#pragma once

#include "integers.h"
#include <cstdio>
#include <cstring>
#include <queue>

// =========================================================================
// UART 16550A — Serial port (COM1 at 0x3F8-0x3FF)
//
// TX output to host stdout, RX from host stdin (interactive console).
// =========================================================================

class UART {
public:
  static constexpr u16 BASE = 0x3F8;
  static constexpr u16 SIZE = 8;

  u8 read(u16 port) {
    u16 reg = port - BASE;
    if (dlab && reg == 0) return dll;
    if (dlab && reg == 1) return dlm;

    switch (reg) {
    case 0: // RBR — Receive Buffer
      if (!rx_fifo.empty()) {
        u8 ch = rx_fifo.front();
        rx_fifo.pop();
        return ch;
      }
      return 0;
    case 1: // IER — Interrupt Enable
      return ier;
    case 2: // IIR — Interrupt Identification
      // Bits 7:6 = FIFO status (0xC0 = FIFOs enabled, 16550A)
      // Priority: RDA (0x04) > THRE (0x02)
      if ((ier & 0x01) && !rx_fifo.empty())
        return 0xC4;  // RDA + FIFOs enabled
      if (thre_pending) {
        thre_pending = false;  // Reading IIR clears THRE interrupt
        return 0xC2;  // THRE + FIFOs enabled
      }
      return 0xC1; // No interrupt pending, FIFOs enabled
    case 3: // LCR — Line Control
      return lcr;
    case 4: // MCR — Modem Control
      return mcr;
    case 5: // LSR — Line Status
      // Bit 0: DR (Data Ready) — set when RX FIFO has data
      // Bit 5: THRE (Transmitter Holding Register Empty) — always ready
      // Bit 6: TEMT (Transmitter Empty) — always empty
      return 0x60 | (rx_fifo.empty() ? 0 : 0x01);
    case 6: // MSR — Modem Status
      // Report DCD, DSR, CTS active so opens don't block on carrier detect
      return 0xB0;  // DCD (bit 7) + DSR (bit 5) + CTS (bit 4)
    case 7: // SCR — Scratch
      return scr;
    default:
      return 0xFF;
    }
  }

  void write(u16 port, u8 val) {
    u16 reg = port - BASE;
    if (dlab && reg == 0) { dll = val; return; }
    if (dlab && reg == 1) { dlm = val; return; }

    switch (reg) {
    case 0: // THR — Transmitter Holding Register
      if (output_fn)
        output_fn(val);
      else
        fputc(val, stderr);
      // After transmit, THR is empty again → THRE interrupt if enabled
      if (ier & 0x02) thre_pending = true;
      break;
    case 1: // IER
    {
      u8 old_ier = ier;
      ier = val;
      // THRE interrupt fires only on 0→1 transition of IER THRI bit
      // (THR is always empty in our instant-write model)
      if ((val & 0x02) && !(old_ier & 0x02))
        thre_pending = true;
      break;
    }
    case 2: // FCR — FIFO Control Register (write-only)
      // Bit 0: enable FIFOs (we always report enabled)
      // Bit 1: clear RX FIFO
      if (val & 0x02) while (!rx_fifo.empty()) rx_fifo.pop();
      break;
    case 3: // LCR
      lcr = val;
      dlab = (val & 0x80) != 0;
      break;
    case 4: // MCR
      mcr = val;
      break;
    case 7: // SCR
      scr = val;
      break;
    default:
      break;
    }
  }

  bool handles(u16 port) const {
    return port >= BASE && port < BASE + SIZE;
  }

  // Optional: redirect output to a callback
  void (*output_fn)(u8 ch) = nullptr;

  // Push a character into the receive FIFO (called from host stdin polling)
  void rx_push(u8 ch) {
    rx_fifo.push(ch);
  }

  // Returns true if the UART has a pending interrupt (for PIC IRQ 4)
  bool has_irq() const {
    // RDA interrupt: IER bit 0 enabled and data available
    if ((ier & 0x01) && !rx_fifo.empty()) return true;
    // THRE interrupt: IER bit 1 enabled and THR empty
    if ((ier & 0x02) && thre_pending) return true;
    return false;
  }

private:
  u8 ier = 0, lcr = 0, mcr = 0, scr = 0;
  u8 dll = 0, dlm = 0;
  bool dlab = false;
  bool thre_pending = false;
  std::queue<u8> rx_fifo;
};

// =========================================================================
// 8259 PIC — Programmable Interrupt Controller
//
// Two cascaded PICs: master (0x20-0x21), slave (0xA0-0xA1).
// Enough to handle IRQ masking and EOI for Linux early boot.
// =========================================================================

class PIC {
public:
  PIC(u16 base, bool is_master) : base(base), is_master(is_master) {}

  u8 read(u16 port) {
    if (port == base) {
      // Read IRR or ISR depending on OCW3
      return read_isr ? isr : irr;
    } else {
      // IMR
      return imr;
    }
  }

  void write(u16 port, u8 val) {
    if (port == base) {
      if (val & 0x10) {
        // ICW1
        icw_step = 1;
        icw4_needed = (val & 0x01) != 0;
      } else if (val & 0x08) {
        // OCW3
        if (val & 0x02)
          read_isr = (val & 0x01) != 0;
      } else {
        // OCW2
        if ((val & 0xE0) == 0x20) {
          // Non-specific EOI: clear highest priority ISR bit
          for (int i = 0; i < 8; i++) {
            if (isr & (1 << i)) {
              isr &= ~(1 << i);
              break;
            }
          }
        } else if ((val & 0xE0) == 0x60) {
          // Specific EOI
          int irq = val & 0x07;
          isr &= ~(1 << irq);
        }
      }
    } else {
      // Port base+1
      if (icw_step == 1) {
        // ICW2: vector offset
        vector_offset = val & 0xF8;
        icw_step = 2;
      } else if (icw_step == 2) {
        // ICW3: cascade
        icw_step = icw4_needed ? 3 : 0;
      } else if (icw_step == 3) {
        // ICW4
        icw_step = 0;
      } else {
        // OCW1: IMR
        imr = val;
      }
    }
  }

  bool handles(u16 port) const {
    return port == base || port == base + 1;
  }

  // Raise an IRQ line
  void raise_irq(int irq) {
    irr |= (1 << irq);
  }

  // Check if there's a pending, unmasked interrupt
  bool has_pending() const {
    return (irr & ~imr & ~isr) != 0;
  }

  // Acknowledge: returns vector number, moves IRR→ISR
  int acknowledge() {
    for (int i = 0; i < 8; i++) {
      u8 bit = 1 << i;
      if ((irr & bit) && !(imr & bit) && !(isr & bit)) {
        irr &= ~bit;
        isr |= bit;
        return vector_offset + i;
      }
    }
    return -1; // spurious
  }

  u8 get_imr() const { return imr; }
  u8 get_irr() const { return irr; }
  u8 get_vector_offset() const { return vector_offset; }

private:
  u16 base;
  bool is_master;
  u8 irr = 0;           // Interrupt Request Register
  u8 isr = 0;           // In-Service Register
  u8 imr = 0xFF;        // Interrupt Mask Register (all masked initially)
  u8 vector_offset = 0; // Base vector number
  int icw_step = 0;
  bool icw4_needed = false;
  bool read_isr = false;
};

// =========================================================================
// 8254 PIT — Programmable Interval Timer
//
// Channel 0 at IRQ 0 for system timer. Minimal implementation.
// =========================================================================

class PIT {
public:
  static constexpr u16 BASE = 0x40;
  static constexpr u16 SIZE = 4;

  PIT() {
    // Channel 2 gate is controlled by port 0x61 bit 0, default off
    channels[2].gate = false;
  }

  u8 read(u16 port) {
    if (port == 0x43) return 0; // Mode/command (write-only, return 0)

    int ch = port - BASE;
    if (ch < 0 || ch > 2) return 0xFF;

    Channel &c = channels[ch];
    if (c.latched) {
      u8 val;
      if (c.latch_low) {
        val = c.latch_val & 0xFF;
        c.latch_low = false;
      } else {
        val = (c.latch_val >> 8) & 0xFF;
        c.latched = false;
      }
      return val;
    }

    // Read current count
    if (c.read_low) {
      c.read_low = false;
      return c.count & 0xFF;
    } else {
      c.read_low = true;
      return (c.count >> 8) & 0xFF;
    }
  }

  void write(u16 port, u8 val) {
    if (port == 0x43) {
      // Mode/command register
      int ch = (val >> 6) & 0x03;
      if (ch == 3)
        return; // Read-back (ignore for now)

      int rw = (val >> 4) & 0x03;
      if (rw == 0) {
        // Latch command
        channels[ch].latched = true;
        channels[ch].latch_val = channels[ch].count;
        channels[ch].latch_low = true;
        return;
      }

      channels[ch].mode = (val >> 1) & 0x07;
      channels[ch].write_low = true;
      return;
    }

    int ch = port - BASE;
    if (ch < 0 || ch > 2) return;

    Channel &c = channels[ch];
    if (c.write_low) {
      c.reload = (c.reload & 0xFF00) | val;
      c.write_low = false;
    } else {
      c.reload = (c.reload & 0x00FF) | ((u16)val << 8);
      c.write_low = true;
      c.count = c.reload;
      if (c.reload == 0) c.count = 65536;
    }
  }

  bool handles(u16 port) const {
    return port >= BASE && port < BASE + SIZE;
  }

  // Tick all channels by a number of PIT cycles.
  // Returns true if channel 0 generated an IRQ.
  bool tick(u64 cycles) {
    bool irq = false;
    for (int ch = 0; ch < 3; ch++) {
      Channel &c = channels[ch];
      if (!c.gate && ch == 2)
        continue; // Channel 2 needs gate enabled
      if (c.reload == 0 && c.count == 0)
        continue;

      for (u64 i = 0; i < cycles; i++) {
        if (c.count > 0) c.count--;
        if (c.count == 0) {
          c.output = true;
          if (ch == 0) irq = true;
          // Mode 2 (rate generator) or Mode 3 (square wave): auto-reload
          if (c.mode == 2 || c.mode == 3) {
            c.output = false;
            c.count = c.reload;
            if (c.count == 0) c.count = 65536;
          }
          // Mode 0 (one-shot): output stays high, count stays 0
        }
      }
    }
    return irq;
  }

  // Port 0x61 (System Control Port B) state
  u8 port_b = 0;

  // Read port 0x61: bit 0 = ch2 gate, bit 5 = ch2 output
  u8 read_port_b() {
    u8 val = port_b & 0x03; // Preserve gate/speaker bits
    if (channels[2].output)
      val |= 0x20; // Bit 5 = timer 2 output
    return val;
  }

  // Write port 0x61: bit 0 = ch2 gate enable
  void write_port_b(u8 val) {
    bool old_gate = channels[2].gate;
    bool new_gate = (val & 0x01) != 0;
    port_b = val;
    channels[2].gate = new_gate;
    // Rising edge on gate reloads count and clears output (mode 0)
    if (!old_gate && new_gate) {
      channels[2].count = channels[2].reload;
      if (channels[2].count == 0)
        channels[2].count = 65536;
      channels[2].output = false;
    }
  }

private:
  struct Channel {
    u32 count = 0;
    u32 reload = 0;
    u8 mode = 0;
    bool write_low = true;
    bool read_low = true;
    bool latched = false;
    u32 latch_val = 0;
    bool latch_low = true;
    bool gate = true;  // Gate input (channels 0,1 default on; ch2 controlled by port 0x61)
    bool output = false; // Output pin state
  };
  Channel channels[3];
};

// =========================================================================
// 8042 Keyboard Controller — stub
//
// Returns "no data available" so Linux doesn't hang probing it.
// =========================================================================

class KeyboardController {
public:
  u8 read(u16 port) {
    if (port == 0x64) {
      // Status register: bit 0 = output buffer full (0 = no data)
      return 0x00;
    }
    if (port == 0x60) {
      // Data register: no data
      return 0x00;
    }
    return 0xFF;
  }

  void write(u16 port, u8 val) {
    if (port == 0x64) {
      last_cmd = val;
    } else if (port == 0x60) {
      // Command data
      if (last_cmd == 0xD1) {
        // Write output port — used for A20 gate
        // Ignore
      }
    }
  }

  bool handles(u16 port) const {
    return port == 0x60 || port == 0x64;
  }

private:
  u8 last_cmd = 0;
};

// =========================================================================
// CMOS/RTC — Real-Time Clock (ports 0x70-0x71)
//
// Linux reads RTC during boot. Return reasonable defaults.
// =========================================================================

class CMOS {
public:
  u8 read(u16 port) {
    if (port == 0x71) {
      switch (index) {
      case 0x00: return 0x00;  // Seconds
      case 0x02: return 0x00;  // Minutes
      case 0x04: return 0x12;  // Hours (12:00)
      case 0x06: return 0x01;  // Day of week
      case 0x07: return 0x01;  // Day of month
      case 0x08: return 0x01;  // Month
      case 0x09: return 0x24;  // Year (2024)
      case 0x0A: return 0x26;  // Status A: divider + rate
      case 0x0B: return 0x02;  // Status B: 24h mode
      case 0x0C: return 0x00;  // Status C: no interrupts
      case 0x0D: return 0x80;  // Status D: valid RAM/time
      case 0x0F: return 0x00;  // Shutdown status
      case 0x10: return 0x00;  // Floppy types
      case 0x15: return 0x80;  // Base memory low (640K)
      case 0x16: return 0x02;  // Base memory high
      case 0x17: return 0x00;  // Extended memory low
      case 0x18: return 0xFC;  // Extended memory high (~64MB)
      case 0x32: return 0x20;  // Century (20)
      default:   return 0x00;
      }
    }
    return 0xFF;
  }

  void write(u16 port, u8 val) {
    if (port == 0x70)
      index = val & 0x7F;  // Bit 7 is NMI mask
    // Ignore writes to 0x71
  }

  bool handles(u16 port) const {
    return port == 0x70 || port == 0x71;
  }

private:
  u8 index = 0;
};

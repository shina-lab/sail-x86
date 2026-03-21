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
// VGA Text Mode — emulates 80×25 text framebuffer at 0xB8000
//
// The framebuffer lives in guest physical memory (0xB8000-0xBFFFF).
// This class handles VGA I/O port registers (CRTC, attribute controller,
// sequencer, graphics controller, DAC).  The emulator periodically reads
// the framebuffer from physical memory and renders it to the host terminal.
// =========================================================================

class VGAText {
public:
  static constexpr u64 FB_BASE = 0xB8000;
  static constexpr u64 FB_SIZE = 0x8000;  // 32KB text window
  static constexpr int COLS = 80;
  static constexpr int ROWS = 50;

  // CRTC registers (port 0x3D4 index, 0x3D5 data)
  u8 crtc_index = 0;
  u8 crtc_regs[256] = {};

  // Attribute controller (port 0x3C0 index/data, 0x3C1 read)
  u8 attr_index = 0;
  bool attr_flip_flop = false;  // toggled by reading 0x3DA
  u8 attr_regs[32] = {};

  // Sequencer (port 0x3C4/0x3C5)
  u8 seq_index = 0;
  u8 seq_regs[8] = {};

  // Graphics controller (port 0x3CE/0x3CF)
  u8 gc_index = 0;
  u8 gc_regs[16] = {};

  // Misc output register (port 0x3C2 write, 0x3CC read)
  u8 misc_output = 0x67;  // color mode, enable RAM, clock select

  // DAC (ports 0x3C6-0x3C9)
  u8 dac_mask = 0xFF;
  u8 dac_read_index = 0;
  u8 dac_write_index = 0;
  u8 dac_state = 0;    // 0 = write mode, 3 = read mode
  u8 dac_rgb_pos = 0;  // 0, 1, 2 for R, G, B
  u8 dac_palette[256][3] = {};

  // Retrace counter (for Input Status Register 1)
  u8 isr1_counter = 0;

  VGAText() {
    // 80x50 color text CRTC defaults (8-pixel font)
    crtc_regs[0x01] = 79;    // Horizontal display end (80 cols)
    crtc_regs[0x09] = 0x07;  // Max scan line = 7 (8-pixel font)
    crtc_regs[0x0A] = 6;     // Cursor start scan line
    crtc_regs[0x0B] = 7;     // Cursor end scan line
    // Sequencer defaults for text mode
    seq_regs[1] = 0x00;  // Clocking mode
    seq_regs[2] = 0x03;  // Map mask (planes 0,1)
    seq_regs[4] = 0x02;  // Memory mode (text, odd/even)
  }

  u8 read(u16 port) {
    switch (port) {
    case 0x3C0: return attr_index;
    case 0x3C1: return attr_regs[attr_index & 0x1F];
    case 0x3C2: return 0x00;  // Input Status 0 (no interrupt)
    case 0x3C4: return seq_index;
    case 0x3C5: return seq_regs[seq_index & 0x07];
    case 0x3C6: return dac_mask;
    case 0x3C7: return dac_state;
    case 0x3C8: return dac_write_index;
    case 0x3C9: {
      u8 val = dac_palette[dac_read_index][dac_rgb_pos];
      if (++dac_rgb_pos >= 3) { dac_rgb_pos = 0; dac_read_index++; }
      return val;
    }
    case 0x3CA: return 0x00;  // Feature Control (read)
    case 0x3CC: return misc_output;
    case 0x3CE: return gc_index;
    case 0x3CF: return gc_regs[gc_index & 0x0F];
    case 0x3D4: return crtc_index;
    case 0x3D5: return crtc_regs[crtc_index];
    case 0x3DA:
      attr_flip_flop = false;  // reading ISR1 resets attribute flip-flop
      isr1_counter++;
      // Bit 0: display enable (1 during retrace), Bit 3: vertical retrace
      return (isr1_counter & 1) ? 0x09 : 0x00;
    default: return 0xFF;
    }
  }

  void write(u16 port, u8 val) {
    switch (port) {
    case 0x3C0:
      if (!attr_flip_flop)
        attr_index = val;
      else
        attr_regs[attr_index & 0x1F] = val;
      attr_flip_flop = !attr_flip_flop;
      break;
    case 0x3C2: misc_output = val; break;
    case 0x3C4: seq_index = val; break;
    case 0x3C5: seq_regs[seq_index & 0x07] = val; break;
    case 0x3C6: dac_mask = val; break;
    case 0x3C7: dac_read_index = val; dac_rgb_pos = 0; dac_state = 3; break;
    case 0x3C8: dac_write_index = val; dac_rgb_pos = 0; dac_state = 0; break;
    case 0x3C9:
      dac_palette[dac_write_index][dac_rgb_pos] = val;
      if (++dac_rgb_pos >= 3) { dac_rgb_pos = 0; dac_write_index++; }
      break;
    case 0x3CE: gc_index = val; break;
    case 0x3CF: gc_regs[gc_index & 0x0F] = val; break;
    case 0x3D4: crtc_index = val; break;
    case 0x3D5: crtc_regs[crtc_index] = val; break;
    case 0x3DA: /* Feature Control (write) — ignore */ break;
    default: break;
    }
  }

  bool handles(u16 port) const {
    return (port >= 0x3C0 && port <= 0x3CF) ||
           port == 0x3D4 || port == 0x3D5 || port == 0x3DA;
  }

  // Cursor position from CRTC regs 0x0E (high) and 0x0F (low)
  u16 cursor_pos() const {
    return ((u16)crtc_regs[0x0E] << 8) | crtc_regs[0x0F];
  }

  // Display start address from CRTC regs 0x0C (high) and 0x0D (low)
  // Used for hardware scrolling within the 32KB text buffer.
  u16 start_addr() const {
    return ((u16)crtc_regs[0x0C] << 8) | crtc_regs[0x0D];
  }
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
// 8042 Keyboard Controller
//
// Emulates the i8042 PS/2 controller enough for Linux's atkbd driver.
// Scancodes are pushed from the host side; the guest reads them via
// port 0x60 and gets IRQ 1 when data is available.
// Uses AT scan code set 1 (translated), which is what the i8042
// presents to the CPU by default.
// =========================================================================

class KeyboardController {
public:
  u8 read(u16 port) {
    if (port == 0x64) {
      // Status register:
      //   bit 0 = output buffer full (data available at port 0x60)
      //   bit 1 = input buffer full (0 = ready for commands)
      //   bit 2 = system flag (POST passed)
      //   bit 3 = command/data (0 = data written to 0x60)
      u8 status = 0x14;  // system flag (bit 2) + keyboard unlocked (bit 4)
      if (!out_buf.empty())
        status |= 0x01;  // output buffer full
      return status;
    }
    if (port == 0x60) {
      if (!out_buf.empty()) {
        u8 val = out_buf.front();
        out_buf.pop();
        return val;
      }
      return 0x00;
    }
    return 0xFF;
  }

  void write(u16 port, u8 val) {
    if (port == 0x64) {
      // Controller commands
      switch (val) {
      case 0x20:  // Read controller configuration byte
        out_buf.push(config_byte);
        break;
      case 0x60:  // Write controller configuration byte (next byte to 0x60)
        last_cmd = 0x60;
        break;
      case 0xA7:  // Disable second PS/2 port (AUX)
        config_byte |= 0x20;   // set AUXDIS bit
        break;
      case 0xA8:  // Enable second PS/2 port (AUX)
        config_byte &= ~0x20;  // clear AUXDIS bit
        break;
      case 0xA9:  // Test second PS/2 port
        out_buf.push(0x00);  // pass
        break;
      case 0xAA:  // Controller self-test
        out_buf.push(0x55);  // pass
        break;
      case 0xAB:  // Test first PS/2 port
        out_buf.push(0x00);  // pass
        break;
      case 0xAD:  // Disable first PS/2 port
        kbd_enabled = false;
        break;
      case 0xAE:  // Enable first PS/2 port
        kbd_enabled = true;
        break;
      case 0xD1:  // Write output port (next byte to 0x60)
        last_cmd = 0xD1;
        break;
      default:
        last_cmd = val;
        break;
      }
    } else if (port == 0x60) {
      if (last_cmd == 0x60) {
        // Writing controller configuration byte
        config_byte = val;
        last_cmd = 0;
      } else if (last_cmd == 0xD1) {
        // Write output port — A20 gate etc., ignore
        last_cmd = 0;
      } else {
        // Data sent to keyboard device — handle device commands
        switch (val) {
        case 0xED:  // Set LEDs (next byte is LED state)
          last_kbd_cmd = 0xED;
          out_buf.push(0xFA);  // ACK
          break;
        case 0xF0:  // Set scan code set (next byte is set number)
          last_kbd_cmd = 0xF0;
          out_buf.push(0xFA);  // ACK
          break;
        case 0xF2:  // Identify keyboard
          out_buf.push(0xFA);  // ACK
          out_buf.push(0xAB);  // keyboard ID byte 1
          out_buf.push(0x83);  // keyboard ID byte 2 (MF2)
          break;
        case 0xF3:  // Set typematic rate (next byte is rate)
          last_kbd_cmd = 0xF3;
          out_buf.push(0xFA);  // ACK
          break;
        case 0xF4:  // Enable scanning
          out_buf.push(0xFA);  // ACK
          break;
        case 0xF5:  // Disable scanning
          out_buf.push(0xFA);  // ACK
          break;
        case 0xFF:  // Reset
          out_buf.push(0xFA);  // ACK
          out_buf.push(0xAA);  // self-test passed
          break;
        default:
          if (last_kbd_cmd == 0xED || last_kbd_cmd == 0xF0 ||
              last_kbd_cmd == 0xF3) {
            // Second byte of a two-byte command — just ACK it
            out_buf.push(0xFA);
            last_kbd_cmd = 0;
          }
          break;
        }
      }
    }
  }

  bool handles(u16 port) const {
    return port == 0x60 || port == 0x64;
  }

  // Push a scancode byte from the host side.
  void push_scancode(u8 sc) {
    out_buf.push(sc);
  }

  // Returns true if there's data waiting (for IRQ 1).
  bool has_data() const {
    return !out_buf.empty();
  }

private:
  std::queue<u8> out_buf;   // output buffer (scancodes + command responses)
  u8 last_cmd = 0;          // last command written to port 0x64
  u8 last_kbd_cmd = 0;      // last device command (for two-byte sequences)
  u8 config_byte = 0x45;    // default: keyboard interrupt enabled, translation on
  bool kbd_enabled = true;
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

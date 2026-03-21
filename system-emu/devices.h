#pragma once

#include "integers.h"
#include <cstdio>
#include <cstring>
#include <queue>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>

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
  CMOS() {
    memset(regs, 0, sizeof(regs));
    // RTC time defaults
    regs[0x00] = 0x00;  // Seconds
    regs[0x02] = 0x00;  // Minutes
    regs[0x04] = 0x12;  // Hours (12:00)
    regs[0x06] = 0x01;  // Day of week
    regs[0x07] = 0x01;  // Day of month
    regs[0x08] = 0x01;  // Month
    regs[0x09] = 0x24;  // Year (2024)
    regs[0x0A] = 0x26;  // Status A: divider + rate
    regs[0x0B] = 0x02;  // Status B: 24h mode
    regs[0x0C] = 0x00;  // Status C: no interrupts
    regs[0x0D] = 0x80;  // Status D: valid RAM/time
    regs[0x0F] = 0x00;  // Shutdown status
    regs[0x10] = 0x40;  // Floppy: drive A = 1.44MB 3.5", B = none
    regs[0x14] = 0x06;  // Equipment: VGA 80x25, no floppy via bit 0
    regs[0x15] = 0x80;  // Base memory low (640K)
    regs[0x16] = 0x02;  // Base memory high
    regs[0x32] = 0x20;  // Century (20)
  }

  // Populate extended memory registers from RAM size.
  void set_ram_size(u64 bytes) {
    // 0x30/0x31: extended memory above 1MB in 1KB units (capped at 0xFFFF = 64MB)
    u64 ext_kb = (bytes > 0x100000) ? (bytes - 0x100000) / 1024 : 0;
    if (ext_kb > 0xFFFF) ext_kb = 0xFFFF;
    regs[0x30] = ext_kb & 0xFF;
    regs[0x31] = (ext_kb >> 8) & 0xFF;
    // Mirror in 0x17/0x18 (same meaning, different CMOS slots)
    regs[0x17] = regs[0x30];
    regs[0x18] = regs[0x31];
    // 0x34/0x35: extended memory above 16MB in 64KB units
    u64 ext16_64k = (bytes > 0x1000000) ? (bytes - 0x1000000) / 65536 : 0;
    if (ext16_64k > 0xFFFF) ext16_64k = 0xFFFF;
    regs[0x34] = ext16_64k & 0xFF;
    regs[0x35] = (ext16_64k >> 8) & 0xFF;
  }

  u8 read(u16 port) {
    if (port == 0x71)
      return regs[index & 0x7F];
    return 0xFF;
  }

  void write(u16 port, u8 val) {
    if (port == 0x70)
      index = val & 0x7F;  // Bit 7 is NMI mask
    else if (port == 0x71)
      regs[index & 0x7F] = val;
  }

  bool handles(u16 port) const {
    return port == 0x70 || port == 0x71;
  }

private:
  u8 index = 0;
  u8 regs[128];
};

// =========================================================================
// PCI Config Space — Minimal i440FX-like host bridge at 0:0.0
//
// SeaBIOS requires an i440FX PMC to manage shadow RAM (PAM registers).
// We provide a minimal PCI config space that reports an i440FX bridge
// and accepts PAM register writes (our RAM is already shadow-capable).
// =========================================================================

class PCIConfigSpace {
public:
  PCIConfigSpace() {
    // Device 0:0.0 — i440FX Host Bridge
    memset(dev0, 0, sizeof(dev0));
    dev0[0x00] = 0x86; dev0[0x01] = 0x80;  // Vendor: Intel (0x8086)
    dev0[0x02] = 0x37; dev0[0x03] = 0x12;  // Device: i440FX (0x1237)
    dev0[0x04] = 0x06;                      // Command: mem + bus master
    dev0[0x06] = 0x00; dev0[0x07] = 0x02;  // Status: devsel medium
    dev0[0x08] = 0x02;                      // Revision
    dev0[0x0A] = 0x00;                      // Subclass: host bridge
    dev0[0x0B] = 0x06;                      // Class: bridge
    dev0[0x0E] = 0x00;                      // Header type 0
    // PAM registers (0x59-0x5F): default all-open (R/W to DRAM)
    for (int i = 0x59; i <= 0x5F; i++)
      dev0[i] = 0x33;  // R/W enabled for all regions

    // Device 0:1.0 — PIIX3 IDE Controller (ISA-compatible mode)
    // SeaBIOS scans PCI for CLASS_STORAGE_IDE devices. This makes it
    // find our ISA ATA controller at the standard ports 0x1F0/0x3F6.
    memset(dev1, 0, sizeof(dev1));
    dev1[0x00] = 0x86; dev1[0x01] = 0x80;  // Vendor: Intel (0x8086)
    dev1[0x02] = 0x10; dev1[0x03] = 0x70;  // Device: PIIX3 IDE (0x7010)
    dev1[0x04] = 0x01;                      // Command: I/O space enabled
    dev1[0x08] = 0x00;                      // Revision
    dev1[0x09] = 0x80;                      // Prog IF: ISA-compat (legacy ports)
    dev1[0x0A] = 0x01;                      // Subclass: IDE
    dev1[0x0B] = 0x01;                      // Class: mass storage
    dev1[0x0E] = 0x00;                      // Header type 0
  }

  void write_addr(u32 val) { addr = val; }
  u32 read_addr() const { return addr; }

  u32 read_data() const {
    if (!(addr & 0x80000000)) return 0xFFFFFFFF;  // Enable bit not set
    int bus = (addr >> 16) & 0xFF;
    int dev = (addr >> 11) & 0x1F;
    int func = (addr >> 8) & 0x07;
    int reg = addr & 0xFC;
    if (bus != 0) return 0xFFFFFFFF;
    const u8 *cfg = get_config(dev, func);
    if (cfg && reg < 256) {
      u32 val;
      memcpy(&val, &cfg[reg], 4);
      return val;
    }
    return 0xFFFFFFFF;  // No device present
  }

  void write_data(u32 val) {
    if (!(addr & 0x80000000)) return;
    int bus = (addr >> 16) & 0xFF;
    int dev = (addr >> 11) & 0x1F;
    int func = (addr >> 8) & 0x07;
    int reg = addr & 0xFC;
    if (bus != 0) return;
    u8 *cfg = get_config_mut(dev, func);
    if (!cfg) return;
    // Allow writes to specific registers
    if (cfg == dev0 && reg >= 0x59 && reg < 0x60) {
      // PAM registers on host bridge
      memcpy(&dev0[reg], &val, 4);
    }
    // Absorb other writes silently
  }

private:
  const u8 *get_config(int dev, int func) const {
    if (dev == 0 && func == 0) return dev0;
    if (dev == 1 && func == 0) return dev1;
    return nullptr;
  }
  u8 *get_config_mut(int dev, int func) {
    if (dev == 0 && func == 0) return dev0;
    if (dev == 1 && func == 0) return dev1;
    return nullptr;
  }

  u32 addr = 0;
  u8 dev0[256];  // 0:0.0 — i440FX host bridge
  u8 dev1[256];  // 0:1.0 — PIIX3 IDE controller
};

// =========================================================================
// ATA/IDE PIO Disk Controller — Primary channel (0x1F0-0x1F7, 0x3F6)
//
// Supports PIO-mode READ SECTORS, WRITE SECTORS, IDENTIFY DEVICE,
// FLUSH CACHE, and INITIALIZE DEVICE PARAMETERS commands.
// =========================================================================

class ATAController {
public:
  ~ATAController() {
    if (disk_fd >= 0) close(disk_fd);
  }

  bool open(const char *path) {
    disk_fd = ::open(path, O_RDWR);
    if (disk_fd < 0) { perror(path); return false; }
    struct stat st;
    if (fstat(disk_fd, &st) < 0) { perror("fstat"); close(disk_fd); disk_fd = -1; return false; }
    disk_size = st.st_size;
    status = 0x40;  // DRDY
    return true;
  }

  bool is_open() const { return disk_fd >= 0; }

  bool handles(u16 port) const {
    return (0x1F0 <= port && port <= 0x1F7) || port == 0x3F6;
  }

  u8 read(u16 port) {
    // If drive 1 is selected and not data port, return 0
    if ((drive_head & 0x10) && port != 0x1F0)
      return 0x00;

    switch (port) {
    case 0x1F0: // Data (low byte of 16-bit — use read16 for real reads)
      return 0xFF;
    case 0x1F1: // Error
      return error;
    case 0x1F2: // Sector Count
      return sector_count;
    case 0x1F3: // LBA Low
      return lba_low;
    case 0x1F4: // LBA Mid
      return lba_mid;
    case 0x1F5: // LBA High
      return lba_high;
    case 0x1F6: // Drive/Head
      return drive_head;
    case 0x1F7: // Status (clears IRQ)
      irq_pending = false;
      return status;
    case 0x3F6: // Alternate Status (does NOT clear IRQ)
      return (drive_head & 0x10) ? 0x00 : status;
    default:
      return 0xFF;
    }
  }

  void write(u16 port, u8 val) {
    switch (port) {
    case 0x1F0: // Data (low byte — use write16 for real writes)
      break;
    case 0x1F1: // Features
      features = val;
      break;
    case 0x1F2: // Sector Count
      sector_count = val;
      break;
    case 0x1F3: // LBA Low
      lba_low = val;
      break;
    case 0x1F4: // LBA Mid
      lba_mid = val;
      break;
    case 0x1F5: // LBA High
      lba_high = val;
      break;
    case 0x1F6: // Drive/Head
      drive_head = val;
      break;
    case 0x1F7: // Command
      if (drive_head & 0x10) break;  // Drive 1: ignore
      execute_command(val);
      break;
    case 0x3F6: // Device Control
      nien = (val & 0x02) != 0;
      if (val & 0x04) {
        // SRST — software reset
        status = 0x40;  // DRDY
        error = 0x01;   // Diagnostic passed
        sector_count = 0x01;
        lba_low = 0x01;
        lba_mid = 0x00;
        lba_high = 0x00;
        drive_head = 0x00;
        buf_reading = false;
        buf_writing = false;
      }
      break;
    }
  }

  // 16-bit data port read (called from z__port_in16)
  u16 read16(u16 port) {
    if (port != 0x1F0 || !buf_reading) return 0xFFFF;
    u16 val;
    memcpy(&val, &data_buf[buf_pos * 2], 2);
    buf_pos++;
    if (buf_pos >= 256) {
      // Sector transfer complete
      buf_pos = 0;
      sectors_remaining--;
      if (sectors_remaining > 0) {
        // Load next sector
        current_lba++;
        load_sector(current_lba);
      } else {
        buf_reading = false;
        status = 0x40;  // DRDY, clear DRQ
        raise_irq();
      }
    }
    return val;
  }

  // 16-bit data port write (called from z__port_out16)
  void write16(u16 port, u16 val) {
    if (port != 0x1F0 || !buf_writing) return;
    memcpy(&data_buf[buf_pos * 2], &val, 2);
    buf_pos++;
    if (buf_pos >= 256) {
      // Sector received, write to disk
      u64 offset = current_lba * 512;
      if (offset + 512 <= disk_size)
        (void)!pwrite(disk_fd, data_buf, 512, offset);
      buf_pos = 0;
      sectors_remaining--;
      if (sectors_remaining > 0) {
        current_lba++;
        status = 0x48;  // DRDY | DRQ
      } else {
        buf_writing = false;
        status = 0x40;  // DRDY
      }
      raise_irq();
    }
  }

  bool irq_pending = false;

private:
  int disk_fd = -1;
  u64 disk_size = 0;

  // ATA registers
  u8 error = 0;
  u8 features = 0;
  u8 sector_count = 0;
  u8 lba_low = 0;
  u8 lba_mid = 0;
  u8 lba_high = 0;
  u8 drive_head = 0;
  u8 status = 0;
  bool nien = false;  // nIEN bit from device control

  // Data transfer state
  u8 data_buf[512];
  int buf_pos = 0;
  bool buf_reading = false;
  bool buf_writing = false;
  u32 current_lba = 0;
  int sectors_remaining = 0;

  u32 get_lba() const {
    if (drive_head & 0x40) {
      // LBA mode
      return lba_low | (lba_mid << 8) | (lba_high << 16) |
             ((drive_head & 0x0F) << 24);
    }
    // CHS mode: convert to LBA
    // C = (lba_high << 8) | lba_mid, H = drive_head & 0x0F, S = lba_low
    u16 cyl = (lba_high << 8) | lba_mid;
    u8 head = drive_head & 0x0F;
    u8 sec = lba_low;
    // Assume 16 heads, 63 sectors/track (standard geometry)
    return (cyl * 16 + head) * 63 + (sec - 1);
  }

  void load_sector(u32 lba) {
    u64 offset = (u64)lba * 512;
    memset(data_buf, 0, 512);
    if (offset + 512 <= disk_size)
      (void)!pread(disk_fd, data_buf, 512, offset);
    buf_pos = 0;
    buf_reading = true;
    status = 0x48;  // DRDY | DRQ
  }

  void raise_irq() {
    if (!nien) irq_pending = true;
  }

  void execute_command(u8 cmd) {
    switch (cmd) {
    case 0x20: // READ SECTORS
    case 0x21: // READ SECTORS (no retry)
    {
      current_lba = get_lba();
      sectors_remaining = sector_count ? sector_count : 256;
      load_sector(current_lba);
      raise_irq();
      break;
    }
    case 0x30: // WRITE SECTORS
    case 0x31: // WRITE SECTORS (no retry)
    {
      current_lba = get_lba();
      sectors_remaining = sector_count ? sector_count : 256;
      buf_pos = 0;
      buf_writing = true;
      status = 0x48;  // DRDY | DRQ
      break;
    }
    case 0x91: // INITIALIZE DEVICE PARAMETERS
      status = 0x40;  // DRDY
      raise_irq();
      break;
    case 0xE7: // FLUSH CACHE
      status = 0x40;  // DRDY
      raise_irq();
      break;
    case 0xEC: // IDENTIFY DEVICE
      identify();
      break;
    default:
      // Unknown command: set error
      status = 0x41;  // DRDY | ERR
      error = 0x04;   // ABRT
      raise_irq();
      break;
    }
  }

  void identify() {
    memset(data_buf, 0, 512);
    u16 *id = reinterpret_cast<u16 *>(data_buf);
    id[0] = 0x0040;    // General: fixed disk, non-removable
    u32 total_sectors = disk_size / 512;
    // CHS geometry (word 1=cylinders, 3=heads, 6=sectors)
    id[1] = total_sectors / (16 * 63);  // cylinders
    if (id[1] > 16383) id[1] = 16383;
    id[3] = 16;   // heads
    id[6] = 63;   // sectors per track

    // Model string (words 27-46, 40 ASCII chars, swapped byte pairs)
    const char *model = "Sail-x86 Virtual Disk                   ";
    for (int i = 0; i < 20; i++)
      id[27 + i] = (model[i * 2] << 8) | model[i * 2 + 1];

    // Serial number (words 10-19)
    const char *serial = "SAIL0001            ";
    for (int i = 0; i < 10; i++)
      id[10 + i] = (serial[i * 2] << 8) | serial[i * 2 + 1];

    // Firmware rev (words 23-26)
    const char *fwrev = "1.0     ";
    for (int i = 0; i < 4; i++)
      id[23 + i] = (fwrev[i * 2] << 8) | fwrev[i * 2 + 1];

    id[47] = 0x8001;   // Max sectors per R/W MULTIPLE (1)
    id[49] = 0x0200;   // Capabilities: LBA supported
    id[51] = 0x0200;   // PIO timing mode
    id[53] = 0x0007;   // Words 54-58, 64-70, 88 valid
    id[54] = id[1];    // Current cylinders
    id[55] = 16;       // Current heads
    id[56] = 63;       // Current sectors
    u32 cur_cap = (u32)id[54] * 16 * 63;
    id[57] = cur_cap & 0xFFFF;
    id[58] = (cur_cap >> 16) & 0xFFFF;
    // Total LBA sectors (words 60-61)
    id[60] = total_sectors & 0xFFFF;
    id[61] = (total_sectors >> 16) & 0xFFFF;

    buf_pos = 0;
    buf_reading = true;
    status = 0x48;  // DRDY | DRQ
    raise_irq();
  }
};

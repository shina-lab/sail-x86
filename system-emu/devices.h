#pragma once

#include "integers.h"
#include <cstdio>
#include <cstring>
#include <cstdlib>
#include <vector>
#include <algorithm>
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
// VGA Text Mode — emulates 80×25 (or 80×50) text framebuffer at 0xB8000
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
  static constexpr int ROWS = 25;

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

  // Four 64 KB VGA planes. Reads load all four latches; writes use the
  // sequencer map mask and graphics-controller data path (including the
  // latch-only mode used for accelerated planar copies).
  std::vector<u8> planes = std::vector<u8>(4 * 65536);
  u8 latch[4] = {};

  bool maps(u64 addr) const {
    unsigned map = (gc_regs[6] >> 2) & 3;
    // Keep the existing text RAM view at B0000/B8000. Font uploads and all
    // graphics memory accesses at A0000 go through the VGA data path.
    if (!graphics() && addr >= 0xB0000) return false;
    return addr >= 0xA0000 && addr < (map == 0 ? 0xC0000 : 0xB0000) && map < 2;
  }
  u8 read_mem(u64 addr) {
    unsigned offset = (addr - 0xA0000) & 0xFFFF, plane = gc_regs[4] & 3;
    if (seq_regs[4] & 8) { plane = offset & 3; offset >>= 2; }
    else if (!(seq_regs[4] & 4) && (gc_regs[5] & 0x10)) {
      plane = (plane & 2) | (offset & 1); offset >>= 1;
    }
    for (unsigned p = 0; p < 4; ++p) latch[p] = planes[p * 65536 + offset];
    if (!(gc_regs[5] & 8)) return latch[plane];
    u8 result = 0xFF;
    for (unsigned p = 0; p < 4; ++p)
      if (gc_regs[7] & (1 << p)) result &= ~(latch[p] ^ ((gc_regs[2] & (1 << p)) ? 0xFF : 0));
    return result;
  }
  void write_mem(u64 addr, u8 value) {
    unsigned offset = (addr - 0xA0000) & 0xFFFF;
    unsigned mask = seq_regs[2] & 15;
    if (seq_regs[4] & 8) { mask &= 1 << (offset & 3); offset >>= 2; }
    else if (!(seq_regs[4] & 4) && (gc_regs[5] & 0x10)) {
      mask &= (offset & 1) ? 0xA : 5; offset >>= 1;
    }
    unsigned mode = gc_regs[5] & 3;
    unsigned rotation = gc_regs[3] & 7;
    u8 rotated = (value >> rotation) | (value << ((8 - rotation) & 7));
    for (unsigned p = 0; p < 4; ++p) {
      if (!(mask & (1 << p))) continue;
      u8 result = rotated, bitmask = gc_regs[8];
      if (mode == 1) { planes[p * 65536 + offset] = latch[p]; continue; }
      if (mode == 0 && (gc_regs[1] & (1 << p))) result = gc_regs[0] & (1 << p) ? 255 : 0;
      if (mode == 2) result = value & (1 << p) ? 255 : 0;
      if (mode == 3) {
        result = gc_regs[0] & (1 << p) ? 255 : 0;
        bitmask &= rotated;
      }
      switch ((gc_regs[3] >> 3) & 3) {
      case 1: result &= latch[p]; break;
      case 2: result |= latch[p]; break;
      case 3: result ^= latch[p]; break;
      }
      planes[p * 65536 + offset] = (result & bitmask) | (latch[p] & ~bitmask);
    }
  }
  bool graphics() const { return gc_regs[6] & 1; }
  unsigned text_cols() const { return unsigned(crtc_regs[1]) + 1; }
  unsigned text_rows() const { return std::max(1u, std::min(100u, pixel_height())); }
  unsigned text_width() const { return text_cols() * ((seq_regs[1] & 1) ? 8 : 9); }
  unsigned text_height() const { return text_rows() * ((crtc_regs[9] & 31) + 1); }
  // Snapshot the CRTC text window (including 80x50 installer screens), with
  // the guest's uploaded plane-2 font and attribute/DAC colors. Blink is
  // captured in its visible phase, including the hardware cursor.
  std::vector<u8> text_rgb(const u8 *memory) const {
    unsigned cw = text_width() / text_cols(), ch = text_height() / text_rows();
    unsigned w = text_width(), h = text_height();
    std::vector<u8> image(size_t(w) * h * 3);
    unsigned cursor = (unsigned(crtc_regs[0x0E]) << 8) | crtc_regs[0x0F];
    for (unsigned y = 0; y < h; ++y) for (unsigned x = 0; x < w; ++x) {
      unsigned cell = (start_addr() + (y / ch) * crtc_regs[0x13] * 2 + x / cw) & 0x3FFF;
      u8 code = memory[cell * 2], attr = memory[cell * 2 + 1];
      unsigned map = (attr & 8) ? ((seq_regs[3] >> 2) & 3) | ((seq_regs[3] >> 3) & 4)
                                : (seq_regs[3] & 3) | ((seq_regs[3] >> 2) & 4);
      unsigned font = (map & 3) * 0x4000 + (map >> 2) * 0x2000;
      u8 glyph = planes[2 * 65536 + font + code * 32 + y % ch];
      bool ink = x % cw < 8 ? (glyph & (0x80 >> (x % cw)))
                           : ((attr_regs[0x10] & 4) && code >= 0xC0 && code <= 0xDF && (glyph & 1));
      if (!(crtc_regs[0x0A] & 0x20) && cell == cursor &&
          y % ch >= (crtc_regs[0x0A] & 31) && y % ch <= (crtc_regs[0x0B] & 31)) ink = true;
      unsigned color = ink ? attr & 15 : (attr >> 4) & ((attr_regs[0x10] & 8) ? 7 : 15);
      color = attr_regs[color] & 63;
      if (attr_regs[0x10] & 0x80) color = (color & 15) | ((attr_regs[0x14] & 3) << 4);
      color |= (attr_regs[0x14] & 12) << 4;
      for (unsigned c = 0; c < 3; ++c)
        image[(size_t(y) * w + x) * 3 + c] = (dac_palette[color & dac_mask][c] & 63) * 255 / 63;
    }
    return image;
  }
  unsigned pixel_width() const {
    return std::min(2560u, unsigned(crtc_regs[1] + 1) * ((gc_regs[5] & 0x40) ? 4 : 8));
  }
  unsigned pixel_height() const {
    unsigned lines = crtc_regs[0x12] | ((crtc_regs[7] & 2) << 7) | ((crtc_regs[7] & 0x40) << 3);
    unsigned repeat = (crtc_regs[9] & 31) + 1;
    if (crtc_regs[9] & 0x80) repeat *= 2;
    return std::min(1600u, (lines + 1) / repeat);
  }
  std::vector<u8> graphics_rgb() const {
    if (!graphics()) return {};
    unsigned w = pixel_width(), h = pixel_height();
    std::vector<u8> image(size_t(w) * h * 3);
    for (unsigned y = 0; y < h; ++y) for (unsigned x = 0; x < w; ++x) {
      unsigned offset = (start_addr() + y * crtc_regs[0x13] * 2 +
                         ((gc_regs[5] & 0x40) ? x / 4 : x / 8)) & 0xFFFF;
      unsigned color = 0;
      if (gc_regs[5] & 0x40) color = planes[(x & 3) * 65536 + offset];
      else {
        for (unsigned p = 0; p < 4; ++p)
          color |= ((planes[p * 65536 + offset] >> (7 - (x & 7))) & 1) << p;
        color = attr_regs[color & attr_regs[0x12] & 15] & 63;
        if (attr_regs[0x10] & 0x80) color = (color & 15) | ((attr_regs[0x14] & 3) << 4);
        color |= (attr_regs[0x14] & 12) << 4;
      }
      for (unsigned c = 0; c < 3; ++c)
        image[(size_t(y) * w + x) * 3 + c] = (dac_palette[color & dac_mask][c] & 63) * 255 / 63;
    }
    return image;
  }

  // Retrace counter (for Input Status Register 1)
  u8 isr1_counter = 0;

  VGAText() {
    // 80x25 color text CRTC defaults (16-pixel font, matching SeaVGABIOS)
    crtc_regs[0x01] = 79;    // Horizontal display end (80 cols)
    crtc_regs[0x07] = 2;     // Vertical display end bit 8
    crtc_regs[0x09] = 0x0F;  // Max scan line = 15 (16-pixel font)
    crtc_regs[0x12] = 0x8F;  // Vertical display end = 399
    crtc_regs[0x13] = 40;    // 80 character words per row
    crtc_regs[0x0A] = 13;    // Cursor start scan line
    crtc_regs[0x0B] = 14;    // Cursor end scan line
    // Sequencer defaults for text mode
    seq_regs[1] = 0x00;  // Clocking mode
    seq_regs[2] = 0x03;  // Map mask (planes 0,1)
    seq_regs[4] = 0x02;  // Memory mode (text, odd/even)
    gc_regs[6] = 0x0E;  // B8000 text aperture
    gc_regs[8] = 0xFF;
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
    case 0x3B4: case 0x3D4: return crtc_index;
    case 0x3B5: case 0x3D5: return crtc_regs[crtc_index];
    case 0x3BA: case 0x3DA:
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
    case 0x3B4: case 0x3D4: crtc_index = val; break;
    case 0x3B5: case 0x3D5: crtc_regs[crtc_index] = val; break;
    case 0x3DA: /* Feature Control (write) — ignore */ break;
    default: break;
    }
  }

  bool handles(u16 port) const {
    return (port >= 0x3C0 && port <= 0x3CF) ||
           port == 0x3B4 || port == 0x3B5 || port == 0x3BA ||
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
  u8 get_isr() const { return isr; }
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
        // Mode 0 (one-shot) past its terminal count: the output stays high
        // and the count stays 0 until reprogrammed; no new edge, no new IRQ.
        if (c.count == 0) break;
        if (--c.count == 0) {
          c.output = true;
          if (ch == 0) irq = true;
          // Mode 2 (rate generator) or Mode 3 (square wave): auto-reload
          if (c.mode == 2 || c.mode == 3) {
            c.output = false;
            c.count = c.reload;
            if (c.count == 0) c.count = 65536;
          }
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
  // Pointer to Sail model's A20 register, set during platform init.
  bool *a20_gate = nullptr;

  u8 read(u16 port) {
    if (port == 0x64) {
      // Status register:
      //   bit 0 = output buffer full (data available at port 0x60)
      //   bit 1 = input buffer full (0 = ready for commands)
      //   bit 2 = system flag (POST passed)
      //   bit 3 = command/data (0 = data written to 0x60)
      u8 status = 0x14;  // system flag (bit 2) + keyboard unlocked (bit 4)
      if (!out_buf.empty() || !scancode_buf.empty())
        status |= 0x01;  // output buffer full
      return status;
    }
    if (port == 0x60) {
      // Serve PS/2 command responses first, then actual scancodes.
      if (!out_buf.empty()) {
        u8 val = out_buf.front();
        out_buf.pop();
        return val;
      }
      if (!scancode_buf.empty()) {
        u8 val = scancode_buf.front();
        scancode_buf.pop();
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
      case 0xD0:  // Read output port (reset deasserted, current A20 gate)
        out_buf.push(1 | ((a20_gate && *a20_gate) ? 2 : 0));
        break;
      case 0xD1:  // Write output port (next byte to 0x60)
        last_cmd = 0xD1;
        break;
      case 0xFE:  // Pulse CPU reset line (system reboot)
        reboot_requested = true;
        break;
      case 0xDD:  // Disable A20
        if (a20_gate) *a20_gate = false;
        break;
      case 0xDF:  // Enable A20
        if (a20_gate) *a20_gate = true;
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
        // Write output port — bit 1 = A20 gate
        if (a20_gate)
          *a20_gate = (val & 0x02) != 0;
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

  // Push a scancode byte from the host side (actual keypress).
  void push_scancode(u8 sc) {
    scancode_buf.push(sc);
  }

  // Returns true if the output buffer has data (for IRQ 1).
  // Real i8042 raises IRQ 1 whenever the output buffer is full,
  // whether it's a scancode or a command response.
  bool has_data() const {
    return !out_buf.empty() || !scancode_buf.empty();
  }

  size_t out_buf_size() const { return out_buf.size() + scancode_buf.size(); }

  bool reboot_requested = false;

private:
  std::queue<u8> out_buf;      // PS/2 command responses (ACKs, IDs, etc.)
  std::queue<u8> scancode_buf; // actual key scancodes from host
  u8 last_cmd = 0;          // last command written to port 0x64
  u8 last_kbd_cmd = 0;      // last device command (for two-byte sequences)
  u8 config_byte = 0x45;    // default: keyboard interrupt enabled, translation on
  bool kbd_enabled = true;
};

// =========================================================================
// CMOS/RTC — Real-Time Clock (ports 0x70-0x71)
//
// MC146818-compatible clock, driven by the platform's virtual nanoseconds.
// =========================================================================

class CMOS {
public:
  const u64 *clock = nullptr;
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
    regs[0x10] = 0x00;  // Floppy: none (set by set_floppy() if -fda given)
    regs[0x14] = 0x06;  // Equipment: VGA 80x25, no floppy (bit 0 clear)
    regs[0x15] = 0x80;  // Base memory low (640K)
    regs[0x16] = 0x02;  // Base memory high
    regs[0x32] = 0x20;  // Century (20)
  }

  // Configure floppy drive presence in CMOS.
  void set_floppy(bool present) {
    if (present) {
      regs[0x10] = 0x40;  // Drive A = 1.44MB 3.5", B = none
      regs[0x14] |= 0x01; // Equipment: floppy present
    } else {
      regs[0x10] = 0x00;
      regs[0x14] &= ~0x01;
    }
  }

  // SeaBIOS boot order (CONFIG_QEMU reads it from CMOS 0x3D and 0x38, one
  // nibble per device, first device in the low nibble of 0x3D): 1 floppy,
  // 2 hard disk, 3 CD-ROM.  Up to three of QEMU's letters a, c, d.
  void set_boot_order(const char *order) {
    u8 code[3] = { 0, 0, 0 };
    int n = 0;
    for (const char *p = order; *p && n < 3; p++)
      code[n++] = *p == 'a' ? 1 : *p == 'c' ? 2 : *p == 'd' ? 3 : 0;
    regs[0x3D] = code[0] | (code[1] << 4);
    regs[0x38] = (regs[0x38] & 0x0F) | (code[2] << 4);
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
    update();
    if (port == 0x71) {
      u8 value = regs[index];
      if (index == 0x0A && running() && !(regs[0x0B] & 0x80) &&
          now() % 1000000000 >= 999755859) value |= 0x80; // UIP
      if (index == 0x0C) regs[index] = 0; // reading C acknowledges the IRQ
      return value;
    }
    return 0xFF;
  }

  void write(u16 port, u8 val) {
    update();
    if (port == 0x70)
      index = val & 0x7F;  // Bit 7 is NMI mask
    else if (port == 0x71 && index != 0x0C && index != 0x0D) {
      regs[index] = index == 0x0A ? val & 0x7F : val;
      update_irq();
    }
  }

  bool has_irq() { update(); return regs[0x0C] & 0x80; }

  bool handles(u16 port) const {
    return port == 0x70 || port == 0x71;
  }

private:
  u8 index = 0;
  u8 regs[128];
  u64 last_ticks = 0, last_second = 0;
  u64 now() const { return clock ? *clock : 0; }
  bool running() const { return (regs[0x0A] & 0x70) == 0x20; }
  unsigned number(u8 x) const { return (regs[0x0B] & 4) ? x : (x >> 4) * 10 + (x & 15); }
  u8 encode(unsigned x) const { return (regs[0x0B] & 4) ? x : (x / 10) * 16 + x % 10; }
  void update_irq() {
    regs[0x0C] &= 0x7F;
    if (regs[0x0C] & regs[0x0B] & 0x70) regs[0x0C] |= 0x80;
  }
  void second() {
    unsigned sec = number(regs[0]), min = number(regs[2]);
    unsigned hour = number(regs[4] & 0x7F);
    bool h24 = regs[0x0B] & 2;
    if (!h24) hour = hour % 12 + ((regs[4] & 0x80) ? 12 : 0);
    if (++sec >= 60) {
      sec = 0;
      if (++min >= 60) {
        min = 0;
        if (++hour >= 24) {
          hour = 0;
          regs[6] = encode(number(regs[6]) % 7 + 1);
          unsigned day = number(regs[7]), month = number(regs[8]);
          unsigned year = number(regs[9]) + 100 * number(regs[0x32]);
          static const u8 days[] = {31,28,31,30,31,30,31,31,30,31,30,31};
          unsigned limit = days[(month >= 1 && month <= 12) ? month - 1 : 0];
          if (month == 2 && year % 4 == 0 && (year % 100 || year % 400 == 0)) ++limit;
          if (++day > limit) {
            day = 1;
            if (++month > 12) { month = 1; ++year; }
          }
          regs[7] = encode(day); regs[8] = encode(month);
          regs[9] = encode(year % 100); regs[0x32] = encode(year / 100);
        }
      }
    }
    regs[0] = encode(sec); regs[2] = encode(min);
    regs[4] = h24 ? encode(hour) : encode(hour % 12 ? hour % 12 : 12) | (hour >= 12 ? 0x80 : 0);
    regs[0x0C] |= 0x10; // update-ended flag
    bool alarm = true;
    for (unsigned i : {0u, 2u, 4u})
      alarm &= (regs[i + 1] & 0xC0) == 0xC0 || regs[i + 1] == regs[i];
    if (alarm) regs[0x0C] |= 0x20;
  }
  void update() {
    u64 ns = now(), sec = ns / 1000000000;
    u64 ticks = sec * 32768 + (ns % 1000000000) * 32768 / 1000000000;
    if (running()) {
      unsigned rate = regs[0x0A] & 15;
      if (rate) {
        unsigned shift = rate <= 2 ? rate + 6 : rate - 1;
        if ((ticks >> shift) != (last_ticks >> shift)) regs[0x0C] |= 0x40;
      }
      if (!(regs[0x0B] & 0x80) && sec >= last_second)
        for (u64 s = last_second; s < sec; ++s) second();
    }
    last_ticks = ticks; last_second = sec;
    update_irq();
  }
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

    // Device 0:1.0 — PIIX3 ISA bridge; the multifunction bit is essential
    // for firmware to discover IDE at function 1 and ACPI PM at function 3.
    memset(dev1isa, 0, sizeof(dev1isa));
    dev1isa[0] = 0x86; dev1isa[1] = 0x80;
    dev1isa[2] = 0x00; dev1isa[3] = 0x70;
    dev1isa[4] = 7;
    dev1isa[0x0A] = 1; dev1isa[0x0B] = 6;
    dev1isa[0x0E] = 0x80;
    for (int i = 0x60; i <= 0x63; ++i) dev1isa[i] = 0x80; // PIRQ disabled

    // Device 0:1.1 — PIIX3 IDE Controller (ISA-compatible mode)
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
    dev1[0x20] = 0x01;                      // BMIBA: 16-byte I/O BAR, unassigned
    // IDETIM (0x40-0x43): IDE decode enable for both channels.  A BIOS
    // sets these; Linux's ata_piix skips a channel whose bit is clear
    // without a word.
    dev1[0x41] = 0x80;                      // primary channel enabled
    dev1[0x43] = 0x80;                      // secondary channel enabled

    // Device 0:2.0 — Simple VGA controller (for option ROM discovery)
    // SeaBIOS scans PCI for VGA devices (class 0x0300) to load VGA BIOS.
    // The ROM BAR (0x30) points to the ROM at C0000.
    memset(dev2, 0, sizeof(dev2));
    dev2[0x00] = 0x34; dev2[0x01] = 0x12;  // Vendor: 0x1234 (Bochs/QEMU VGA)
    dev2[0x02] = 0x11; dev2[0x03] = 0x11;  // Device: 0x1111
    dev2[0x04] = 0x03;                      // Command: I/O + mem
    dev2[0x08] = 0x00;                      // Revision
    dev2[0x0A] = 0x00;                      // Subclass: VGA compatible
    dev2[0x0B] = 0x03;                      // Class: display controller
    dev2[0x0E] = 0x00;                      // Header type 0
    // BAR0: 16 MB prefetchable Bochs VBE linear framebuffer.
    dev2[0x10] = 0x08; dev2[0x13] = 0xE0;
    // ROM BAR (0x30): point to 0xFEB00000 (in PCI memory space above RAM).
    // The emulator stores a copy of vgabios.bin there so SeaBIOS can read it
    // independently from the shadow RAM at C0000 (which SeaBIOS clears first).
    // Bit 0 = enable.
    dev2[0x30] = 0x01; dev2[0x31] = 0x00; dev2[0x32] = 0xB0; dev2[0x33] = 0xFE;

    // Device 0:1.3 — PIIX4 ACPI/Power Management (for SMM support)
    // SeaBIOS's smm_setup() looks for PCI_DEVICE_ID_INTEL_82371AB_3
    // (0x7113) to enable SMM via the APMC register.
    memset(dev1f3, 0, sizeof(dev1f3));
    dev1f3[0x00] = 0x86; dev1f3[0x01] = 0x80;  // Vendor: Intel (0x8086)
    dev1f3[0x02] = 0x13; dev1f3[0x03] = 0x71;  // Device: PIIX4 ACPI (0x7113)
    dev1f3[0x04] = 0x01;                        // Command: I/O space enabled
    dev1f3[0x08] = 0x03;                        // Revision
    dev1f3[0x0A] = 0x80;                        // Subclass: other
    dev1f3[0x0B] = 0x06;                        // Class: bridge
    dev1f3[0x0E] = 0x00;                        // Header type 0
    // PIIX_DEVACTB at offset 0x58: APMC_EN bit not set initially
    dev1f3[0x58] = 0x00; dev1f3[0x59] = 0x00;
    dev1f3[0x5A] = 0x00; dev1f3[0x5B] = 0x00;
    // PM I/O base at offset 0x40 (PMBA): we use 0xB000
    dev1f3[0x40] = 0x01; dev1f3[0x41] = 0xB0;  // 0xB001 (bit 0 = I/O space)
  }

  void write_addr(u32 val) { addr = val; }
  u32 read_addr() const { return addr; }
  u16 pm_base() const {
    return (u16(dev1f3[0x41]) << 8 | dev1f3[0x40]) & 0xFFC0;
  }
  bool vga_memory_enabled() const { return dev2[4] & 2; }
  bool smram_open() const { return (dev0[0x72] & 0x48) == 0x48; }
  bool apmc_smi_enabled() const { return dev1f3[0x5B] & 2; }

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
      memcpy(&cfg[reg], &val, 4);
    } else if (cfg == dev0 && reg == 0x70) {
      // I440FX_SMRAM register (0x72) and neighboring regs
      memcpy(&cfg[reg], &val, 4);
    } else if (cfg == dev1isa && reg >= 0x40) {
      memcpy(&cfg[reg], &val, 4);
    } else if (cfg == dev1 && reg == 0x20) {
      // Intel 82371SB datasheet section 2.3.9: only bits 15:4 are
      // writable; bit 0 identifies I/O space. Firmware sizes/assigns it.
      u32 bar = (val & 0xFFF0) | 1;
      memcpy(&cfg[reg], &bar, 4);
    } else if (cfg == dev1 && (reg == 4 || reg >= 0x40)) {
      memcpy(&cfg[reg], &val, 4);
    } else if (cfg == dev1f3 && (reg == 4 || reg >= 0x40)) {
      // PIIX4 ACPI: allow writes to DEVACTB (0x58), PMBA (0x40), etc.
      memcpy(&cfg[reg], &val, 4);
    } else if (cfg == dev2 && reg >= 0x10 && reg < 0x28) {
      u32 bar = 0;
      if (reg == 0x10) {
        bar = (val & 0xFF000000) | 8;
        if (val != 0xFFFFFFFF) vga_lfb_addr = val & 0xFF000000;
      }
      memcpy(&cfg[reg], &bar, 4);
    } else if (cfg == dev2 && reg == 0x30) {
      // Address bits below the ROM size are hardwired zero, including when
      // SeaBIOS probes with FFFFF800 rather than FFFFFFFF.
      u32 aligned = 0x800;
      while (aligned < vga_rom_size) aligned <<= 1;
      u32 bar = val & (~(aligned - 1) | 1);
      memcpy(&cfg[reg], &bar, 4);
      if ((val & 0xFFFFF800) != 0xFFFFF800)
        vga_rom_bar_addr = bar & ~1u;
    } else if (cfg == dev2) {
      // VGA: allow other config writes (command, etc.)
      memcpy(&cfg[reg], &val, 4);
    }
    // Absorb other writes silently
  }

private:
  const u8 *get_config(int dev, int func) const {
    if (dev == 0 && func == 0) return dev0;
    if (dev == 1 && func == 0) return dev1isa;
    if (dev == 1 && func == 1) return dev1;
    if (dev == 1 && func == 3) return dev1f3;
    if (dev == 2 && func == 0) return dev2;
    return nullptr;
  }
  u8 *get_config_mut(int dev, int func) {
    if (dev == 0 && func == 0) return dev0;
    if (dev == 1 && func == 0) return dev1isa;
    if (dev == 1 && func == 1) return dev1;
    if (dev == 1 && func == 3) return dev1f3;
    if (dev == 2 && func == 0) return dev2;
    return nullptr;
  }

  u32 addr = 0;
  u8 dev0[256];    // 0:0.0 — i440FX host bridge
  u8 dev1isa[256]; // 0:1.0 — PIIX3 ISA bridge
  u8 dev1[256];    // 0:1.1 — PIIX3 IDE controller
  u8 dev2[256];    // 0:2.0 — VGA controller (for option ROM)
  u8 dev1f3[256];  // 0:1.3 — PIIX4 ACPI/PM (for SMM)
public:
  u16 ide_bus_master_base() const {
    return (u16)(dev1[0x20] | (dev1[0x21] << 8)) & 0xFFF0;
  }
  bool ide_bus_master_handles(u16 port) const {
    u16 base = ide_bus_master_base();
    return (dev1[4] & 1) && base != 0 && port >= base && port - base < 16;
  }
  u32 vga_lfb_addr = 0xE0000000;
  u32 vga_rom_bar_addr = 0xFEB00000;  // Current ROM BAR address (updated on PCI write)
  u32 vga_rom_size = 0;               // Actual VGA ROM size (for BAR sizing)
};

// =========================================================================
// QEMU fw_cfg Device — Firmware Configuration Interface
//
// Provides configuration data to SeaBIOS via ports 0x510 (selector) and
// 0x511 (data).  SeaBIOS reads the signature, ID, E820 table, and file
// directory to detect QEMU and discover guest RAM layout.
// =========================================================================

class FwCfg {
public:
  FwCfg() { rebuild_directory(); }

  void set_vga_rom(const u8 *data, size_t len) {
    vga_rom.assign(data, data + len);
    rebuild_directory();
  }

  void rebuild_directory() {
    memset(filedir_buf, 0, sizeof(filedir_buf));
    unsigned count = vga_rom.empty() ? 1 : 2;
    filedir_buf[3] = count;
    auto entry = [&](unsigned i, u32 sz, u16 selector, const char *name) {
      u8 *f = filedir_buf + 4 + i * 64;
      f[0] = sz >> 24; f[1] = sz >> 16; f[2] = sz >> 8; f[3] = sz;
      f[4] = selector >> 8; f[5] = selector;
      strncpy((char *)f + 8, name, 55);
    };
    entry(0, 1, 0x22, "etc/irq0-override");
    if (!vga_rom.empty()) entry(1, vga_rom.size(), 0x21, "vgaroms/vgabios.bin");
    filedir_len = 4 + count * 64;
  }

  void set_ram_size(u64 bytes) {
    ram_size = bytes;
    // Build E820 table: one RAM entry (addr=0, size=ram_size, type=1)
    // Entry format: u64 addr, u64 size, u32 type = 20 bytes
    memset(e820_buf, 0, sizeof(e820_buf));
    u64 addr = 0;
    u64 size = ram_size;
    u32 type = 1;  // RAM
    memcpy(e820_buf + 0, &addr, 8);
    memcpy(e820_buf + 8, &size, 8);
    memcpy(e820_buf + 16, &type, 4);
    e820_len = 20;
  }

  // Port 0x510 write: set selector, reset data offset
  void write(u16 port, u16 val) {
    if (port == 0x510) {
      selector = val;
      offset = 0;
    }
  }

  // Port 0x511 read: return next byte from selected entry
  u8 read(u16 port) {
    if (port != 0x511) return 0xFF;

    const u8 *data = nullptr;
    u32 len = 0;

    switch (selector) {
    case 0x00:  // QEMU_CFG_SIGNATURE: "QEMU"
      data = reinterpret_cast<const u8 *>("QEMU");
      len = 4;
      break;
    case 0x01:  // QEMU_CFG_ID: traditional interface
      data = id_buf;
      len = 4;
      break;
    case 0x05:  // QEMU_CFG_NB_CPUS: one BSP, no APs
    case 0x0F:  // QEMU_CFG_MAX_CPUS
    case 0x22:  // etc/irq0-override: ISA IRQ0 is wired to IOAPIC input 2
      return offset++ == 0 ? 1 : 0;
    case 0x19:  // QEMU_CFG_FILE_DIR
      data = filedir_buf;
      len = filedir_len;
      break;
    case 0x8003:  // QEMU_CFG_E820_TABLE (ARCH_LOCAL + 3)
      data = e820_buf;
      len = e820_len;
      break;
    case 0x21:  // First user file (vgaroms/vgabios.bin)
      if (!vga_rom.empty()) {
        data = vga_rom.data();
        len = (u32)vga_rom.size();
      }
      break;
    default:
      return 0x00;
    }

    if (offset < len)
      return data[offset++];
    return 0x00;
  }

  bool handles_read(u16 port) const { return port == 0x511; }
  bool handles_write(u16 port) const { return port == 0x510; }

private:
  u16 selector = 0;
  u32 offset = 0;
  u64 ram_size = 0;

  // QEMU_CFG_ID = 0x00000001 (little-endian)
  u8 id_buf[4] = { 0x01, 0x00, 0x00, 0x00 };

  // E820 table buffer (one entry = 20 bytes max)
  u8 e820_buf[20] = {};
  u32 e820_len = 0;

  // File directory buffer (header + file entries)
  u8 filedir_buf[132] = {};
  u32 filedir_len = 4;  // default: just u32 count=0

  // VGA ROM file data (loaded via set_vga_rom)
  std::vector<u8> vga_rom;
};

// =========================================================================
// IDE devices — PIO ATA hard disk or ATAPI CD-ROM
//
// The primary channel is at 0x1F0-0x1F7/0x3F6 (IRQ 14), the secondary at
// 0x170-0x177/0x376 (IRQ 15). Each channel can have a master and a slave.
// An absent device reads as zero so drive probes skip it.
//
// Hard disk: READ/WRITE SECTORS, IDENTIFY DEVICE, INITIALIZE DEVICE
// PARAMETERS, SET FEATURES, FLUSH CACHE.  CD-ROM: IDENTIFY PACKET DEVICE,
// DEVICE RESET and PACKET with the SCSI/MMC commands a BIOS or an OS needs
// to boot from and mount a disc: TEST UNIT READY, REQUEST SENSE, INQUIRY,
// READ CAPACITY, READ(10)/(12), READ TOC, MODE SENSE(10), GET
// CONFIGURATION, START STOP UNIT, PREVENT/ALLOW MEDIUM REMOVAL.
//
// All data moves through the 16-bit data port.  A transfer is a byte
// buffer split into DRQ blocks: 512 bytes for ATA, and for ATAPI at most
// the byte count the host wrote before PACKET.  The device interrupts once
// per data-in block (ATA and ATAPI), once per completed data-out block, and
// once more at the end of every ATAPI command; the host's status read
// clears the interrupt.
// =========================================================================

// SAIL_X86_IDE_TRACE in the environment logs every command and packet with
// its outcome to stderr.
inline bool ide_trace = getenv("SAIL_X86_IDE_TRACE") != nullptr;

class IDEDevice {
public:
  enum Kind { NONE, DISK, CDROM };

  IDEDevice(u16 base, u16 ctrl, bool slave) : base(base), ctrl(ctrl), slave(slave) {}
  ~IDEDevice() {
    if (fd >= 0) close(fd);
  }

  bool open_disk(const char *path) { return open_image(path, DISK, 512, O_RDWR); }
  bool open_cdrom(const char *path) { return open_image(path, CDROM, 2048, O_RDONLY); }
  bool is_open() const { return fd >= 0; }
  Kind kind() const { return dev; }

  bool handles(u16 port) const {
    return (base <= port && port <= base + 7) || port == ctrl;
  }
  bool is_data_port(u16 port) const { return port == base; }

  u8 read(u16 port) {
    if (dev == NONE || slave_selected()) return 0x00;
    if (port == ctrl) return status;  // alternate status: no IRQ clear
    switch (port - base) {
    case 0: return 0x00;          // data port is 16-bit; see read16
    case 1: return error;
    case 2: return sector_count;  // ATAPI: interrupt reason
    case 3: return lba_low;
    case 4: return lba_mid;       // ATAPI: byte count low
    case 5: return lba_high;      // ATAPI: byte count high
    case 6: return drive_head;
    case 7:                       // status: clears the interrupt
      irq_pending = false;
      irq_asserted = false;
      return status;
    }
    return 0x00;
  }

  void write(u16 port, u8 val) {
    if (port == ctrl) {
      nien = (val & 0x02) != 0;
      if (nien) irq_asserted = false;
      if (val & 0x04) reset_device();  // SRST
      return;
    }
    switch (port - base) {
    case 1: features = val; break;
    case 2: sector_count = val; break;
    case 3: lba_low = val; break;
    case 4: lba_mid = val; break;
    case 5: lba_high = val; break;
    case 6: drive_head = val; break;
    case 7:
      if (dev != NONE && !slave_selected()) execute(val);
      break;
    }
  }

  // 16-bit data port read (also used for the halves of a 32-bit read)
  u16 read16() {
    if (xfer != XFER_IN || dev == NONE || slave_selected()) return 0x0000;
    u16 v = buf[buf_pos];
    if (buf_pos + 1 < block_end) v |= (u16)buf[buf_pos + 1] << 8;
    buf_pos = std::min(buf_pos + 2, block_end);
    if (buf_pos >= block_end) {
      if (buf_pos < buf.size()) {
        begin_in_block();
      } else {
        xfer = XFER_NONE;
        status = 0x40;  // DRDY
        if (packet) {
          sector_count = 0x03;  // I/O | C/D: command complete
          raise_irq();
        }
      }
    }
    return v;
  }

  // 16-bit data port write
  void write16(u16 val) {
    if (dev == NONE || slave_selected()) return;
    if (xfer == XFER_CDB) {
      cdb[cdb_pos++] = val & 0xFF;
      cdb[cdb_pos++] = val >> 8;
      if (cdb_pos >= 12) {
        xfer = XFER_NONE;
        execute_packet();
      }
      return;
    }
    if (xfer != XFER_OUT) return;
    buf[buf_pos++] = val & 0xFF;
    buf[buf_pos++] = val >> 8;
    if (buf_pos >= block_end) {
      // One sector received: write it and either expect the next or finish.
      u64 offset = (u64)current_lba * 512;
      if (offset + 512 <= image_size)
        (void)!pwrite(fd, &buf[block_end - 512], 512, offset);
      current_lba++;
      if (buf_pos < buf.size()) {
        block_end = buf_pos + 512;
        status = 0x48;  // DRDY | DRQ
      } else {
        xfer = XFER_NONE;
        status = 0x40;  // DRDY
      }
      raise_irq();
    }
  }

  // Set when the device asserts INTRQ; the platform delivers it to the PIC
  // once (edge) and clears it.
  bool irq_pending = false;
  bool irq_asserted = false;

private:
  enum Xfer { XFER_NONE, XFER_IN, XFER_OUT, XFER_CDB };

  u16 base, ctrl;
  Kind dev = NONE;
  int fd = -1;
  u64 image_size = 0;
  u32 sector_size = 512;

  // Task-file registers
  u8 error = 0;
  u8 features = 0;
  u8 sector_count = 0;
  u8 lba_low = 0;
  u8 lba_mid = 0;
  u8 lba_high = 0;
  u8 drive_head = 0;
  u8 status = 0;
  bool nien = false;

  // Transfer state
  Xfer xfer = XFER_NONE;
  std::vector<u8> buf;    // the whole transfer
  size_t buf_pos = 0;     // next byte to move
  size_t block_end = 0;   // end of the current DRQ block
  size_t block_limit = 512;
  u32 current_lba = 0;    // next sector of a data-out transfer

  // ATAPI state
  u8 cdb[12] = {};
  int cdb_pos = 0;
  u8 sense_key = 0, asc = 0, ascq = 0;
  bool medium_locked = false;
  bool packet = false;  // the current transfer belongs to a PACKET command

  bool slave;
  bool slave_selected() const { return ((drive_head & 0x10) != 0) != slave; }

  bool open_image(const char *path, Kind k, u32 ssize, int flags) {
    fd = ::open(path, flags);
    if (fd < 0 && flags == O_RDWR) fd = ::open(path, O_RDONLY);
    if (fd < 0) { perror(path); return false; }
    struct stat st;
    if (fstat(fd, &st) < 0) { perror("fstat"); close(fd); fd = -1; return false; }
    image_size = st.st_size;
    sector_size = ssize;
    dev = k;
    reset_device();
    return true;
  }

  u64 total_sectors() const { return (image_size + sector_size - 1) / sector_size; }

  void raise_irq() {
    if (!nien) irq_pending = irq_asserted = true;
  }

  // Leave the signature that tells the host what kind of device this is:
  // ATA 01 01 00 00, ATAPI 01 01 14 EB (sector count, LBA low, mid, high).
  void set_signature() {
    sector_count = 0x01;
    lba_low = 0x01;
    lba_mid = dev == CDROM ? 0x14 : 0x00;
    lba_high = dev == CDROM ? 0xEB : 0x00;
    drive_head = 0x00;
  }

  void reset_device() {
    xfer = XFER_NONE;
    buf.clear();
    buf_pos = block_end = 0;
    cdb_pos = 0;
    irq_pending = false;
    irq_asserted = false;
    error = 0x01;  // diagnostics passed
    status = dev == NONE ? 0x00 : 0x40;
    set_signature();
    sense_key = asc = ascq = 0;
  }

  void abort_command() {
    xfer = XFER_NONE;
    status = 0x41;  // DRDY | ERR
    error = 0x04;   // ABRT
    raise_irq();
  }

  void complete_ok() {
    xfer = XFER_NONE;
    status = 0x40;  // DRDY
    raise_irq();
  }

  // Data-in: the host reads `buf`, block by block.
  void begin_data_in(size_t limit) {
    block_limit = limit;
    buf_pos = 0;
    xfer = XFER_IN;
    begin_in_block();
  }

  void begin_in_block() {
    size_t n = std::min(buf.size() - buf_pos, block_limit);
    if (ide_trace) fprintf(stderr, "ide%d: data-in block %zu of %zu bytes\n", base == 0x1F0 ? 0 : 1, n, buf.size());
    block_end = buf_pos + n;
    if (packet) {
      lba_mid = n & 0xFF;
      lba_high = (n >> 8) & 0xFF;
      sector_count = 0x02;  // I/O: data for the host
    }
    status = 0x48;  // DRDY | DRQ
    raise_irq();
  }

  u32 get_lba() const {
    if (drive_head & 0x40)
      return lba_low | (lba_mid << 8) | (lba_high << 16) | ((drive_head & 0x0F) << 24);
    // CHS with the geometry reported by IDENTIFY: 16 heads, 63 sectors
    u16 cyl = (lba_high << 8) | lba_mid;
    return (cyl * 16 + (drive_head & 0x0F)) * 63 + (lba_low - 1);
  }

  void execute(u8 cmd) {
    if (ide_trace)
      fprintf(stderr, "ide%d: cmd %02x feat=%02x count=%02x lba=%02x%02x%02x dh=%02x nien=%d\n",
              base == 0x1F0 ? 0 : 1, cmd, features, sector_count, lba_high, lba_mid, lba_low,
              drive_head, nien);
    error = 0;
    packet = false;
    switch (cmd) {
    case 0x08:  // DEVICE RESET (ATAPI)
      if (dev != CDROM) { abort_command(); break; }
      reset_device();  // no interrupt
      break;
    case 0x90:  // EXECUTE DEVICE DIAGNOSTIC
      xfer = XFER_NONE;
      set_signature();
      error = 0x01;
      status = 0x40;
      raise_irq();
      break;
    case 0x20: case 0x21: {  // READ SECTORS
      if (dev != DISK) { abort_command(); break; }
      u32 lba = get_lba();
      int n = sector_count ? sector_count : 256;
      buf.assign((size_t)n * 512, 0);
      u64 offset = (u64)lba * 512;
      if (offset < image_size)
        (void)!pread(fd, buf.data(), std::min<u64>(buf.size(), image_size - offset), offset);
      begin_data_in(512);
      break;
    }
    case 0x30: case 0x31: {  // WRITE SECTORS
      if (dev != DISK) { abort_command(); break; }
      current_lba = get_lba();
      int n = sector_count ? sector_count : 256;
      buf.assign((size_t)n * 512, 0);
      buf_pos = 0;
      block_end = 512;
      xfer = XFER_OUT;
      status = 0x48;  // DRDY | DRQ, no interrupt for the first block
      break;
    }
    case 0x91:  // INITIALIZE DEVICE PARAMETERS
    case 0xE7:  // FLUSH CACHE
    case 0xEA:  // FLUSH CACHE EXT
    case 0xEF:  // SET FEATURES
      complete_ok();
      break;
    case 0xE5:  // CHECK POWER MODE
      sector_count = 0xFF;  // active
      complete_ok();
      break;
    case 0xEC:  // IDENTIFY DEVICE
      if (dev != DISK) { set_signature(); abort_command(); break; }
      identify_disk();
      begin_data_in(512);
      break;
    case 0xA1:  // IDENTIFY PACKET DEVICE
      if (dev != CDROM) { abort_command(); break; }
      identify_cdrom();
      begin_data_in(512);
      break;
    case 0xA0: {  // PACKET
      if (dev != CDROM) { abort_command(); break; }
      // Byte count limit for the DRQ blocks of the reply; 0 and 0xFFFF
      // mean the maximum, and blocks are even-sized.
      size_t limit = lba_mid | (lba_high << 8);
      if (limit == 0 || limit == 0xFFFF) limit = 0xFFFE;
      block_limit = limit & ~(size_t)1;
      cdb_pos = 0;
      packet = true;
      xfer = XFER_CDB;
      sector_count = 0x01;  // C/D: expecting the command packet
      status = 0x48;        // DRDY | DRQ, no interrupt (device-paced DRQ)
      break;
    }
    default:
      abort_command();
      break;
    }
  }

  static void put_string(u16 *id, int word, const char *s, int words) {
    for (int i = 0; i < words; i++) {
      u8 a = *s ? *s++ : ' ';
      u8 b = *s ? *s++ : ' ';
      id[word + i] = (a << 8) | b;
    }
  }

  void identify_disk() {
    buf.assign(512, 0);
    u16 *id = reinterpret_cast<u16 *>(buf.data());
    u32 sectors = image_size / 512;
    id[0] = 0x0040;  // fixed disk
    id[1] = std::min<u32>(sectors / (16 * 63), 16383);  // cylinders
    id[3] = 16;      // heads
    id[6] = 63;      // sectors per track
    put_string(id, 10, "SAIL0001", 10);
    put_string(id, 23, "1.0", 4);
    put_string(id, 27, "Sail-x86 Virtual Disk", 20);
    id[47] = 0x8001;  // one sector per READ/WRITE MULTIPLE
    id[49] = 0x0200;  // LBA
    id[51] = 0x0200;  // PIO timing mode
    id[53] = 0x0007;  // words 54-58, 64-70, 88 valid
    id[54] = id[1];
    id[55] = 16;
    id[56] = 63;
    u32 cur = (u32)id[54] * 16 * 63;
    id[57] = cur & 0xFFFF;
    id[58] = cur >> 16;
    id[60] = sectors & 0xFFFF;
    id[61] = sectors >> 16;
    id[64] = 0x0003;  // PIO modes 3 and 4
    id[80] = 0x007E;  // ATA-1..6
  }

  void identify_cdrom() {
    buf.assign(512, 0);
    u16 *id = reinterpret_cast<u16 *>(buf.data());
    // ATAPI device, CD-ROM, removable, DRQ within 50 us of PACKET (no
    // interrupt before the command packet), 12-byte packets
    id[0] = (2 << 14) | (5 << 8) | (1 << 7) | (2 << 5);
    put_string(id, 10, "SAILCD01", 10);
    id[20] = 3;    // buffer type
    id[21] = 512;  // buffer size in sectors
    id[22] = 4;    // ECC bytes
    put_string(id, 23, "1.0", 4);
    put_string(id, 27, "Sail-x86 CD-ROM", 20);
    id[49] = 0x0200;  // LBA, no DMA
    id[53] = 0x0003;  // words 54-58 and 64-70 valid
    id[64] = 0x0003;  // PIO modes 3 and 4
    id[65] = 0x00B4;
    id[66] = 0x00B4;
    id[67] = 0x012C;  // minimum PIO cycle time without flow control
    id[68] = 0x00B4;  // minimum PIO cycle time with IORDY
    id[71] = 30;      // PACKET to bus release, ns
    id[72] = 30;      // SERVICE to BSY clear, ns
    id[80] = 0x007E;  // ATA/ATAPI-1..6
    id[82] = 0x0210;  // DEVICE RESET, PACKET
    id[83] = 0x4000;
    id[84] = 0x4000;
    id[85] = 0x0210;
    id[87] = 0x4000;
  }

  // ----- ATAPI packet commands -----

  static u16 be16(const u8 *p) { return (p[0] << 8) | p[1]; }
  static u32 be32(const u8 *p) { return ((u32)p[0] << 24) | (p[1] << 16) | (p[2] << 8) | p[3]; }
  static void put_be16(u8 *p, u16 v) { p[0] = v >> 8; p[1] = v; }
  static void put_be32(u8 *p, u32 v) { p[0] = v >> 24; p[1] = v >> 16; p[2] = v >> 8; p[3] = v; }
  static void put_msf(u8 *p, u32 lba) {
    u32 x = lba + 150;
    p[0] = 0;
    p[1] = x / (60 * 75);
    p[2] = (x / 75) % 60;
    p[3] = x % 75;
  }

  void packet_ok() {
    xfer = XFER_NONE;
    status = 0x40;        // DRDY
    sector_count = 0x03;  // I/O | C/D
    raise_irq();
  }

  void check_condition(u8 key, u8 a, u8 q) {
    if (ide_trace) fprintf(stderr, "ide%d: check condition %x/%02x/%02x\n", base == 0x1F0 ? 0 : 1, key, a, q);
    sense_key = key; asc = a; ascq = q;
    xfer = XFER_NONE;
    status = 0x41;        // DRDY | ERR
    error = key << 4;
    sector_count = 0x03;  // I/O | C/D
    raise_irq();
  }

  // Reply with `len` bytes of `buf`, or fewer if the host asked for less.
  void packet_reply(size_t len, size_t alloc) {
    len = std::min(len, alloc);
    if (len == 0) { packet_ok(); return; }
    buf.resize(len);
    begin_data_in(block_limit);
  }

  void execute_packet() {
    const u8 *c = cdb;
    if (ide_trace) {
      fprintf(stderr, "ide%d: packet", base == 0x1F0 ? 0 : 1);
      for (int i = 0; i < 12; i++) fprintf(stderr, " %02x", c[i]);
      fprintf(stderr, " limit=%zu\n", block_limit);
    }
    switch (c[0]) {
    case 0x00:  // TEST UNIT READY
    case 0x1B:  // START STOP UNIT
      packet_ok();
      break;
    case 0x1E:  // PREVENT ALLOW MEDIUM REMOVAL
      medium_locked = (c[4] & 0x01) != 0;
      packet_ok();
      break;
    case 0x03: {  // REQUEST SENSE
      buf.assign(18, 0);
      buf[0] = 0x70;  // current error, fixed format
      buf[2] = sense_key;
      buf[7] = 10;    // additional sense length
      buf[12] = asc;
      buf[13] = ascq;
      sense_key = asc = ascq = 0;
      packet_reply(18, c[4]);
      break;
    }
    case 0x12: {  // INQUIRY
      if (c[1] & 0x01) { check_condition(5, 0x24, 0x00); break; }  // no VPD pages
      buf.assign(36, 0);
      buf[0] = 0x05;  // CD-ROM
      buf[1] = 0x80;  // removable
      buf[2] = 0x00;  // ATAPI: no ANSI version claimed
      buf[3] = 0x21;  // ATAPI, response data format 1
      buf[4] = 31;    // additional length
      memcpy(&buf[8], "SAIL    ", 8);
      memcpy(&buf[16], "Sail-x86 CD-ROM ", 16);
      memcpy(&buf[32], "1.0 ", 4);
      packet_reply(36, be16(c + 3));
      break;
    }
    case 0x25: {  // READ CAPACITY
      buf.assign(8, 0);
      put_be32(&buf[0], (u32)total_sectors() - 1);
      put_be32(&buf[4], 2048);
      packet_reply(8, 8);
      break;
    }
    case 0x28:    // READ(10)
    case 0xA8: {  // READ(12)
      u32 lba = be32(c + 2);
      u32 n = c[0] == 0x28 ? be16(c + 7) : be32(c + 6);
      if (n == 0) { packet_ok(); break; }
      if ((u64)lba + n > total_sectors()) { check_condition(5, 0x21, 0x00); break; }
      buf.assign((size_t)n * 2048, 0);
      (void)!pread(fd, buf.data(), std::min<u64>(buf.size(), image_size - (u64)lba * 2048), (u64)lba * 2048);
      begin_data_in(block_limit);
      break;
    }
    case 0x43: {  // READ TOC: one data track, formats 0 (TOC) and 1 (session)
      bool msf = (c[1] & 0x02) != 0;
      u8 format = c[2] & 0x0F;
      if (format == 0) format = c[9] >> 6;
      u8 start = c[6];
      size_t alloc = be16(c + 7);
      buf.assign(4, 0);
      auto descriptor = [&](u8 track, u32 lba) {
        u8 d[8] = { 0, 0x14, track, 0, 0, 0, 0, 0 };  // ADR 1, data track
        if (msf) put_msf(&d[4], lba); else put_be32(&d[4], lba);
        buf.insert(buf.end(), d, d + 8);
      };
      if (format == 0) {
        if (start > 1 && start != 0xAA) { check_condition(5, 0x24, 0x00); break; }
        buf[2] = 1;  // first track
        buf[3] = 1;  // last track
        if (start <= 1) descriptor(1, 0);
        descriptor(0xAA, (u32)total_sectors());  // lead-out
      } else if (format == 1) {
        buf[2] = 1;  // first session
        buf[3] = 1;  // last session
        descriptor(1, 0);
      } else {
        check_condition(5, 0x24, 0x00);
        break;
      }
      put_be16(&buf[0], buf.size() - 2);
      packet_reply(buf.size(), alloc);
      break;
    }
    case 0x5A: {  // MODE SENSE(10): only the CD capabilities page (2Ah)
      u8 page = c[2] & 0x3F;
      if (page != 0x2A && page != 0x3F) { check_condition(5, 0x24, 0x00); break; }
      buf.assign(8 + 20, 0);
      put_be16(&buf[0], buf.size() - 2);
      buf[8] = 0x2A;
      buf[9] = 18;                      // page length
      buf[12] = 0x70;                   // multi-session, mode 2 form 1 and 2
      buf[14] = (1 << 5) | 0x08 | (medium_locked ? 0x02 : 0) | 0x01;  // tray, eject, lock
      put_be16(&buf[16], 706);          // maximum read speed, kB/s (4x)
      put_be16(&buf[18], 2);            // volume levels
      put_be16(&buf[20], 512);          // buffer size, kB
      put_be16(&buf[22], 706);          // current read speed
      packet_reply(buf.size(), be16(c + 7));
      break;
    }
    case 0x46: {  // GET CONFIGURATION: current profile CD-ROM, profile list
      u16 start = be16(c + 2);
      buf.assign(8, 0);
      put_be16(&buf[6], 0x0008);  // current profile: CD-ROM
      if (start == 0) {
        u8 f[8] = { 0x00, 0x00, 0x03, 4, 0x00, 0x08, 0x01, 0x00 };  // profile list: CD-ROM, current
        buf.insert(buf.end(), f, f + 8);
      }
      put_be32(&buf[0], buf.size() - 4);
      packet_reply(buf.size(), be16(c + 7));
      break;
    }
    default:  // MODE SENSE(6), GET EVENT STATUS NOTIFICATION, READ CD, ...
      check_condition(5, 0x20, 0x00);  // ILLEGAL REQUEST, invalid command operation code
      break;
    }
  }
};
// A channel shares task-file writes and device control between both devices;
// only the selected device executes commands or drives the data/status bus.
class IDEChannel {
public:
  using Kind = IDEDevice::Kind;
  static constexpr Kind NONE = IDEDevice::NONE, DISK = IDEDevice::DISK, CDROM = IDEDevice::CDROM;
  IDEChannel(u16 base, u16 ctrl) : master(base, ctrl, false), slave(base, ctrl, true), base(base) {}
  bool open_disk(const char *path) { return master.open_disk(path); }
  bool open_slave_disk(const char *path) { return slave.open_disk(path); }
  bool open_cdrom(const char *path) { return master.open_cdrom(path); }
  bool is_open() const { return master.is_open() || slave.is_open(); }
  Kind kind() const { return master.kind(); }
  bool handles(u16 port) const { return master.handles(port); }
  bool is_data_port(u16 port) const { return master.is_data_port(port); }
  u8 read(u16 port) {
    u8 value = selected().read(port);
    if (port == base + 7) irq_pending = false;
    sync_irq();
    return value;
  }
  void write(u16 port, u8 value) {
    if (port == base + 6) select_slave = value & 0x10;
    master.write(port, value);
    slave.write(port, value);
    sync_irq();
  }
  u16 read16() { u16 value = selected().read16(); sync_irq(); return value; }
  void write16(u16 value) { selected().write16(value); sync_irq(); }
  // Intel 82371SB sections 2.7.1-2.7.3. The interrupt latch is used by
  // PCI IDE drivers even for PIO commands. Attached devices advertise
  // PIO only, so there are no device DMA requests/PRD transfers yet.
  u8 read_bus_master(unsigned offset) const {
    if (offset == 0) return bm_command;
    if (offset == 2) return bm_status;
    if (offset >= 4 && offset < 8) return bm_prdt >> ((offset - 4) * 8);
    return 0;
  }
  void write_bus_master(unsigned offset, u8 value) {
    if (offset == 0) {
      bm_command = value & 9;
      bm_status = (bm_status & ~1u) | (value & 1);
    } else if (offset == 2) {
      // Capability bits are software-owned; error/interrupt are W1C.
      bm_status = (bm_status & 7 & ~(value & 6)) | (value & 0x60);
    } else if (offset >= 4 && offset < 8) {
      unsigned shift = (offset - 4) * 8;
      bm_prdt = ((bm_prdt & ~(0xFFu << shift)) | ((u32)value << shift)) & ~3u;
    }
  }
  bool irq_pending = false, irq_asserted = false;
private:
  IDEDevice master, slave;
  u16 base;
  bool select_slave = false;
  u8 bm_command = 0, bm_status = 0;
  u32 bm_prdt = 0;
  IDEDevice &selected() { return select_slave ? slave : master; }
  void sync_irq() {
    // W1C while INTRQ remains high must not relatch the same assertion.
    if ((master.irq_asserted || slave.irq_asserted) && !irq_asserted)
      bm_status |= 4;
    irq_pending |= master.irq_pending || slave.irq_pending;
    master.irq_pending = slave.irq_pending = false;
    irq_asserted = master.irq_asserted || slave.irq_asserted;
  }
};

// =========================================================================
// 8237 DMA Controller — ISA DMA (channels 0-3)
//
// The floppy controller uses DMA channel 2 to transfer sector data.
// We implement just enough for SeaBIOS/DOS floppy access.
// Ports 0x00-0x0F (address/count for channels 0-3, command, mode, etc.)
// Page registers at 0x81 (ch2), 0x82 (ch3), 0x83 (ch1), 0x87 (ch0).
// =========================================================================

class DMAController {
public:
  struct Channel {
    u16 base_addr = 0;
    u16 base_count = 0;
    u16 current_addr = 0;
    u16 current_count = 0;
    u8 page = 0;
    u8 mode = 0;
    bool masked = true;
  };

  Channel ch[4];
  bool flip_flop = false;  // Low/high byte toggle for 16-bit registers
  u8 status = 0;
  u8 command = 0;

  u8 read(u16 port) {
    if (port <= 0x07) {
      int c = (port >> 1) & 3;
      bool is_count = port & 1;
      u16 val = is_count ? ch[c].current_count : ch[c].current_addr;
      u8 result;
      if (!flip_flop)
        result = val & 0xFF;
      else
        result = (val >> 8) & 0xFF;
      flip_flop = !flip_flop;
      return result;
    }
    switch (port) {
    case 0x08: return status;   // Status register
    case 0x0F: {                // Multi-channel mask register
      u8 val = 0;
      for (int i = 0; i < 4; i++)
        if (ch[i].masked) val |= (1 << i);
      return val;
    }
    default: return 0xFF;
    }
  }

  void write(u16 port, u8 val) {
    if (port <= 0x07) {
      int c = (port >> 1) & 3;
      bool is_count = port & 1;
      if (is_count) {
        if (!flip_flop)
          ch[c].base_count = (ch[c].base_count & 0xFF00) | val;
        else
          ch[c].base_count = (ch[c].base_count & 0x00FF) | ((u16)val << 8);
        ch[c].current_count = ch[c].base_count;
      } else {
        if (!flip_flop)
          ch[c].base_addr = (ch[c].base_addr & 0xFF00) | val;
        else
          ch[c].base_addr = (ch[c].base_addr & 0x00FF) | ((u16)val << 8);
        ch[c].current_addr = ch[c].base_addr;
      }
      flip_flop = !flip_flop;
      return;
    }
    switch (port) {
    case 0x08: command = val; break;           // Command register
    case 0x09: ch[val & 3].mode = val; break;  // Mode register
    case 0x0A:                                  // Single channel mask
      ch[val & 3].masked = (val & 4) != 0;
      break;
    case 0x0B: ch[val & 3].mode = val; break;  // Mode register (alias)
    case 0x0C: flip_flop = false; break;        // Clear flip-flop
    case 0x0D:                                  // Master clear
      flip_flop = false;
      status = 0;
      command = 0;
      for (auto &c : ch) c.masked = true;
      break;
    case 0x0E:                                  // Clear all masks
      for (auto &c : ch) c.masked = false;
      break;
    case 0x0F:                                  // Multi-channel mask
      for (int i = 0; i < 4; i++)
        ch[i].masked = (val & (1 << i)) != 0;
      break;
    }
  }

  // Page register ports
  void write_page(u16 port, u8 val) {
    switch (port) {
    case 0x81: ch[2].page = val; break;
    case 0x82: ch[3].page = val; break;
    case 0x83: ch[1].page = val; break;
    case 0x87: ch[0].page = val; break;
    }
  }

  u8 read_page(u16 port) {
    switch (port) {
    case 0x81: return ch[2].page;
    case 0x82: return ch[3].page;
    case 0x83: return ch[1].page;
    case 0x87: return ch[0].page;
    default: return 0xFF;
    }
  }

  bool handles(u16 port) const {
    return port <= 0x0F;
  }

  bool handles_page(u16 port) const {
    return port == 0x81 || port == 0x82 || port == 0x83 || port == 0x87;
  }

  // Get DMA channel physical address
  u32 get_addr(int c) const {
    return ((u32)ch[c].page << 16) | ch[c].current_addr;
  }

  u16 get_count(int c) const {
    return ch[c].current_count;
  }

  // After a DMA transfer completes, set terminal count in status
  void set_terminal_count(int c) {
    status |= (1 << c);
  }
};

// =========================================================================
// Floppy Disk Controller (i8272/82077AA)
//
// Ports 0x3F0-0x3F5, 0x3F7. Uses DMA channel 2 and IRQ 6.
// Supports 1.44MB 3.5" floppy (80 cylinders, 2 heads, 18 sectors/track).
// =========================================================================

class FloppyController {
public:
  ~FloppyController() {
    if (disk_fd >= 0) close(disk_fd);
  }

  bool open(const char *path) {
    disk_fd = ::open(path, O_RDWR);
    if (disk_fd < 0) {
      // Try read-only
      disk_fd = ::open(path, O_RDONLY);
      if (disk_fd < 0) { perror(path); return false; }
      read_only = true;
    }
    struct stat st;
    if (fstat(disk_fd, &st) < 0) { perror("fstat"); close(disk_fd); disk_fd = -1; return false; }
    disk_size = st.st_size;
    return true;
  }

  bool is_open() const { return disk_fd >= 0; }

  u8 read(u16 port) {
    switch (port) {
    case 0x3F0: return 0x80;  // SRA — drive 0 selected
    case 0x3F1: return 0x00;  // SRB
    case 0x3F2: return dor;   // Digital Output Register
    case 0x3F4:               // Main Status Register
      return msr;
    case 0x3F5:               // Data (FIFO)
      return read_fifo();
    case 0x3F7:               // Digital Input Register
      // Bit 7 = disk change (cleared after seek)
      return disk_changed ? 0x80 : 0x00;
    default: return 0xFF;
    }
  }

  void write(u16 port, u8 val) {
    switch (port) {
    case 0x3F2:  // Digital Output Register
    {
      bool was_reset = !(dor & 0x04);
      dor = val;
      bool in_reset = !(val & 0x04);
      if (was_reset && !in_reset) {
        // Coming out of reset — delay IRQ so floppy_wait_irq() can clear
        // the BDA flag before the IRQ fires (matches real hardware delay)
        reset_sensei_count = 4;
        irq_delay = 100;  // Fire IRQ after ~100 instruction steps
        msr = 0x80;  // RQM — ready for commands
        cmd_pos = 0;
        result_pos = 0;
        result_len = 0;
      }
      if (in_reset) {
        msr = 0x00;
        cmd_pos = 0;
        result_pos = 0;
        result_len = 0;
      }
      break;
    }
    case 0x3F5:  // Data (FIFO) — command bytes
      write_fifo(val);
      break;
    case 0x3F7:  // Configuration Control Register (data rate)
      data_rate = val & 0x03;
      break;
    }
  }

  bool handles(u16 port) const {
    return (0x3F0 <= port && port <= 0x3F5) || port == 0x3F7;
  }

  // Perform the DMA transfer for a completed read/write command.
  // Returns true if a DMA transfer was performed.
  template<typename PhysMem>
  bool do_dma_transfer(DMAController &dma, PhysMem &mem) {
    if (!dma_pending) return false;
    dma_pending = false;

    DMAController::Channel &dc = dma.ch[2];
    u32 addr = dma.get_addr(2);
    u16 count = dma.get_count(2) + 1;  // DMA count is N-1

    if (dma_is_write) {
      // Write: guest memory → disk
      for (u16 i = 0; i < count && i < (u16)sizeof(dma_buf); i++)
        dma_buf[i] = mem.read8(addr + i);
      u64 offset = dma_disk_offset;
      if (!read_only && offset + count <= disk_size)
        (void)!pwrite(disk_fd, dma_buf, count, offset);
    } else {
      // Read: disk → guest memory
      u64 offset = dma_disk_offset;
      memset(dma_buf, 0, count);
      if (offset + count <= disk_size)
        (void)!pread(disk_fd, dma_buf, count, offset);
      for (u16 i = 0; i < count; i++)
        mem.write8(addr + i, dma_buf[i]);
    }

    // Update DMA current address/count
    dc.current_addr += count;
    dc.current_count = 0;
    dma.set_terminal_count(2);

    irq_pending = true;
    return true;
  }

  // Called each instruction step to handle delayed IRQ
  void tick() {
    if (irq_delay > 0 && --irq_delay == 0)
      irq_pending = true;
  }

  bool irq_pending = false;

private:
  int disk_fd = -1;
  u64 disk_size = 0;
  bool read_only = false;

  // Geometry: 1.44MB = 80 cylinders × 2 heads × 18 sectors × 512 bytes
  static constexpr int CYLINDERS = 80;
  static constexpr int HEADS = 2;
  static constexpr int SECTORS = 18;
  static constexpr int SECTOR_SIZE = 512;

  // Delayed IRQ counter (for reset completion)
  int irq_delay = 0;

  // Registers
  u8 dor = 0;        // Digital Output Register
  u8 msr = 0x80;     // Main Status Register (RQM set)
  u8 data_rate = 0;   // CCR data rate

  // Cylinder tracking (per drive, only drive 0 used)
  u8 current_cylinder = 0;
  bool disk_changed = true;

  // Command FIFO
  u8 cmd_buf[16] = {};
  int cmd_pos = 0;
  int cmd_expected = 0;

  // Result FIFO
  u8 result_buf[16] = {};
  int result_pos = 0;
  int result_len = 0;

  // Reset sense interrupt counter
  int reset_sensei_count = 0;

  // DMA transfer state (set by command execution, performed by do_dma_transfer)
  bool dma_pending = false;
  bool dma_is_write = false;
  u64 dma_disk_offset = 0;
  u8 dma_buf[512 * 36] = {};  // Max: full track (18 sectors × 2 sides)

  u8 read_fifo() {
    if (result_pos < result_len) {
      // Reading first result byte deasserts IRQ (matches real hardware)
      if (result_pos == 0)
        irq_pending = false;
      u8 val = result_buf[result_pos++];
      if (result_pos >= result_len) {
        // All result bytes read — back to command phase
        result_pos = 0;
        result_len = 0;
        msr = 0x80;  // RQM, host→controller direction
      }
      return val;
    }
    return 0xFF;
  }

  void write_fifo(u8 val) {
    if (cmd_pos == 0) {
      // First byte: decode command
      cmd_buf[0] = val;
      cmd_pos = 1;
      cmd_expected = command_length(val & 0x1F);
      if (cmd_expected <= 1)
        execute_command();
      else
        msr = 0x90;  // RQM + CB (command busy, expecting more bytes)
      return;
    }

    cmd_buf[cmd_pos++] = val;
    if (cmd_pos >= cmd_expected)
      execute_command();
  }

  static int command_length(u8 cmd) {
    switch (cmd) {
    case 0x03: return 3;  // SPECIFY
    case 0x04: return 2;  // SENSE DRIVE STATUS
    case 0x05: return 9;  // WRITE DATA
    case 0x06: return 9;  // READ DATA
    case 0x07: return 2;  // RECALIBRATE
    case 0x08: return 1;  // SENSE INTERRUPT STATUS
    case 0x0A: return 2;  // READ ID
    case 0x0D: return 6;  // FORMAT TRACK
    case 0x0F: return 3;  // SEEK
    case 0x12: return 1;  // PERPENDICULAR MODE
    case 0x13: return 4;  // CONFIGURE
    case 0x14: return 1;  // LOCK
    default:   return 9;  // Unknown — assume max length
    }
  }

  void set_result_st012(u8 c, u8 h, u8 s) {
    // ST0, ST1, ST2, C, H, R, N
    result_buf[0] = 0x00;    // ST0: normal termination
    result_buf[1] = 0x00;    // ST1: no errors
    result_buf[2] = 0x00;    // ST2: no errors
    result_buf[3] = c;
    result_buf[4] = h;
    result_buf[5] = s;
    result_buf[6] = 0x02;    // N = 2 (512 bytes/sector)
    result_len = 7;
    result_pos = 0;
    msr = 0xD0;  // RQM + DIO (controller→host) + CB
  }

  void execute_command() {
    u8 cmd = cmd_buf[0] & 0x1F;  // Mask MT, MFM, SK bits

    switch (cmd) {
    case 0x03:  // SPECIFY
      // SRT, HUT, HLT, ND — just absorb
      cmd_pos = 0;
      msr = 0x80;
      break;

    case 0x04:  // SENSE DRIVE STATUS
      result_buf[0] = 0x20;  // ST3: track 0 + ready
      if (current_cylinder == 0) result_buf[0] |= 0x10;
      result_len = 1;
      result_pos = 0;
      cmd_pos = 0;
      msr = 0xD0;
      break;

    case 0x05:  // WRITE DATA
    case 0x06:  // READ DATA
    {
      u8 head = (cmd_buf[1] >> 2) & 1;
      u8 cyl = cmd_buf[2];
      u8 sec = cmd_buf[4];    // 1-based
      u8 eot = cmd_buf[6];    // End of track

      // Calculate disk offset: CHS → linear
      u64 offset = ((u64)cyl * HEADS * SECTORS + (u64)head * SECTORS + (sec - 1)) * SECTOR_SIZE;

      dma_pending = true;
      dma_is_write = (cmd == 0x05);
      dma_disk_offset = offset;

      // After DMA, set result (will be read after IRQ)
      current_cylinder = cyl;
      set_result_st012(cyl, head, eot + 1 > SECTORS ? 1 : eot + 1);
      if (eot + 1 > SECTORS) {
        result_buf[3] = cyl + 1;  // Wrapped to next cylinder
        result_buf[5] = 1;
      }
      cmd_pos = 0;
      break;
    }

    case 0x07:  // RECALIBRATE
      current_cylinder = 0;
      disk_changed = false;
      cmd_pos = 0;
      msr = 0x80;
      irq_pending = true;
      break;

    case 0x08:  // SENSE INTERRUPT STATUS
      if (reset_sensei_count > 0) {
        reset_sensei_count--;
        result_buf[0] = 0xC0 | (4 - 1 - reset_sensei_count);  // ST0: ready changed
        result_buf[1] = 0;  // PCN (current cylinder)
      } else {
        result_buf[0] = 0x20;  // ST0: seek end
        result_buf[1] = current_cylinder;
      }
      result_len = 2;
      result_pos = 0;
      cmd_pos = 0;
      msr = 0xD0;
      irq_pending = false;  // Acknowledge
      break;

    case 0x0A:  // READ ID
    {
      u8 head = (cmd_buf[1] >> 2) & 1;
      set_result_st012(current_cylinder, head, 1);
      cmd_pos = 0;
      irq_pending = true;
      break;
    }

    case 0x0F:  // SEEK
    {
      u8 ncn = cmd_buf[2];  // New cylinder number
      current_cylinder = ncn;
      disk_changed = false;
      cmd_pos = 0;
      msr = 0x80;
      irq_pending = true;
      break;
    }

    case 0x12:  // PERPENDICULAR MODE
    case 0x13:  // CONFIGURE
    case 0x14:  // LOCK
      cmd_pos = 0;
      msr = 0x80;
      break;

    default:
      // Unknown command — return invalid command status
      result_buf[0] = 0x80;  // ST0: invalid command
      result_len = 1;
      result_pos = 0;
      cmd_pos = 0;
      msr = 0xD0;
      break;
    }
  }
};

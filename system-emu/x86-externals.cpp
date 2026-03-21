// System-mode specific external function implementations.
// Shared functions are in ../emu-shared/x86-externals-common.cpp.

#include "sail_x86_model.h"
#include "x86-cpuid.h"
#include "x86-helpers.h"
#include <cstring>
#include <cmath>
#include <cfenv>
#include <unordered_map>
#include <immintrin.h>
#include <x86intrin.h>

namespace x86 {
void Model::z__read_mem(lbits *rop, u64 addr, sail_int n) {
  i64 nbytes = mpz_get_si(n);
  u8 buf[64];
  if (nbytes > 64) {
    fprintf(stderr, "z__read_mem: nbytes=%ld > 64\n", nbytes);
    abort();
  }
  phys_mem.read_bytes(addr, buf, nbytes);
  bytes_to_bits(rop, buf, nbytes, nbytes * 8);
}

unit Model::z__write_mem(u64 addr, sail_int n, lbits data) {
  i64 nbytes = mpz_get_si(n);
  u8 buf[64];
  if (nbytes > 64) {
    fprintf(stderr, "z__write_mem: nbytes=%ld > 64\n", nbytes);
    abort();
  }
  bits_to_bytes(data, buf, nbytes);

  phys_mem.write_bytes(addr, buf, nbytes);
  return UNIT;
}

// Page-crossing read: translate each byte's virtual address separately.
// Called when a memory access spans a 4KB page boundary, so the second
// page may map to a non-contiguous physical address.
void Model::z__mem_read_crossing(lbits *rop, u64 vaddr, sail_int n) {
  i64 nbytes = mpz_get_si(n);
  u8 buf[64];
  if (nbytes > 64) {
    fprintf(stderr, "z__mem_read_crossing: nbytes=%ld > 64\n", nbytes);
    abort();
  }
  for (i64 i = 0; i < nbytes; i++) {
    u64 paddr = ztranslate_addr(vaddr + i, zPT_Read);
    phys_mem.read_bytes(paddr, &buf[i], 1);
  }
  bytes_to_bits(rop, buf, nbytes, nbytes * 8);
}

// Page-crossing write: translate each byte's virtual address separately.
unit Model::z__mem_write_crossing(u64 vaddr, sail_int n, lbits data) {
  i64 nbytes = mpz_get_si(n);
  u8 buf[64];
  if (nbytes > 64) {
    fprintf(stderr, "z__mem_write_crossing: nbytes=%ld > 64\n", nbytes);
    abort();
  }
  bits_to_bytes(data, buf, nbytes);
  for (i64 i = 0; i < nbytes; i++) {
    u64 paddr = ztranslate_addr(vaddr + i, zPT_Write);
    phys_mem.write_bytes(paddr, &buf[i], 1);
  }
  return UNIT;
}

// =========================================================================
// Software TLB
// =========================================================================

void Model::z__tlb_lookup(struct zoptionzIbzK *rop, u64 linear, bool is_write) {
  u64 vpn = (u64)linear >> 12;
  int idx = vpn & (TLB_SIZE - 1);
  auto &e = tlb[idx];
  if (e.valid && e.vpn == vpn && (!is_write || e.writable)) {
    u64 paddr = (e.ppn << 12) | ((u64)linear & 0xFFF);
    // Clean up previous Some value if present
    if (rop->kind == Kind_zSomezIbzK) {
      KILL(lbits)(&rop->variants.zSomezIbzK);
    }
    rop->kind = Kind_zSomezIbzK;
    CREATE_OF(lbits, fbits)(&rop->variants.zSomezIbzK, paddr, 64, true);
    return;
  }
  if (rop->kind == Kind_zSomezIbzK) {
    KILL(lbits)(&rop->variants.zSomezIbzK);
  }
  rop->kind = Kind_zNonezIbzK;
}

unit Model::z__tlb_insert(u64 linear, u64 paddr, bool is_write) {
  u64 vpn = (u64)linear >> 12;
  u64 ppn = (u64)paddr >> 12;
  int idx = vpn & (TLB_SIZE - 1);
  auto &e = tlb[idx];
  e.vpn = vpn;
  e.ppn = ppn;
  e.valid = true;
  e.writable = is_write;
  return UNIT;
}

unit Model::z__tlb_flush(unit) {
  for (int i = 0; i < TLB_SIZE; i++)
    tlb[i].valid = false;
  return UNIT;
}

// =========================================================================
// MSR register file
// =========================================================================
//
// MSRs that alias Sail registers (EFER, FS_BASE, GS_BASE, KERNEL_GS_BASE)
// are handled directly in the Sail model. All other MSRs are stored here.

static std::unordered_map<u32, u64> msr_store;

u64 Model::z__rdmsr(u64 addr) {
  u32 msr = (u32)addr;
  auto it = msr_store.find(msr);
  if (it != msr_store.end())
    return it->second;

  // Default values for common MSRs
  switch (msr) {
  case 0x1B:   return 0xFEE00900;  // IA32_APIC_BASE (APIC enabled, BSP)
  case 0x10:   return tsc;         // IA32_TSC
  case 0x277:  return 0x0007040600070406ULL; // IA32_PAT (default)
  case 0x1A0:  return 1;           // IA32_MISC_ENABLE (bit 0 = FAST_STRING)
  case 0xC0000103: return 0;       // IA32_TSC_AUX
  case 0x17:  return 0;           // IA32_PLATFORM_ID
  case 0x34:  return 0;           // MSR_SMI_COUNT
  case 0x3a:  return 0;           // IA32_FEATURE_CONTROL
  case 0xce:  return 0;           // MSR_PLATFORM_INFO
  case 0x140: return 0;           // IA32_PERF_CAPABILITIES
  case 0x64e: return 0;           // MSR_PPERF
  default:
    { static int rdmsr_warn = 0;
      if (rdmsr_warn++ < 10)
        fprintf(stderr, "RDMSR: unhandled MSR 0x%x, returning 0\n", msr);
    }
    return 0;
  }
}

unit Model::z__wrmsr(u64 addr, u64 val) {
  u32 msr = (u32)addr;
  msr_store[msr] = val;
  return UNIT;
}

// =========================================================================
// I/O port dispatch — routes to device emulation
// =========================================================================

u64 Model::z__port_in8(u64 port) {
  u16 p = (u16)port;
  if (uart.handles(p))       return uart.read(p);
  if (pic_master.handles(p)) return pic_master.read(p);
  if (pic_slave.handles(p))  return pic_slave.read(p);
  if (pit.handles(p))        return pit.read(p);
  if (kbd.handles(p))        return kbd.read(p);
  if (cmos.handles(p))       return cmos.read(p);
  if (ata.handles(p))        return ata.read(p);
  if (fw_cfg.handles_read(p)) return fw_cfg.read(p);
  if (p == 0x61)             { pit.tick(10); return pit.read_port_b(); }
  if (p == 0x92)             return 0x02; // System Control Port A: A20 always enabled
  if (vga.handles(p))        return vga.read(p);
  // DMA controller (0x00-0x0F, 0x80-0x8F, 0xC0-0xDF)
  if (p <= 0x0F)             return 0x00;
  if (0x80 <= p && p <= 0x8F) return 0x00;
  if (0xC0 <= p && p <= 0xDF) return 0x00;
  // PCI config data (0xCFC-0xCFF)
  if (0xCFC <= p && p <= 0xCFF) {
    u32 val = pci.read_data();
    return (val >> ((p - 0xCFC) * 8)) & 0xFF;
  }
  if (p == 0xCF8) return pci.read_addr() & 0xFF;
  return 0xFF; // Default: empty bus
}

u64 Model::z__port_in16(u64 port) {
  u16 p = (u16)port;
  // ATA data port must be read as an atomic 16-bit word
  if (p == 0x1F0) return ata.read16(p);
  u16 lo = z__port_in8(port);
  u16 hi = z__port_in8(port + 1);
  return (hi << 8) | lo;
}

u64 Model::z__port_in32(u64 port) {
  u16 p = (u16)port;
  // PCI config address register: atomic 32-bit read
  if (p == 0xCF8) return pci.read_addr();
  // PCI config data register: atomic 32-bit read
  if (p == 0xCFC) return pci.read_data();
  u32 b0 = z__port_in8(port);
  u32 b1 = z__port_in8(port + 1);
  u32 b2 = z__port_in8(port + 2);
  u32 b3 = z__port_in8(port + 3);
  return (b3 << 24) | (b2 << 16) | (b1 << 8) | b0;
}

unit Model::z__port_out8(u64 port, u64 val) {
  u16 p = (u16)port;
  u8 v = (u8)val;
  if (uart.handles(p))            uart.write(p, v);
  else if (pic_master.handles(p)) pic_master.write(p, v);
  else if (pic_slave.handles(p))  pic_slave.write(p, v);
  else if (pit.handles(p))        pit.write(p, v);
  else if (kbd.handles(p))        kbd.write(p, v);
  else if (cmos.handles(p))       cmos.write(p, v);
  else if (ata.handles(p))        ata.write(p, v);
  else if (fw_cfg.handles_write(p)) fw_cfg.write(p, v);
  else if (p == 0x61)             pit.write_port_b(v);
  else if (vga.handles(p))        vga.write(p, v);
  else if (p == 0xCF8 || p == 0xCF9 || p == 0xCFA || p == 0xCFB) {
    u32 a = pci.read_addr();
    int shift = (p - 0xCF8) * 8;
    a = (a & ~(0xFF << shift)) | ((u32)v << shift);
    pci.write_addr(a);
  }
  else if (0xCFC <= p && p <= 0xCFF) {
    u32 d = pci.read_data();
    int shift = (p - 0xCFC) * 8;
    d = (d & ~(0xFF << shift)) | ((u32)v << shift);
    pci.write_data(d);
  }
  // Port 0x402, DMA, POST code, APM/SMI: silently absorb
  return UNIT;
}

unit Model::z__port_out16(u64 port, u64 val) {
  u16 p = (u16)port;
  // ATA data port must be written as an atomic 16-bit word
  if (p == 0x1F0) { ata.write16(p, (u16)val); return UNIT; }
  // fw_cfg selector is a 16-bit register
  if (p == 0x510) { fw_cfg.write(p, (u16)val); return UNIT; }
  z__port_out8(port, val & 0xFF);
  z__port_out8(port + 1, (val >> 8) & 0xFF);
  return UNIT;
}

unit Model::z__port_out32(u64 port, u64 val) {
  u16 p = (u16)port;
  // PCI config address register: atomic 32-bit write
  if (p == 0xCF8) { pci.write_addr((u32)val); return UNIT; }
  // PCI config data register: atomic 32-bit write
  if (p == 0xCFC) { pci.write_data((u32)val); return UNIT; }
  z__port_out8(port, val & 0xFF);
  z__port_out8(port + 1, (val >> 8) & 0xFF);
  z__port_out8(port + 2, (val >> 16) & 0xFF);
  z__port_out8(port + 3, (val >> 24) & 0xFF);
  return UNIT;
}

// =========================================================================
// External interrupt check — called by Sail model at start of step()


void Model::z__check_pending_irq(sail_int *rop, unit) {
  // Suppress hardware IRQs when in BIOS transition code (CS=F000, RM).
  // SeaBIOS's irqentry_extrastack has SS mismatch issues when IRQs
  // fire during call16/call32 transitions.
  if (zcur_mode == zRealMode &&
      (u16)zSegReg.data[x86::SEG_CS] == 0xF000) {
    mpz_set_si(*rop, -1);
    return;
  }

  // Raise ATA IRQ 14 on slave PIC (IRQ 6 on slave = system IRQ 14)
  if (ata.irq_pending)
    pic_slave.raise_irq(6);

  // Cascade: if slave has pending interrupts, raise IRQ 2 on master
  if (pic_slave.has_pending())
    pic_master.raise_irq(2);

  // Check master PIC for pending, unmasked interrupts
  if (pic_master.has_pending()) {
    int vec = pic_master.acknowledge();
    if (vec >= 0) {
      // If this is the cascade IRQ (master IRQ 2), acknowledge slave instead
      if ((vec & 7) == 2 && vec == pic_master.get_vector_offset() + 2) {
        int slave_vec = pic_slave.acknowledge();
        if (slave_vec >= 0) { mpz_set_si(*rop, slave_vec); return; }
        // Spurious cascade — still need to EOI the master
      }
      mpz_set_si(*rop, vec);
      return;
    }
  }
  mpz_set_si(*rop, -1); // No interrupt pending
}

// =========================================================================
// MASKMOVDQU
// =========================================================================

unit Model::z__maskmovdqu(lbits data, lbits mask, u64 vaddr) {
  u8 d[16];
  u8 m[16];
  bits_to_bytes(data, d, 16);
  bits_to_bytes(mask, m, 16);
  for (int i = 0; i < 16; i++)
    if (m[i] & 0x80) {
      u64 paddr = ztranslate_addr(vaddr + i, zPT_Write);
      phys_mem.write8(paddr, d[i]);
    }
  return UNIT;
}

// =========================================================================
// Virtual memory helpers for FXSAVE/FXRSTOR/XSAVE/XRSTOR
// =========================================================================
//
// These instructions receive virtual addresses from Sail but need to
// access physical memory. We must translate each page's worth separately
// to handle non-contiguous physical pages.

static void virt_write_bytes(Model &m, u64 vaddr, const void *buf, u64 len) {
  const u8 *src = static_cast<const u8 *>(buf);
  u64 pos = 0;
  while (pos < len) {
    u64 paddr = m.ztranslate_addr(vaddr + pos, zPT_Write);
    u64 page_remaining = 0x1000 - (paddr & 0xFFF);
    u64 chunk = std::min(page_remaining, len - pos);
    m.phys_mem.write_bytes(paddr, src + pos, chunk);
    pos += chunk;
  }
}

static void virt_read_bytes(Model &m, u64 vaddr, void *buf, u64 len) {
  u8 *dst = static_cast<u8 *>(buf);
  u64 pos = 0;
  while (pos < len) {
    u64 paddr = m.ztranslate_addr(vaddr + pos, zPT_Read);
    u64 page_remaining = 0x1000 - (paddr & 0xFFF);
    u64 chunk = std::min(page_remaining, len - pos);
    m.phys_mem.read_bytes(paddr, dst + pos, chunk);
    pos += chunk;
  }
}

static void virt_write32(Model &m, u64 vaddr, u32 val) {
  virt_write_bytes(m, vaddr, &val, 4);
}

static u32 virt_read32(Model &m, u64 vaddr) {
  u32 val;
  virt_read_bytes(m, vaddr, &val, 4);
  return val;
}

static void virt_write64(Model &m, u64 vaddr, u64 val) {
  virt_write_bytes(m, vaddr, &val, 8);
}

static u64 virt_read64(Model &m, u64 vaddr) {
  u64 val;
  virt_read_bytes(m, vaddr, &val, 8);
  return val;
}

// =========================================================================
// FXSAVE / FXRSTOR — save/restore FPU+SSE state to/from 512-byte area
// =========================================================================
//
// FXSAVE layout (512 bytes):
//   0x000: FCW (16), FSW (16), FTW_abridged (8), reserved (8), FOP (16)
//   0x008: FIP (32), FCS (16) / FIP (64 in 64-bit mode)
//   0x010: FDP (32), FDS (16) / FDP (64 in 64-bit mode)
//   0x018: MXCSR (32), MXCSR_MASK (32)
//   0x020-0x09F: ST0-ST7 (8 x 16 bytes, only 10 used per entry)
//   0x0A0-0x15F: XMM0-XMM7 (8 x 16 bytes) [32-bit mode]
//   0x0A0-0x19F: XMM0-XMM15 (16 x 16 bytes) [64-bit mode]
//   0x1A0-0x1FF: reserved

static void fxsave_common(Model &m, u64 addr) {
  // Zero the 512-byte area
  u8 zero[512] = {};
  virt_write_bytes(m, addr, zero, 512);

  // FCW at offset 0x00, FSW at offset 0x02
  u16 cw = (u16)m.zx87_cw;
  u16 sw = (u16)m.zx87_sw;
  virt_write_bytes(m, addr + 0x00, &cw, 2);
  virt_write_bytes(m, addr + 0x02, &sw, 2);

  // Abridged FTW at offset 0x04 (1 bit per register: 0=empty, 1=valid)
  u16 tw = (u16)m.zx87_tw;
  u8 ftw_abridged = 0;
  for (int i = 0; i < 8; i++)
    if (((tw >> (i * 2)) & 3) != 3)
      ftw_abridged |= (1 << i);
  virt_write_bytes(m, addr + 0x04, &ftw_abridged, 1);

  // MXCSR at offset 0x18
  u32 mxcsr = m.mxcsr_state.mxcsr;
  virt_write32(m, addr + 0x18, mxcsr);
  virt_write32(m, addr + 0x1C, 0x0002FFFF);

  // ST0-ST7 at offset 0x20 (16 bytes each, only 10 used)
  for (int i = 0; i < 8; i++) {
    u8 bytes[10];
    bits_to_bytes(m.zx87_ST.data[i], bytes, 10);
    virt_write_bytes(m, addr + 0x20 + i * 16, bytes, 10);
  }

  // XMM0-XMM15 at offset 0xA0 (16 bytes each)
  for (int i = 0; i < 16; i++) {
    u8 bytes[16];
    bits_to_bytes(m.zZMM.data[i], bytes, 16);
    virt_write_bytes(m, addr + 0xA0 + i * 16, bytes, 16);
  }
}

static void fxrstor_common(Model &m, u64 addr) {
  // FCW at offset 0x00, FSW at offset 0x02
  u16 cw, sw;
  virt_read_bytes(m, addr + 0x00, &cw, 2);
  virt_read_bytes(m, addr + 0x02, &sw, 2);
  m.zx87_cw = cw;
  m.zx87_sw = sw;

  // Abridged FTW at offset 0x04 — expand to full tag word
  u8 ftw_abridged;
  virt_read_bytes(m, addr + 0x04, &ftw_abridged, 1);
  u16 tw = 0;
  for (int i = 0; i < 8; i++)
    tw |= ((ftw_abridged & (1 << i)) ? 0 : 3) << (i * 2);
  m.zx87_tw = tw;

  // MXCSR at offset 0x18
  m.mxcsr_state.mxcsr = virt_read32(m, addr + 0x18);

  // ST0-ST7 at offset 0x20
  for (int i = 0; i < 8; i++) {
    u8 bytes[10];
    virt_read_bytes(m, addr + 0x20 + i * 16, bytes, 10);
    RECREATE(lbits)(&m.zx87_ST.data[i]);
    bytes_to_bits(&m.zx87_ST.data[i], bytes, 10, 80);
  }

  // XMM0-XMM15 at offset 0xA0
  for (int i = 0; i < 16; i++) {
    u8 bytes[16];
    virt_read_bytes(m, addr + 0xA0 + i * 16, bytes, 16);
    RECREATE(lbits)(&m.zZMM.data[i]);
    bytes_to_bits(&m.zZMM.data[i], bytes, 16, 128);
  }
}

unit Model::z__fxsave(u64 addr) {
  fxsave_common(*this, addr);
  return UNIT;
}

unit Model::z__fxsave64(u64 addr) {
  fxsave_common(*this, addr);
  return UNIT;
}

unit Model::z__fxrstor(u64 addr) {
  fxrstor_common(*this, addr);
  return UNIT;
}

unit Model::z__fxrstor64(u64 addr) {
  fxrstor_common(*this, addr);
  return UNIT;
}

// =========================================================================
// XSAVE / XRSTOR — save/restore extended state (x87+SSE+AVX)
// =========================================================================
//
// XSAVE area layout:
//   0x000–0x1FF: Legacy region (same as FXSAVE)
//   0x200–0x23F: XSAVE header
//   0x200: XSTATE_BV (8 bytes) — which components are saved
//   0x208: XCOMP_BV (8 bytes) — compaction mode (0 for standard XSAVE)
//   0x210–0x23F: reserved (must be zero)
//   0x240–0x33F: AVX state (YMM upper 128 bits) — if bit 2 set

unit Model::z__xsave(u64 addr, u64 mask) {
  u64 rfbm = mask & zXCR0;

  // Read old XSTATE_BV (XSAVE merges, not overwrites).
  u64 old_bv = virt_read64(*this, addr + 0x200);

  if (rfbm & 3)
    fxsave_common(*this, addr);

  u64 xstate_bv = (old_bv & ~rfbm) | (zXCR0 & rfbm);
  virt_write64(*this, addr + 0x200, xstate_bv);
  // XCOMP_BV = 0, reserved = 0.
  u8 zero[56] = {};
  virt_write_bytes(*this, addr + 0x208, zero, 56);

  return UNIT;
}

unit Model::z__xrstor(u64 addr, u64 mask) {
  u64 rfbm = mask & zXCR0;
  u64 xstate_bv = virt_read64(*this, addr + 0x200);

  u64 to_restore = rfbm & xstate_bv;
  u64 to_init = rfbm & ~xstate_bv;

  if (to_restore & 3)
    fxrstor_common(*this, addr);

  if (to_init & 1)
    zx87_init(UNIT);

  if (to_init & 2) {
    u8 zero[16] = {};
    for (int i = 0; i < 16; i++) {
      RECREATE(lbits)(&zZMM.data[i]);
      bytes_to_bits(&zZMM.data[i], zero, 16, 128);
    }
    mxcsr_state.mxcsr = 0x1F80;
  }

  if ((rfbm & 6) && (xstate_bv & 2))
    mxcsr_state.mxcsr = virt_read32(*this, addr + 0x18);

  return UNIT;
}

} // namespace x86

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
struct TracePhysWriteConfig {
  bool enabled;
  u64 target;
};

static const TracePhysWriteConfig &trace_phys_write_config() {
  static const TracePhysWriteConfig cfg = []{
    const char *s = getenv("SAIL_X86_TRACE_PHYS_WRITE");
    if (!s || !*s) return TracePhysWriteConfig{false, 0};
    return TracePhysWriteConfig{true, (u64)strtoull(s, nullptr, 0)};
  }();
  return cfg;
}

static void maybe_trace_phys_write(Model &m, u64 addr, const u8 *buf, i64 nbytes) {
  const auto &cfg = trace_phys_write_config();
  if (!cfg.enabled) return;
  if (cfg.target < addr || cfg.target >= addr + (u64)nbytes) return;
  fprintf(stderr,
          "sail-x86-system: phys-write tsc=%lu CS:RIP=%04x:%08lx addr=%016lx size=%ld target=%016lx bytes=",
          (u64)m.tsc, (unsigned)m.zSegReg.data[SEG_CS], (u64)m.zRIP,
          addr, (long)nbytes, cfg.target);
  for (i64 i = 0; i < nbytes; i++)
    fprintf(stderr, "%02x", buf[i]);
  fprintf(stderr, "\n");
}

void Model::z__read_mem(lbits *rop, u64 addr, sail_int n) {
  i64 nbits = mpz_get_si(n);
  i64 nbytes = nbits / 8;
  // Legacy x87 save areas occupy up to 108 bytes, larger than a ZMM.
  u8 buf[128];
  if (nbytes > 128) {
    fprintf(stderr, "z__read_mem: nbytes=%ld > 128\n", nbytes);
    abort();
  }
  phys_mem.read_bytes(addr, buf, nbytes);
  bytes_to_bits(rop, buf, nbytes, nbits);
}

unit Model::z__write_mem(u64 addr, sail_int n, lbits data) {
  i64 nbits = mpz_get_si(n);
  i64 nbytes = nbits / 8;
  u8 buf[128];
  if (nbytes > 128) {
    fprintf(stderr, "z__write_mem: nbytes=%ld > 128\n", nbytes);
    abort();
  }
  bits_to_bytes(data, buf, nbytes);
  maybe_trace_phys_write(*this, addr, buf, nbytes);
  phys_mem.write_bytes(addr, buf, nbytes);
  return UNIT;
}

// Page-crossing read: translate each byte's virtual address separately.
// Called when a memory access spans a 4KB page boundary, so the second
// page may map to a non-contiguous physical address.
void Model::z__mem_read_crossing(lbits *rop, u64 vaddr, sail_int n, enum zPTAccess access) {
  i64 nbits = mpz_get_si(n);
  i64 nbytes = nbits / 8;
  u8 buf[128];
  if (nbytes > 128) {
    fprintf(stderr, "z__mem_read_crossing: nbytes=%ld > 128\n", nbytes);
    abort();
  }
  for (i64 i = 0; i < nbytes; i++) {
    u64 paddr = ztranslate_addr(vaddr + i, access);
    phys_mem.read_bytes(paddr, &buf[i], 1);
  }
  bytes_to_bits(rop, buf, nbytes, nbits);
}

// Page-crossing write: translate each byte's virtual address separately.
unit Model::z__mem_write_crossing(u64 vaddr, sail_int n, lbits data) {
  i64 nbits = mpz_get_si(n);
  i64 nbytes = nbits / 8;
  u8 buf[128];
  if (nbytes > 128) {
    fprintf(stderr, "z__mem_write_crossing: nbytes=%ld > 128\n", nbytes);
    abort();
  }
  bits_to_bytes(data, buf, nbytes);
  for (i64 i = 0; i < nbytes; i++) {
    u64 paddr = ztranslate_addr(vaddr + i, zPT_Write);
    maybe_trace_phys_write(*this, paddr, &buf[i], 1);
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

u64 Model::z__read_cr8(unit) {
  return (lapic.base_msr & 0x800) ? lapic.read(0x80) >> 4 : zCR8;
}
unit Model::z__write_cr8(u64 value) {
  if (lapic.base_msr & 0x800) lapic.write(0x80, value << 4);
  return UNIT;
}

u64 Model::z__rdmsr(u64 addr) {
  u32 msr = (u32)addr;
  if (msr == 0x1B) return lapic.base_msr;
  auto it = msr_store.find(msr);
  if (it != msr_store.end())
    return it->second;

  // Default values for common MSRs
  switch (msr) {
  case 0x10:   return tsc;         // IA32_TSC
  case 0x277:  return 0x0007040600070406ULL; // IA32_PAT (default)
  case 0x1A0:  return 1;           // IA32_MISC_ENABLE (bit 0 = FAST_STRING)
  case 0xC0000103: return 0;       // IA32_TSC_AUX
  case 0x17:  return 0;           // IA32_PLATFORM_ID
  case 0x34:  return 0;           // MSR_SMI_COUNT
  // Note: IA32_FEATURE_CONTROL (0x3A) is handled in the Sail model's RDMSR dispatch
  case 0xfe:  return 0x508;        // IA32_MTRRCAP: 8 var ranges, fixed+WC supported
  case 0xce:  return 0;           // MSR_PLATFORM_INFO
  case 0x140: return 0;           // IA32_PERF_CAPABILITIES
  case 0x64e: return 0;           // MSR_PPERF
  case 0x48:  return 0;           // IA32_SPEC_CTRL (Spectre mitigations — none)
  case 0x122: return 0;           // IA32_TSX_CTRL (TSX — not supported)
  case 0x492: return 0;           // IA32_VMX_PROCBASED_CTLS3 (no tertiary controls)
  case 0xE1:  return 0;           // IA32_UMWAIT_CONTROL
  case 0x560: case 0x561:         // IA32_RTIT_OUTPUT_BASE/MASK (Processor Trace — not supported)
  case 0x570: case 0x571: case 0x572: // IA32_RTIT_CTL/STATUS/CR3_MATCH
  case 0x580: case 0x581: case 0x582: case 0x583: // IA32_RTIT_ADDR0-1
  case 0x584: case 0x585: case 0x586: case 0x587: // IA32_RTIT_ADDR2-3
    return 0;
  case 0x1D9: return 0;           // IA32_DEBUGCTL (debug/trace — not supported)
  case 0x1C4: return 0;           // IA32_XFD (Extended Feature Disable — not supported)
  case 0x1C5: return 0;           // IA32_XFD_ERR
  case 0x6A0: case 0x6A2:        // IA32_U_CET, IA32_S_CET (CET — not supported)
  case 0x6A4: case 0x6A5: case 0x6A6: case 0x6A7: case 0x6A8: // Shadow stack pointers
    return 0;
  case 0xD90: return 0;           // IA32_BNDCFGS (MPX — deprecated, not supported)
  case 0xC0000081: return 0;      // IA32_STAR (SYSCALL segment selectors — set by kernel via WRMSR)
  case 0xC0000082: return 0;      // IA32_LSTAR (64-bit SYSCALL target RIP)
  case 0xC0000083: return 0;      // IA32_CSTAR (compat-mode SYSCALL target RIP)
  case 0xC0000084: return 0;      // IA32_FMASK (SYSCALL RFLAGS mask)
  case 0xC0010117: return 0;      // AMD MSR_VIRT_SPEC_CTRL (not applicable on Intel)
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
  if (msr == 0x1B) {
    lapic.base_msr = (val & 0xFFFFFF800ULL) | 0x100; // xAPIC, BSP
    return UNIT;
  }
  msr_store[msr] = val;
  return UNIT;
}

// =========================================================================
// I/O port dispatch — routes to device emulation
// =========================================================================

u64 Model::z__port_in8(u64 port) {
  u16 p = (u16)port;
  if (vbe.handles(p)) return vbe.read(p) & 0xFF;
  if (uart.handles(p))       return uart.read(p);
  if (pic_master.handles(p)) return pic_master.read(p);
  if (pic_slave.handles(p))  return pic_slave.read(p);
  if (pit.handles(p))        return pit.read(p);
  if (kbd.handles(p))        return read_keyboard(p);
  if (cmos.handles(p)) {
    u8 value = cmos.read(p);
    set_irq(8, cmos.has_irq());
    return value;
  }
  if (floppy.handles(p))     return floppy.read(p);
  if (ide0.handles(p))       { u8 v = ide0.read(p); latch_ide_irqs(); return v; }
  if (ide1.handles(p))       { u8 v = ide1.read(p); latch_ide_irqs(); return v; }
  if (pci.ide_busmaster_handles(p)) {
    unsigned reg = p - pci.ide_busmaster_base();
    return (reg & 8 ? ide1 : ide0).read_busmaster(reg & 7);
  }
  if (p == 0x22) return imcr_index;
  if (p == 0x23 && imcr_index == 0x70) return imcr_apic;
  if (fw_cfg.handles_read(p)) return fw_cfg.read(p);
  if (p == 0x61)             return pit.read_port_b();
  if (p == 0x92)             return za20_enabled ? 0x02 : 0x00;
  if (p == 0xB2)             return pm.apmc;
  if (p == 0xB3)             return apmc_status; // APM Status
  if (p == 0x402)            return bios_debug ? 0xE9 : 0xFF; // QEMU debug console readback
  if (pm.handles_hotplug(p)) return pm.read_hotplug(p);
  // PIIX4 ACPI PM I/O (base 0xB000, range 0x40)
  if (pci.pm_base() <= p && p < pci.pm_base() + 0x40)
    return pm.read(p - pci.pm_base(), tsc);
  if (vga.handles(p))        return vga.read(p);
  // DMA controller (0x00-0x0F)
  if (dma.handles(p))        return dma.read(p);
  // DMA page registers
  if (dma.handles_page(p))   return dma.read_page(p);
  if (0xC0 <= p && p <= 0xDF) return 0x00; // High DMA (16-bit): stub
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
  if (vbe.handles(p)) return vbe.read(p);
  // IDE data ports must be read as atomic 16-bit words
  if (ide0.is_data_port(p)) { u16 v = ide0.read16(); latch_ide_irqs(); return v; }
  if (ide1.is_data_port(p)) { u16 v = ide1.read16(); latch_ide_irqs(); return v; }
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
  // 32-bit IDE data port access (insl) moves two words
  if (ide0.is_data_port(p)) { u32 v = ide0.read16(); v |= (u32)ide0.read16() << 16; latch_ide_irqs(); return v; }
  if (ide1.is_data_port(p)) { u32 v = ide1.read16(); v |= (u32)ide1.read16() << 16; latch_ide_irqs(); return v; }
  u32 b0 = z__port_in8(port);
  u32 b1 = z__port_in8(port + 1);
  u32 b2 = z__port_in8(port + 2);
  u32 b3 = z__port_in8(port + 3);
  return (b3 << 24) | (b2 << 16) | (b1 << 8) | b0;
}

unit Model::z__port_out8(u64 port, u64 val) {
  u16 p = (u16)port;
  u8 v = (u8)val;
  if (vbe.handles(p))            vbe.write(p, v);
  else if (uart.handles(p))       uart.write(p, v);
  else if (pic_master.handles(p)) pic_master.write(p, v);
  else if (pic_slave.handles(p))  pic_slave.write(p, v);
  else if (pit.handles(p))        pit.write(p, v);
  else if (kbd.handles(p))        kbd.write(p, v);
  else if (cmos.handles(p))       cmos.write(p, v);
  else if (floppy.handles(p))     { floppy.write(p, v); floppy.do_dma_transfer(dma, phys_mem); }
  else if (ide0.handles(p))       { ide0.write(p, v); latch_ide_irqs(); }
  else if (ide1.handles(p))       { ide1.write(p, v); latch_ide_irqs(); }
  else if (pci.ide_busmaster_handles(p)) {
    unsigned reg = p - pci.ide_busmaster_base();
    (reg & 8 ? ide1 : ide0).write_busmaster(reg & 7, v);
  }
  else if (fw_cfg.handles_write(p)) fw_cfg.write(p, v);
  else if (p == 0x61)             pit.write_port_b(v);
  else if (p == 0x22)             imcr_index = v;
  else if (p == 0x23 && imcr_index == 0x70) imcr_apic = v & 1;
  else if (vga.handles(p))        vga.write(p, v);
  else if (dma.handles(p))        dma.write(p, v);
  else if (dma.handles_page(p))   dma.write_page(p, v);
  else if (p == 0xCF9) {
    // PCI reset control register: bit 1 = reset, bit 2 = full reset
    if (v & 0x04) reboot_pending = true;
  } else if (p == 0xCF8 || p == 0xCFA || p == 0xCFB) {
    u32 a = pci.read_addr();
    int shift = (p - 0xCF8) * 8;
    a = (a & ~(0xFF << shift)) | ((u32)v << shift);
    pci.write_addr(a);
  } else if (0xCFC <= p && p <= 0xCFF) {
    u32 d = pci.read_data();
    int shift = (p - 0xCFC) * 8;
    d = (d & ~(0xFF << shift)) | ((u32)v << shift);
    pci.write_data(d);
    // If VGA ROM BAR was updated, sync the physical memory mapping
    sync_vga_bars();
  } else if (p == 0x92) {
    // System Control Port A: bit 1 = A20 gate
    za20_enabled = (v & 0x02) != 0;
  } else if (p == 0xB2) {
    // APM Control: trigger SMI
    pm.apm_write(v);
    if (pci.apmc_smi_enabled() && (pm.global_control & 1)) smi_pending = true;
  } else if (p == 0xB3) {
    // APM Status: store value
    apmc_status = v;
  } else if (pm.handles_hotplug(p)) {
    pm.write_hotplug(p, v);
  } else if (pci.pm_base() <= p && p < pci.pm_base() + 0x40) {
    if (pm.write(p - pci.pm_base(), v)) should_exit = true;
  }
  else if (p == 0x402) {
    // QEMU debug console: SeaBIOS dprintf output, shown with SAIL_X86_BIOS_DEBUG
    if (bios_debug) fputc(v, stderr);
  }
  // Port 0x80 POST code, high DMA: silently absorb
  return UNIT;
}

unit Model::z__port_out16(u64 port, u64 val) {
  u16 p = (u16)port;
  if (vbe.handles(p)) { vbe.write(p, val); return UNIT; }
  // IDE data ports must be written as atomic 16-bit words
  if (ide0.is_data_port(p)) { ide0.write16((u16)val); latch_ide_irqs(); return UNIT; }
  if (ide1.is_data_port(p)) { ide1.write16((u16)val); latch_ide_irqs(); return UNIT; }
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
  if (p == 0xCFC) { pci.write_data((u32)val); sync_vga_bars(); return UNIT; }
  // 32-bit IDE data port access (outsl) moves two words
  if (ide0.is_data_port(p)) { ide0.write16((u16)val); ide0.write16((u16)(val >> 16)); latch_ide_irqs(); return UNIT; }
  if (ide1.is_data_port(p)) { ide1.write16((u16)val); ide1.write16((u16)(val >> 16)); latch_ide_irqs(); return UNIT; }
  z__port_out8(port, val & 0xFF);
  z__port_out8(port + 1, (val >> 8) & 0xFF);
  z__port_out8(port + 2, (val >> 16) & 0xFF);
  z__port_out8(port + 3, (val >> 24) & 0xFF);
  return UNIT;
}

// =========================================================================
// SMI check — called by Sail model at start of step()

bool Model::z__check_pending_smi(unit) {
  bool pending = smi_pending;
  smi_pending = false;
  // Assert the chipset's SMM memory view before Sail writes the save state.
  // This check is skipped while in SMM; the first check after RSM closes it.
  phys_mem.smram_active = pending;
  return pending;
}

// =========================================================================
// External interrupt check — called by Sail model at start of step()


void Model::z__check_pending_irq(sail_int *rop, unit) {

  set_irq(8, cmos.has_irq());

  // Raise floppy IRQ 6 on master PIC (edge-triggered: one-shot)
  if (floppy.irq_pending) {
    floppy.irq_pending = false;
    pulse_irq(6);
  }

  // IDE interrupts are latched at the port access that raised them; this
  // catches one raised any other way (reset).
  latch_ide_irqs();

  int apic_vector = lapic.acknowledge();
  if (apic_vector >= 0) { mpz_set_si(*rop, apic_vector); return; }

  // Cascade: if slave has pending interrupts, raise IRQ 2 on master
  if (pic_slave.has_pending())
    pic_master.raise_irq(2);

  // Check master PIC for pending, unmasked interrupts
  if (pic_connected() && pic_master.has_pending()) {
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
  // MXCSR_MASK follows the model's vendor profile (insn_xsave.sail).
  virt_write32(m, addr + 0x1C, (u32)m.zmxcsr_mask(UNIT));

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

  // XMM0-XMM15 at offset 0xA0: the low 128 bits of each register; bits
  // 511:128 are not accessed (SDM Vol.1 §14.8).
  for (int i = 0; i < 16; i++) {
    u8 bytes[16];
    virt_read_bytes(m, addr + 0xA0 + i * 16, bytes, 16);
    set_zmm_low128(m.zZMM.data[i], bytes);
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

// XSAVE/XRSTOR are now implemented in Sail (insn_xsave.sail)

} // namespace x86

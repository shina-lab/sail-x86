// User-mode specific external function implementations.
// Shared functions are in ../emu-shared/x86-externals-common.cpp.

#include "sail_x86_model.h"
#include "x86-cpuid.h"
#include "x86-helpers.h"
#include <cstring>
#include <cmath>
#include <cfenv>
#include <unordered_map>
#include <vector>
#include <immintrin.h>
#include <x86intrin.h>

namespace x86 {
void Model::z__read_mem(lbits *rop, u64 addr, sail_int n) {
  i64 nbits = mpz_get_si(n);
  i64 nbytes = nbits / 8;
  u8 buf[128];
  if (nbytes > 128) {
    fprintf(stderr, "z__read_mem: nbytes=%ld > 128\n", nbytes);
    abort();
  }
  memcpy(buf, (void *)addr, nbytes);
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
  memcpy((void *)addr, buf, nbytes);
  return UNIT;
}

// Page-crossing read/write — translate each byte's virtual address
// separately, like the system emulator.  With paging disabled (CR0.PG=0,
// the user-mode emulator's normal state) translate_addr is the identity,
// so this matches the old direct access; with paging enabled (the KVM
// harness's #PF tests link this file) a crossing access faults exactly
// like the non-crossing path instead of bypassing translation.
void Model::z__mem_read_crossing(lbits *rop, u64 addr, sail_int n, enum zPTAccess access) {
  i64 nbits = mpz_get_si(n);
  i64 nbytes = nbits / 8;
  u8 buf[128];
  if (nbytes > 128) {
    fprintf(stderr, "z__mem_read_crossing: nbytes=%ld > 128\n", nbytes);
    abort();
  }
  for (i64 i = 0; i < nbytes; i++) {
    u64 paddr = ztranslate_addr(addr + i, access);
    // On #PF the generated code records the exception and returns a
    // dummy value; propagate instead of dereferencing it.
    if (have_exception) {
      bytes_to_bits(rop, buf, nbytes, nbits);
      return;
    }
    buf[i] = *(u8 *)paddr;
  }
  bytes_to_bits(rop, buf, nbytes, nbits);
}

unit Model::z__mem_write_crossing(u64 addr, sail_int n, lbits data) {
  i64 nbits = mpz_get_si(n);
  i64 nbytes = nbits / 8;
  u8 buf[128];
  if (nbytes > 128) {
    fprintf(stderr, "z__mem_write_crossing: nbytes=%ld > 128\n", nbytes);
    abort();
  }
  bits_to_bytes(data, buf, nbytes);
  for (i64 i = 0; i < nbytes; i++) {
    u64 paddr = ztranslate_addr(addr + i, zPT_Write);
    if (have_exception)
      return UNIT;  // #PF recorded; do not touch the dummy address
    *(u8 *)paddr = buf[i];
  }
  return UNIT;
}

// =========================================================================
// Software TLB — no-op stubs for user mode (paging is disabled)
// =========================================================================

void Model::z__tlb_lookup(struct zoptionzIbzK *rop, u64, bool) {
  rop->kind = Kind_zNonezIbzK;
}
unit Model::z__tlb_insert(u64, u64, bool) { return UNIT; }
unit Model::z__tlb_flush(unit) { return UNIT; }

// =========================================================================
// MSRs the model keeps outside its registers: a plain store, empty at start
// (user mode has no MSR access; the KVM harness loads a test's MSRs).
// =========================================================================

static std::unordered_map<u64, u64> msr_store;

u64 Model::z__read_cr8(unit) { return zCR8; }
unit Model::z__write_cr8(u64) { return UNIT; }

void x86_externals_reset_msrs() { msr_store.clear(); }
void x86_externals_set_msr(u64 msr, u64 value) { msr_store[msr] = value; }

u64 Model::z__rdmsr(u64 msr) {
  auto it = msr_store.find(msr);
  return it == msr_store.end() ? 0 : it->second;
}
unit Model::z__wrmsr(u64 msr, u64 value) {
  msr_store[msr] = value;
  return UNIT;
}
bool Model::z__check_pending_smi(unit) { return false; }

// =========================================================================
// I/O ports: user mode has no devices.  The KVM harness compares the
// sequence of port accesses with the guest's, so every access is logged
// (direction in bit 63, size in bits 55:48, port in bits 47:32, value in
// bits 31:0), and IN returns a value derived from the port, which the
// harness also supplies to the guest.
// =========================================================================

static std::vector<u64> port_io_log;

u32 x86_externals_port_in_value(u16 port, unsigned size) {
  u32 value = 0xA5000000u ^ (u32(port) * 0x01010101u);
  return size == 4 ? value : value & ((1u << (8 * size)) - 1);
}
static void log_port_io(bool out, unsigned size, u64 port, u64 value) {
  port_io_log.push_back((u64(out) << 63) | (u64(size) << 48) | ((port & 0xFFFF) << 32) | (value & 0xFFFFFFFF));
}
void x86_externals_reset_port_io() { port_io_log.clear(); }
const std::vector<u64> &x86_externals_port_io() { return port_io_log; }

u64 Model::z__port_in8(u64 port) {
  u32 v = x86_externals_port_in_value(port, 1);
  log_port_io(false, 1, port, v);
  return v;
}
u64 Model::z__port_in16(u64 port) {
  u32 v = x86_externals_port_in_value(port, 2);
  log_port_io(false, 2, port, v);
  return v;
}
u64 Model::z__port_in32(u64 port) {
  u32 v = x86_externals_port_in_value(port, 4);
  log_port_io(false, 4, port, v);
  return v;
}
unit Model::z__port_out8(u64 port, u64 value) { log_port_io(true, 1, port, value & 0xFF); return UNIT; }
unit Model::z__port_out16(u64 port, u64 value) { log_port_io(true, 2, port, value & 0xFFFF); return UNIT; }
unit Model::z__port_out32(u64 port, u64 value) { log_port_io(true, 4, port, value); return UNIT; }

// External interrupt check — not used in user mode
void Model::z__check_pending_irq(sail_int *rop, unit) { mpz_set_si(*rop, -1); }

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
  memset((void *)addr, 0, 512);

  // FCW at offset 0x00, FSW at offset 0x02
  u16 cw = (u16)m.zx87_cw;
  u16 sw = (u16)m.zx87_sw;
  memcpy((void *)(addr + 0x00), &cw, 2);
  memcpy((void *)(addr + 0x02), &sw, 2);

  // Abridged FTW at offset 0x04 (1 bit per register: 0=empty, 1=valid)
  u16 tw = (u16)m.zx87_tw;
  u8 ftw_abridged = 0;
  for (int i = 0; i < 8; i++)
  if (((tw >> (i * 2)) & 3) != 3)
    ftw_abridged |= (1 << i);
  memcpy((void *)(addr + 0x04), &ftw_abridged, 1);

  // MXCSR at offset 0x18
  u32 mxcsr = m.mxcsr_state.mxcsr;
  memcpy((void *)(addr + 0x18), &mxcsr, 4);
  // MXCSR_MASK follows the model's vendor profile (insn_xsave.sail).
  u32 mxcsr_mask = (u32)m.zmxcsr_mask(UNIT);
  memcpy((void *)(addr + 0x1C), &mxcsr_mask, 4);

  // ST0-ST7 at offset 0x20 (16 bytes each, only 10 used)
  for (int i = 0; i < 8; i++) {
  u8 bytes[10];
  bits_to_bytes(m.zx87_ST.data[i], bytes, 10);
  memcpy((void *)(addr + 0x20 + i * 16), bytes, 10);
  }

  // XMM0-XMM15 at offset 0xA0 (16 bytes each)
  for (int i = 0; i < 16; i++) {
  u8 bytes[16];
  bits_to_bytes(m.zZMM.data[i], bytes, 16);
  memcpy((void *)(addr + 0xA0 + i * 16), bytes, 16);
  }
}

static void fxrstor_common(Model &m, u64 addr) {
  // FCW at offset 0x00, FSW at offset 0x02
  u16 cw;
  u16 sw;
  memcpy(&cw, (void *)(addr + 0x00), 2);
  memcpy(&sw, (void *)(addr + 0x02), 2);
  m.zx87_cw = cw;
  m.zx87_sw = sw;

  // Abridged FTW at offset 0x04 — expand to full tag word
  u8 ftw_abridged;
  memcpy(&ftw_abridged, (void *)(addr + 0x04), 1);
  u16 tw = 0;
  for (int i = 0; i < 8; i++)
  tw |= ((ftw_abridged & (1 << i)) ? 0 : 3) << (i * 2);
  m.zx87_tw = tw;

  // MXCSR at offset 0x18
  u32 mxcsr;
  memcpy(&mxcsr, (void *)(addr + 0x18), 4);
  m.mxcsr_state.mxcsr = mxcsr;

  // ST0-ST7 at offset 0x20
  for (int i = 0; i < 8; i++) {
  u8 bytes[10];
  memcpy(bytes, (void *)(addr + 0x20 + i * 16), 10);
  RECREATE(lbits)(&m.zx87_ST.data[i]);
  bytes_to_bits(&m.zx87_ST.data[i], bytes, 10, 80);
  }

  // XMM0-XMM15 at offset 0xA0: the low 128 bits of each register; bits
  // 511:128 are not accessed (SDM Vol.1 §14.8).
  for (int i = 0; i < 16; i++) {
  u8 bytes[16];
  memcpy(bytes, (void *)(addr + 0xA0 + i * 16), 16);
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

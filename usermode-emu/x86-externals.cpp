// User-mode specific external function implementations.
// Shared functions are in ../emu-shared/x86-externals-common.cpp.

#include "sail_x86_model.h"
#include "x86-cpuid.h"
#include "x86-helpers.h"
#include <cstring>
#include <cmath>
#include <cfenv>
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
  memcpy(buf, (void *)addr, nbytes);
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
  memcpy((void *)addr, buf, nbytes);
  return UNIT;
}

// Page-crossing read/write — in user mode, paging is disabled so these
// are identical to the normal read/write (virtual = physical).
void Model::z__mem_read_crossing(lbits *rop, u64 addr, sail_int n) {
  z__read_mem(rop, addr, n);
}

unit Model::z__mem_write_crossing(u64 addr, sail_int n, lbits data) {
  return z__write_mem(addr, n, data);
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
// MSR (stub — user mode doesn't have MSR access)
// =========================================================================

u64 Model::z__rdmsr(u64) { return 0; }
unit Model::z__wrmsr(u64, u64) { return UNIT; }
bool Model::z__check_pending_smi(unit) { return false; }

// =========================================================================
// I/O ports (stub — user mode doesn't have port access)
// =========================================================================

u64 Model::z__port_in8(u64) { return 0xFF; }
u64 Model::z__port_in16(u64) { return 0xFFFF; }
u64 Model::z__port_in32(u64) { return 0xFFFFFFFF; }
unit Model::z__port_out8(u64, u64) { return UNIT; }
unit Model::z__port_out16(u64, u64) { return UNIT; }
unit Model::z__port_out32(u64, u64) { return UNIT; }

// External interrupt check — not used in user mode
void Model::z__check_pending_irq(sail_int *rop, unit) { mpz_set_si(*rop, -1); }

// =========================================================================
// MASKMOVDQU
// =========================================================================

unit Model::z__maskmovdqu(lbits data, lbits mask, u64 addr) {
  u8 d[16];
  u8 m[16];
  bits_to_bytes(data, d, 16);
  bits_to_bytes(mask, m, 16);
  for (int i = 0; i < 16; i++)
    if (m[i] & 0x80)
      *(u8 *)(addr + i) = d[i];
  return UNIT;
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
  u32 mxcsr_mask = 0x0002FFFF;
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

  // XMM0-XMM15 at offset 0xA0
  for (int i = 0; i < 16; i++) {
  u8 bytes[16];
  memcpy(bytes, (void *)(addr + 0xA0 + i * 16), 16);
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

// XSAVE/XRSTOR are now implemented in Sail (insn_xsave.sail)

} // namespace x86

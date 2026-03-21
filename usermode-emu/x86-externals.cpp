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
  u64 old_bv;
  memcpy(&old_bv, (void *)(addr + 0x200), 8);

  // Save x87 state into legacy region if RFBM[0].
  // Save XMM registers into legacy region if RFBM[1].
  // We use fxsave_common which saves both; acceptable since it writes
  // the full legacy region and the header disambiguates.
  if (rfbm & 3)
    fxsave_common(*this, addr);

  // XSTATE_BV := (OLD_BV AND NOT RFBM) OR (XINUSE AND RFBM).
  // We treat all supported components as in-use (XINUSE = zXCR0).
  u64 xstate_bv = (old_bv & ~rfbm) | (zXCR0 & rfbm);
  memcpy((void *)(addr + 0x200), &xstate_bv, 8);
  // XCOMP_BV = 0 (standard format), reserved = 0.
  memset((void *)(addr + 0x208), 0, 56);

  return UNIT;
}

unit Model::z__xrstor(u64 addr, u64 mask) {
  u64 rfbm = mask & zXCR0;

  u64 xstate_bv;
  memcpy(&xstate_bv, (void *)(addr + 0x200), 8);

  u64 to_restore = rfbm & xstate_bv;
  u64 to_init = rfbm & ~xstate_bv;

  // Restore legacy region (x87+SSE) if present in save area.
  if (to_restore & 3)
    fxrstor_common(*this, addr);

  // Initialize x87 to default if requested but not present.
  if (to_init & 1)
    zx87_init(UNIT);

  // Initialize SSE (XMM regs to zero, MXCSR to default) if requested but not present.
  if (to_init & 2) {
    u8 zero[16] = {};
    for (int i = 0; i < 16; i++) {
      RECREATE(lbits)(&zZMM.data[i]);
      bytes_to_bits(&zZMM.data[i], zero, 16, 128);
    }
    mxcsr_state.mxcsr = 0x1F80;
  }

  // Restore MXCSR if either SSE or AVX bit is in RFBM (per SDM).
  if ((rfbm & 6) && (xstate_bv & 2)) {
    u32 mxcsr;
    memcpy(&mxcsr, (void *)(addr + 0x18), 4);
    mxcsr_state.mxcsr = mxcsr;
  }

  return UNIT;
}

} // namespace x86

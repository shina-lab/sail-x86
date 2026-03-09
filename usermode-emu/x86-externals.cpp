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
// CPUID
// =========================================================================

struct ztuple_z8z5bv32zCz0z5bv32zCz0z5bv32zCz0z5bv32z9
Model::z__cpuid(u64 leaf, u64 subleaf) {
  struct ztuple_z8z5bv32zCz0z5bv32zCz0z5bv32zCz0z5bv32z9 result;
  result.ztup0 = 0; result.ztup1 = 0; result.ztup2 = 0; result.ztup3 = 0;

  auto pack = [](const char *p) -> u32 {
    return p[0] | (p[1] << 8) | (p[2] << 16) | (p[3] << 24);
  };

  // Return a baseline x86-64 CPU description (no host CPUID).
  // Roughly x86-64-v2: SSE4.2, POPCNT, CMPXCHG16B, but no AVX/FMA/BMI.
  switch (leaf) {
  case 0:
    result.ztup0 = 0x0D;    // max basic leaf
    result.ztup1 = pack("Genu");
    result.ztup2 = pack("ntel");
    result.ztup3 = pack("ineI");
    break;
  case 1:
    // EAX: Family 6, Model 0x5E, Stepping 3
    result.ztup0 = 0x000506E3;
    // EBX: CLFLUSH=8, max logical=1, initial APIC=0
    result.ztup1 = 0x00010800;
    result.ztup2 = EMU_CPUID_1_ECX;
    result.ztup3 = EMU_CPUID_1_EDX;
    break;
  case 2:
    // Cache/TLB descriptors — return a plausible single descriptor
    result.ztup0 = 0x76036301;  // call count=1 + descriptors
    result.ztup1 = 0x00F0B5FF;
    result.ztup2 = 0x00000000;
    result.ztup3 = 0x00C30000;
    break;
  case 4:
    // Deterministic cache parameters — report no more caches
    result.ztup0 = 0x00000000;  // type=0 (no more caches)
    break;
  case 7:
    if (subleaf == 0)
      result.ztup1 = EMU_CPUID_7_EBX;
    break;
  case 0xD:
    if (subleaf == 0) {
      // XSAVE: x87(0) + SSE(1) + AVX(2) + opmask(5) + ZMM_Hi256(6) + Hi16_ZMM(7)
      result.ztup0 = 0x000000E7;  // XCR0 supported bits
      result.ztup1 = 0x00000980;  // max size (2432 bytes)
      result.ztup2 = 0x00000980;
      result.ztup3 = 0x00000000;
    } else if (subleaf == 1) {
      result.ztup0 = 0x00000000;
    } else if (subleaf == 2) {
      // AVX state (component 2): 256 bytes at offset 576
      result.ztup0 = 0x00000100;
      result.ztup1 = 0x00000240;
    } else if (subleaf == 5) {
      // Opmask state (component 5): 64 bytes at offset 832
      result.ztup0 = 0x00000040;
      result.ztup1 = 0x00000340;
    } else if (subleaf == 6) {
      // ZMM_Hi256 (component 6): 512 bytes at offset 896
      result.ztup0 = 0x00000200;
      result.ztup1 = 0x00000380;
    } else if (subleaf == 7) {
      // Hi16_ZMM (component 7): 1024 bytes at offset 1408
      result.ztup0 = 0x00000400;
      result.ztup1 = 0x00000580;
    }
    break;
  case 0x80000000:
    result.ztup0 = 0x80000008;  // max extended leaf
    break;
  case 0x80000001:
    result.ztup2 = EMU_CPUID_EXT1_ECX;
    result.ztup3 = EMU_CPUID_EXT1_EDX;
    break;
  case 0x80000002:
    // Processor brand string part 1
    result.ztup0 = pack("Sail");
    result.ztup1 = pack(" x86");
    result.ztup2 = pack("-64 ");
    result.ztup3 = pack("Emul");
    break;
  case 0x80000003:
    // Processor brand string part 2
    result.ztup0 = pack("ator");
    break;
  case 0x80000004:
    // Processor brand string part 3 (empty)
    break;
  case 0x80000007:
    // Advanced power management — invariant TSC (bit 8)
    result.ztup3 = 0x00000100;
    break;
  case 0x80000008:
    // Address sizes: 39-bit physical, 48-bit virtual
    result.ztup0 = 0x00003027;
    break;
  }
  return result;
}

// =========================================================================
// MSR (stub — user mode doesn't have MSR access)
// =========================================================================

u64 Model::z__rdmsr(u64) { return 0; }
unit Model::z__wrmsr(u64, u64) { return UNIT; }

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

void Model::z__fxsave(zExecutionResult *rop, u64 addr) {
  fxsave_common(*this, addr);
  rop->kind = Kind_zOk;
  rop->variants.zOk = UNIT;
}

void Model::z__fxsave64(zExecutionResult *rop, u64 addr) {
  fxsave_common(*this, addr);
  rop->kind = Kind_zOk;
  rop->variants.zOk = UNIT;
}

void Model::z__fxrstor(zExecutionResult *rop, u64 addr) {
  fxrstor_common(*this, addr);
  rop->kind = Kind_zOk;
  rop->variants.zOk = UNIT;
}

void Model::z__fxrstor64(zExecutionResult *rop, u64 addr) {
  fxrstor_common(*this, addr);
  rop->kind = Kind_zOk;
  rop->variants.zOk = UNIT;
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

// XCR0: we support x87 (bit 0), SSE (bit 1), AVX (bit 2).
static constexpr u64 XCR0 = 0x7;

void Model::z__xsave(zExecutionResult *rop, u64 addr, u64 mask) {
  u64 rfbm = mask & XCR0;

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
  // We treat all supported components as in-use (XINUSE = XCR0).
  u64 xstate_bv = (old_bv & ~rfbm) | (XCR0 & rfbm);
  memcpy((void *)(addr + 0x200), &xstate_bv, 8);
  // XCOMP_BV = 0 (standard format), reserved = 0.
  memset((void *)(addr + 0x208), 0, 56);

  rop->kind = Kind_zOk;
  rop->variants.zOk = UNIT;
}

void Model::z__xrstor(zExecutionResult *rop, u64 addr, u64 mask) {
  u64 rfbm = mask & XCR0;

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

  rop->kind = Kind_zOk;
  rop->variants.zOk = UNIT;
}

} // namespace x86

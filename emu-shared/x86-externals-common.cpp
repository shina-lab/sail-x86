// Shared external function implementations used by both user-mode and system-mode emulators.
// Mode-specific functions (memory access, TLB, CPUID, MSR, I/O ports, etc.)
// are in the per-mode x86-externals.cpp.

#include "sail_x86_model.h"
#include "x86-cpuid.h"
#include "x86-helpers.h"
#include <cstring>
#include <cmath>
#include <cfenv>
#include <immintrin.h>
#include <wmmintrin.h>
#include <x86intrin.h>
#include <cstdlib>
#include <climits>

namespace x86 {
// Set the host FPU rounding mode based on 2-bit RC field.
static void set_rounding(int rc) {
  switch (rc) {
  case 0: fesetround(FE_TONEAREST); break;
  case 1: fesetround(FE_DOWNWARD); break;
  case 2: fesetround(FE_UPWARD); break;
  case 3: fesetround(FE_TOWARDZERO); break;
  }
}

// Sync host FPU rounding from MXCSR (bits 14:13).
#define SYNC_MXCSR_RC() set_rounding((mxcsr_state.mxcsr >> 13) & 3)

// DAZ: Denormals-Are-Zeros (MXCSR bit 6) — flush denormal inputs to ±0
static inline float f32_daz(float f, u32 mxcsr) {
  if (!(mxcsr & 0x0040))
    return f;
  u32 bits;
  memcpy(&bits, &f, 4);
  if ((bits & 0x7F800000) == 0 && (bits & 0x007FFFFF) != 0) {
    bits &= 0x80000000;  // preserve sign, zero out mantissa
    memcpy(&f, &bits, 4);
  }
  return f;
}

static inline double f64_daz(double f, u32 mxcsr) {
  if (!(mxcsr & 0x0040))
    return f;
  u64 bits;
  memcpy(&bits, &f, 8);
  if ((bits & 0x7FF0000000000000ULL) == 0 && (bits & 0x000FFFFFFFFFFFFFULL) != 0) {
    bits &= 0x8000000000000000ULL;
    memcpy(&f, &bits, 8);
  }
  return f;
}

// FTZ: Flush-To-Zero (MXCSR bit 15) — flush denormal results to ±0
static inline float f32_ftz(float f, u32 mxcsr) {
  if (!(mxcsr & 0x8000))
    return f;
  u32 bits;
  memcpy(&bits, &f, 4);
  if ((bits & 0x7F800000) == 0 && (bits & 0x007FFFFF) != 0) {
    bits &= 0x80000000;
    memcpy(&f, &bits, 4);
  }
  return f;
}

static inline double f64_ftz(double f, u32 mxcsr) {
  if (!(mxcsr & 0x8000))
    return f;
  u64 bits;
  memcpy(&bits, &f, 8);
  if ((bits & 0x7FF0000000000000ULL) == 0 && (bits & 0x000FFFFFFFFFFFFFULL) != 0) {
    bits &= 0x8000000000000000ULL;
    memcpy(&f, &bits, 8);
  }
  return f;
}

// DAZ for raw u64 bit patterns
static inline u64 f32_daz_bits(u64 a, u32 mxcsr) {
  if (!(mxcsr & 0x0040))
    return a;
  u32 bits = (u32)a;
  if ((bits & 0x7F800000) == 0 && (bits & 0x007FFFFF) != 0)
    return bits & 0x80000000;
  return a;
}

static inline u64 f64_daz_bits(u64 a, u32 mxcsr) {
  if (!(mxcsr & 0x0040))
    return a;
  if ((a & 0x7FF0000000000000ULL) == 0 && (a & 0x000FFFFFFFFFFFFFULL) != 0)
    return a & 0x8000000000000000ULL;
  return a;
}

// =========================================================================
// Helper: convert between lbits (Sail arbitrary-width bitvector) and bytes
// =========================================================================

// bits_to_bytes and bytes_to_bits are defined in x86-helpers.h

// Helper: long double <-> lbits(80) conversion
static long double lbits_to_f80(lbits val) {
  u8 bytes[10];
  bits_to_bytes(val, bytes, 10);
  long double result;
  memcpy(&result, bytes, 10);
  return result;
}

static void f80_to_lbits(lbits *out, long double val) {
  u8 bytes[10] = {};
  memcpy(bytes, &val, 10);
  bytes_to_bits(out, bytes, 10, 80);
}

// =========================================================================
// Memory: __read_mem, __write_mem
// =========================================================================

// =========================================================================
// IEEE 754 single-precision (f32) operations
// =========================================================================

// Intel NaN propagation for f32: if both NaN, return SRC1 (a) as QNaN;
// if only one is NaN, return that NaN as QNaN. Returns true if handled.
static bool f32_nan_prop(u64 a, u64 b, u64 *out) {
  u32 ua = (u32)a;
  u32 ub = (u32)b;
  float fa;
  float fb;
  memcpy(&fa, &ua, 4);
  memcpy(&fb, &ub, 4);
  bool a_nan = __builtin_isnan(fa);
  bool b_nan = __builtin_isnan(fb);
  if (!a_nan && !b_nan)
    return false;
  *out = a_nan ? (ua | 0x00400000) : (ub | 0x00400000);
  return true;
}

// Intel NaN propagation for f64.
static bool f64_nan_prop(u64 a, u64 b, u64 *out) {
  double fa;
  double fb;
  memcpy(&fa, &a, 8);
  memcpy(&fb, &b, 8);
  bool a_nan = __builtin_isnan(fa);
  bool b_nan = __builtin_isnan(fb);
  if (!a_nan && !b_nan)
    return false;
  *out = a_nan ? (a | 0x0008000000000000ULL) : (b | 0x0008000000000000ULL);
  return true;
}

u64 Model::z__f32_add(u64 a, u64 b) {
  a = f32_daz_bits(a, mxcsr_state.mxcsr);
  b = f32_daz_bits(b, mxcsr_state.mxcsr);
  u64 nr;
  if (f32_nan_prop(a, b, &nr))
    return nr;
  float fa;
  float fb;
  memcpy(&fa, &a, 4);
  memcpy(&fb, &b, 4);
  SYNC_MXCSR_RC();
  float fr = f32_ftz(fa + fb, mxcsr_state.mxcsr);
  u32 r;
  memcpy(&r, &fr, 4);
  return r;
}

u64 Model::z__f32_sub(u64 a, u64 b) {
  a = f32_daz_bits(a, mxcsr_state.mxcsr);
  b = f32_daz_bits(b, mxcsr_state.mxcsr);
  u64 nr;
  if (f32_nan_prop(a, b, &nr))
    return nr;
  float fa;
  float fb;
  memcpy(&fa, &a, 4);
  memcpy(&fb, &b, 4);
  SYNC_MXCSR_RC();
  float fr = f32_ftz(fa - fb, mxcsr_state.mxcsr);
  u32 r;
  memcpy(&r, &fr, 4);
  return r;
}

u64 Model::z__f32_mul(u64 a, u64 b) {
  a = f32_daz_bits(a, mxcsr_state.mxcsr);
  b = f32_daz_bits(b, mxcsr_state.mxcsr);
  u64 nr;
  if (f32_nan_prop(a, b, &nr))
    return nr;
  float fa;
  float fb;
  memcpy(&fa, &a, 4);
  memcpy(&fb, &b, 4);
  SYNC_MXCSR_RC();
  float fr = f32_ftz(fa * fb, mxcsr_state.mxcsr);
  u32 r;
  memcpy(&r, &fr, 4);
  return r;
}

u64 Model::z__f32_div(u64 a, u64 b) {
  a = f32_daz_bits(a, mxcsr_state.mxcsr);
  b = f32_daz_bits(b, mxcsr_state.mxcsr);
  u64 nr;
  if (f32_nan_prop(a, b, &nr))
    return nr;
  float fa;
  float fb;
  memcpy(&fa, &a, 4);
  memcpy(&fb, &b, 4);
  SYNC_MXCSR_RC();
  float fr = f32_ftz(fa / fb, mxcsr_state.mxcsr);
  u32 r;
  memcpy(&r, &fr, 4);
  return r;
}

u64 Model::z__f32_sqrt(u64 a) {
  a = f32_daz_bits(a, mxcsr_state.mxcsr);
  float fa;
  memcpy(&fa, &a, 4);
  SYNC_MXCSR_RC();
  float fr = f32_ftz(sqrtf(fa), mxcsr_state.mxcsr);
  u32 r;
  memcpy(&r, &fr, 4);
  return r;
}

u64 Model::z__f32_min(u64 a, u64 b) {
  a = f32_daz_bits(a, mxcsr_state.mxcsr);
  b = f32_daz_bits(b, mxcsr_state.mxcsr);
  float fa;
  float fb;
  memcpy(&fa, &a, 4);
  memcpy(&fb, &b, 4);
  float fr;
  // Per Intel SDM: if either source is NaN or both are zero, return SRC2 (b)
  if (__builtin_isnan(fa) || __builtin_isnan(fb)) {
    fr = fb;
  } else if (fa == 0.0f && fb == 0.0f) {
    fr = fb;
  } else {
    fr = fa < fb ? fa : fb;
  }
  u32 r;
  memcpy(&r, &fr, 4);
  return r;
}

u64 Model::z__f32_max(u64 a, u64 b) {
  a = f32_daz_bits(a, mxcsr_state.mxcsr);
  b = f32_daz_bits(b, mxcsr_state.mxcsr);
  float fa;
  float fb;
  memcpy(&fa, &a, 4);
  memcpy(&fb, &b, 4);
  float fr;
  // Per Intel SDM: if either source is NaN or both are zero, return SRC2 (b)
  if (__builtin_isnan(fa) || __builtin_isnan(fb)) {
    fr = fb;
  } else if (fa == 0.0f && fb == 0.0f) {
    fr = fb;
  } else {
    fr = fa > fb ? fa : fb;
  }
  u32 r;
  memcpy(&r, &fr, 4);
  return r;
}

u64 Model::z__f32_rcp(u64 a) {
  a = f32_daz_bits(a, mxcsr_state.mxcsr);
  float fa;
  memcpy(&fa, &a, 4);
  float fr = 1.0f / fa;
  u32 r;
  memcpy(&r, &fr, 4);
  return r;
}

u64 Model::z__f32_rsqrt(u64 a) {
  a = f32_daz_bits(a, mxcsr_state.mxcsr);
  float fa;
  memcpy(&fa, &a, 4);
  float fr = 1.0f / sqrtf(fa);
  u32 r;
  memcpy(&r, &fr, 4);
  return r;
}

u64 Model::z__f32_round(u64 a, u64 imm8) {
  a = f32_daz_bits(a, mxcsr_state.mxcsr);
  float fa;
  memcpy(&fa, &a, 4);
  float fr;
  int rc = imm8 & 3;
  switch (rc) {
    case 0: fr = nearbyintf(fa); break;  // round to nearest
    case 1: fr = floorf(fa); break;    // round down
    case 2: fr = ceilf(fa); break;     // round up
    case 3: fr = truncf(fa); break;    // truncate
    default: fr = fa; break;
  }
  u32 r;
  memcpy(&r, &fr, 4);
  return r;
}

// =========================================================================
// IEEE 754 double-precision (f64) operations
// =========================================================================

u64 Model::z__f64_add(u64 a, u64 b) {
  a = f64_daz_bits(a, mxcsr_state.mxcsr);
  b = f64_daz_bits(b, mxcsr_state.mxcsr);
  u64 nr;
  if (f64_nan_prop(a, b, &nr))
    return nr;
  double fa;
  double fb;
  memcpy(&fa, &a, 8);
  memcpy(&fb, &b, 8);
  SYNC_MXCSR_RC();
  double fr = f64_ftz(fa + fb, mxcsr_state.mxcsr);
  u64 r;
  memcpy(&r, &fr, 8);
  return r;
}

u64 Model::z__f64_sub(u64 a, u64 b) {
  a = f64_daz_bits(a, mxcsr_state.mxcsr);
  b = f64_daz_bits(b, mxcsr_state.mxcsr);
  u64 nr;
  if (f64_nan_prop(a, b, &nr))
    return nr;
  double fa;
  double fb;
  memcpy(&fa, &a, 8);
  memcpy(&fb, &b, 8);
  SYNC_MXCSR_RC();
  double fr = f64_ftz(fa - fb, mxcsr_state.mxcsr);
  u64 r;
  memcpy(&r, &fr, 8);
  return r;
}

u64 Model::z__f64_mul(u64 a, u64 b) {
  a = f64_daz_bits(a, mxcsr_state.mxcsr);
  b = f64_daz_bits(b, mxcsr_state.mxcsr);
  u64 nr;
  if (f64_nan_prop(a, b, &nr))
    return nr;
  double fa;
  double fb;
  memcpy(&fa, &a, 8);
  memcpy(&fb, &b, 8);
  SYNC_MXCSR_RC();
  double fr = f64_ftz(fa * fb, mxcsr_state.mxcsr);
  u64 r;
  memcpy(&r, &fr, 8);
  return r;
}

u64 Model::z__f64_div(u64 a, u64 b) {
  a = f64_daz_bits(a, mxcsr_state.mxcsr);
  b = f64_daz_bits(b, mxcsr_state.mxcsr);
  u64 nr;
  if (f64_nan_prop(a, b, &nr))
    return nr;
  double fa;
  double fb;
  memcpy(&fa, &a, 8);
  memcpy(&fb, &b, 8);
  SYNC_MXCSR_RC();
  double fr = f64_ftz(fa / fb, mxcsr_state.mxcsr);
  u64 r;
  memcpy(&r, &fr, 8);
  return r;
}

u64 Model::z__f64_sqrt(u64 a) {
  a = f64_daz_bits(a, mxcsr_state.mxcsr);
  double fa;
  memcpy(&fa, &a, 8);
  SYNC_MXCSR_RC();
  double fr = f64_ftz(sqrt(fa), mxcsr_state.mxcsr);
  u64 r;
  memcpy(&r, &fr, 8);
  return r;
}

u64 Model::z__f64_min(u64 a, u64 b) {
  a = f64_daz_bits(a, mxcsr_state.mxcsr);
  b = f64_daz_bits(b, mxcsr_state.mxcsr);
  double fa;
  double fb;
  memcpy(&fa, &a, 8);
  memcpy(&fb, &b, 8);
  double fr;
  // Per Intel SDM: if either source is NaN or both are zero, return SRC2 (b)
  if (__builtin_isnan(fa) || __builtin_isnan(fb)) {
    fr = fb;
  } else if (fa == 0.0 && fb == 0.0) {
    fr = fb;
  } else {
    fr = fa < fb ? fa : fb;
  }
  u64 r;
  memcpy(&r, &fr, 8);
  return r;
}

u64 Model::z__f64_max(u64 a, u64 b) {
  a = f64_daz_bits(a, mxcsr_state.mxcsr);
  b = f64_daz_bits(b, mxcsr_state.mxcsr);
  double fa;
  double fb;
  memcpy(&fa, &a, 8);
  memcpy(&fb, &b, 8);
  double fr;
  // Per Intel SDM: if either source is NaN or both are zero, return SRC2 (b)
  if (__builtin_isnan(fa) || __builtin_isnan(fb)) {
    fr = fb;
  } else if (fa == 0.0 && fb == 0.0) {
    fr = fb;
  } else {
    fr = fa > fb ? fa : fb;
  }
  u64 r;
  memcpy(&r, &fr, 8);
  return r;
}

u64 Model::z__f64_round(u64 a, u64 imm8) {
  a = f64_daz_bits(a, mxcsr_state.mxcsr);
  double fa;
  memcpy(&fa, &a, 8);
  double fr;
  int rc = imm8 & 3;
  switch (rc) {
    case 0: fr = nearbyint(fa); break;
    case 1: fr = floor(fa); break;
    case 2: fr = ceil(fa); break;
    case 3: fr = trunc(fa); break;
    default: fr = fa; break;
  }
  u64 r;
  memcpy(&r, &fr, 8);
  return r;
}

// =========================================================================
// FP comparison
// =========================================================================

enum zFPCompareResult Model::z__compare_ss(u64 a, u64 b) {
  a = f32_daz_bits(a, mxcsr_state.mxcsr);
  b = f32_daz_bits(b, mxcsr_state.mxcsr);
  float fa;
  float fb;
  memcpy(&fa, &a, 4);
  memcpy(&fb, &b, 4);
  if (__builtin_isnan(fa) || __builtin_isnan(fb))
    return zFP_UNORDERED;
  if (fa < fb)
    return zFP_LT;
  if (fa > fb)
    return zFP_GT;
  return zFP_EQ;
}

enum zFPCompareResult Model::z__compare_sd(u64 a, u64 b) {
  a = f64_daz_bits(a, mxcsr_state.mxcsr);
  b = f64_daz_bits(b, mxcsr_state.mxcsr);
  double fa;
  double fb;
  memcpy(&fa, &a, 8);
  memcpy(&fb, &b, 8);
  if (__builtin_isnan(fa) || __builtin_isnan(fb))
    return zFP_UNORDERED;
  if (fa < fb)
    return zFP_LT;
  if (fa > fb)
    return zFP_GT;
  return zFP_EQ;
}

enum zFPCompareResult Model::z__compare_sh(u64 a, u64 b) {
  // Convert FP16 to FP32 for comparison
  _Float16 ha;
  _Float16 hb;
  uint16_t ua = (uint16_t)a;
  uint16_t ub = (uint16_t)b;
  memcpy(&ha, &ua, 2);
  memcpy(&hb, &ub, 2);
  float fa = (float)ha;
  float fb = (float)hb;
  if (__builtin_isnan(fa) || __builtin_isnan(fb))
    return zFP_UNORDERED;
  if (fa < fb)
    return zFP_LT;
  if (fa > fb)
    return zFP_GT;
  return zFP_EQ;
}

// =========================================================================
// Int <-> Float conversions
// =========================================================================

u64 Model::z__int32_to_f64(u64 a) {
  i32 ia = (i32)a;
  double fr = (double)ia;
  u64 r;
  memcpy(&r, &fr, 8);
  return r;
}

u64 Model::z__int64_to_f64(u64 a) {
  i64 ia = (i64)a;
  SYNC_MXCSR_RC();
  double fr = (double)ia;
  u64 r;
  memcpy(&r, &fr, 8);
  return r;
}

u64 Model::z__int32_to_f32(u64 a) {
  i32 ia = (i32)a;
  SYNC_MXCSR_RC();
  float fr = (float)ia;
  u32 r;
  memcpy(&r, &fr, 4);
  return r;
}

u64 Model::z__int64_to_f32(u64 a) {
  i64 ia = (i64)a;
  SYNC_MXCSR_RC();
  float fr = (float)ia;
  u32 r;
  memcpy(&r, &fr, 4);
  return r;
}

u64 Model::z__f64_to_int32(u64 a) {
  a = f64_daz_bits(a, mxcsr_state.mxcsr);
  double fa;
  memcpy(&fa, &a, 8);
  if (__builtin_isnan(fa) || __builtin_isinf(fa))
    return (u32)INT32_MIN;
  set_rounding((mxcsr_state.mxcsr >> 13) & 3);
  long long r = llrint(fa);
  if (r > INT32_MAX || r < INT32_MIN)
    return (u32)INT32_MIN;
  return (u32)(i32)r;
}

u64 Model::z__f64_to_int64(u64 a) {
  a = f64_daz_bits(a, mxcsr_state.mxcsr);
  double fa;
  memcpy(&fa, &a, 8);
  if (__builtin_isnan(fa) || __builtin_isinf(fa))
    return (u64)INT64_MIN;
  set_rounding((mxcsr_state.mxcsr >> 13) & 3);
  long long r = llrint(fa);
  return (u64)r;
}

u64 Model::z__f32_to_int32(u64 a) {
  a = f32_daz_bits(a, mxcsr_state.mxcsr);
  float fa;
  memcpy(&fa, &a, 4);
  if (__builtin_isnan(fa) || __builtin_isinf(fa))
    return (u32)INT32_MIN;
  set_rounding((mxcsr_state.mxcsr >> 13) & 3);
  long long r = llrintf(fa);
  if (r > INT32_MAX || r < INT32_MIN)
    return (u32)INT32_MIN;
  return (u32)(i32)r;
}

u64 Model::z__f32_to_int64(u64 a) {
  a = f32_daz_bits(a, mxcsr_state.mxcsr);
  float fa;
  memcpy(&fa, &a, 4);
  if (__builtin_isnan(fa) || __builtin_isinf(fa))
    return (u64)INT64_MIN;
  set_rounding((mxcsr_state.mxcsr >> 13) & 3);
  long long r = llrintf(fa);
  return (u64)r;
}

u64 Model::z__f64_to_int32_trunc(u64 a) {
  double fa;
  memcpy(&fa, &a, 8);
  if (__builtin_isnan(fa) || __builtin_isinf(fa))
    return (u32)INT32_MIN;
  long long r = (long long)fa;
  if (r > INT32_MAX || r < INT32_MIN)
    return (u32)INT32_MIN;
  return (u32)(i32)r;
}

u64 Model::z__f64_to_int64_trunc(u64 a) {
  double fa;
  memcpy(&fa, &a, 8);
  if (__builtin_isnan(fa) || __builtin_isinf(fa))
    return (u64)INT64_MIN;
  // Use long double to avoid UB for values near INT64 boundary
  long double ld = (long double)fa;
  if (ld > (long double)INT64_MAX || ld < (long double)INT64_MIN)
    return (u64)INT64_MIN;
  return (u64)(i64)fa;
}

u64 Model::z__f32_to_int32_trunc(u64 a) {
  float fa;
  memcpy(&fa, &a, 4);
  if (__builtin_isnan(fa) || __builtin_isinf(fa))
    return (u32)INT32_MIN;
  long long r = (long long)fa;
  if (r > INT32_MAX || r < INT32_MIN)
    return (u32)INT32_MIN;
  return (u32)(i32)r;
}

u64 Model::z__f32_to_int64_trunc(u64 a) {
  float fa;
  memcpy(&fa, &a, 4);
  if (__builtin_isnan(fa) || __builtin_isinf(fa))
    return (u64)INT64_MIN;
  // float can't represent values > 2^63, so no overflow possible for in-range values
  long double ld = (long double)fa;
  if (ld > (long double)INT64_MAX || ld < (long double)INT64_MIN)
    return (u64)INT64_MIN;
  return (u64)(i64)fa;
}

u64 Model::z__f64_to_f32(u64 a) {
  a = f64_daz_bits(a, mxcsr_state.mxcsr);
  double fa;
  memcpy(&fa, &a, 8);
  SYNC_MXCSR_RC();
  float fr = f32_ftz((float)fa, mxcsr_state.mxcsr);
  u32 r;
  memcpy(&r, &fr, 4);
  return r;
}

u64 Model::z__f32_to_f64(u64 a) {
  a = f32_daz_bits(a, mxcsr_state.mxcsr);
  float fa;
  memcpy(&fa, &a, 4);
  double fr = (double)fa;
  u64 r;
  memcpy(&r, &fr, 8);
  return r;
}

// x87 FPU state is now managed in Sail (core/x87_regs.sail).
// The Sail registers zx87_ST, zx87_cw, zx87_sw, zx87_tw are accessed
// directly by the generated C++ code.

// =========================================================================
// x87 80-bit FP arithmetic (using host long double)
// =========================================================================

void Model::z__f80_add(lbits *rop, lbits a, lbits b) {
  f80_to_lbits(rop, lbits_to_f80(a) + lbits_to_f80(b));
}

void Model::z__f80_sub(lbits *rop, lbits a, lbits b) {
  f80_to_lbits(rop, lbits_to_f80(a) - lbits_to_f80(b));
}

void Model::z__f80_mul(lbits *rop, lbits a, lbits b) {
  f80_to_lbits(rop, lbits_to_f80(a) * lbits_to_f80(b));
}

void Model::z__f80_div(lbits *rop, lbits a, lbits b) {
  f80_to_lbits(rop, lbits_to_f80(a) / lbits_to_f80(b));
}

void Model::z__f80_sqrt(lbits *rop, lbits a) {
  f80_to_lbits(rop, sqrtl(lbits_to_f80(a)));
}

void Model::z__f80_abs(lbits *rop, lbits a) {
  f80_to_lbits(rop, fabsl(lbits_to_f80(a)));
}

void Model::z__f80_chs(lbits *rop, lbits a) {
  f80_to_lbits(rop, -lbits_to_f80(a));
}

enum zFPCompareResult Model::z__f80_compare(lbits a, lbits b) {
  long double fa = lbits_to_f80(a), fb = lbits_to_f80(b);
  if (__builtin_isnan(fa) || __builtin_isnan(fb))
    return zFP_UNORDERED;
  if (fa < fb)
    return zFP_LT;
  if (fa > fb)
    return zFP_GT;
  return zFP_EQ;
}

// x87 conversions
void Model::z__f80_from_f32(lbits *rop, u64 a) {
  float fa;
  memcpy(&fa, &a, 4);
  f80_to_lbits(rop, (long double)fa);
}

void Model::z__f80_from_f64(lbits *rop, u64 a) {
  double fa;
  memcpy(&fa, &a, 8);
  f80_to_lbits(rop, (long double)fa);
}

u64 Model::z__f80_to_f32(lbits a) {
  float fr = (float)lbits_to_f80(a);
  u32 r;
  memcpy(&r, &fr, 4);
  return r;
}

u64 Model::z__f80_to_f64(lbits a) {
  double fr = (double)lbits_to_f80(a);
  u64 r;
  memcpy(&r, &fr, 8);
  return r;
}

void Model::z__f80_from_int32(lbits *rop, u64 a) {
  f80_to_lbits(rop, (long double)(i32)a);
}

void Model::z__f80_from_int64(lbits *rop, u64 a) {
  f80_to_lbits(rop, (long double)(i64)a);
}

void Model::z__f80_from_int16(lbits *rop, u64 a) {
  f80_to_lbits(rop, (long double)(i16)a);
}

// Set the host FPU rounding mode based on the x87 control word RC field.
static void sync_rounding_mode(u64 cw) {
  set_rounding((cw >> 10) & 3);
}

u64 Model::z__f80_to_int32(lbits a) {
  long double v = lbits_to_f80(a);
  sync_rounding_mode(zx87_cw);
  return (u32)(i32)llrintl(v);
}

u64 Model::z__f80_to_int64(lbits a) {
  long double v = lbits_to_f80(a);
  sync_rounding_mode(zx87_cw);
  return (u64)llrintl(v);
}

u64 Model::z__f80_to_int32_trunc(lbits a) {
  return (u32)(i32)lbits_to_f80(a);
}

u64 Model::z__f80_to_int64_trunc(lbits a) {
  return (u64)(i64)lbits_to_f80(a);
}

u64 Model::z__f80_to_int16(lbits a) {
  long double v = lbits_to_f80(a);
  sync_rounding_mode(zx87_cw);
  return (u16)(i16)llrintl(v);
}

u64 Model::z__f80_to_int16_trunc(lbits a) {
  return (u16)(i16)lbits_to_f80(a);
}

// x87 constants
void Model::z__f80_zzero(lbits *rop, unit) {
  f80_to_lbits(rop, 0.0L);
}

void Model::z__f80_one(lbits *rop, unit) {
  f80_to_lbits(rop, 1.0L);
}

void Model::z__f80_log2_10(lbits *rop, unit) {
  f80_to_lbits(rop, 3.32192809488736234787031942948939017749L);
}

void Model::z__f80_log2_e(lbits *rop, unit) {
  f80_to_lbits(rop, 1.44269504088896340735992468100189213743L);
}

void Model::z__f80_pi(lbits *rop, unit) {
  f80_to_lbits(rop, 3.14159265358979323846264338327950288420L);
}

void Model::z__f80_log10_2(lbits *rop, unit) {
  f80_to_lbits(rop, 0.30102999566398119521373889472449302677L);
}

void Model::z__f80_ln_2(lbits *rop, unit) {
  f80_to_lbits(rop, 0.69314718055994530941723212145817656808L);
}


// x87 transcendentals
void Model::z__f80_sin(lbits *rop, lbits a) {
  f80_to_lbits(rop, sinl(lbits_to_f80(a)));
}

void Model::z__f80_cos(lbits *rop, lbits a) {
  f80_to_lbits(rop, cosl(lbits_to_f80(a)));
}

void Model::z__f80_tan(lbits *rop, lbits a) {
  f80_to_lbits(rop, tanl(lbits_to_f80(a)));
}

void Model::z__f80_atan2(lbits *rop, lbits a, lbits b) {
  f80_to_lbits(rop, atan2l(lbits_to_f80(a), lbits_to_f80(b)));
}

void Model::z__f80_2xm1(lbits *rop, lbits a) {
  f80_to_lbits(rop, exp2l(lbits_to_f80(a)) - 1.0L);
}

void Model::z__f80_scale(lbits *rop, lbits a, lbits b) {
  // FSCALE: ST(0) * 2^trunc(ST(1))
  long double base = lbits_to_f80(a);
  long double exp_val = lbits_to_f80(b);
  f80_to_lbits(rop, ldexpl(base, (int)truncl(exp_val)));
}

void Model::z__f80_prem(lbits *rop, lbits a, lbits b) {
  f80_to_lbits(rop, fmodl(lbits_to_f80(a), lbits_to_f80(b)));
}

void Model::z__f80_prem1(lbits *rop, lbits a, lbits b) {
  f80_to_lbits(rop, remainderl(lbits_to_f80(a), lbits_to_f80(b)));
}

void Model::z__f80_round(lbits *rop, lbits a) {
  f80_to_lbits(rop, rintl(lbits_to_f80(a)));
}

void Model::z__f80_yl2x(lbits *rop, lbits y, lbits x) {
  f80_to_lbits(rop, lbits_to_f80(y) * log2l(lbits_to_f80(x)));
}

void Model::z__f80_yl2xp1(lbits *rop, lbits y, lbits x) {
  f80_to_lbits(rop, lbits_to_f80(y) * log2l(lbits_to_f80(x) + 1.0L));
}

void Model::z__f80_from_bcd(lbits *rop, lbits a) {
  // Convert 80-bit BCD (18 digits + sign) to long double
  u8 bytes[10];
  bits_to_bytes(a, bytes, 10);
  long double result = 0;
  for (int i = 8; i >= 0; i--) {
    int hi = (bytes[i] >> 4) & 0xF;
    int lo = bytes[i] & 0xF;
    result = result * 100.0L + hi * 10 + lo;
  }
  if (bytes[9] & 0x80)
    result = -result;
  f80_to_lbits(rop, result);
}

void Model::z__f80_to_bcd(lbits *rop, lbits a) {
  long double val = lbits_to_f80(a);
  u8 bytes[10] = {};
  bool neg = val < 0;
  if (neg)
    val = -val;
  u64 ival = (u64)llrintl(val);
  for (int i = 0; i < 9; i++) {
    int lo = ival % 10; ival /= 10;
    int hi = ival % 10; ival /= 10;
    bytes[i] = (hi << 4) | lo;
  }
  if (neg)
    bytes[9] = 0x80;
  bytes_to_bits(rop, bytes, 10, 80);
}

enum zFPClass Model::z__f80_classify(lbits a) {
  long double val = lbits_to_f80(a);
  int cl = std::fpclassify(val);
  switch (cl) {
    case FP_NAN: return zFP_NaN;
    case FP_INFINITE: return zFP_Infinity;
    case FP_ZERO: return zFP_Zero;
    case FP_SUBNORMAL: return zFP_Denormal;
    case FP_NORMAL: return zFP_Normal;
    default: return zFP_Unsupported;
  }
}

void Model::z__f80_extract_exponent(lbits *rop, lbits a) {
  long double val = lbits_to_f80(a);
  int exp;
  frexpl(val, &exp);
  f80_to_lbits(rop, (long double)(exp - 1));
}

void Model::z__f80_extract_significand(lbits *rop, lbits a) {
  long double val = lbits_to_f80(a);
  int exp;
  long double sig = frexpl(val, &exp);
  // Return significand with exponent 0 (biased 3FFF in x87)
  f80_to_lbits(rop, sig * 2.0L);  // frexpl returns [0.5, 1.0), we want [1.0, 2.0)
}

// =========================================================================
// MXCSR
// =========================================================================

unit Model::z__ldmxcsr(u64 val) {
  mxcsr_state.mxcsr = (u32)val;
  return UNIT;
}

u64 Model::z__stmxcsr(unit) {
  return mxcsr_state.mxcsr;
}

// =========================================================================
// RDTSC
// =========================================================================

u64 Model::z__rdtsc(unit) {
  // In system mode, return a simulated TSC. The tsc counter is
  // incremented by the main loop (once per step), so it tracks
  // instruction count. This ensures timer calibration (comparing TSC
  // deltas against PIT intervals) produces consistent results.
  if (zsystem_mode)
    return tsc;
  return __rdtsc();
}

// =========================================================================
// RDRAND / RDSEED
// =========================================================================

struct ztuple_z8z5bv64zCz0z5bv1z9 Model::z__rdrand64(unit) {
  unsigned long long val;
  int ok = _rdrand64_step(&val);
  struct ztuple_z8z5bv64zCz0z5bv1z9 result;
  result.ztup0 = val;
  result.ztup1 = ok ? 1 : 0;
  return result;
}

struct ztuple_z8z5bv64zCz0z5bv1z9 Model::z__rdseed64(unit) {
  unsigned long long val;
  int ok = _rdseed64_step(&val);
  struct ztuple_z8z5bv64zCz0z5bv1z9 result;
  result.ztup0 = val;
  result.ztup1 = ok ? 1 : 0;
  return result;
}

// =========================================================================
// Software interrupt (INT n) — stub for user mode
// =========================================================================

unit Model::z__software_interrupt(u64 vec) {
  // In user mode, INT 0x80 was the old Linux syscall interface.
  // For now, just raise a fault exception.
  current_exception->kind = Kind_zFault;
  current_exception->variants.zFault.ztup0 = (i64)vec;
  current_exception->variants.zFault.ztup1 = 0;
  have_exception = true;
  return UNIT;
}

// =========================================================================
// WAIT/FWAIT — no-op in user mode
// =========================================================================

unit Model::z__wait(unit) {
  return UNIT;
}
// =========================================================================
// AES-NI
// =========================================================================

void Model::z__aesenc(lbits *rop, lbits state, lbits key) {
  u8 s[16];
  u8 k[16];
  u8 r[16];
  bits_to_bytes(state, s, 16);
  bits_to_bytes(key, k, 16);
  __m128i si = _mm_loadu_si128((__m128i *)s);
  __m128i ki = _mm_loadu_si128((__m128i *)k);
  __m128i ri = _mm_aesenc_si128(si, ki);
  _mm_storeu_si128((__m128i *)r, ri);
  bytes_to_bits(rop, r, 16, 128);
}

void Model::z__aesenclast(lbits *rop, lbits state, lbits key) {
  u8 s[16];
  u8 k[16];
  u8 r[16];
  bits_to_bytes(state, s, 16);
  bits_to_bytes(key, k, 16);
  __m128i si = _mm_loadu_si128((__m128i *)s);
  __m128i ki = _mm_loadu_si128((__m128i *)k);
  __m128i ri = _mm_aesenclast_si128(si, ki);
  _mm_storeu_si128((__m128i *)r, ri);
  bytes_to_bits(rop, r, 16, 128);
}

void Model::z__aesdec(lbits *rop, lbits state, lbits key) {
  u8 s[16];
  u8 k[16];
  u8 r[16];
  bits_to_bytes(state, s, 16);
  bits_to_bytes(key, k, 16);
  __m128i si = _mm_loadu_si128((__m128i *)s);
  __m128i ki = _mm_loadu_si128((__m128i *)k);
  __m128i ri = _mm_aesdec_si128(si, ki);
  _mm_storeu_si128((__m128i *)r, ri);
  bytes_to_bits(rop, r, 16, 128);
}

void Model::z__aesdeclast(lbits *rop, lbits state, lbits key) {
  u8 s[16];
  u8 k[16];
  u8 r[16];
  bits_to_bytes(state, s, 16);
  bits_to_bytes(key, k, 16);
  __m128i si = _mm_loadu_si128((__m128i *)s);
  __m128i ki = _mm_loadu_si128((__m128i *)k);
  __m128i ri = _mm_aesdeclast_si128(si, ki);
  _mm_storeu_si128((__m128i *)r, ri);
  bytes_to_bits(rop, r, 16, 128);
}

void Model::z__aesimc(lbits *rop, lbits key) {
  u8 k[16];
  u8 r[16];
  bits_to_bytes(key, k, 16);
  __m128i ki = _mm_loadu_si128((__m128i *)k);
  __m128i ri = _mm_aesimc_si128(ki);
  _mm_storeu_si128((__m128i *)r, ri);
  bytes_to_bits(rop, r, 16, 128);
}

void Model::z__aeskeygenassist(lbits *rop, lbits key, u64 rcon) {
  u8 k[16];
  u8 r[16];
  bits_to_bytes(key, k, 16);
  __m128i ki = _mm_loadu_si128((__m128i *)k);
  // _mm_aeskeygenassist_si128 requires compile-time constant for rcon,
  // so we use a switch for common values.
  __m128i ri;
  switch (rcon & 0xFF) {
    case 0x01: ri = _mm_aeskeygenassist_si128(ki, 0x01); break;
    case 0x02: ri = _mm_aeskeygenassist_si128(ki, 0x02); break;
    case 0x04: ri = _mm_aeskeygenassist_si128(ki, 0x04); break;
    case 0x08: ri = _mm_aeskeygenassist_si128(ki, 0x08); break;
    case 0x10: ri = _mm_aeskeygenassist_si128(ki, 0x10); break;
    case 0x20: ri = _mm_aeskeygenassist_si128(ki, 0x20); break;
    case 0x40: ri = _mm_aeskeygenassist_si128(ki, 0x40); break;
    case 0x80: ri = _mm_aeskeygenassist_si128(ki, 0x80); break;
    case 0x1B: ri = _mm_aeskeygenassist_si128(ki, 0x1B); break;
    case 0x36: ri = _mm_aeskeygenassist_si128(ki, 0x36); break;
    default:   ri = _mm_aeskeygenassist_si128(ki, 0x00); break;
  }
  _mm_storeu_si128((__m128i *)r, ri);
  bytes_to_bits(rop, r, 16, 128);
}

// =========================================================================
// GFNI (Galois Field New Instructions)
// =========================================================================

void Model::z__gf2p8mulb(lbits *rop, lbits src1, lbits src2) {
  u8 a[16], b[16], r[16];
  bits_to_bytes(src1, a, 16);
  bits_to_bytes(src2, b, 16);
  __m128i va = _mm_loadu_si128((__m128i *)a);
  __m128i vb = _mm_loadu_si128((__m128i *)b);
  __m128i vr = _mm_gf2p8mul_epi8(va, vb);
  _mm_storeu_si128((__m128i *)r, vr);
  bytes_to_bits(rop, r, 16, 128);
}

// Helper macro for GF2P8AFFINE with compile-time imm8
#define GF2P8AFFINE_CASE(N) case N: vr = _mm_gf2p8affine_epi64_epi8(va, vb, N); break;

void Model::z__gf2p8affineqb(lbits *rop, lbits src1, lbits src2, u64 imm8) {
  u8 a[16], b[16], r[16];
  bits_to_bytes(src1, a, 16);
  bits_to_bytes(src2, b, 16);
  __m128i va = _mm_loadu_si128((__m128i *)a);
  __m128i vb = _mm_loadu_si128((__m128i *)b);
  __m128i vr;
  // imm8 must be compile-time constant; exhaustive switch
  switch (imm8 & 0xFF) {
    GF2P8AFFINE_CASE(0)   GF2P8AFFINE_CASE(1)   GF2P8AFFINE_CASE(2)   GF2P8AFFINE_CASE(3)
    GF2P8AFFINE_CASE(4)   GF2P8AFFINE_CASE(5)   GF2P8AFFINE_CASE(6)   GF2P8AFFINE_CASE(7)
    GF2P8AFFINE_CASE(8)   GF2P8AFFINE_CASE(9)   GF2P8AFFINE_CASE(10)  GF2P8AFFINE_CASE(11)
    GF2P8AFFINE_CASE(12)  GF2P8AFFINE_CASE(13)  GF2P8AFFINE_CASE(14)  GF2P8AFFINE_CASE(15)
    GF2P8AFFINE_CASE(16)  GF2P8AFFINE_CASE(17)  GF2P8AFFINE_CASE(18)  GF2P8AFFINE_CASE(19)
    GF2P8AFFINE_CASE(20)  GF2P8AFFINE_CASE(21)  GF2P8AFFINE_CASE(22)  GF2P8AFFINE_CASE(23)
    GF2P8AFFINE_CASE(24)  GF2P8AFFINE_CASE(25)  GF2P8AFFINE_CASE(26)  GF2P8AFFINE_CASE(27)
    GF2P8AFFINE_CASE(28)  GF2P8AFFINE_CASE(29)  GF2P8AFFINE_CASE(30)  GF2P8AFFINE_CASE(31)
    GF2P8AFFINE_CASE(32)  GF2P8AFFINE_CASE(33)  GF2P8AFFINE_CASE(34)  GF2P8AFFINE_CASE(35)
    GF2P8AFFINE_CASE(36)  GF2P8AFFINE_CASE(37)  GF2P8AFFINE_CASE(38)  GF2P8AFFINE_CASE(39)
    GF2P8AFFINE_CASE(40)  GF2P8AFFINE_CASE(41)  GF2P8AFFINE_CASE(42)  GF2P8AFFINE_CASE(43)
    GF2P8AFFINE_CASE(44)  GF2P8AFFINE_CASE(45)  GF2P8AFFINE_CASE(46)  GF2P8AFFINE_CASE(47)
    GF2P8AFFINE_CASE(48)  GF2P8AFFINE_CASE(49)  GF2P8AFFINE_CASE(50)  GF2P8AFFINE_CASE(51)
    GF2P8AFFINE_CASE(52)  GF2P8AFFINE_CASE(53)  GF2P8AFFINE_CASE(54)  GF2P8AFFINE_CASE(55)
    GF2P8AFFINE_CASE(56)  GF2P8AFFINE_CASE(57)  GF2P8AFFINE_CASE(58)  GF2P8AFFINE_CASE(59)
    GF2P8AFFINE_CASE(60)  GF2P8AFFINE_CASE(61)  GF2P8AFFINE_CASE(62)  GF2P8AFFINE_CASE(63)
    GF2P8AFFINE_CASE(64)  GF2P8AFFINE_CASE(65)  GF2P8AFFINE_CASE(66)  GF2P8AFFINE_CASE(67)
    GF2P8AFFINE_CASE(68)  GF2P8AFFINE_CASE(69)  GF2P8AFFINE_CASE(70)  GF2P8AFFINE_CASE(71)
    GF2P8AFFINE_CASE(72)  GF2P8AFFINE_CASE(73)  GF2P8AFFINE_CASE(74)  GF2P8AFFINE_CASE(75)
    GF2P8AFFINE_CASE(76)  GF2P8AFFINE_CASE(77)  GF2P8AFFINE_CASE(78)  GF2P8AFFINE_CASE(79)
    GF2P8AFFINE_CASE(80)  GF2P8AFFINE_CASE(81)  GF2P8AFFINE_CASE(82)  GF2P8AFFINE_CASE(83)
    GF2P8AFFINE_CASE(84)  GF2P8AFFINE_CASE(85)  GF2P8AFFINE_CASE(86)  GF2P8AFFINE_CASE(87)
    GF2P8AFFINE_CASE(88)  GF2P8AFFINE_CASE(89)  GF2P8AFFINE_CASE(90)  GF2P8AFFINE_CASE(91)
    GF2P8AFFINE_CASE(92)  GF2P8AFFINE_CASE(93)  GF2P8AFFINE_CASE(94)  GF2P8AFFINE_CASE(95)
    GF2P8AFFINE_CASE(96)  GF2P8AFFINE_CASE(97)  GF2P8AFFINE_CASE(98)  GF2P8AFFINE_CASE(99)
    GF2P8AFFINE_CASE(100) GF2P8AFFINE_CASE(101) GF2P8AFFINE_CASE(102) GF2P8AFFINE_CASE(103)
    GF2P8AFFINE_CASE(104) GF2P8AFFINE_CASE(105) GF2P8AFFINE_CASE(106) GF2P8AFFINE_CASE(107)
    GF2P8AFFINE_CASE(108) GF2P8AFFINE_CASE(109) GF2P8AFFINE_CASE(110) GF2P8AFFINE_CASE(111)
    GF2P8AFFINE_CASE(112) GF2P8AFFINE_CASE(113) GF2P8AFFINE_CASE(114) GF2P8AFFINE_CASE(115)
    GF2P8AFFINE_CASE(116) GF2P8AFFINE_CASE(117) GF2P8AFFINE_CASE(118) GF2P8AFFINE_CASE(119)
    GF2P8AFFINE_CASE(120) GF2P8AFFINE_CASE(121) GF2P8AFFINE_CASE(122) GF2P8AFFINE_CASE(123)
    GF2P8AFFINE_CASE(124) GF2P8AFFINE_CASE(125) GF2P8AFFINE_CASE(126) GF2P8AFFINE_CASE(127)
    GF2P8AFFINE_CASE(128) GF2P8AFFINE_CASE(129) GF2P8AFFINE_CASE(130) GF2P8AFFINE_CASE(131)
    GF2P8AFFINE_CASE(132) GF2P8AFFINE_CASE(133) GF2P8AFFINE_CASE(134) GF2P8AFFINE_CASE(135)
    GF2P8AFFINE_CASE(136) GF2P8AFFINE_CASE(137) GF2P8AFFINE_CASE(138) GF2P8AFFINE_CASE(139)
    GF2P8AFFINE_CASE(140) GF2P8AFFINE_CASE(141) GF2P8AFFINE_CASE(142) GF2P8AFFINE_CASE(143)
    GF2P8AFFINE_CASE(144) GF2P8AFFINE_CASE(145) GF2P8AFFINE_CASE(146) GF2P8AFFINE_CASE(147)
    GF2P8AFFINE_CASE(148) GF2P8AFFINE_CASE(149) GF2P8AFFINE_CASE(150) GF2P8AFFINE_CASE(151)
    GF2P8AFFINE_CASE(152) GF2P8AFFINE_CASE(153) GF2P8AFFINE_CASE(154) GF2P8AFFINE_CASE(155)
    GF2P8AFFINE_CASE(156) GF2P8AFFINE_CASE(157) GF2P8AFFINE_CASE(158) GF2P8AFFINE_CASE(159)
    GF2P8AFFINE_CASE(160) GF2P8AFFINE_CASE(161) GF2P8AFFINE_CASE(162) GF2P8AFFINE_CASE(163)
    GF2P8AFFINE_CASE(164) GF2P8AFFINE_CASE(165) GF2P8AFFINE_CASE(166) GF2P8AFFINE_CASE(167)
    GF2P8AFFINE_CASE(168) GF2P8AFFINE_CASE(169) GF2P8AFFINE_CASE(170) GF2P8AFFINE_CASE(171)
    GF2P8AFFINE_CASE(172) GF2P8AFFINE_CASE(173) GF2P8AFFINE_CASE(174) GF2P8AFFINE_CASE(175)
    GF2P8AFFINE_CASE(176) GF2P8AFFINE_CASE(177) GF2P8AFFINE_CASE(178) GF2P8AFFINE_CASE(179)
    GF2P8AFFINE_CASE(180) GF2P8AFFINE_CASE(181) GF2P8AFFINE_CASE(182) GF2P8AFFINE_CASE(183)
    GF2P8AFFINE_CASE(184) GF2P8AFFINE_CASE(185) GF2P8AFFINE_CASE(186) GF2P8AFFINE_CASE(187)
    GF2P8AFFINE_CASE(188) GF2P8AFFINE_CASE(189) GF2P8AFFINE_CASE(190) GF2P8AFFINE_CASE(191)
    GF2P8AFFINE_CASE(192) GF2P8AFFINE_CASE(193) GF2P8AFFINE_CASE(194) GF2P8AFFINE_CASE(195)
    GF2P8AFFINE_CASE(196) GF2P8AFFINE_CASE(197) GF2P8AFFINE_CASE(198) GF2P8AFFINE_CASE(199)
    GF2P8AFFINE_CASE(200) GF2P8AFFINE_CASE(201) GF2P8AFFINE_CASE(202) GF2P8AFFINE_CASE(203)
    GF2P8AFFINE_CASE(204) GF2P8AFFINE_CASE(205) GF2P8AFFINE_CASE(206) GF2P8AFFINE_CASE(207)
    GF2P8AFFINE_CASE(208) GF2P8AFFINE_CASE(209) GF2P8AFFINE_CASE(210) GF2P8AFFINE_CASE(211)
    GF2P8AFFINE_CASE(212) GF2P8AFFINE_CASE(213) GF2P8AFFINE_CASE(214) GF2P8AFFINE_CASE(215)
    GF2P8AFFINE_CASE(216) GF2P8AFFINE_CASE(217) GF2P8AFFINE_CASE(218) GF2P8AFFINE_CASE(219)
    GF2P8AFFINE_CASE(220) GF2P8AFFINE_CASE(221) GF2P8AFFINE_CASE(222) GF2P8AFFINE_CASE(223)
    GF2P8AFFINE_CASE(224) GF2P8AFFINE_CASE(225) GF2P8AFFINE_CASE(226) GF2P8AFFINE_CASE(227)
    GF2P8AFFINE_CASE(228) GF2P8AFFINE_CASE(229) GF2P8AFFINE_CASE(230) GF2P8AFFINE_CASE(231)
    GF2P8AFFINE_CASE(232) GF2P8AFFINE_CASE(233) GF2P8AFFINE_CASE(234) GF2P8AFFINE_CASE(235)
    GF2P8AFFINE_CASE(236) GF2P8AFFINE_CASE(237) GF2P8AFFINE_CASE(238) GF2P8AFFINE_CASE(239)
    GF2P8AFFINE_CASE(240) GF2P8AFFINE_CASE(241) GF2P8AFFINE_CASE(242) GF2P8AFFINE_CASE(243)
    GF2P8AFFINE_CASE(244) GF2P8AFFINE_CASE(245) GF2P8AFFINE_CASE(246) GF2P8AFFINE_CASE(247)
    GF2P8AFFINE_CASE(248) GF2P8AFFINE_CASE(249) GF2P8AFFINE_CASE(250) GF2P8AFFINE_CASE(251)
    GF2P8AFFINE_CASE(252) GF2P8AFFINE_CASE(253) GF2P8AFFINE_CASE(254) GF2P8AFFINE_CASE(255)
  }
  _mm_storeu_si128((__m128i *)r, vr);
  bytes_to_bits(rop, r, 16, 128);
}
#undef GF2P8AFFINE_CASE

#define GF2P8AFFINEINV_CASE(N) case N: vr = _mm_gf2p8affineinv_epi64_epi8(va, vb, N); break;

void Model::z__gf2p8affineinvqb(lbits *rop, lbits src1, lbits src2, u64 imm8) {
  u8 a[16], b[16], r[16];
  bits_to_bytes(src1, a, 16);
  bits_to_bytes(src2, b, 16);
  __m128i va = _mm_loadu_si128((__m128i *)a);
  __m128i vb = _mm_loadu_si128((__m128i *)b);
  __m128i vr;
  switch (imm8 & 0xFF) {
    GF2P8AFFINEINV_CASE(0)   GF2P8AFFINEINV_CASE(1)   GF2P8AFFINEINV_CASE(2)   GF2P8AFFINEINV_CASE(3)
    GF2P8AFFINEINV_CASE(4)   GF2P8AFFINEINV_CASE(5)   GF2P8AFFINEINV_CASE(6)   GF2P8AFFINEINV_CASE(7)
    GF2P8AFFINEINV_CASE(8)   GF2P8AFFINEINV_CASE(9)   GF2P8AFFINEINV_CASE(10)  GF2P8AFFINEINV_CASE(11)
    GF2P8AFFINEINV_CASE(12)  GF2P8AFFINEINV_CASE(13)  GF2P8AFFINEINV_CASE(14)  GF2P8AFFINEINV_CASE(15)
    GF2P8AFFINEINV_CASE(16)  GF2P8AFFINEINV_CASE(17)  GF2P8AFFINEINV_CASE(18)  GF2P8AFFINEINV_CASE(19)
    GF2P8AFFINEINV_CASE(20)  GF2P8AFFINEINV_CASE(21)  GF2P8AFFINEINV_CASE(22)  GF2P8AFFINEINV_CASE(23)
    GF2P8AFFINEINV_CASE(24)  GF2P8AFFINEINV_CASE(25)  GF2P8AFFINEINV_CASE(26)  GF2P8AFFINEINV_CASE(27)
    GF2P8AFFINEINV_CASE(28)  GF2P8AFFINEINV_CASE(29)  GF2P8AFFINEINV_CASE(30)  GF2P8AFFINEINV_CASE(31)
    GF2P8AFFINEINV_CASE(32)  GF2P8AFFINEINV_CASE(33)  GF2P8AFFINEINV_CASE(34)  GF2P8AFFINEINV_CASE(35)
    GF2P8AFFINEINV_CASE(36)  GF2P8AFFINEINV_CASE(37)  GF2P8AFFINEINV_CASE(38)  GF2P8AFFINEINV_CASE(39)
    GF2P8AFFINEINV_CASE(40)  GF2P8AFFINEINV_CASE(41)  GF2P8AFFINEINV_CASE(42)  GF2P8AFFINEINV_CASE(43)
    GF2P8AFFINEINV_CASE(44)  GF2P8AFFINEINV_CASE(45)  GF2P8AFFINEINV_CASE(46)  GF2P8AFFINEINV_CASE(47)
    GF2P8AFFINEINV_CASE(48)  GF2P8AFFINEINV_CASE(49)  GF2P8AFFINEINV_CASE(50)  GF2P8AFFINEINV_CASE(51)
    GF2P8AFFINEINV_CASE(52)  GF2P8AFFINEINV_CASE(53)  GF2P8AFFINEINV_CASE(54)  GF2P8AFFINEINV_CASE(55)
    GF2P8AFFINEINV_CASE(56)  GF2P8AFFINEINV_CASE(57)  GF2P8AFFINEINV_CASE(58)  GF2P8AFFINEINV_CASE(59)
    GF2P8AFFINEINV_CASE(60)  GF2P8AFFINEINV_CASE(61)  GF2P8AFFINEINV_CASE(62)  GF2P8AFFINEINV_CASE(63)
    GF2P8AFFINEINV_CASE(64)  GF2P8AFFINEINV_CASE(65)  GF2P8AFFINEINV_CASE(66)  GF2P8AFFINEINV_CASE(67)
    GF2P8AFFINEINV_CASE(68)  GF2P8AFFINEINV_CASE(69)  GF2P8AFFINEINV_CASE(70)  GF2P8AFFINEINV_CASE(71)
    GF2P8AFFINEINV_CASE(72)  GF2P8AFFINEINV_CASE(73)  GF2P8AFFINEINV_CASE(74)  GF2P8AFFINEINV_CASE(75)
    GF2P8AFFINEINV_CASE(76)  GF2P8AFFINEINV_CASE(77)  GF2P8AFFINEINV_CASE(78)  GF2P8AFFINEINV_CASE(79)
    GF2P8AFFINEINV_CASE(80)  GF2P8AFFINEINV_CASE(81)  GF2P8AFFINEINV_CASE(82)  GF2P8AFFINEINV_CASE(83)
    GF2P8AFFINEINV_CASE(84)  GF2P8AFFINEINV_CASE(85)  GF2P8AFFINEINV_CASE(86)  GF2P8AFFINEINV_CASE(87)
    GF2P8AFFINEINV_CASE(88)  GF2P8AFFINEINV_CASE(89)  GF2P8AFFINEINV_CASE(90)  GF2P8AFFINEINV_CASE(91)
    GF2P8AFFINEINV_CASE(92)  GF2P8AFFINEINV_CASE(93)  GF2P8AFFINEINV_CASE(94)  GF2P8AFFINEINV_CASE(95)
    GF2P8AFFINEINV_CASE(96)  GF2P8AFFINEINV_CASE(97)  GF2P8AFFINEINV_CASE(98)  GF2P8AFFINEINV_CASE(99)
    GF2P8AFFINEINV_CASE(100) GF2P8AFFINEINV_CASE(101) GF2P8AFFINEINV_CASE(102) GF2P8AFFINEINV_CASE(103)
    GF2P8AFFINEINV_CASE(104) GF2P8AFFINEINV_CASE(105) GF2P8AFFINEINV_CASE(106) GF2P8AFFINEINV_CASE(107)
    GF2P8AFFINEINV_CASE(108) GF2P8AFFINEINV_CASE(109) GF2P8AFFINEINV_CASE(110) GF2P8AFFINEINV_CASE(111)
    GF2P8AFFINEINV_CASE(112) GF2P8AFFINEINV_CASE(113) GF2P8AFFINEINV_CASE(114) GF2P8AFFINEINV_CASE(115)
    GF2P8AFFINEINV_CASE(116) GF2P8AFFINEINV_CASE(117) GF2P8AFFINEINV_CASE(118) GF2P8AFFINEINV_CASE(119)
    GF2P8AFFINEINV_CASE(120) GF2P8AFFINEINV_CASE(121) GF2P8AFFINEINV_CASE(122) GF2P8AFFINEINV_CASE(123)
    GF2P8AFFINEINV_CASE(124) GF2P8AFFINEINV_CASE(125) GF2P8AFFINEINV_CASE(126) GF2P8AFFINEINV_CASE(127)
    GF2P8AFFINEINV_CASE(128) GF2P8AFFINEINV_CASE(129) GF2P8AFFINEINV_CASE(130) GF2P8AFFINEINV_CASE(131)
    GF2P8AFFINEINV_CASE(132) GF2P8AFFINEINV_CASE(133) GF2P8AFFINEINV_CASE(134) GF2P8AFFINEINV_CASE(135)
    GF2P8AFFINEINV_CASE(136) GF2P8AFFINEINV_CASE(137) GF2P8AFFINEINV_CASE(138) GF2P8AFFINEINV_CASE(139)
    GF2P8AFFINEINV_CASE(140) GF2P8AFFINEINV_CASE(141) GF2P8AFFINEINV_CASE(142) GF2P8AFFINEINV_CASE(143)
    GF2P8AFFINEINV_CASE(144) GF2P8AFFINEINV_CASE(145) GF2P8AFFINEINV_CASE(146) GF2P8AFFINEINV_CASE(147)
    GF2P8AFFINEINV_CASE(148) GF2P8AFFINEINV_CASE(149) GF2P8AFFINEINV_CASE(150) GF2P8AFFINEINV_CASE(151)
    GF2P8AFFINEINV_CASE(152) GF2P8AFFINEINV_CASE(153) GF2P8AFFINEINV_CASE(154) GF2P8AFFINEINV_CASE(155)
    GF2P8AFFINEINV_CASE(156) GF2P8AFFINEINV_CASE(157) GF2P8AFFINEINV_CASE(158) GF2P8AFFINEINV_CASE(159)
    GF2P8AFFINEINV_CASE(160) GF2P8AFFINEINV_CASE(161) GF2P8AFFINEINV_CASE(162) GF2P8AFFINEINV_CASE(163)
    GF2P8AFFINEINV_CASE(164) GF2P8AFFINEINV_CASE(165) GF2P8AFFINEINV_CASE(166) GF2P8AFFINEINV_CASE(167)
    GF2P8AFFINEINV_CASE(168) GF2P8AFFINEINV_CASE(169) GF2P8AFFINEINV_CASE(170) GF2P8AFFINEINV_CASE(171)
    GF2P8AFFINEINV_CASE(172) GF2P8AFFINEINV_CASE(173) GF2P8AFFINEINV_CASE(174) GF2P8AFFINEINV_CASE(175)
    GF2P8AFFINEINV_CASE(176) GF2P8AFFINEINV_CASE(177) GF2P8AFFINEINV_CASE(178) GF2P8AFFINEINV_CASE(179)
    GF2P8AFFINEINV_CASE(180) GF2P8AFFINEINV_CASE(181) GF2P8AFFINEINV_CASE(182) GF2P8AFFINEINV_CASE(183)
    GF2P8AFFINEINV_CASE(184) GF2P8AFFINEINV_CASE(185) GF2P8AFFINEINV_CASE(186) GF2P8AFFINEINV_CASE(187)
    GF2P8AFFINEINV_CASE(188) GF2P8AFFINEINV_CASE(189) GF2P8AFFINEINV_CASE(190) GF2P8AFFINEINV_CASE(191)
    GF2P8AFFINEINV_CASE(192) GF2P8AFFINEINV_CASE(193) GF2P8AFFINEINV_CASE(194) GF2P8AFFINEINV_CASE(195)
    GF2P8AFFINEINV_CASE(196) GF2P8AFFINEINV_CASE(197) GF2P8AFFINEINV_CASE(198) GF2P8AFFINEINV_CASE(199)
    GF2P8AFFINEINV_CASE(200) GF2P8AFFINEINV_CASE(201) GF2P8AFFINEINV_CASE(202) GF2P8AFFINEINV_CASE(203)
    GF2P8AFFINEINV_CASE(204) GF2P8AFFINEINV_CASE(205) GF2P8AFFINEINV_CASE(206) GF2P8AFFINEINV_CASE(207)
    GF2P8AFFINEINV_CASE(208) GF2P8AFFINEINV_CASE(209) GF2P8AFFINEINV_CASE(210) GF2P8AFFINEINV_CASE(211)
    GF2P8AFFINEINV_CASE(212) GF2P8AFFINEINV_CASE(213) GF2P8AFFINEINV_CASE(214) GF2P8AFFINEINV_CASE(215)
    GF2P8AFFINEINV_CASE(216) GF2P8AFFINEINV_CASE(217) GF2P8AFFINEINV_CASE(218) GF2P8AFFINEINV_CASE(219)
    GF2P8AFFINEINV_CASE(220) GF2P8AFFINEINV_CASE(221) GF2P8AFFINEINV_CASE(222) GF2P8AFFINEINV_CASE(223)
    GF2P8AFFINEINV_CASE(224) GF2P8AFFINEINV_CASE(225) GF2P8AFFINEINV_CASE(226) GF2P8AFFINEINV_CASE(227)
    GF2P8AFFINEINV_CASE(228) GF2P8AFFINEINV_CASE(229) GF2P8AFFINEINV_CASE(230) GF2P8AFFINEINV_CASE(231)
    GF2P8AFFINEINV_CASE(232) GF2P8AFFINEINV_CASE(233) GF2P8AFFINEINV_CASE(234) GF2P8AFFINEINV_CASE(235)
    GF2P8AFFINEINV_CASE(236) GF2P8AFFINEINV_CASE(237) GF2P8AFFINEINV_CASE(238) GF2P8AFFINEINV_CASE(239)
    GF2P8AFFINEINV_CASE(240) GF2P8AFFINEINV_CASE(241) GF2P8AFFINEINV_CASE(242) GF2P8AFFINEINV_CASE(243)
    GF2P8AFFINEINV_CASE(244) GF2P8AFFINEINV_CASE(245) GF2P8AFFINEINV_CASE(246) GF2P8AFFINEINV_CASE(247)
    GF2P8AFFINEINV_CASE(248) GF2P8AFFINEINV_CASE(249) GF2P8AFFINEINV_CASE(250) GF2P8AFFINEINV_CASE(251)
    GF2P8AFFINEINV_CASE(252) GF2P8AFFINEINV_CASE(253) GF2P8AFFINEINV_CASE(254) GF2P8AFFINEINV_CASE(255)
  }
  _mm_storeu_si128((__m128i *)r, vr);
  bytes_to_bits(rop, r, 16, 128);
}
#undef GF2P8AFFINEINV_CASE

// =========================================================================
// SHA Extensions
// =========================================================================

void Model::z__sha1rnds4(lbits *rop, lbits src1, lbits src2, u64 imm8) {
  u8 a[16], b[16], r[16];
  bits_to_bytes(src1, a, 16);
  bits_to_bytes(src2, b, 16);
  __m128i va = _mm_loadu_si128((__m128i *)a);
  __m128i vb = _mm_loadu_si128((__m128i *)b);
  __m128i vr;
  switch (imm8 & 3) {
    case 0: vr = _mm_sha1rnds4_epu32(va, vb, 0); break;
    case 1: vr = _mm_sha1rnds4_epu32(va, vb, 1); break;
    case 2: vr = _mm_sha1rnds4_epu32(va, vb, 2); break;
    case 3: vr = _mm_sha1rnds4_epu32(va, vb, 3); break;
  }
  _mm_storeu_si128((__m128i *)r, vr);
  bytes_to_bits(rop, r, 16, 128);
}

void Model::z__sha1nexte(lbits *rop, lbits src1, lbits src2) {
  u8 a[16], b[16], r[16];
  bits_to_bytes(src1, a, 16);
  bits_to_bytes(src2, b, 16);
  __m128i va = _mm_loadu_si128((__m128i *)a);
  __m128i vb = _mm_loadu_si128((__m128i *)b);
  __m128i vr = _mm_sha1nexte_epu32(va, vb);
  _mm_storeu_si128((__m128i *)r, vr);
  bytes_to_bits(rop, r, 16, 128);
}

void Model::z__sha1msg1(lbits *rop, lbits src1, lbits src2) {
  u8 a[16], b[16], r[16];
  bits_to_bytes(src1, a, 16);
  bits_to_bytes(src2, b, 16);
  __m128i va = _mm_loadu_si128((__m128i *)a);
  __m128i vb = _mm_loadu_si128((__m128i *)b);
  __m128i vr = _mm_sha1msg1_epu32(va, vb);
  _mm_storeu_si128((__m128i *)r, vr);
  bytes_to_bits(rop, r, 16, 128);
}

void Model::z__sha1msg2(lbits *rop, lbits src1, lbits src2) {
  u8 a[16], b[16], r[16];
  bits_to_bytes(src1, a, 16);
  bits_to_bytes(src2, b, 16);
  __m128i va = _mm_loadu_si128((__m128i *)a);
  __m128i vb = _mm_loadu_si128((__m128i *)b);
  __m128i vr = _mm_sha1msg2_epu32(va, vb);
  _mm_storeu_si128((__m128i *)r, vr);
  bytes_to_bits(rop, r, 16, 128);
}

void Model::z__sha256rnds2(lbits *rop, lbits src1, lbits src2, lbits xmm0) {
  u8 a[16], b[16], c[16], r[16];
  bits_to_bytes(src1, a, 16);
  bits_to_bytes(src2, b, 16);
  bits_to_bytes(xmm0, c, 16);
  __m128i va = _mm_loadu_si128((__m128i *)a);
  __m128i vb = _mm_loadu_si128((__m128i *)b);
  __m128i vc = _mm_loadu_si128((__m128i *)c);
  __m128i vr = _mm_sha256rnds2_epu32(va, vb, vc);
  _mm_storeu_si128((__m128i *)r, vr);
  bytes_to_bits(rop, r, 16, 128);
}

void Model::z__sha256msg1(lbits *rop, lbits src1, lbits src2) {
  u8 a[16], b[16], r[16];
  bits_to_bytes(src1, a, 16);
  bits_to_bytes(src2, b, 16);
  __m128i va = _mm_loadu_si128((__m128i *)a);
  __m128i vb = _mm_loadu_si128((__m128i *)b);
  __m128i vr = _mm_sha256msg1_epu32(va, vb);
  _mm_storeu_si128((__m128i *)r, vr);
  bytes_to_bits(rop, r, 16, 128);
}

void Model::z__sha256msg2(lbits *rop, lbits src1, lbits src2) {
  u8 a[16], b[16], r[16];
  bits_to_bytes(src1, a, 16);
  bits_to_bytes(src2, b, 16);
  __m128i va = _mm_loadu_si128((__m128i *)a);
  __m128i vb = _mm_loadu_si128((__m128i *)b);
  __m128i vr = _mm_sha256msg2_epu32(va, vb);
  _mm_storeu_si128((__m128i *)r, vr);
  bytes_to_bits(rop, r, 16, 128);
}

// =========================================================================
// PCLMULQDQ
// =========================================================================

void Model::z__pclmulqdq(lbits *rop, u64 a, u64 b) {
  // Carry-less multiplication of two 64-bit values -> 128-bit result
  __m128i va = _mm_set_epi64x(0, a);
  __m128i vb = _mm_set_epi64x(0, b);
  __m128i result = _mm_clmulepi64_si128(va, vb, 0x00);
  u8 r[16];
  _mm_storeu_si128((__m128i *)r, result);
  bytes_to_bits(rop, r, 16, 128);
}

// =========================================================================
// MPSADBW
// =========================================================================

void Model::z__mpsadbw(lbits *rop, lbits src1, lbits src2, u64 imm8) {
  u8 s1[16];
  u8 s2[16];
  u8 r[16];
  bits_to_bytes(src1, s1, 16);
  bits_to_bytes(src2, s2, 16);
  __m128i v1 = _mm_loadu_si128((__m128i *)s1);
  __m128i v2 = _mm_loadu_si128((__m128i *)s2);
  __m128i vr;
  switch (imm8 & 7) {
    case 0: vr = _mm_mpsadbw_epu8(v1, v2, 0); break;
    case 1: vr = _mm_mpsadbw_epu8(v1, v2, 1); break;
    case 2: vr = _mm_mpsadbw_epu8(v1, v2, 2); break;
    case 3: vr = _mm_mpsadbw_epu8(v1, v2, 3); break;
    case 4: vr = _mm_mpsadbw_epu8(v1, v2, 4); break;
    case 5: vr = _mm_mpsadbw_epu8(v1, v2, 5); break;
    case 6: vr = _mm_mpsadbw_epu8(v1, v2, 6); break;
    case 7: vr = _mm_mpsadbw_epu8(v1, v2, 7); break;
    default: vr = _mm_setzero_si128(); break;
  }
  _mm_storeu_si128((__m128i *)r, vr);
  bytes_to_bits(rop, r, 16, 128);
}

// =========================================================================
// PCMPxSTRx (SSE4.2 string instructions)
// =========================================================================

// Use intrinsics for pcmpistri. The imm8 must be a compile-time constant
// for the intrinsic, so we use a macro-based dispatch.
#define PCMPISTRI_CASE(IMM)                     \
  case IMM: {                                   \
    idx = _mm_cmpistri(v1, v2, IMM);            \
    cf = _mm_cmpistrc(v1, v2, IMM);             \
    zf = _mm_cmpistrz(v1, v2, IMM);             \
    sf = _mm_cmpistrs(v1, v2, IMM);             \
    of = _mm_cmpistro(v1, v2, IMM);             \
    break;                                      \
  }

static void pcmpistri_dispatch(const u8 *s1, const u8 *s2, int imm8,
                 u32 &idx, u8 &cf, u8 &zf,
                 u8 &sf, u8 &of) {
  __m128i v1 = _mm_loadu_si128((const __m128i *)s1);
  __m128i v2 = _mm_loadu_si128((const __m128i *)s2);
  switch (imm8 & 0x7f) {
  PCMPISTRI_CASE(0x00) PCMPISTRI_CASE(0x01) PCMPISTRI_CASE(0x02) PCMPISTRI_CASE(0x03)
  PCMPISTRI_CASE(0x04) PCMPISTRI_CASE(0x05) PCMPISTRI_CASE(0x06) PCMPISTRI_CASE(0x07)
  PCMPISTRI_CASE(0x08) PCMPISTRI_CASE(0x09) PCMPISTRI_CASE(0x0a) PCMPISTRI_CASE(0x0b)
  PCMPISTRI_CASE(0x0c) PCMPISTRI_CASE(0x0d) PCMPISTRI_CASE(0x0e) PCMPISTRI_CASE(0x0f)
  PCMPISTRI_CASE(0x10) PCMPISTRI_CASE(0x11) PCMPISTRI_CASE(0x12) PCMPISTRI_CASE(0x13)
  PCMPISTRI_CASE(0x14) PCMPISTRI_CASE(0x15) PCMPISTRI_CASE(0x16) PCMPISTRI_CASE(0x17)
  PCMPISTRI_CASE(0x18) PCMPISTRI_CASE(0x19) PCMPISTRI_CASE(0x1a) PCMPISTRI_CASE(0x1b)
  PCMPISTRI_CASE(0x1c) PCMPISTRI_CASE(0x1d) PCMPISTRI_CASE(0x1e) PCMPISTRI_CASE(0x1f)
  PCMPISTRI_CASE(0x20) PCMPISTRI_CASE(0x21) PCMPISTRI_CASE(0x22) PCMPISTRI_CASE(0x23)
  PCMPISTRI_CASE(0x24) PCMPISTRI_CASE(0x25) PCMPISTRI_CASE(0x26) PCMPISTRI_CASE(0x27)
  PCMPISTRI_CASE(0x28) PCMPISTRI_CASE(0x29) PCMPISTRI_CASE(0x2a) PCMPISTRI_CASE(0x2b)
  PCMPISTRI_CASE(0x2c) PCMPISTRI_CASE(0x2d) PCMPISTRI_CASE(0x2e) PCMPISTRI_CASE(0x2f)
  PCMPISTRI_CASE(0x30) PCMPISTRI_CASE(0x31) PCMPISTRI_CASE(0x32) PCMPISTRI_CASE(0x33)
  PCMPISTRI_CASE(0x34) PCMPISTRI_CASE(0x35) PCMPISTRI_CASE(0x36) PCMPISTRI_CASE(0x37)
  PCMPISTRI_CASE(0x38) PCMPISTRI_CASE(0x39) PCMPISTRI_CASE(0x3a) PCMPISTRI_CASE(0x3b)
  PCMPISTRI_CASE(0x3c) PCMPISTRI_CASE(0x3d) PCMPISTRI_CASE(0x3e) PCMPISTRI_CASE(0x3f)
  PCMPISTRI_CASE(0x40) PCMPISTRI_CASE(0x41) PCMPISTRI_CASE(0x42) PCMPISTRI_CASE(0x43)
  PCMPISTRI_CASE(0x44) PCMPISTRI_CASE(0x45) PCMPISTRI_CASE(0x46) PCMPISTRI_CASE(0x47)
  PCMPISTRI_CASE(0x48) PCMPISTRI_CASE(0x49) PCMPISTRI_CASE(0x4a) PCMPISTRI_CASE(0x4b)
  PCMPISTRI_CASE(0x4c) PCMPISTRI_CASE(0x4d) PCMPISTRI_CASE(0x4e) PCMPISTRI_CASE(0x4f)
  PCMPISTRI_CASE(0x50) PCMPISTRI_CASE(0x51) PCMPISTRI_CASE(0x52) PCMPISTRI_CASE(0x53)
  PCMPISTRI_CASE(0x54) PCMPISTRI_CASE(0x55) PCMPISTRI_CASE(0x56) PCMPISTRI_CASE(0x57)
  PCMPISTRI_CASE(0x58) PCMPISTRI_CASE(0x59) PCMPISTRI_CASE(0x5a) PCMPISTRI_CASE(0x5b)
  PCMPISTRI_CASE(0x5c) PCMPISTRI_CASE(0x5d) PCMPISTRI_CASE(0x5e) PCMPISTRI_CASE(0x5f)
  PCMPISTRI_CASE(0x60) PCMPISTRI_CASE(0x61) PCMPISTRI_CASE(0x62) PCMPISTRI_CASE(0x63)
  PCMPISTRI_CASE(0x64) PCMPISTRI_CASE(0x65) PCMPISTRI_CASE(0x66) PCMPISTRI_CASE(0x67)
  PCMPISTRI_CASE(0x68) PCMPISTRI_CASE(0x69) PCMPISTRI_CASE(0x6a) PCMPISTRI_CASE(0x6b)
  PCMPISTRI_CASE(0x6c) PCMPISTRI_CASE(0x6d) PCMPISTRI_CASE(0x6e) PCMPISTRI_CASE(0x6f)
  PCMPISTRI_CASE(0x70) PCMPISTRI_CASE(0x71) PCMPISTRI_CASE(0x72) PCMPISTRI_CASE(0x73)
  PCMPISTRI_CASE(0x74) PCMPISTRI_CASE(0x75) PCMPISTRI_CASE(0x76) PCMPISTRI_CASE(0x77)
  PCMPISTRI_CASE(0x78) PCMPISTRI_CASE(0x79) PCMPISTRI_CASE(0x7a) PCMPISTRI_CASE(0x7b)
  PCMPISTRI_CASE(0x7c) PCMPISTRI_CASE(0x7d) PCMPISTRI_CASE(0x7e) PCMPISTRI_CASE(0x7f)
  default: idx = 16; cf = 0; zf = 0; sf = 0; of = 0; break;
  }
}
#undef PCMPISTRI_CASE

// Same approach for pcmpestri
#define PCMPESTRI_CASE(IMM)                     \
  case IMM: {                                   \
    idx = _mm_cmpestri(v1, la, v2, lb, IMM);    \
    cf = _mm_cmpestrc(v1, la, v2, lb, IMM);     \
    zf = _mm_cmpestrz(v1, la, v2, lb, IMM);     \
    sf = _mm_cmpestrs(v1, la, v2, lb, IMM);     \
    of = _mm_cmpestro(v1, la, v2, lb, IMM);     \
    break;                                      \
  }

static void pcmpestri_dispatch(const u8 *s1, int la, const u8 *s2, int lb,
                 int imm8, u32 &idx, u8 &cf, u8 &zf,
                 u8 &sf, u8 &of) {
  __m128i v1 = _mm_loadu_si128((const __m128i *)s1);
  __m128i v2 = _mm_loadu_si128((const __m128i *)s2);
  switch (imm8 & 0x7f) {
  PCMPESTRI_CASE(0x00) PCMPESTRI_CASE(0x01) PCMPESTRI_CASE(0x02) PCMPESTRI_CASE(0x03)
  PCMPESTRI_CASE(0x04) PCMPESTRI_CASE(0x05) PCMPESTRI_CASE(0x06) PCMPESTRI_CASE(0x07)
  PCMPESTRI_CASE(0x08) PCMPESTRI_CASE(0x09) PCMPESTRI_CASE(0x0a) PCMPESTRI_CASE(0x0b)
  PCMPESTRI_CASE(0x0c) PCMPESTRI_CASE(0x0d) PCMPESTRI_CASE(0x0e) PCMPESTRI_CASE(0x0f)
  PCMPESTRI_CASE(0x10) PCMPESTRI_CASE(0x11) PCMPESTRI_CASE(0x12) PCMPESTRI_CASE(0x13)
  PCMPESTRI_CASE(0x14) PCMPESTRI_CASE(0x15) PCMPESTRI_CASE(0x16) PCMPESTRI_CASE(0x17)
  PCMPESTRI_CASE(0x18) PCMPESTRI_CASE(0x19) PCMPESTRI_CASE(0x1a) PCMPESTRI_CASE(0x1b)
  PCMPESTRI_CASE(0x1c) PCMPESTRI_CASE(0x1d) PCMPESTRI_CASE(0x1e) PCMPESTRI_CASE(0x1f)
  PCMPESTRI_CASE(0x20) PCMPESTRI_CASE(0x21) PCMPESTRI_CASE(0x22) PCMPESTRI_CASE(0x23)
  PCMPESTRI_CASE(0x24) PCMPESTRI_CASE(0x25) PCMPESTRI_CASE(0x26) PCMPESTRI_CASE(0x27)
  PCMPESTRI_CASE(0x28) PCMPESTRI_CASE(0x29) PCMPESTRI_CASE(0x2a) PCMPESTRI_CASE(0x2b)
  PCMPESTRI_CASE(0x2c) PCMPESTRI_CASE(0x2d) PCMPESTRI_CASE(0x2e) PCMPESTRI_CASE(0x2f)
  PCMPESTRI_CASE(0x30) PCMPESTRI_CASE(0x31) PCMPESTRI_CASE(0x32) PCMPESTRI_CASE(0x33)
  PCMPESTRI_CASE(0x34) PCMPESTRI_CASE(0x35) PCMPESTRI_CASE(0x36) PCMPESTRI_CASE(0x37)
  PCMPESTRI_CASE(0x38) PCMPESTRI_CASE(0x39) PCMPESTRI_CASE(0x3a) PCMPESTRI_CASE(0x3b)
  PCMPESTRI_CASE(0x3c) PCMPESTRI_CASE(0x3d) PCMPESTRI_CASE(0x3e) PCMPESTRI_CASE(0x3f)
  PCMPESTRI_CASE(0x40) PCMPESTRI_CASE(0x41) PCMPESTRI_CASE(0x42) PCMPESTRI_CASE(0x43)
  PCMPESTRI_CASE(0x44) PCMPESTRI_CASE(0x45) PCMPESTRI_CASE(0x46) PCMPESTRI_CASE(0x47)
  PCMPESTRI_CASE(0x48) PCMPESTRI_CASE(0x49) PCMPESTRI_CASE(0x4a) PCMPESTRI_CASE(0x4b)
  PCMPESTRI_CASE(0x4c) PCMPESTRI_CASE(0x4d) PCMPESTRI_CASE(0x4e) PCMPESTRI_CASE(0x4f)
  PCMPESTRI_CASE(0x50) PCMPESTRI_CASE(0x51) PCMPESTRI_CASE(0x52) PCMPESTRI_CASE(0x53)
  PCMPESTRI_CASE(0x54) PCMPESTRI_CASE(0x55) PCMPESTRI_CASE(0x56) PCMPESTRI_CASE(0x57)
  PCMPESTRI_CASE(0x58) PCMPESTRI_CASE(0x59) PCMPESTRI_CASE(0x5a) PCMPESTRI_CASE(0x5b)
  PCMPESTRI_CASE(0x5c) PCMPESTRI_CASE(0x5d) PCMPESTRI_CASE(0x5e) PCMPESTRI_CASE(0x5f)
  PCMPESTRI_CASE(0x60) PCMPESTRI_CASE(0x61) PCMPESTRI_CASE(0x62) PCMPESTRI_CASE(0x63)
  PCMPESTRI_CASE(0x64) PCMPESTRI_CASE(0x65) PCMPESTRI_CASE(0x66) PCMPESTRI_CASE(0x67)
  PCMPESTRI_CASE(0x68) PCMPESTRI_CASE(0x69) PCMPESTRI_CASE(0x6a) PCMPESTRI_CASE(0x6b)
  PCMPESTRI_CASE(0x6c) PCMPESTRI_CASE(0x6d) PCMPESTRI_CASE(0x6e) PCMPESTRI_CASE(0x6f)
  PCMPESTRI_CASE(0x70) PCMPESTRI_CASE(0x71) PCMPESTRI_CASE(0x72) PCMPESTRI_CASE(0x73)
  PCMPESTRI_CASE(0x74) PCMPESTRI_CASE(0x75) PCMPESTRI_CASE(0x76) PCMPESTRI_CASE(0x77)
  PCMPESTRI_CASE(0x78) PCMPESTRI_CASE(0x79) PCMPESTRI_CASE(0x7a) PCMPESTRI_CASE(0x7b)
  PCMPESTRI_CASE(0x7c) PCMPESTRI_CASE(0x7d) PCMPESTRI_CASE(0x7e) PCMPESTRI_CASE(0x7f)
  default: idx = 16; cf = 0; zf = 0; sf = 0; of = 0; break;
  }
}
#undef PCMPESTRI_CASE

// Same approach for pcmpistrm / pcmpestrm
#define PCMPISTRM_CASE(IMM)                     \
  case IMM: {                                   \
    vr = _mm_cmpistrm(v1, v2, IMM);             \
    cf = _mm_cmpistrc(v1, v2, IMM);             \
    zf = _mm_cmpistrz(v1, v2, IMM);             \
    sf = _mm_cmpistrs(v1, v2, IMM);             \
    of = _mm_cmpistro(v1, v2, IMM);             \
    break;                                      \
  }

static void pcmpistrm_dispatch(const u8 *s1, const u8 *s2, int imm8,
                 u8 *result_bytes, u8 &cf, u8 &zf,
                 u8 &sf, u8 &of) {
  __m128i v1 = _mm_loadu_si128((const __m128i *)s1);
  __m128i v2 = _mm_loadu_si128((const __m128i *)s2);
  __m128i vr = _mm_setzero_si128();
  switch (imm8 & 0x7f) {
  PCMPISTRM_CASE(0x00) PCMPISTRM_CASE(0x01) PCMPISTRM_CASE(0x02) PCMPISTRM_CASE(0x03)
  PCMPISTRM_CASE(0x04) PCMPISTRM_CASE(0x05) PCMPISTRM_CASE(0x06) PCMPISTRM_CASE(0x07)
  PCMPISTRM_CASE(0x08) PCMPISTRM_CASE(0x09) PCMPISTRM_CASE(0x0a) PCMPISTRM_CASE(0x0b)
  PCMPISTRM_CASE(0x0c) PCMPISTRM_CASE(0x0d) PCMPISTRM_CASE(0x0e) PCMPISTRM_CASE(0x0f)
  PCMPISTRM_CASE(0x10) PCMPISTRM_CASE(0x11) PCMPISTRM_CASE(0x12) PCMPISTRM_CASE(0x13)
  PCMPISTRM_CASE(0x14) PCMPISTRM_CASE(0x15) PCMPISTRM_CASE(0x16) PCMPISTRM_CASE(0x17)
  PCMPISTRM_CASE(0x18) PCMPISTRM_CASE(0x19) PCMPISTRM_CASE(0x1a) PCMPISTRM_CASE(0x1b)
  PCMPISTRM_CASE(0x1c) PCMPISTRM_CASE(0x1d) PCMPISTRM_CASE(0x1e) PCMPISTRM_CASE(0x1f)
  PCMPISTRM_CASE(0x20) PCMPISTRM_CASE(0x21) PCMPISTRM_CASE(0x22) PCMPISTRM_CASE(0x23)
  PCMPISTRM_CASE(0x24) PCMPISTRM_CASE(0x25) PCMPISTRM_CASE(0x26) PCMPISTRM_CASE(0x27)
  PCMPISTRM_CASE(0x28) PCMPISTRM_CASE(0x29) PCMPISTRM_CASE(0x2a) PCMPISTRM_CASE(0x2b)
  PCMPISTRM_CASE(0x2c) PCMPISTRM_CASE(0x2d) PCMPISTRM_CASE(0x2e) PCMPISTRM_CASE(0x2f)
  PCMPISTRM_CASE(0x30) PCMPISTRM_CASE(0x31) PCMPISTRM_CASE(0x32) PCMPISTRM_CASE(0x33)
  PCMPISTRM_CASE(0x34) PCMPISTRM_CASE(0x35) PCMPISTRM_CASE(0x36) PCMPISTRM_CASE(0x37)
  PCMPISTRM_CASE(0x38) PCMPISTRM_CASE(0x39) PCMPISTRM_CASE(0x3a) PCMPISTRM_CASE(0x3b)
  PCMPISTRM_CASE(0x3c) PCMPISTRM_CASE(0x3d) PCMPISTRM_CASE(0x3e) PCMPISTRM_CASE(0x3f)
  PCMPISTRM_CASE(0x40) PCMPISTRM_CASE(0x41) PCMPISTRM_CASE(0x42) PCMPISTRM_CASE(0x43)
  PCMPISTRM_CASE(0x44) PCMPISTRM_CASE(0x45) PCMPISTRM_CASE(0x46) PCMPISTRM_CASE(0x47)
  PCMPISTRM_CASE(0x48) PCMPISTRM_CASE(0x49) PCMPISTRM_CASE(0x4a) PCMPISTRM_CASE(0x4b)
  PCMPISTRM_CASE(0x4c) PCMPISTRM_CASE(0x4d) PCMPISTRM_CASE(0x4e) PCMPISTRM_CASE(0x4f)
  PCMPISTRM_CASE(0x50) PCMPISTRM_CASE(0x51) PCMPISTRM_CASE(0x52) PCMPISTRM_CASE(0x53)
  PCMPISTRM_CASE(0x54) PCMPISTRM_CASE(0x55) PCMPISTRM_CASE(0x56) PCMPISTRM_CASE(0x57)
  PCMPISTRM_CASE(0x58) PCMPISTRM_CASE(0x59) PCMPISTRM_CASE(0x5a) PCMPISTRM_CASE(0x5b)
  PCMPISTRM_CASE(0x5c) PCMPISTRM_CASE(0x5d) PCMPISTRM_CASE(0x5e) PCMPISTRM_CASE(0x5f)
  PCMPISTRM_CASE(0x60) PCMPISTRM_CASE(0x61) PCMPISTRM_CASE(0x62) PCMPISTRM_CASE(0x63)
  PCMPISTRM_CASE(0x64) PCMPISTRM_CASE(0x65) PCMPISTRM_CASE(0x66) PCMPISTRM_CASE(0x67)
  PCMPISTRM_CASE(0x68) PCMPISTRM_CASE(0x69) PCMPISTRM_CASE(0x6a) PCMPISTRM_CASE(0x6b)
  PCMPISTRM_CASE(0x6c) PCMPISTRM_CASE(0x6d) PCMPISTRM_CASE(0x6e) PCMPISTRM_CASE(0x6f)
  PCMPISTRM_CASE(0x70) PCMPISTRM_CASE(0x71) PCMPISTRM_CASE(0x72) PCMPISTRM_CASE(0x73)
  PCMPISTRM_CASE(0x74) PCMPISTRM_CASE(0x75) PCMPISTRM_CASE(0x76) PCMPISTRM_CASE(0x77)
  PCMPISTRM_CASE(0x78) PCMPISTRM_CASE(0x79) PCMPISTRM_CASE(0x7a) PCMPISTRM_CASE(0x7b)
  PCMPISTRM_CASE(0x7c) PCMPISTRM_CASE(0x7d) PCMPISTRM_CASE(0x7e) PCMPISTRM_CASE(0x7f)
  default: cf = 0; zf = 0; sf = 0; of = 0; break;
  }
  _mm_storeu_si128((__m128i *)result_bytes, vr);
}
#undef PCMPISTRM_CASE

#define PCMESTRM_CASE(IMM)                      \
  case IMM: {                                   \
    vr = _mm_cmpestrm(v1, la, v2, lb, IMM);     \
    cf = _mm_cmpestrc(v1, la, v2, lb, IMM);     \
    zf = _mm_cmpestrz(v1, la, v2, lb, IMM);     \
    sf = _mm_cmpestrs(v1, la, v2, lb, IMM);     \
    of = _mm_cmpestro(v1, la, v2, lb, IMM);     \
    break;                                      \
  }

static void pcmestrm_dispatch(const u8 *s1, int la, const u8 *s2, int lb,
                int imm8, u8 *result_bytes, u8 &cf, u8 &zf,
                u8 &sf, u8 &of) {
  __m128i v1 = _mm_loadu_si128((const __m128i *)s1);
  __m128i v2 = _mm_loadu_si128((const __m128i *)s2);
  __m128i vr = _mm_setzero_si128();
  switch (imm8 & 0x7f) {
  PCMESTRM_CASE(0x00) PCMESTRM_CASE(0x01) PCMESTRM_CASE(0x02) PCMESTRM_CASE(0x03)
  PCMESTRM_CASE(0x04) PCMESTRM_CASE(0x05) PCMESTRM_CASE(0x06) PCMESTRM_CASE(0x07)
  PCMESTRM_CASE(0x08) PCMESTRM_CASE(0x09) PCMESTRM_CASE(0x0a) PCMESTRM_CASE(0x0b)
  PCMESTRM_CASE(0x0c) PCMESTRM_CASE(0x0d) PCMESTRM_CASE(0x0e) PCMESTRM_CASE(0x0f)
  PCMESTRM_CASE(0x10) PCMESTRM_CASE(0x11) PCMESTRM_CASE(0x12) PCMESTRM_CASE(0x13)
  PCMESTRM_CASE(0x14) PCMESTRM_CASE(0x15) PCMESTRM_CASE(0x16) PCMESTRM_CASE(0x17)
  PCMESTRM_CASE(0x18) PCMESTRM_CASE(0x19) PCMESTRM_CASE(0x1a) PCMESTRM_CASE(0x1b)
  PCMESTRM_CASE(0x1c) PCMESTRM_CASE(0x1d) PCMESTRM_CASE(0x1e) PCMESTRM_CASE(0x1f)
  PCMESTRM_CASE(0x20) PCMESTRM_CASE(0x21) PCMESTRM_CASE(0x22) PCMESTRM_CASE(0x23)
  PCMESTRM_CASE(0x24) PCMESTRM_CASE(0x25) PCMESTRM_CASE(0x26) PCMESTRM_CASE(0x27)
  PCMESTRM_CASE(0x28) PCMESTRM_CASE(0x29) PCMESTRM_CASE(0x2a) PCMESTRM_CASE(0x2b)
  PCMESTRM_CASE(0x2c) PCMESTRM_CASE(0x2d) PCMESTRM_CASE(0x2e) PCMESTRM_CASE(0x2f)
  PCMESTRM_CASE(0x30) PCMESTRM_CASE(0x31) PCMESTRM_CASE(0x32) PCMESTRM_CASE(0x33)
  PCMESTRM_CASE(0x34) PCMESTRM_CASE(0x35) PCMESTRM_CASE(0x36) PCMESTRM_CASE(0x37)
  PCMESTRM_CASE(0x38) PCMESTRM_CASE(0x39) PCMESTRM_CASE(0x3a) PCMESTRM_CASE(0x3b)
  PCMESTRM_CASE(0x3c) PCMESTRM_CASE(0x3d) PCMESTRM_CASE(0x3e) PCMESTRM_CASE(0x3f)
  PCMESTRM_CASE(0x40) PCMESTRM_CASE(0x41) PCMESTRM_CASE(0x42) PCMESTRM_CASE(0x43)
  PCMESTRM_CASE(0x44) PCMESTRM_CASE(0x45) PCMESTRM_CASE(0x46) PCMESTRM_CASE(0x47)
  PCMESTRM_CASE(0x48) PCMESTRM_CASE(0x49) PCMESTRM_CASE(0x4a) PCMESTRM_CASE(0x4b)
  PCMESTRM_CASE(0x4c) PCMESTRM_CASE(0x4d) PCMESTRM_CASE(0x4e) PCMESTRM_CASE(0x4f)
  PCMESTRM_CASE(0x50) PCMESTRM_CASE(0x51) PCMESTRM_CASE(0x52) PCMESTRM_CASE(0x53)
  PCMESTRM_CASE(0x54) PCMESTRM_CASE(0x55) PCMESTRM_CASE(0x56) PCMESTRM_CASE(0x57)
  PCMESTRM_CASE(0x58) PCMESTRM_CASE(0x59) PCMESTRM_CASE(0x5a) PCMESTRM_CASE(0x5b)
  PCMESTRM_CASE(0x5c) PCMESTRM_CASE(0x5d) PCMESTRM_CASE(0x5e) PCMESTRM_CASE(0x5f)
  PCMESTRM_CASE(0x60) PCMESTRM_CASE(0x61) PCMESTRM_CASE(0x62) PCMESTRM_CASE(0x63)
  PCMESTRM_CASE(0x64) PCMESTRM_CASE(0x65) PCMESTRM_CASE(0x66) PCMESTRM_CASE(0x67)
  PCMESTRM_CASE(0x68) PCMESTRM_CASE(0x69) PCMESTRM_CASE(0x6a) PCMESTRM_CASE(0x6b)
  PCMESTRM_CASE(0x6c) PCMESTRM_CASE(0x6d) PCMESTRM_CASE(0x6e) PCMESTRM_CASE(0x6f)
  PCMESTRM_CASE(0x70) PCMESTRM_CASE(0x71) PCMESTRM_CASE(0x72) PCMESTRM_CASE(0x73)
  PCMESTRM_CASE(0x74) PCMESTRM_CASE(0x75) PCMESTRM_CASE(0x76) PCMESTRM_CASE(0x77)
  PCMESTRM_CASE(0x78) PCMESTRM_CASE(0x79) PCMESTRM_CASE(0x7a) PCMESTRM_CASE(0x7b)
  PCMESTRM_CASE(0x7c) PCMESTRM_CASE(0x7d) PCMESTRM_CASE(0x7e) PCMESTRM_CASE(0x7f)
  default: cf = 0; zf = 0; sf = 0; of = 0; break;
  }
  _mm_storeu_si128((__m128i *)result_bytes, vr);
}
#undef PCMESTRM_CASE

struct ztuple_z8z5bv32zCz0z5bv1zCz0z5bv1zCz0z5bv1zCz0z5bv1z9
Model::z__pcmpestri(lbits src1, u64 len1, lbits src2, u64 len2, u64 imm8) {
  u8 s1[16];
  u8 s2[16];
  bits_to_bytes(src1, s1, 16);
  bits_to_bytes(src2, s2, 16);
  u32 idx;
  u8 cf;
  u8 zf;
  u8 sf;
  u8 of;
  pcmpestri_dispatch(s1, (int)len1, s2, (int)len2, (int)imm8, idx, cf, zf, sf, of);
  struct ztuple_z8z5bv32zCz0z5bv1zCz0z5bv1zCz0z5bv1zCz0z5bv1z9 result;
  result.ztup0 = idx;
  result.ztup1 = cf;
  result.ztup2 = zf;
  result.ztup3 = sf;
  result.ztup4 = of;
  return result;
}

struct ztuple_z8z5bv32zCz0z5bv1zCz0z5bv1zCz0z5bv1zCz0z5bv1z9
Model::z__pcmpistri(lbits src1, lbits src2, u64 imm8) {
  u8 s1[16];
  u8 s2[16];
  bits_to_bytes(src1, s1, 16);
  bits_to_bytes(src2, s2, 16);
  u32 idx;
  u8 cf;
  u8 zf;
  u8 sf;
  u8 of;
  pcmpistri_dispatch(s1, s2, (int)imm8, idx, cf, zf, sf, of);
  struct ztuple_z8z5bv32zCz0z5bv1zCz0z5bv1zCz0z5bv1zCz0z5bv1z9 result;
  result.ztup0 = idx;
  result.ztup1 = cf;
  result.ztup2 = zf;
  result.ztup3 = sf;
  result.ztup4 = of;
  return result;
}

void Model::z__pcmpestrm(struct ztuple_z8z5bvzCz0z5bv1zCz0z5bv1zCz0z5bv1zCz0z5bv1z9 *rop,
              lbits src1, u64 len1, lbits src2, u64 len2, u64 imm8) {
  u8 s1[16];
  u8 s2[16];
  u8 r[16];
  bits_to_bytes(src1, s1, 16);
  bits_to_bytes(src2, s2, 16);
  u8 cf;
  u8 zf;
  u8 sf;
  u8 of;
  pcmestrm_dispatch(s1, (int)len1, s2, (int)len2, (int)imm8, r, cf, zf, sf, of);
  RECREATE(lbits)(&rop->ztup0);
  bytes_to_bits(&rop->ztup0, r, 16, 128);
  rop->ztup1 = cf;
  rop->ztup2 = zf;
  rop->ztup3 = sf;
  rop->ztup4 = of;
}

void Model::z__pcmpistrm(struct ztuple_z8z5bvzCz0z5bv1zCz0z5bv1zCz0z5bv1zCz0z5bv1z9 *rop,
              lbits src1, lbits src2, u64 imm8) {
  u8 s1[16];
  u8 s2[16];
  u8 r[16];
  bits_to_bytes(src1, s1, 16);
  bits_to_bytes(src2, s2, 16);
  u8 cf;
  u8 zf;
  u8 sf;
  u8 of;
  pcmpistrm_dispatch(s1, s2, (int)imm8, r, cf, zf, sf, of);
  RECREATE(lbits)(&rop->ztup0);
  bytes_to_bits(&rop->ztup0, r, 16, 128);
  rop->ztup1 = cf;
  rop->ztup2 = zf;
  rop->ztup3 = sf;
  rop->ztup4 = of;
}

// =========================================================================
// SYSCALL — handled externally by the emulator run loop
// =========================================================================

unit Model::z__syscall(u64 rip, u64 rflags) {
  // SYSCALL ABI: RCX = return address (next instruction), R11 = saved RFLAGS
  // rip is the address of the SYSCALL instruction itself;
  // zdecode_pos points past it (next instruction address).
  (void)rip;
  zGPR.data[1] = zdecode_pos;  // RCX = next instruction
  zGPR.data[11] = rflags;    // R11 = RFLAGS

  // Advance RIP past the SYSCALL instruction.
  zRIP = zdecode_pos;

  // Signal to the run loop that a syscall happened.
  zsystem_state = zSysSyscall;
  return UNIT;
}

// =========================================================================
// FMA (fused multiply-add) primitives
// =========================================================================

u64 Model::z__f32_fmadd(u64 a, u64 b, u64 c) {
  a = f32_daz_bits(a, mxcsr_state.mxcsr);
  b = f32_daz_bits(b, mxcsr_state.mxcsr);
  c = f32_daz_bits(c, mxcsr_state.mxcsr);
  float fa;
  float fb;
  float fc;
  memcpy(&fa, &a, 4);
  memcpy(&fb, &b, 4);
  memcpy(&fc, &c, 4);
  SYNC_MXCSR_RC();
  float fr = f32_ftz(fmaf(fa, fb, fc), mxcsr_state.mxcsr);
  u32 r;
  memcpy(&r, &fr, 4);
  return r;
}

u64 Model::z__f32_fmsub(u64 a, u64 b, u64 c) {
  a = f32_daz_bits(a, mxcsr_state.mxcsr);
  b = f32_daz_bits(b, mxcsr_state.mxcsr);
  c = f32_daz_bits(c, mxcsr_state.mxcsr);
  float fa;
  float fb;
  float fc;
  memcpy(&fa, &a, 4);
  memcpy(&fb, &b, 4);
  memcpy(&fc, &c, 4);
  SYNC_MXCSR_RC();
  float fr = f32_ftz(fmaf(fa, fb, -fc), mxcsr_state.mxcsr);
  u32 r;
  memcpy(&r, &fr, 4);
  return r;
}

u64 Model::z__f32_fnmadd(u64 a, u64 b, u64 c) {
  a = f32_daz_bits(a, mxcsr_state.mxcsr);
  b = f32_daz_bits(b, mxcsr_state.mxcsr);
  c = f32_daz_bits(c, mxcsr_state.mxcsr);
  float fa;
  float fb;
  float fc;
  memcpy(&fa, &a, 4);
  memcpy(&fb, &b, 4);
  memcpy(&fc, &c, 4);
  SYNC_MXCSR_RC();
  float fr = f32_ftz(fmaf(-fa, fb, fc), mxcsr_state.mxcsr);
  u32 r;
  memcpy(&r, &fr, 4);
  return r;
}

u64 Model::z__f32_fnmsub(u64 a, u64 b, u64 c) {
  a = f32_daz_bits(a, mxcsr_state.mxcsr);
  b = f32_daz_bits(b, mxcsr_state.mxcsr);
  c = f32_daz_bits(c, mxcsr_state.mxcsr);
  float fa;
  float fb;
  float fc;
  memcpy(&fa, &a, 4);
  memcpy(&fb, &b, 4);
  memcpy(&fc, &c, 4);
  SYNC_MXCSR_RC();
  float fr = f32_ftz(fmaf(-fa, fb, -fc), mxcsr_state.mxcsr);
  u32 r;
  memcpy(&r, &fr, 4);
  return r;
}

u64 Model::z__f64_fmadd(u64 a, u64 b, u64 c) {
  a = f64_daz_bits(a, mxcsr_state.mxcsr);
  b = f64_daz_bits(b, mxcsr_state.mxcsr);
  c = f64_daz_bits(c, mxcsr_state.mxcsr);
  double fa;
  double fb;
  double fc;
  memcpy(&fa, &a, 8);
  memcpy(&fb, &b, 8);
  memcpy(&fc, &c, 8);
  SYNC_MXCSR_RC();
  double fr = f64_ftz(fma(fa, fb, fc), mxcsr_state.mxcsr);
  u64 r;
  memcpy(&r, &fr, 8);
  return r;
}

u64 Model::z__f64_fmsub(u64 a, u64 b, u64 c) {
  a = f64_daz_bits(a, mxcsr_state.mxcsr);
  b = f64_daz_bits(b, mxcsr_state.mxcsr);
  c = f64_daz_bits(c, mxcsr_state.mxcsr);
  double fa;
  double fb;
  double fc;
  memcpy(&fa, &a, 8);
  memcpy(&fb, &b, 8);
  memcpy(&fc, &c, 8);
  SYNC_MXCSR_RC();
  double fr = f64_ftz(fma(fa, fb, -fc), mxcsr_state.mxcsr);
  u64 r;
  memcpy(&r, &fr, 8);
  return r;
}

u64 Model::z__f64_fnmadd(u64 a, u64 b, u64 c) {
  a = f64_daz_bits(a, mxcsr_state.mxcsr);
  b = f64_daz_bits(b, mxcsr_state.mxcsr);
  c = f64_daz_bits(c, mxcsr_state.mxcsr);
  double fa;
  double fb;
  double fc;
  memcpy(&fa, &a, 8);
  memcpy(&fb, &b, 8);
  memcpy(&fc, &c, 8);
  SYNC_MXCSR_RC();
  double fr = f64_ftz(fma(-fa, fb, fc), mxcsr_state.mxcsr);
  u64 r;
  memcpy(&r, &fr, 8);
  return r;
}

u64 Model::z__f64_fnmsub(u64 a, u64 b, u64 c) {
  a = f64_daz_bits(a, mxcsr_state.mxcsr);
  b = f64_daz_bits(b, mxcsr_state.mxcsr);
  c = f64_daz_bits(c, mxcsr_state.mxcsr);
  double fa;
  double fb;
  double fc;
  memcpy(&fa, &a, 8);
  memcpy(&fb, &b, 8);
  memcpy(&fc, &c, 8);
  SYNC_MXCSR_RC();
  double fr = f64_ftz(fma(-fa, fb, -fc), mxcsr_state.mxcsr);
  u64 r;
  memcpy(&r, &fr, 8);
  return r;
}

// =========================================================================
// BF16 dot product: dest += make_fp32(src1_hi)*make_fp32(src2_hi)
//                        + make_fp32(src1_lo)*make_fp32(src2_lo)
// Per SDM: always RNE, DAZ in, FTZ out, MXCSR not consulted.
// =========================================================================

u64 Model::z__vdpbf16ps_elem(u64 dst, u64 src1, u64 src2) {
  // Extract BF16 pairs from dword operands
  auto make_fp32 = [](u16 bf16) -> float {
    u32 bits = (u32)bf16 << 16;
    float f;
    memcpy(&f, &bits, 4);
    // DAZ: if denormal, flush to zero (preserve sign)
    if ((bits & 0x7F800000) == 0 && (bits & 0x007FFFFF) != 0) {
      bits &= 0x80000000;
      memcpy(&f, &bits, 4);
    }
    return f;
  };

  u16 s1_lo = (u16)(src1 & 0xFFFF);
  u16 s1_hi = (u16)((src1 >> 16) & 0xFFFF);
  u16 s2_lo = (u16)(src2 & 0xFFFF);
  u16 s2_hi = (u16)((src2 >> 16) & 0xFFFF);

  float fd;
  memcpy(&fd, &dst, 4);
  // DAZ on accumulator input
  u32 dst_bits = (u32)dst;
  if ((dst_bits & 0x7F800000) == 0 && (dst_bits & 0x007FFFFF) != 0) {
    dst_bits &= 0x80000000;
    memcpy(&fd, &dst_bits, 4);
  }

  // Force RNE rounding
  fesetround(FE_TONEAREST);

  // Two multiply-accumulates (not fused per SDM — separate mul + add)
  float p_hi = make_fp32(s1_hi) * make_fp32(s2_hi);
  float p_lo = make_fp32(s1_lo) * make_fp32(s2_lo);
  float result = fd + p_hi + p_lo;

  // FTZ on result
  u32 r;
  memcpy(&r, &result, 4);
  if ((r & 0x7F800000) == 0 && (r & 0x007FFFFF) != 0)
    r &= 0x80000000;
  return r;
}

// =========================================================================
// Unsigned integer ↔ float conversions
// =========================================================================

u64 Model::z__f32_to_uint32_trunc(u64 a) {
  float fa;
  memcpy(&fa, &a, 4);
  if (std::isnan(fa) || fa < 0.0f || fa >= 4294967296.0f) return 0xFFFFFFFF;
  return (u32)fa;
}

u64 Model::z__f32_to_uint32(u64 a) {
  float fa;
  memcpy(&fa, &a, 4);
  SYNC_MXCSR_RC();
  float rounded = rintf(fa);
  if (std::isnan(rounded) || rounded < 0.0f || rounded >= 4294967296.0f) return 0xFFFFFFFF;
  return (u32)rounded;
}

u64 Model::z__f32_to_uint64_trunc(u64 a) {
  float fa;
  memcpy(&fa, &a, 4);
  if (std::isnan(fa) || fa < 0.0f || fa >= 18446744073709551616.0f) return 0xFFFFFFFFFFFFFFFF;
  return (u64)fa;
}

u64 Model::z__f32_to_uint64(u64 a) {
  float fa;
  memcpy(&fa, &a, 4);
  SYNC_MXCSR_RC();
  float rounded = rintf(fa);
  if (std::isnan(rounded) || rounded < 0.0f || rounded >= 18446744073709551616.0f) return 0xFFFFFFFFFFFFFFFF;
  return (u64)rounded;
}

u64 Model::z__f64_to_uint32_trunc(u64 a) {
  double fa;
  memcpy(&fa, &a, 8);
  if (std::isnan(fa) || fa < 0.0 || fa >= 4294967296.0) return 0xFFFFFFFF;
  return (u32)fa;
}

u64 Model::z__f64_to_uint32(u64 a) {
  double fa;
  memcpy(&fa, &a, 8);
  SYNC_MXCSR_RC();
  double rounded = rint(fa);
  if (std::isnan(rounded) || rounded < 0.0 || rounded >= 4294967296.0) return 0xFFFFFFFF;
  return (u32)rounded;
}

u64 Model::z__f64_to_uint64_trunc(u64 a) {
  double fa;
  memcpy(&fa, &a, 8);
  if (std::isnan(fa) || fa < 0.0 || fa >= 18446744073709551616.0) return 0xFFFFFFFFFFFFFFFF;
  return (u64)fa;
}

u64 Model::z__f64_to_uint64(u64 a) {
  double fa;
  memcpy(&fa, &a, 8);
  SYNC_MXCSR_RC();
  double rounded = rint(fa);
  if (std::isnan(rounded) || rounded < 0.0 || rounded >= 18446744073709551616.0) return 0xFFFFFFFFFFFFFFFF;
  return (u64)rounded;
}

u64 Model::z__uint32_to_f32(u64 a) {
  SYNC_MXCSR_RC();
  float fr = (float)(u32)a;
  u32 r;
  memcpy(&r, &fr, 4);
  return r;
}

u64 Model::z__uint64_to_f32(u64 a) {
  SYNC_MXCSR_RC();
  float fr = (float)(u64)a;
  u32 r;
  memcpy(&r, &fr, 4);
  return r;
}

u64 Model::z__uint32_to_f64(u64 a) {
  double fr = (double)(u32)a;
  u64 r;
  memcpy(&r, &fr, 8);
  return r;
}

u64 Model::z__uint64_to_f64(u64 a) {
  SYNC_MXCSR_RC();
  double fr = (double)(u64)a;
  u64 r;
  memcpy(&r, &fr, 8);
  return r;
}

// =========================================================================
// AVX-512 FP math: VSCALEF, VGETEXP, VRCP14, VRSQRT14
// =========================================================================

// VSCALEF: result = src1 * 2^(floor(src2))
u64 Model::z__f32_scalef(u64 a, u64 b) {
  float fa;
  float fb;
  memcpy(&fa, &a, 4);
  memcpy(&fb, &b, 4);
  float result = fa * powf(2.0f, floorf(fb));
  u32 r;
  memcpy(&r, &result, 4);
  return r;
}

u64 Model::z__f64_scalef(u64 a, u64 b) {
  double da;
  double db;
  memcpy(&da, &a, 8);
  memcpy(&db, &b, 8);
  double result = da * pow(2.0, floor(db));
  memcpy(&a, &result, 8);
  return a;
}

// VGETEXP: extract unbiased exponent as FP value
u64 Model::z__f32_getexp(u64 a) {
  float fa;
  memcpy(&fa, &a, 4);
  if (fa == 0.0f || fa == -0.0f) {
    float r = -INFINITY;
    u32 rr;
    memcpy(&rr, &r, 4);
    return rr;
  }
  if (std::isinf(fa)) {
    float r = INFINITY;
    u32 rr;
    memcpy(&rr, &r, 4);
    return rr;
  }
  if (std::isnan(fa)) {
    u32 rr;
    memcpy(&rr, &fa, 4);
    return rr;
  }
  int exp;
  frexpf(fabsf(fa), &exp);
  float result = (float)(exp - 1);  // frexp returns [0.5, 1.0) so exp is biased by 1
  u32 r;
  memcpy(&r, &result, 4);
  return r;
}

u64 Model::z__f64_getexp(u64 a) {
  double da;
  memcpy(&da, &a, 8);
  if (da == 0.0 || da == -0.0) {
    double r = -INFINITY;
    memcpy(&a, &r, 8);
    return a;
  }
  if (std::isinf(da)) {
    double r = INFINITY;
    memcpy(&a, &r, 8);
    return a;
  }
  if (std::isnan(da))
    return a;  // NaN passthrough
  int exp;
  frexp(fabs(da), &exp);
  double result = (double)(exp - 1);
  memcpy(&a, &result, 8);
  return a;
}

// VRCP14: approximate reciprocal (host FPU gives better than 14-bit precision)
u64 Model::z__f32_rcp14(u64 a) {
  float fa;
  memcpy(&fa, &a, 4);
  float result = 1.0f / fa;
  u32 r;
  memcpy(&r, &result, 4);
  return r;
}

u64 Model::z__f64_rcp14(u64 a) {
  double da;
  memcpy(&da, &a, 8);
  double result = 1.0 / da;
  memcpy(&a, &result, 8);
  return a;
}

// VRSQRT14: approximate reciprocal square root
u64 Model::z__f32_rsqrt14(u64 a) {
  float fa;
  memcpy(&fa, &a, 4);
  float result = 1.0f / sqrtf(fa);
  u32 r;
  memcpy(&r, &result, 4);
  return r;
}

u64 Model::z__f64_rsqrt14(u64 a) {
  double da;
  memcpy(&da, &a, 8);
  double result = 1.0 / sqrt(da);
  memcpy(&a, &result, 8);
  return a;
}

// VRCP28: approximate reciprocal (28-bit precision, same as host FPU)
u64 Model::z__f32_rcp28(u64 a) {
  float fa;
  memcpy(&fa, &a, 4);
  float result = 1.0f / fa;
  u32 r;
  memcpy(&r, &result, 4);
  return r;
}

u64 Model::z__f64_rcp28(u64 a) {
  double da;
  memcpy(&da, &a, 8);
  double result = 1.0 / da;
  memcpy(&a, &result, 8);
  return a;
}

// VRSQRT28: approximate reciprocal square root (28-bit precision)
u64 Model::z__f32_rsqrt28(u64 a) {
  float fa;
  memcpy(&fa, &a, 4);
  float result = 1.0f / sqrtf(fa);
  u32 r;
  memcpy(&r, &result, 4);
  return r;
}

u64 Model::z__f64_rsqrt28(u64 a) {
  double da;
  memcpy(&da, &a, 8);
  double result = 1.0 / sqrt(da);
  memcpy(&a, &result, 8);
  return a;
}

// VEXP2: approximate 2^x
u64 Model::z__f32_exp2(u64 a) {
  float fa;
  memcpy(&fa, &a, 4);
  float result = exp2f(fa);
  u32 r;
  memcpy(&r, &result, 4);
  return r;
}

u64 Model::z__f64_exp2(u64 a) {
  double da;
  memcpy(&da, &a, 8);
  double result = exp2(da);
  memcpy(&a, &result, 8);
  return a;
}

// VRNDSCALE: round to number of fraction bits specified by imm8
// imm8[3:0] = M (number of fraction bits), imm8[7:4] = rounding control
u64 Model::z__f32_rndscale(u64 a, u64 imm) {
  float fa;
  memcpy(&fa, &a, 4);
  // imm8[3] (RS): 0 = use imm8[1:0] for rounding, 1 = use MXCSR.RC
  // imm8[1:0] (RC): 00=RN, 01=RD, 10=RU, 11=RZ
  int rc = (imm & 8) ? 0 : (imm & 3);  // TODO: read MXCSR.RC when RS=1
  float result;
  switch (rc) {
  case 0: result = nearbyintf(fa); break;  // round to nearest
  case 1: result = floorf(fa); break;      // round down
  case 2: result = ceilf(fa); break;       // round up
  case 3: result = truncf(fa); break;      // round toward zero
  default: result = nearbyintf(fa); break;
  }
  u32 r;
  memcpy(&r, &result, 4);
  return r;
}

u64 Model::z__f64_rndscale(u64 a, u64 imm) {
  double da;
  memcpy(&da, &a, 8);
  int rc = (imm & 8) ? 0 : (imm & 3);
  double result;
  switch (rc) {
  case 0: result = nearbyint(da); break;
  case 1: result = floor(da); break;
  case 2: result = ceil(da); break;
  case 3: result = trunc(da); break;
  default: result = nearbyint(da); break;
  }
  memcpy(&a, &result, 8);
  return a;
}

// VGETMANT: extract normalized mantissa
// imm8[1:0] = normalization interval: 0=[1,2), 1=[1/2,2), 2=[1/2,1), 3=[3/4,3/2)
// imm8[3:2] = sign control: sc[0]=0 preserve src sign, sc[0]=1 force positive
u64 Model::z__f32_getmant(u64 a, u64 imm) {
  float fa;
  memcpy(&fa, &a, 4);
  if (std::isnan(fa) || std::isinf(fa) || fa == 0.0f) {
    // Simplified: return input for special cases
    u32 r;
    memcpy(&r, &fa, 4);
    return r;
  }
  int exp;
  float mantissa = frexpf(fabsf(fa), &exp);
  // frexp returns [0.5, 1.0), we want [1.0, 2.0) for interval=0 (default)
  int interval = imm & 3;
  // Adjust for normalization interval
  // interval=0: [1,2) — multiply by 2
  // interval=1: [1/2,2) — if odd exponent, keep [0.5,1); else multiply by 2
  // interval=2: [1/2,1) — keep as-is
  // interval=3: [3/4,3/2) — if mantissa MSB set, keep; else multiply by 2
  if (interval == 0) {
    mantissa *= 2.0f;
  } else if (interval == 1) {
    int unbiased = exp - 1;  // frexp exponent is 1-based
    if ((unbiased & 1) == 0) mantissa *= 2.0f;
  } else if (interval == 2) {
    // Already [0.5, 1.0) from frexp — correct
  } else {
    // interval=3: [3/4, 3/2)
    // If significand bit set (mantissa >= 0.5 in frexp), check position
    if (mantissa >= 0.75f) {
      // Already in [3/4, 3/2)
    } else {
      mantissa *= 2.0f;
    }
  }
  // Sign control: imm8[3:2], sc[0] (bit 2 of imm) = 0: preserve, 1: force positive
  int sc = (imm >> 2) & 3;
  if (!(sc & 1) && fa < 0)
    mantissa = -mantissa;
  u32 r;
  memcpy(&r, &mantissa, 4);
  return r;
}

u64 Model::z__f64_getmant(u64 a, u64 imm) {
  double da;
  memcpy(&da, &a, 8);
  if (std::isnan(da) || std::isinf(da) || da == 0.0)
    return a;
  int exp;
  double mantissa = frexp(fabs(da), &exp);
  int interval = imm & 3;
  if (interval == 0) {
    mantissa *= 2.0;
  } else if (interval == 1) {
    int unbiased = exp - 1;
    if ((unbiased & 1) == 0) mantissa *= 2.0;
  } else if (interval == 2) {
    // Already [0.5, 1.0) from frexp
  } else {
    if (mantissa >= 0.75) {
      // Already in [3/4, 3/2)
    } else {
      mantissa *= 2.0;
    }
  }
  int sc = (imm >> 2) & 3;
  if (!(sc & 1) && da < 0)
    mantissa = -mantissa;
  memcpy(&a, &mantissa, 8);
  return a;
}

// VREDUCE: reduce = src - round(src) * 2^(-M)
// Simplified: return src - rndscale(src, imm)
u64 Model::z__f32_reduce(u64 a, u64 imm) {
  float fa;
  memcpy(&fa, &a, 4);
  u64 rounded = z__f32_rndscale(a, imm);
  float fr;
  memcpy(&fr, &rounded, 4);
  float result = fa - fr;
  u32 r;
  memcpy(&r, &result, 4);
  return r;
}

u64 Model::z__f64_reduce(u64 a, u64 imm) {
  double da;
  memcpy(&da, &a, 8);
  u64 rounded = z__f64_rndscale(a, imm);
  double dr;
  memcpy(&dr, &rounded, 8);
  double result = da - dr;
  memcpy(&a, &result, 8);
  return a;
}

// VFIXUPIMM: fix up special FP values based on lookup table
// Classify src1 into 8 token types, look up 4-bit response in tbl, apply action.
static u32 fixupimm_sp_response(u32 dst, u32 src1, u32 tbl, u8 imm) {
  // Classify src1 into token type (0-7)
  int exp = (src1 >> 23) & 0xFF;
  u32 frac = src1 & 0x7FFFFF;
  bool sign = (src1 >> 31) != 0;
  int j;
  if (exp == 0xFF && frac != 0 && (frac & 0x400000))
    j = 0;  // QNAN
  else if (exp == 0xFF && frac != 0)
    j = 1;  // SNAN
  else if (exp == 0 && frac == 0)
    j = 2;  // ZERO (includes +0 and -0)
  else if (src1 == 0x3F800000)
    j = 3;  // POS_ONE (+1.0)
  else if (src1 == 0xFF800000)
    j = 4;  // NEG_INF
  else if (src1 == 0x7F800000)
    j = 5;  // POS_INF
  else if (sign)
    j = 6;  // NEG_VALUE
  else
    j = 7;  // POS_VALUE
  int resp = (tbl >> (j * 4)) & 0xF;
  switch (resp) {
  case 0x0: return dst;
  case 0x1: return src1;
  case 0x2: return src1 | 0x00400000;  // QNaN(src1)
  case 0x3: return 0xFFC00000;         // QNaN indefinite
  case 0x4: return 0xFF800000;         // -INF
  case 0x5: return 0x7F800000;         // +INF
  case 0x6: return sign ? 0xFF800000 : 0x7F800000;  // sign-dependent INF
  case 0x7: return 0x80000000;         // -0
  case 0x8: return 0x00000000;         // +0
  case 0x9: return 0xBF800000;         // -1.0
  case 0xA: return 0x3F800000;         // +1.0
  case 0xB: return 0x3F000000;         // 0.5
  case 0xC: return 0x42B40000;         // 90.0
  case 0xD: return 0x3FC90FDB;         // pi/2
  case 0xE: return 0x7F7FFFFF;         // MAX_FLOAT
  case 0xF: return 0xFF7FFFFF;         // -MAX_FLOAT
  default: return dst;
  }
}

u64 Model::z__f32_fixupimm(u64 dst, u64 src1, u64 src2, u64 imm) {
  return fixupimm_sp_response((u32)dst, (u32)src1, (u32)src2, (u8)imm);
}

static u64 fixupimm_dp_response(u64 dst, u64 src1, u64 tbl, u8 imm) {
  int exp = (src1 >> 52) & 0x7FF;
  u64 frac = src1 & 0xFFFFFFFFFFFFFULL;
  bool sign = (src1 >> 63) != 0;
  int j;
  if (exp == 0x7FF && frac != 0 && (frac & 0x8000000000000ULL))
    j = 0;  // QNAN
  else if (exp == 0x7FF && frac != 0)
    j = 1;  // SNAN
  else if (exp == 0 && frac == 0)
    j = 2;  // ZERO
  else if (src1 == 0x3FF0000000000000ULL)
    j = 3;  // POS_ONE
  else if (src1 == 0xFFF0000000000000ULL)
    j = 4;  // NEG_INF
  else if (src1 == 0x7FF0000000000000ULL)
    j = 5;  // POS_INF
  else if (sign)
    j = 6;  // NEG_VALUE
  else
    j = 7;  // POS_VALUE
  int resp = (tbl >> (j * 4)) & 0xF;
  switch (resp) {
  case 0x0: return dst;
  case 0x1: return src1;
  case 0x2: return src1 | 0x0008000000000000ULL;  // QNaN(src1)
  case 0x3: return 0xFFF8000000000000ULL;          // QNaN indefinite
  case 0x4: return 0xFFF0000000000000ULL;          // -INF
  case 0x5: return 0x7FF0000000000000ULL;          // +INF
  case 0x6: return sign ? 0xFFF0000000000000ULL : 0x7FF0000000000000ULL;
  case 0x7: return 0x8000000000000000ULL;          // -0
  case 0x8: return 0x0000000000000000ULL;          // +0
  case 0x9: return 0xBFF0000000000000ULL;          // -1.0
  case 0xA: return 0x3FF0000000000000ULL;          // +1.0
  case 0xB: return 0x3FE0000000000000ULL;          // 0.5
  case 0xC: return 0x4056800000000000ULL;          // 90.0
  case 0xD: return 0x3FF921FB54442D18ULL;          // pi/2
  case 0xE: return 0x7FEFFFFFFFFFFFFFULL;          // MAX_DOUBLE
  case 0xF: return 0xFFEFFFFFFFFFFFFFULL;          // -MAX_DOUBLE
  default: return dst;
  }
}

u64 Model::z__f64_fixupimm(u64 dst, u64 src1, u64 src2, u64 imm) {
  return fixupimm_dp_response(dst, src1, src2, (u8)imm);
}

// =========================================================================
// IEEE 754 half-precision (f16) operations — AVX-512 FP16
// =========================================================================

// FP16 DAZ: flush denormal FP16 inputs to ±0
static inline u64 f16_daz_bits(u64 a, u32 mxcsr) {
  if (!(mxcsr & 0x0040))
    return a;
  u16 bits = (u16)a;
  if ((bits & 0x7C00) == 0 && (bits & 0x03FF) != 0)
    return bits & 0x8000;
  return a;
}

// FP16 FTZ: flush denormal FP16 result to ±0
static inline _Float16 f16_ftz(_Float16 f, u32 mxcsr) {
  if (!(mxcsr & 0x8000))
    return f;
  u16 bits;
  memcpy(&bits, &f, 2);
  if ((bits & 0x7C00) == 0 && (bits & 0x03FF) != 0) {
    bits &= 0x8000;
    memcpy(&f, &bits, 2);
  }
  return f;
}

// Intel NaN propagation for f16: SRC1 (a) priority
static bool f16_nan_prop(u64 a, u64 b, u64 *out) {
  u16 ua = (u16)a;
  u16 ub = (u16)b;
  bool a_nan = ((ua & 0x7C00) == 0x7C00) && ((ua & 0x03FF) != 0);
  bool b_nan = ((ub & 0x7C00) == 0x7C00) && ((ub & 0x03FF) != 0);
  if (!a_nan && !b_nan)
    return false;
  *out = a_nan ? (ua | 0x0200) : (ub | 0x0200);  // quiet NaN bit
  return true;
}

static inline u16 f16_arith(u64 a_bits, u64 b_bits, u32 mxcsr,
                             float (*op)(float, float)) {
  a_bits = f16_daz_bits(a_bits, mxcsr);
  b_bits = f16_daz_bits(b_bits, mxcsr);
  // Convert FP16 to float
  _Float16 ha, hb;
  u16 ua = (u16)a_bits, ub = (u16)b_bits;
  memcpy(&ha, &ua, 2);
  memcpy(&hb, &ub, 2);
  float fa = (float)ha, fb = (float)hb;
  set_rounding((mxcsr >> 13) & 3);
  float fr = op(fa, fb);
  // Convert back to FP16
  _Float16 hr = (_Float16)fr;
  hr = f16_ftz(hr, mxcsr);
  u16 r;
  memcpy(&r, &hr, 2);
  return r;
}

u64 Model::z__f16_add(u64 a, u64 b) {
  u64 nr;
  if (f16_nan_prop(a, b, &nr)) return nr;
  return f16_arith(a, b, mxcsr_state.mxcsr,
                   [](float a, float b) { return a + b; });
}

u64 Model::z__f16_sub(u64 a, u64 b) {
  u64 nr;
  if (f16_nan_prop(a, b, &nr)) return nr;
  return f16_arith(a, b, mxcsr_state.mxcsr,
                   [](float a, float b) { return a - b; });
}

u64 Model::z__f16_mul(u64 a, u64 b) {
  u64 nr;
  if (f16_nan_prop(a, b, &nr)) return nr;
  return f16_arith(a, b, mxcsr_state.mxcsr,
                   [](float a, float b) { return a * b; });
}

u64 Model::z__f16_div(u64 a, u64 b) {
  u64 nr;
  if (f16_nan_prop(a, b, &nr)) return nr;
  return f16_arith(a, b, mxcsr_state.mxcsr,
                   [](float a, float b) { return a / b; });
}

u64 Model::z__f16_sqrt(u64 a) {
  a = f16_daz_bits(a, mxcsr_state.mxcsr);
  _Float16 ha;
  u16 ua = (u16)a;
  memcpy(&ha, &ua, 2);
  float fa = (float)ha;
  SYNC_MXCSR_RC();
  float fr = sqrtf(fa);
  _Float16 hr = (_Float16)fr;
  hr = f16_ftz(hr, mxcsr_state.mxcsr);
  u16 r;
  memcpy(&r, &hr, 2);
  return r;
}

u64 Model::z__f16_min(u64 a, u64 b) {
  a = f16_daz_bits(a, mxcsr_state.mxcsr);
  b = f16_daz_bits(b, mxcsr_state.mxcsr);
  u16 ua = (u16)a, ub = (u16)b;
  _Float16 ha, hb;
  memcpy(&ha, &ua, 2);
  memcpy(&hb, &ub, 2);
  float fa = (float)ha, fb = (float)hb;
  // MINPH: if either is NaN, return src2 (b); if both zero, return src2
  if (__builtin_isnan(fa)) { return b; }
  if (__builtin_isnan(fb)) { return a; }
  if (fa == 0.0f && fb == 0.0f) { return b; }
  _Float16 hr = fa < fb ? ha : hb;
  u16 r;
  memcpy(&r, &hr, 2);
  return r;
}

u64 Model::z__f16_max(u64 a, u64 b) {
  a = f16_daz_bits(a, mxcsr_state.mxcsr);
  b = f16_daz_bits(b, mxcsr_state.mxcsr);
  u16 ua = (u16)a, ub = (u16)b;
  _Float16 ha, hb;
  memcpy(&ha, &ua, 2);
  memcpy(&hb, &ub, 2);
  float fa = (float)ha, fb = (float)hb;
  if (__builtin_isnan(fa)) { return b; }
  if (__builtin_isnan(fb)) { return a; }
  if (fa == 0.0f && fb == 0.0f) { return b; }
  _Float16 hr = fa > fb ? ha : hb;
  u16 r;
  memcpy(&r, &hr, 2);
  return r;
}

// FP16 FMA
u64 Model::z__f16_fmadd(u64 a, u64 b, u64 c) {
  a = f16_daz_bits(a, mxcsr_state.mxcsr);
  b = f16_daz_bits(b, mxcsr_state.mxcsr);
  c = f16_daz_bits(c, mxcsr_state.mxcsr);
  _Float16 ha, hb, hc;
  u16 ua = (u16)a, ub = (u16)b, uc = (u16)c;
  memcpy(&ha, &ua, 2); memcpy(&hb, &ub, 2); memcpy(&hc, &uc, 2);
  SYNC_MXCSR_RC();
  float fr = fmaf((float)ha, (float)hb, (float)hc);
  _Float16 hr = f16_ftz((_Float16)fr, mxcsr_state.mxcsr);
  u16 r; memcpy(&r, &hr, 2); return r;
}

u64 Model::z__f16_fmsub(u64 a, u64 b, u64 c) {
  a = f16_daz_bits(a, mxcsr_state.mxcsr);
  b = f16_daz_bits(b, mxcsr_state.mxcsr);
  c = f16_daz_bits(c, mxcsr_state.mxcsr);
  _Float16 ha, hb, hc;
  u16 ua = (u16)a, ub = (u16)b, uc = (u16)c;
  memcpy(&ha, &ua, 2); memcpy(&hb, &ub, 2); memcpy(&hc, &uc, 2);
  SYNC_MXCSR_RC();
  float fr = fmaf((float)ha, (float)hb, -(float)hc);
  _Float16 hr = f16_ftz((_Float16)fr, mxcsr_state.mxcsr);
  u16 r; memcpy(&r, &hr, 2); return r;
}

u64 Model::z__f16_fnmadd(u64 a, u64 b, u64 c) {
  a = f16_daz_bits(a, mxcsr_state.mxcsr);
  b = f16_daz_bits(b, mxcsr_state.mxcsr);
  c = f16_daz_bits(c, mxcsr_state.mxcsr);
  _Float16 ha, hb, hc;
  u16 ua = (u16)a, ub = (u16)b, uc = (u16)c;
  memcpy(&ha, &ua, 2); memcpy(&hb, &ub, 2); memcpy(&hc, &uc, 2);
  SYNC_MXCSR_RC();
  float fr = fmaf(-(float)ha, (float)hb, (float)hc);
  _Float16 hr = f16_ftz((_Float16)fr, mxcsr_state.mxcsr);
  u16 r; memcpy(&r, &hr, 2); return r;
}

u64 Model::z__f16_fnmsub(u64 a, u64 b, u64 c) {
  a = f16_daz_bits(a, mxcsr_state.mxcsr);
  b = f16_daz_bits(b, mxcsr_state.mxcsr);
  c = f16_daz_bits(c, mxcsr_state.mxcsr);
  _Float16 ha, hb, hc;
  u16 ua = (u16)a, ub = (u16)b, uc = (u16)c;
  memcpy(&ha, &ua, 2); memcpy(&hb, &ub, 2); memcpy(&hc, &uc, 2);
  SYNC_MXCSR_RC();
  float fr = fmaf(-(float)ha, (float)hb, -(float)hc);
  _Float16 hr = f16_ftz((_Float16)fr, mxcsr_state.mxcsr);
  u16 r; memcpy(&r, &hr, 2); return r;
}

u64 Model::z__f16_to_f64(u64 a) {
  _Float16 h; u16 ua = (u16)a; memcpy(&h, &ua, 2);
  double d = (double)h; u64 r; memcpy(&r, &d, 8); return r;
}

u64 Model::z__int32_to_f16(u64 a) {
  int32_t v; memcpy(&v, &a, 4);
  SYNC_MXCSR_RC();
  _Float16 h = (_Float16)v; u16 r; memcpy(&r, &h, 2); return r;
}

u64 Model::z__int64_to_f16(u64 a) {
  int64_t v; memcpy(&v, &a, 8);
  SYNC_MXCSR_RC();
  _Float16 h = (_Float16)v; u16 r; memcpy(&r, &h, 2); return r;
}

// FP16 conversions
u64 Model::z__f16_to_f32(u64 a) {
  _Float16 h; u16 ua = (u16)a; memcpy(&h, &ua, 2);
  float f = (float)h; u32 r; memcpy(&r, &f, 4); return r;
}

u64 Model::z__f32_to_f16(u64 a) {
  float f; memcpy(&f, &a, 4);
  SYNC_MXCSR_RC();
  _Float16 h = (_Float16)f; u16 r; memcpy(&r, &h, 2); return r;
}

u64 Model::z__f64_to_f16(u64 a) {
  double d; memcpy(&d, &a, 8);
  SYNC_MXCSR_RC();
  _Float16 h = (_Float16)d; u16 r; memcpy(&r, &h, 2); return r;
}

u64 Model::z__f16_to_int32(u64 a) {
  _Float16 h; u16 ua = (u16)a; memcpy(&h, &ua, 2);
  SYNC_MXCSR_RC();
  float f = (float)h;
  int32_t r = (int32_t)nearbyintf(f);
  u32 ru; memcpy(&ru, &r, 4); return ru;
}

u64 Model::z__f16_to_int64(u64 a) {
  _Float16 h; u16 ua = (u16)a; memcpy(&h, &ua, 2);
  SYNC_MXCSR_RC();
  float f = (float)h;
  int64_t r = (int64_t)nearbyintf(f);
  u64 ru; memcpy(&ru, &r, 8); return ru;
}

u64 Model::z__f16_to_int32_trunc(u64 a) {
  _Float16 h; u16 ua = (u16)a; memcpy(&h, &ua, 2);
  float f = (float)h;
  int32_t r = (int32_t)truncf(f);
  u32 ru; memcpy(&ru, &r, 4); return ru;
}

u64 Model::z__f16_to_int64_trunc(u64 a) {
  _Float16 h; u16 ua = (u16)a; memcpy(&h, &ua, 2);
  float f = (float)h;
  int64_t r = (int64_t)truncf(f);
  u64 ru; memcpy(&ru, &r, 8); return ru;
}

u64 Model::z__f16_to_uint32(u64 a) {
  _Float16 h; u16 ua = (u16)a; memcpy(&h, &ua, 2);
  SYNC_MXCSR_RC();
  float f = (float)h;
  uint32_t r = (uint32_t)nearbyintf(f);
  return r;
}

u64 Model::z__f16_to_uint64(u64 a) {
  _Float16 h; u16 ua = (u16)a; memcpy(&h, &ua, 2);
  SYNC_MXCSR_RC();
  float f = (float)h;
  uint64_t r = (uint64_t)nearbyintf(f);
  return r;
}

u64 Model::z__f16_to_uint32_trunc(u64 a) {
  _Float16 h; u16 ua = (u16)a; memcpy(&h, &ua, 2);
  float f = (float)h;
  uint32_t r = (uint32_t)truncf(f);
  return r;
}

u64 Model::z__f16_to_uint64_trunc(u64 a) {
  _Float16 h; u16 ua = (u16)a; memcpy(&h, &ua, 2);
  float f = (float)h;
  uint64_t r = (uint64_t)truncf(f);
  return r;
}

u64 Model::z__uint32_to_f16(u64 a) {
  uint32_t v = (uint32_t)a;
  SYNC_MXCSR_RC();
  _Float16 h = (_Float16)v; u16 r; memcpy(&r, &h, 2); return r;
}

u64 Model::z__uint64_to_f16(u64 a) {
  uint64_t v = (uint64_t)a;
  SYNC_MXCSR_RC();
  _Float16 h = (_Float16)v; u16 r; memcpy(&r, &h, 2); return r;
}

u64 Model::z__f16_to_int16(u64 a) {
  _Float16 h; u16 ua = (u16)a; memcpy(&h, &ua, 2);
  SYNC_MXCSR_RC();
  float f = (float)h;
  int16_t r = (int16_t)nearbyintf(f);
  u16 ru; memcpy(&ru, &r, 2); return ru;
}

u64 Model::z__f16_to_int16_trunc(u64 a) {
  _Float16 h; u16 ua = (u16)a; memcpy(&h, &ua, 2);
  float f = (float)h;
  int16_t r = (int16_t)truncf(f);
  u16 ru; memcpy(&ru, &r, 2); return ru;
}

u64 Model::z__int16_to_f16(u64 a) {
  int16_t v = (int16_t)(u16)a;
  SYNC_MXCSR_RC();
  _Float16 h = (_Float16)v; u16 r; memcpy(&r, &h, 2); return r;
}

u64 Model::z__f16_to_uint16(u64 a) {
  _Float16 h; u16 ua = (u16)a; memcpy(&h, &ua, 2);
  SYNC_MXCSR_RC();
  float f = (float)h;
  uint16_t r = (uint16_t)nearbyintf(f);
  return r;
}

u64 Model::z__f16_to_uint16_trunc(u64 a) {
  _Float16 h; u16 ua = (u16)a; memcpy(&h, &ua, 2);
  float f = (float)h;
  uint16_t r = (uint16_t)truncf(f);
  return r;
}

u64 Model::z__uint16_to_f16(u64 a) {
  uint16_t v = (uint16_t)a;
  SYNC_MXCSR_RC();
  _Float16 h = (_Float16)v; u16 r; memcpy(&r, &h, 2); return r;
}

// FP16 special operations
u64 Model::z__f16_scalef(u64 a, u64 b) {
  _Float16 ha, hb; u16 ua = (u16)a, ub = (u16)b;
  memcpy(&ha, &ua, 2); memcpy(&hb, &ub, 2);
  float fa = (float)ha, fb = (float)hb;
  SYNC_MXCSR_RC();
  float fr = fa * exp2f(truncf(fb));
  _Float16 hr = f16_ftz((_Float16)fr, mxcsr_state.mxcsr);
  u16 r; memcpy(&r, &hr, 2); return r;
}

u64 Model::z__f16_getexp(u64 a) {
  u16 ua = (u16)a;
  _Float16 ha; memcpy(&ha, &ua, 2);
  float fa = (float)ha;
  if (__builtin_isnan(fa) || __builtin_isinf(fa)) {
    u16 r;
    if (__builtin_isnan(fa)) r = ua | 0x0200;  // QNaN
    else { r = 0x7C00; }  // +Inf
    return r;
  }
  if (fa == 0.0f) return ua & 0x8000 ? 0xFC00 : 0xFC00;  // -Inf
  int exp;
  frexpf(fa, &exp);
  _Float16 hr = (_Float16)(exp - 1);
  u16 r; memcpy(&r, &hr, 2); return r;
}

u64 Model::z__f16_rcp(u64 a) {
  _Float16 ha; u16 ua = (u16)a; memcpy(&ha, &ua, 2);
  float fa = (float)ha;
  float fr = 1.0f / fa;
  _Float16 hr = (_Float16)fr;
  u16 r; memcpy(&r, &hr, 2); return r;
}

u64 Model::z__f16_rsqrt(u64 a) {
  _Float16 ha; u16 ua = (u16)a; memcpy(&ha, &ua, 2);
  float fa = (float)ha;
  float fr = 1.0f / sqrtf(fa);
  _Float16 hr = (_Float16)fr;
  u16 r; memcpy(&r, &hr, 2); return r;
}

u64 Model::z__f16_rndscale(u64 a, u64 imm) {
  _Float16 ha; u16 ua = (u16)a; memcpy(&ha, &ua, 2);
  float fa = (float)ha;
  int rc = (int)((imm >> 2) & 3);
  int m = (int)(imm & 0xF);
  float scale = exp2f((float)m);
  int saved = fegetround();
  // imm[3:2] = rounding mode (0=RNE,1=DN,2=UP,3=TZ), imm[4]=use-imm-rc
  if (imm & 0x04) {
    switch (rc) {
    case 0: fesetround(FE_TONEAREST); break;
    case 1: fesetround(FE_DOWNWARD); break;
    case 2: fesetround(FE_UPWARD); break;
    case 3: fesetround(FE_TOWARDZERO); break;
    }
  } else {
    SYNC_MXCSR_RC();
  }
  float fr = nearbyintf(fa * scale) / scale;
  fesetround(saved);
  _Float16 hr = (_Float16)fr;
  u16 r; memcpy(&r, &hr, 2); return r;
}

u64 Model::z__f16_getmant(u64 a, u64 imm) {
  // Simplified: extract mantissa, return as FP16 in [1,2) or [0.5,1) range
  u16 ua = (u16)a;
  _Float16 ha; memcpy(&ha, &ua, 2);
  float fa = (float)ha;
  if (__builtin_isnan(fa)) return ua | 0x0200;
  if (__builtin_isinf(fa)) return ua | 0x0200;  // QNaN
  if (fa == 0.0f) return ua;
  int exp;
  float mant = frexpf(fabsf(fa), &exp);  // [0.5, 1.0)
  int norm = (int)(imm & 3);
  if (norm == 0 || norm == 2) mant *= 2.0f;  // [1.0, 2.0)
  int sign_ctrl = (int)((imm >> 2) & 3);
  bool neg;
  switch (sign_ctrl) {
  case 0: neg = fa < 0.0f; break;
  case 1: neg = false; break;
  case 2: neg = false; break;
  default: neg = fa < 0.0f; break;
  }
  if (neg) mant = -mant;
  _Float16 hr = (_Float16)mant;
  u16 r; memcpy(&r, &hr, 2); return r;
}

u64 Model::z__f16_reduce(u64 a, u64 imm) {
  _Float16 ha; u16 ua = (u16)a; memcpy(&ha, &ua, 2);
  float fa = (float)ha;
  int m = (int)(imm & 0xF);
  float scale = exp2f((float)m);
  SYNC_MXCSR_RC();
  float rounded = nearbyintf(fa * scale) / scale;
  float fr = fa - rounded;
  _Float16 hr = (_Float16)fr;
  u16 r; memcpy(&r, &hr, 2); return r;
}

} // namespace x86

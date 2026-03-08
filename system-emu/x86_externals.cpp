// Implementation of all external functions declared in the Sail model.
// System-mode version: memory access goes through PhysicalMemory.

#include "sail_x86_model.h"
#include "x86_cpuid.h"
#include <cstring>
#include <cmath>
#include <cfenv>
#include <unordered_map>
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

static void bits_to_bytes(lbits val, u8 *out, size_t nbytes) {
  // lbits stores data in mpz_t. Extract bytes in little-endian order.
  for (size_t i = 0; i < nbytes; i++) {
    out[i] = (u8)mpz_getlimbn(*val.bits, 0) >> (i * 8) & 0xFF;
  }
  // More robust extraction:
  mpz_t tmp;
  mpz_init_set(tmp, *val.bits);
  for (size_t i = 0; i < nbytes; i++) {
    out[i] = (u8)(mpz_get_ui(tmp) & 0xFF);
    mpz_fdiv_q_2exp(tmp, tmp, 8);
  }
  mpz_clear(tmp);
}

static void bytes_to_bits(lbits *out, const u8 *in, size_t nbytes, size_t nbits) {
  mpz_set_ui(*out->bits, 0);
  for (size_t i = nbytes; i > 0; i--) {
    mpz_mul_2exp(*out->bits, *out->bits, 8);
    mpz_add_ui(*out->bits, *out->bits, in[i - 1]);
  }
  out->len = nbits;
}

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
// CPUID
// =========================================================================

struct ztuple_z8z5bv32zCz0z5bv32zCz0z5bv32zCz0z5bv32z9
Model::z__cpuid(u64 leaf, u64 subleaf) {
  struct ztuple_z8z5bv32zCz0z5bv32zCz0z5bv32zCz0z5bv32z9 result;
  result.ztup0 = 0; result.ztup1 = 0; result.ztup2 = 0; result.ztup3 = 0;

  // Return x86-64 CPU description for Linux boot.
  // Stripped-down: no XSAVE/AVX/AVX-512 to avoid XSAVE init issues.
  // Leaf 1 EDX: FPU DE PSE TSC MSR PAE MCE CX8 APIC SEP MTRR PGE MCA
  //             CMOV PAT CLFSH MMX FXSR SSE SSE2 (no PSE36)
  // Leaf 1 ECX: SSE3 SSSE3 CX16 SSE4.1 SSE4.2 POPCNT
  // No APIC bit: we don't emulate local APIC MMIO, so kernel uses PIC-only.
  constexpr u32 SYS_CPUID_1_EDX =
    CPUID_1_EDX_FPU | CPUID_1_EDX_DE | CPUID_1_EDX_PSE | CPUID_1_EDX_TSC |
    CPUID_1_EDX_MSR | CPUID_1_EDX_PAE | CPUID_1_EDX_MCE | CPUID_1_EDX_CX8 |
    CPUID_1_EDX_SEP | CPUID_1_EDX_MTRR | CPUID_1_EDX_PGE |
    CPUID_1_EDX_MCA | CPUID_1_EDX_CMOV | CPUID_1_EDX_PAT |
    CPUID_1_EDX_CLFSH | CPUID_1_EDX_MMX | CPUID_1_EDX_FXSR |
    CPUID_1_EDX_SSE | CPUID_1_EDX_SSE2;
  constexpr u32 SYS_CPUID_1_ECX =
    CPUID_1_ECX_SSE3 | CPUID_1_ECX_SSSE3 | CPUID_1_ECX_CX16 |
    CPUID_1_ECX_SSE4_1 | CPUID_1_ECX_SSE4_2 | CPUID_1_ECX_POPCNT;

  switch (leaf) {
  case 0:
    result.ztup0 = 0x07;    // max basic leaf
    result.ztup1 = 0x756E6547;  // "Genu"
    result.ztup2 = 0x6C65746E;  // "ntel"
    result.ztup3 = 0x49656E69;  // "ineI"
    break;
  case 1:
    // EAX: Family 6, Model 0x5E, Stepping 3
    result.ztup0 = 0x000506E3;
    // EBX: CLFLUSH=8, max logical=1, initial APIC=0
    result.ztup1 = 0x00010800;
    result.ztup2 = SYS_CPUID_1_ECX;
    result.ztup3 = SYS_CPUID_1_EDX;
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
      result.ztup1 = CPUID_7_EBX_ERMS;  // only ERMS, no AVX2/AVX-512
    break;
  case 0x80000000:
    result.ztup0 = 0x80000008;  // max extended leaf
    break;
  case 0x80000001:
    result.ztup2 = EMU_CPUID_EXT1_ECX;
    result.ztup3 = EMU_CPUID_EXT1_EDX;
    break;
  case 0x80000002:
    // Processor brand string part 1: "Sail"
    result.ztup0 = 0x6C696153;  // "Sail"
    result.ztup1 = 0x38782D20;  // " x8"
    result.ztup2 = 0x34362D36;  // "6-64"
    result.ztup3 = 0x6F724520;  // " Emu"
    break;
  case 0x80000003:
    // Processor brand string part 2: "lato"
    result.ztup0 = 0x6F74616C;  // "lato"
    result.ztup1 = 0x00000072;  // "r\0"
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
  // CPUID trace disabled for performance
  return result;
}

// =========================================================================
// RDTSC
// =========================================================================

u64 Model::z__rdtsc(unit) {
  return __rdtsc();
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
  case 0x10:   return __rdtsc();   // IA32_TSC
  case 0x277:  return 0x0007040600070406ULL; // IA32_PAT (default)
  case 0x1A0:  return 1;           // IA32_MISC_ENABLE (bit 0 = FAST_STRING)
  case 0xC0000103: return 0;       // IA32_TSC_AUX
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
  if (p == 0x61)             { pit.tick(10); return pit.read_port_b(); }
  if (p == 0x92)             return 0x02; // System Control Port A (A20 enabled)
  if (p == 0x3DA)            return 0x00; // VGA status (not retrace)
  if (p == 0xCF8 || p == 0xCFC) return 0xFF; // PCI config (no devices)
  if (0xCF9 <= p && p <= 0xCFF) return 0xFF; // PCI config data
  return 0xFF; // Default: empty bus
}

u64 Model::z__port_in16(u64 port) {
  u16 lo = z__port_in8(port);
  u16 hi = z__port_in8(port + 1);
  return (hi << 8) | lo;
}

u64 Model::z__port_in32(u64 port) {
  u32 b0 = z__port_in8(port);
  u32 b1 = z__port_in8(port + 1);
  u32 b2 = z__port_in8(port + 2);
  u32 b3 = z__port_in8(port + 3);
  return (b3 << 24) | (b2 << 16) | (b1 << 8) | b0;
}

unit Model::z__port_out8(u64 port, u64 val) {
  u16 p = (u16)port;
  u8 v = (u8)val;
  if (uart.handles(p))       uart.write(p, v);
  else if (pic_master.handles(p)) pic_master.write(p, v);
  else if (pic_slave.handles(p))  pic_slave.write(p, v);
  else if (pit.handles(p))        pit.write(p, v);
  else if (kbd.handles(p))        kbd.write(p, v);
  else if (cmos.handles(p))       cmos.write(p, v);
  else if (p == 0x61)             pit.write_port_b(v);
  // else: ignore writes to unknown ports
  return UNIT;
}

unit Model::z__port_out16(u64 port, u64 val) {
  z__port_out8(port, val & 0xFF);
  z__port_out8(port + 1, (val >> 8) & 0xFF);
  return UNIT;
}

unit Model::z__port_out32(u64 port, u64 val) {
  z__port_out8(port, val & 0xFF);
  z__port_out8(port + 1, (val >> 8) & 0xFF);
  z__port_out8(port + 2, (val >> 16) & 0xFF);
  z__port_out8(port + 3, (val >> 24) & 0xFF);
  return UNIT;
}

// =========================================================================
// External interrupt check — called by Sail model at start of step()
// =========================================================================

void Model::z__check_pending_irq(sail_int *rop, unit) {
  // Check master PIC for pending, unmasked interrupts
  if (pic_master.has_pending()) {
    int vec = pic_master.acknowledge();
    if (vec >= 0) { mpz_set_si(*rop, vec); return; }
  }
  mpz_set_si(*rop, -1); // No interrupt pending
}

// =========================================================================
// Software interrupt (INT n) — stub for user mode
// =========================================================================

void Model::z__software_interrupt(struct zExecutionResult *rop, u64 vec) {
  // In user mode, INT 0x80 was the old Linux syscall interface.
  // For now, just fault.
  rop->kind = Kind_zFault;
  rop->variants.zFault.ztup0 = (i64)vec;
  rop->variants.zFault.ztup1 = 0;
}

// =========================================================================
// WAIT/FWAIT — no-op in user mode
// =========================================================================

void Model::z__wait(struct zExecutionResult *rop, unit) {
  rop->kind = Kind_zOk;
  rop->variants.zOk = UNIT;
}

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
      phys_mem.write8(addr + i, d[i]);
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
#define PCMPISTRI_CASE(IMM) \
  case IMM: { \
  idx = _mm_cmpistri(v1, v2, IMM); \
  cf = _mm_cmpistrc(v1, v2, IMM); \
  zf = _mm_cmpistrz(v1, v2, IMM); \
  sf = _mm_cmpistrs(v1, v2, IMM); \
  of = _mm_cmpistro(v1, v2, IMM); \
  break; \
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
#define PCMPESTRI_CASE(IMM) \
  case IMM: { \
  idx = _mm_cmpestri(v1, la, v2, lb, IMM); \
  cf = _mm_cmpestrc(v1, la, v2, lb, IMM); \
  zf = _mm_cmpestrz(v1, la, v2, lb, IMM); \
  sf = _mm_cmpestrs(v1, la, v2, lb, IMM); \
  of = _mm_cmpestro(v1, la, v2, lb, IMM); \
  break; \
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
#define PCMPISTRM_CASE(IMM) \
  case IMM: { \
  vr = _mm_cmpistrm(v1, v2, IMM); \
  cf = _mm_cmpistrc(v1, v2, IMM); \
  zf = _mm_cmpistrz(v1, v2, IMM); \
  sf = _mm_cmpistrs(v1, v2, IMM); \
  of = _mm_cmpistro(v1, v2, IMM); \
  break; \
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

#define PCMESTRM_CASE(IMM) \
  case IMM: { \
  vr = _mm_cmpestrm(v1, la, v2, lb, IMM); \
  cf = _mm_cmpestrc(v1, la, v2, lb, IMM); \
  zf = _mm_cmpestrz(v1, la, v2, lb, IMM); \
  sf = _mm_cmpestrs(v1, la, v2, lb, IMM); \
  of = _mm_cmpestro(v1, la, v2, lb, IMM); \
  break; \
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

void Model::z__syscall(struct zExecutionResult *rop, u64 rip, u64 rflags) {
  // In system mode, SYSCALL is handled by the Sail model using MSRs
  // (STAR, LSTAR, FMASK). For now, implement the basic SYSCALL mechanism:
  // RCX = return address, R11 = saved RFLAGS, then jump to LSTAR.
  // TODO: Full SYSCALL implementation in Sail once MSR support is added.
  (void)rip;
  zGPR.data[1] = zdecode_pos;  // RCX = next instruction
  zGPR.data[11] = rflags;      // R11 = RFLAGS

  // Advance RIP past the SYSCALL instruction.
  zRIP = zdecode_pos;

  // Signal to the run loop that a syscall happened by returning Halt.
  rop->kind = Kind_zHalt;
  rop->variants.zHalt = UNIT;
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
  m.phys_mem.write_bytes(addr, zero, 512);

  // FCW at offset 0x00, FSW at offset 0x02
  u16 cw = (u16)m.zx87_cw;
  u16 sw = (u16)m.zx87_sw;
  m.phys_mem.write_bytes(addr + 0x00, &cw, 2);
  m.phys_mem.write_bytes(addr + 0x02, &sw, 2);

  // Abridged FTW at offset 0x04 (1 bit per register: 0=empty, 1=valid)
  u16 tw = (u16)m.zx87_tw;
  u8 ftw_abridged = 0;
  for (int i = 0; i < 8; i++)
    if (((tw >> (i * 2)) & 3) != 3)
      ftw_abridged |= (1 << i);
  m.phys_mem.write_bytes(addr + 0x04, &ftw_abridged, 1);

  // MXCSR at offset 0x18
  u32 mxcsr = m.mxcsr_state.mxcsr;
  m.phys_mem.write32(addr + 0x18, mxcsr);
  m.phys_mem.write32(addr + 0x1C, 0x0002FFFF);

  // ST0-ST7 at offset 0x20 (16 bytes each, only 10 used)
  for (int i = 0; i < 8; i++) {
    u8 bytes[10];
    bits_to_bytes(m.zx87_ST.data[i], bytes, 10);
    m.phys_mem.write_bytes(addr + 0x20 + i * 16, bytes, 10);
  }

  // XMM0-XMM15 at offset 0xA0 (16 bytes each)
  for (int i = 0; i < 16; i++) {
    u8 bytes[16];
    bits_to_bytes(m.zZMM.data[i], bytes, 16);
    m.phys_mem.write_bytes(addr + 0xA0 + i * 16, bytes, 16);
  }
}

static void fxrstor_common(Model &m, u64 addr) {
  // FCW at offset 0x00, FSW at offset 0x02
  u16 cw, sw;
  m.phys_mem.read_bytes(addr + 0x00, &cw, 2);
  m.phys_mem.read_bytes(addr + 0x02, &sw, 2);
  m.zx87_cw = cw;
  m.zx87_sw = sw;

  // Abridged FTW at offset 0x04 — expand to full tag word
  u8 ftw_abridged;
  m.phys_mem.read_bytes(addr + 0x04, &ftw_abridged, 1);
  u16 tw = 0;
  for (int i = 0; i < 8; i++)
    tw |= ((ftw_abridged & (1 << i)) ? 0 : 3) << (i * 2);
  m.zx87_tw = tw;

  // MXCSR at offset 0x18
  m.mxcsr_state.mxcsr = m.phys_mem.read32(addr + 0x18);

  // ST0-ST7 at offset 0x20
  for (int i = 0; i < 8; i++) {
    u8 bytes[10];
    m.phys_mem.read_bytes(addr + 0x20 + i * 16, bytes, 10);
    RECREATE(lbits)(&m.zx87_ST.data[i]);
    bytes_to_bits(&m.zx87_ST.data[i], bytes, 10, 80);
  }

  // XMM0-XMM15 at offset 0xA0
  for (int i = 0; i < 16; i++) {
    u8 bytes[16];
    m.phys_mem.read_bytes(addr + 0xA0 + i * 16, bytes, 16);
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
  u64 old_bv = phys_mem.read64(addr + 0x200);

  if (rfbm & 3)
    fxsave_common(*this, addr);

  u64 xstate_bv = (old_bv & ~rfbm) | (XCR0 & rfbm);
  phys_mem.write64(addr + 0x200, xstate_bv);
  // XCOMP_BV = 0, reserved = 0.
  u8 zero[56] = {};
  phys_mem.write_bytes(addr + 0x208, zero, 56);

  rop->kind = Kind_zOk;
  rop->variants.zOk = UNIT;
}

void Model::z__xrstor(zExecutionResult *rop, u64 addr, u64 mask) {
  u64 rfbm = mask & XCR0;
  u64 xstate_bv = phys_mem.read64(addr + 0x200);

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
    mxcsr_state.mxcsr = phys_mem.read32(addr + 0x18);

  rop->kind = Kind_zOk;
  rop->variants.zOk = UNIT;
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
// Unsigned integer ↔ float conversions
// =========================================================================

u64 Model::z__f32_to_uint32_trunc(u64 a) {
  float fa;
  memcpy(&fa, &a, 4);
  return (u32)fa;
}
u64 Model::z__f32_to_uint32(u64 a) {
  float fa;
  memcpy(&fa, &a, 4);
  return (u32)rintf(fa);
}
u64 Model::z__f32_to_uint64_trunc(u64 a) {
  float fa;
  memcpy(&fa, &a, 4);
  return (u64)fa;
}
u64 Model::z__f32_to_uint64(u64 a) {
  float fa;
  memcpy(&fa, &a, 4);
  return (u64)rintf(fa);
}
u64 Model::z__f64_to_uint32_trunc(u64 a) {
  double fa;
  memcpy(&fa, &a, 8);
  return (u32)fa;
}
u64 Model::z__f64_to_uint32(u64 a) {
  double fa;
  memcpy(&fa, &a, 8);
  return (u32)rint(fa);
}
u64 Model::z__f64_to_uint64_trunc(u64 a) {
  double fa;
  memcpy(&fa, &a, 8);
  return (u64)fa;
}
u64 Model::z__f64_to_uint64(u64 a) {
  double fa;
  memcpy(&fa, &a, 8);
  return (u64)rint(fa);
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
  int rc = (imm >> 2) & 3;
  // Use host rounding for now (simplified)
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
  int rc = (imm >> 2) & 3;
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
// imm8[1:0] = sign control, imm8[3:2] = interval
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
  // frexp returns [0.5, 1.0), we want [1.0, 2.0) by default
  mantissa *= 2.0f;
  // Sign control: imm[1:0]
  int sc = imm & 3;
  if (sc == 0 && fa < 0)
    mantissa = -mantissa;
  // else sc=1: positive, sc=2: negative, sc=3: positive
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
  mantissa *= 2.0;
  int sc = imm & 3;
  if (sc == 0 && da < 0)
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
// dst = destination, src1 = first source, src2 = lookup table (int32/int64), imm = control
u64 Model::z__f32_fixupimm(u64 dst, u64 src1, u64 src2, u64 imm) {
  // Simplified: for normal cases, return src1 unchanged
  // A full implementation would classify src1 and dst, then use src2 as a lookup table
  float fs;
  memcpy(&fs, &src1, 4);
  u32 r;
  memcpy(&r, &fs, 4);
  return r;
}

u64 Model::z__f64_fixupimm(u64 dst, u64 src1, u64 src2, u64 imm) {
  // Simplified: return src1 unchanged for normal values
  double ds;
  memcpy(&ds, &src1, 8);
  memcpy(&dst, &ds, 8);
  return dst;
}

} // namespace x86

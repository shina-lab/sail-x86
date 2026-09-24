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

// Debug trace to stderr (unbuffered, visible even when stdout is piped)
int trace_stderr(const char *s) {
  fprintf(stderr, "%s\n", s);
  return 0; // unit
}

namespace x86 {
struct DeterministicRandState {
  bool enabled;
  uint64_t state;
};

static DeterministicRandState &deterministic_rand_state() {
  static DeterministicRandState s = []{
    const char *env = getenv("SAIL_X86_DETERMINISTIC_RDRAND");
    if (!env || !*env) return DeterministicRandState{false, 0};
    char *end = nullptr;
    unsigned long long seed = strtoull(env, &end, 0);
    if (!end || *end != '\0') {
      fprintf(stderr,
              "sail-x86: ignoring invalid SAIL_X86_DETERMINISTIC_RDRAND=%s, "
              "using seed 0\n",
              env);
      seed = 0;
    }
    return DeterministicRandState{true, (uint64_t)seed};
  }();
  return s;
}

static inline bool deterministic_rand_enabled() {
  return deterministic_rand_state().enabled;
}

static inline uint64_t deterministic_rand64() {
  uint64_t &state = deterministic_rand_state().state;
  uint64_t z = (state += 0x9E3779B97F4A7C15ULL);
  z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9ULL;
  z = (z ^ (z >> 27)) * 0x94D049BB133111EBULL;
  return z ^ (z >> 31);
}

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

enum zFPCompareResult Model::z__f32_compare(u64 a, u64 b) {
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

enum zFPCompareResult Model::z__f64_compare(u64 a, u64 b) {
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

enum zFPCompareResult Model::z__f16_compare(u64 a, u64 b) {
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

static void sync_rounding_mode(u64 cw);

// The precision-control field of the x87 control word (SDM Vol.1 §8.1.5.2,
// Table 8-2) reduces the significand of FADD, FSUB, FMUL, FDIV and FSQRT
// results to 24 or 53 bits, and the RC field selects the rounding direction
// (Vol.1 §4.8.4).  The host's x87 unit applies both when its control word
// carries the guest's PC and RC bits, so the operation runs between two
// loads of the control word; the volatile accesses keep the compiler from
// moving it outside that window.
static inline u16 host_x87_cw() {
  u16 cw;
  asm volatile("fnstcw %0" : "=m"(cw));
  return cw;
}

static inline void host_x87_set_cw(u16 cw) {
  asm volatile("fldcw %0" : : "m"(cw) : "memory");
}

template <class Op>
static long double f80_arith(u64 guest_cw, long double a, long double b, Op op) {
  u16 saved = host_x87_cw();
  host_x87_set_cw((saved & ~0x0F00) | (guest_cw & 0x0F00));  // PC (9:8) and RC (11:10)
  volatile long double va = a, vb = b;
  volatile long double r = op(va, vb);
  host_x87_set_cw(saved);
  return r;
}

void Model::z__f80_add(lbits *rop, lbits a, lbits b) {
  f80_to_lbits(rop, f80_arith(zx87_cw, lbits_to_f80(a), lbits_to_f80(b),
                              [](long double x, long double y) { return x + y; }));
}

void Model::z__f80_sub(lbits *rop, lbits a, lbits b) {
  f80_to_lbits(rop, f80_arith(zx87_cw, lbits_to_f80(a), lbits_to_f80(b),
                              [](long double x, long double y) { return x - y; }));
}

void Model::z__f80_mul(lbits *rop, lbits a, lbits b) {
  f80_to_lbits(rop, f80_arith(zx87_cw, lbits_to_f80(a), lbits_to_f80(b),
                              [](long double x, long double y) { return x * y; }));
}

void Model::z__f80_div(lbits *rop, lbits a, lbits b) {
  f80_to_lbits(rop, f80_arith(zx87_cw, lbits_to_f80(a), lbits_to_f80(b),
                              [](long double x, long double y) { return x / y; }));
}

void Model::z__f80_sqrt(lbits *rop, lbits a) {
  f80_to_lbits(rop, f80_arith(zx87_cw, lbits_to_f80(a), 0.0L,
                              [](long double x, long double) { return sqrtl(x); }));
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

// FST/FSTP m32fp and m64fp: "the significand of the value being stored is
// rounded to the width of the destination (according to the rounding mode
// specified by the RC field of the FPU control word)" (SDM Vol.2A FST/FSTP,
// Description).
u64 Model::z__f80_to_f32(lbits a) {
  sync_rounding_mode(zx87_cw);
  float fr = (float)lbits_to_f80(a);
  u32 r;
  memcpy(&r, &fr, 4);
  return r;
}

u64 Model::z__f80_to_f64(lbits a) {
  sync_rounding_mode(zx87_cw);
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

// FIST/FISTP round per the RC field, FISTTP truncates.  A value too large
// for the destination, an infinity or a NaN is an invalid operation; with
// #IA masked the integer indefinite 100..00B is stored (SDM Vol.2A
// FIST/FISTP and FISTTP, Description; Vol.1 §8.2.1).
static u64 f80_to_int(long double v, int bits, bool trunc, u64 cw) {
  if (!trunc) sync_rounding_mode(cw);
  long double r = trunc ? truncl(v) : rintl(v);
  long double lim = ldexpl(1.0L, bits - 1);
  u64 mask = bits == 64 ? ~0ULL : (1ULL << bits) - 1;
  if (__builtin_isnan(v) || !(r >= -lim && r < lim))
    return (1ULL << (bits - 1)) & mask;
  return (u64)(i64)r & mask;
}

u64 Model::z__f80_to_int32(lbits a) { return f80_to_int(lbits_to_f80(a), 32, false, zx87_cw); }
u64 Model::z__f80_to_int64(lbits a) { return f80_to_int(lbits_to_f80(a), 64, false, zx87_cw); }
u64 Model::z__f80_to_int32_trunc(lbits a) { return f80_to_int(lbits_to_f80(a), 32, true, zx87_cw); }
u64 Model::z__f80_to_int64_trunc(lbits a) { return f80_to_int(lbits_to_f80(a), 64, true, zx87_cw); }
u64 Model::z__f80_to_int16(lbits a) { return f80_to_int(lbits_to_f80(a), 16, false, zx87_cw); }
u64 Model::z__f80_to_int16_trunc(lbits a) { return f80_to_int(lbits_to_f80(a), 16, true, zx87_cw); }

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
  // FRNDINT rounds "depending on the current rounding mode (setting of the
  // RC field of the FPU control word)" (SDM Vol.2A FRNDINT, Description).
  sync_rounding_mode(zx87_cw);
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
  int ok;
  if (deterministic_rand_enabled()) {
    val = deterministic_rand64();
    ok = 1;
  } else {
    ok = _rdrand64_step(&val);
  }
  struct ztuple_z8z5bv64zCz0z5bv1z9 result;
  result.ztup0 = val;
  result.ztup1 = ok ? 1 : 0;
  return result;
}

struct ztuple_z8z5bv64zCz0z5bv1z9 Model::z__rdseed64(unit) {
  unsigned long long val;
  int ok;
  if (deterministic_rand_enabled()) {
    val = deterministic_rand64();
    ok = 1;
  } else {
    ok = _rdseed64_step(&val);
  }
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

// VCVT(T)SH2SI and the packed VCVT(T)PH2DQ/QQ: a result that exceeds the
// signed range, or a NaN, gives the indefinite integer value 80000000H or
// 80000000_00000000H (SDM Vol. 2C, VCVTSH2SI, Description).
static inline u64 f16_int32_result(float rounded) {
  if (std::isnan(rounded) || rounded < -2147483648.0f || rounded >= 2147483648.0f)
    return 0x80000000u;
  int32_t r = (int32_t)rounded;
  u32 ru; memcpy(&ru, &r, 4); return ru;
}

static inline u64 f16_int64_result(float rounded) {
  if (std::isnan(rounded) || rounded < -9223372036854775808.0f || rounded >= 9223372036854775808.0f)
    return 0x8000000000000000ull;
  int64_t r = (int64_t)rounded;
  u64 ru; memcpy(&ru, &r, 8); return ru;
}

// VCVT(T)SH2USI and the packed VCVT(T)PH2UDQ/UQQ: a result that cannot be
// represented in the unsigned destination (negative, too large, or a NaN)
// gives FFFFFFFFH or FFFFFFFF_FFFFFFFFH (SDM Vol. 2C, VCVTSH2USI and
// VCVTPH2UDQ, Description).
static inline u64 f16_uint32_result(float rounded) {
  if (std::isnan(rounded) || rounded < 0.0f || rounded >= 4294967296.0f)
    return 0xFFFFFFFFu;
  return (uint32_t)rounded;
}

static inline u64 f16_uint64_result(float rounded) {
  if (std::isnan(rounded) || rounded < 0.0f || rounded >= 18446744073709551616.0f)
    return ~0ull;
  return (uint64_t)rounded;
}

u64 Model::z__f16_to_int32(u64 a) {
  _Float16 h; u16 ua = (u16)a; memcpy(&h, &ua, 2);
  SYNC_MXCSR_RC();
  float f = (float)h;
  return f16_int32_result(nearbyintf(f));
}

u64 Model::z__f16_to_int64(u64 a) {
  _Float16 h; u16 ua = (u16)a; memcpy(&h, &ua, 2);
  SYNC_MXCSR_RC();
  float f = (float)h;
  return f16_int64_result(nearbyintf(f));
}

u64 Model::z__f16_to_int32_trunc(u64 a) {
  _Float16 h; u16 ua = (u16)a; memcpy(&h, &ua, 2);
  float f = (float)h;
  return f16_int32_result(truncf(f));
}

u64 Model::z__f16_to_int64_trunc(u64 a) {
  _Float16 h; u16 ua = (u16)a; memcpy(&h, &ua, 2);
  float f = (float)h;
  return f16_int64_result(truncf(f));
}

u64 Model::z__f16_to_uint32(u64 a) {
  _Float16 h; u16 ua = (u16)a; memcpy(&h, &ua, 2);
  SYNC_MXCSR_RC();
  float f = (float)h;
  return f16_uint32_result(nearbyintf(f));
}

u64 Model::z__f16_to_uint64(u64 a) {
  _Float16 h; u16 ua = (u16)a; memcpy(&h, &ua, 2);
  SYNC_MXCSR_RC();
  float f = (float)h;
  return f16_uint64_result(nearbyintf(f));
}

u64 Model::z__f16_to_uint32_trunc(u64 a) {
  _Float16 h; u16 ua = (u16)a; memcpy(&h, &ua, 2);
  float f = (float)h;
  return f16_uint32_result(truncf(f));
}

u64 Model::z__f16_to_uint64_trunc(u64 a) {
  _Float16 h; u16 ua = (u16)a; memcpy(&h, &ua, 2);
  float f = (float)h;
  return f16_uint64_result(truncf(f));
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

// VCVTPH2W / VCVTTPH2W: a result that does not fit int16, or a NaN, gives
// the indefinite integer value 8000H (SDM Vol. 2C, VCVTPH2W, Description).
static inline u64 f16_int16_result(float rounded) {
  if (std::isnan(rounded) || rounded < -32768.0f || rounded > 32767.0f)
    return 0x8000;
  int16_t r = (int16_t)rounded;
  u16 ru; memcpy(&ru, &r, 2); return ru;
}

u64 Model::z__f16_to_int16(u64 a) {
  _Float16 h; u16 ua = (u16)a; memcpy(&h, &ua, 2);
  SYNC_MXCSR_RC();
  float f = (float)h;
  return f16_int16_result(nearbyintf(f));
}

u64 Model::z__f16_to_int16_trunc(u64 a) {
  _Float16 h; u16 ua = (u16)a; memcpy(&h, &ua, 2);
  float f = (float)h;
  return f16_int16_result(truncf(f));
}

u64 Model::z__int16_to_f16(u64 a) {
  int16_t v = (int16_t)(u16)a;
  SYNC_MXCSR_RC();
  _Float16 h = (_Float16)v; u16 r; memcpy(&r, &h, 2); return r;
}

// VCVTPH2UW / VCVTTPH2UW: a result that does not fit uint16 (including a
// negative one), or a NaN, gives the all-ones integer value (SDM Vol. 2C,
// VCVTPH2UW, Description: "the integer value FFFF...H is returned").
static inline u64 f16_uint16_result(float rounded) {
  if (std::isnan(rounded) || rounded < 0.0f || rounded > 65535.0f)
    return 0xFFFF;
  return (uint16_t)rounded;
}

u64 Model::z__f16_to_uint16(u64 a) {
  _Float16 h; u16 ua = (u16)a; memcpy(&h, &ua, 2);
  SYNC_MXCSR_RC();
  float f = (float)h;
  return f16_uint16_result(nearbyintf(f));
}

u64 Model::z__f16_to_uint16_trunc(u64 a) {
  _Float16 h; u16 ua = (u16)a; memcpy(&h, &ua, 2);
  float f = (float)h;
  return f16_uint16_result(truncf(f));
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
  // SDM VSCALEFPH: DEST := SRC1 * POW(2, Floor(SRC2)).
  float fr = fa * exp2f(floorf(fb));
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

// VRNDSCALEPH imm8 (SDM Vol. 2C, round_fp16_to_integer): imm8[7:4] is the
// scale m, imm8[2] selects MXCSR.RC (1) or imm8[1:0] (0) as the rounding
// direction; the result is round(2^m * src) / 2^m.
static inline float f16_round_scaled(float fa, u64 imm, u32 mxcsr) {
  int m = (int)((imm >> 4) & 0xF);
  float scale = exp2f((float)m);
  int saved = fegetround();
  if (imm & 0x04) {
    set_rounding((mxcsr >> 13) & 3);
  } else {
    switch ((int)(imm & 3)) {
    case 0: fesetround(FE_TONEAREST); break;
    case 1: fesetround(FE_DOWNWARD); break;
    case 2: fesetround(FE_UPWARD); break;
    case 3: fesetround(FE_TOWARDZERO); break;
    }
  }
  float fr = nearbyintf(fa * scale) / scale;
  fesetround(saved);
  return fr;
}

u64 Model::z__f16_rndscale(u64 a, u64 imm) {
  _Float16 ha; u16 ua = (u16)a; memcpy(&ha, &ua, 2);
  float fa = (float)ha;
  float fr = f16_round_scaled(fa, imm, mxcsr_state.mxcsr);
  _Float16 hr = (_Float16)fr;
  u16 r; memcpy(&r, &hr, 2); return r;
}

// VGETMANTPH, following the SDM's getmant_fp16 pseudocode (Vol. 2C):
// sign from sign_control[0]; zero and infinity give +/-1.0; a negative
// source with sign_control[1] set gives QNaN_Indefinite; the exponent is
// then set to the bias, or to bias-1 by the normalization interval
// (01: odd unbiased exponent, 10: always, 11: fraction MSB set).
u64 Model::z__f16_getmant(u64 a, u64 imm) {
  const int bias = 15;
  u16 ua = (u16)a;
  unsigned sign = (ua >> 15) & 1;
  int exp = (ua >> 10) & 0x1F;
  unsigned frac = ua & 0x3FF;
  unsigned sign_control = (unsigned)((imm >> 2) & 3);
  unsigned interval = (unsigned)(imm & 3);
  unsigned dst_sign = (sign_control & 1) ? 0 : sign;
  bool zero_operand = (exp == 0) && (frac == 0);
  bool denorm_operand = (exp == 0) && (frac != 0);
  bool inf_operand = (exp == 0x1F) && (frac == 0);
  bool nan_operand = (exp == 0x1F) && (frac != 0);
  if (nan_operand) return ua | 0x0200;  // QNaN(src)
  if (zero_operand || inf_operand) return (u16)((dst_sign << 15) | (bias << 10));
  if (sign && (sign_control & 2)) return 0xFE00;  // QNaN_Indefinite
  if (denorm_operand) {
    if (mxcsr_state.mxcsr & 0x40) {  // DAZ: treat as zero
      frac = 0;
    } else {
      exp = 1;
      while ((frac & 0x200) == 0) { frac <<= 1; exp--; }
      frac = (frac << 1) & 0x3FF;  // drop the leading one into the implicit bit
      exp--;
    }
  }
  int unbiased = exp - bias;
  bool odd_exp = (unbiased & 1) != 0;
  bool msb = (frac & 0x200) != 0;
  int dst_exp;
  switch (interval) {
  case 0: dst_exp = bias; break;
  case 1: dst_exp = odd_exp ? bias - 1 : bias; break;
  case 2: dst_exp = bias - 1; break;
  default: dst_exp = msb ? bias - 1 : bias; break;
  }
  return (u16)((dst_sign << 15) | ((unsigned)dst_exp << 10) | frac);
}

// VREDUCEPH (SDM Vol. 2C): m := imm8[7:4], rc := imm8[1:0], rc_source :=
// imm8[2]; DEST := src - round(2^m * src) / 2^m, the same imm8 layout as
// VRNDSCALEPH.
u64 Model::z__f16_reduce(u64 a, u64 imm) {
  _Float16 ha; u16 ua = (u16)a; memcpy(&ha, &ua, 2);
  float fa = (float)ha;
  float rounded = f16_round_scaled(fa, imm, mxcsr_state.mxcsr);
  float fr = fa - rounded;
  _Float16 hr = (_Float16)fr;
  u16 r; memcpy(&r, &hr, 2); return r;
}

} // namespace x86

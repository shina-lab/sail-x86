#pragma once

// Shared helper functions for converting between lbits and byte arrays.
// Used by both shared and per-mode external function implementations.

#include "sail_x86_model.h"
#include <cstring>

namespace x86 {

static inline void bits_to_bytes(lbits val, u8 *out, size_t nbytes) {
  // lbits stores data in mpz_t. Extract bytes in little-endian order.
  mpz_t tmp;
  mpz_init_set(tmp, *val.bits);
  for (size_t i = 0; i < nbytes; i++) {
    out[i] = (u8)(mpz_get_ui(tmp) & 0xFF);
    mpz_fdiv_q_2exp(tmp, tmp, 8);
  }
  mpz_clear(tmp);
}

static inline void bytes_to_bits(lbits *out, const u8 *in, size_t nbytes, size_t nbits) {
  mpz_set_ui(*out->bits, 0);
  for (size_t i = nbytes; i > 0; i--) {
    mpz_mul_2exp(*out->bits, *out->bits, 8);
    mpz_add_ui(*out->bits, *out->bits, in[i - 1]);
  }
  out->len = nbits;
}

// Feature level helpers — mirror the Sail enable_features_v* functions.
// Call after model_init() + zinitializze_registers().

static inline void clear_all_features(Model &m) {
  m.zhas_popcnt = false;
  m.zhas_lzzcnt = false;
  m.zhas_bmi1 = false;
  m.zhas_bmi2 = false;
  m.zhas_fma = false;
  m.zhas_aesni = false;
  m.zhas_pclmulqdq = false;
  m.zhas_f16c = false;
  m.zhas_movbe = false;
  m.zhas_adx = false;
  m.zhas_sha = false;
  m.zhas_rdrand = false;
  m.zhas_rdseed = false;
  m.zhas_crc32 = false;
  m.zhas_avx512 = false;
}

// x86-64-v1: baseline 64-bit (SSE2, no extensions)
static inline void enable_features_v1(Model &m) {
  m.zCR0 = (m.zCR0 & ~(1ULL << 2)) | (1ULL << 1);  // clear EM, set MP
  m.zCR4 = m.zCR4 | (1ULL << 9) | (1ULL << 10);     // OSFXSR + OSXMMEXCPT
  m.zXCR0_SUPPORTED = 0x03;
  m.zXCR0 = 0x03;  // x87 + SSE
  clear_all_features(m);
}

// x86-64-v2: Nehalem+ (SSE4.2, POPCNT)
static inline void enable_features_v2(Model &m) {
  enable_features_v1(m);
  m.zhas_popcnt = true;
  m.zhas_crc32 = true;
  m.zhas_pclmulqdq = true;
}

// x86-64-v3: Haswell+ (AVX2, FMA, BMI1/2, F16C, MOVBE)
static inline void enable_features_v3(Model &m) {
  enable_features_v2(m);
  m.zCR4 = m.zCR4 | (1ULL << 18);  // OSXSAVE
  m.zXCR0_SUPPORTED = 0x07;
  m.zXCR0 = 0x07;  // + AVX
  m.zhas_bmi1 = true;
  m.zhas_bmi2 = true;
  m.zhas_fma = true;
  m.zhas_lzzcnt = true;
  m.zhas_f16c = true;
  m.zhas_movbe = true;
  m.zhas_rdrand = true;
  m.zhas_aesni = true;
  m.zhas_adx = true;
}

// x86-64-v4: Skylake-X+ (AVX-512)
static inline void enable_features_v4(Model &m) {
  enable_features_v3(m);
  m.zXCR0_SUPPORTED = 0xE7;
  m.zXCR0 = 0xE7;  // + opmask + ZMM
  m.zhas_avx512 = true;
  m.zhas_rdseed = true;
  m.zhas_sha = true;
}

// Alias
static inline void enable_all_features(Model &m) { enable_features_v4(m); }

} // namespace x86

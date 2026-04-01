#pragma once

// Shared helper functions for converting between lbits and byte arrays.
// Used by both shared and per-mode external function implementations.

#include "sail_x86_model.h"
#include <cstring>

namespace x86 {

// Segment register indices (matching Sail segreg_idx constants).
constexpr int SEG_ES = 0;
constexpr int SEG_CS = 1;
constexpr int SEG_SS = 2;
constexpr int SEG_DS = 3;
constexpr int SEG_FS = 4;
constexpr int SEG_GS = 5;

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

// Enable all CPU features (x86-64-v4 level).
// Call after model_init() + zinitializze_registers().
static inline void enable_all_features(Model &m) {
  // CR0: clear EM, set MP
  m.zCR0 = (m.zCR0 & ~(1ULL << 2)) | (1ULL << 1);

  // CR4: OSFXSR + OSXMMEXCPT + OSXSAVE
  m.zCR4 = m.zCR4 | (1ULL << 9) | (1ULL << 10) | (1ULL << 18);

  // XCR0: x87 + SSE + AVX + opmask + ZMM_Hi256 + Hi16_ZMM
  m.zXCR0_SUPPORTED = 0xE7;
  m.zXCR0 = 0xE7;

  // CPUID feature flags
  m.zhas_sse3 = true;
  m.zhas_ssse3 = true;
  m.zhas_sse4_1 = true;
  m.zhas_sse4_2 = true;
  m.zhas_cx16 = true;
  m.zhas_xsave = true;
  m.zhas_popcnt = true;
  m.zhas_lzzcnt = true;
  m.zhas_bmi1 = true;
  m.zhas_bmi2 = true;
  m.zhas_fma = true;
  m.zhas_aesni = true;
  m.zhas_pclmulqdq = true;
  m.zhas_f16c = true;
  m.zhas_movbe = true;
  m.zhas_adx = true;
  m.zhas_sha = true;
  m.zhas_rdrand = true;
  m.zhas_rdseed = true;
  m.zhas_crc32 = true;
  m.zhas_movdiri = true;
  m.zhas_movdir64b = true;
  m.zhas_avx512 = true;
  m.zhas_la57 = true;
  m.zhas_vmx = true;
}

} // namespace x86

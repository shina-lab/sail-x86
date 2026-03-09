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

} // namespace x86

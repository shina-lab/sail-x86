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

// Convert between lbits and little-endian byte buffers using only Sail's
// public bitvector API (no direct GMP access). Call sites include x87
// 80-bit floats, 128-bit AES/XMM state, and __read_mem/__write_mem up to
// 64 bytes, so any width up to 512 bits is supported.

// Read a little-endian fbits chunk of `width` bits (≤64) starting at byte
// offset `byte_off` from `in`.
static inline fbits read_fbits_le(const u8 *in, size_t byte_off, size_t width) {
  size_t nbytes = (width + 7) / 8;
  fbits v = 0;
  for (size_t i = nbytes; i > 0; i--) {
    v = (v << 8) | in[byte_off + i - 1];
  }
  if (width < 64) v &= ((fbits)1 << width) - 1;
  return v;
}

static inline void bits_to_bytes(lbits val, u8 *out, size_t nbytes) {
  size_t nbits = nbytes * 8;

  // ≤64-bit fast path: one conversion, no sail_int/lbits allocation.
  if (nbits <= 64) {
    fbits v = CONVERT_OF(fbits, lbits)(val, true);
    for (size_t i = 0; i < nbytes; i++) out[i] = (u8)(v >> (i * 8));
    return;
  }

  // General path: slice into 64-bit chunks from the low end upward.
  sail_int start_si;
  sail_int len_si;
  CREATE(sail_int)(&start_si);
  CREATE(sail_int)(&len_si);
  lbits chunk;
  CREATE(lbits)(&chunk);

  for (size_t off = 0; off < nbits; off += 64) {
    size_t take = (nbits - off > 64) ? 64 : (nbits - off);
    CONVERT_OF(sail_int, mach_int)(&start_si, (mach_int)off);
    CONVERT_OF(sail_int, mach_int)(&len_si, (mach_int)take);
    slice(&chunk, val, start_si, len_si);
    fbits v = CONVERT_OF(fbits, lbits)(chunk, true);
    size_t byte_off = off / 8;
    size_t chunk_bytes = (take + 7) / 8;
    for (size_t i = 0; i < chunk_bytes; i++) {
      out[byte_off + i] = (u8)(v >> (i * 8));
    }
  }

  KILL(lbits)(&chunk);
  KILL(sail_int)(&len_si);
  KILL(sail_int)(&start_si);
}

static inline void bytes_to_bits(lbits *out, const u8 *in, size_t nbytes, size_t nbits) {
  (void)nbytes;

  // ≤64-bit fast path.
  if (nbits <= 64) {
    fbits v = read_fbits_le(in, 0, nbits);
    CONVERT_OF(lbits, fbits)(out, v, (uint64_t)nbits, true);
    return;
  }

  // General path: build the value high-to-low via append. The highest
  // chunk may be narrower than 64 bits when nbits isn't a multiple of 64.
  size_t top_width = (nbits % 64 != 0) ? (nbits % 64) : 64;
  size_t top_bit_off = nbits - top_width;
  fbits top = read_fbits_le(in, top_bit_off / 8, top_width);

  lbits acc;
  lbits tmp;
  lbits low_chunk;
  CREATE(lbits)(&acc);
  CREATE(lbits)(&tmp);
  CREATE(lbits)(&low_chunk);
  CONVERT_OF(lbits, fbits)(&acc, top, (uint64_t)top_width, true);

  // Append each remaining 64-bit chunk on the low side.
  size_t next_bit = top_bit_off;
  while (next_bit > 0) {
    next_bit -= 64;
    fbits v = read_fbits_le(in, next_bit / 8, 64);
    CONVERT_OF(lbits, fbits)(&low_chunk, v, 64, true);
    append(&tmp, acc, low_chunk);
    COPY(lbits)(&acc, tmp);
  }

  COPY(lbits)(out, acc);
  KILL(lbits)(&low_chunk);
  KILL(lbits)(&tmp);
  KILL(lbits)(&acc);
}

// Replace bits 127:0 of a 512-bit register with 16 little-endian bytes and
// keep bits 511:128 (FXRSTOR: a non-VEX instruction on XMM state does not
// access the upper bits, SDM Vol.1 §14.8).  The register stays 512 bits
// wide; building it from the 16 bytes alone would leave a 128-bit lbits
// that the model's 512-bit slices reject.
static inline void set_zmm_low128(lbits &zmm, const u8 *bytes) {
  lbits low;
  CREATE(lbits)(&low);
  bytes_to_bits(&low, bytes, 16, 128);
  mpz_fdiv_q_2exp(*zmm.bits, *zmm.bits, 128);
  mpz_mul_2exp(*zmm.bits, *zmm.bits, 128);
  mpz_ior(*zmm.bits, *zmm.bits, *low.bits);
  zmm.len = 512;
  KILL(lbits)(&low);
}

// Enable all CPU features: the model's own x86-64-v4 profile (CR0/CR4/XCR0
// and every has_* flag it knows, so a flag added in regs.sail is picked up
// here automatically) plus the extensions the emulators expose beyond it.
// Call after model_init() + zinitializze_registers().
static inline void enable_all_features(Model &m) {
  m.zenable_features_all(UNIT);
  m.zhas_movdiri = true;
  m.zhas_movdir64b = true;
  m.zhas_la57 = true;
}

} // namespace x86

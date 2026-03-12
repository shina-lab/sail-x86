// SIMD equivalence test functions for Isla symbolic execution.
// Each pair (orig/opt) encodes concrete instruction bytes for the original
// and optimized SIMD sequences. Isla produces symbolic traces that
// prove_equiv.py feeds to Z3 for equivalence checking.
//
// Programs covered: FFmpeg (vf_blend.asm), libjpeg-turbo (jquanti-sse2.asm)
//
// Usage: pass this file via -splice alongside model/isla_overrides.sail,
// and --isla-preserve each test function name.

// --- Candidate 1: DIFFERENCE blend ---
// Original: widen to words, subtract, abs (SSE2), pack back (18 instrs)
// Optimized: psubusb + psubusb + por (4 instrs)
// Input: xmm0 = top, xmm1 = bottom. Result in xmm0.

val test_difference_orig : unit -> bits(128)
function test_difference_orig() = {
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4d2ef0f66);  // pxor xmm2, xmm2
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4d86f0f66);  // movdqa xmm3, xmm0
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4c2600f66);  // punpcklbw xmm0, xmm2
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4da680f66);  // punpckhbw xmm3, xmm2
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4e16f0f66);  // movdqa xmm4, xmm1
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4ca600f66);  // punpcklbw xmm1, xmm2
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4e2680f66);  // punpckhbw xmm4, xmm2
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4c1f90f66);  // psubw xmm0, xmm1
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4dcf90f66);  // psubw xmm3, xmm4
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4c9ef0f66);  // pxor xmm1, xmm1
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4e4ef0f66);  // pxor xmm4, xmm4
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4c8650f66);  // pcmpgtw xmm1, xmm0
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4e3650f66);  // pcmpgtw xmm4, xmm3
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4c1ef0f66);  // pxor xmm0, xmm1
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4dcef0f66);  // pxor xmm3, xmm4
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4c1f90f66);  // psubw xmm0, xmm1
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4dcf90f66);  // psubw xmm3, xmm4
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4c3670f66);  // packuswb xmm0, xmm3
  read_xmm(0)
}

val test_difference_opt : unit -> bits(128)
function test_difference_opt() = {
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4d06f0f66);  // movdqa xmm2, xmm0
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4c1d80f66);  // psubusb xmm0, xmm1
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4cad80f66);  // psubusb xmm1, xmm2
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4c1eb0f66);  // por xmm0, xmm1
  read_xmm(0)
}

// --- Candidate 2: PHOENIX blend ---
// Original: pminub/pmaxub/psubusb/paddusb (6 instrs)
// Optimized: psubusb/psubusb/por/pxor (5 instrs)
// Input: xmm0 = top, xmm1 = bottom, xmm3 = 0xFF. Result: orig in xmm2, opt in xmm0.

val test_phoenix_orig : unit -> bits(128)
function test_phoenix_orig() = {
  write_xmm_legacy(3, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4d06f0f66);  // movdqa xmm2, xmm0
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4c1da0f66);  // pminub xmm0, xmm1
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4cade0f66);  // pmaxub xmm1, xmm2
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4d36f0f66);  // movdqa xmm2, xmm3
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4d1d80f66);  // psubusb xmm2, xmm1
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4d0dc0f66);  // paddusb xmm2, xmm0
  read_xmm(2)
}

val test_phoenix_opt : unit -> bits(128)
function test_phoenix_opt() = {
  write_xmm_legacy(3, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4d06f0f66);  // movdqa xmm2, xmm0
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4c1d80f66);  // psubusb xmm0, xmm1
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4cad80f66);  // psubusb xmm1, xmm2
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4c1eb0f66);  // por xmm0, xmm1
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4c3ef0f66);  // pxor xmm0, xmm3
  read_xmm(0)
}

// --- Candidate 3: MULTIPLY macro ---
// Original: pmullw/paddw/movdqa/psrlw/paddw/psrlw (6 instrs, clobbers xmm1)
// Optimized: pmullw/paddw/pmulhuw (3 instrs, preserves xmm1)
// Input: xmm0 = a, xmm1 = b (words in [0,255]). Result in xmm0.

val test_multiply_orig : unit -> bits(128)
function test_multiply_orig() = {
  // xmm5 = pw_1 (all words = 1)
  write_xmm_legacy(5, 0x00010001000100010001000100010001);
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4c1d50f66);  // pmullw xmm0, xmm1
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4c5fd0f66);  // paddw xmm0, xmm5
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4c86f0f66);  // movdqa xmm1, xmm0
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F408d1710f66);  // psrlw xmm1, 8
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4c1fd0f66);  // paddw xmm0, xmm1
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F408d0710f66);  // psrlw xmm0, 8
  read_xmm(0)
}

val test_multiply_opt : unit -> bits(128)
function test_multiply_opt() = {
  // xmm5 = pw_128 (all words = 128), xmm6 = pw_257 (all words = 0x0101)
  write_xmm_legacy(5, 0x00800080008000800080008000800080);
  write_xmm_legacy(6, 0x01010101010101010101010101010101);
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4c1d50f66);  // pmullw xmm0, xmm1
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4c5fd0f66);  // paddw xmm0, xmm5
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4c6e40f66);  // pmulhuw xmm0, xmm6
  read_xmm(0)
}

// --- Candidate 4: EXTREMITY blend (FFmpeg vf_blend.asm:366-399) ---
// Computes |255 - top - bottom| for each byte lane.
// Original: widen to words, subtract from 255, abs (SSE2), pack back (21 instrs)
// Optimized: pxor(~top) + psubusb + psubusb + por (6 instrs)
// Input: xmm0 = top, xmm1 = bottom. Result: orig in xmm3, opt in xmm0.

val test_extremity_orig : unit -> bits(128)
function test_extremity_orig() = {
  // Setup: xmm2 = 0 (zero register), xmm4 = pw_255 (all words = 0x00FF)
  write_xmm_legacy(2, 0x00000000000000000000000000000000);
  write_xmm_legacy(4, 0x00FF00FF00FF00FF00FF00FF00FF00FF);
  // Widen top bytes to words (hi/lo halves)
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4e86f0f66);  // movdqa xmm5, xmm0
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4ea680f66);  // punpckhbw xmm5, xmm2
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4c2600f66);  // punpcklbw xmm0, xmm2
  // Widen bottom bytes to words (hi/lo halves)
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4f16f0f66);  // movdqa xmm6, xmm1
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4f2680f66);  // punpckhbw xmm6, xmm2
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4ca600f66);  // punpcklbw xmm1, xmm2
  // 255 - top_lo, 255 - top_hi
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4dc6f0f66);  // movdqa xmm3, xmm4
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4d8f90f66);  // psubw xmm3, xmm0
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4fc6f0f66);  // movdqa xmm7, xmm4
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4fdf90f66);  // psubw xmm7, xmm5
  // (255 - top) - bottom
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4d9f90f66);  // psubw xmm3, xmm1
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4fef90f66);  // psubw xmm7, xmm6
  // ABS2: SSE2 absolute value via pcmpgtw/pxor/psubw
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4c9ef0f66);  // pxor xmm1, xmm1
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4cb650f66);  // pcmpgtw xmm1, xmm3
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4d9ef0f66);  // pxor xmm3, xmm1
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4d9f90f66);  // psubw xmm3, xmm1
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4f6ef0f66);  // pxor xmm6, xmm6
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4f7650f66);  // pcmpgtw xmm6, xmm7
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4feef0f66);  // pxor xmm7, xmm6
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4fef90f66);  // psubw xmm7, xmm6
  // Pack words back to bytes
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4df670f66);  // packuswb xmm3, xmm7
  read_xmm(3)
}

val test_extremity_opt : unit -> bits(128)
function test_extremity_opt() = {
  // 255 - top = top XOR 0xFF, then absdiff via psubusb+psubusb+por
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4d2740f66);  // pcmpeqb xmm2, xmm2 (all 0xFF)
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4c2ef0f66);  // pxor xmm0, xmm2    (255 - top)
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4d86f0f66);  // movdqa xmm3, xmm0  (save)
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4c1d80f66);  // psubusb xmm0, xmm1 (max(0, ~top - bot))
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4cbd80f66);  // psubusb xmm1, xmm3 (max(0, bot - ~top))
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4c1eb0f66);  // por xmm0, xmm1     (|255 - top - bottom|)
  read_xmm(0)
}

// --- Candidate 5: NEGATION blend (FFmpeg vf_blend.asm:401-436) ---
// Computes 255 - |255 - top - bottom| for each byte lane.
// Original: widen, subtract, abs, invert, pack (25 instrs)
// Optimized: pxor(~top) + psubusb + psubusb + por + pxor (7 instrs)
// Input: xmm0 = top, xmm1 = bottom. Result in xmm0 for both.

val test_negation_orig : unit -> bits(128)
function test_negation_orig() = {
  // Setup: xmm2 = 0, xmm4 = pw_255
  write_xmm_legacy(2, 0x00000000000000000000000000000000);
  write_xmm_legacy(4, 0x00FF00FF00FF00FF00FF00FF00FF00FF);
  // Widen top
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4e86f0f66);  // movdqa xmm5, xmm0
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4ea680f66);  // punpckhbw xmm5, xmm2
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4c2600f66);  // punpcklbw xmm0, xmm2
  // Widen bottom
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4f16f0f66);  // movdqa xmm6, xmm1
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4f2680f66);  // punpckhbw xmm6, xmm2
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4ca600f66);  // punpcklbw xmm1, xmm2
  // 255 - top - bottom (in words)
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4dc6f0f66);  // movdqa xmm3, xmm4
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4d8f90f66);  // psubw xmm3, xmm0
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4fc6f0f66);  // movdqa xmm7, xmm4
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4fdf90f66);  // psubw xmm7, xmm5
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4d9f90f66);  // psubw xmm3, xmm1
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4fef90f66);  // psubw xmm7, xmm6
  // ABS2 (SSE2)
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4c9ef0f66);  // pxor xmm1, xmm1
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4cb650f66);  // pcmpgtw xmm1, xmm3
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4d9ef0f66);  // pxor xmm3, xmm1
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4d9f90f66);  // psubw xmm3, xmm1
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4f6ef0f66);  // pxor xmm6, xmm6
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4f7650f66);  // pcmpgtw xmm6, xmm7
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4feef0f66);  // pxor xmm7, xmm6
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4fef90f66);  // psubw xmm7, xmm6
  // 255 - |255 - top - bottom|, then pack
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4c46f0f66);  // movdqa xmm0, xmm4
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4c3f90f66);  // psubw xmm0, xmm3
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4cc6f0f66);  // movdqa xmm1, xmm4
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4cff90f66);  // psubw xmm1, xmm7
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4c1670f66);  // packuswb xmm0, xmm1
  read_xmm(0)
}

val test_negation_opt : unit -> bits(128)
function test_negation_opt() = {
  // 255 - |255 - top - bottom| = ~(absdiff(~top, bottom))
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4d2740f66);  // pcmpeqb xmm2, xmm2 (all 0xFF)
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4c2ef0f66);  // pxor xmm0, xmm2    (255 - top)
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4d86f0f66);  // movdqa xmm3, xmm0  (save)
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4c1d80f66);  // psubusb xmm0, xmm1 (max(0, ~top - bot))
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4cbd80f66);  // psubusb xmm1, xmm3 (max(0, bot - ~top))
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4c1eb0f66);  // por xmm0, xmm1     (|255 - top - bottom|)
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4c2ef0f66);  // pxor xmm0, xmm2    (255 - result)
  read_xmm(0)
}

// --- Candidate 6: Absolute value SSE2 vs SSSE3 (libjpeg-turbo jquanti-sse2.asm) ---
// SSE2 manual abs: movdqa + psraw + pxor + psubw (4 instrs)
// SSSE3 pabsw: single instruction (1 instr)
// Input: xmm4 = signed word values (symbolic). Result in xmm0.

val test_abs16_sse2 : unit -> bits(128)
function test_abs16_sse2() = {
  // SSE2 absolute value: abs(x) = ((x >> 15) ^ x) - (x >> 15)
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4c46f0f66);  // movdqa xmm0, xmm4
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F40fe4710f66);  // psraw xmm4, 15
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4c4ef0f66);  // pxor xmm0, xmm4
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4c4f90f66);  // psubw xmm0, xmm4
  read_xmm(0)
}

val test_abs16_ssse3 : unit -> bits(128)
function test_abs16_ssse3() = {
  // SSSE3 pabsw: absolute value in one instruction
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4c41d380f66);  // pabsw xmm0, xmm4
  read_xmm(0)
}

// --- Candidate 7: MULTIPLY byte-constrained (FFmpeg vf_blend.asm:117-123) ---
// Same div-by-255 as Candidate 3, but with punpcklbw to naturally
// constrain word inputs to [0,255]. This proves the two approximations
// agree for byte products — the operationally valid range.
// Input: xmm0 = bytes A, xmm1 = bytes B (symbolic). Result in xmm0.

val test_multiply_byte_orig : unit -> bits(128)
function test_multiply_byte_orig() = {
  // Constants
  write_xmm_legacy(5, 0x00010001000100010001000100010001);  // pw_1
  write_xmm_legacy(7, 0x00000000000000000000000000000000);  // zero
  // Zero-extend low 8 bytes to 8 words in [0,255]
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4c7600f66);  // punpcklbw xmm0, xmm7
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4cf600f66);  // punpcklbw xmm1, xmm7
  // Original MULTIPLY: (x + 1 + ((x + 1) >> 8)) >> 8
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4c1d50f66);  // pmullw xmm0, xmm1
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4c5fd0f66);  // paddw xmm0, xmm5
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4c86f0f66);  // movdqa xmm1, xmm0
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F408d1710f66);  // psrlw xmm1, 8
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4c1fd0f66);  // paddw xmm0, xmm1
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F408d0710f66);  // psrlw xmm0, 8
  read_xmm(0)
}

val test_multiply_byte_opt : unit -> bits(128)
function test_multiply_byte_opt() = {
  // Constants
  write_xmm_legacy(5, 0x00800080008000800080008000800080);  // pw_128
  write_xmm_legacy(6, 0x01010101010101010101010101010101);  // pw_257
  write_xmm_legacy(7, 0x00000000000000000000000000000000);  // zero
  // Zero-extend (same as orig — shares symbolic byte inputs)
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4c7600f66);  // punpcklbw xmm0, xmm7
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4cf600f66);  // punpcklbw xmm1, xmm7
  // Optimized MULTIPLY: (x + 128) * 257 >> 16
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4c1d50f66);  // pmullw xmm0, xmm1
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4c5fd0f66);  // paddw xmm0, xmm5
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4c6e40f66);  // pmulhuw xmm0, xmm6
  read_xmm(0)
}

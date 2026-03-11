// FFmpeg equivalence test functions for Isla symbolic execution.
// Each pair (orig/opt) encodes concrete instruction bytes for the original
// and optimized SIMD sequences. Isla produces symbolic traces that
// prove_ffmpeg_equiv.py feeds to Z3 for equivalence checking.
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

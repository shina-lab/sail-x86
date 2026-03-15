// Equivalence test functions for FFmpeg blend optimizations.
// Each pair (test_*_orig, test_*_opt) encodes the original and optimized
// instruction sequences. ISLA symbolic execution + Z3 proves equivalence.

// Helper: execute one 4-byte instruction (66 0F XX ModRM), resetting RIP.
val exec4 : bits(32) -> unit
function exec4(insn) = {
  let base : bits(64) = 0x0000000000400000;
  RIP = base;
  insn_start = base;
  let b0 : bits(8) = insn[31..24];
  let b1 : bits(8) = insn[23..16];
  let b2 : bits(8) = insn[15..8];
  let b3 : bits(8) = insn[7..0];
  insn_buf = 0xF4 @ 0xF4 @ 0xF4 @ 0xF4 @ 0xF4 @ 0xF4 @ 0xF4 @
             0xF4 @ 0xF4 @ 0xF4 @ 0xF4 @ b3 @ b2 @ b1 @ b0;
  let _ = step();
  ()
}

// Helper: execute one 5-byte instruction (66 0F 38 XX ModRM), resetting RIP.
val exec5 : bits(40) -> unit
function exec5(insn) = {
  let base : bits(64) = 0x0000000000400000;
  RIP = base;
  insn_start = base;
  let b0 : bits(8) = insn[39..32];
  let b1 : bits(8) = insn[31..24];
  let b2 : bits(8) = insn[23..16];
  let b3 : bits(8) = insn[15..8];
  let b4 : bits(8) = insn[7..0];
  insn_buf = 0xF4 @ 0xF4 @ 0xF4 @ 0xF4 @ 0xF4 @ 0xF4 @ 0xF4 @
             0xF4 @ 0xF4 @ 0xF4 @ b4 @ b3 @ b2 @ b1 @ b0;
  let _ = step();
  ()
}

// =========================================================================
// HARDMIX 8-bit: (a+b >= 255) ? 0xFF : 0x00
// Original: pxor/pxor/pcmpgtb/pxor (4 instrs, 3 constants)
// Optimized: paddusb/pcmpeqb (2 instrs, 1 constant)
// =========================================================================

val test_hardmix_orig : unit -> unit
function test_hardmix_orig() = {
  // xmm0 = a (symbolic), xmm1 = b (symbolic)
  write_xmm(2, replicate_bits(0xFF : bits(8), 16));
  write_xmm(3, replicate_bits(0x80 : bits(8), 16));
  write_xmm(4, replicate_bits(0x7F : bits(8), 16));
  exec4(0x660FEFCC);  // pxor xmm1, xmm4
  exec4(0x660FEFC3);  // pxor xmm0, xmm3
  exec4(0x660F64C8);  // pcmpgtb xmm1, xmm0
  exec4(0x660FEFCA);  // pxor xmm1, xmm2
  Final_result = read_xmm(1)
}

val test_hardmix_opt : unit -> unit
function test_hardmix_opt() = {
  write_xmm(2, replicate_bits(0xFF : bits(8), 16));
  exec4(0x660FDCC1);  // paddusb xmm0, xmm1
  exec4(0x660F74C2);  // pcmpeqb xmm0, xmm2
  Final_result = read_xmm(0)
}

// =========================================================================
// PHOENIX 8-bit: 255 - |a - b|
// Original: pminub/pmaxub/psubusb/paddusb (6 instrs with copies)
// Optimized: psubusb/psubusb/por/pxor (5 instrs with copy)
// =========================================================================

val test_phoenix_orig : unit -> unit
function test_phoenix_orig() = {
  // xmm0 = a (symbolic), xmm1 = b (symbolic), xmm3 = 0xFF
  write_xmm(3, replicate_bits(0xFF : bits(8), 16));
  exec4(0x660F6FD0);  // movdqa xmm2, xmm0  (save a)
  exec4(0x660FDAC1);  // pminub xmm0, xmm1
  exec4(0x660FDECA);  // pmaxub xmm1, xmm2
  exec4(0x660F6FD3);  // movdqa xmm2, xmm3  (copy 255)
  exec4(0x660FD8D1);  // psubusb xmm2, xmm1
  exec4(0x660FDCD0);  // paddusb xmm2, xmm0
  Final_result = read_xmm(2)
}

val test_phoenix_opt : unit -> unit
function test_phoenix_opt() = {
  write_xmm(3, replicate_bits(0xFF : bits(8), 16));
  exec4(0x660F6FD0);  // movdqa xmm2, xmm0
  exec4(0x660FD8C1);  // psubusb xmm0, xmm1
  exec4(0x660FD8CA);  // psubusb xmm1, xmm2
  exec4(0x660FEBC1);  // por xmm0, xmm1
  exec4(0x660FEFC3);  // pxor xmm0, xmm3
  Final_result = read_xmm(0)
}

// =========================================================================
// DIFFERENCE 16-bit: |a - b| for unsigned 16-bit words
// Original: widen to dword, psubd, pabsd, packssdw (11 instrs)
// Optimized: psubusw/psubusw/por (4 instrs)
// =========================================================================

val test_difference16_orig : unit -> unit
function test_difference16_orig() = {
  // xmm0 = a (symbolic), xmm1 = b (symbolic), xmm2 = zero
  write_xmm(2, replicate_bits(0x0000 : bits(16), 8));
  // movdqa xmm3, xmm0; punpckhwd xmm3, xmm2  (widen a high)
  exec4(0x660F6FD8);  // movdqa xmm3, xmm0
  exec4(0x660F69DA);  // punpckhwd xmm3, xmm2
  exec4(0x660F61C2);  // punpcklwd xmm0, xmm2  (widen a low)
  // movdqa xmm4, xmm1; punpckhwd xmm4, xmm2  (widen b high)
  exec4(0x660F6FE1);  // movdqa xmm4, xmm1
  exec4(0x660F69E2);  // punpckhwd xmm4, xmm2
  exec4(0x660F61CA);  // punpcklwd xmm1, xmm2  (widen b low)
  exec4(0x660FFAC1);  // psubd xmm0, xmm1  (low)
  exec4(0x660FFADC);  // psubd xmm3, xmm4  (high)
  exec5(0x660F381EC0);  // pabsd xmm0, xmm0
  exec5(0x660F381EDB);  // pabsd xmm3, xmm3
  exec5(0x660F382BC3);  // packusdw xmm0, xmm3  (SSE4.1)
  Final_result = read_xmm(0)
}

val test_difference16_opt : unit -> unit
function test_difference16_opt() = {
  exec4(0x660F6FD0);  // movdqa xmm2, xmm0
  exec4(0x660FD9C1);  // psubusw xmm0, xmm1
  exec4(0x660FD9CA);  // psubusw xmm1, xmm2
  exec4(0x660FEBC1);  // por xmm0, xmm1
  Final_result = read_xmm(0)
}

// =========================================================================
// EXTREMITY 16-bit: |65535 - a - b| = |~a - b|
// Original: widen, sub from 65535, sub b, pabsd, pack (13 instrs)
// Optimized: pxor/psubusw/psubusw/por (5 instrs)
// =========================================================================

val test_extremity16_orig : unit -> unit
function test_extremity16_orig() = {
  // xmm0 = a, xmm1 = b, xmm2 = zero, xmm4 = 65535 as dwords
  write_xmm(2, replicate_bits(0x0000 : bits(16), 8));
  write_xmm(4, replicate_bits(0x0000FFFF : bits(32), 4));
  // Widen a: movdqa xmm5, xmm0; punpckhwd xmm5, xmm2; punpcklwd xmm0, xmm2
  exec4(0x660F6FE8);  // movdqa xmm5, xmm0
  exec4(0x660F69EA);  // punpckhwd xmm5, xmm2
  exec4(0x660F61C2);  // punpcklwd xmm0, xmm2
  // Widen b: movdqa xmm6, xmm1; punpckhwd xmm6, xmm2; punpcklwd xmm1, xmm2
  exec4(0x660F6FF1);  // movdqa xmm6, xmm1
  exec4(0x660F69F2);  // punpckhwd xmm6, xmm2
  exec4(0x660F61CA);  // punpcklwd xmm1, xmm2
  // m3 = 65535 - a_lo; m7 = 65535 - a_hi
  // psubd xmm3, xmm4, xmm0 -> movdqa xmm3, xmm4; psubd xmm3, xmm0
  exec4(0x660F6FDC);  // movdqa xmm3, xmm4
  exec4(0x660FFAD8);  // psubd xmm3, xmm0
  exec4(0x660F6FFC);  // movdqa xmm7, xmm4
  exec4(0x660FFAFD);  // psubd xmm7, xmm5
  // Subtract b
  exec4(0x660FFAD9);  // psubd xmm3, xmm1
  exec4(0x660FFAFE);  // psubd xmm7, xmm6
  // Abs
  exec5(0x660F381EDB);  // pabsd xmm3, xmm3
  exec5(0x660F381EFF);  // pabsd xmm7, xmm7
  // Pack
  exec5(0x660F382BDF);  // packusdw xmm3, xmm7  (SSE4.1)
  Final_result = read_xmm(3)
}

val test_extremity16_opt : unit -> unit
function test_extremity16_opt() = {
  write_xmm(3, replicate_bits(0xFFFF : bits(16), 8));
  exec4(0x660FEFC3);  // pxor xmm0, xmm3  (~a)
  exec4(0x660F6FD0);  // movdqa xmm2, xmm0
  exec4(0x660FD9C1);  // psubusw xmm0, xmm1
  exec4(0x660FD9CA);  // psubusw xmm1, xmm2
  exec4(0x660FEBC1);  // por xmm0, xmm1
  Final_result = read_xmm(0)
}

// =========================================================================
// NEGATION 16-bit: 65535 - |65535 - a - b| = ~|~a - b|
// Original: same as extremity + subtract from 65535
// Optimized: pxor/psubusw/psubusw/por/pxor (6 instrs)
// =========================================================================

val test_negation16_orig : unit -> unit
function test_negation16_orig() = {
  write_xmm(2, replicate_bits(0x0000 : bits(16), 8));
  write_xmm(4, replicate_bits(0x0000FFFF : bits(32), 4));
  // Widen a
  exec4(0x660F6FE8);  // movdqa xmm5, xmm0
  exec4(0x660F69EA);  // punpckhwd xmm5, xmm2
  exec4(0x660F61C2);  // punpcklwd xmm0, xmm2
  // Widen b
  exec4(0x660F6FF1);  // movdqa xmm6, xmm1
  exec4(0x660F69F2);  // punpckhwd xmm6, xmm2
  exec4(0x660F61CA);  // punpcklwd xmm1, xmm2
  // 65535 - a - b
  exec4(0x660F6FDC);  // movdqa xmm3, xmm4
  exec4(0x660FFAD8);  // psubd xmm3, xmm0
  exec4(0x660F6FFC);  // movdqa xmm7, xmm4
  exec4(0x660FFAFD);  // psubd xmm7, xmm5
  exec4(0x660FFAD9);  // psubd xmm3, xmm1
  exec4(0x660FFAFE);  // psubd xmm7, xmm6
  // |65535 - a - b|
  exec5(0x660F381EDB);  // pabsd xmm3, xmm3
  exec5(0x660F381EFF);  // pabsd xmm7, xmm7
  // 65535 - |65535-a-b|: movdqa xmm0, xmm4; psubd xmm0, xmm3; etc.
  exec4(0x660F6FC4);  // movdqa xmm0, xmm4
  exec4(0x660FFAC3);  // psubd xmm0, xmm3
  exec4(0x660F6FCC);  // movdqa xmm1, xmm4
  exec4(0x660FFACF);  // psubd xmm1, xmm7
  // Pack
  exec5(0x660F382BC1);  // packusdw xmm0, xmm1  (SSE4.1)
  Final_result = read_xmm(0)
}

val test_negation16_opt : unit -> unit
function test_negation16_opt() = {
  write_xmm(3, replicate_bits(0xFFFF : bits(16), 8));
  exec4(0x660FEFC3);  // pxor xmm0, xmm3  (~a)
  exec4(0x660F6FD0);  // movdqa xmm2, xmm0
  exec4(0x660FD9C1);  // psubusw xmm0, xmm1
  exec4(0x660FD9CA);  // psubusw xmm1, xmm2
  exec4(0x660FEBC1);  // por xmm0, xmm1
  exec4(0x660FEFC3);  // pxor xmm0, xmm3  (invert)
  Final_result = read_xmm(0)
}

// =========================================================================
// PHOENIX 16-bit: 65535 - |a - b|
// Original: pminuw/pmaxuw/psubusw/paddusw (6 instrs, SSE4)
// Optimized: psubusw/psubusw/por/pxor (5 instrs, SSE2)
// =========================================================================

val test_phoenix16_orig : unit -> unit
function test_phoenix16_orig() = {
  // xmm0 = a, xmm1 = b, xmm3 = 0xFFFF
  write_xmm(3, replicate_bits(0xFFFF : bits(16), 8));
  exec4(0x660F6FD0);     // movdqa xmm2, xmm0
  exec5(0x660F383AC1);   // pminuw xmm0, xmm1  (SSE4.1)
  exec5(0x660F383ECA);   // pmaxuw xmm1, xmm2  (SSE4.1)
  exec4(0x660F6FD3);     // movdqa xmm2, xmm3
  exec4(0x660FD9D1);     // psubusw xmm2, xmm1
  exec4(0x660FDDD0);     // paddusw xmm2, xmm0
  Final_result = read_xmm(2)
}

val test_phoenix16_opt : unit -> unit
function test_phoenix16_opt() = {
  write_xmm(3, replicate_bits(0xFFFF : bits(16), 8));
  exec4(0x660F6FD0);  // movdqa xmm2, xmm0
  exec4(0x660FD9C1);  // psubusw xmm0, xmm1
  exec4(0x660FD9CA);  // psubusw xmm1, xmm2
  exec4(0x660FEBC1);  // por xmm0, xmm1
  exec4(0x660FEFC3);  // pxor xmm0, xmm3
  Final_result = read_xmm(0)
}

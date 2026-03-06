// AVX-512 FP16 Arithmetic Instructions
//
// EVEX-encoded half-precision floating-point arithmetic.
// These require YMM/ZMM infrastructure we do not model,
// so they are declared as external functions.
// No flags are affected.

// VDIVPH — Divide Packed FP16 Values
// EVEX.128/256/512, AVX512-FP16
// Divides packed FP16 values in src1 by packed FP16 values in src2.
val __vdivph : unit -> unit

val exec_vdivph : unit -> ExecutionResult
function exec_vdivph() = {
  __vdivph();
  Ok(())
}

// VDIVSH — Divide Scalar FP16 Values
// EVEX.LLIG, AVX512-FP16
// Divides the low FP16 value in xmm2 by the low FP16 value in xmm3/m16.
// Bits 127:16 of xmm2 are copied to the destination.
val __vdivsh : unit -> unit

val exec_vdivsh : unit -> ExecutionResult
function exec_vdivsh() = {
  __vdivsh();
  Ok(())
}

// VGETMANTSD, VGETMANTSH, VGETMANTSS — Get Normalized Mantissa from Scalar FP Values
//
// Extract the normalized mantissa from a scalar float64, float16, or float32
// value in the source operand, using the sign/interval control from imm8.
// These are AVX-512 instructions with no YMM/ZMM infrastructure modeled here.
// No flags affected.

// External mantissa extraction primitives
val __vgetmantsd : (xmmword, xmmword, byte) -> xmmword
val __vgetmantsh : (xmmword, xmmword, byte) -> xmmword
val __vgetmantss : (xmmword, xmmword, byte) -> xmmword

// VGETMANTSD — Get Normalized Mantissa from Scalar Float64
// EVEX.128: xmm1 {k1}{z} := VGETMANTSD(xmm2, xmm3/m64, imm8)
val exec_vgetmantsd : (simd_idx, xmmword, xmmword, byte) -> ExecutionResult
function exec_vgetmantsd(dst, src1, src2, imm8) = {
  let a : xmmword = src1;
  let b : xmmword = src2;
  let result : xmmword = __vgetmantsd(a, b, imm8);
  write_xmm(dst, result);
  Ok(())
}

// VGETMANTSH — Get Normalized Mantissa from Scalar Float16
// EVEX.128: xmm1 {k1}{z} := VGETMANTSH(xmm2, xmm3/m16, imm8)
val exec_vgetmantsh : (simd_idx, xmmword, xmmword, byte) -> ExecutionResult
function exec_vgetmantsh(dst, src1, src2, imm8) = {
  let a : xmmword = src1;
  let b : xmmword = src2;
  let result : xmmword = __vgetmantsh(a, b, imm8);
  write_xmm(dst, result);
  Ok(())
}

// VGETMANTSS — Get Normalized Mantissa from Scalar Float32
// EVEX.128: xmm1 {k1}{z} := VGETMANTSS(xmm2, xmm3/m32, imm8)
val exec_vgetmantss : (simd_idx, xmmword, xmmword, byte) -> ExecutionResult
function exec_vgetmantss(dst, src1, src2, imm8) = {
  let a : xmmword = src1;
  let b : xmmword = src2;
  let result : xmmword = __vgetmantss(a, b, imm8);
  write_xmm(dst, result);
  Ok(())
}

// ROUNDPD — Round Packed Double-FP (SSE4.1)
// ROUNDPS — Round Packed Single-FP (SSE4.1)
// ROUNDSD — Round Scalar Double-FP (SSE4.1)
// ROUNDSS — Round Scalar Single-FP (SSE4.1)
// imm8 controls rounding mode. No flags affected.

val __f64_round : (qword, byte) -> qword
val __f32_round : (dword, byte) -> dword

val exec_roundpd : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_roundpd(dst, src, imm8) = {
  let s : xmmword = src;
  let lo : qword = __f64_round(s[63..0], imm8);
  let hi : qword = __f64_round(s[127..64], imm8);
  write_xmm_legacy(dst, hi @ lo);
  Ok(())
}

val exec_roundps : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_roundps(dst, src, imm8) = {
  let s : xmmword = src;
  let d0 : dword = __f32_round(s[31..0], imm8);
  let d1 : dword = __f32_round(s[63..32], imm8);
  let d2 : dword = __f32_round(s[95..64], imm8);
  let d3 : dword = __f32_round(s[127..96], imm8);
  write_xmm_legacy(dst, d3 @ d2 @ d1 @ d0);
  Ok(())
}

val exec_roundsd : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_roundsd(dst, src, imm8) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let lo : qword = __f64_round(b[63..0], imm8);
  write_xmm_legacy(dst, a[127..64] @ lo);
  Ok(())
}

val exec_roundss : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_roundss(dst, src, imm8) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let lo : dword = __f32_round(b[31..0], imm8);
  write_xmm_legacy(dst, a[127..32] @ lo);
  Ok(())
}

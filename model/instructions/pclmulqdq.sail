// PCLMULQDQ — Carry-Less Multiplication Quadword
//
// Performs carry-less (polynomial) multiplication of two 64-bit values
// selected from src and dst by imm8. The 128-bit result is stored in dst.
// imm8[0] selects which qword of dst, imm8[4] selects which qword of src.
// No flags affected.
//
// The carry-less multiply operation is complex; modeled as external.

val __pclmulqdq : (qword, qword) -> xmmword

val exec_pclmulqdq : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_pclmulqdq(dst, src, imm8) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let sel_a : qword = if imm8[0] == bitone then a[127..64] else a[63..0];
  let sel_b : qword = if imm8[4] == bitone then b[127..64] else b[63..0];
  let result : xmmword = __pclmulqdq(sel_a, sel_b);
  write_xmm_legacy(dst, result);
  Ok(())
}

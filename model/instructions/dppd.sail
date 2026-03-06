// DPPD — Dot Product of Packed Double-FP (SSE4.1)
// imm8[5:4] selects which products to include, imm8[1:0] selects output lanes.
// No flags affected.

val exec_dppd : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_dppd(dst, src, imm8) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let zero : qword = 0x0000000000000000;
  let temp0 : qword = if imm8[4] == bitone then __f64_mul(a[63..0], b[63..0]) else zero;
  let temp1 : qword = if imm8[5] == bitone then __f64_mul(a[127..64], b[127..64]) else zero;
  let sum : qword = __f64_add(temp0, temp1);
  let lo : qword = if imm8[0] == bitone then sum else zero;
  let hi : qword = if imm8[1] == bitone then sum else zero;
  write_xmm_legacy(dst, hi @ lo);
  Ok(())
}

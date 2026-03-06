// BLENDPD — Blend Packed Double-FP (SSE4.1)
// imm8[0] selects lane 0: 0=dst, 1=src. imm8[1] selects lane 1.
// No flags affected.

val exec_blendpd : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_blendpd(dst, src, imm8) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let lo : qword = if imm8[0] == bitone then b[63..0] else a[63..0];
  let hi : qword = if imm8[1] == bitone then b[127..64] else a[127..64];
  write_xmm_legacy(dst, hi @ lo);
  Ok(())
}

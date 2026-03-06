// SHUFPD — Shuffle Packed Double-Precision FP Values
// Bit 0 of imm8 selects result[63:0] from dst's low or high qword.
// Bit 1 of imm8 selects result[127:64] from src's low or high qword.
// No flags affected.

val exec_shufpd : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_shufpd(dst, src, imm8) = {
  let d : xmmword = read_xmm(dst);
  let s : xmmword = src;
  let low : qword = if imm8[0] == bitone then d[127..64] else d[63..0];
  let high : qword = if imm8[1] == bitone then s[127..64] else s[63..0];
  write_xmm_legacy(dst, high @ low);
  Ok(())
}

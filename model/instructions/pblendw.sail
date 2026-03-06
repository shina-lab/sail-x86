// PBLENDW — Blend Packed Words (SSE4.1)
// imm8[0..7] each select the corresponding word lane: 0=dst, 1=src.
// No flags affected.

val exec_pblendw : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_pblendw(dst, src, imm8) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let w0 : word = if imm8[0] == bitone then b[15..0]    else a[15..0];
  let w1 : word = if imm8[1] == bitone then b[31..16]   else a[31..16];
  let w2 : word = if imm8[2] == bitone then b[47..32]   else a[47..32];
  let w3 : word = if imm8[3] == bitone then b[63..48]   else a[63..48];
  let w4 : word = if imm8[4] == bitone then b[79..64]   else a[79..64];
  let w5 : word = if imm8[5] == bitone then b[95..80]   else a[95..80];
  let w6 : word = if imm8[6] == bitone then b[111..96]  else a[111..96];
  let w7 : word = if imm8[7] == bitone then b[127..112] else a[127..112];
  write_xmm_legacy(dst, w7 @ w6 @ w5 @ w4 @ w3 @ w2 @ w1 @ w0);
  Ok(())
}

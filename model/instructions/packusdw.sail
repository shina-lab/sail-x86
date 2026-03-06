// PACKUSDW — Pack Dwords to Words with Unsigned Saturation (SSE4.1)
// Packs 4 signed dwords from dst and 4 from src into 8 unsigned words.
// No flags affected.

val sat_s32_to_u16 : dword -> word
function sat_s32_to_u16(v) = {
  let sv : int = signed(v);
  if sv < 0 then 0x0000
  else if sv > 65535 then 0xFFFF
  else v[15..0]
}

val exec_packusdw : (simd_idx, xmmword) -> ExecutionResult
function exec_packusdw(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let w0 : word = sat_s32_to_u16(a[31..0]);
  let w1 : word = sat_s32_to_u16(a[63..32]);
  let w2 : word = sat_s32_to_u16(a[95..64]);
  let w3 : word = sat_s32_to_u16(a[127..96]);
  let w4 : word = sat_s32_to_u16(b[31..0]);
  let w5 : word = sat_s32_to_u16(b[63..32]);
  let w6 : word = sat_s32_to_u16(b[95..64]);
  let w7 : word = sat_s32_to_u16(b[127..96]);
  write_xmm_legacy(dst, w7 @ w6 @ w5 @ w4 @ w3 @ w2 @ w1 @ w0);
  Ok(())
}

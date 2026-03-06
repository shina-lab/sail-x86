// PACKSSWB — Pack with Signed Saturation (words to bytes)
// PACKSSDW — Pack with Signed Saturation (dwords to words)
// No flags affected.

val sat_s16_to_s8 : word -> byte
function sat_s16_to_s8(x) = {
  let v = signed(x);
  if v > 127 then 0x7F
  else if v < -128 then 0x80
  else x[7..0]
}

val sat_s32_to_s16 : dword -> word
function sat_s32_to_s16(x) = {
  let v = signed(x);
  if v > 32767 then 0x7FFF
  else if v < -32768 then 0x8000
  else x[15..0]
}

val exec_packsswb : (simd_idx, xmmword) -> ExecutionResult
function exec_packsswb(dst, src) = {
  let d : xmmword = read_xmm(dst);
  let s : xmmword = src;
  let r : xmmword =
    sat_s16_to_s8(s[127..112]) @ sat_s16_to_s8(s[111..96]) @
    sat_s16_to_s8(s[95..80])   @ sat_s16_to_s8(s[79..64]) @
    sat_s16_to_s8(s[63..48])   @ sat_s16_to_s8(s[47..32]) @
    sat_s16_to_s8(s[31..16])   @ sat_s16_to_s8(s[15..0]) @
    sat_s16_to_s8(d[127..112]) @ sat_s16_to_s8(d[111..96]) @
    sat_s16_to_s8(d[95..80])   @ sat_s16_to_s8(d[79..64]) @
    sat_s16_to_s8(d[63..48])   @ sat_s16_to_s8(d[47..32]) @
    sat_s16_to_s8(d[31..16])   @ sat_s16_to_s8(d[15..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

val exec_packssdw : (simd_idx, xmmword) -> ExecutionResult
function exec_packssdw(dst, src) = {
  let d : xmmword = read_xmm(dst);
  let s : xmmword = src;
  let r : xmmword =
    sat_s32_to_s16(s[127..96]) @ sat_s32_to_s16(s[95..64]) @
    sat_s32_to_s16(s[63..32])  @ sat_s32_to_s16(s[31..0]) @
    sat_s32_to_s16(d[127..96]) @ sat_s32_to_s16(d[95..64]) @
    sat_s32_to_s16(d[63..32])  @ sat_s32_to_s16(d[31..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

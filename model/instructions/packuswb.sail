// PACKUSWB — Pack with Unsigned Saturation (words to bytes)
// No flags affected.

val sat_s16_to_u8 : word -> byte
function sat_s16_to_u8(x) = {
  let v = signed(x);
  if v > 255 then 0xFF
  else if v < 0 then 0x00
  else x[7..0]
}

val exec_packuswb : (simd_idx, xmmword) -> ExecutionResult
function exec_packuswb(dst, src) = {
  let d : xmmword = read_xmm(dst);
  let s : xmmword = src;
  let r : xmmword =
    sat_s16_to_u8(s[127..112]) @ sat_s16_to_u8(s[111..96]) @
    sat_s16_to_u8(s[95..80])   @ sat_s16_to_u8(s[79..64]) @
    sat_s16_to_u8(s[63..48])   @ sat_s16_to_u8(s[47..32]) @
    sat_s16_to_u8(s[31..16])   @ sat_s16_to_u8(s[15..0]) @
    sat_s16_to_u8(d[127..112]) @ sat_s16_to_u8(d[111..96]) @
    sat_s16_to_u8(d[95..80])   @ sat_s16_to_u8(d[79..64]) @
    sat_s16_to_u8(d[63..48])   @ sat_s16_to_u8(d[47..32]) @
    sat_s16_to_u8(d[31..16])   @ sat_s16_to_u8(d[15..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

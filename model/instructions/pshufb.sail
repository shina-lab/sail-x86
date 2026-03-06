// PSHUFB — Packed Shuffle Bytes (SSSE3)
// Each byte in result is selected from dst by the low 4 bits of the corresponding
// byte in src. If the high bit of the selector byte is set, the result byte is zero.
// No flags affected.

val pshufb_byte : (xmmword, byte) -> byte
function pshufb_byte(data, mask) = {
  if mask[7] == bitone then 0x00
  else {
    let idx : range(0, 15) = unsigned(mask[3..0]);
    match idx {
      0  => data[7..0],
      1  => data[15..8],
      2  => data[23..16],
      3  => data[31..24],
      4  => data[39..32],
      5  => data[47..40],
      6  => data[55..48],
      7  => data[63..56],
      8  => data[71..64],
      9  => data[79..72],
      10 => data[87..80],
      11 => data[95..88],
      12 => data[103..96],
      13 => data[111..104],
      14 => data[119..112],
      15 => data[127..120]
    }
  }
}

val exec_pshufb : (simd_idx, xmmword) -> ExecutionResult
function exec_pshufb(dst, src) = {
  let d : xmmword = read_xmm(dst);
  let s : xmmword = src;
  let r : xmmword =
    pshufb_byte(d, s[127..120]) @ pshufb_byte(d, s[119..112]) @
    pshufb_byte(d, s[111..104]) @ pshufb_byte(d, s[103..96]) @
    pshufb_byte(d, s[95..88])   @ pshufb_byte(d, s[87..80]) @
    pshufb_byte(d, s[79..72])   @ pshufb_byte(d, s[71..64]) @
    pshufb_byte(d, s[63..56])   @ pshufb_byte(d, s[55..48]) @
    pshufb_byte(d, s[47..40])   @ pshufb_byte(d, s[39..32]) @
    pshufb_byte(d, s[31..24])   @ pshufb_byte(d, s[23..16]) @
    pshufb_byte(d, s[15..8])    @ pshufb_byte(d, s[7..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

// PADDSB/PADDSW — Add Packed Signed Integers with Signed Saturation
// PADDUSB/PADDUSW — Add Packed Unsigned Integers with Unsigned Saturation
// No flags affected.

val sat_add_s8 : (byte, byte) -> byte
function sat_add_s8(a, b) = {
  let sum : int = signed(a) + signed(b);
  let clamped : int = if sum < -128 then -128
                      else if sum > 127 then 127
                      else sum;
  to_bits_truncate(clamped)
}

val sat_add_s16 : (word, word) -> word
function sat_add_s16(a, b) = {
  let sum : int = signed(a) + signed(b);
  let clamped : int = if sum < -32768 then -32768
                      else if sum > 32767 then 32767
                      else sum;
  to_bits_truncate(clamped)
}

val sat_add_u8 : (byte, byte) -> byte
function sat_add_u8(a, b) = {
  let sum : int = unsigned(a) + unsigned(b);
  let clamped : int = if sum > 255 then 255 else sum;
  to_bits_truncate(clamped)
}

val sat_add_u16 : (word, word) -> word
function sat_add_u16(a, b) = {
  let sum : int = unsigned(a) + unsigned(b);
  let clamped : int = if sum > 65535 then 65535 else sum;
  to_bits_truncate(clamped)
}

val exec_paddsb : (simd_idx, xmmword) -> ExecutionResult
function exec_paddsb(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    sat_add_s8(a[127..120], b[127..120]) @ sat_add_s8(a[119..112], b[119..112]) @
    sat_add_s8(a[111..104], b[111..104]) @ sat_add_s8(a[103..96], b[103..96]) @
    sat_add_s8(a[95..88], b[95..88]) @ sat_add_s8(a[87..80], b[87..80]) @
    sat_add_s8(a[79..72], b[79..72]) @ sat_add_s8(a[71..64], b[71..64]) @
    sat_add_s8(a[63..56], b[63..56]) @ sat_add_s8(a[55..48], b[55..48]) @
    sat_add_s8(a[47..40], b[47..40]) @ sat_add_s8(a[39..32], b[39..32]) @
    sat_add_s8(a[31..24], b[31..24]) @ sat_add_s8(a[23..16], b[23..16]) @
    sat_add_s8(a[15..8], b[15..8]) @ sat_add_s8(a[7..0], b[7..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

val exec_paddsw : (simd_idx, xmmword) -> ExecutionResult
function exec_paddsw(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    sat_add_s16(a[127..112], b[127..112]) @ sat_add_s16(a[111..96], b[111..96]) @
    sat_add_s16(a[95..80], b[95..80]) @ sat_add_s16(a[79..64], b[79..64]) @
    sat_add_s16(a[63..48], b[63..48]) @ sat_add_s16(a[47..32], b[47..32]) @
    sat_add_s16(a[31..16], b[31..16]) @ sat_add_s16(a[15..0], b[15..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

val exec_paddusb : (simd_idx, xmmword) -> ExecutionResult
function exec_paddusb(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    sat_add_u8(a[127..120], b[127..120]) @ sat_add_u8(a[119..112], b[119..112]) @
    sat_add_u8(a[111..104], b[111..104]) @ sat_add_u8(a[103..96], b[103..96]) @
    sat_add_u8(a[95..88], b[95..88]) @ sat_add_u8(a[87..80], b[87..80]) @
    sat_add_u8(a[79..72], b[79..72]) @ sat_add_u8(a[71..64], b[71..64]) @
    sat_add_u8(a[63..56], b[63..56]) @ sat_add_u8(a[55..48], b[55..48]) @
    sat_add_u8(a[47..40], b[47..40]) @ sat_add_u8(a[39..32], b[39..32]) @
    sat_add_u8(a[31..24], b[31..24]) @ sat_add_u8(a[23..16], b[23..16]) @
    sat_add_u8(a[15..8], b[15..8]) @ sat_add_u8(a[7..0], b[7..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

val exec_paddusw : (simd_idx, xmmword) -> ExecutionResult
function exec_paddusw(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    sat_add_u16(a[127..112], b[127..112]) @ sat_add_u16(a[111..96], b[111..96]) @
    sat_add_u16(a[95..80], b[95..80]) @ sat_add_u16(a[79..64], b[79..64]) @
    sat_add_u16(a[63..48], b[63..48]) @ sat_add_u16(a[47..32], b[47..32]) @
    sat_add_u16(a[31..16], b[31..16]) @ sat_add_u16(a[15..0], b[15..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

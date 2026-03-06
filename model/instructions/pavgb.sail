// PAVGB/PAVGW — Average Packed Integers with Rounding
// No flags affected.

val avg8 : (byte, byte) -> byte
function avg8(a, b) = {
  let sum : bits(9) = (0b0 @ a) + (0b0 @ b) + 0b000000001;
  sum[8..1]
}

val avg16 : (word, word) -> word
function avg16(a, b) = {
  let sum : bits(17) = (0b0 @ a) + (0b0 @ b) + 0b00000000000000001;
  sum[16..1]
}

val exec_pavgb : (simd_idx, xmmword) -> ExecutionResult
function exec_pavgb(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    avg8(a[127..120], b[127..120]) @ avg8(a[119..112], b[119..112]) @
    avg8(a[111..104], b[111..104]) @ avg8(a[103..96], b[103..96]) @
    avg8(a[95..88], b[95..88]) @ avg8(a[87..80], b[87..80]) @
    avg8(a[79..72], b[79..72]) @ avg8(a[71..64], b[71..64]) @
    avg8(a[63..56], b[63..56]) @ avg8(a[55..48], b[55..48]) @
    avg8(a[47..40], b[47..40]) @ avg8(a[39..32], b[39..32]) @
    avg8(a[31..24], b[31..24]) @ avg8(a[23..16], b[23..16]) @
    avg8(a[15..8], b[15..8]) @ avg8(a[7..0], b[7..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

val exec_pavgw : (simd_idx, xmmword) -> ExecutionResult
function exec_pavgw(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    avg16(a[127..112], b[127..112]) @ avg16(a[111..96], b[111..96]) @
    avg16(a[95..80], b[95..80]) @ avg16(a[79..64], b[79..64]) @
    avg16(a[63..48], b[63..48]) @ avg16(a[47..32], b[47..32]) @
    avg16(a[31..16], b[31..16]) @ avg16(a[15..0], b[15..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

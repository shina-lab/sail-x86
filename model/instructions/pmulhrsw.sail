// PMULHRSW — Packed Multiply High with Round and Scale (SSSE3)
// No flags affected.

val mulhrsw : (word, word) -> word
function mulhrsw(a, b) = {
  let product : dword = to_bits_truncate(signed(a) * signed(b));
  let rounded : dword = product + 0x00004000;
  // Take bits [30..15] which is equivalent to arithmetic right shift by 15
  rounded[30..15]
}

val exec_pmulhrsw : (simd_idx, xmmword) -> ExecutionResult
function exec_pmulhrsw(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    mulhrsw(a[127..112], b[127..112]) @ mulhrsw(a[111..96], b[111..96]) @
    mulhrsw(a[95..80], b[95..80]) @ mulhrsw(a[79..64], b[79..64]) @
    mulhrsw(a[63..48], b[63..48]) @ mulhrsw(a[47..32], b[47..32]) @
    mulhrsw(a[31..16], b[31..16]) @ mulhrsw(a[15..0], b[15..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

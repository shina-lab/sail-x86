// PMADDUBSW — Multiply and Add Packed Signed and Unsigned Bytes (SSSE3)
// Multiplies unsigned bytes from src1 with signed bytes from src2,
// then adds adjacent pairs with signed saturation to produce 16-bit results.
// No flags affected.

val pmaddubsw_pair : (byte, byte, byte, byte) -> word
function pmaddubsw_pair(a_even, b_even, a_odd, b_odd) = {
  let p1 : int = unsigned(a_even) * signed(b_even);
  let p2 : int = unsigned(a_odd) * signed(b_odd);
  let sum : int = p1 + p2;
  if sum > 32767 then 0x7FFF
  else if sum < -32768 then 0x8000
  else to_bits_truncate(sum) : word
}

val exec_pmaddubsw : (simd_idx, xmmword) -> ExecutionResult
function exec_pmaddubsw(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    pmaddubsw_pair(a[127..120], b[127..120], a[119..112], b[119..112]) @
    pmaddubsw_pair(a[111..104], b[111..104], a[103..96], b[103..96]) @
    pmaddubsw_pair(a[95..88], b[95..88], a[87..80], b[87..80]) @
    pmaddubsw_pair(a[79..72], b[79..72], a[71..64], b[71..64]) @
    pmaddubsw_pair(a[63..56], b[63..56], a[55..48], b[55..48]) @
    pmaddubsw_pair(a[47..40], b[47..40], a[39..32], b[39..32]) @
    pmaddubsw_pair(a[31..24], b[31..24], a[23..16], b[23..16]) @
    pmaddubsw_pair(a[15..8], b[15..8], a[7..0], b[7..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

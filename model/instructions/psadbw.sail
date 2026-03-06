// PSADBW — Compute Sum of Absolute Differences
// Computes absolute differences of unsigned byte pairs, then sums each 8-byte group.
// Result is zero-extended to 64 bits per qword lane. No flags affected.

val abs_diff8 : (byte, byte) -> int
function abs_diff8(a, b) = {
  let diff : int = unsigned(a) - unsigned(b);
  if diff < 0 then negate(diff) else diff
}

val exec_psadbw : (simd_idx, xmmword) -> ExecutionResult
function exec_psadbw(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let sum_hi : int = abs_diff8(a[127..120], b[127..120]) +
                     abs_diff8(a[119..112], b[119..112]) +
                     abs_diff8(a[111..104], b[111..104]) +
                     abs_diff8(a[103..96], b[103..96]) +
                     abs_diff8(a[95..88], b[95..88]) +
                     abs_diff8(a[87..80], b[87..80]) +
                     abs_diff8(a[79..72], b[79..72]) +
                     abs_diff8(a[71..64], b[71..64]);
  let sum_lo : int = abs_diff8(a[63..56], b[63..56]) +
                     abs_diff8(a[55..48], b[55..48]) +
                     abs_diff8(a[47..40], b[47..40]) +
                     abs_diff8(a[39..32], b[39..32]) +
                     abs_diff8(a[31..24], b[31..24]) +
                     abs_diff8(a[23..16], b[23..16]) +
                     abs_diff8(a[15..8], b[15..8]) +
                     abs_diff8(a[7..0], b[7..0]);
  let hi : qword = to_bits_truncate(sum_hi);
  let lo : qword = to_bits_truncate(sum_lo);
  let r : xmmword = hi @ lo;
  write_xmm_legacy(dst, r);
  Ok(())
}

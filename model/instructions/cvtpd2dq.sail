// CVTPD2DQ — Convert Packed Double-Precision FP Values to Packed Doubleword Integers
// Converts two 64-bit doubles to two 32-bit signed integers in low quadword, upper zeroed.
// No flags affected.

val exec_cvtpd2dq : (simd_idx, xmmword) -> ExecutionResult
function exec_cvtpd2dq(dst, src) = {
  let s : xmmword = src;
  let r : xmmword = zeros(64) @ __f64_to_int32(s[127..64]) @ __f64_to_int32(s[63..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

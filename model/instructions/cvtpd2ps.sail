// CVTPD2PS — Convert Packed Double-Precision FP Values to Packed Single-Precision FP Values
// Converts two 64-bit doubles to two 32-bit singles in low quadword, upper zeroed.
// No flags affected.

val exec_cvtpd2ps : (simd_idx, xmmword) -> ExecutionResult
function exec_cvtpd2ps(dst, src) = {
  let s : xmmword = src;
  let r : xmmword = zeros(64) @ __f64_to_f32(s[127..64]) @ __f64_to_f32(s[63..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

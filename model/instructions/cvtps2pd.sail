// CVTPS2PD — Convert Packed Single-Precision FP Values to Packed Double-Precision FP Values
// Converts two 32-bit singles from low quadword of src to two 64-bit doubles.
// No flags affected.

val exec_cvtps2pd : (simd_idx, xmmword) -> ExecutionResult
function exec_cvtps2pd(dst, src) = {
  let s : xmmword = src;
  let r : xmmword = __f32_to_f64(s[63..32]) @ __f32_to_f64(s[31..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

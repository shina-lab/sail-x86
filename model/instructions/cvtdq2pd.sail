// CVTDQ2PD — Convert Packed Doubleword Integers to Packed Double-Precision FP Values
// Converts two 32-bit signed integers from low quadword of src to two 64-bit doubles.
// No flags affected.

val exec_cvtdq2pd : (simd_idx, xmmword) -> ExecutionResult
function exec_cvtdq2pd(dst, src) = {
  let s : xmmword = src;
  let r : xmmword = __int32_to_f64(s[63..32]) @ __int32_to_f64(s[31..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

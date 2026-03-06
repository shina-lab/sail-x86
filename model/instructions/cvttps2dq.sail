// CVTTPS2DQ — Convert with Truncation Packed Single-Precision FP Values to Packed Doubleword Integers
// Converts four 32-bit singles to four 32-bit signed integers using truncation.
// No flags affected.

val exec_cvttps2dq : (simd_idx, xmmword) -> ExecutionResult
function exec_cvttps2dq(dst, src) = {
  let s : xmmword = src;
  let r : xmmword =
    __f32_to_int32_trunc(s[127..96]) @ __f32_to_int32_trunc(s[95..64]) @
    __f32_to_int32_trunc(s[63..32]) @ __f32_to_int32_trunc(s[31..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

// CVTDQ2PS — Convert Packed Doubleword Integers to Packed Single-Precision FP Values
// Converts four 32-bit signed integers to four 32-bit singles. No flags affected.

val exec_cvtdq2ps : (simd_idx, xmmword) -> ExecutionResult
function exec_cvtdq2ps(dst, src) = {
  let s : xmmword = src;
  let r : xmmword =
    __int32_to_f32(s[127..96]) @ __int32_to_f32(s[95..64]) @
    __int32_to_f32(s[63..32]) @ __int32_to_f32(s[31..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

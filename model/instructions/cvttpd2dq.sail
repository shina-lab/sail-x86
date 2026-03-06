// CVTTPD2DQ — Convert with Truncation Packed Double-FP to Packed Dword Integers
// Converts two 64-bit doubles to two 32-bit signed integers using truncation.
// Result is stored in low 64 bits of XMM; upper 64 bits are zeroed.
// No flags affected.

val exec_cvttpd2dq : (simd_idx, xmmword) -> ExecutionResult
function exec_cvttpd2dq(dst, src) = {
  let s : xmmword = src;
  let lo : dword = __f64_to_int32_trunc(s[63..0]);
  let hi : dword = __f64_to_int32_trunc(s[127..64]);
  let r : xmmword = zeros(64) @ hi @ lo;
  write_xmm_legacy(dst, r);
  Ok(())
}

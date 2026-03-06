// UNPCKHPS — Unpack and Interleave High Packed Single-Precision FP
// UNPCKLPS — Unpack and Interleave Low Packed Single-Precision FP
// No flags affected.

val exec_unpckhps : (simd_idx, xmmword) -> ExecutionResult
function exec_unpckhps(dst, src) = {
  let d : xmmword = read_xmm(dst);
  let s : xmmword = src;
  write_xmm_legacy(dst, s[127..96] @ d[127..96] @ s[95..64] @ d[95..64]);
  Ok(())
}

val exec_unpcklps : (simd_idx, xmmword) -> ExecutionResult
function exec_unpcklps(dst, src) = {
  let d : xmmword = read_xmm(dst);
  let s : xmmword = src;
  write_xmm_legacy(dst, s[63..32] @ d[63..32] @ s[31..0] @ d[31..0]);
  Ok(())
}

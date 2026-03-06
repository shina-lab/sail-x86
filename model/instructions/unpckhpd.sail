// UNPCKHPD — Unpack and Interleave High Packed Double-Precision FP
// UNPCKLPD — Unpack and Interleave Low Packed Double-Precision FP
// No flags affected.

val exec_unpckhpd : (simd_idx, xmmword) -> ExecutionResult
function exec_unpckhpd(dst, src) = {
  let d : xmmword = read_xmm(dst);
  let s : xmmword = src;
  write_xmm_legacy(dst, s[127..64] @ d[127..64]);
  Ok(())
}

val exec_unpcklpd : (simd_idx, xmmword) -> ExecutionResult
function exec_unpcklpd(dst, src) = {
  let d : xmmword = read_xmm(dst);
  let s : xmmword = src;
  write_xmm_legacy(dst, s[63..0] @ d[63..0]);
  Ok(())
}

// MOVSHDUP — Move and Duplicate Odd Single-FP (SSE3)
// MOVSLDUP — Move and Duplicate Even Single-FP (SSE3)
// No flags affected.

val exec_movshdup : (simd_idx, xmmword) -> ExecutionResult
function exec_movshdup(dst, src) = {
  let s : xmmword = src;
  write_xmm_legacy(dst, s[127..96] @ s[127..96] @ s[63..32] @ s[63..32]);
  Ok(())
}

val exec_movsldup : (simd_idx, xmmword) -> ExecutionResult
function exec_movsldup(dst, src) = {
  let s : xmmword = src;
  write_xmm_legacy(dst, s[95..64] @ s[95..64] @ s[31..0] @ s[31..0]);
  Ok(())
}

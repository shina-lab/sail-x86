// MOVDDUP — Move and Duplicate Double-FP (SSE3)
// Duplicates the low qword of src into both lanes. No flags affected.

val exec_movddup : (simd_idx, xmmword) -> ExecutionResult
function exec_movddup(dst, src) = {
  let s : xmmword = src;
  write_xmm_legacy(dst, s[63..0] @ s[63..0]);
  Ok(())
}

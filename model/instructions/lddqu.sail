// LDDQU — Load Unaligned Integer 128 Bits (SSE3)
// Functionally equivalent to MOVDQU for specification purposes.
// No flags affected.

val exec_lddqu : (simd_idx, xmmword) -> ExecutionResult
function exec_lddqu(dst, src) = {
  write_xmm_legacy(dst, src);
  Ok(())
}

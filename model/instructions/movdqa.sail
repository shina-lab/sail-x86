// MOVDQA/MOVDQU — Move Aligned/Unaligned Double Quadword
// Moves 128-bit integer data between XMM registers or memory.
// No flags affected.

val exec_movdqa : (simd_idx, xmmword) -> ExecutionResult
function exec_movdqa(dst, src) = {
  write_xmm_legacy(dst, src);
  Ok(())
}

val exec_movdqu : (simd_idx, xmmword) -> ExecutionResult
function exec_movdqu(dst, src) = {
  write_xmm_legacy(dst, src);
  Ok(())
}

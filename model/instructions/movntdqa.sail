// MOVNTDQA — Load Double Quadword Non-Temporal Aligned Hint
//
// Non-temporal load is semantically equivalent to a regular 128-bit
// aligned load for spec purposes. The hint tells the processor to
// minimize cache pollution but has no effect on program-visible state.

val exec_movntdqa : (simd_idx, xmmword) -> ExecutionResult
function exec_movntdqa(dst, src) = {
  write_xmm_legacy(dst, src);
  Ok(())
}

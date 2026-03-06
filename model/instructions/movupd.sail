// MOVUPD — Move Unaligned Packed Double-Precision FP
// MOVUPS — Move Unaligned Packed Single-Precision FP
// Moves 128-bit XMM values. Alignment checking is a runtime concern,
// not modeled in the spec. No flags affected.

val exec_movupd_load : (simd_idx, xmmword) -> ExecutionResult
function exec_movupd_load(dst, src) = {
  let v : xmmword = src;
  write_xmm_legacy(dst, v);
  Ok(())
}

val exec_movups_load : (simd_idx, xmmword) -> ExecutionResult
function exec_movups_load(dst, src) = {
  let v : xmmword = src;
  write_xmm_legacy(dst, v);
  Ok(())
}

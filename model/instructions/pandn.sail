// PANDN — Bitwise Logical AND NOT of Packed Integers
// POR — Bitwise Logical OR of Packed Integers
// No flags affected.

val exec_pandn : (simd_idx, xmmword) -> ExecutionResult
function exec_pandn(dst, src) = {
  write_xmm_legacy(dst, ~(read_xmm(dst)) & src);
  Ok(())
}

val exec_por : (simd_idx, xmmword) -> ExecutionResult
function exec_por(dst, src) = {
  write_xmm_legacy(dst, read_xmm(dst) | src);
  Ok(())
}

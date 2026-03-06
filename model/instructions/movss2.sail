// MOVSS — Move Scalar Single Precision FP
// Moves 32-bit float from src XMM[31:0] to dst XMM[31:0].
// When both operands are XMM, upper bits of dst preserved.
// No flags affected.

val exec_movss_xmm : (simd_idx, xmmword) -> ExecutionResult
function exec_movss_xmm(dst, src) = {
  var xmm : xmmword = read_xmm(dst);
  xmm[31..0] = src[31..0];
  write_xmm_legacy(dst, xmm);
  Ok(())
}

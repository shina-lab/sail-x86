// MOVSD — Move Scalar Double Precision FP
// Moves 64-bit double from src XMM[63:0] to dst XMM[63:0].
// When both operands are XMM, upper bits of dst preserved.
// No flags affected.

val exec_movsd_xmm : (simd_idx, xmmword) -> ExecutionResult
function exec_movsd_xmm(dst, src) = {
  var xmm : xmmword = read_xmm(dst);
  xmm[63..0] = src[63..0];
  write_xmm_legacy(dst, xmm);
  Ok(())
}

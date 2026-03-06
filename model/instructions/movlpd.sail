// MOVLPD/MOVLPS — Move Low Packed FP
// Moves 64 bits to/from XMM[63:0]. Upper 64 bits preserved.
// MOVHPD/MOVHPS — Move High Packed FP
// Moves 64 bits to/from XMM[127:64]. Lower 64 bits preserved.
// No flags affected.

val exec_movlpd : (simd_idx, qword) -> ExecutionResult
function exec_movlpd(dst, src) = {
  var xmm : xmmword = read_xmm(dst);
  xmm[63..0] = src;
  write_xmm_legacy(dst, xmm);
  Ok(())
}

val exec_movlps : (simd_idx, qword) -> ExecutionResult
function exec_movlps(dst, src) = {
  var xmm : xmmword = read_xmm(dst);
  xmm[63..0] = src;
  write_xmm_legacy(dst, xmm);
  Ok(())
}

val exec_movhpd : (simd_idx, qword) -> ExecutionResult
function exec_movhpd(dst, src) = {
  var xmm : xmmword = read_xmm(dst);
  xmm[127..64] = src;
  write_xmm_legacy(dst, xmm);
  Ok(())
}

val exec_movhps : (simd_idx, qword) -> ExecutionResult
function exec_movhps(dst, src) = {
  var xmm : xmmword = read_xmm(dst);
  xmm[127..64] = src;
  write_xmm_legacy(dst, xmm);
  Ok(())
}

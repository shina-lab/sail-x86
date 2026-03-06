// RCPSS/RCPPS: Reciprocal Approximation of Scalar/Packed Single-Precision FP
// No flags affected.

val __f32_rcp : dword -> dword

val exec_rcpss : (simd_idx, xmmword) -> ExecutionResult
function exec_rcpss(dst, src) = {
  var xmm : xmmword = read_xmm(dst);
  xmm[31..0] = __f32_rcp(src[31..0]);
  write_xmm_legacy(dst, xmm);
  Ok(())
}

val exec_rcpps : (simd_idx, xmmword) -> ExecutionResult
function exec_rcpps(dst, src) = {
  let src_xmm : xmmword = src;
  var xmm : xmmword = zeros();
  xmm[31..0]   = __f32_rcp(src_xmm[31..0]);
  xmm[63..32]  = __f32_rcp(src_xmm[63..32]);
  xmm[95..64]  = __f32_rcp(src_xmm[95..64]);
  xmm[127..96] = __f32_rcp(src_xmm[127..96]);
  write_xmm_legacy(dst, xmm);
  Ok(())
}

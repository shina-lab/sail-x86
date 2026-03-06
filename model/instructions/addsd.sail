// Scalar Double Precision FP Arithmetic: ADDSD, SUBSD, MULSD, DIVSD
// Each operates on XMM[63:0], preserving XMM[127:64]. No flags affected.

val exec_addsd : (simd_idx, xmmword) -> ExecutionResult
function exec_addsd(dst, src) = {
  var xmm : xmmword = read_xmm(dst);
  xmm[63..0] = __f64_add(xmm[63..0], src[63..0]);
  write_xmm_legacy(dst, xmm);
  Ok(())
}

val exec_subsd : (simd_idx, xmmword) -> ExecutionResult
function exec_subsd(dst, src) = {
  var xmm : xmmword = read_xmm(dst);
  xmm[63..0] = __f64_sub(xmm[63..0], src[63..0]);
  write_xmm_legacy(dst, xmm);
  Ok(())
}

val exec_mulsd : (simd_idx, xmmword) -> ExecutionResult
function exec_mulsd(dst, src) = {
  var xmm : xmmword = read_xmm(dst);
  xmm[63..0] = __f64_mul(xmm[63..0], src[63..0]);
  write_xmm_legacy(dst, xmm);
  Ok(())
}

val exec_divsd : (simd_idx, xmmword) -> ExecutionResult
function exec_divsd(dst, src) = {
  var xmm : xmmword = read_xmm(dst);
  xmm[63..0] = __f64_div(xmm[63..0], src[63..0]);
  write_xmm_legacy(dst, xmm);
  Ok(())
}

val exec_sqrtsd : (simd_idx, xmmword) -> ExecutionResult
function exec_sqrtsd(dst, src) = {
  var xmm : xmmword = read_xmm(dst);
  xmm[63..0] = __f64_sqrt(src[63..0]);
  write_xmm_legacy(dst, xmm);
  Ok(())
}

val exec_minsd : (simd_idx, xmmword) -> ExecutionResult
function exec_minsd(dst, src) = {
  var xmm : xmmword = read_xmm(dst);
  xmm[63..0] = __f64_min(xmm[63..0], src[63..0]);
  write_xmm_legacy(dst, xmm);
  Ok(())
}

val exec_maxsd : (simd_idx, xmmword) -> ExecutionResult
function exec_maxsd(dst, src) = {
  var xmm : xmmword = read_xmm(dst);
  xmm[63..0] = __f64_max(xmm[63..0], src[63..0]);
  write_xmm_legacy(dst, xmm);
  Ok(())
}

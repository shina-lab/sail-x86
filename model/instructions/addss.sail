// Scalar Single Precision FP Arithmetic: ADDSS, SUBSS, MULSS, DIVSS
// Each operates on XMM[31:0], preserving XMM[127:32]. No flags affected.

val exec_addss : (simd_idx, xmmword) -> ExecutionResult
function exec_addss(dst, src) = {
  var xmm : xmmword = read_xmm(dst);
  xmm[31..0] = __f32_add(xmm[31..0], src[31..0]);
  write_xmm_legacy(dst, xmm);
  Ok(())
}

val exec_subss : (simd_idx, xmmword) -> ExecutionResult
function exec_subss(dst, src) = {
  var xmm : xmmword = read_xmm(dst);
  xmm[31..0] = __f32_sub(xmm[31..0], src[31..0]);
  write_xmm_legacy(dst, xmm);
  Ok(())
}

val exec_mulss : (simd_idx, xmmword) -> ExecutionResult
function exec_mulss(dst, src) = {
  var xmm : xmmword = read_xmm(dst);
  xmm[31..0] = __f32_mul(xmm[31..0], src[31..0]);
  write_xmm_legacy(dst, xmm);
  Ok(())
}

val exec_divss : (simd_idx, xmmword) -> ExecutionResult
function exec_divss(dst, src) = {
  var xmm : xmmword = read_xmm(dst);
  xmm[31..0] = __f32_div(xmm[31..0], src[31..0]);
  write_xmm_legacy(dst, xmm);
  Ok(())
}

val exec_sqrtss : (simd_idx, xmmword) -> ExecutionResult
function exec_sqrtss(dst, src) = {
  var xmm : xmmword = read_xmm(dst);
  xmm[31..0] = __f32_sqrt(src[31..0]);
  write_xmm_legacy(dst, xmm);
  Ok(())
}

val exec_minss : (simd_idx, xmmword) -> ExecutionResult
function exec_minss(dst, src) = {
  var xmm : xmmword = read_xmm(dst);
  xmm[31..0] = __f32_min(xmm[31..0], src[31..0]);
  write_xmm_legacy(dst, xmm);
  Ok(())
}

val exec_maxss : (simd_idx, xmmword) -> ExecutionResult
function exec_maxss(dst, src) = {
  var xmm : xmmword = read_xmm(dst);
  xmm[31..0] = __f32_max(xmm[31..0], src[31..0]);
  write_xmm_legacy(dst, xmm);
  Ok(())
}

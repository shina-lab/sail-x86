// Packed Double Precision FP Arithmetic: ADDPD, SUBPD, MULPD, DIVPD, SQRTPD, MINPD, MAXPD
// Operates on both 64-bit lanes of XMM. No flags affected.

val exec_addpd : (simd_idx, xmmword) -> ExecutionResult
function exec_addpd(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let lo : qword = __f64_add(a[63..0], b[63..0]);
  let hi : qword = __f64_add(a[127..64], b[127..64]);
  write_xmm_legacy(dst, hi @ lo);
  Ok(())
}

val exec_subpd : (simd_idx, xmmword) -> ExecutionResult
function exec_subpd(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  write_xmm_legacy(dst, __f64_sub(a[127..64], b[127..64]) @ __f64_sub(a[63..0], b[63..0]));
  Ok(())
}

val exec_mulpd : (simd_idx, xmmword) -> ExecutionResult
function exec_mulpd(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  write_xmm_legacy(dst, __f64_mul(a[127..64], b[127..64]) @ __f64_mul(a[63..0], b[63..0]));
  Ok(())
}

val exec_divpd : (simd_idx, xmmword) -> ExecutionResult
function exec_divpd(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  write_xmm_legacy(dst, __f64_div(a[127..64], b[127..64]) @ __f64_div(a[63..0], b[63..0]));
  Ok(())
}

val exec_sqrtpd : (simd_idx, xmmword) -> ExecutionResult
function exec_sqrtpd(dst, src) = {
  let b : xmmword = src;
  write_xmm_legacy(dst, __f64_sqrt(b[127..64]) @ __f64_sqrt(b[63..0]));
  Ok(())
}

val exec_minpd : (simd_idx, xmmword) -> ExecutionResult
function exec_minpd(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  write_xmm_legacy(dst, __f64_min(a[127..64], b[127..64]) @ __f64_min(a[63..0], b[63..0]));
  Ok(())
}

val exec_maxpd : (simd_idx, xmmword) -> ExecutionResult
function exec_maxpd(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  write_xmm_legacy(dst, __f64_max(a[127..64], b[127..64]) @ __f64_max(a[63..0], b[63..0]));
  Ok(())
}

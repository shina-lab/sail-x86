// Packed Single Precision FP Arithmetic: ADDPS, SUBPS, MULPS, DIVPS, SQRTPS, MINPS, MAXPS
// Operates on all four 32-bit lanes of XMM. No flags affected.

val exec_addps : (simd_idx, xmmword) -> ExecutionResult
function exec_addps(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword = __f32_add(a[127..96], b[127..96]) @
                       __f32_add(a[95..64], b[95..64]) @
                       __f32_add(a[63..32], b[63..32]) @
                       __f32_add(a[31..0], b[31..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

val exec_subps : (simd_idx, xmmword) -> ExecutionResult
function exec_subps(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword = __f32_sub(a[127..96], b[127..96]) @
                       __f32_sub(a[95..64], b[95..64]) @
                       __f32_sub(a[63..32], b[63..32]) @
                       __f32_sub(a[31..0], b[31..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

val exec_mulps : (simd_idx, xmmword) -> ExecutionResult
function exec_mulps(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword = __f32_mul(a[127..96], b[127..96]) @
                       __f32_mul(a[95..64], b[95..64]) @
                       __f32_mul(a[63..32], b[63..32]) @
                       __f32_mul(a[31..0], b[31..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

val exec_divps : (simd_idx, xmmword) -> ExecutionResult
function exec_divps(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword = __f32_div(a[127..96], b[127..96]) @
                       __f32_div(a[95..64], b[95..64]) @
                       __f32_div(a[63..32], b[63..32]) @
                       __f32_div(a[31..0], b[31..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

val exec_sqrtps : (simd_idx, xmmword) -> ExecutionResult
function exec_sqrtps(dst, src) = {
  let b : xmmword = src;
  let r : xmmword = __f32_sqrt(b[127..96]) @
                       __f32_sqrt(b[95..64]) @
                       __f32_sqrt(b[63..32]) @
                       __f32_sqrt(b[31..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

val exec_minps : (simd_idx, xmmword) -> ExecutionResult
function exec_minps(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword = __f32_min(a[127..96], b[127..96]) @
                       __f32_min(a[95..64], b[95..64]) @
                       __f32_min(a[63..32], b[63..32]) @
                       __f32_min(a[31..0], b[31..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

val exec_maxps : (simd_idx, xmmword) -> ExecutionResult
function exec_maxps(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword = __f32_max(a[127..96], b[127..96]) @
                       __f32_max(a[95..64], b[95..64]) @
                       __f32_max(a[63..32], b[63..32]) @
                       __f32_max(a[31..0], b[31..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

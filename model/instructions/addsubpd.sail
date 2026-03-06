// ADDSUBPD — Packed Double-FP Add/Subtract (SSE3)
// Lane 0: subtract, Lane 1: add. No flags affected.

val exec_addsubpd : (simd_idx, xmmword) -> ExecutionResult
function exec_addsubpd(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let lo : qword = __f64_sub(a[63..0], b[63..0]);
  let hi : qword = __f64_add(a[127..64], b[127..64]);
  write_xmm_legacy(dst, hi @ lo);
  Ok(())
}

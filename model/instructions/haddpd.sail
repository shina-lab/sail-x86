// HADDPD — Horizontal Add Packed Doubles (SSE3)
// HSUBPD — Horizontal Subtract Packed Doubles (SSE3)
// No flags affected.

val exec_haddpd : (simd_idx, xmmword) -> ExecutionResult
function exec_haddpd(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let lo : qword = __f64_add(a[63..0], a[127..64]);
  let hi : qword = __f64_add(b[63..0], b[127..64]);
  write_xmm_legacy(dst, hi @ lo);
  Ok(())
}

val exec_hsubpd : (simd_idx, xmmword) -> ExecutionResult
function exec_hsubpd(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let lo : qword = __f64_sub(a[63..0], a[127..64]);
  let hi : qword = __f64_sub(b[63..0], b[127..64]);
  write_xmm_legacy(dst, hi @ lo);
  Ok(())
}

// VHADDPD xmm1, xmm2, xmm3/m128 (VEX.128)
val exec_vhaddpd_128 : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vhaddpd_128(dst, src1, src2) = {
  let a : xmmword = src1;
  let b : xmmword = src2;
  let lo : qword = __f64_add(a[63..0], a[127..64]);
  let hi : qword = __f64_add(b[63..0], b[127..64]);
  write_xmm_vex(dst, hi @ lo);
  Ok(())
}

// VHADDPD ymm1, ymm2, ymm3/m256 (VEX.256)
val exec_vhaddpd_256 : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_vhaddpd_256(dst, src1, src2) = {
  let a : ymmword = read_ymm(src1);
  let b : ymmword = read_ymm(src2);
  let d0 : qword = __f64_add(a[63..0], a[127..64]);
  let d1 : qword = __f64_add(b[63..0], b[127..64]);
  let d2 : qword = __f64_add(a[191..128], a[255..192]);
  let d3 : qword = __f64_add(b[191..128], b[255..192]);
  write_ymm(dst, d3 @ d2 @ d1 @ d0);
  Ok(())
}

// VHSUBPD xmm1, xmm2, xmm3/m128 (VEX.128)
val exec_vhsubpd_128 : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vhsubpd_128(dst, src1, src2) = {
  let a : xmmword = src1;
  let b : xmmword = src2;
  let lo : qword = __f64_sub(a[63..0], a[127..64]);
  let hi : qword = __f64_sub(b[63..0], b[127..64]);
  write_xmm_vex(dst, hi @ lo);
  Ok(())
}

// VHSUBPD ymm1, ymm2, ymm3/m256 (VEX.256)
val exec_vhsubpd_256 : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_vhsubpd_256(dst, src1, src2) = {
  let a : ymmword = read_ymm(src1);
  let b : ymmword = read_ymm(src2);
  let d0 : qword = __f64_sub(a[63..0], a[127..64]);
  let d1 : qword = __f64_sub(b[63..0], b[127..64]);
  let d2 : qword = __f64_sub(a[191..128], a[255..192]);
  let d3 : qword = __f64_sub(b[191..128], b[255..192]);
  write_ymm(dst, d3 @ d2 @ d1 @ d0);
  Ok(())
}

// HADDPS — Horizontal Add Packed Singles (SSE3)
// HSUBPS — Horizontal Subtract Packed Singles (SSE3)
// No flags affected.

val exec_haddps : (simd_idx, xmmword) -> ExecutionResult
function exec_haddps(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let d0 : dword = __f32_add(a[31..0], a[63..32]);
  let d1 : dword = __f32_add(a[95..64], a[127..96]);
  let d2 : dword = __f32_add(b[31..0], b[63..32]);
  let d3 : dword = __f32_add(b[95..64], b[127..96]);
  write_xmm_legacy(dst, d3 @ d2 @ d1 @ d0);
  Ok(())
}

val exec_hsubps : (simd_idx, xmmword) -> ExecutionResult
function exec_hsubps(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let d0 : dword = __f32_sub(a[31..0], a[63..32]);
  let d1 : dword = __f32_sub(a[95..64], a[127..96]);
  let d2 : dword = __f32_sub(b[31..0], b[63..32]);
  let d3 : dword = __f32_sub(b[95..64], b[127..96]);
  write_xmm_legacy(dst, d3 @ d2 @ d1 @ d0);
  Ok(())
}

// VHADDPS xmm1, xmm2, xmm3/m128 (VEX.128)
val exec_vhaddps_128 : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vhaddps_128(dst, src1, src2) = {
  let a : xmmword = src1;
  let b : xmmword = src2;
  let d0 : dword = __f32_add(a[31..0], a[63..32]);
  let d1 : dword = __f32_add(a[95..64], a[127..96]);
  let d2 : dword = __f32_add(b[31..0], b[63..32]);
  let d3 : dword = __f32_add(b[95..64], b[127..96]);
  write_xmm_vex(dst, d3 @ d2 @ d1 @ d0);
  Ok(())
}

// VHADDPS ymm1, ymm2, ymm3/m256 (VEX.256)
val exec_vhaddps_256 : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_vhaddps_256(dst, src1, src2) = {
  let a : ymmword = read_ymm(src1);
  let b : ymmword = read_ymm(src2);
  let d0 : dword = __f32_add(a[31..0], a[63..32]);
  let d1 : dword = __f32_add(a[95..64], a[127..96]);
  let d2 : dword = __f32_add(b[31..0], b[63..32]);
  let d3 : dword = __f32_add(b[95..64], b[127..96]);
  let d4 : dword = __f32_add(a[159..128], a[191..160]);
  let d5 : dword = __f32_add(a[223..192], a[255..224]);
  let d6 : dword = __f32_add(b[159..128], b[191..160]);
  let d7 : dword = __f32_add(b[223..192], b[255..224]);
  write_ymm(dst, d7 @ d6 @ d5 @ d4 @ d3 @ d2 @ d1 @ d0);
  Ok(())
}

// VHSUBPS xmm1, xmm2, xmm3/m128 (VEX.128)
val exec_vhsubps_128 : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vhsubps_128(dst, src1, src2) = {
  let a : xmmword = src1;
  let b : xmmword = src2;
  let d0 : dword = __f32_sub(a[31..0], a[63..32]);
  let d1 : dword = __f32_sub(a[95..64], a[127..96]);
  let d2 : dword = __f32_sub(b[31..0], b[63..32]);
  let d3 : dword = __f32_sub(b[95..64], b[127..96]);
  write_xmm_vex(dst, d3 @ d2 @ d1 @ d0);
  Ok(())
}

// VHSUBPS ymm1, ymm2, ymm3/m256 (VEX.256)
val exec_vhsubps_256 : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_vhsubps_256(dst, src1, src2) = {
  let a : ymmword = read_ymm(src1);
  let b : ymmword = read_ymm(src2);
  let d0 : dword = __f32_sub(a[31..0], a[63..32]);
  let d1 : dword = __f32_sub(a[95..64], a[127..96]);
  let d2 : dword = __f32_sub(b[31..0], b[63..32]);
  let d3 : dword = __f32_sub(b[95..64], b[127..96]);
  let d4 : dword = __f32_sub(a[159..128], a[191..160]);
  let d5 : dword = __f32_sub(a[223..192], a[255..224]);
  let d6 : dword = __f32_sub(b[159..128], b[191..160]);
  let d7 : dword = __f32_sub(b[223..192], b[255..224]);
  write_ymm(dst, d7 @ d6 @ d5 @ d4 @ d3 @ d2 @ d1 @ d0);
  Ok(())
}

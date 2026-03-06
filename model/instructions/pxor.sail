// PXOR — Logical Exclusive OR (packed)
//
// 128-bit bitwise XOR on XMM registers. No flags affected.

// Legacy SSE: PXOR xmm1, xmm2
val exec_pxor_xmm : (simd_idx, xmmword) -> ExecutionResult
function exec_pxor_xmm(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  write_xmm_legacy(dst, a ^ b);
  Ok(())
}

// VEX.128: VPXOR xmm1, xmm2, xmm3
val exec_vpxor_xmm : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vpxor_xmm(dst, src1, src2) = {
  let a : xmmword = src1;
  let b : xmmword = src2;
  write_xmm(dst, a ^ b);
  Ok(())
}

// VEX.256: VPXOR ymm1, ymm2, ymm3
val exec_vpxor_ymm : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_vpxor_ymm(dst, src1, src2) = {
  let a : ymmword = read_ymm(src1);
  let b : ymmword = read_ymm(src2);
  write_ymm(dst, a ^ b);
  Ok(())
}

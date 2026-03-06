// PAND — Logical AND (packed)
//
// 128-bit SSE: xmm1 := xmm1 AND xmm2/m128 (upper bits unmodified)
// VEX.128:    xmm1 := xmm2 AND xmm3/m128 (upper bits zeroed)
// No flags affected.

// Legacy SSE: PAND xmm1, xmm2
val exec_pand_xmm : (simd_idx, xmmword) -> ExecutionResult
function exec_pand_xmm(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  write_xmm_legacy(dst, a & b);
  Ok(())
}

// VEX.128: VPAND xmm1, xmm2, xmm3
val exec_vpand_xmm : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vpand_xmm(dst, src1, src2) = {
  let a : xmmword = src1;
  let b : xmmword = src2;
  write_xmm(dst, a & b);
  Ok(())
}

// VEX.256: VPAND ymm1, ymm2, ymm3
val exec_vpand_ymm : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_vpand_ymm(dst, src1, src2) = {
  let a : ymmword = read_ymm(src1);
  let b : ymmword = read_ymm(src2);
  write_ymm(dst, a & b);
  Ok(())
}

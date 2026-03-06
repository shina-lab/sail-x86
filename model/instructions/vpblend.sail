// VPBLENDD — Blend Packed Dwords
// VPBLENDMB/VPBLENDMW — Blend Byte/Word Vectors Using Opmask
// VPBLENDMD/VPBLENDMQ — Blend Int32/Int64 Vectors Using Opmask
//
// AVX2 and AVX-512 blend instructions. All modeled as external functions.
// No flags affected.

// =========================================================================
// VPBLENDD — Blend Packed Dwords (AVX2)
// =========================================================================

val __vpblendd_xmm : (xmmword, xmmword, byte) -> xmmword
val __vpblendd_ymm : (ymmword, ymmword, byte) -> ymmword

// VPBLENDD (VEX.128): xmm1 := blend(xmm2, xmm3/m128, imm8)
val exec_vpblendd_xmm : (simd_idx, xmmword, xmmword, byte) -> ExecutionResult
function exec_vpblendd_xmm(dst, src1, src2, imm8) = {
  let a : xmmword = src1;
  let b : xmmword = src2;
  write_xmm(dst, __vpblendd_xmm(a, b, imm8));
  Ok(())
}

// VPBLENDD (VEX.256): ymm1 := blend(ymm2, ymm3/m256, imm8)
val exec_vpblendd_ymm : (simd_idx, simd_idx, simd_idx, byte) -> ExecutionResult
function exec_vpblendd_ymm(dst, src1, src2, imm8) = {
  let a : ymmword = read_ymm(src1);
  let b : ymmword = read_ymm(src2);
  write_ymm(dst, __vpblendd_ymm(a, b, imm8));
  Ok(())
}

// =========================================================================
// VPBLENDMB/VPBLENDMW — Blend Byte/Word Using Opmask (AVX-512)
// =========================================================================

val __vpblendmb_xmm : (xmmword, xmmword, xmmword) -> xmmword
val __vpblendmb_ymm : (ymmword, ymmword, ymmword) -> ymmword
val __vpblendmb_zmm : (zmmword, zmmword, zmmword) -> zmmword
val __vpblendmw_xmm : (xmmword, xmmword, xmmword) -> xmmword
val __vpblendmw_ymm : (ymmword, ymmword, ymmword) -> ymmword
val __vpblendmw_zmm : (zmmword, zmmword, zmmword) -> zmmword

// VPBLENDMB (EVEX.128): xmm1 {k1}{z} := blend(xmm2, xmm3/m128) using k1
val exec_vpblendmb_xmm : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vpblendmb_xmm(dst, src1, src2) = {
  let a : xmmword = src1;
  let b : xmmword = src2;
  let d : xmmword = read_xmm(dst);
  write_xmm(dst, __vpblendmb_xmm(a, b, d));
  Ok(())
}

// VPBLENDMB (EVEX.256): ymm1 {k1}{z} := blend(ymm2, ymm3/m256) using k1
val exec_vpblendmb_ymm : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_vpblendmb_ymm(dst, src1, src2) = {
  let a : ymmword = read_ymm(src1);
  let b : ymmword = read_ymm(src2);
  let d : ymmword = read_ymm(dst);
  write_ymm(dst, __vpblendmb_ymm(a, b, d));
  Ok(())
}

// VPBLENDMB (EVEX.512): zmm1 {k1}{z} := blend(zmm2, zmm3/m512) using k1
val exec_vpblendmb_zmm : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_vpblendmb_zmm(dst, src1, src2) = {
  let a : zmmword = read_zmm(src1);
  let b : zmmword = read_zmm(src2);
  let d : zmmword = read_zmm(dst);
  write_zmm(dst, __vpblendmb_zmm(a, b, d));
  Ok(())
}

// VPBLENDMW (EVEX.128): xmm1 {k1}{z} := blend(xmm2, xmm3/m128) using k1
val exec_vpblendmw_xmm : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vpblendmw_xmm(dst, src1, src2) = {
  let a : xmmword = src1;
  let b : xmmword = src2;
  let d : xmmword = read_xmm(dst);
  write_xmm(dst, __vpblendmw_xmm(a, b, d));
  Ok(())
}

// VPBLENDMW (EVEX.256): ymm1 {k1}{z} := blend(ymm2, ymm3/m256) using k1
val exec_vpblendmw_ymm : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_vpblendmw_ymm(dst, src1, src2) = {
  let a : ymmword = read_ymm(src1);
  let b : ymmword = read_ymm(src2);
  let d : ymmword = read_ymm(dst);
  write_ymm(dst, __vpblendmw_ymm(a, b, d));
  Ok(())
}

// VPBLENDMW (EVEX.512): zmm1 {k1}{z} := blend(zmm2, zmm3/m512) using k1
val exec_vpblendmw_zmm : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_vpblendmw_zmm(dst, src1, src2) = {
  let a : zmmword = read_zmm(src1);
  let b : zmmword = read_zmm(src2);
  let d : zmmword = read_zmm(dst);
  write_zmm(dst, __vpblendmw_zmm(a, b, d));
  Ok(())
}

// =========================================================================
// VPBLENDMD/VPBLENDMQ — Blend Int32/Int64 Using Opmask (AVX-512)
// =========================================================================

val __vpblendmd_xmm : (xmmword, xmmword, xmmword) -> xmmword
val __vpblendmd_ymm : (ymmword, ymmword, ymmword) -> ymmword
val __vpblendmd_zmm : (zmmword, zmmword, zmmword) -> zmmword
val __vpblendmq_xmm : (xmmword, xmmword, xmmword) -> xmmword
val __vpblendmq_ymm : (ymmword, ymmword, ymmword) -> ymmword
val __vpblendmq_zmm : (zmmword, zmmword, zmmword) -> zmmword

// VPBLENDMD (EVEX.128): xmm1 {k1}{z} := blend(xmm2, xmm3/m128) using k1
val exec_vpblendmd_xmm : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vpblendmd_xmm(dst, src1, src2) = {
  let a : xmmword = src1;
  let b : xmmword = src2;
  let d : xmmword = read_xmm(dst);
  write_xmm(dst, __vpblendmd_xmm(a, b, d));
  Ok(())
}

// VPBLENDMD (EVEX.256): ymm1 {k1}{z} := blend(ymm2, ymm3/m256) using k1
val exec_vpblendmd_ymm : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_vpblendmd_ymm(dst, src1, src2) = {
  let a : ymmword = read_ymm(src1);
  let b : ymmword = read_ymm(src2);
  let d : ymmword = read_ymm(dst);
  write_ymm(dst, __vpblendmd_ymm(a, b, d));
  Ok(())
}

// VPBLENDMD (EVEX.512): zmm1 {k1}{z} := blend(zmm2, zmm3/m512) using k1
val exec_vpblendmd_zmm : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_vpblendmd_zmm(dst, src1, src2) = {
  let a : zmmword = read_zmm(src1);
  let b : zmmword = read_zmm(src2);
  let d : zmmword = read_zmm(dst);
  write_zmm(dst, __vpblendmd_zmm(a, b, d));
  Ok(())
}

// VPBLENDMQ (EVEX.128): xmm1 {k1}{z} := blend(xmm2, xmm3/m128) using k1
val exec_vpblendmq_xmm : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vpblendmq_xmm(dst, src1, src2) = {
  let a : xmmword = src1;
  let b : xmmword = src2;
  let d : xmmword = read_xmm(dst);
  write_xmm(dst, __vpblendmq_xmm(a, b, d));
  Ok(())
}

// VPBLENDMQ (EVEX.256): ymm1 {k1}{z} := blend(ymm2, ymm3/m256) using k1
val exec_vpblendmq_ymm : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_vpblendmq_ymm(dst, src1, src2) = {
  let a : ymmword = read_ymm(src1);
  let b : ymmword = read_ymm(src2);
  let d : ymmword = read_ymm(dst);
  write_ymm(dst, __vpblendmq_ymm(a, b, d));
  Ok(())
}

// VPBLENDMQ (EVEX.512): zmm1 {k1}{z} := blend(zmm2, zmm3/m512) using k1
val exec_vpblendmq_zmm : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_vpblendmq_zmm(dst, src1, src2) = {
  let a : zmmword = read_zmm(src1);
  let b : zmmword = read_zmm(src2);
  let d : zmmword = read_zmm(dst);
  write_zmm(dst, __vpblendmq_zmm(a, b, d));
  Ok(())
}

// VPDPBUSD — Multiply and Add Unsigned and Signed Bytes
// VPDPBUSDS — Multiply and Add Unsigned and Signed Bytes with Saturation
// VPDPWSSD — Multiply and Add Signed Word Integers
// VPDPWSSDS — Multiply and Add Signed Word Integers with Saturation
// VP4DPWSSD — Dot Product of Signed Words with Dword Accumulation (4-register)
// VP4DPWSSDS — Dot Product of Signed Words with Dword Accumulation and Saturation (4-register)
//
// AVX-512 VNNI and AVX-512_4VNNI dot-product instructions.
// All modeled as external functions. No flags affected.

// =========================================================================
// VPDPBUSD — Multiply and Add Unsigned and Signed Bytes (AVX-512 VNNI)
// =========================================================================

val __vpdpbusd_xmm : (xmmword, xmmword, xmmword) -> xmmword
val __vpdpbusd_ymm : (ymmword, ymmword, ymmword) -> ymmword
val __vpdpbusd_zmm : (zmmword, zmmword, zmmword) -> zmmword

// VPDPBUSD (EVEX.128): xmm1 {k1}{z} := xmm1 + dotprod(xmm2, xmm3/m128)
val exec_vpdpbusd_xmm : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vpdpbusd_xmm(dst, src1, src2) = {
  let d : xmmword = read_xmm(dst);
  let a : xmmword = src1;
  let b : xmmword = src2;
  write_xmm(dst, __vpdpbusd_xmm(d, a, b));
  Ok(())
}

// VPDPBUSD (EVEX.256): ymm1 {k1}{z} := ymm1 + dotprod(ymm2, ymm3/m256)
val exec_vpdpbusd_ymm : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_vpdpbusd_ymm(dst, src1, src2) = {
  let d : ymmword = read_ymm(dst);
  let a : ymmword = read_ymm(src1);
  let b : ymmword = read_ymm(src2);
  write_ymm(dst, __vpdpbusd_ymm(d, a, b));
  Ok(())
}

// VPDPBUSD (EVEX.512): zmm1 {k1}{z} := zmm1 + dotprod(zmm2, zmm3/m512)
val exec_vpdpbusd_zmm : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_vpdpbusd_zmm(dst, src1, src2) = {
  let d : zmmword = read_zmm(dst);
  let a : zmmword = read_zmm(src1);
  let b : zmmword = read_zmm(src2);
  write_zmm(dst, __vpdpbusd_zmm(d, a, b));
  Ok(())
}

// =========================================================================
// VPDPBUSDS — Multiply and Add Unsigned and Signed Bytes with Saturation
// =========================================================================

val __vpdpbusds_xmm : (xmmword, xmmword, xmmword) -> xmmword
val __vpdpbusds_ymm : (ymmword, ymmword, ymmword) -> ymmword
val __vpdpbusds_zmm : (zmmword, zmmword, zmmword) -> zmmword

// VPDPBUSDS (EVEX.128): xmm1 {k1}{z} := saturate(xmm1 + dotprod(xmm2, xmm3/m128))
val exec_vpdpbusds_xmm : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vpdpbusds_xmm(dst, src1, src2) = {
  let d : xmmword = read_xmm(dst);
  let a : xmmword = src1;
  let b : xmmword = src2;
  write_xmm(dst, __vpdpbusds_xmm(d, a, b));
  Ok(())
}

// VPDPBUSDS (EVEX.256): ymm1 {k1}{z} := saturate(ymm1 + dotprod(ymm2, ymm3/m256))
val exec_vpdpbusds_ymm : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_vpdpbusds_ymm(dst, src1, src2) = {
  let d : ymmword = read_ymm(dst);
  let a : ymmword = read_ymm(src1);
  let b : ymmword = read_ymm(src2);
  write_ymm(dst, __vpdpbusds_ymm(d, a, b));
  Ok(())
}

// VPDPBUSDS (EVEX.512): zmm1 {k1}{z} := saturate(zmm1 + dotprod(zmm2, zmm3/m512))
val exec_vpdpbusds_zmm : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_vpdpbusds_zmm(dst, src1, src2) = {
  let d : zmmword = read_zmm(dst);
  let a : zmmword = read_zmm(src1);
  let b : zmmword = read_zmm(src2);
  write_zmm(dst, __vpdpbusds_zmm(d, a, b));
  Ok(())
}

// =========================================================================
// VPDPWSSD — Multiply and Add Signed Word Integers (AVX-512 VNNI)
// =========================================================================

val __vpdpwssd_xmm : (xmmword, xmmword, xmmword) -> xmmword
val __vpdpwssd_ymm : (ymmword, ymmword, ymmword) -> ymmword
val __vpdpwssd_zmm : (zmmword, zmmword, zmmword) -> zmmword

// VPDPWSSD (EVEX.128): xmm1 {k1}{z} := xmm1 + dotprod(xmm2, xmm3/m128)
val exec_vpdpwssd_xmm : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vpdpwssd_xmm(dst, src1, src2) = {
  let d : xmmword = read_xmm(dst);
  let a : xmmword = src1;
  let b : xmmword = src2;
  write_xmm(dst, __vpdpwssd_xmm(d, a, b));
  Ok(())
}

// VPDPWSSD (EVEX.256): ymm1 {k1}{z} := ymm1 + dotprod(ymm2, ymm3/m256)
val exec_vpdpwssd_ymm : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_vpdpwssd_ymm(dst, src1, src2) = {
  let d : ymmword = read_ymm(dst);
  let a : ymmword = read_ymm(src1);
  let b : ymmword = read_ymm(src2);
  write_ymm(dst, __vpdpwssd_ymm(d, a, b));
  Ok(())
}

// VPDPWSSD (EVEX.512): zmm1 {k1}{z} := zmm1 + dotprod(zmm2, zmm3/m512)
val exec_vpdpwssd_zmm : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_vpdpwssd_zmm(dst, src1, src2) = {
  let d : zmmword = read_zmm(dst);
  let a : zmmword = read_zmm(src1);
  let b : zmmword = read_zmm(src2);
  write_zmm(dst, __vpdpwssd_zmm(d, a, b));
  Ok(())
}

// =========================================================================
// VPDPWSSDS — Multiply and Add Signed Word Integers with Saturation
// =========================================================================

val __vpdpwssds_xmm : (xmmword, xmmword, xmmword) -> xmmword
val __vpdpwssds_ymm : (ymmword, ymmword, ymmword) -> ymmword
val __vpdpwssds_zmm : (zmmword, zmmword, zmmword) -> zmmword

// VPDPWSSDS (EVEX.128): xmm1 {k1}{z} := saturate(xmm1 + dotprod(xmm2, xmm3/m128))
val exec_vpdpwssds_xmm : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vpdpwssds_xmm(dst, src1, src2) = {
  let d : xmmword = read_xmm(dst);
  let a : xmmword = src1;
  let b : xmmword = src2;
  write_xmm(dst, __vpdpwssds_xmm(d, a, b));
  Ok(())
}

// VPDPWSSDS (EVEX.256): ymm1 {k1}{z} := saturate(ymm1 + dotprod(ymm2, ymm3/m256))
val exec_vpdpwssds_ymm : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_vpdpwssds_ymm(dst, src1, src2) = {
  let d : ymmword = read_ymm(dst);
  let a : ymmword = read_ymm(src1);
  let b : ymmword = read_ymm(src2);
  write_ymm(dst, __vpdpwssds_ymm(d, a, b));
  Ok(())
}

// VPDPWSSDS (EVEX.512): zmm1 {k1}{z} := saturate(zmm1 + dotprod(zmm2, zmm3/m512))
val exec_vpdpwssds_zmm : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_vpdpwssds_zmm(dst, src1, src2) = {
  let d : zmmword = read_zmm(dst);
  let a : zmmword = read_zmm(src1);
  let b : zmmword = read_zmm(src2);
  write_zmm(dst, __vpdpwssds_zmm(d, a, b));
  Ok(())
}

// =========================================================================
// VP4DPWSSD — Dot Product of Signed Words with Dword Accumulation (4-register)
// Uses 4 consecutive source registers (zmm+0 through zmm+3) and a m128 operand.
// AVX-512_4VNNI, EVEX.512 only.
// =========================================================================

val __vp4dpwssd : (zmmword, zmmword, zmmword, zmmword, zmmword, xmmword) -> zmmword

// VP4DPWSSD (EVEX.512): zmm1 {k1}{z} := zmm1 + dotprod4(zmm2+0..zmm2+3, m128)
val exec_vp4dpwssd : (simd_idx, simd_idx, simd_idx, simd_idx, simd_idx, xmmword) -> ExecutionResult
function exec_vp4dpwssd(dst, src0, src1, src2, src3, mem_val) = {
  let d : zmmword = read_zmm(dst);
  let s0 : zmmword = read_zmm(src0);
  let s1 : zmmword = read_zmm(src1);
  let s2 : zmmword = read_zmm(src2);
  let s3 : zmmword = read_zmm(src3);
  write_zmm(dst, __vp4dpwssd(d, s0, s1, s2, s3, mem_val));
  Ok(())
}

// =========================================================================
// VP4DPWSSDS — Dot Product of Signed Words with Dword Accumulation and Saturation
// AVX-512_4VNNI, EVEX.512 only.
// =========================================================================

val __vp4dpwssds : (zmmword, zmmword, zmmword, zmmword, zmmword, xmmword) -> zmmword

// VP4DPWSSDS (EVEX.512): zmm1 {k1}{z} := saturate(zmm1 + dotprod4(zmm2+0..zmm2+3, m128))
val exec_vp4dpwssds : (simd_idx, simd_idx, simd_idx, simd_idx, simd_idx, xmmword) -> ExecutionResult
function exec_vp4dpwssds(dst, src0, src1, src2, src3, mem_val) = {
  let d : zmmword = read_zmm(dst);
  let s0 : zmmword = read_zmm(src0);
  let s1 : zmmword = read_zmm(src1);
  let s2 : zmmword = read_zmm(src2);
  let s3 : zmmword = read_zmm(src3);
  write_zmm(dst, __vp4dpwssds(d, s0, s1, s2, s3, mem_val));
  Ok(())
}

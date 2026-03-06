// VPCOMPRESSB/VPCOMPRESSW — Store Sparse Packed Byte/Word Values into Dense Memory/Register
// VPCOMPRESSD — Store Sparse Packed Dword Values into Dense Memory/Register
// VPCOMPRESSQ — Store Sparse Packed Qword Values into Dense Memory/Register
//
// AVX-512 compress instructions. Elements selected by the writemask are
// stored contiguously in the destination. Modeled as external functions.
// No flags affected.

// =========================================================================
// VPCOMPRESSB — Compress Packed Bytes (AVX-512 VBMI2)
// =========================================================================

val __vpcompressb_xmm : (xmmword, word) -> xmmword
val __vpcompressb_ymm : (ymmword, dword) -> ymmword
val __vpcompressb_zmm : (zmmword, qword) -> zmmword

// VPCOMPRESSB (EVEX.128): xmm1/m128 {k1}{z} := compress(xmm2)
val exec_vpcompressb_xmm : (simd_idx, xmmword, word) -> ExecutionResult
function exec_vpcompressb_xmm(dst, src, mask) = {
  let s : xmmword = src;
  write_xmm(dst, __vpcompressb_xmm(s, mask));
  Ok(())
}

// VPCOMPRESSB (EVEX.256): ymm1/m256 {k1}{z} := compress(ymm2)
val exec_vpcompressb_ymm : (simd_idx, simd_idx, dword) -> ExecutionResult
function exec_vpcompressb_ymm(dst, src, mask) = {
  let s : ymmword = read_ymm(src);
  write_ymm(dst, __vpcompressb_ymm(s, mask));
  Ok(())
}

// VPCOMPRESSB (EVEX.512): zmm1/m512 {k1}{z} := compress(zmm2)
val exec_vpcompressb_zmm : (simd_idx, simd_idx, qword) -> ExecutionResult
function exec_vpcompressb_zmm(dst, src, mask) = {
  let s : zmmword = read_zmm(src);
  write_zmm(dst, __vpcompressb_zmm(s, mask));
  Ok(())
}

// =========================================================================
// VPCOMPRESSW — Compress Packed Words (AVX-512 VBMI2)
// =========================================================================

val __vpcompressw_xmm : (xmmword, byte) -> xmmword
val __vpcompressw_ymm : (ymmword, word) -> ymmword
val __vpcompressw_zmm : (zmmword, dword) -> zmmword

// VPCOMPRESSW (EVEX.128): xmm1/m128 {k1}{z} := compress(xmm2)
val exec_vpcompressw_xmm : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_vpcompressw_xmm(dst, src, mask) = {
  let s : xmmword = src;
  write_xmm(dst, __vpcompressw_xmm(s, mask));
  Ok(())
}

// VPCOMPRESSW (EVEX.256): ymm1/m256 {k1}{z} := compress(ymm2)
val exec_vpcompressw_ymm : (simd_idx, simd_idx, word) -> ExecutionResult
function exec_vpcompressw_ymm(dst, src, mask) = {
  let s : ymmword = read_ymm(src);
  write_ymm(dst, __vpcompressw_ymm(s, mask));
  Ok(())
}

// VPCOMPRESSW (EVEX.512): zmm1/m512 {k1}{z} := compress(zmm2)
val exec_vpcompressw_zmm : (simd_idx, simd_idx, dword) -> ExecutionResult
function exec_vpcompressw_zmm(dst, src, mask) = {
  let s : zmmword = read_zmm(src);
  write_zmm(dst, __vpcompressw_zmm(s, mask));
  Ok(())
}

// =========================================================================
// VPCOMPRESSD — Compress Packed Dwords (AVX-512)
// =========================================================================

val __vpcompressd_xmm : (xmmword, byte) -> xmmword
val __vpcompressd_ymm : (ymmword, byte) -> ymmword
val __vpcompressd_zmm : (zmmword, word) -> zmmword

// VPCOMPRESSD (EVEX.128): xmm1/m128 {k1}{z} := compress(xmm2)
val exec_vpcompressd_xmm : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_vpcompressd_xmm(dst, src, mask) = {
  let s : xmmword = src;
  write_xmm(dst, __vpcompressd_xmm(s, mask));
  Ok(())
}

// VPCOMPRESSD (EVEX.256): ymm1/m256 {k1}{z} := compress(ymm2)
val exec_vpcompressd_ymm : (simd_idx, simd_idx, byte) -> ExecutionResult
function exec_vpcompressd_ymm(dst, src, mask) = {
  let s : ymmword = read_ymm(src);
  write_ymm(dst, __vpcompressd_ymm(s, mask));
  Ok(())
}

// VPCOMPRESSD (EVEX.512): zmm1/m512 {k1}{z} := compress(zmm2)
val exec_vpcompressd_zmm : (simd_idx, simd_idx, word) -> ExecutionResult
function exec_vpcompressd_zmm(dst, src, mask) = {
  let s : zmmword = read_zmm(src);
  write_zmm(dst, __vpcompressd_zmm(s, mask));
  Ok(())
}

// =========================================================================
// VPCOMPRESSQ — Compress Packed Qwords (AVX-512)
// =========================================================================

val __vpcompressq_xmm : (xmmword, byte) -> xmmword
val __vpcompressq_ymm : (ymmword, byte) -> ymmword
val __vpcompressq_zmm : (zmmword, byte) -> zmmword

// VPCOMPRESSQ (EVEX.128): xmm1/m128 {k1}{z} := compress(xmm2)
val exec_vpcompressq_xmm : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_vpcompressq_xmm(dst, src, mask) = {
  let s : xmmword = src;
  write_xmm(dst, __vpcompressq_xmm(s, mask));
  Ok(())
}

// VPCOMPRESSQ (EVEX.256): ymm1/m256 {k1}{z} := compress(ymm2)
val exec_vpcompressq_ymm : (simd_idx, simd_idx, byte) -> ExecutionResult
function exec_vpcompressq_ymm(dst, src, mask) = {
  let s : ymmword = read_ymm(src);
  write_ymm(dst, __vpcompressq_ymm(s, mask));
  Ok(())
}

// VPCOMPRESSQ (EVEX.512): zmm1/m512 {k1}{z} := compress(zmm2)
val exec_vpcompressq_zmm : (simd_idx, simd_idx, byte) -> ExecutionResult
function exec_vpcompressq_zmm(dst, src, mask) = {
  let s : zmmword = read_zmm(src);
  write_zmm(dst, __vpcompressq_zmm(s, mask));
  Ok(())
}

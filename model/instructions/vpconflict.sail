// VPCONFLICTD/VPCONFLICTQ — Detect Conflicts Within a Vector of Packed Dword/Qword Values
//
// For each element, these instructions produce a bitmask of preceding elements
// with matching values (used for scatter conflict detection).
// AVX-512CD instructions modeled as external functions.
// No flags affected.

// =========================================================================
// VP2INTERSECTD/VP2INTERSECTQ — Compute Intersection Between Dwords/Qwords
// =========================================================================

// VP2INTERSECT produces two opmask results indicating which element pairs
// from the two sources are equal.

val __vp2intersectd_xmm : (xmmword, xmmword) -> (byte, byte)
val __vp2intersectd_ymm : (ymmword, ymmword) -> (byte, byte)
val __vp2intersectd_zmm : (zmmword, zmmword) -> (word, word)
val __vp2intersectq_xmm : (xmmword, xmmword) -> (byte, byte)
val __vp2intersectq_ymm : (ymmword, ymmword) -> (byte, byte)
val __vp2intersectq_zmm : (zmmword, zmmword) -> (byte, byte)

// VP2INTERSECTD (EVEX.128): k0, k1 := intersect(xmm2, xmm3/m128)
val exec_vp2intersectd_xmm : (xmmword, xmmword) -> (ExecutionResult, byte, byte)
function exec_vp2intersectd_xmm(src1, src2) = {
  let a : xmmword = src1;
  let b : xmmword = src2;
  let (k0, k1) = __vp2intersectd_xmm(a, b);
  (Ok(()), k0, k1)
}

// VP2INTERSECTD (EVEX.256): k0, k1 := intersect(ymm2, ymm3/m256)
val exec_vp2intersectd_ymm : (simd_idx, simd_idx) -> (ExecutionResult, byte, byte)
function exec_vp2intersectd_ymm(src1, src2) = {
  let a : ymmword = read_ymm(src1);
  let b : ymmword = read_ymm(src2);
  let (k0, k1) = __vp2intersectd_ymm(a, b);
  (Ok(()), k0, k1)
}

// VP2INTERSECTD (EVEX.512): k0, k1 := intersect(zmm2, zmm3/m512)
val exec_vp2intersectd_zmm : (simd_idx, simd_idx) -> (ExecutionResult, word, word)
function exec_vp2intersectd_zmm(src1, src2) = {
  let a : zmmword = read_zmm(src1);
  let b : zmmword = read_zmm(src2);
  let (k0, k1) = __vp2intersectd_zmm(a, b);
  (Ok(()), k0, k1)
}

// VP2INTERSECTQ (EVEX.128): k0, k1 := intersect(xmm2, xmm3/m128)
val exec_vp2intersectq_xmm : (xmmword, xmmword) -> (ExecutionResult, byte, byte)
function exec_vp2intersectq_xmm(src1, src2) = {
  let a : xmmword = src1;
  let b : xmmword = src2;
  let (k0, k1) = __vp2intersectq_xmm(a, b);
  (Ok(()), k0, k1)
}

// VP2INTERSECTQ (EVEX.256): k0, k1 := intersect(ymm2, ymm3/m256)
val exec_vp2intersectq_ymm : (simd_idx, simd_idx) -> (ExecutionResult, byte, byte)
function exec_vp2intersectq_ymm(src1, src2) = {
  let a : ymmword = read_ymm(src1);
  let b : ymmword = read_ymm(src2);
  let (k0, k1) = __vp2intersectq_ymm(a, b);
  (Ok(()), k0, k1)
}

// VP2INTERSECTQ (EVEX.512): k0, k1 := intersect(zmm2, zmm3/m512)
val exec_vp2intersectq_zmm : (simd_idx, simd_idx) -> (ExecutionResult, byte, byte)
function exec_vp2intersectq_zmm(src1, src2) = {
  let a : zmmword = read_zmm(src1);
  let b : zmmword = read_zmm(src2);
  let (k0, k1) = __vp2intersectq_zmm(a, b);
  (Ok(()), k0, k1)
}

// =========================================================================
// VPCONFLICTD — Detect Conflicts Within Packed Dwords (AVX-512CD)
// =========================================================================

val __vpconflictd_xmm : xmmword -> xmmword
val __vpconflictd_ymm : ymmword -> ymmword
val __vpconflictd_zmm : zmmword -> zmmword

// VPCONFLICTD (EVEX.128): xmm1 {k1}{z} := conflict_detect(xmm2/m128)
val exec_vpconflictd_xmm : (simd_idx, xmmword) -> ExecutionResult
function exec_vpconflictd_xmm(dst, src) = {
  let s : xmmword = src;
  write_xmm(dst, __vpconflictd_xmm(s));
  Ok(())
}

// VPCONFLICTD (EVEX.256): ymm1 {k1}{z} := conflict_detect(ymm2/m256)
val exec_vpconflictd_ymm : (simd_idx, simd_idx) -> ExecutionResult
function exec_vpconflictd_ymm(dst, src) = {
  let s : ymmword = read_ymm(src);
  write_ymm(dst, __vpconflictd_ymm(s));
  Ok(())
}

// VPCONFLICTD (EVEX.512): zmm1 {k1}{z} := conflict_detect(zmm2/m512)
val exec_vpconflictd_zmm : (simd_idx, simd_idx) -> ExecutionResult
function exec_vpconflictd_zmm(dst, src) = {
  let s : zmmword = read_zmm(src);
  write_zmm(dst, __vpconflictd_zmm(s));
  Ok(())
}

// =========================================================================
// VPCONFLICTQ — Detect Conflicts Within Packed Qwords (AVX-512CD)
// =========================================================================

val __vpconflictq_xmm : xmmword -> xmmword
val __vpconflictq_ymm : ymmword -> ymmword
val __vpconflictq_zmm : zmmword -> zmmword

// VPCONFLICTQ (EVEX.128): xmm1 {k1}{z} := conflict_detect(xmm2/m128)
val exec_vpconflictq_xmm : (simd_idx, xmmword) -> ExecutionResult
function exec_vpconflictq_xmm(dst, src) = {
  let s : xmmword = src;
  write_xmm(dst, __vpconflictq_xmm(s));
  Ok(())
}

// VPCONFLICTQ (EVEX.256): ymm1 {k1}{z} := conflict_detect(ymm2/m256)
val exec_vpconflictq_ymm : (simd_idx, simd_idx) -> ExecutionResult
function exec_vpconflictq_ymm(dst, src) = {
  let s : ymmword = read_ymm(src);
  write_ymm(dst, __vpconflictq_ymm(s));
  Ok(())
}

// VPCONFLICTQ (EVEX.512): zmm1 {k1}{z} := conflict_detect(zmm2/m512)
val exec_vpconflictq_zmm : (simd_idx, simd_idx) -> ExecutionResult
function exec_vpconflictq_zmm(dst, src) = {
  let s : zmmword = read_zmm(src);
  write_zmm(dst, __vpconflictq_zmm(s));
  Ok(())
}

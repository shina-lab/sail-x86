// GF2P8AFFINEINVQB -- Galois Field Affine Transformation Inverse
// GF2P8AFFINEQB -- Galois Field Affine Transformation
// GF2P8MULB -- Galois Field Multiply Bytes
//
// These instructions perform Galois Field GF(2^8) operations.
// The mathematics are complex (matrix multiplication in GF(2^8),
// multiplicative inverse in GF(2^8) with polynomial 0x11B), so
// we model them as external operations.

val __gf2p8affineinvqb : (xmmword, xmmword, byte) -> xmmword
val __gf2p8affineqb : (xmmword, xmmword, byte) -> xmmword
val __gf2p8mulb : (xmmword, xmmword) -> xmmword

// GF2P8AFFINEINVQB xmm1, xmm2/m128, imm8
val exec_gf2p8affineinvqb : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_gf2p8affineinvqb(dst, src, imm8) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  write_xmm_legacy(dst, __gf2p8affineinvqb(a, b, imm8));
  Ok(())
}

// GF2P8AFFINEQB xmm1, xmm2/m128, imm8
val exec_gf2p8affineqb : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_gf2p8affineqb(dst, src, imm8) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  write_xmm_legacy(dst, __gf2p8affineqb(a, b, imm8));
  Ok(())
}

// GF2P8MULB xmm1, xmm2/m128
val exec_gf2p8mulb : (simd_idx, xmmword) -> ExecutionResult
function exec_gf2p8mulb(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  write_xmm_legacy(dst, __gf2p8mulb(a, b));
  Ok(())
}

// VINSERTF128/VINSERTF32x4/VINSERTF64x2/VINSERTF32x8/VINSERTF64x4 — Insert Packed FP Values
// VINSERTI128/VINSERTI32x4/VINSERTI64x2/VINSERTI32x8/VINSERTI64x4 — Insert Packed Integer Values
//
// These instructions insert a 128-bit or 256-bit source operand into a
// specified position within a 256-bit or 512-bit destination, controlled
// by an immediate byte. AVX/AVX-512 with no YMM/ZMM infrastructure modeled.
// No flags affected.

// External insert primitives — floating-point variants
val __vinsertf128 : (ymmword, xmmword, byte) -> ymmword
val __vinsertf32x4_ymm : (ymmword, xmmword, byte) -> ymmword
val __vinsertf32x4_zmm : (zmmword, xmmword, byte) -> zmmword
val __vinsertf64x2_ymm : (ymmword, xmmword, byte) -> ymmword
val __vinsertf64x2_zmm : (zmmword, xmmword, byte) -> zmmword
val __vinsertf32x8 : (zmmword, ymmword, byte) -> zmmword
val __vinsertf64x4 : (zmmword, ymmword, byte) -> zmmword

// External insert primitives — integer variants
val __vinserti128 : (ymmword, xmmword, byte) -> ymmword
val __vinserti32x4_ymm : (ymmword, xmmword, byte) -> ymmword
val __vinserti32x4_zmm : (zmmword, xmmword, byte) -> zmmword
val __vinserti64x2_ymm : (ymmword, xmmword, byte) -> ymmword
val __vinserti64x2_zmm : (zmmword, xmmword, byte) -> zmmword
val __vinserti32x8 : (zmmword, ymmword, byte) -> zmmword
val __vinserti64x4 : (zmmword, ymmword, byte) -> zmmword

// =========================================================================
// Floating-point insert variants
// =========================================================================

// VINSERTF128 — Insert 128-bit into 256-bit (VEX.256)
val exec_vinsertf128 : (simd_idx, simd_idx, xmmword, byte) -> ExecutionResult
function exec_vinsertf128(dst, src1, src2, imm8) = {
  let a : ymmword = read_ymm(src1);
  let b : xmmword = src2;
  write_ymm(dst, __vinsertf128(a, b, imm8));
  Ok(())
}

// VINSERTF32x4 — Insert 128-bit as 32-bit FP elements (EVEX.256)
val exec_vinsertf32x4_ymm : (simd_idx, simd_idx, xmmword, byte) -> ExecutionResult
function exec_vinsertf32x4_ymm(dst, src1, src2, imm8) = {
  let a : ymmword = read_ymm(src1);
  let b : xmmword = src2;
  write_ymm(dst, __vinsertf32x4_ymm(a, b, imm8));
  Ok(())
}

// VINSERTF32x4 — Insert 128-bit as 32-bit FP elements (EVEX.512)
val exec_vinsertf32x4_zmm : (simd_idx, simd_idx, xmmword, byte) -> ExecutionResult
function exec_vinsertf32x4_zmm(dst, src1, src2, imm8) = {
  let a : zmmword = read_zmm(src1);
  let b : xmmword = src2;
  write_zmm(dst, __vinsertf32x4_zmm(a, b, imm8));
  Ok(())
}

// VINSERTF64x2 — Insert 128-bit as 64-bit FP elements (EVEX.256)
val exec_vinsertf64x2_ymm : (simd_idx, simd_idx, xmmword, byte) -> ExecutionResult
function exec_vinsertf64x2_ymm(dst, src1, src2, imm8) = {
  let a : ymmword = read_ymm(src1);
  let b : xmmword = src2;
  write_ymm(dst, __vinsertf64x2_ymm(a, b, imm8));
  Ok(())
}

// VINSERTF64x2 — Insert 128-bit as 64-bit FP elements (EVEX.512)
val exec_vinsertf64x2_zmm : (simd_idx, simd_idx, xmmword, byte) -> ExecutionResult
function exec_vinsertf64x2_zmm(dst, src1, src2, imm8) = {
  let a : zmmword = read_zmm(src1);
  let b : xmmword = src2;
  write_zmm(dst, __vinsertf64x2_zmm(a, b, imm8));
  Ok(())
}

// VINSERTF32x8 — Insert 256-bit as 32-bit FP elements (EVEX.512)
val exec_vinsertf32x8 : (simd_idx, simd_idx, simd_idx, byte) -> ExecutionResult
function exec_vinsertf32x8(dst, src1, src2, imm8) = {
  let a : zmmword = read_zmm(src1);
  let b : ymmword = read_ymm(src2);
  write_zmm(dst, __vinsertf32x8(a, b, imm8));
  Ok(())
}

// VINSERTF64x4 — Insert 256-bit as 64-bit FP elements (EVEX.512)
val exec_vinsertf64x4 : (simd_idx, simd_idx, simd_idx, byte) -> ExecutionResult
function exec_vinsertf64x4(dst, src1, src2, imm8) = {
  let a : zmmword = read_zmm(src1);
  let b : ymmword = read_ymm(src2);
  write_zmm(dst, __vinsertf64x4(a, b, imm8));
  Ok(())
}

// =========================================================================
// Integer insert variants
// =========================================================================

// VINSERTI128 — Insert 128-bit into 256-bit (VEX.256)
val exec_vinserti128 : (simd_idx, simd_idx, xmmword, byte) -> ExecutionResult
function exec_vinserti128(dst, src1, src2, imm8) = {
  let a : ymmword = read_ymm(src1);
  let b : xmmword = src2;
  write_ymm(dst, __vinserti128(a, b, imm8));
  Ok(())
}

// VINSERTI32x4 — Insert 128-bit as 32-bit integer elements (EVEX.256)
val exec_vinserti32x4_ymm : (simd_idx, simd_idx, xmmword, byte) -> ExecutionResult
function exec_vinserti32x4_ymm(dst, src1, src2, imm8) = {
  let a : ymmword = read_ymm(src1);
  let b : xmmword = src2;
  write_ymm(dst, __vinserti32x4_ymm(a, b, imm8));
  Ok(())
}

// VINSERTI32x4 — Insert 128-bit as 32-bit integer elements (EVEX.512)
val exec_vinserti32x4_zmm : (simd_idx, simd_idx, xmmword, byte) -> ExecutionResult
function exec_vinserti32x4_zmm(dst, src1, src2, imm8) = {
  let a : zmmword = read_zmm(src1);
  let b : xmmword = src2;
  write_zmm(dst, __vinserti32x4_zmm(a, b, imm8));
  Ok(())
}

// VINSERTI64x2 — Insert 128-bit as 64-bit integer elements (EVEX.256)
val exec_vinserti64x2_ymm : (simd_idx, simd_idx, xmmword, byte) -> ExecutionResult
function exec_vinserti64x2_ymm(dst, src1, src2, imm8) = {
  let a : ymmword = read_ymm(src1);
  let b : xmmword = src2;
  write_ymm(dst, __vinserti64x2_ymm(a, b, imm8));
  Ok(())
}

// VINSERTI64x2 — Insert 128-bit as 64-bit integer elements (EVEX.512)
val exec_vinserti64x2_zmm : (simd_idx, simd_idx, xmmword, byte) -> ExecutionResult
function exec_vinserti64x2_zmm(dst, src1, src2, imm8) = {
  let a : zmmword = read_zmm(src1);
  let b : xmmword = src2;
  write_zmm(dst, __vinserti64x2_zmm(a, b, imm8));
  Ok(())
}

// VINSERTI32x8 — Insert 256-bit as 32-bit integer elements (EVEX.512)
val exec_vinserti32x8 : (simd_idx, simd_idx, simd_idx, byte) -> ExecutionResult
function exec_vinserti32x8(dst, src1, src2, imm8) = {
  let a : zmmword = read_zmm(src1);
  let b : ymmword = read_ymm(src2);
  write_zmm(dst, __vinserti32x8(a, b, imm8));
  Ok(())
}

// VINSERTI64x4 — Insert 256-bit as 64-bit integer elements (EVEX.512)
val exec_vinserti64x4 : (simd_idx, simd_idx, simd_idx, byte) -> ExecutionResult
function exec_vinserti64x4(dst, src1, src2, imm8) = {
  let a : zmmword = read_zmm(src1);
  let b : ymmword = read_ymm(src2);
  write_zmm(dst, __vinserti64x4(a, b, imm8));
  Ok(())
}

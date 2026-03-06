// VMULPH — Multiply Packed FP16 Values
// VMULSH — Multiply Scalar FP16 Values
// VMOVSH — Move Scalar FP16 Value
// VMOVW — Move Word (FP16 load/store/move)
//
// AVX-512 FP16 instructions modeled as external functions.
// No flags affected.

// =========================================================================
// VMULPH — Multiply Packed FP16 Values (AVX-512 FP16)
// =========================================================================

val __vmulph_xmm : (xmmword, xmmword) -> xmmword
val __vmulph_ymm : (ymmword, ymmword) -> ymmword
val __vmulph_zmm : (zmmword, zmmword) -> zmmword

// VMULPH (EVEX.128): xmm1 {k1}{z} := xmm2 * xmm3/m128
val exec_vmulph_xmm : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vmulph_xmm(dst, src1, src2) = {
  let a : xmmword = src1;
  let b : xmmword = src2;
  write_xmm(dst, __vmulph_xmm(a, b));
  Ok(())
}

// VMULPH (EVEX.256): ymm1 {k1}{z} := ymm2 * ymm3/m256
val exec_vmulph_ymm : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_vmulph_ymm(dst, src1, src2) = {
  let a : ymmword = read_ymm(src1);
  let b : ymmword = read_ymm(src2);
  write_ymm(dst, __vmulph_ymm(a, b));
  Ok(())
}

// VMULPH (EVEX.512): zmm1 {k1}{z} := zmm2 * zmm3/m512
val exec_vmulph_zmm : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_vmulph_zmm(dst, src1, src2) = {
  let a : zmmword = read_zmm(src1);
  let b : zmmword = read_zmm(src2);
  write_zmm(dst, __vmulph_zmm(a, b));
  Ok(())
}

// =========================================================================
// VMULSH — Multiply Scalar FP16 Values (AVX-512 FP16)
// =========================================================================

val __vmulsh : (xmmword, xmmword) -> xmmword

// VMULSH (EVEX.128): xmm1 {k1}{z} := xmm2[15:0] * xmm3/m16[15:0]
val exec_vmulsh : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vmulsh(dst, src1, src2) = {
  let a : xmmword = src1;
  let b : xmmword = src2;
  write_xmm(dst, __vmulsh(a, b));
  Ok(())
}

// =========================================================================
// VMOVSH — Move Scalar FP16 Value (AVX-512 FP16)
// =========================================================================

// VMOVSH xmm1 {k1}{z}, xmm2, xmm3 — register-to-register move
// Moves lowest FP16 from xmm3 to xmm1, with upper bits from xmm2.
val exec_vmovsh_reg : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vmovsh_reg(dst, src1, src2) = {
  let a : xmmword = src1;
  let b : xmmword = src2;
  let result : xmmword = a[127..16] @ b[15..0];
  write_xmm(dst, result);
  Ok(())
}

// VMOVSH xmm1 {k1}{z}, m16 — load scalar FP16 from memory
// Loads 16-bit FP value from memory into lowest element, zeroes upper bits.
val exec_vmovsh_load : (simd_idx, word) -> ExecutionResult
function exec_vmovsh_load(dst, mem_val) = {
  let result : xmmword = zeros();
  write_xmm(dst, result[127..16] @ mem_val);
  Ok(())
}

// VMOVSH m16, xmm1 — store scalar FP16 to memory
// Stores lowest 16-bit FP element to memory.
val exec_vmovsh_store : xmmword -> (ExecutionResult, word)
function exec_vmovsh_store(src) = {
  let v : xmmword = src;
  (Ok(()), v[15..0])
}

// =========================================================================
// VMOVW — Move Word (AVX-512 FP16)
// =========================================================================

// VMOVW xmm1, r32/m16 — load 16-bit value into lowest element
val exec_vmovw_load : (simd_idx, word) -> ExecutionResult
function exec_vmovw_load(dst, val16) = {
  let result : xmmword = zeros();
  write_xmm(dst, result[127..16] @ val16);
  Ok(())
}

// VMOVW r32/m16, xmm1 — store lowest 16-bit element
val exec_vmovw_store : xmmword -> (ExecutionResult, word)
function exec_vmovw_store(src) = {
  let v : xmmword = src;
  (Ok(()), v[15..0])
}

// VMOVW xmm1, xmm2 — register-to-register (move low word, zero upper)
val exec_vmovw_reg : (simd_idx, xmmword) -> ExecutionResult
function exec_vmovw_reg(dst, src) = {
  let v : xmmword = src;
  let result : xmmword = zeros();
  write_xmm(dst, result[127..16] @ v[15..0]);
  Ok(())
}

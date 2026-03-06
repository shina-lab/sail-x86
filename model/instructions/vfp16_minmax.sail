// VMASKMOV — Conditional SIMD Packed Loads and Stores
// VMAXPH — Maximum of Packed FP16 Values
// VMAXSH — Maximum of Scalar FP16 Values
// VMINPH — Minimum of Packed FP16 Values
// VMINSH — Minimum of Scalar FP16 Values
//
// VMASKMOV is an AVX instruction for conditional packed loads/stores.
// VMAXPH/VMAXSH/VMINPH/VMINSH are AVX-512 FP16 instructions.
// All modeled as external functions (no YMM/ZMM infrastructure).
// No flags affected.

// =========================================================================
// VMASKMOV — Conditional SIMD Packed Loads and Stores (AVX)
// =========================================================================

// External VMASKMOV primitives
val __vmaskmovps_load_xmm : (xmmword, xmmword) -> xmmword
val __vmaskmovps_load_ymm : (ymmword, ymmword) -> ymmword
val __vmaskmovpd_load_xmm : (xmmword, xmmword) -> xmmword
val __vmaskmovpd_load_ymm : (ymmword, ymmword) -> ymmword
val __vmaskmovps_store_xmm : (xmmword, xmmword, xmmword) -> xmmword
val __vmaskmovps_store_ymm : (ymmword, ymmword, ymmword) -> ymmword
val __vmaskmovpd_store_xmm : (xmmword, xmmword, xmmword) -> xmmword
val __vmaskmovpd_store_ymm : (ymmword, ymmword, ymmword) -> ymmword

// VMASKMOVPS — Load (VEX.128): xmm1 := conditional load from m128 using xmm2 mask
val exec_vmaskmovps_load_xmm : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vmaskmovps_load_xmm(dst, mask_reg, mem_val) = {
  let mask : xmmword = mask_reg;
  write_xmm(dst, __vmaskmovps_load_xmm(mask, mem_val));
  Ok(())
}

// VMASKMOVPS — Load (VEX.256): ymm1 := conditional load from m256 using ymm2 mask
val exec_vmaskmovps_load_ymm : (simd_idx, simd_idx, ymmword) -> ExecutionResult
function exec_vmaskmovps_load_ymm(dst, mask_reg, mem_val) = {
  let mask : ymmword = read_ymm(mask_reg);
  write_ymm(dst, __vmaskmovps_load_ymm(mask, mem_val));
  Ok(())
}

// VMASKMOVPD — Load (VEX.128): xmm1 := conditional load from m128 using xmm2 mask
val exec_vmaskmovpd_load_xmm : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vmaskmovpd_load_xmm(dst, mask_reg, mem_val) = {
  let mask : xmmword = mask_reg;
  write_xmm(dst, __vmaskmovpd_load_xmm(mask, mem_val));
  Ok(())
}

// VMASKMOVPD — Load (VEX.256): ymm1 := conditional load from m256 using ymm2 mask
val exec_vmaskmovpd_load_ymm : (simd_idx, simd_idx, ymmword) -> ExecutionResult
function exec_vmaskmovpd_load_ymm(dst, mask_reg, mem_val) = {
  let mask : ymmword = read_ymm(mask_reg);
  write_ymm(dst, __vmaskmovpd_load_ymm(mask, mem_val));
  Ok(())
}

// VMASKMOVPS — Store (VEX.128): conditional store xmm1 to m128 using xmm2 mask
val exec_vmaskmovps_store_xmm : (xmmword, xmmword) -> (ExecutionResult, xmmword)
function exec_vmaskmovps_store_xmm(mask_reg, src) = {
  let mask : xmmword = mask_reg;
  let data : xmmword = src;
  (Ok(()), __vmaskmovps_store_xmm(mask, data, zeros()))
}

// VMASKMOVPS — Store (VEX.256): conditional store ymm1 to m256 using ymm2 mask
val exec_vmaskmovps_store_ymm : (simd_idx, simd_idx) -> (ExecutionResult, ymmword)
function exec_vmaskmovps_store_ymm(mask_reg, src) = {
  let mask : ymmword = read_ymm(mask_reg);
  let data : ymmword = read_ymm(src);
  (Ok(()), __vmaskmovps_store_ymm(mask, data, zeros()))
}

// VMASKMOVPD — Store (VEX.128): conditional store xmm1 to m128 using xmm2 mask
val exec_vmaskmovpd_store_xmm : (xmmword, xmmword) -> (ExecutionResult, xmmword)
function exec_vmaskmovpd_store_xmm(mask_reg, src) = {
  let mask : xmmword = mask_reg;
  let data : xmmword = src;
  (Ok(()), __vmaskmovpd_store_xmm(mask, data, zeros()))
}

// VMASKMOVPD — Store (VEX.256): conditional store ymm1 to m256 using ymm2 mask
val exec_vmaskmovpd_store_ymm : (simd_idx, simd_idx) -> (ExecutionResult, ymmword)
function exec_vmaskmovpd_store_ymm(mask_reg, src) = {
  let mask : ymmword = read_ymm(mask_reg);
  let data : ymmword = read_ymm(src);
  (Ok(()), __vmaskmovpd_store_ymm(mask, data, zeros()))
}

// =========================================================================
// VMAXPH — Maximum of Packed FP16 Values (AVX-512 FP16)
// =========================================================================

val __vmaxph_xmm : (xmmword, xmmword) -> xmmword
val __vmaxph_ymm : (ymmword, ymmword) -> ymmword
val __vmaxph_zmm : (zmmword, zmmword) -> zmmword

// VMAXPH (EVEX.128): xmm1 {k1}{z} := MAX(xmm2, xmm3/m128)
val exec_vmaxph_xmm : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vmaxph_xmm(dst, src1, src2) = {
  let a : xmmword = src1;
  let b : xmmword = src2;
  write_xmm(dst, __vmaxph_xmm(a, b));
  Ok(())
}

// VMAXPH (EVEX.256): ymm1 {k1}{z} := MAX(ymm2, ymm3/m256)
val exec_vmaxph_ymm : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_vmaxph_ymm(dst, src1, src2) = {
  let a : ymmword = read_ymm(src1);
  let b : ymmword = read_ymm(src2);
  write_ymm(dst, __vmaxph_ymm(a, b));
  Ok(())
}

// VMAXPH (EVEX.512): zmm1 {k1}{z} := MAX(zmm2, zmm3/m512)
val exec_vmaxph_zmm : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_vmaxph_zmm(dst, src1, src2) = {
  let a : zmmword = read_zmm(src1);
  let b : zmmword = read_zmm(src2);
  write_zmm(dst, __vmaxph_zmm(a, b));
  Ok(())
}

// =========================================================================
// VMAXSH — Maximum of Scalar FP16 Values (AVX-512 FP16)
// =========================================================================

val __vmaxsh : (xmmword, xmmword) -> xmmword

// VMAXSH (EVEX.128): xmm1 {k1}{z} := MAX(xmm2[15:0], xmm3/m16[15:0])
val exec_vmaxsh : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vmaxsh(dst, src1, src2) = {
  let a : xmmword = src1;
  let b : xmmword = src2;
  write_xmm(dst, __vmaxsh(a, b));
  Ok(())
}

// =========================================================================
// VMINPH — Minimum of Packed FP16 Values (AVX-512 FP16)
// =========================================================================

val __vminph_xmm : (xmmword, xmmword) -> xmmword
val __vminph_ymm : (ymmword, ymmword) -> ymmword
val __vminph_zmm : (zmmword, zmmword) -> zmmword

// VMINPH (EVEX.128): xmm1 {k1}{z} := MIN(xmm2, xmm3/m128)
val exec_vminph_xmm : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vminph_xmm(dst, src1, src2) = {
  let a : xmmword = src1;
  let b : xmmword = src2;
  write_xmm(dst, __vminph_xmm(a, b));
  Ok(())
}

// VMINPH (EVEX.256): ymm1 {k1}{z} := MIN(ymm2, ymm3/m256)
val exec_vminph_ymm : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_vminph_ymm(dst, src1, src2) = {
  let a : ymmword = read_ymm(src1);
  let b : ymmword = read_ymm(src2);
  write_ymm(dst, __vminph_ymm(a, b));
  Ok(())
}

// VMINPH (EVEX.512): zmm1 {k1}{z} := MIN(zmm2, zmm3/m512)
val exec_vminph_zmm : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_vminph_zmm(dst, src1, src2) = {
  let a : zmmword = read_zmm(src1);
  let b : zmmword = read_zmm(src2);
  write_zmm(dst, __vminph_zmm(a, b));
  Ok(())
}

// =========================================================================
// VMINSH — Minimum of Scalar FP16 Values (AVX-512 FP16)
// =========================================================================

val __vminsh : (xmmword, xmmword) -> xmmword

// VMINSH (EVEX.128): xmm1 {k1}{z} := MIN(xmm2[15:0], xmm3/m16[15:0])
val exec_vminsh : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vminsh(dst, src1, src2) = {
  let a : xmmword = src1;
  let b : xmmword = src2;
  write_xmm(dst, __vminsh(a, b));
  Ok(())
}

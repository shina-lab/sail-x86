// VPCMPB/VPCMPUB — Compare Packed Byte Values into Mask
// VPCMPD/VPCMPUD — Compare Packed Dword Values into Mask
// VPCMPQ/VPCMPUQ — Compare Packed Qword Values into Mask
// VPCMPW/VPCMPUW — Compare Packed Word Values into Mask
//
// AVX-512 packed compare instructions that write results to opmask registers.
// The imm8 operand selects the comparison predicate.
// Signed variants: VPCMPB, VPCMPD, VPCMPQ, VPCMPW
// Unsigned variants: VPCMPUB, VPCMPUD, VPCMPUQ, VPCMPUW
// All modeled as external functions. No flags affected.

// =========================================================================
// VPCMPB/VPCMPUB — Compare Packed Bytes (AVX-512)
// =========================================================================

val __vpcmpb_xmm : (xmmword, xmmword, byte) -> word
val __vpcmpb_ymm : (ymmword, ymmword, byte) -> dword
val __vpcmpb_zmm : (zmmword, zmmword, byte) -> qword
val __vpcmpub_xmm : (xmmword, xmmword, byte) -> word
val __vpcmpub_ymm : (ymmword, ymmword, byte) -> dword
val __vpcmpub_zmm : (zmmword, zmmword, byte) -> qword

// VPCMPB (EVEX.128): k1 := compare(xmm2, xmm3/m128, imm8)
val exec_vpcmpb_xmm : (xmmword, xmmword, byte) -> (ExecutionResult, word)
function exec_vpcmpb_xmm(src1, src2, imm8) = {
  let a : xmmword = src1;
  let b : xmmword = src2;
  (Ok(()), __vpcmpb_xmm(a, b, imm8))
}

// VPCMPB (EVEX.256): k1 := compare(ymm2, ymm3/m256, imm8)
val exec_vpcmpb_ymm : (simd_idx, simd_idx, byte) -> (ExecutionResult, dword)
function exec_vpcmpb_ymm(src1, src2, imm8) = {
  let a : ymmword = read_ymm(src1);
  let b : ymmword = read_ymm(src2);
  (Ok(()), __vpcmpb_ymm(a, b, imm8))
}

// VPCMPB (EVEX.512): k1 := compare(zmm2, zmm3/m512, imm8)
val exec_vpcmpb_zmm : (simd_idx, simd_idx, byte) -> (ExecutionResult, qword)
function exec_vpcmpb_zmm(src1, src2, imm8) = {
  let a : zmmword = read_zmm(src1);
  let b : zmmword = read_zmm(src2);
  (Ok(()), __vpcmpb_zmm(a, b, imm8))
}

// VPCMPUB (EVEX.128): k1 := unsigned compare(xmm2, xmm3/m128, imm8)
val exec_vpcmpub_xmm : (xmmword, xmmword, byte) -> (ExecutionResult, word)
function exec_vpcmpub_xmm(src1, src2, imm8) = {
  let a : xmmword = src1;
  let b : xmmword = src2;
  (Ok(()), __vpcmpub_xmm(a, b, imm8))
}

// VPCMPUB (EVEX.256): k1 := unsigned compare(ymm2, ymm3/m256, imm8)
val exec_vpcmpub_ymm : (simd_idx, simd_idx, byte) -> (ExecutionResult, dword)
function exec_vpcmpub_ymm(src1, src2, imm8) = {
  let a : ymmword = read_ymm(src1);
  let b : ymmword = read_ymm(src2);
  (Ok(()), __vpcmpub_ymm(a, b, imm8))
}

// VPCMPUB (EVEX.512): k1 := unsigned compare(zmm2, zmm3/m512, imm8)
val exec_vpcmpub_zmm : (simd_idx, simd_idx, byte) -> (ExecutionResult, qword)
function exec_vpcmpub_zmm(src1, src2, imm8) = {
  let a : zmmword = read_zmm(src1);
  let b : zmmword = read_zmm(src2);
  (Ok(()), __vpcmpub_zmm(a, b, imm8))
}

// =========================================================================
// VPCMPD/VPCMPUD — Compare Packed Dwords (AVX-512)
// =========================================================================

val __vpcmpd_xmm : (xmmword, xmmword, byte) -> byte
val __vpcmpd_ymm : (ymmword, ymmword, byte) -> byte
val __vpcmpd_zmm : (zmmword, zmmword, byte) -> word
val __vpcmpud_xmm : (xmmword, xmmword, byte) -> byte
val __vpcmpud_ymm : (ymmword, ymmword, byte) -> byte
val __vpcmpud_zmm : (zmmword, zmmword, byte) -> word

// VPCMPD (EVEX.128): k1 := compare(xmm2, xmm3/m128, imm8)
val exec_vpcmpd_xmm : (xmmword, xmmword, byte) -> (ExecutionResult, byte)
function exec_vpcmpd_xmm(src1, src2, imm8) = {
  let a : xmmword = src1;
  let b : xmmword = src2;
  (Ok(()), __vpcmpd_xmm(a, b, imm8))
}

// VPCMPD (EVEX.256): k1 := compare(ymm2, ymm3/m256, imm8)
val exec_vpcmpd_ymm : (simd_idx, simd_idx, byte) -> (ExecutionResult, byte)
function exec_vpcmpd_ymm(src1, src2, imm8) = {
  let a : ymmword = read_ymm(src1);
  let b : ymmword = read_ymm(src2);
  (Ok(()), __vpcmpd_ymm(a, b, imm8))
}

// VPCMPD (EVEX.512): k1 := compare(zmm2, zmm3/m512, imm8)
val exec_vpcmpd_zmm : (simd_idx, simd_idx, byte) -> (ExecutionResult, word)
function exec_vpcmpd_zmm(src1, src2, imm8) = {
  let a : zmmword = read_zmm(src1);
  let b : zmmword = read_zmm(src2);
  (Ok(()), __vpcmpd_zmm(a, b, imm8))
}

// VPCMPUD (EVEX.128): k1 := unsigned compare(xmm2, xmm3/m128, imm8)
val exec_vpcmpud_xmm : (xmmword, xmmword, byte) -> (ExecutionResult, byte)
function exec_vpcmpud_xmm(src1, src2, imm8) = {
  let a : xmmword = src1;
  let b : xmmword = src2;
  (Ok(()), __vpcmpud_xmm(a, b, imm8))
}

// VPCMPUD (EVEX.256): k1 := unsigned compare(ymm2, ymm3/m256, imm8)
val exec_vpcmpud_ymm : (simd_idx, simd_idx, byte) -> (ExecutionResult, byte)
function exec_vpcmpud_ymm(src1, src2, imm8) = {
  let a : ymmword = read_ymm(src1);
  let b : ymmword = read_ymm(src2);
  (Ok(()), __vpcmpud_ymm(a, b, imm8))
}

// VPCMPUD (EVEX.512): k1 := unsigned compare(zmm2, zmm3/m512, imm8)
val exec_vpcmpud_zmm : (simd_idx, simd_idx, byte) -> (ExecutionResult, word)
function exec_vpcmpud_zmm(src1, src2, imm8) = {
  let a : zmmword = read_zmm(src1);
  let b : zmmword = read_zmm(src2);
  (Ok(()), __vpcmpud_zmm(a, b, imm8))
}

// =========================================================================
// VPCMPQ/VPCMPUQ — Compare Packed Qwords (AVX-512)
// =========================================================================

val __vpcmpq_xmm : (xmmword, xmmword, byte) -> byte
val __vpcmpq_ymm : (ymmword, ymmword, byte) -> byte
val __vpcmpq_zmm : (zmmword, zmmword, byte) -> byte
val __vpcmpuq_xmm : (xmmword, xmmword, byte) -> byte
val __vpcmpuq_ymm : (ymmword, ymmword, byte) -> byte
val __vpcmpuq_zmm : (zmmword, zmmword, byte) -> byte

// VPCMPQ (EVEX.128): k1 := compare(xmm2, xmm3/m128, imm8)
val exec_vpcmpq_xmm : (xmmword, xmmword, byte) -> (ExecutionResult, byte)
function exec_vpcmpq_xmm(src1, src2, imm8) = {
  let a : xmmword = src1;
  let b : xmmword = src2;
  (Ok(()), __vpcmpq_xmm(a, b, imm8))
}

// VPCMPQ (EVEX.256): k1 := compare(ymm2, ymm3/m256, imm8)
val exec_vpcmpq_ymm : (simd_idx, simd_idx, byte) -> (ExecutionResult, byte)
function exec_vpcmpq_ymm(src1, src2, imm8) = {
  let a : ymmword = read_ymm(src1);
  let b : ymmword = read_ymm(src2);
  (Ok(()), __vpcmpq_ymm(a, b, imm8))
}

// VPCMPQ (EVEX.512): k1 := compare(zmm2, zmm3/m512, imm8)
val exec_vpcmpq_zmm : (simd_idx, simd_idx, byte) -> (ExecutionResult, byte)
function exec_vpcmpq_zmm(src1, src2, imm8) = {
  let a : zmmword = read_zmm(src1);
  let b : zmmword = read_zmm(src2);
  (Ok(()), __vpcmpq_zmm(a, b, imm8))
}

// VPCMPUQ (EVEX.128): k1 := unsigned compare(xmm2, xmm3/m128, imm8)
val exec_vpcmpuq_xmm : (xmmword, xmmword, byte) -> (ExecutionResult, byte)
function exec_vpcmpuq_xmm(src1, src2, imm8) = {
  let a : xmmword = src1;
  let b : xmmword = src2;
  (Ok(()), __vpcmpuq_xmm(a, b, imm8))
}

// VPCMPUQ (EVEX.256): k1 := unsigned compare(ymm2, ymm3/m256, imm8)
val exec_vpcmpuq_ymm : (simd_idx, simd_idx, byte) -> (ExecutionResult, byte)
function exec_vpcmpuq_ymm(src1, src2, imm8) = {
  let a : ymmword = read_ymm(src1);
  let b : ymmword = read_ymm(src2);
  (Ok(()), __vpcmpuq_ymm(a, b, imm8))
}

// VPCMPUQ (EVEX.512): k1 := unsigned compare(zmm2, zmm3/m512, imm8)
val exec_vpcmpuq_zmm : (simd_idx, simd_idx, byte) -> (ExecutionResult, byte)
function exec_vpcmpuq_zmm(src1, src2, imm8) = {
  let a : zmmword = read_zmm(src1);
  let b : zmmword = read_zmm(src2);
  (Ok(()), __vpcmpuq_zmm(a, b, imm8))
}

// =========================================================================
// VPCMPW/VPCMPUW — Compare Packed Words (AVX-512)
// =========================================================================

val __vpcmpw_xmm : (xmmword, xmmword, byte) -> byte
val __vpcmpw_ymm : (ymmword, ymmword, byte) -> word
val __vpcmpw_zmm : (zmmword, zmmword, byte) -> dword
val __vpcmpuw_xmm : (xmmword, xmmword, byte) -> byte
val __vpcmpuw_ymm : (ymmword, ymmword, byte) -> word
val __vpcmpuw_zmm : (zmmword, zmmword, byte) -> dword

// VPCMPW (EVEX.128): k1 := compare(xmm2, xmm3/m128, imm8)
val exec_vpcmpw_xmm : (xmmword, xmmword, byte) -> (ExecutionResult, byte)
function exec_vpcmpw_xmm(src1, src2, imm8) = {
  let a : xmmword = src1;
  let b : xmmword = src2;
  (Ok(()), __vpcmpw_xmm(a, b, imm8))
}

// VPCMPW (EVEX.256): k1 := compare(ymm2, ymm3/m256, imm8)
val exec_vpcmpw_ymm : (simd_idx, simd_idx, byte) -> (ExecutionResult, word)
function exec_vpcmpw_ymm(src1, src2, imm8) = {
  let a : ymmword = read_ymm(src1);
  let b : ymmword = read_ymm(src2);
  (Ok(()), __vpcmpw_ymm(a, b, imm8))
}

// VPCMPW (EVEX.512): k1 := compare(zmm2, zmm3/m512, imm8)
val exec_vpcmpw_zmm : (simd_idx, simd_idx, byte) -> (ExecutionResult, dword)
function exec_vpcmpw_zmm(src1, src2, imm8) = {
  let a : zmmword = read_zmm(src1);
  let b : zmmword = read_zmm(src2);
  (Ok(()), __vpcmpw_zmm(a, b, imm8))
}

// VPCMPUW (EVEX.128): k1 := unsigned compare(xmm2, xmm3/m128, imm8)
val exec_vpcmpuw_xmm : (xmmword, xmmword, byte) -> (ExecutionResult, byte)
function exec_vpcmpuw_xmm(src1, src2, imm8) = {
  let a : xmmword = src1;
  let b : xmmword = src2;
  (Ok(()), __vpcmpuw_xmm(a, b, imm8))
}

// VPCMPUW (EVEX.256): k1 := unsigned compare(ymm2, ymm3/m256, imm8)
val exec_vpcmpuw_ymm : (simd_idx, simd_idx, byte) -> (ExecutionResult, word)
function exec_vpcmpuw_ymm(src1, src2, imm8) = {
  let a : ymmword = read_ymm(src1);
  let b : ymmword = read_ymm(src2);
  (Ok(()), __vpcmpuw_ymm(a, b, imm8))
}

// VPCMPUW (EVEX.512): k1 := unsigned compare(zmm2, zmm3/m512, imm8)
val exec_vpcmpuw_zmm : (simd_idx, simd_idx, byte) -> (ExecutionResult, dword)
function exec_vpcmpuw_zmm(src1, src2, imm8) = {
  let a : zmmword = read_zmm(src1);
  let b : zmmword = read_zmm(src2);
  (Ok(()), __vpcmpuw_zmm(a, b, imm8))
}

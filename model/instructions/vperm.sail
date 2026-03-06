// VPERM2F128 — Permute Floating-Point Values (AVX)
// VPERM2I128 — Permute Integer Values (AVX2)
// VPERMB — Permute Packed Bytes (AVX-512 VBMI)
// VPERMD/VPERMW — Permute Packed Dwords/Words (AVX2/AVX-512)
// VPERMI2B — Full Permute of Bytes from Two Tables (AVX-512 VBMI)
// VPERMI2W/VPERMI2D/VPERMI2Q/VPERMI2PS/VPERMI2PD — Full Permute from Two Tables
// VPERMILPD — Permute In-Lane Double-Precision FP (AVX)
// VPERMILPS — Permute In-Lane Single-Precision FP (AVX)
// VPERMPD — Permute Double-Precision FP (AVX2/AVX-512)
// VPERMPS — Permute Single-Precision FP (AVX2/AVX-512)
// VPERMQ — Permute Quadwords (AVX2/AVX-512)
//
// All modeled as external functions. No flags affected.

// =========================================================================
// VPERM2F128 — Permute 128-bit FP lanes (VEX.256)
// =========================================================================

val __vperm2f128 : (ymmword, ymmword, byte) -> ymmword

val exec_vperm2f128 : (simd_idx, simd_idx, simd_idx, byte) -> ExecutionResult
function exec_vperm2f128(dst, src1, src2, imm8) = {
  let a : ymmword = read_ymm(src1);
  let b : ymmword = read_ymm(src2);
  write_ymm(dst, __vperm2f128(a, b, imm8));
  Ok(())
}

// =========================================================================
// VPERM2I128 — Permute 128-bit integer lanes (VEX.256)
// =========================================================================

val __vperm2i128 : (ymmword, ymmword, byte) -> ymmword

val exec_vperm2i128 : (simd_idx, simd_idx, simd_idx, byte) -> ExecutionResult
function exec_vperm2i128(dst, src1, src2, imm8) = {
  let a : ymmword = read_ymm(src1);
  let b : ymmword = read_ymm(src2);
  write_ymm(dst, __vperm2i128(a, b, imm8));
  Ok(())
}

// =========================================================================
// VPERMB — Permute Packed Bytes (AVX-512 VBMI)
// =========================================================================

val __vpermb_xmm : (xmmword, xmmword) -> xmmword
val __vpermb_ymm : (ymmword, ymmword) -> ymmword
val __vpermb_zmm : (zmmword, zmmword) -> zmmword

val exec_vpermb_xmm : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vpermb_xmm(dst, idx_reg, src) = {
  let idx : xmmword = idx_reg;
  let s : xmmword = src;
  write_xmm(dst, __vpermb_xmm(idx, s));
  Ok(())
}

val exec_vpermb_ymm : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_vpermb_ymm(dst, idx_reg, src) = {
  let idx : ymmword = read_ymm(idx_reg);
  let s : ymmword = read_ymm(src);
  write_ymm(dst, __vpermb_ymm(idx, s));
  Ok(())
}

val exec_vpermb_zmm : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_vpermb_zmm(dst, idx_reg, src) = {
  let idx : zmmword = read_zmm(idx_reg);
  let s : zmmword = read_zmm(src);
  write_zmm(dst, __vpermb_zmm(idx, s));
  Ok(())
}

// =========================================================================
// VPERMD — Permute Packed Dwords (AVX2/AVX-512)
// =========================================================================

val __vpermd_ymm : (ymmword, ymmword) -> ymmword
val __vpermd_zmm : (zmmword, zmmword) -> zmmword

val exec_vpermd_ymm : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_vpermd_ymm(dst, idx_reg, src) = {
  let idx : ymmword = read_ymm(idx_reg);
  let s : ymmword = read_ymm(src);
  write_ymm(dst, __vpermd_ymm(idx, s));
  Ok(())
}

val exec_vpermd_zmm : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_vpermd_zmm(dst, idx_reg, src) = {
  let idx : zmmword = read_zmm(idx_reg);
  let s : zmmword = read_zmm(src);
  write_zmm(dst, __vpermd_zmm(idx, s));
  Ok(())
}

// =========================================================================
// VPERMW — Permute Packed Words (AVX-512 BW)
// =========================================================================

val __vpermw_xmm : (xmmword, xmmword) -> xmmword
val __vpermw_ymm : (ymmword, ymmword) -> ymmword
val __vpermw_zmm : (zmmword, zmmword) -> zmmword

val exec_vpermw_xmm : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vpermw_xmm(dst, idx_reg, src) = {
  let idx : xmmword = idx_reg;
  let s : xmmword = src;
  write_xmm(dst, __vpermw_xmm(idx, s));
  Ok(())
}

val exec_vpermw_ymm : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_vpermw_ymm(dst, idx_reg, src) = {
  let idx : ymmword = read_ymm(idx_reg);
  let s : ymmword = read_ymm(src);
  write_ymm(dst, __vpermw_ymm(idx, s));
  Ok(())
}

val exec_vpermw_zmm : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_vpermw_zmm(dst, idx_reg, src) = {
  let idx : zmmword = read_zmm(idx_reg);
  let s : zmmword = read_zmm(src);
  write_zmm(dst, __vpermw_zmm(idx, s));
  Ok(())
}

// =========================================================================
// VPERMI2B — Full Permute of Bytes from Two Tables (AVX-512 VBMI)
// dst/idx selects bytes from src1 and src2; index is in dst register.
// =========================================================================

val __vpermi2b_xmm : (xmmword, xmmword, xmmword) -> xmmword
val __vpermi2b_ymm : (ymmword, ymmword, ymmword) -> ymmword
val __vpermi2b_zmm : (zmmword, zmmword, zmmword) -> zmmword

val exec_vpermi2b_xmm : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vpermi2b_xmm(dst, src1, src2) = {
  let idx : xmmword = read_xmm(dst);
  let a : xmmword = src1;
  let b : xmmword = src2;
  write_xmm(dst, __vpermi2b_xmm(idx, a, b));
  Ok(())
}

val exec_vpermi2b_ymm : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_vpermi2b_ymm(dst, src1, src2) = {
  let idx : ymmword = read_ymm(dst);
  let a : ymmword = read_ymm(src1);
  let b : ymmword = read_ymm(src2);
  write_ymm(dst, __vpermi2b_ymm(idx, a, b));
  Ok(())
}

val exec_vpermi2b_zmm : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_vpermi2b_zmm(dst, src1, src2) = {
  let idx : zmmword = read_zmm(dst);
  let a : zmmword = read_zmm(src1);
  let b : zmmword = read_zmm(src2);
  write_zmm(dst, __vpermi2b_zmm(idx, a, b));
  Ok(())
}

// =========================================================================
// VPERMI2W — Full Permute of Words from Two Tables (AVX-512 BW)
// =========================================================================

val __vpermi2w_xmm : (xmmword, xmmword, xmmword) -> xmmword
val __vpermi2w_ymm : (ymmword, ymmword, ymmword) -> ymmword
val __vpermi2w_zmm : (zmmword, zmmword, zmmword) -> zmmword

val exec_vpermi2w_xmm : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vpermi2w_xmm(dst, src1, src2) = {
  let idx : xmmword = read_xmm(dst);
  let a : xmmword = src1;
  let b : xmmword = src2;
  write_xmm(dst, __vpermi2w_xmm(idx, a, b));
  Ok(())
}

val exec_vpermi2w_ymm : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_vpermi2w_ymm(dst, src1, src2) = {
  let idx : ymmword = read_ymm(dst);
  let a : ymmword = read_ymm(src1);
  let b : ymmword = read_ymm(src2);
  write_ymm(dst, __vpermi2w_ymm(idx, a, b));
  Ok(())
}

val exec_vpermi2w_zmm : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_vpermi2w_zmm(dst, src1, src2) = {
  let idx : zmmword = read_zmm(dst);
  let a : zmmword = read_zmm(src1);
  let b : zmmword = read_zmm(src2);
  write_zmm(dst, __vpermi2w_zmm(idx, a, b));
  Ok(())
}

// =========================================================================
// VPERMI2D — Full Permute of Dwords from Two Tables (AVX-512)
// =========================================================================

val __vpermi2d_xmm : (xmmword, xmmword, xmmword) -> xmmword
val __vpermi2d_ymm : (ymmword, ymmword, ymmword) -> ymmword
val __vpermi2d_zmm : (zmmword, zmmword, zmmword) -> zmmword

val exec_vpermi2d_xmm : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vpermi2d_xmm(dst, src1, src2) = {
  let idx : xmmword = read_xmm(dst);
  let a : xmmword = src1;
  let b : xmmword = src2;
  write_xmm(dst, __vpermi2d_xmm(idx, a, b));
  Ok(())
}

val exec_vpermi2d_ymm : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_vpermi2d_ymm(dst, src1, src2) = {
  let idx : ymmword = read_ymm(dst);
  let a : ymmword = read_ymm(src1);
  let b : ymmword = read_ymm(src2);
  write_ymm(dst, __vpermi2d_ymm(idx, a, b));
  Ok(())
}

val exec_vpermi2d_zmm : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_vpermi2d_zmm(dst, src1, src2) = {
  let idx : zmmword = read_zmm(dst);
  let a : zmmword = read_zmm(src1);
  let b : zmmword = read_zmm(src2);
  write_zmm(dst, __vpermi2d_zmm(idx, a, b));
  Ok(())
}

// =========================================================================
// VPERMI2Q — Full Permute of Qwords from Two Tables (AVX-512)
// =========================================================================

val __vpermi2q_xmm : (xmmword, xmmword, xmmword) -> xmmword
val __vpermi2q_ymm : (ymmword, ymmword, ymmword) -> ymmword
val __vpermi2q_zmm : (zmmword, zmmword, zmmword) -> zmmword

val exec_vpermi2q_xmm : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vpermi2q_xmm(dst, src1, src2) = {
  let idx : xmmword = read_xmm(dst);
  let a : xmmword = src1;
  let b : xmmword = src2;
  write_xmm(dst, __vpermi2q_xmm(idx, a, b));
  Ok(())
}

val exec_vpermi2q_ymm : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_vpermi2q_ymm(dst, src1, src2) = {
  let idx : ymmword = read_ymm(dst);
  let a : ymmword = read_ymm(src1);
  let b : ymmword = read_ymm(src2);
  write_ymm(dst, __vpermi2q_ymm(idx, a, b));
  Ok(())
}

val exec_vpermi2q_zmm : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_vpermi2q_zmm(dst, src1, src2) = {
  let idx : zmmword = read_zmm(dst);
  let a : zmmword = read_zmm(src1);
  let b : zmmword = read_zmm(src2);
  write_zmm(dst, __vpermi2q_zmm(idx, a, b));
  Ok(())
}

// =========================================================================
// VPERMI2PS — Full Permute of SP FP from Two Tables (AVX-512)
// =========================================================================

val __vpermi2ps_xmm : (xmmword, xmmword, xmmword) -> xmmword
val __vpermi2ps_ymm : (ymmword, ymmword, ymmword) -> ymmword
val __vpermi2ps_zmm : (zmmword, zmmword, zmmword) -> zmmword

val exec_vpermi2ps_xmm : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vpermi2ps_xmm(dst, src1, src2) = {
  let idx : xmmword = read_xmm(dst);
  let a : xmmword = src1;
  let b : xmmword = src2;
  write_xmm(dst, __vpermi2ps_xmm(idx, a, b));
  Ok(())
}

val exec_vpermi2ps_ymm : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_vpermi2ps_ymm(dst, src1, src2) = {
  let idx : ymmword = read_ymm(dst);
  let a : ymmword = read_ymm(src1);
  let b : ymmword = read_ymm(src2);
  write_ymm(dst, __vpermi2ps_ymm(idx, a, b));
  Ok(())
}

val exec_vpermi2ps_zmm : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_vpermi2ps_zmm(dst, src1, src2) = {
  let idx : zmmword = read_zmm(dst);
  let a : zmmword = read_zmm(src1);
  let b : zmmword = read_zmm(src2);
  write_zmm(dst, __vpermi2ps_zmm(idx, a, b));
  Ok(())
}

// =========================================================================
// VPERMI2PD — Full Permute of DP FP from Two Tables (AVX-512)
// =========================================================================

val __vpermi2pd_xmm : (xmmword, xmmword, xmmword) -> xmmword
val __vpermi2pd_ymm : (ymmword, ymmword, ymmword) -> ymmword
val __vpermi2pd_zmm : (zmmword, zmmword, zmmword) -> zmmword

val exec_vpermi2pd_xmm : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vpermi2pd_xmm(dst, src1, src2) = {
  let idx : xmmword = read_xmm(dst);
  let a : xmmword = src1;
  let b : xmmword = src2;
  write_xmm(dst, __vpermi2pd_xmm(idx, a, b));
  Ok(())
}

val exec_vpermi2pd_ymm : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_vpermi2pd_ymm(dst, src1, src2) = {
  let idx : ymmword = read_ymm(dst);
  let a : ymmword = read_ymm(src1);
  let b : ymmword = read_ymm(src2);
  write_ymm(dst, __vpermi2pd_ymm(idx, a, b));
  Ok(())
}

val exec_vpermi2pd_zmm : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_vpermi2pd_zmm(dst, src1, src2) = {
  let idx : zmmword = read_zmm(dst);
  let a : zmmword = read_zmm(src1);
  let b : zmmword = read_zmm(src2);
  write_zmm(dst, __vpermi2pd_zmm(idx, a, b));
  Ok(())
}

// =========================================================================
// VPERMILPD — Permute In-Lane Double-Precision FP (AVX/AVX-512)
// =========================================================================

// Immediate form
val __vpermilpd_xmm_imm : (xmmword, byte) -> xmmword
val __vpermilpd_ymm_imm : (ymmword, byte) -> ymmword
val __vpermilpd_zmm_imm : (zmmword, byte) -> zmmword
// Register control form
val __vpermilpd_xmm_reg : (xmmword, xmmword) -> xmmword
val __vpermilpd_ymm_reg : (ymmword, ymmword) -> ymmword
val __vpermilpd_zmm_reg : (zmmword, zmmword) -> zmmword

// VPERMILPD imm8 (VEX.128/EVEX.128)
val exec_vpermilpd_xmm_imm : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_vpermilpd_xmm_imm(dst, src, imm8) = {
  let s : xmmword = src;
  write_xmm(dst, __vpermilpd_xmm_imm(s, imm8));
  Ok(())
}

// VPERMILPD imm8 (VEX.256/EVEX.256)
val exec_vpermilpd_ymm_imm : (simd_idx, simd_idx, byte) -> ExecutionResult
function exec_vpermilpd_ymm_imm(dst, src, imm8) = {
  let s : ymmword = read_ymm(src);
  write_ymm(dst, __vpermilpd_ymm_imm(s, imm8));
  Ok(())
}

// VPERMILPD imm8 (EVEX.512)
val exec_vpermilpd_zmm_imm : (simd_idx, simd_idx, byte) -> ExecutionResult
function exec_vpermilpd_zmm_imm(dst, src, imm8) = {
  let s : zmmword = read_zmm(src);
  write_zmm(dst, __vpermilpd_zmm_imm(s, imm8));
  Ok(())
}

// VPERMILPD reg (VEX.128/EVEX.128)
val exec_vpermilpd_xmm_reg : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vpermilpd_xmm_reg(dst, src1, ctrl) = {
  let s : xmmword = src1;
  let c : xmmword = ctrl;
  write_xmm(dst, __vpermilpd_xmm_reg(s, c));
  Ok(())
}

// VPERMILPD reg (VEX.256/EVEX.256)
val exec_vpermilpd_ymm_reg : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_vpermilpd_ymm_reg(dst, src1, ctrl) = {
  let s : ymmword = read_ymm(src1);
  let c : ymmword = read_ymm(ctrl);
  write_ymm(dst, __vpermilpd_ymm_reg(s, c));
  Ok(())
}

// VPERMILPD reg (EVEX.512)
val exec_vpermilpd_zmm_reg : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_vpermilpd_zmm_reg(dst, src1, ctrl) = {
  let s : zmmword = read_zmm(src1);
  let c : zmmword = read_zmm(ctrl);
  write_zmm(dst, __vpermilpd_zmm_reg(s, c));
  Ok(())
}

// =========================================================================
// VPERMILPS — Permute In-Lane Single-Precision FP (AVX/AVX-512)
// =========================================================================

// Immediate form
val __vpermilps_xmm_imm : (xmmword, byte) -> xmmword
val __vpermilps_ymm_imm : (ymmword, byte) -> ymmword
val __vpermilps_zmm_imm : (zmmword, byte) -> zmmword
// Register control form
val __vpermilps_xmm_reg : (xmmword, xmmword) -> xmmword
val __vpermilps_ymm_reg : (ymmword, ymmword) -> ymmword
val __vpermilps_zmm_reg : (zmmword, zmmword) -> zmmword

// VPERMILPS imm8 (VEX.128/EVEX.128)
val exec_vpermilps_xmm_imm : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_vpermilps_xmm_imm(dst, src, imm8) = {
  let s : xmmword = src;
  write_xmm(dst, __vpermilps_xmm_imm(s, imm8));
  Ok(())
}

// VPERMILPS imm8 (VEX.256/EVEX.256)
val exec_vpermilps_ymm_imm : (simd_idx, simd_idx, byte) -> ExecutionResult
function exec_vpermilps_ymm_imm(dst, src, imm8) = {
  let s : ymmword = read_ymm(src);
  write_ymm(dst, __vpermilps_ymm_imm(s, imm8));
  Ok(())
}

// VPERMILPS imm8 (EVEX.512)
val exec_vpermilps_zmm_imm : (simd_idx, simd_idx, byte) -> ExecutionResult
function exec_vpermilps_zmm_imm(dst, src, imm8) = {
  let s : zmmword = read_zmm(src);
  write_zmm(dst, __vpermilps_zmm_imm(s, imm8));
  Ok(())
}

// VPERMILPS reg (VEX.128/EVEX.128)
val exec_vpermilps_xmm_reg : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vpermilps_xmm_reg(dst, src1, ctrl) = {
  let s : xmmword = src1;
  let c : xmmword = ctrl;
  write_xmm(dst, __vpermilps_xmm_reg(s, c));
  Ok(())
}

// VPERMILPS reg (VEX.256/EVEX.256)
val exec_vpermilps_ymm_reg : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_vpermilps_ymm_reg(dst, src1, ctrl) = {
  let s : ymmword = read_ymm(src1);
  let c : ymmword = read_ymm(ctrl);
  write_ymm(dst, __vpermilps_ymm_reg(s, c));
  Ok(())
}

// VPERMILPS reg (EVEX.512)
val exec_vpermilps_zmm_reg : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_vpermilps_zmm_reg(dst, src1, ctrl) = {
  let s : zmmword = read_zmm(src1);
  let c : zmmword = read_zmm(ctrl);
  write_zmm(dst, __vpermilps_zmm_reg(s, c));
  Ok(())
}

// =========================================================================
// VPERMPD — Permute Double-Precision FP (AVX2/AVX-512)
// =========================================================================

val __vpermpd_ymm_imm : (ymmword, byte) -> ymmword
val __vpermpd_ymm_reg : (ymmword, ymmword) -> ymmword
val __vpermpd_zmm_imm : (zmmword, byte) -> zmmword
val __vpermpd_zmm_reg : (zmmword, zmmword) -> zmmword

// VPERMPD imm8 (VEX.256/EVEX.256)
val exec_vpermpd_ymm_imm : (simd_idx, simd_idx, byte) -> ExecutionResult
function exec_vpermpd_ymm_imm(dst, src, imm8) = {
  let s : ymmword = read_ymm(src);
  write_ymm(dst, __vpermpd_ymm_imm(s, imm8));
  Ok(())
}

// VPERMPD imm8 (EVEX.512)
val exec_vpermpd_zmm_imm : (simd_idx, simd_idx, byte) -> ExecutionResult
function exec_vpermpd_zmm_imm(dst, src, imm8) = {
  let s : zmmword = read_zmm(src);
  write_zmm(dst, __vpermpd_zmm_imm(s, imm8));
  Ok(())
}

// VPERMPD reg (EVEX.256)
val exec_vpermpd_ymm_reg : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_vpermpd_ymm_reg(dst, idx_reg, src) = {
  let idx : ymmword = read_ymm(idx_reg);
  let s : ymmword = read_ymm(src);
  write_ymm(dst, __vpermpd_ymm_reg(idx, s));
  Ok(())
}

// VPERMPD reg (EVEX.512)
val exec_vpermpd_zmm_reg : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_vpermpd_zmm_reg(dst, idx_reg, src) = {
  let idx : zmmword = read_zmm(idx_reg);
  let s : zmmword = read_zmm(src);
  write_zmm(dst, __vpermpd_zmm_reg(idx, s));
  Ok(())
}

// =========================================================================
// VPERMPS — Permute Single-Precision FP (AVX2/AVX-512)
// =========================================================================

val __vpermps_ymm : (ymmword, ymmword) -> ymmword
val __vpermps_zmm : (zmmword, zmmword) -> zmmword

val exec_vpermps_ymm : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_vpermps_ymm(dst, idx_reg, src) = {
  let idx : ymmword = read_ymm(idx_reg);
  let s : ymmword = read_ymm(src);
  write_ymm(dst, __vpermps_ymm(idx, s));
  Ok(())
}

val exec_vpermps_zmm : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_vpermps_zmm(dst, idx_reg, src) = {
  let idx : zmmword = read_zmm(idx_reg);
  let s : zmmword = read_zmm(src);
  write_zmm(dst, __vpermps_zmm(idx, s));
  Ok(())
}

// =========================================================================
// VPERMQ — Permute Quadwords (AVX2/AVX-512)
// =========================================================================

val __vpermq_ymm_imm : (ymmword, byte) -> ymmword
val __vpermq_ymm_reg : (ymmword, ymmword) -> ymmword
val __vpermq_zmm_imm : (zmmword, byte) -> zmmword
val __vpermq_zmm_reg : (zmmword, zmmword) -> zmmword

// VPERMQ imm8 (VEX.256/EVEX.256)
val exec_vpermq_ymm_imm : (simd_idx, simd_idx, byte) -> ExecutionResult
function exec_vpermq_ymm_imm(dst, src, imm8) = {
  let s : ymmword = read_ymm(src);
  write_ymm(dst, __vpermq_ymm_imm(s, imm8));
  Ok(())
}

// VPERMQ imm8 (EVEX.512)
val exec_vpermq_zmm_imm : (simd_idx, simd_idx, byte) -> ExecutionResult
function exec_vpermq_zmm_imm(dst, src, imm8) = {
  let s : zmmword = read_zmm(src);
  write_zmm(dst, __vpermq_zmm_imm(s, imm8));
  Ok(())
}

// VPERMQ reg (EVEX.256)
val exec_vpermq_ymm_reg : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_vpermq_ymm_reg(dst, idx_reg, src) = {
  let idx : ymmword = read_ymm(idx_reg);
  let s : ymmword = read_ymm(src);
  write_ymm(dst, __vpermq_ymm_reg(idx, s));
  Ok(())
}

// VPERMQ reg (EVEX.512)
val exec_vpermq_zmm_reg : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_vpermq_zmm_reg(dst, idx_reg, src) = {
  let idx : zmmword = read_zmm(idx_reg);
  let s : zmmword = read_zmm(src);
  write_zmm(dst, __vpermq_zmm_reg(idx, s));
  Ok(())
}

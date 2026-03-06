// VCVT* — AVX/AVX-512 Conversion Instructions
//
// These instructions convert between various numeric formats using
// AVX-512 registers. All require YMM/ZMM infrastructure and are
// modeled as external functions.

// =========================================================================
// FP16 conversions
// =========================================================================

// VCVTDQ2PH — Convert Packed Signed Doubleword Integers to Packed FP16 Values
val __vcvtdq2ph : zmmword -> zmmword

val exec_vcvtdq2ph : (simd_idx, simd_idx) -> ExecutionResult
function exec_vcvtdq2ph(dst, src) = {
  let result : zmmword = __vcvtdq2ph(read_zmm(src));
  write_zmm(dst, result);
  Ok(())
}

// VCVTPD2PH — Convert Packed Double-Precision FP to Packed FP16 Values
val __vcvtpd2ph : zmmword -> zmmword

val exec_vcvtpd2ph : (simd_idx, simd_idx) -> ExecutionResult
function exec_vcvtpd2ph(dst, src) = {
  let result : zmmword = __vcvtpd2ph(read_zmm(src));
  write_zmm(dst, result);
  Ok(())
}

// VCVTPH2DQ — Convert Packed FP16 Values to Packed Signed Doubleword Integers
val __vcvtph2dq : zmmword -> zmmword

val exec_vcvtph2dq : (simd_idx, simd_idx) -> ExecutionResult
function exec_vcvtph2dq(dst, src) = {
  let result : zmmword = __vcvtph2dq(read_zmm(src));
  write_zmm(dst, result);
  Ok(())
}

// VCVTPH2PD — Convert Packed FP16 Values to Packed Double-Precision FP
val __vcvtph2pd : zmmword -> zmmword

val exec_vcvtph2pd : (simd_idx, simd_idx) -> ExecutionResult
function exec_vcvtph2pd(dst, src) = {
  let result : zmmword = __vcvtph2pd(read_zmm(src));
  write_zmm(dst, result);
  Ok(())
}

// VCVTPH2PS / VCVTPH2PSX — Convert Packed FP16 to Packed Single-Precision FP
val __vcvtph2ps : zmmword -> zmmword

val exec_vcvtph2ps : (simd_idx, simd_idx) -> ExecutionResult
function exec_vcvtph2ps(dst, src) = {
  let result : zmmword = __vcvtph2ps(read_zmm(src));
  write_zmm(dst, result);
  Ok(())
}

val __vcvtph2psx : zmmword -> zmmword

val exec_vcvtph2psx : (simd_idx, simd_idx) -> ExecutionResult
function exec_vcvtph2psx(dst, src) = {
  let result : zmmword = __vcvtph2psx(read_zmm(src));
  write_zmm(dst, result);
  Ok(())
}

// VCVTPH2QQ — Convert Packed FP16 Values to Packed Signed Quadword Integers
val __vcvtph2qq : zmmword -> zmmword

val exec_vcvtph2qq : (simd_idx, simd_idx) -> ExecutionResult
function exec_vcvtph2qq(dst, src) = {
  let result : zmmword = __vcvtph2qq(read_zmm(src));
  write_zmm(dst, result);
  Ok(())
}

// VCVTPH2UDQ — Convert Packed FP16 Values to Packed Unsigned Doubleword Integers
val __vcvtph2udq : zmmword -> zmmword

val exec_vcvtph2udq : (simd_idx, simd_idx) -> ExecutionResult
function exec_vcvtph2udq(dst, src) = {
  let result : zmmword = __vcvtph2udq(read_zmm(src));
  write_zmm(dst, result);
  Ok(())
}

// =========================================================================
// PD (Double-Precision) conversions
// =========================================================================

// VCVTPD2QQ — Convert Packed Double-Precision FP to Packed Signed Quadword Integers
val __vcvtpd2qq : zmmword -> zmmword

val exec_vcvtpd2qq : (simd_idx, simd_idx) -> ExecutionResult
function exec_vcvtpd2qq(dst, src) = {
  let result : zmmword = __vcvtpd2qq(read_zmm(src));
  write_zmm(dst, result);
  Ok(())
}

// VCVTPD2UDQ — Convert Packed Double-Precision FP to Packed Unsigned Doubleword Integers
val __vcvtpd2udq : zmmword -> zmmword

val exec_vcvtpd2udq : (simd_idx, simd_idx) -> ExecutionResult
function exec_vcvtpd2udq(dst, src) = {
  let result : zmmword = __vcvtpd2udq(read_zmm(src));
  write_zmm(dst, result);
  Ok(())
}

// VCVTPD2UQQ — Convert Packed Double-Precision FP to Packed Unsigned Quadword Integers
val __vcvtpd2uqq : zmmword -> zmmword

val exec_vcvtpd2uqq : (simd_idx, simd_idx) -> ExecutionResult
function exec_vcvtpd2uqq(dst, src) = {
  let result : zmmword = __vcvtpd2uqq(read_zmm(src));
  write_zmm(dst, result);
  Ok(())
}

// =========================================================================
// BF16 (Brain Floating-Point 16) conversions
// =========================================================================

// VCVTNE2PS2BF16 — Convert Two Packed Single-Precision FP to Packed BF16 Values
val __vcvtne2ps2bf16 : (zmmword, zmmword) -> zmmword

val exec_vcvtne2ps2bf16 : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_vcvtne2ps2bf16(dst, src1, src2) = {
  let result : zmmword = __vcvtne2ps2bf16(read_zmm(src1), read_zmm(src2));
  write_zmm(dst, result);
  Ok(())
}

// VCVTNEPS2BF16 — Convert Packed Single-Precision FP to Packed BF16 Values
val __vcvtneps2bf16 : zmmword -> zmmword

val exec_vcvtneps2bf16 : (simd_idx, simd_idx) -> ExecutionResult
function exec_vcvtneps2bf16(dst, src) = {
  let result : zmmword = __vcvtneps2bf16(read_zmm(src));
  write_zmm(dst, result);
  Ok(())
}

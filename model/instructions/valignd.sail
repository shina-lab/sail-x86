// VALIGND/VALIGNQ — Align Doubleword/Quadword Vectors
//
// AVX-512 instructions that concatenate two source vectors and extract
// a contiguous result shifted by an immediate count. Require ZMM infrastructure.
// Modeled as external.

// VALIGND — Align Doubleword Vectors
val __valignd : (zmmword, zmmword, byte) -> zmmword

val exec_valignd : (simd_idx, simd_idx, simd_idx, byte) -> ExecutionResult
function exec_valignd(dst, src1, src2, imm8) = {
  let result : zmmword = __valignd(read_zmm(src1), read_zmm(src2), imm8);
  write_zmm(dst, result);
  Ok(())
}

// VALIGNQ — Align Quadword Vectors
val __valignq : (zmmword, zmmword, byte) -> zmmword

val exec_valignq : (simd_idx, simd_idx, simd_idx, byte) -> ExecutionResult
function exec_valignq(dst, src1, src2, imm8) = {
  let result : zmmword = __valignq(read_zmm(src1), read_zmm(src2), imm8);
  write_zmm(dst, result);
  Ok(())
}

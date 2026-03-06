// VBLENDMPD/VBLENDMPS — Blend Float64/Float32 Vectors Using an OpMask Control
//
// AVX-512 instructions that blend elements from two sources based on
// a mask register. Require ZMM and opmask infrastructure.
// Modeled as external.

// VBLENDMPD — Blend Packed Double-Precision FP Vectors
val __vblendmpd : (zmmword, zmmword, byte) -> zmmword

val exec_vblendmpd : (simd_idx, simd_idx, simd_idx, byte) -> ExecutionResult
function exec_vblendmpd(dst, src1, src2, kmask) = {
  let result : zmmword = __vblendmpd(read_zmm(src1), read_zmm(src2), kmask);
  write_zmm(dst, result);
  Ok(())
}

// VBLENDMPS — Blend Packed Single-Precision FP Vectors
val __vblendmps : (zmmword, zmmword, word) -> zmmword

val exec_vblendmps : (simd_idx, simd_idx, simd_idx, word) -> ExecutionResult
function exec_vblendmps(dst, src1, src2, kmask) = {
  let result : zmmword = __vblendmps(read_zmm(src1), read_zmm(src2), kmask);
  write_zmm(dst, result);
  Ok(())
}

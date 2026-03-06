// VCOMPRESSPD/VCOMPRESSPS — Store Sparse Packed FP Values into Dense Memory/Register
//
// AVX-512 instructions that compress (densely pack) elements from a source
// vector based on an opmask. Require ZMM and opmask infrastructure.
// Modeled as external.

// VCOMPRESSPD — Store Sparse Packed Double-Precision FP Values into Dense Memory/Register
val __vcompresspd : (zmmword, byte) -> zmmword

val exec_vcompresspd : (simd_idx, simd_idx, byte) -> ExecutionResult
function exec_vcompresspd(dst, src, kmask) = {
  let result : zmmword = __vcompresspd(read_zmm(src), kmask);
  write_zmm(dst, result);
  Ok(())
}

// VCOMPRESSPS — Store Sparse Packed Single-Precision FP Values into Dense Memory/Register
val __vcompressps : (zmmword, word) -> zmmword

val exec_vcompressps : (simd_idx, simd_idx, word) -> ExecutionResult
function exec_vcompressps(dst, src, kmask) = {
  let result : zmmword = __vcompressps(read_zmm(src), kmask);
  write_zmm(dst, result);
  Ok(())
}

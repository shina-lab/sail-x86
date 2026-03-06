// V4FMADDPS/V4FNMADDPS — Packed Single-Precision FP Fused Multiply-Add (4-iteration)
// V4FMADDSS/V4FNMADDSS — Scalar Single-Precision FP Fused Multiply-Add (4-iteration)
//
// AVX-512 instructions requiring ZMM register infrastructure.
// All modeled as external.

// V4FMADDPS — 4-iteration FMA on packed singles (ZMM)
val __v4fmaddps : (zmmword, zmmword, zmmword) -> zmmword

val exec_v4fmaddps : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_v4fmaddps(dst, src1, src2) = {
  let result : zmmword = __v4fmaddps(read_zmm(dst), read_zmm(src1), read_zmm(src2));
  write_zmm(dst, result);
  Ok(())
}

// V4FNMADDPS — 4-iteration negated FMA on packed singles (ZMM)
val __v4fnmaddps : (zmmword, zmmword, zmmword) -> zmmword

val exec_v4fnmaddps : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_v4fnmaddps(dst, src1, src2) = {
  let result : zmmword = __v4fnmaddps(read_zmm(dst), read_zmm(src1), read_zmm(src2));
  write_zmm(dst, result);
  Ok(())
}

// V4FMADDSS — 4-iteration FMA on scalar single (uses ZMM registers)
val __v4fmaddss : (zmmword, zmmword, zmmword) -> zmmword

val exec_v4fmaddss : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_v4fmaddss(dst, src1, src2) = {
  let result : zmmword = __v4fmaddss(read_zmm(dst), read_zmm(src1), read_zmm(src2));
  write_zmm(dst, result);
  Ok(())
}

// V4FNMADDSS — 4-iteration negated FMA on scalar single (uses ZMM registers)
val __v4fnmaddss : (zmmword, zmmword, zmmword) -> zmmword

val exec_v4fnmaddss : (simd_idx, simd_idx, simd_idx) -> ExecutionResult
function exec_v4fnmaddss(dst, src1, src2) = {
  let result : zmmword = __v4fnmaddss(read_zmm(dst), read_zmm(src1), read_zmm(src2));
  write_zmm(dst, result);
  Ok(())
}

// MOVHLPS — Move Packed Single-Precision FP High to Low
// dst[63:0] = src[127:64], dst[127:64] preserved.
// MOVLHPS — Move Packed Single-Precision FP Low to High
// dst[127:64] = src[63:0], dst[63:0] preserved.
// No flags affected.

val exec_movhlps : (simd_idx, xmmword) -> ExecutionResult
function exec_movhlps(dst, src) = {
  let high : qword = read_xmm(dst)[127..64];
  let src_high : qword = src[127..64];
  write_xmm_legacy(dst, high @ src_high);
  Ok(())
}

val exec_movlhps : (simd_idx, xmmword) -> ExecutionResult
function exec_movlhps(dst, src) = {
  let low : qword = read_xmm(dst)[63..0];
  let src_low : qword = src[63..0];
  write_xmm_legacy(dst, src_low @ low);
  Ok(())
}

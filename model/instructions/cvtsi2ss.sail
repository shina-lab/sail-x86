// CVTSI2SS — Convert Integer to Scalar Single Precision FP
//
// Converts a 32/64-bit integer to single-precision FP in XMM[31:0].
// Upper bits of XMM preserved. No flags affected.

val exec_cvtsi2ss : (simd_idx, qword, OperandSize) -> ExecutionResult
function exec_cvtsi2ss(dst, src, os) = {
  let result : dword = match os {
    OS64 => __int64_to_f32(src),
    _    => __int32_to_f32(src[31..0]),
  };
  var xmm : xmmword = read_xmm(dst);
  xmm[31..0] = result;
  write_xmm_legacy(dst, xmm);
  Ok(())
}

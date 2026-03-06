// CVTSI2SD — Convert Integer to Scalar Double Precision FP
//
// Converts a 32/64-bit integer to double-precision FP in XMM.
// Upper bits of XMM preserved. No flags affected.

val exec_cvtsi2sd : (simd_idx, qword, OperandSize) -> ExecutionResult
function exec_cvtsi2sd(dst, src, os) = {
  let result : qword = match os {
    OS64 => __int64_to_f64(src),
    _    => __int32_to_f64(src[31..0]),
  };
  var xmm : xmmword = read_xmm(dst);
  xmm[63..0] = result;
  write_xmm_legacy(dst, xmm);
  Ok(())
}

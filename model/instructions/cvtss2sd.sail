// CVTSS2SD — Convert Scalar Single Precision FP to Double Precision FP
//
// Converts single in XMM src[31:0] to double in XMM dst[63:0].
// Upper bits of dst preserved. No flags affected.

val exec_cvtss2sd : (simd_idx, xmmword) -> ExecutionResult
function exec_cvtss2sd(dst, src) = {
  let result : qword = __f32_to_f64(src[31..0]);
  var xmm : xmmword = read_xmm(dst);
  xmm[63..0] = result;
  write_xmm_legacy(dst, xmm);
  Ok(())
}

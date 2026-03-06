// CVTSD2SS — Convert Scalar Double Precision FP to Single Precision FP
//
// Converts double in XMM src[63:0] to single in XMM dst[31:0].
// Upper bits of dst preserved. No flags affected.

val exec_cvtsd2ss : (simd_idx, xmmword) -> ExecutionResult
function exec_cvtsd2ss(dst, src) = {
  let result : dword = __f64_to_f32(src[63..0]);
  var xmm : xmmword = read_xmm(dst);
  xmm[31..0] = result;
  write_xmm_legacy(dst, xmm);
  Ok(())
}

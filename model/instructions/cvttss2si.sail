// CVTTSS2SI — Convert with Truncation Scalar Single Precision FP to Integer
//
// Like CVTSS2SI but always truncates toward zero. No flags affected.

val exec_cvttss2si : (gpr_idx, xmmword, OperandSize) -> ExecutionResult
function exec_cvttss2si(dst, src, os) = {
  let fp_val : dword = src[31..0];
  match os {
    OS64 => write_gpr64(dst, __f32_to_int64_trunc(fp_val)),
    _    => write_gpr32(dst, __f32_to_int32_trunc(fp_val)),
  };
  Ok(())
}

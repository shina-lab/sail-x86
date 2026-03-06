// CVTTSD2SI — Convert with Truncation Scalar Double Precision FP to Integer
//
// Like CVTSD2SI but always truncates toward zero. No flags affected.

val exec_cvttsd2si : (gpr_idx, xmmword, OperandSize) -> ExecutionResult
function exec_cvttsd2si(dst, src, os) = {
  let fp_val : qword = src[63..0];
  match os {
    OS64 => write_gpr64(dst, __f64_to_int64_trunc(fp_val)),
    _    => write_gpr32(dst, __f64_to_int32_trunc(fp_val)),
  };
  Ok(())
}

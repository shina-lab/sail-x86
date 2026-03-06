// CVTSD2SI — Convert Scalar Double Precision FP to Integer
//
// Converts double-precision FP in XMM to 32/64-bit integer in GPR.
// No flags affected.

val exec_cvtsd2si : (gpr_idx, xmmword, OperandSize) -> ExecutionResult
function exec_cvtsd2si(dst, src, os) = {
  let fp_val : qword = src[63..0];
  match os {
    OS64 => write_gpr64(dst, __f64_to_int64(fp_val)),
    _    => write_gpr32(dst, __f64_to_int32(fp_val)),
  };
  Ok(())
}

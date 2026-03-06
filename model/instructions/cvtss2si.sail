// CVTSS2SI — Convert Scalar Single Precision FP to Integer
//
// Converts single-precision FP in XMM to 32/64-bit integer in GPR.
// No flags affected.

val exec_cvtss2si : (gpr_idx, xmmword, OperandSize) -> ExecutionResult
function exec_cvtss2si(dst, src, os) = {
  let fp_val : dword = src[31..0];
  match os {
    OS64 => write_gpr64(dst, __f32_to_int64(fp_val)),
    _    => write_gpr32(dst, __f32_to_int32(fp_val)),
  };
  Ok(())
}

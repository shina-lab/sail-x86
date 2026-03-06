// NOT — One's Complement Negation
//
// Computes dest := NOT dest (bitwise inversion).
// No flags are affected.

val exec_not : (gpr_idx, OperandSize) -> ExecutionResult
function exec_not(dst, os) = {
  let a : qword = read_gpr(dst, os);
  let result : qword = ~(a);
  write_gpr(dst, os, result);
  Ok(())
}

// XCHG — Exchange Register/Memory with Register
//
// Exchanges the values of two operands. No flags affected.

val exec_xchg_reg_reg : (gpr_idx, gpr_idx, OperandSize) -> ExecutionResult
function exec_xchg_reg_reg(a, b, os) = {
  let va : qword = read_gpr(a, os);
  let vb : qword = read_gpr(b, os);
  write_gpr(a, os, vb);
  write_gpr(b, os, va);
  Ok(())
}

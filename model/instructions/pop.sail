// POP — Pop a Value from the Stack
//
// Loads the value from the top of the stack to a register,
// then increments RSP.
// No flags are affected.

// POP reg
val exec_pop_reg : (gpr_idx, OperandSize) -> ExecutionResult
function exec_pop_reg(dst, os) = {
  match os {
    OS64 => write_gpr64(dst, pop64()),
    OS32 => write_gpr32(dst, pop64()[31..0]),
    OS16 => write_gpr16(dst, pop16()),
    _ => (),
  };
  Ok(())
}

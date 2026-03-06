// PUSH — Push Value Onto the Stack
//
// Decrements RSP and stores the source operand on top of the stack.
// No flags are affected.

// PUSH reg
val exec_push_reg : (gpr_idx, OperandSize) -> ExecutionResult
function exec_push_reg(src, os) = {
  match os {
    OS64 => push64(read_gpr64(src)),
    OS32 => push64(zero_extend(read_gpr32(src))),
    OS16 => push16(read_gpr16(src)),
    _ => (),
  };
  Ok(())
}

// PUSH imm
val exec_push_imm : (qword, OperandSize) -> ExecutionResult
function exec_push_imm(imm, os) = {
  match os {
    OS64 => push64(imm),
    OS32 => push64(imm),
    OS16 => push16(imm[15..0]),
    _ => (),
  };
  Ok(())
}

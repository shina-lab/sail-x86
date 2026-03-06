// RET — Return from Procedure
//
// Pops a return address from the stack into RIP.
// Optionally adds an immediate value to RSP to release stack parameters.
// No flags are affected (near return).

// RET near (no immediate)
val exec_ret : OperandSize -> ExecutionResult
function exec_ret(os) = {
  let target : qword = match os {
    OS64 => pop64(),
    OS32 => zero_extend(pop64()[31..0]),
    OS16 => zero_extend(pop16()),
    OS8 => zeros(),
  };
  RIP = target;
  decode_pos = target;
  Ok(())
}

// RET near with immediate (release stack parameters)
val exec_ret_imm : (word, OperandSize) -> ExecutionResult
function exec_ret_imm(imm, os) = {
  let target : qword = match os {
    OS64 => pop64(),
    OS32 => zero_extend(pop64()[31..0]),
    OS16 => zero_extend(pop16()),
    OS8 => zeros(),
  };
  RIP = target;
  decode_pos = target;
  GPR[RSP] = GPR[RSP] + zero_extend(imm);
  Ok(())
}

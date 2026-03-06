// CALL — Call Procedure
//
// Pushes return address (current RIP) onto the stack, then jumps.
// RIP is assumed to already point past the CALL instruction (advanced by decoder).
// No flags are affected.

// CALL near relative: push return address, then RIP := decode_pos + offset
// decode_pos points past the instruction (the return address).
val exec_call_rel : (qword, OperandSize) -> ExecutionResult
function exec_call_rel(offset, os) = {
  let return_addr = decode_pos;
  match os {
    OS64 => push64(return_addr),
    OS32 => push64(zero_extend(return_addr[31..0])),
    OS16 => push16(return_addr[15..0]),
    _ => (),
  };
  let new_rip = return_addr + offset;
  RIP = new_rip;
  decode_pos = new_rip;
  Ok(())
}

// CALL near absolute indirect: push return address, then RIP := target
val exec_call_abs : (qword, OperandSize) -> ExecutionResult
function exec_call_abs(target, os) = {
  let return_addr = decode_pos;
  match os {
    OS64 => push64(return_addr),
    OS32 => push64(zero_extend(return_addr[31..0])),
    OS16 => push16(return_addr[15..0]),
    _ => (),
  };
  RIP = target;
  decode_pos = target;
  Ok(())
}

// JMP — Jump
//
// Transfers control to a different point in the instruction stream.
// No flags are affected. RIP is assumed to already point past the
// JMP instruction itself (advanced by decoder).

// JMP near relative: RIP := decode_pos + sign-extended offset
// (decode_pos points past the JMP instruction)
val exec_jmp_rel : qword -> ExecutionResult
function exec_jmp_rel(offset) = {
  let new_rip = decode_pos + offset;
  RIP = new_rip;
  decode_pos = new_rip;
  Ok(())
}

// JMP near absolute indirect: RIP := value from register
val exec_jmp_abs : qword -> ExecutionResult
function exec_jmp_abs(target) = {
  RIP = target;
  decode_pos = target;
  Ok(())
}

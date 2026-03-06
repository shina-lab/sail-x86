// PUSHF/PUSHFD/PUSHFQ — Push EFLAGS Register Onto the Stack
//
// Pushes the lower 16 bits (PUSHF) or full RFLAGS (PUSHFQ) onto the stack.
// Bits 16-17 (VM, RF) are cleared in the pushed value.

val exec_pushf : OperandSize -> ExecutionResult
function exec_pushf(os) = {
  let flags : qword = read_rflags();
  match os {
    OS16 => push16(flags[15..0]),
    OS64 => {
      // Clear VM (bit 17) and RF (bit 16) in pushed value
      var v : qword = flags;
      v[16] = bitzero;
      v[17] = bitzero;
      push64(v);
    },
    _ => (),
  };
  Ok(())
}

// LEAVE — High Level Procedure Exit
//
// Copies frame pointer (RBP) into stack pointer (RSP), then pops RBP.
// No flags affected.

val exec_leave : OperandSize -> ExecutionResult
function exec_leave(os) = {
  match os {
    OS64 => {
      write_gpr64(RSP, read_gpr64(RBP));
      write_gpr64(RBP, pop64());
    },
    OS32 => {
      write_gpr64(RSP, zero_extend(read_gpr32(RBP)));
      let v : qword = pop64();
      write_gpr32(RBP, v[31..0]);
    },
    OS16 => {
      write_gpr16(RSP, read_gpr16(RBP));
      write_gpr16(RBP, pop16());
    },
    _ => (),
  };
  Ok(())
}

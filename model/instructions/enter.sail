// ENTER — Make Stack Frame for Procedure Parameters
//
// Creates a stack frame. imm16 = dynamic storage size, imm8 = nesting level.
// Nesting level 0 is the common case (simple procedure frame).
// We model 64-bit mode only (OperandSize=64 default, or 16 with 66H prefix).

val exec_enter : (word, byte, OperandSize) -> ExecutionResult
function exec_enter(alloc_size, nesting_raw, os) = {
  let nesting : range(0, 31) = unsigned(nesting_raw) % 32;
  match os {
    OS64 => {
      push64(read_gpr64(RBP));
      let frame_temp : qword = read_gpr64(RSP);
      if nesting > 1 then {
        foreach (i from 1 to (nesting - 1)) {
          write_gpr64(RBP, read_gpr64(RBP) - 8);
          push64(mem_read64(read_gpr64(RBP)));
        };
      };
      if nesting >= 1 then
        push64(frame_temp);
      write_gpr64(RBP, frame_temp);
      write_gpr64(RSP, read_gpr64(RSP) - zero_extend(alloc_size));
    },
    OS16 => {
      push16(read_gpr16(RBP));
      let frame_temp : word = read_gpr16(RSP);
      if nesting > 1 then {
        foreach (i from 1 to (nesting - 1)) {
          write_gpr16(RBP, read_gpr16(RBP) - 2);
          push16(mem_read16(zero_extend(read_gpr16(RBP))));
        };
      };
      if nesting >= 1 then
        push16(frame_temp);
      write_gpr16(RBP, frame_temp);
      write_gpr64(RSP, read_gpr64(RSP) - zero_extend(alloc_size));
    },
    _ => (),
  };
  Ok(())
}

// LAHF — Load Status Flags Into AH Register
// SAHF — Store AH Into Flags
//
// LAHF: AH := RFLAGS(SF:ZF:0:AF:0:PF:1:CF)
// SAHF: RFLAGS(SF:ZF:0:AF:0:PF:1:CF) := AH

val exec_lahf : unit -> ExecutionResult
function exec_lahf() = {
  let v : byte = CF @ bitone @ PF @ bitzero @ AF @ bitzero @ ZF @ SF;
  write_gpr8h(RAX, v);
  Ok(())
}

val exec_sahf : unit -> ExecutionResult
function exec_sahf() = {
  let ah : byte = read_gpr8h(RAX);
  CF = ah[0];
  PF = ah[2];
  AF = ah[4];
  ZF = ah[6];
  SF = ah[7];
  Ok(())
}

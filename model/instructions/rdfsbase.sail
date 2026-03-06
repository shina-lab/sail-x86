// RDFSBASE/RDGSBASE — Read FS/GS Segment Base
//
// Reads the FS or GS segment base address into a 32-bit or 64-bit
// general-purpose register. No flags affected.
// Modeled as external since segment base registers are system state.

val __rdfsbase : unit -> qword
val __rdgsbase : unit -> qword

val exec_rdfsbase32 : (gpr_idx) -> ExecutionResult
function exec_rdfsbase32(dst) = {
  let base : qword = __rdfsbase();
  write_gpr32(dst, base[31..0]);
  Ok(())
}

val exec_rdfsbase64 : (gpr_idx) -> ExecutionResult
function exec_rdfsbase64(dst) = {
  write_gpr64(dst, __rdfsbase());
  Ok(())
}

val exec_rdgsbase32 : (gpr_idx) -> ExecutionResult
function exec_rdgsbase32(dst) = {
  let base : qword = __rdgsbase();
  write_gpr32(dst, base[31..0]);
  Ok(())
}

val exec_rdgsbase64 : (gpr_idx) -> ExecutionResult
function exec_rdgsbase64(dst) = {
  write_gpr64(dst, __rdgsbase());
  Ok(())
}

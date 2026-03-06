// RDSSPD/RDSSPQ — Read Shadow Stack Pointer
//
// Reads the current shadow stack pointer (SSP) into a 32-bit or 64-bit
// general-purpose register. Part of Control-flow Enforcement Technology (CET).
// No flags affected.

val __rdssp : unit -> qword

val exec_rdsspd : (gpr_idx) -> ExecutionResult
function exec_rdsspd(dst) = {
  let ssp : qword = __rdssp();
  write_gpr32(dst, ssp[31..0]);
  Ok(())
}

val exec_rdsspq : (gpr_idx) -> ExecutionResult
function exec_rdsspq(dst) = {
  write_gpr64(dst, __rdssp());
  Ok(())
}

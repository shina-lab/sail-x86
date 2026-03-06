// RDPID — Read Processor ID
//
// Reads IA32_TSC_AUX MSR into destination register.
// No flags affected.

val __read_tsc_aux : unit -> dword

val exec_rdpid : gpr_idx -> ExecutionResult
function exec_rdpid(dst) = {
  write_gpr32(dst, __read_tsc_aux());
  Ok(())
}

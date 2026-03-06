// RDTSCP — Read Time-Stamp Counter and Processor ID
//
// Reads the 64-bit TSC into EDX:EAX and the IA32_TSC_AUX MSR
// into ECX. Upper 32 bits of RAX, RDX, and RCX are cleared.
// No flags affected.

val __rdtscp : unit -> (qword, dword)

val exec_rdtscp : unit -> ExecutionResult
function exec_rdtscp() = {
  let (tsc, tsc_aux) = __rdtscp();
  write_gpr32(RAX, tsc[31..0]);
  write_gpr32(RDX, tsc[63..32]);
  write_gpr32(RCX, tsc_aux);
  Ok(())
}

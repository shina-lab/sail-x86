// RDTSC — Read Time-Stamp Counter
//
// Reads the 64-bit TSC into EDX:EAX (high:low).
// Upper 32 bits of RAX and RDX are cleared.
// No flags affected. TSC value is provided by the execution environment.

// External function: returns current time-stamp counter value.
val __rdtsc : unit -> qword

val exec_rdtsc : unit -> ExecutionResult
function exec_rdtsc() = {
  let tsc : qword = __rdtsc();
  write_gpr32(RAX, tsc[31..0]);
  write_gpr32(RDX, tsc[63..32]);
  Ok(())
}

// RDMSR — Read from Model Specific Register
//
// Reads the 64-bit MSR specified in ECX into EDX:EAX.
// High 32 bits of RAX and RDX are cleared.
// No flags affected. Requires CPL=0.

val __rdmsr : dword -> qword

val exec_rdmsr : unit -> ExecutionResult
function exec_rdmsr() = {
  let addr : dword = read_gpr32(RCX);
  let val64 : qword = __rdmsr(addr);
  write_gpr32(RAX, val64[31..0]);
  write_gpr32(RDX, val64[63..32]);
  Ok(())
}

// RDPMC — Read Performance-Monitoring Counters
//
// Reads the 64-bit performance counter specified in ECX into EDX:EAX.
// High 32 bits of RAX and RDX are cleared.
// No flags affected.

val __rdpmc : dword -> qword

val exec_rdpmc : unit -> ExecutionResult
function exec_rdpmc() = {
  let idx : dword = read_gpr32(RCX);
  let val64 : qword = __rdpmc(idx);
  write_gpr32(RAX, val64[31..0]);
  write_gpr32(RDX, val64[63..32]);
  Ok(())
}

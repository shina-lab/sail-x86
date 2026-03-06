// RDPKRU — Read Protection Key Rights for User Pages
//
// Reads the PKRU register into EAX. ECX must be 0.
// EDX is cleared. No flags affected.

val __rdpkru : unit -> dword

val exec_rdpkru : unit -> ExecutionResult
function exec_rdpkru() = {
  let pkru : dword = __rdpkru();
  write_gpr32(RAX, pkru);
  write_gpr32(RDX, 0x00000000);
  Ok(())
}

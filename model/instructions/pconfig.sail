// PCONFIG — Platform Configuration
//
// Used to configure platform features. Takes a leaf function in EAX
// and additional parameters in RBX, RCX, RDX. Results returned in
// EAX (and possibly RBX, RCX, RDX). Requires CPL=0.
// No flags affected (except EAX return status).
//
// Modeled as external due to platform-specific behavior.

val __pconfig : (dword, qword, qword, qword) -> (dword, qword, qword, qword)

val exec_pconfig : unit -> ExecutionResult
function exec_pconfig() = {
  let leaf : dword = read_gpr32(RAX);
  let (out_eax, out_rbx, out_rcx, out_rdx) = __pconfig(leaf, read_gpr64(RBX), read_gpr64(RCX), read_gpr64(RDX));
  write_gpr32(RAX, out_eax);
  write_gpr64(RBX, out_rbx);
  write_gpr64(RCX, out_rcx);
  write_gpr64(RDX, out_rdx);
  Ok(())
}

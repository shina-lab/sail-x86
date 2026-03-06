// CPUID — CPU Identification
//
// Returns processor identification and feature information in EAX, EBX,
// ECX, EDX based on input leaf (EAX) and sub-leaf (ECX).
// No flags affected. Values are implementation-defined.

// External function provided by the execution environment.
// Takes (leaf, subleaf) and returns (eax, ebx, ecx, edx).
val __cpuid : (dword, dword) -> (dword, dword, dword, dword)

val exec_cpuid : unit -> ExecutionResult
function exec_cpuid() = {
  let leaf : dword = read_gpr32(RAX);
  let subleaf : dword = read_gpr32(RCX);
  let (out_eax, out_ebx, out_ecx, out_edx) = __cpuid(leaf, subleaf);
  write_gpr32(RAX, out_eax);
  write_gpr32(RBX, out_ebx);
  write_gpr32(RCX, out_ecx);
  write_gpr32(RDX, out_edx);
  Ok(())
}

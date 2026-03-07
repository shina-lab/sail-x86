// XGETBV — Get Value of Extended Control Register
//
// Reads XCR[ECX] into EDX:EAX. ECX=0 (XCR0) reports OS-enabled state components.
// We report x87 + SSE + AVX enabled (bits 0-2).

val exec_xgetbv : unit -> ExecutionResult
function exec_xgetbv() = {
  let ecx_val : dword = read_gpr32(RCX);
  if ecx_val == 0x00000000 then {
    // XCR0: bit 0 = x87, bit 1 = SSE, bit 2 = AVX
    write_gpr32(RAX, 0x00000007);
    write_gpr32(RDX, 0x00000000);
    Ok(())
  } else {
    // Only XCR0 is supported
    raise_GP0()
  }
}

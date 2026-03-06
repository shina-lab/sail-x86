// CMPXCHG8B/CMPXCHG16B — Compare and Exchange Bytes
//
// Compares EDX:EAX (or RDX:RAX) with 64-bit (or 128-bit) memory operand.
// If equal, sets ZF and stores ECX:EBX (or RCX:RBX) to memory.
// Otherwise, clears ZF and loads memory value into EDX:EAX (or RDX:RAX).

val exec_cmpxchg8b : qword -> ExecutionResult
function exec_cmpxchg8b(addr) = {
  let mem_lo : dword = mem_read32(addr);
  let mem_hi : dword = mem_read32(addr + 0x0000000000000004);
  if read_gpr32(RAX) == mem_lo & read_gpr32(RDX) == mem_hi then {
    ZF = bitone;
    mem_write32(addr, read_gpr32(RBX));
    mem_write32(addr + 0x0000000000000004, read_gpr32(RCX));
  } else {
    ZF = bitzero;
    write_gpr32(RAX, mem_lo);
    write_gpr32(RDX, mem_hi);
  };
  Ok(())
}

val exec_cmpxchg16b : qword -> ExecutionResult
function exec_cmpxchg16b(addr) = {
  let mem_lo : qword = mem_read64(addr);
  let mem_hi : qword = mem_read64(addr + 0x0000000000000008);
  if read_gpr64(RAX) == mem_lo & read_gpr64(RDX) == mem_hi then {
    ZF = bitone;
    mem_write64(addr, read_gpr64(RBX));
    mem_write64(addr + 0x0000000000000008, read_gpr64(RCX));
  } else {
    ZF = bitzero;
    write_gpr64(RAX, mem_lo);
    write_gpr64(RDX, mem_hi);
  };
  Ok(())
}

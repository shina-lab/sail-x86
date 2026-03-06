// STOS/STOSB/STOSW/STOSD/STOSQ — Store String
//
// Stores AL/AX/EAX/RAX to memory at ES:[RDI], then adjusts RDI
// by operand size (increment if DF=0, decrement if DF=1).
// Address size selects RDI vs EDI.
// No flags affected.

val exec_stos : (OperandSize, AddressSize) -> ExecutionResult
function exec_stos(os, asz) = {
  let addr : qword = read_index_dst(asz);
  match os {
    OS8  => mem_write8(addr, read_gpr8l(RAX)),
    OS16 => mem_write16(addr, read_gpr16(RAX)),
    OS32 => mem_write32(addr, read_gpr32(RAX)),
    OS64 => mem_write64(addr, read_gpr64(RAX)),
  };
  let delta : qword = match os {
    OS8  => 0x0000000000000001,
    OS16 => 0x0000000000000002,
    OS32 => 0x0000000000000004,
    OS64 => 0x0000000000000008,
  };
  if DF == bitzero then
    write_index_dst(asz, addr + delta)
  else
    write_index_dst(asz, addr - delta);
  Ok(())
}

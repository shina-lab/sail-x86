// INS/INSB/INSW/INSD — Input from Port to String
//
// Reads from I/O port DX into ES:[RDI], then adjusts RDI.
// No flags affected.

val exec_ins : OperandSize -> ExecutionResult
function exec_ins(os) = {
  let port : word = read_gpr16(RDX);
  let addr : qword = read_gpr64(RDI);
  match os {
    OS8  => mem_write8(addr, __port_in8(port)),
    OS16 => mem_write16(addr, __port_in16(port)),
    OS32 => mem_write32(addr, __port_in32(port)),
    OS64 => (),
  };
  let delta : qword = match os {
    OS8  => 0x0000000000000001,
    OS16 => 0x0000000000000002,
    OS32 => 0x0000000000000004,
    OS64 => 0x0000000000000008,
  };
  if DF == bitzero then
    write_gpr64(RDI, addr + delta)
  else
    write_gpr64(RDI, addr - delta);
  Ok(())
}

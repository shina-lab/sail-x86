// OUTS/OUTSB/OUTSW/OUTSD — Output String to Port
//
// Writes from DS:[RSI] to I/O port DX, then adjusts RSI.
// No flags affected.

val exec_outs : OperandSize -> ExecutionResult
function exec_outs(os) = {
  let port : word = read_gpr16(RDX);
  let addr : qword = read_gpr64(RSI);
  match os {
    OS8  => __port_out8(port, mem_read8(addr)),
    OS16 => __port_out16(port, mem_read16(addr)),
    OS32 => __port_out32(port, mem_read32(addr)),
    OS64 => (),
  };
  let delta : qword = match os {
    OS8  => 0x0000000000000001,
    OS16 => 0x0000000000000002,
    OS32 => 0x0000000000000004,
    OS64 => 0x0000000000000008,
  };
  if DF == bitzero then
    write_gpr64(RSI, addr + delta)
  else
    write_gpr64(RSI, addr - delta);
  Ok(())
}

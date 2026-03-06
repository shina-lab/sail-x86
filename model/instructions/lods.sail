// LODS/LODSB/LODSW/LODSD/LODSQ — Load String
//
// Loads a byte/word/dword/qword from DS:[RSI] into AL/AX/EAX/RAX,
// then adjusts RSI by operand size (increment if DF=0, decrement if DF=1).
// Address size selects RSI vs ESI.
// No flags affected.

val exec_lods : (OperandSize, AddressSize) -> ExecutionResult
function exec_lods(os, asz) = {
  let addr : qword = read_index_src(asz);
  match os {
    OS8  => write_gpr8l(RAX, mem_read8(addr)),
    OS16 => write_gpr16(RAX, mem_read16(addr)),
    OS32 => write_gpr32(RAX, mem_read32(addr)),
    OS64 => write_gpr64(RAX, mem_read64(addr)),
  };
  let delta : qword = match os {
    OS8  => 0x0000000000000001,
    OS16 => 0x0000000000000002,
    OS32 => 0x0000000000000004,
    OS64 => 0x0000000000000008,
  };
  if DF == bitzero then
    write_index_src(asz, addr + delta)
  else
    write_index_src(asz, addr - delta);
  Ok(())
}

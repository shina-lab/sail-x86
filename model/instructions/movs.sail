// MOVS/MOVSB/MOVSW/MOVSD/MOVSQ — Move String
//
// Copies byte/word/dword/qword from DS:[RSI] to ES:[RDI],
// then adjusts RSI and RDI by operand size.
// Address size selects RSI/RDI vs ESI/EDI.
// No flags affected.

val exec_movs : (OperandSize, AddressSize) -> ExecutionResult
function exec_movs(os, asz) = {
  let src_addr : qword = read_index_src(asz);
  let dst_addr : qword = read_index_dst(asz);
  match os {
    OS8  => mem_write8(dst_addr, mem_read8(src_addr)),
    OS16 => mem_write16(dst_addr, mem_read16(src_addr)),
    OS32 => mem_write32(dst_addr, mem_read32(src_addr)),
    OS64 => mem_write64(dst_addr, mem_read64(src_addr)),
  };
  let delta : qword = match os {
    OS8  => 0x0000000000000001,
    OS16 => 0x0000000000000002,
    OS32 => 0x0000000000000004,
    OS64 => 0x0000000000000008,
  };
  if DF == bitzero then {
    write_index_src(asz, src_addr + delta);
    write_index_dst(asz, dst_addr + delta);
  } else {
    write_index_src(asz, src_addr - delta);
    write_index_dst(asz, dst_addr - delta);
  };
  Ok(())
}

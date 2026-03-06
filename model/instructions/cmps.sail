// CMPS/CMPSB/CMPSW/CMPSD/CMPSQ — Compare String Operands
//
// Compares byte/word/dword/qword at DS:[RSI] with ES:[RDI],
// sets flags as for SUB, then adjusts RSI and RDI.
// Address size selects RSI/RDI vs ESI/EDI.

val exec_cmps : (OperandSize, AddressSize) -> ExecutionResult
function exec_cmps(os, asz) = {
  let src_addr : qword = read_index_src(asz);
  let dst_addr : qword = read_index_dst(asz);
  match os {
    OS8 => {
      let a : byte = mem_read8(src_addr);
      let b : byte = mem_read8(dst_addr);
      update_flags_sub(a - b, a, b);
    },
    OS16 => {
      let a : word = mem_read16(src_addr);
      let b : word = mem_read16(dst_addr);
      update_flags_sub(a - b, a, b);
    },
    OS32 => {
      let a : dword = mem_read32(src_addr);
      let b : dword = mem_read32(dst_addr);
      update_flags_sub(a - b, a, b);
    },
    OS64 => {
      let a : qword = mem_read64(src_addr);
      let b : qword = mem_read64(dst_addr);
      update_flags_sub(a - b, a, b);
    },
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

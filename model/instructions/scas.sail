// SCAS/SCASB/SCASW/SCASD/SCASQ — Scan String
//
// Compares AL/AX/EAX/RAX with byte/word/dword/qword at ES:[RDI],
// sets flags as for SUB, then adjusts RDI by operand size.
// Address size selects RDI vs EDI.

val exec_scas : (OperandSize, AddressSize) -> ExecutionResult
function exec_scas(os, asz) = {
  let addr : qword = read_index_dst(asz);
  match os {
    OS8 => {
      let a : byte = read_gpr8l(RAX);
      let b : byte = mem_read8(addr);
      update_flags_sub(a - b, a, b);
    },
    OS16 => {
      let a : word = read_gpr16(RAX);
      let b : word = mem_read16(addr);
      update_flags_sub(a - b, a, b);
    },
    OS32 => {
      let a : dword = read_gpr32(RAX);
      let b : dword = mem_read32(addr);
      update_flags_sub(a - b, a, b);
    },
    OS64 => {
      let a : qword = read_gpr64(RAX);
      let b : qword = mem_read64(addr);
      update_flags_sub(a - b, a, b);
    },
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

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
  Ok()
}
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
  Ok()
}
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
  Ok()
}
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
  Ok()
}
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
  Ok()
}
// REP/REPE/REPZ/REPNE/REPNZ — Repeat String Operation Prefix
//
// REP: repeat while RCX != 0 (for MOVS, STOS, LODS, INS, OUTS).
// REPE/REPZ: also stop if ZF=0 after CMPS/SCAS.
// REPNE/REPNZ: also stop if ZF=1 after CMPS/SCAS.
// Address size (67h prefix) selects RCX vs ECX for the count register.

enum RepPrefix = { REP_none, REP_rep, REP_repe, REP_repne }

enum StringOp = { STR_movs, STR_stos, STR_lods, STR_cmps, STR_scas }

val exec_rep : (RepPrefix, StringOp, OperandSize, AddressSize) -> ExecutionResult
function exec_rep(prefix, op, os, asz) = {
  var done : bool = false;
  while ~(done) do {
    if read_count_reg(asz) == zeros() then
      done = true
    else {
      match op {
        STR_movs => { let _ = exec_movs(os, asz); () },
        STR_stos => { let _ = exec_stos(os, asz); () },
        STR_lods => { let _ = exec_lods(os, asz); () },
        STR_cmps => { let _ = exec_cmps(os, asz); () },
        STR_scas => { let _ = exec_scas(os, asz); () },
      };
      let cnt = read_count_reg(asz);
      write_count_reg(asz, cnt - 1);
      if read_count_reg(asz) == zeros() then
        done = true
      else match prefix {
        REP_repe  => if ZF == bitzero then done = true,
        REP_repne => if ZF == bitone then done = true,
        _         => (),
      };
    };
  };
  Ok()
}

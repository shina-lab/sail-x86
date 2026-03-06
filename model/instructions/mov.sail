// MOV — Move
//
// Copies the source operand to the destination operand.
// No flags are affected.

// MOV reg, reg
val exec_mov_reg_reg : (gpr_idx, gpr_idx, OperandSize) -> ExecutionResult
function exec_mov_reg_reg(dst, src, os) = {
  let v = read_gpr(src, os);
  write_gpr(dst, os, v);
  Ok(())
}

// MOV reg, imm
val exec_mov_reg_imm : (gpr_idx, qword, OperandSize) -> ExecutionResult
function exec_mov_reg_imm(dst, imm, os) = {
  write_gpr(dst, os, imm);
  Ok(())
}

// MOV reg, mem
val exec_mov_reg_mem : (gpr_idx, qword, OperandSize) -> ExecutionResult
function exec_mov_reg_mem(dst, addr, os) = {
  let v : qword = match os {
    OS8  => zero_extend(mem_read8(addr)),
    OS16 => zero_extend(mem_read16(addr)),
    OS32 => zero_extend(mem_read32(addr)),
    OS64 => mem_read64(addr),
  };
  write_gpr(dst, os, v);
  Ok(())
}

// MOV mem, reg
val exec_mov_mem_reg : (qword, gpr_idx, OperandSize) -> ExecutionResult
function exec_mov_mem_reg(addr, src, os) = {
  let v = read_gpr(src, os);
  match os {
    OS8  => mem_write8(addr, v[7..0]),
    OS16 => mem_write16(addr, v[15..0]),
    OS32 => mem_write32(addr, v[31..0]),
    OS64 => mem_write64(addr, v),
  };
  Ok(())
}

// MOV mem, imm
val exec_mov_mem_imm : (qword, qword, OperandSize) -> ExecutionResult
function exec_mov_mem_imm(addr, imm, os) = {
  match os {
    OS8  => mem_write8(addr, imm[7..0]),
    OS16 => mem_write16(addr, imm[15..0]),
    OS32 => mem_write32(addr, imm[31..0]),
    OS64 => mem_write64(addr, imm),
  };
  Ok(())
}

// MOV Sreg, r/m16 — Move to segment register.
// In long mode, only the low 16 bits are used.
// Loading CS is not allowed (#UD).
val exec_mov_segreg_from_rm : (segreg_idx, word) -> ExecutionResult
function exec_mov_segreg_from_rm(seg, selector) = {
  if seg == CS then raise_UD()
  else {
    // TODO: In protected mode, loading a segment register triggers
    // descriptor validation (see Operation pseudocode in SDM).
    // For now we just load the selector directly.
    write_segreg(seg, selector);
    Ok(())
  }
}

// MOV r/m16, Sreg — Move from segment register.
// The 16-bit segment selector is zero-extended to the operand size.
val exec_mov_rm_from_segreg : (gpr_idx, segreg_idx, OperandSize) -> ExecutionResult
function exec_mov_rm_from_segreg(dst, seg, os) = {
  let selector : qword = zero_extend(read_segreg(seg));
  write_gpr(dst, os, selector);
  Ok(())
}

// MOV r/m16, Sreg — store to memory variant (always 16-bit write).
val exec_mov_mem_from_segreg : (qword, segreg_idx) -> ExecutionResult
function exec_mov_mem_from_segreg(addr, seg) = {
  mem_write16(addr, read_segreg(seg));
  Ok(())
}

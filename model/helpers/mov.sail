// MOV — Move
//
// Copies the source operand to the destination operand.
// No flags are affected.

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

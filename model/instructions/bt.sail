// BT — Bit Test
//
// CF := selected bit from bit base. OF, SF, AF, PF undefined.

// BT reg, reg (bit offset taken modulo operand size)
val exec_bt_reg_reg : (gpr_idx, gpr_idx, OperandSize) -> ExecutionResult
function exec_bt_reg_reg(base, offset, os) = {
  let base_val : qword = read_gpr(base, os);
  let off_val : range(0, 63) = unsigned(read_gpr(offset, os)) % operand_size_bits(os);
  CF = base_val[off_val];
  Ok(())
}

// BT reg, imm8 (bit offset taken modulo operand size)
val exec_bt_reg_imm : (gpr_idx, byte, OperandSize) -> ExecutionResult
function exec_bt_reg_imm(base, imm, os) = {
  let base_val : qword = read_gpr(base, os);
  let off_val : range(0, 63) = unsigned(imm) % operand_size_bits(os);
  CF = base_val[off_val];
  Ok(())
}

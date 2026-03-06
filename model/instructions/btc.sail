// BTC — Bit Test and Complement
//
// CF := selected bit, then complement that bit. OF, SF, AF, PF undefined.

val exec_btc_reg_reg : (gpr_idx, gpr_idx, OperandSize) -> ExecutionResult
function exec_btc_reg_reg(base, offset, os) = {
  let base_val : qword = read_gpr(base, os);
  let off_val : range(0, 63) = unsigned(read_gpr(offset, os)) % operand_size_bits(os);
  CF = base_val[off_val];
  var result : qword = base_val;
  result[off_val] = if base_val[off_val] == bitone then bitzero else bitone;
  write_gpr(base, os, result);
  Ok(())
}

val exec_btc_reg_imm : (gpr_idx, byte, OperandSize) -> ExecutionResult
function exec_btc_reg_imm(base, imm, os) = {
  let base_val : qword = read_gpr(base, os);
  let off_val : range(0, 63) = unsigned(imm) % operand_size_bits(os);
  CF = base_val[off_val];
  var result : qword = base_val;
  result[off_val] = if base_val[off_val] == bitone then bitzero else bitone;
  write_gpr(base, os, result);
  Ok(())
}

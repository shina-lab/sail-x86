// TZCNT — Count the Number of Trailing Zero Bits
//
// Counts trailing zeros in source. If source is zero, result = operand size.
// CF set if source is zero, ZF set if result is zero.
// OF, SF, PF, AF undefined.

val exec_tzcnt : (gpr_idx, gpr_idx, OperandSize) -> ExecutionResult
function exec_tzcnt(dst, src, os) = {
  let src_val : qword = read_gpr(src, os);
  let os_bits : {8, 16, 32, 64} = operand_size_bits(os);
  // Reuse bsf64 which scans from bit 0 upward
  let is_zero : bool = match os {
    OS8  => src_val[7..0] == zeros(),
    OS16 => src_val[15..0] == zeros(),
    OS32 => src_val[31..0] == zeros(),
    OS64 => src_val == zeros(),
  };
  let count : int = if is_zero then os_bits
                    else bsf64(src_val, 0);
  write_gpr(dst, os, to_bits_truncate(count));
  CF = if is_zero then bitone else bitzero;
  ZF = if count == 0 then bitone else bitzero;
  Ok(())
}

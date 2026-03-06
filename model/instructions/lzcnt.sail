// LZCNT — Count the Number of Leading Zero Bits
//
// Counts leading zeros in source. If source is zero, result = operand size.
// CF set if source is zero, ZF set if result is zero.
// OF, SF, PF, AF undefined.

val lzcnt64 : (qword, range(0, 63)) -> range(0, 64)
function lzcnt64(v, idx) =
  if idx == 0 then (if bit_to_bool(v[idx]) then 0 else 64)
  else if bit_to_bool(v[idx]) then 63 - idx
  else lzcnt64(v, idx - 1)

val exec_lzcnt : (gpr_idx, gpr_idx, OperandSize) -> ExecutionResult
function exec_lzcnt(dst, src, os) = {
  let src_val : qword = read_gpr(src, os);
  let os_bits : {8, 16, 32, 64} = operand_size_bits(os);
  let count : range(0, 64) = match os {
    OS8  => lzcnt64(zero_extend(src_val[7..0]), 7),
    OS16 => lzcnt64(zero_extend(src_val[15..0]), 15),
    OS32 => lzcnt64(zero_extend(src_val[31..0]), 31),
    OS64 => lzcnt64(src_val, 63),
  };
  write_gpr(dst, os, to_bits_truncate(count));
  CF = if count == os_bits then bitone else bitzero;
  ZF = if count == 0 then bitone else bitzero;
  Ok(())
}

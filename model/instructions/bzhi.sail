// BZHI — Zero High Bits Starting with Specified Bit Position (BMI2)
//
// Copy SRC1, zero bits from position N (SRC2[7:0]) upward.
// CF set if N > OperandSize-1. ZF, SF from result. OF cleared.
// Only 32/64-bit operand sizes.

val exec_bzhi : (gpr_idx, gpr_idx, gpr_idx, OperandSize) -> ExecutionResult
function exec_bzhi(dst, src1, src2, os) = {
  let src_val : qword = read_gpr(src1, os);
  let n : range(0, 255) = unsigned(read_gpr(src2, os)[7..0]);
  let os_bits : int = operand_size_bits(os);
  let result : qword =
    if n >= os_bits then src_val
    else src_val & to_bits_truncate((2 ^ n) - 1);
  CF = if n > os_bits - 1 then bitone else bitzero;
  OF = bitzero;
  match os {
    OS32 => {
      SF = result[31];
      ZF = if result[31..0] == zeros() then bitone else bitzero;
    },
    OS64 => {
      SF = result[63];
      ZF = if result == zeros() then bitone else bitzero;
    },
    _ => (),
  };
  write_gpr(dst, os, result);
  Ok(())
}

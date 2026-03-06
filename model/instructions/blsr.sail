// BLSR — Reset Lowest Set Bit (BMI1)
//
// DEST := (SRC - 1) AND SRC. Clears the lowest set bit.
// SF from MSB, ZF from result, CF=1 if SRC=0, OF cleared.
// Only 32/64-bit operand sizes.

val exec_blsr : (gpr_idx, gpr_idx, OperandSize) -> ExecutionResult
function exec_blsr(dst, src, os) = {
  let src_val : qword = read_gpr(src, os);
  let result : qword = (src_val - 1) & src_val;
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
  CF = if src_val == zeros() then bitone else bitzero;
  OF = bitzero;
  write_gpr(dst, os, result);
  Ok(())
}

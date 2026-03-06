// BLSI — Extract Lowest Set Isolated Bit (BMI1)
//
// DEST := (-SRC) AND SRC. Isolates the lowest set bit.
// SF from MSB, ZF from result, CF=1 if SRC!=0, OF cleared.
// Only 32/64-bit operand sizes.

val exec_blsi : (gpr_idx, gpr_idx, OperandSize) -> ExecutionResult
function exec_blsi(dst, src, os) = {
  let src_val : qword = read_gpr(src, os);
  let neg_src : qword = zeros() - src_val;
  let result : qword = neg_src & src_val;
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
  CF = if src_val != zeros() then bitone else bitzero;
  OF = bitzero;
  write_gpr(dst, os, result);
  Ok(())
}

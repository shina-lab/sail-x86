// BLSMSK — Get Mask Up to Lowest Set Bit (BMI1)
//
// DEST := (SRC - 1) XOR SRC.
// SF from MSB, ZF cleared, CF=1 if SRC=0, OF cleared.
// Only 32/64-bit operand sizes.

val exec_blsmsk : (gpr_idx, gpr_idx, OperandSize) -> ExecutionResult
function exec_blsmsk(dst, src, os) = {
  let src_val : qword = read_gpr(src, os);
  let result : qword = (src_val - 1) ^ src_val;
  match os {
    OS32 => SF = result[31],
    OS64 => SF = result[63],
    _ => (),
  };
  ZF = bitzero;
  CF = if src_val == zeros() then bitone else bitzero;
  OF = bitzero;
  write_gpr(dst, os, result);
  Ok(())
}

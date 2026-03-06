// ANDN — Logical AND NOT (BMI1)
//
// DEST := (NOT SRC1) AND SRC2.
// SF and ZF set from result. OF and CF cleared. AF and PF undefined.
// Only 32-bit and 64-bit operand sizes.

val exec_andn : (gpr_idx, gpr_idx, gpr_idx, OperandSize) -> ExecutionResult
function exec_andn(dst, src1, src2, os) = {
  let a : qword = read_gpr(src1, os);
  let b : qword = read_gpr(src2, os);
  let result : qword = (~(a)) & b;
  match os {
    OS32 => update_flags_logic(result[31..0]),
    OS64 => update_flags_logic(result),
    _ => (),
  };
  write_gpr(dst, os, result);
  Ok(())
}

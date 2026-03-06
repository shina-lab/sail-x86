// CMP — Compare Two Operands
//
// Computes dest - src (subtract without storing result) and updates RFLAGS.
// The OF, SF, ZF, AF, CF, and PF flags are set according to the result.

// CMP reg, reg
val exec_cmp_reg_reg : (gpr_idx, gpr_idx, OperandSize) -> ExecutionResult
function exec_cmp_reg_reg(dst, src, os) = {
  let a : qword = read_gpr(dst, os);
  let b : qword = read_gpr(src, os);
  let result : qword = a - b;
  match os {
    OS8  => update_flags_sub(result[7..0], a[7..0], b[7..0]),
    OS16 => update_flags_sub(result[15..0], a[15..0], b[15..0]),
    OS32 => update_flags_sub(result[31..0], a[31..0], b[31..0]),
    OS64 => update_flags_sub(result, a, b),
  };
  Ok(())
}

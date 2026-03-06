// ADD — Add
//
// Computes dest := dest + src and updates RFLAGS.
// The OF, SF, ZF, AF, CF, and PF flags are set according to the result.

// ADD reg, reg
val exec_add_reg_reg : (gpr_idx, gpr_idx, OperandSize) -> ExecutionResult
function exec_add_reg_reg(dst, src, os) = {
  let a : qword = read_gpr(dst, os);
  let b : qword = read_gpr(src, os);
  let result : qword = a + b;
  match os {
    OS8  => update_flags_add(result[7..0], a[7..0], b[7..0]),
    OS16 => update_flags_add(result[15..0], a[15..0], b[15..0]),
    OS32 => update_flags_add(result[31..0], a[31..0], b[31..0]),
    OS64 => update_flags_add(result, a, b),
  };
  write_gpr(dst, os, result);
  Ok(())
}

// ADD reg, imm
val exec_add_reg_imm : (gpr_idx, qword, OperandSize) -> ExecutionResult
function exec_add_reg_imm(dst, imm, os) = {
  let a : qword = read_gpr(dst, os);
  let result : qword = a + imm;
  match os {
    OS8  => update_flags_add(result[7..0], a[7..0], imm[7..0]),
    OS16 => update_flags_add(result[15..0], a[15..0], imm[15..0]),
    OS32 => update_flags_add(result[31..0], a[31..0], imm[31..0]),
    OS64 => update_flags_add(result, a, imm),
  };
  write_gpr(dst, os, result);
  Ok(())
}

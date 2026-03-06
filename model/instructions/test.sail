// TEST — Logical Compare
//
// Computes AND of two operands without storing result, updates RFLAGS.
// OF and CF cleared; SF, ZF, PF set according to result; AF undefined.

// TEST reg, reg
val exec_test_reg_reg : (gpr_idx, gpr_idx, OperandSize) -> ExecutionResult
function exec_test_reg_reg(dst, src, os) = {
  let a : qword = read_gpr(dst, os);
  let b : qword = read_gpr(src, os);
  let result : qword = a & b;
  match os {
    OS8  => update_flags_logic(result[7..0]),
    OS16 => update_flags_logic(result[15..0]),
    OS32 => update_flags_logic(result[31..0]),
    OS64 => update_flags_logic(result),
  };
  Ok(())
}

// TEST reg, imm
val exec_test_reg_imm : (gpr_idx, qword, OperandSize) -> ExecutionResult
function exec_test_reg_imm(dst, imm, os) = {
  let a : qword = read_gpr(dst, os);
  let result : qword = a & imm;
  match os {
    OS8  => update_flags_logic(result[7..0]),
    OS16 => update_flags_logic(result[15..0]),
    OS32 => update_flags_logic(result[31..0]),
    OS64 => update_flags_logic(result),
  };
  Ok(())
}

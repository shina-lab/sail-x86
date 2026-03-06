// DEC — Decrement by 1
//
// Computes dest := dest - 1. Updates OF, SF, ZF, AF, PF. CF unchanged.

val exec_dec : (gpr_idx, OperandSize) -> ExecutionResult
function exec_dec(dst, os) = {
  let a : qword = read_gpr(dst, os);
  let one : qword = zero_extend(0b1 : bits(1));
  let result : qword = a - one;
  let saved_cf : bit = CF;
  match os {
    OS8  => update_flags_sub(result[7..0], a[7..0], one[7..0]),
    OS16 => update_flags_sub(result[15..0], a[15..0], one[15..0]),
    OS32 => update_flags_sub(result[31..0], a[31..0], one[31..0]),
    OS64 => update_flags_sub(result, a, one),
  };
  CF = saved_cf;
  write_gpr(dst, os, result);
  Ok(())
}

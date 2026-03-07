// DEC — Decrement by 1
//
// Computes dest := dest - 1. Updates OF, SF, ZF, AF, PF. CF unchanged.

val exec_dec : (qword, OperandSize) -> (ExecutionResult, qword)
function exec_dec(a, os) = {
  let one : qword = zero_extend(0b1 : bits(1));
  let result : qword = a - one;
  match os {
    OS8  => update_flags_sub_no_cf(result[7..0], a[7..0], one[7..0]),
    OS16 => update_flags_sub_no_cf(result[15..0], a[15..0], one[15..0]),
    OS32 => update_flags_sub_no_cf(result[31..0], a[31..0], one[31..0]),
    OS64 => update_flags_sub_no_cf(result, a, one),
  };
  (Ok(()), result)
}

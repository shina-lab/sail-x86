// XADD — Exchange and Add
//
// Exchanges dst and src, then stores sum in dst.
// TEMP := SRC + DEST; SRC := DEST; DEST := TEMP.
// Flags set from the addition.

val exec_xadd : (gpr_idx, gpr_idx, OperandSize) -> ExecutionResult
function exec_xadd(dst, src, os) = {
  let a : qword = read_gpr(dst, os);
  let b : qword = read_gpr(src, os);
  let sum : qword = a + b;
  match os {
    OS8  => update_flags_add(sum[7..0], a[7..0], b[7..0]),
    OS16 => update_flags_add(sum[15..0], a[15..0], b[15..0]),
    OS32 => update_flags_add(sum[31..0], a[31..0], b[31..0]),
    OS64 => update_flags_add(sum, a, b),
  };
  write_gpr(src, os, a);
  write_gpr(dst, os, sum);
  Ok(())
}

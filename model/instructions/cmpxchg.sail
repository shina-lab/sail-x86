// CMPXCHG — Compare and Exchange
//
// Compares accumulator with dst. If equal, ZF=1 and src is loaded into dst.
// Otherwise, ZF=0 and dst is loaded into accumulator.
// CF, PF, AF, SF, OF set from the comparison (as if SUB accumulator, dst).

val exec_cmpxchg : (gpr_idx, gpr_idx, OperandSize) -> ExecutionResult
function exec_cmpxchg(dst, src, os) = {
  let acc : qword = read_gpr(RAX, os);
  let dst_val : qword = read_gpr(dst, os);
  // Flags set as if comparing accumulator - dst_val
  match os {
    OS8  => update_flags_sub(acc[7..0] - dst_val[7..0], acc[7..0], dst_val[7..0]),
    OS16 => update_flags_sub(acc[15..0] - dst_val[15..0], acc[15..0], dst_val[15..0]),
    OS32 => update_flags_sub(acc[31..0] - dst_val[31..0], acc[31..0], dst_val[31..0]),
    OS64 => update_flags_sub(acc - dst_val, acc, dst_val),
  };
  if acc == dst_val then {
    write_gpr(dst, os, read_gpr(src, os));
  } else {
    write_gpr(RAX, os, dst_val);
    write_gpr(dst, os, dst_val);
  };
  Ok(())
}

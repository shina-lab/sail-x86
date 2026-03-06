// NEG — Two's Complement Negation
//
// Computes dest := 0 - dest (two's complement negation).
// CF set to 0 if source is 0, else 1. OF, SF, ZF, AF, PF set per result.

val exec_neg : (gpr_idx, OperandSize) -> ExecutionResult
function exec_neg(dst, os) = {
  let a : qword = read_gpr(dst, os);
  let z : qword = zeros();
  let result : qword = z - a;
  match os {
    OS8  => update_flags_sub(result[7..0], z[7..0], a[7..0]),
    OS16 => update_flags_sub(result[15..0], z[15..0], a[15..0]),
    OS32 => update_flags_sub(result[31..0], z[31..0], a[31..0]),
    OS64 => update_flags_sub(result, z, a),
  };
  write_gpr(dst, os, result);
  Ok(())
}

// CMOVcc — Conditional Move
//
// If condition is met, move source to destination. No flags affected.

val exec_cmovcc : (cc_idx, gpr_idx, gpr_idx, OperandSize) -> ExecutionResult
function exec_cmovcc(cc, dst, src, os) = {
  if eval_cc(cc) then {
    let v : qword = read_gpr(src, os);
    write_gpr(dst, os, v);
  };
  Ok(())
}

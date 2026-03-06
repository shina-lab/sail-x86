// SETcc — Set Byte on Condition
//
// Sets the destination byte to 1 if condition is met, 0 otherwise.
// No flags affected.

val exec_setcc : (cc_idx, gpr_idx) -> ExecutionResult
function exec_setcc(cc, dst) = {
  let v : byte = if eval_cc(cc) then 0x01 else 0x00;
  write_gpr8l(dst, v);
  Ok(())
}

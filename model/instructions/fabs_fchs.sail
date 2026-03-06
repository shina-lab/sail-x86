// FABS — Absolute Value
// FCHS — Change Sign
//
// These instructions operate on ST(0) in-place.

// FABS — Replace ST(0) with its absolute value.
val exec_fabs : unit -> ExecutionResult
function exec_fabs() = {
  let result : fp80 = __f80_abs(__x87_read_st(0));
  __x87_write_st(0, result);
  Ok(())
}

// FCHS — Negate ST(0) (change its sign).
val exec_fchs : unit -> ExecutionResult
function exec_fchs() = {
  let result : fp80 = __f80_chs(__x87_read_st(0));
  __x87_write_st(0, result);
  Ok(())
}

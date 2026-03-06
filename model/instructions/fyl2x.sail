// FYL2X -- Compute y * log2(x)
//
// Computes ST(1) * log2(ST(0)), stores result in ST(1), then pops.
// After the operation, ST(0) contains the result.

val exec_fyl2x : unit -> ExecutionResult
function exec_fyl2x() = {
  let x : fp80 = __x87_read_st(0);
  let y : fp80 = __x87_read_st(1);
  let result : fp80 = __f80_yl2x(y, x);
  let _ = __x87_pop();
  __x87_write_st(0, result);
  Ok(())
}

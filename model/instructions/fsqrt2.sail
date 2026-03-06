// FSQRT — Square Root
//
// Computes the square root of ST(0) and stores the result in ST(0).

val exec_fsqrt : unit -> ExecutionResult
function exec_fsqrt() = {
  let result : fp80 = __f80_sqrt(__x87_read_st(0));
  __x87_write_st(0, result);
  Ok(())
}

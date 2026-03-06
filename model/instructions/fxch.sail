// FXCH — Exchange Register Contents
//
// Exchanges the contents of ST(0) and ST(i).

val exec_fxch : int -> ExecutionResult
function exec_fxch(i) = {
  let v0 : fp80 = __x87_read_st(0);
  let vi : fp80 = __x87_read_st(i);
  __x87_write_st(0, vi);
  __x87_write_st(i, v0);
  Ok(())
}

// FXTRACT -- Extract Exponent and Significand
//
// Separates ST(0) into its exponent and significand.
// The exponent replaces ST(0), then the significand is pushed onto the stack.
// After the operation, ST(0) = significand, ST(1) = exponent.

val exec_fxtract : unit -> ExecutionResult
function exec_fxtract() = {
  let val80 : fp80 = __x87_read_st(0);
  let exponent : fp80 = __f80_extract_exponent(val80);
  let significand : fp80 = __f80_extract_significand(val80);
  __x87_write_st(0, exponent);
  __x87_push(significand);
  Ok(())
}

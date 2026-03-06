// FBLD — Load Binary Coded Decimal
//
// Converts an 80-bit packed BCD value from memory to extended-precision
// floating-point and pushes it onto the FPU stack.

val exec_fbld : fp80 -> ExecutionResult
function exec_fbld(src) = {
  let val80 : fp80 = __f80_from_bcd(src);
  __x87_push(val80);
  Ok(())
}

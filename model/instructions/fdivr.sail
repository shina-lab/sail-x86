// FDIVR/FDIVRP/FIDIVR — Reverse Divide (integer operand forms)
// FIADD/FIMUL/FIDIV i16 forms not covered by fadd/fmul/fdiv.sail.

// FIDIVR m16int — ST(0) = int16 / ST(0) (reversed).
val exec_fidivr_i16 : word -> ExecutionResult
function exec_fidivr_i16(val16) = {
  let src : fp80 = __f80_from_int16(val16);
  let result : fp80 = __f80_div(src, __x87_read_st(0));
  __x87_write_st(0, result);
  Ok(())
}

// FIDIV m16int — ST(0) = ST(0) / int16.
val exec_fidiv_i16 : word -> ExecutionResult
function exec_fidiv_i16(val16) = {
  let src : fp80 = __f80_from_int16(val16);
  let result : fp80 = __f80_div(__x87_read_st(0), src);
  __x87_write_st(0, result);
  Ok(())
}

// FIADD m16int — ST(0) = ST(0) + int16.
val exec_fiadd_i16 : word -> ExecutionResult
function exec_fiadd_i16(val16) = {
  let src : fp80 = __f80_from_int16(val16);
  let result : fp80 = __f80_add(__x87_read_st(0), src);
  __x87_write_st(0, result);
  Ok(())
}

// FIMUL m16int — ST(0) = ST(0) * int16.
val exec_fimul_i16 : word -> ExecutionResult
function exec_fimul_i16(val16) = {
  let src : fp80 = __f80_from_int16(val16);
  let result : fp80 = __f80_mul(__x87_read_st(0), src);
  __x87_write_st(0, result);
  Ok(())
}

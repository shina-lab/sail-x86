// FADD/FADDP/FIADD — Add Floating-Point
//
// Adds two floating-point values and stores the result.

// FADD ST(0), ST(i) — ST(0) = ST(0) + ST(i).
val exec_fadd_st0_sti : int -> ExecutionResult
function exec_fadd_st0_sti(i) = {
  let result : fp80 = __f80_add(__x87_read_st(0), __x87_read_st(i));
  __x87_write_st(0, result);
  Ok(())
}

// FADD ST(i), ST(0) — ST(i) = ST(i) + ST(0).
val exec_fadd_sti_st0 : int -> ExecutionResult
function exec_fadd_sti_st0(i) = {
  let result : fp80 = __f80_add(__x87_read_st(i), __x87_read_st(0));
  __x87_write_st(i, result);
  Ok(())
}

// FADDP ST(i), ST(0) — ST(i) = ST(i) + ST(0), then pop.
val exec_faddp_sti : int -> ExecutionResult
function exec_faddp_sti(i) = {
  let result : fp80 = __f80_add(__x87_read_st(i), __x87_read_st(0));
  let _ = __x87_pop();
  __x87_write_st(i - 1, result);
  Ok(())
}

// FADD m32fp — ST(0) = ST(0) + float32.
val exec_fadd_f32 : dword -> ExecutionResult
function exec_fadd_f32(val32) = {
  let src : fp80 = __f80_from_f32(val32);
  let result : fp80 = __f80_add(__x87_read_st(0), src);
  __x87_write_st(0, result);
  Ok(())
}

// FADD m64fp — ST(0) = ST(0) + float64.
val exec_fadd_f64 : qword -> ExecutionResult
function exec_fadd_f64(val64) = {
  let src : fp80 = __f80_from_f64(val64);
  let result : fp80 = __f80_add(__x87_read_st(0), src);
  __x87_write_st(0, result);
  Ok(())
}

// FIADD m32int — ST(0) = ST(0) + int32.
val exec_fiadd_i32 : dword -> ExecutionResult
function exec_fiadd_i32(val32) = {
  let src : fp80 = __f80_from_int32(val32);
  let result : fp80 = __f80_add(__x87_read_st(0), src);
  __x87_write_st(0, result);
  Ok(())
}

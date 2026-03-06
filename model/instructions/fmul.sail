// FMUL/FMULP/FIMUL — Multiply Floating-Point
//
// Multiplies two floating-point values and stores the result.

// FMUL ST(0), ST(i) — ST(0) = ST(0) * ST(i).
val exec_fmul_st0_sti : int -> ExecutionResult
function exec_fmul_st0_sti(i) = {
  let result : fp80 = __f80_mul(__x87_read_st(0), __x87_read_st(i));
  __x87_write_st(0, result);
  Ok(())
}

// FMUL ST(i), ST(0) — ST(i) = ST(i) * ST(0).
val exec_fmul_sti_st0 : int -> ExecutionResult
function exec_fmul_sti_st0(i) = {
  let result : fp80 = __f80_mul(__x87_read_st(i), __x87_read_st(0));
  __x87_write_st(i, result);
  Ok(())
}

// FMULP ST(i), ST(0) — ST(i) = ST(i) * ST(0), then pop.
val exec_fmulp_sti : int -> ExecutionResult
function exec_fmulp_sti(i) = {
  let result : fp80 = __f80_mul(__x87_read_st(i), __x87_read_st(0));
  let _ = __x87_pop();
  __x87_write_st(i - 1, result);
  Ok(())
}

// FMUL m32fp — ST(0) = ST(0) * float32.
val exec_fmul_f32 : dword -> ExecutionResult
function exec_fmul_f32(val32) = {
  let src : fp80 = __f80_from_f32(val32);
  let result : fp80 = __f80_mul(__x87_read_st(0), src);
  __x87_write_st(0, result);
  Ok(())
}

// FMUL m64fp — ST(0) = ST(0) * float64.
val exec_fmul_f64 : qword -> ExecutionResult
function exec_fmul_f64(val64) = {
  let src : fp80 = __f80_from_f64(val64);
  let result : fp80 = __f80_mul(__x87_read_st(0), src);
  __x87_write_st(0, result);
  Ok(())
}

// FIMUL m32int — ST(0) = ST(0) * int32.
val exec_fimul_i32 : dword -> ExecutionResult
function exec_fimul_i32(val32) = {
  let src : fp80 = __f80_from_int32(val32);
  let result : fp80 = __f80_mul(__x87_read_st(0), src);
  __x87_write_st(0, result);
  Ok(())
}

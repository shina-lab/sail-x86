// FDIV/FDIVP/FDIVR/FDIVRP — Divide Floating-Point
//
// Divides floating-point values. The "R" (reverse) variants swap operand order.

// FDIV ST(0), ST(i) — ST(0) = ST(0) / ST(i).
val exec_fdiv_st0_sti : int -> ExecutionResult
function exec_fdiv_st0_sti(i) = {
  let result : fp80 = __f80_div(__x87_read_st(0), __x87_read_st(i));
  __x87_write_st(0, result);
  Ok(())
}

// FDIV ST(i), ST(0) — ST(i) = ST(i) / ST(0).
val exec_fdiv_sti_st0 : int -> ExecutionResult
function exec_fdiv_sti_st0(i) = {
  let result : fp80 = __f80_div(__x87_read_st(i), __x87_read_st(0));
  __x87_write_st(i, result);
  Ok(())
}

// FDIVP ST(i), ST(0) — ST(i) = ST(i) / ST(0), then pop.
val exec_fdivp_sti : int -> ExecutionResult
function exec_fdivp_sti(i) = {
  let result : fp80 = __f80_div(__x87_read_st(i), __x87_read_st(0));
  let _ = __x87_pop();
  __x87_write_st(i - 1, result);
  Ok(())
}

// FDIVR ST(0), ST(i) — ST(0) = ST(i) / ST(0) (reversed).
val exec_fdivr_st0_sti : int -> ExecutionResult
function exec_fdivr_st0_sti(i) = {
  let result : fp80 = __f80_div(__x87_read_st(i), __x87_read_st(0));
  __x87_write_st(0, result);
  Ok(())
}

// FDIVR ST(i), ST(0) — ST(i) = ST(0) / ST(i) (reversed).
val exec_fdivr_sti_st0 : int -> ExecutionResult
function exec_fdivr_sti_st0(i) = {
  let result : fp80 = __f80_div(__x87_read_st(0), __x87_read_st(i));
  __x87_write_st(i, result);
  Ok(())
}

// FDIVRP ST(i), ST(0) — ST(i) = ST(0) / ST(i) (reversed), then pop.
val exec_fdivrp_sti : int -> ExecutionResult
function exec_fdivrp_sti(i) = {
  let result : fp80 = __f80_div(__x87_read_st(0), __x87_read_st(i));
  let _ = __x87_pop();
  __x87_write_st(i - 1, result);
  Ok(())
}

// FDIV m32fp — ST(0) = ST(0) / float32.
val exec_fdiv_f32 : dword -> ExecutionResult
function exec_fdiv_f32(val32) = {
  let src : fp80 = __f80_from_f32(val32);
  let result : fp80 = __f80_div(__x87_read_st(0), src);
  __x87_write_st(0, result);
  Ok(())
}

// FDIV m64fp — ST(0) = ST(0) / float64.
val exec_fdiv_f64 : qword -> ExecutionResult
function exec_fdiv_f64(val64) = {
  let src : fp80 = __f80_from_f64(val64);
  let result : fp80 = __f80_div(__x87_read_st(0), src);
  __x87_write_st(0, result);
  Ok(())
}

// FDIVR m32fp — ST(0) = float32 / ST(0) (reversed).
val exec_fdivr_f32 : dword -> ExecutionResult
function exec_fdivr_f32(val32) = {
  let src : fp80 = __f80_from_f32(val32);
  let result : fp80 = __f80_div(src, __x87_read_st(0));
  __x87_write_st(0, result);
  Ok(())
}

// FDIVR m64fp — ST(0) = float64 / ST(0) (reversed).
val exec_fdivr_f64 : qword -> ExecutionResult
function exec_fdivr_f64(val64) = {
  let src : fp80 = __f80_from_f64(val64);
  let result : fp80 = __f80_div(src, __x87_read_st(0));
  __x87_write_st(0, result);
  Ok(())
}

// FIDIV m32int — ST(0) = ST(0) / int32.
val exec_fidiv_i32 : dword -> ExecutionResult
function exec_fidiv_i32(val32) = {
  let src : fp80 = __f80_from_int32(val32);
  let result : fp80 = __f80_div(__x87_read_st(0), src);
  __x87_write_st(0, result);
  Ok(())
}

// FIDIVR m32int — ST(0) = int32 / ST(0) (reversed).
val exec_fidivr_i32 : dword -> ExecutionResult
function exec_fidivr_i32(val32) = {
  let src : fp80 = __f80_from_int32(val32);
  let result : fp80 = __f80_div(src, __x87_read_st(0));
  __x87_write_st(0, result);
  Ok(())
}

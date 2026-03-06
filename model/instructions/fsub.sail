// FSUB/FSUBP/FISUB/FSUBR/FSUBRP/FISUBR — Subtract Floating-Point
//
// Subtracts floating-point values. The "R" (reverse) variants swap operand order.
// The "I" variants convert integer memory operands to extended precision first.

// FSUB ST(0), ST(i) — ST(0) = ST(0) - ST(i).
val exec_fsub_st0_sti : int -> ExecutionResult
function exec_fsub_st0_sti(i) = {
  let result : fp80 = __f80_sub(__x87_read_st(0), __x87_read_st(i));
  __x87_write_st(0, result);
  Ok(())
}

// FSUB ST(i), ST(0) — ST(i) = ST(i) - ST(0).
val exec_fsub_sti_st0 : int -> ExecutionResult
function exec_fsub_sti_st0(i) = {
  let result : fp80 = __f80_sub(__x87_read_st(i), __x87_read_st(0));
  __x87_write_st(i, result);
  Ok(())
}

// FSUBP ST(i), ST(0) — ST(i) = ST(i) - ST(0), then pop.
val exec_fsubp_sti : int -> ExecutionResult
function exec_fsubp_sti(i) = {
  let result : fp80 = __f80_sub(__x87_read_st(i), __x87_read_st(0));
  let _ = __x87_pop();
  __x87_write_st(i - 1, result);
  Ok(())
}

// FSUBR ST(0), ST(i) — ST(0) = ST(i) - ST(0) (reversed).
val exec_fsubr_st0_sti : int -> ExecutionResult
function exec_fsubr_st0_sti(i) = {
  let result : fp80 = __f80_sub(__x87_read_st(i), __x87_read_st(0));
  __x87_write_st(0, result);
  Ok(())
}

// FSUBR ST(i), ST(0) — ST(i) = ST(0) - ST(i) (reversed).
val exec_fsubr_sti_st0 : int -> ExecutionResult
function exec_fsubr_sti_st0(i) = {
  let result : fp80 = __f80_sub(__x87_read_st(0), __x87_read_st(i));
  __x87_write_st(i, result);
  Ok(())
}

// FSUBRP ST(i), ST(0) — ST(i) = ST(0) - ST(i) (reversed), then pop.
val exec_fsubrp_sti : int -> ExecutionResult
function exec_fsubrp_sti(i) = {
  let result : fp80 = __f80_sub(__x87_read_st(0), __x87_read_st(i));
  let _ = __x87_pop();
  __x87_write_st(i - 1, result);
  Ok(())
}

// FSUB m32fp — ST(0) = ST(0) - float32.
val exec_fsub_f32 : dword -> ExecutionResult
function exec_fsub_f32(val32) = {
  let src : fp80 = __f80_from_f32(val32);
  let result : fp80 = __f80_sub(__x87_read_st(0), src);
  __x87_write_st(0, result);
  Ok(())
}

// FSUB m64fp — ST(0) = ST(0) - float64.
val exec_fsub_f64 : qword -> ExecutionResult
function exec_fsub_f64(val64) = {
  let src : fp80 = __f80_from_f64(val64);
  let result : fp80 = __f80_sub(__x87_read_st(0), src);
  __x87_write_st(0, result);
  Ok(())
}

// FSUBR m32fp — ST(0) = float32 - ST(0) (reversed).
val exec_fsubr_f32 : dword -> ExecutionResult
function exec_fsubr_f32(val32) = {
  let src : fp80 = __f80_from_f32(val32);
  let result : fp80 = __f80_sub(src, __x87_read_st(0));
  __x87_write_st(0, result);
  Ok(())
}

// FSUBR m64fp — ST(0) = float64 - ST(0) (reversed).
val exec_fsubr_f64 : qword -> ExecutionResult
function exec_fsubr_f64(val64) = {
  let src : fp80 = __f80_from_f64(val64);
  let result : fp80 = __f80_sub(src, __x87_read_st(0));
  __x87_write_st(0, result);
  Ok(())
}

// FISUB m32int — ST(0) = ST(0) - int32.
val exec_fisub_i32 : dword -> ExecutionResult
function exec_fisub_i32(val32) = {
  let src : fp80 = __f80_from_int32(val32);
  let result : fp80 = __f80_sub(__x87_read_st(0), src);
  __x87_write_st(0, result);
  Ok(())
}

// FISUB m16int — ST(0) = ST(0) - int16.
val exec_fisub_i16 : word -> ExecutionResult
function exec_fisub_i16(val16) = {
  let src : fp80 = __f80_from_int32(sign_extend(val16));
  let result : fp80 = __f80_sub(__x87_read_st(0), src);
  __x87_write_st(0, result);
  Ok(())
}

// FISUBR m32int — ST(0) = int32 - ST(0) (reversed).
val exec_fisubr_i32 : dword -> ExecutionResult
function exec_fisubr_i32(val32) = {
  let src : fp80 = __f80_from_int32(val32);
  let result : fp80 = __f80_sub(src, __x87_read_st(0));
  __x87_write_st(0, result);
  Ok(())
}

// FISUBR m16int — ST(0) = int16 - ST(0) (reversed).
val exec_fisubr_i16 : word -> ExecutionResult
function exec_fisubr_i16(val16) = {
  let src : fp80 = __f80_from_int32(sign_extend(val16));
  let result : fp80 = __f80_sub(src, __x87_read_st(0));
  __x87_write_st(0, result);
  Ok(())
}

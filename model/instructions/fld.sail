// FLD — Load Floating-Point Value
//
// Pushes a floating-point value onto the x87 FPU stack.
// Source can be ST(i), or a 32/64/80-bit memory operand.

// FLD ST(i) — push ST(i) onto the stack.
val exec_fld_st : int -> ExecutionResult
function exec_fld_st(i) = {
  let v : fp80 = __x87_read_st(i);
  __x87_push(v);
  Ok(())
}

// FLD m32fp — load 32-bit float, convert to 80-bit, push.
val exec_fld_f32 : dword -> ExecutionResult
function exec_fld_f32(val32) = {
  __x87_push(__f80_from_f32(val32));
  Ok(())
}

// FLD m64fp — load 64-bit float, convert to 80-bit, push.
val exec_fld_f64 : qword -> ExecutionResult
function exec_fld_f64(val64) = {
  __x87_push(__f80_from_f64(val64));
  Ok(())
}

// FLD m80fp — load 80-bit extended precision, push directly.
val exec_fld_f80 : fp80 -> ExecutionResult
function exec_fld_f80(val80) = {
  __x87_push(val80);
  Ok(())
}

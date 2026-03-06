// FILD — Load Integer
//
// Converts a signed integer source operand into extended-precision
// floating-point format and pushes the value onto the FPU stack.

// FILD m16int — push int16 converted to f80.
val exec_fild_i16 : word -> ExecutionResult
function exec_fild_i16(val16) = {
  __x87_push(__f80_from_int16(val16));
  Ok(())
}

// FILD m32int — push int32 converted to f80.
val exec_fild_i32 : dword -> ExecutionResult
function exec_fild_i32(val32) = {
  __x87_push(__f80_from_int32(val32));
  Ok(())
}

// FILD m64int — push int64 converted to f80.
val exec_fild_i64 : qword -> ExecutionResult
function exec_fild_i64(val64) = {
  __x87_push(__f80_from_int64(val64));
  Ok(())
}

// FST/FSTP — Store Floating-Point Value
//
// Copies ST(0) to the destination. FSTP additionally pops the stack.

// FST ST(i) — copy ST(0) to ST(i).
val exec_fst_st : int -> ExecutionResult
function exec_fst_st(i) = {
  __x87_write_st(i, __x87_read_st(0));
  Ok(())
}

// FSTP ST(i) — copy ST(0) to ST(i), then pop.
val exec_fstp_st : int -> ExecutionResult
function exec_fstp_st(i) = {
  let v : fp80 = __x87_pop();
  __x87_write_st(i, v);
  Ok(())
}

// FST m32fp — store ST(0) as 32-bit float.
val exec_fst_f32 : unit -> dword
function exec_fst_f32() = __f80_to_f32(__x87_read_st(0))

// FST m64fp — store ST(0) as 64-bit float.
val exec_fst_f64 : unit -> qword
function exec_fst_f64() = __f80_to_f64(__x87_read_st(0))

// FSTP m32fp — store ST(0) as 32-bit float, then pop.
val exec_fstp_f32 : unit -> dword
function exec_fstp_f32() = {
  let v : fp80 = __x87_pop();
  __f80_to_f32(v)
}

// FSTP m64fp — store ST(0) as 64-bit float, then pop.
val exec_fstp_f64 : unit -> qword
function exec_fstp_f64() = {
  let v : fp80 = __x87_pop();
  __f80_to_f64(v)
}

// FSTP m80fp — store ST(0) as 80-bit extended precision, then pop.
val exec_fstp_f80 : unit -> fp80
function exec_fstp_f80() = __x87_pop()

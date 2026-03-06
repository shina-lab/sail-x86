// FIST/FISTP — Store Integer
//
// Converts ST(0) to a signed integer and stores it. FISTP also pops the stack.
// Rounding is controlled by the RC field in the FPU control word.

// FIST m16int — store ST(0) as int16 (no pop).
val exec_fist_i16 : unit -> word
function exec_fist_i16() = __f80_to_int16(__x87_read_st(0))

// FIST m32int — store ST(0) as int32 (no pop).
val exec_fist_i32 : unit -> dword
function exec_fist_i32() = __f80_to_int32(__x87_read_st(0))

// FISTP m16int — store ST(0) as int16, then pop.
val exec_fistp_i16 : unit -> word
function exec_fistp_i16() = {
  let v : fp80 = __x87_pop();
  __f80_to_int16(v)
}

// FISTP m32int — store ST(0) as int32, then pop.
val exec_fistp_i32 : unit -> dword
function exec_fistp_i32() = {
  let v : fp80 = __x87_pop();
  __f80_to_int32(v)
}

// FISTP m64int — store ST(0) as int64, then pop.
val exec_fistp_i64 : unit -> qword
function exec_fistp_i64() = {
  let v : fp80 = __x87_pop();
  __f80_to_int64(v)
}

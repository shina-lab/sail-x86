// FISTTP — Store Integer With Truncation (SSE3)
//
// Converts ST(0) to a signed integer using truncation (round toward zero),
// stores the result, and pops the stack.

// FISTTP m16int — store ST(0) as int16 with truncation, then pop.
val exec_fisttp_i16 : unit -> word
function exec_fisttp_i16() = {
  let v : fp80 = __x87_pop();
  __f80_to_int16_trunc(v)
}

// FISTTP m32int — store ST(0) as int32 with truncation, then pop.
val exec_fisttp_i32 : unit -> dword
function exec_fisttp_i32() = {
  let v : fp80 = __x87_pop();
  __f80_to_int32_trunc(v)
}

// FISTTP m64int — store ST(0) as int64 with truncation, then pop.
val exec_fisttp_i64 : unit -> qword
function exec_fisttp_i64() = {
  let v : fp80 = __x87_pop();
  __f80_to_int64_trunc(v)
}

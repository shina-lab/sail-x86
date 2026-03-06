// FICOM/FICOMP — Compare Integer
//
// Compares ST(0) with an integer source operand (converted to extended-
// precision floating-point). Sets condition code flags C3, C2, C0 in
// the FPU status word. FICOMP also pops the stack.

// FICOM m16int — compare ST(0) with int16, set status word.
val exec_ficom_i16 : word -> ExecutionResult
function exec_ficom_i16(val16) = {
  let src : fp80 = __f80_from_int16(val16);
  let sw : word = __x87_get_sw();
  var new_sw : word = sw;
  match __f80_compare(__x87_read_st(0), src) {
    FP_GT        => { new_sw[14] = bitzero; new_sw[10] = bitzero; new_sw[8] = bitzero; },
    FP_LT        => { new_sw[14] = bitzero; new_sw[10] = bitzero; new_sw[8] = bitone;  },
    FP_EQ        => { new_sw[14] = bitone;  new_sw[10] = bitzero; new_sw[8] = bitzero; },
    FP_UNORDERED => { new_sw[14] = bitone;  new_sw[10] = bitone;  new_sw[8] = bitone;  },
  };
  __x87_set_sw(new_sw);
  Ok(())
}

// FICOM m32int — compare ST(0) with int32, set status word.
val exec_ficom_i32 : dword -> ExecutionResult
function exec_ficom_i32(val32) = {
  let src : fp80 = __f80_from_int32(val32);
  let sw : word = __x87_get_sw();
  var new_sw : word = sw;
  match __f80_compare(__x87_read_st(0), src) {
    FP_GT        => { new_sw[14] = bitzero; new_sw[10] = bitzero; new_sw[8] = bitzero; },
    FP_LT        => { new_sw[14] = bitzero; new_sw[10] = bitzero; new_sw[8] = bitone;  },
    FP_EQ        => { new_sw[14] = bitone;  new_sw[10] = bitzero; new_sw[8] = bitzero; },
    FP_UNORDERED => { new_sw[14] = bitone;  new_sw[10] = bitone;  new_sw[8] = bitone;  },
  };
  __x87_set_sw(new_sw);
  Ok(())
}

// FICOMP m16int — compare ST(0) with int16, set status word, then pop.
val exec_ficomp_i16 : word -> ExecutionResult
function exec_ficomp_i16(val16) = {
  let src : fp80 = __f80_from_int16(val16);
  let sw : word = __x87_get_sw();
  var new_sw : word = sw;
  match __f80_compare(__x87_read_st(0), src) {
    FP_GT        => { new_sw[14] = bitzero; new_sw[10] = bitzero; new_sw[8] = bitzero; },
    FP_LT        => { new_sw[14] = bitzero; new_sw[10] = bitzero; new_sw[8] = bitone;  },
    FP_EQ        => { new_sw[14] = bitone;  new_sw[10] = bitzero; new_sw[8] = bitzero; },
    FP_UNORDERED => { new_sw[14] = bitone;  new_sw[10] = bitone;  new_sw[8] = bitone;  },
  };
  __x87_set_sw(new_sw);
  let _ = __x87_pop();
  Ok(())
}

// FICOMP m32int — compare ST(0) with int32, set status word, then pop.
val exec_ficomp_i32 : dword -> ExecutionResult
function exec_ficomp_i32(val32) = {
  let src : fp80 = __f80_from_int32(val32);
  let sw : word = __x87_get_sw();
  var new_sw : word = sw;
  match __f80_compare(__x87_read_st(0), src) {
    FP_GT        => { new_sw[14] = bitzero; new_sw[10] = bitzero; new_sw[8] = bitzero; },
    FP_LT        => { new_sw[14] = bitzero; new_sw[10] = bitzero; new_sw[8] = bitone;  },
    FP_EQ        => { new_sw[14] = bitone;  new_sw[10] = bitzero; new_sw[8] = bitzero; },
    FP_UNORDERED => { new_sw[14] = bitone;  new_sw[10] = bitone;  new_sw[8] = bitone;  },
  };
  __x87_set_sw(new_sw);
  let _ = __x87_pop();
  Ok(())
}

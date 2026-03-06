// FCOM/FCOMP/FCOMPP/FCOMI/FCOMIP/FUCOM/FUCOMP/FUCOMPP — Compare Floating-Point
//
// Compare ST(0) with another value and set x87 status word condition codes
// or RFLAGS (for FCOMI/FCOMIP variants).

// FCOMI ST(0), ST(i) — compare and set RFLAGS (ZF, PF, CF).
// Used by conditional branches after FP comparison.
val exec_fcomi : int -> ExecutionResult
function exec_fcomi(i) = {
  match __f80_compare(__x87_read_st(0), __x87_read_st(i)) {
    FP_UNORDERED => { ZF = bitone;  PF = bitone;  CF = bitone;  },
    FP_GT        => { ZF = bitzero; PF = bitzero; CF = bitzero; },
    FP_LT        => { ZF = bitzero; PF = bitzero; CF = bitone;  },
    FP_EQ        => { ZF = bitone;  PF = bitzero; CF = bitzero; },
  };
  OF = bitzero;
  AF = bitzero;
  SF = bitzero;
  Ok(())
}

// FCOMIP ST(0), ST(i) — compare, set RFLAGS, then pop.
val exec_fcomip : int -> ExecutionResult
function exec_fcomip(i) = {
  match __f80_compare(__x87_read_st(0), __x87_read_st(i)) {
    FP_UNORDERED => { ZF = bitone;  PF = bitone;  CF = bitone;  },
    FP_GT        => { ZF = bitzero; PF = bitzero; CF = bitzero; },
    FP_LT        => { ZF = bitzero; PF = bitzero; CF = bitone;  },
    FP_EQ        => { ZF = bitone;  PF = bitzero; CF = bitzero; },
  };
  OF = bitzero;
  AF = bitzero;
  SF = bitzero;
  let _ = __x87_pop();
  Ok(())
}

// FUCOMI ST(0), ST(i) — unordered compare, set RFLAGS.
// Behaves like FCOMI but does not raise #IA for QNaNs.
// We model both identically since exception behavior is external.
val exec_fucomi : int -> ExecutionResult
function exec_fucomi(i) = {
  match __f80_compare(__x87_read_st(0), __x87_read_st(i)) {
    FP_UNORDERED => { ZF = bitone;  PF = bitone;  CF = bitone;  },
    FP_GT        => { ZF = bitzero; PF = bitzero; CF = bitzero; },
    FP_LT        => { ZF = bitzero; PF = bitzero; CF = bitone;  },
    FP_EQ        => { ZF = bitone;  PF = bitzero; CF = bitzero; },
  };
  OF = bitzero;
  AF = bitzero;
  SF = bitzero;
  Ok(())
}

// FUCOMIP ST(0), ST(i) — unordered compare, set RFLAGS, then pop.
val exec_fucomip : int -> ExecutionResult
function exec_fucomip(i) = {
  match __f80_compare(__x87_read_st(0), __x87_read_st(i)) {
    FP_UNORDERED => { ZF = bitone;  PF = bitone;  CF = bitone;  },
    FP_GT        => { ZF = bitzero; PF = bitzero; CF = bitzero; },
    FP_LT        => { ZF = bitzero; PF = bitzero; CF = bitone;  },
    FP_EQ        => { ZF = bitone;  PF = bitzero; CF = bitzero; },
  };
  OF = bitzero;
  AF = bitzero;
  SF = bitzero;
  let _ = __x87_pop();
  Ok(())
}

// FCOM ST(i) — compare ST(0) with ST(i), set x87 status word C0/C2/C3.
// The status word bits C3, C2, C0 encode the comparison result.
val exec_fcom : int -> ExecutionResult
function exec_fcom(i) = {
  let sw : word = __x87_get_sw();
  var new_sw : word = sw;
  match __f80_compare(__x87_read_st(0), __x87_read_st(i)) {
    FP_GT        => { new_sw[14] = bitzero; new_sw[10] = bitzero; new_sw[8] = bitzero; },
    FP_LT        => { new_sw[14] = bitzero; new_sw[10] = bitzero; new_sw[8] = bitone;  },
    FP_EQ        => { new_sw[14] = bitone;  new_sw[10] = bitzero; new_sw[8] = bitzero; },
    FP_UNORDERED => { new_sw[14] = bitone;  new_sw[10] = bitone;  new_sw[8] = bitone;  },
  };
  __x87_set_sw(new_sw);
  Ok(())
}

// FCOMP ST(i) — compare ST(0) with ST(i), set status word, then pop.
val exec_fcomp : int -> ExecutionResult
function exec_fcomp(i) = {
  let sw : word = __x87_get_sw();
  var new_sw : word = sw;
  match __f80_compare(__x87_read_st(0), __x87_read_st(i)) {
    FP_GT        => { new_sw[14] = bitzero; new_sw[10] = bitzero; new_sw[8] = bitzero; },
    FP_LT        => { new_sw[14] = bitzero; new_sw[10] = bitzero; new_sw[8] = bitone;  },
    FP_EQ        => { new_sw[14] = bitone;  new_sw[10] = bitzero; new_sw[8] = bitzero; },
    FP_UNORDERED => { new_sw[14] = bitone;  new_sw[10] = bitone;  new_sw[8] = bitone;  },
  };
  __x87_set_sw(new_sw);
  let _ = __x87_pop();
  Ok(())
}

// FCOMPP — compare ST(0) with ST(1), set status word, then pop both.
val exec_fcompp : unit -> ExecutionResult
function exec_fcompp() = {
  let sw : word = __x87_get_sw();
  var new_sw : word = sw;
  match __f80_compare(__x87_read_st(0), __x87_read_st(1)) {
    FP_GT        => { new_sw[14] = bitzero; new_sw[10] = bitzero; new_sw[8] = bitzero; },
    FP_LT        => { new_sw[14] = bitzero; new_sw[10] = bitzero; new_sw[8] = bitone;  },
    FP_EQ        => { new_sw[14] = bitone;  new_sw[10] = bitzero; new_sw[8] = bitzero; },
    FP_UNORDERED => { new_sw[14] = bitone;  new_sw[10] = bitone;  new_sw[8] = bitone;  },
  };
  __x87_set_sw(new_sw);
  let _ = __x87_pop();
  let _ = __x87_pop();
  Ok(())
}

// FUCOM ST(i) — unordered compare, set x87 status word.
val exec_fucom : int -> ExecutionResult
function exec_fucom(i) = {
  let sw : word = __x87_get_sw();
  var new_sw : word = sw;
  match __f80_compare(__x87_read_st(0), __x87_read_st(i)) {
    FP_GT        => { new_sw[14] = bitzero; new_sw[10] = bitzero; new_sw[8] = bitzero; },
    FP_LT        => { new_sw[14] = bitzero; new_sw[10] = bitzero; new_sw[8] = bitone;  },
    FP_EQ        => { new_sw[14] = bitone;  new_sw[10] = bitzero; new_sw[8] = bitzero; },
    FP_UNORDERED => { new_sw[14] = bitone;  new_sw[10] = bitone;  new_sw[8] = bitone;  },
  };
  __x87_set_sw(new_sw);
  Ok(())
}

// FUCOMP ST(i) — unordered compare, set status word, then pop.
val exec_fucomp : int -> ExecutionResult
function exec_fucomp(i) = {
  let sw : word = __x87_get_sw();
  var new_sw : word = sw;
  match __f80_compare(__x87_read_st(0), __x87_read_st(i)) {
    FP_GT        => { new_sw[14] = bitzero; new_sw[10] = bitzero; new_sw[8] = bitzero; },
    FP_LT        => { new_sw[14] = bitzero; new_sw[10] = bitzero; new_sw[8] = bitone;  },
    FP_EQ        => { new_sw[14] = bitone;  new_sw[10] = bitzero; new_sw[8] = bitzero; },
    FP_UNORDERED => { new_sw[14] = bitone;  new_sw[10] = bitone;  new_sw[8] = bitone;  },
  };
  __x87_set_sw(new_sw);
  let _ = __x87_pop();
  Ok(())
}

// FUCOMPP — unordered compare ST(0) with ST(1), set status word, pop both.
val exec_fucompp : unit -> ExecutionResult
function exec_fucompp() = {
  let sw : word = __x87_get_sw();
  var new_sw : word = sw;
  match __f80_compare(__x87_read_st(0), __x87_read_st(1)) {
    FP_GT        => { new_sw[14] = bitzero; new_sw[10] = bitzero; new_sw[8] = bitzero; },
    FP_LT        => { new_sw[14] = bitzero; new_sw[10] = bitzero; new_sw[8] = bitone;  },
    FP_EQ        => { new_sw[14] = bitone;  new_sw[10] = bitzero; new_sw[8] = bitzero; },
    FP_UNORDERED => { new_sw[14] = bitone;  new_sw[10] = bitone;  new_sw[8] = bitone;  },
  };
  __x87_set_sw(new_sw);
  let _ = __x87_pop();
  let _ = __x87_pop();
  Ok(())
}

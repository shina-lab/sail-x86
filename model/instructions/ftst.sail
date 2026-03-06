// FTST -- TEST
//
// Compares ST(0) with 0.0 and sets the x87 status word condition codes
// C3, C2, C0 according to the result.

val exec_ftst : unit -> ExecutionResult
function exec_ftst() = {
  let sw : word = __x87_get_sw();
  var new_sw : word = sw;
  match __f80_compare(__x87_read_st(0), __f80_zero()) {
    FP_GT        => { new_sw[14] = bitzero; new_sw[10] = bitzero; new_sw[8] = bitzero; },
    FP_LT        => { new_sw[14] = bitzero; new_sw[10] = bitzero; new_sw[8] = bitone;  },
    FP_EQ        => { new_sw[14] = bitone;  new_sw[10] = bitzero; new_sw[8] = bitzero; },
    FP_UNORDERED => { new_sw[14] = bitone;  new_sw[10] = bitone;  new_sw[8] = bitone;  },
  };
  __x87_set_sw(new_sw);
  Ok(())
}

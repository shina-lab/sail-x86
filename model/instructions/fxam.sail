// FXAM -- Examine Floating-Point
//
// Examines ST(0) and sets C3, C2, C0 in the FPU status word to indicate
// the class of value. C1 is set to the sign bit of ST(0).
// FPClass enum and __f80_classify are declared in x87_extern.sail.

val exec_fxam : unit -> ExecutionResult
function exec_fxam() = {
  let val80 : fp80 = __x87_read_st(0);
  let sw : word = __x87_get_sw();
  var new_sw : word = sw;
  // C1 = sign bit of ST(0)
  new_sw[9] = val80[79];
  // C3, C2, C0 encode the class
  match __f80_classify(val80) {
    //                      C3(14)     C2(10)     C0(8)
    FP_Unsupported => { new_sw[14] = bitzero; new_sw[10] = bitzero; new_sw[8] = bitzero; },
    FP_NaN         => { new_sw[14] = bitzero; new_sw[10] = bitzero; new_sw[8] = bitone;  },
    FP_Normal      => { new_sw[14] = bitzero; new_sw[10] = bitone;  new_sw[8] = bitzero; },
    FP_Infinity    => { new_sw[14] = bitzero; new_sw[10] = bitone;  new_sw[8] = bitone;  },
    FP_Zero        => { new_sw[14] = bitone;  new_sw[10] = bitzero; new_sw[8] = bitzero; },
    FP_Empty       => { new_sw[14] = bitone;  new_sw[10] = bitzero; new_sw[8] = bitone;  },
    FP_Denormal    => { new_sw[14] = bitone;  new_sw[10] = bitone;  new_sw[8] = bitzero; },
  };
  __x87_set_sw(new_sw);
  Ok(())
}

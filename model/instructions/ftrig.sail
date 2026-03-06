// x87 Transcendental and Exponential Functions
//
// F2XM1, FSIN, FCOS, FSINCOS, FPTAN, FPATAN, FSCALE, FPREM, FPREM1, FRNDINT

// F2XM1 — Compute 2^ST(0) - 1, replace ST(0).
val exec_f2xm1 : unit -> ExecutionResult
function exec_f2xm1() = {
  let result : fp80 = __f80_2xm1(__x87_read_st(0));
  __x87_write_st(0, result);
  Ok(())
}

// FSIN — Replace ST(0) with sin(ST(0)).
val exec_fsin : unit -> ExecutionResult
function exec_fsin() = {
  let result : fp80 = __f80_sin(__x87_read_st(0));
  __x87_write_st(0, result);
  Ok(())
}

// FCOS — Replace ST(0) with cos(ST(0)).
val exec_fcos : unit -> ExecutionResult
function exec_fcos() = {
  let result : fp80 = __f80_cos(__x87_read_st(0));
  __x87_write_st(0, result);
  Ok(())
}

// FSINCOS — Compute sin and cos of ST(0).
// Replace ST(0) with sin, then push cos onto the stack.
// After: ST(0) = cos, ST(1) = sin.
val exec_fsincos : unit -> ExecutionResult
function exec_fsincos() = {
  let src : fp80 = __x87_read_st(0);
  let sin_val : fp80 = __f80_sin(src);
  let cos_val : fp80 = __f80_cos(src);
  __x87_write_st(0, sin_val);
  __x87_push(cos_val);
  Ok(())
}

// FPTAN — Compute tan(ST(0)), replace ST(0) with result, push 1.0.
// After: ST(0) = 1.0, ST(1) = tan(original ST(0)).
val exec_fptan : unit -> ExecutionResult
function exec_fptan() = {
  let result : fp80 = __f80_tan(__x87_read_st(0));
  __x87_write_st(0, result);
  __x87_push(__f80_one());
  Ok(())
}

// FPATAN — Compute arctan(ST(1)/ST(0)), pop, store result in ST(0).
// Result = atan2(ST(1), ST(0)).
val exec_fpatan : unit -> ExecutionResult
function exec_fpatan() = {
  let st0 : fp80 = __x87_read_st(0);
  let st1 : fp80 = __x87_read_st(1);
  let result : fp80 = __f80_atan2(st1, st0);
  let _ = __x87_pop();
  __x87_write_st(0, result);
  Ok(())
}

// FSCALE — ST(0) = ST(0) * 2^(trunc(ST(1))).
val exec_fscale : unit -> ExecutionResult
function exec_fscale() = {
  let result : fp80 = __f80_scale(__x87_read_st(0), __x87_read_st(1));
  __x87_write_st(0, result);
  Ok(())
}

// FPREM — ST(0) = ST(0) partial remainder w.r.t. ST(1) (IEEE 8087-compatible).
val exec_fprem : unit -> ExecutionResult
function exec_fprem() = {
  let result : fp80 = __f80_prem(__x87_read_st(0), __x87_read_st(1));
  __x87_write_st(0, result);
  Ok(())
}

// FPREM1 — ST(0) = IEEE remainder of ST(0) / ST(1).
val exec_fprem1 : unit -> ExecutionResult
function exec_fprem1() = {
  let result : fp80 = __f80_prem1(__x87_read_st(0), __x87_read_st(1));
  __x87_write_st(0, result);
  Ok(())
}

// FRNDINT — Round ST(0) to integer (using current rounding mode).
val exec_frndint : unit -> ExecutionResult
function exec_frndint() = {
  let result : fp80 = __f80_round(__x87_read_st(0));
  __x87_write_st(0, result);
  Ok(())
}

// FLD1/FLDL2T/FLDL2E/FLDPI/FLDLG2/FLDLN2/FLDZ — Load Constant
//
// Push commonly used FPU constants onto the x87 stack.

// FLD1 — Push +1.0.
val exec_fld1 : unit -> ExecutionResult
function exec_fld1() = {
  __x87_push(__f80_one());
  Ok(())
}

// FLDL2T — Push log2(10).
val exec_fldl2t : unit -> ExecutionResult
function exec_fldl2t() = {
  __x87_push(__f80_log2_10());
  Ok(())
}

// FLDL2E — Push log2(e).
val exec_fldl2e : unit -> ExecutionResult
function exec_fldl2e() = {
  __x87_push(__f80_log2_e());
  Ok(())
}

// FLDPI — Push pi.
val exec_fldpi : unit -> ExecutionResult
function exec_fldpi() = {
  __x87_push(__f80_pi());
  Ok(())
}

// FLDLG2 — Push log10(2).
val exec_fldlg2 : unit -> ExecutionResult
function exec_fldlg2() = {
  __x87_push(__f80_log10_2());
  Ok(())
}

// FLDLN2 — Push ln(2).
val exec_fldln2 : unit -> ExecutionResult
function exec_fldln2() = {
  __x87_push(__f80_ln_2());
  Ok(())
}

// FLDZ — Push +0.0.
val exec_fldz : unit -> ExecutionResult
function exec_fldz() = {
  __x87_push(__f80_zero());
  Ok(())
}

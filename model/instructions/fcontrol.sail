// x87 FPU Control Instructions
//
// FCLEX/FNCLEX, FINIT/FNINIT, FLDCW, FSTCW/FNSTCW, FSTSW/FNSTSW,
// FLDENV, FSTENV/FNSTENV, FDECSTP, FINCSTP, FFREE

// =========================================================================
// FCLEX/FNCLEX — Clear Exceptions
// Clears exception flags (PE, UE, OE, ZE, DE, IE), ES, SF, B in status word.
// FCLEX checks for pending exceptions first; FNCLEX does not.
// We model both identically (the FWAIT prefix for FCLEX is handled elsewhere).
// =========================================================================

val exec_fnclex : unit -> ExecutionResult
function exec_fnclex() = {
  let sw : word = __x87_get_sw();
  var new_sw : word = sw;
  // Clear bits 0-7 (IE, DE, ZE, OE, UE, PE, SF, ES) and bit 15 (B)
  new_sw[7 .. 0] = 0x00;
  new_sw[15] = bitzero;
  __x87_set_sw(new_sw);
  Ok(())
}

// =========================================================================
// FINIT/FNINIT — Initialize Floating-Point Unit
// Sets CW=037FH, SW=0, tag word=FFFFH, clears pointers.
// =========================================================================

val exec_fninit : unit -> ExecutionResult
function exec_fninit() = {
  __x87_init();
  Ok(())
}

// =========================================================================
// FLDCW — Load x87 FPU Control Word
// Loads a 16-bit value into the FPU control word from memory.
// =========================================================================

val exec_fldcw : word -> ExecutionResult
function exec_fldcw(src) = {
  __x87_set_cw(src);
  Ok(())
}

// =========================================================================
// FSTCW/FNSTCW — Store x87 FPU Control Word
// Returns the current FPU control word (to be stored to memory).
// =========================================================================

val exec_fnstcw : unit -> word
function exec_fnstcw() = __x87_get_cw()

// =========================================================================
// FSTSW/FNSTSW — Store x87 FPU Status Word
// Two forms: to memory (m2byte) and to AX register.
// Returns the current FPU status word.
// =========================================================================

val exec_fnstsw : unit -> word
function exec_fnstsw() = __x87_get_sw()

// =========================================================================
// FLDENV — Load x87 FPU Environment
// Loads the FPU environment (control word, status word, tag word, etc.)
// from a memory image.
// =========================================================================

val exec_fldenv : bits(224) -> ExecutionResult
function exec_fldenv(src) = {
  __x87_load_env(src);
  Ok(())
}

// =========================================================================
// FSTENV/FNSTENV — Store x87 FPU Environment
// Stores the FPU environment to memory.
// =========================================================================

val exec_fnstenv : unit -> bits(224)
function exec_fnstenv() = __x87_save_env()

// =========================================================================
// FDECSTP — Decrement Stack-Top Pointer
// Rotates the TOP field of the status word by decrementing it by one.
// Does not modify tag word or register contents.
// =========================================================================

val exec_fdecstp : unit -> ExecutionResult
function exec_fdecstp() = {
  __x87_dec_top();
  Ok(())
}

// =========================================================================
// FINCSTP — Increment Stack-Top Pointer
// Rotates the TOP field of the status word by incrementing it by one.
// Does not modify tag word or register contents.
// =========================================================================

val exec_fincstp : unit -> ExecutionResult
function exec_fincstp() = {
  __x87_inc_top();
  Ok(())
}

// =========================================================================
// FFREE — Free Floating-Point Register
// Sets the tag for ST(i) to empty (11B) without popping or modifying content.
// =========================================================================

val exec_ffree : int -> ExecutionResult
function exec_ffree(i) = {
  __x87_free(i);
  Ok(())
}

// x87 FPU External Functions
//
// Only 80-bit extended precision arithmetic remains external, since Sail
// has no native float80 type. The x87 register state (stack, control/status
// words, tag word) is now modeled natively in core/x87_regs.sail.

// Backward-compatible wrappers so existing instruction files don't change.
val __x87_read_st : int -> fp80
function __x87_read_st(i) = x87_read_st(i)

val __x87_write_st : (int, fp80) -> unit
function __x87_write_st(i, v) = x87_write_st(i, v)

val __x87_push : fp80 -> unit
function __x87_push(v) = x87_push(v)

val __x87_pop : unit -> fp80
function __x87_pop() = x87_pop()

val __x87_get_sw : unit -> word
function __x87_get_sw() = x87_sw

val __x87_set_sw : word -> unit
function __x87_set_sw(v) = { x87_sw = v }

val __x87_get_cw : unit -> word
function __x87_get_cw() = x87_cw

val __x87_set_cw : word -> unit
function __x87_set_cw(v) = { x87_cw = v }

// =========================================================================
// 80-bit extended precision arithmetic (external — no native float80 in Sail)
// =========================================================================

val __f80_add : (fp80, fp80) -> fp80
val __f80_sub : (fp80, fp80) -> fp80
val __f80_mul : (fp80, fp80) -> fp80
val __f80_div : (fp80, fp80) -> fp80
val __f80_sqrt : fp80 -> fp80
val __f80_abs : fp80 -> fp80
val __f80_chs : fp80 -> fp80
val __f80_compare : (fp80, fp80) -> FPCompareResult

// =========================================================================
// Conversions to/from 80-bit extended precision
// =========================================================================

val __f80_from_f32 : dword -> fp80
val __f80_from_f64 : qword -> fp80
val __f80_to_f32 : fp80 -> dword
val __f80_to_f64 : fp80 -> qword
val __f80_from_int32 : dword -> fp80
val __f80_from_int64 : qword -> fp80
val __f80_to_int32 : fp80 -> dword
val __f80_to_int64 : fp80 -> qword
val __f80_to_int32_trunc : fp80 -> dword
val __f80_to_int64_trunc : fp80 -> qword

// =========================================================================
// Constants
// =========================================================================

val __f80_zero : unit -> fp80

// =========================================================================
// Classification
// =========================================================================

enum FPClass = {
  FP_Unsupported,
  FP_NaN,
  FP_Normal,
  FP_Infinity,
  FP_Zero,
  FP_Empty,
  FP_Denormal
}

val __f80_classify : fp80 -> FPClass

// =========================================================================
// Decomposition (used by FXTRACT)
// =========================================================================

val __f80_extract_exponent : fp80 -> fp80
val __f80_extract_significand : fp80 -> fp80

// =========================================================================
// Transcendental operations
// =========================================================================

val __f80_yl2x : (fp80, fp80) -> fp80
val __f80_yl2xp1 : (fp80, fp80) -> fp80
// x87 FPU External Functions — Extended
//
// Additional external functions for 80-bit arithmetic not covered
// by the base x87_extern.sail.

// =========================================================================
// Integer conversions for 16-bit operands
// =========================================================================

val __f80_from_int16 : word -> fp80
val __f80_to_int16 : fp80 -> word
val __f80_to_int16_trunc : fp80 -> word

// =========================================================================
// BCD conversions (for FBLD/FBSTP)
// =========================================================================

val __f80_from_bcd : fp80 -> fp80
val __f80_to_bcd : fp80 -> fp80

// =========================================================================
// Transcendental / special functions
// =========================================================================

val __f80_sin : fp80 -> fp80
val __f80_cos : fp80 -> fp80
val __f80_tan : fp80 -> fp80
val __f80_atan2 : (fp80, fp80) -> fp80
val __f80_2xm1 : fp80 -> fp80
val __f80_scale : (fp80, fp80) -> fp80
val __f80_prem : (fp80, fp80) -> fp80
val __f80_prem1 : (fp80, fp80) -> fp80
val __f80_round : fp80 -> fp80

// =========================================================================
// FPU load constants
// =========================================================================

val __f80_one : unit -> fp80
val __f80_log2_10 : unit -> fp80
val __f80_log2_e : unit -> fp80
val __f80_pi : unit -> fp80
val __f80_log10_2 : unit -> fp80
val __f80_ln_2 : unit -> fp80

// =========================================================================
// Backward-compatible wrappers for state management
// (now implemented natively in core/x87_regs.sail)
// =========================================================================

val __x87_init : unit -> unit
function __x87_init() = x87_init()

val __x87_free : int -> unit
function __x87_free(i) = x87_free(i)

val __x87_save_env : unit -> bits(224)
function __x87_save_env() = x87_save_env()

val __x87_load_env : bits(224) -> unit
function __x87_load_env(v) = x87_load_env(v)

val __x87_save_state : unit -> bits(864)
function __x87_save_state() = x87_save_state()

val __x87_load_state : bits(864) -> unit
function __x87_load_state(v) = x87_load_state(v)

val __x87_dec_top : unit -> unit
function __x87_dec_top() = x87_dec_top()

val __x87_inc_top : unit -> unit
function __x87_inc_top() = x87_inc_top()
// WAIT/FWAIT — Wait for Pending FP Exceptions
//
// Checks for and handles pending unmasked x87 FPU exceptions.
// WAIT and FWAIT are synonymous. The processor checks for pending
// unmasked FP exceptions before proceeding.
// Modeled as external since it requires checking FPU exception state.

val __wait : unit -> ExecutionResult
val exec_fwait : unit -> ExecutionResult
function exec_fwait() = __wait()
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
// FLD — Load Floating-Point Value
//
// Pushes a floating-point value onto the x87 FPU stack.
// Source can be ST(i), or a 32/64/80-bit memory operand.

// FLD ST(i) — push ST(i) onto the stack.
val exec_fld_st : int -> ExecutionResult
function exec_fld_st(i) = {
  let v : fp80 = __x87_read_st(i);
  __x87_push(v);
  Ok(())
}

// FLD m32fp — load 32-bit float, convert to 80-bit, push.
val exec_fld_f32 : dword -> ExecutionResult
function exec_fld_f32(val32) = {
  __x87_push(__f80_from_f32(val32));
  Ok(())
}

// FLD m64fp — load 64-bit float, convert to 80-bit, push.
val exec_fld_f64 : qword -> ExecutionResult
function exec_fld_f64(val64) = {
  __x87_push(__f80_from_f64(val64));
  Ok(())
}

// FLD m80fp — load 80-bit extended precision, push directly.
val exec_fld_f80 : fp80 -> ExecutionResult
function exec_fld_f80(val80) = {
  __x87_push(val80);
  Ok(())
}
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
// FADD/FADDP/FIADD — Add Floating-Point
//
// Adds two floating-point values and stores the result.

// FADD ST(0), ST(i) — ST(0) = ST(0) + ST(i).
val exec_fadd_st0_sti : int -> ExecutionResult
function exec_fadd_st0_sti(i) = {
  let result : fp80 = __f80_add(__x87_read_st(0), __x87_read_st(i));
  __x87_write_st(0, result);
  Ok(())
}

// FADD ST(i), ST(0) — ST(i) = ST(i) + ST(0).
val exec_fadd_sti_st0 : int -> ExecutionResult
function exec_fadd_sti_st0(i) = {
  let result : fp80 = __f80_add(__x87_read_st(i), __x87_read_st(0));
  __x87_write_st(i, result);
  Ok(())
}

// FADDP ST(i), ST(0) — ST(i) = ST(i) + ST(0), then pop.
val exec_faddp_sti : int -> ExecutionResult
function exec_faddp_sti(i) = {
  let result : fp80 = __f80_add(__x87_read_st(i), __x87_read_st(0));
  let _ = __x87_pop();
  __x87_write_st(i - 1, result);
  Ok(())
}

// FADD m32fp — ST(0) = ST(0) + float32.
val exec_fadd_f32 : dword -> ExecutionResult
function exec_fadd_f32(val32) = {
  let src : fp80 = __f80_from_f32(val32);
  let result : fp80 = __f80_add(__x87_read_st(0), src);
  __x87_write_st(0, result);
  Ok(())
}

// FADD m64fp — ST(0) = ST(0) + float64.
val exec_fadd_f64 : qword -> ExecutionResult
function exec_fadd_f64(val64) = {
  let src : fp80 = __f80_from_f64(val64);
  let result : fp80 = __f80_add(__x87_read_st(0), src);
  __x87_write_st(0, result);
  Ok(())
}

// FIADD m32int — ST(0) = ST(0) + int32.
val exec_fiadd_i32 : dword -> ExecutionResult
function exec_fiadd_i32(val32) = {
  let src : fp80 = __f80_from_int32(val32);
  let result : fp80 = __f80_add(__x87_read_st(0), src);
  __x87_write_st(0, result);
  Ok(())
}
// FSUB/FSUBP/FISUB/FSUBR/FSUBRP/FISUBR — Subtract Floating-Point
//
// Subtracts floating-point values. The "R" (reverse) variants swap operand order.
// The "I" variants convert integer memory operands to extended precision first.

// FSUB ST(0), ST(i) — ST(0) = ST(0) - ST(i).
val exec_fsub_st0_sti : int -> ExecutionResult
function exec_fsub_st0_sti(i) = {
  let result : fp80 = __f80_sub(__x87_read_st(0), __x87_read_st(i));
  __x87_write_st(0, result);
  Ok(())
}

// FSUB ST(i), ST(0) — ST(i) = ST(i) - ST(0).
val exec_fsub_sti_st0 : int -> ExecutionResult
function exec_fsub_sti_st0(i) = {
  let result : fp80 = __f80_sub(__x87_read_st(i), __x87_read_st(0));
  __x87_write_st(i, result);
  Ok(())
}

// FSUBP ST(i), ST(0) — ST(i) = ST(i) - ST(0), then pop.
val exec_fsubp_sti : int -> ExecutionResult
function exec_fsubp_sti(i) = {
  let result : fp80 = __f80_sub(__x87_read_st(i), __x87_read_st(0));
  let _ = __x87_pop();
  __x87_write_st(i - 1, result);
  Ok(())
}

// FSUBR ST(0), ST(i) — ST(0) = ST(i) - ST(0) (reversed).
val exec_fsubr_st0_sti : int -> ExecutionResult
function exec_fsubr_st0_sti(i) = {
  let result : fp80 = __f80_sub(__x87_read_st(i), __x87_read_st(0));
  __x87_write_st(0, result);
  Ok(())
}

// FSUBR ST(i), ST(0) — ST(i) = ST(0) - ST(i) (reversed).
val exec_fsubr_sti_st0 : int -> ExecutionResult
function exec_fsubr_sti_st0(i) = {
  let result : fp80 = __f80_sub(__x87_read_st(0), __x87_read_st(i));
  __x87_write_st(i, result);
  Ok(())
}

// FSUBRP ST(i), ST(0) — ST(i) = ST(0) - ST(i) (reversed), then pop.
val exec_fsubrp_sti : int -> ExecutionResult
function exec_fsubrp_sti(i) = {
  let result : fp80 = __f80_sub(__x87_read_st(0), __x87_read_st(i));
  let _ = __x87_pop();
  __x87_write_st(i - 1, result);
  Ok(())
}

// FSUB m32fp — ST(0) = ST(0) - float32.
val exec_fsub_f32 : dword -> ExecutionResult
function exec_fsub_f32(val32) = {
  let src : fp80 = __f80_from_f32(val32);
  let result : fp80 = __f80_sub(__x87_read_st(0), src);
  __x87_write_st(0, result);
  Ok(())
}

// FSUB m64fp — ST(0) = ST(0) - float64.
val exec_fsub_f64 : qword -> ExecutionResult
function exec_fsub_f64(val64) = {
  let src : fp80 = __f80_from_f64(val64);
  let result : fp80 = __f80_sub(__x87_read_st(0), src);
  __x87_write_st(0, result);
  Ok(())
}

// FSUBR m32fp — ST(0) = float32 - ST(0) (reversed).
val exec_fsubr_f32 : dword -> ExecutionResult
function exec_fsubr_f32(val32) = {
  let src : fp80 = __f80_from_f32(val32);
  let result : fp80 = __f80_sub(src, __x87_read_st(0));
  __x87_write_st(0, result);
  Ok(())
}

// FSUBR m64fp — ST(0) = float64 - ST(0) (reversed).
val exec_fsubr_f64 : qword -> ExecutionResult
function exec_fsubr_f64(val64) = {
  let src : fp80 = __f80_from_f64(val64);
  let result : fp80 = __f80_sub(src, __x87_read_st(0));
  __x87_write_st(0, result);
  Ok(())
}

// FISUB m32int — ST(0) = ST(0) - int32.
val exec_fisub_i32 : dword -> ExecutionResult
function exec_fisub_i32(val32) = {
  let src : fp80 = __f80_from_int32(val32);
  let result : fp80 = __f80_sub(__x87_read_st(0), src);
  __x87_write_st(0, result);
  Ok(())
}

// FISUB m16int — ST(0) = ST(0) - int16.
val exec_fisub_i16 : word -> ExecutionResult
function exec_fisub_i16(val16) = {
  let src : fp80 = __f80_from_int32(sign_extend(val16));
  let result : fp80 = __f80_sub(__x87_read_st(0), src);
  __x87_write_st(0, result);
  Ok(())
}

// FISUBR m32int — ST(0) = int32 - ST(0) (reversed).
val exec_fisubr_i32 : dword -> ExecutionResult
function exec_fisubr_i32(val32) = {
  let src : fp80 = __f80_from_int32(val32);
  let result : fp80 = __f80_sub(src, __x87_read_st(0));
  __x87_write_st(0, result);
  Ok(())
}

// FISUBR m16int — ST(0) = int16 - ST(0) (reversed).
val exec_fisubr_i16 : word -> ExecutionResult
function exec_fisubr_i16(val16) = {
  let src : fp80 = __f80_from_int32(sign_extend(val16));
  let result : fp80 = __f80_sub(src, __x87_read_st(0));
  __x87_write_st(0, result);
  Ok(())
}
// FMUL/FMULP/FIMUL — Multiply Floating-Point
//
// Multiplies two floating-point values and stores the result.

// FMUL ST(0), ST(i) — ST(0) = ST(0) * ST(i).
val exec_fmul_st0_sti : int -> ExecutionResult
function exec_fmul_st0_sti(i) = {
  let result : fp80 = __f80_mul(__x87_read_st(0), __x87_read_st(i));
  __x87_write_st(0, result);
  Ok(())
}

// FMUL ST(i), ST(0) — ST(i) = ST(i) * ST(0).
val exec_fmul_sti_st0 : int -> ExecutionResult
function exec_fmul_sti_st0(i) = {
  let result : fp80 = __f80_mul(__x87_read_st(i), __x87_read_st(0));
  __x87_write_st(i, result);
  Ok(())
}

// FMULP ST(i), ST(0) — ST(i) = ST(i) * ST(0), then pop.
val exec_fmulp_sti : int -> ExecutionResult
function exec_fmulp_sti(i) = {
  let result : fp80 = __f80_mul(__x87_read_st(i), __x87_read_st(0));
  let _ = __x87_pop();
  __x87_write_st(i - 1, result);
  Ok(())
}

// FMUL m32fp — ST(0) = ST(0) * float32.
val exec_fmul_f32 : dword -> ExecutionResult
function exec_fmul_f32(val32) = {
  let src : fp80 = __f80_from_f32(val32);
  let result : fp80 = __f80_mul(__x87_read_st(0), src);
  __x87_write_st(0, result);
  Ok(())
}

// FMUL m64fp — ST(0) = ST(0) * float64.
val exec_fmul_f64 : qword -> ExecutionResult
function exec_fmul_f64(val64) = {
  let src : fp80 = __f80_from_f64(val64);
  let result : fp80 = __f80_mul(__x87_read_st(0), src);
  __x87_write_st(0, result);
  Ok(())
}

// FIMUL m32int — ST(0) = ST(0) * int32.
val exec_fimul_i32 : dword -> ExecutionResult
function exec_fimul_i32(val32) = {
  let src : fp80 = __f80_from_int32(val32);
  let result : fp80 = __f80_mul(__x87_read_st(0), src);
  __x87_write_st(0, result);
  Ok(())
}
// FDIV/FDIVP/FDIVR/FDIVRP — Divide Floating-Point
//
// Divides floating-point values. The "R" (reverse) variants swap operand order.

// FDIV ST(0), ST(i) — ST(0) = ST(0) / ST(i).
val exec_fdiv_st0_sti : int -> ExecutionResult
function exec_fdiv_st0_sti(i) = {
  let result : fp80 = __f80_div(__x87_read_st(0), __x87_read_st(i));
  __x87_write_st(0, result);
  Ok(())
}

// FDIV ST(i), ST(0) — ST(i) = ST(i) / ST(0).
val exec_fdiv_sti_st0 : int -> ExecutionResult
function exec_fdiv_sti_st0(i) = {
  let result : fp80 = __f80_div(__x87_read_st(i), __x87_read_st(0));
  __x87_write_st(i, result);
  Ok(())
}

// FDIVP ST(i), ST(0) — ST(i) = ST(i) / ST(0), then pop.
val exec_fdivp_sti : int -> ExecutionResult
function exec_fdivp_sti(i) = {
  let result : fp80 = __f80_div(__x87_read_st(i), __x87_read_st(0));
  let _ = __x87_pop();
  __x87_write_st(i - 1, result);
  Ok(())
}

// FDIVR ST(0), ST(i) — ST(0) = ST(i) / ST(0) (reversed).
val exec_fdivr_st0_sti : int -> ExecutionResult
function exec_fdivr_st0_sti(i) = {
  let result : fp80 = __f80_div(__x87_read_st(i), __x87_read_st(0));
  __x87_write_st(0, result);
  Ok(())
}

// FDIVR ST(i), ST(0) — ST(i) = ST(0) / ST(i) (reversed).
val exec_fdivr_sti_st0 : int -> ExecutionResult
function exec_fdivr_sti_st0(i) = {
  let result : fp80 = __f80_div(__x87_read_st(0), __x87_read_st(i));
  __x87_write_st(i, result);
  Ok(())
}

// FDIVRP ST(i), ST(0) — ST(i) = ST(0) / ST(i) (reversed), then pop.
val exec_fdivrp_sti : int -> ExecutionResult
function exec_fdivrp_sti(i) = {
  let result : fp80 = __f80_div(__x87_read_st(0), __x87_read_st(i));
  let _ = __x87_pop();
  __x87_write_st(i - 1, result);
  Ok(())
}

// FDIV m32fp — ST(0) = ST(0) / float32.
val exec_fdiv_f32 : dword -> ExecutionResult
function exec_fdiv_f32(val32) = {
  let src : fp80 = __f80_from_f32(val32);
  let result : fp80 = __f80_div(__x87_read_st(0), src);
  __x87_write_st(0, result);
  Ok(())
}

// FDIV m64fp — ST(0) = ST(0) / float64.
val exec_fdiv_f64 : qword -> ExecutionResult
function exec_fdiv_f64(val64) = {
  let src : fp80 = __f80_from_f64(val64);
  let result : fp80 = __f80_div(__x87_read_st(0), src);
  __x87_write_st(0, result);
  Ok(())
}

// FDIVR m32fp — ST(0) = float32 / ST(0) (reversed).
val exec_fdivr_f32 : dword -> ExecutionResult
function exec_fdivr_f32(val32) = {
  let src : fp80 = __f80_from_f32(val32);
  let result : fp80 = __f80_div(src, __x87_read_st(0));
  __x87_write_st(0, result);
  Ok(())
}

// FDIVR m64fp — ST(0) = float64 / ST(0) (reversed).
val exec_fdivr_f64 : qword -> ExecutionResult
function exec_fdivr_f64(val64) = {
  let src : fp80 = __f80_from_f64(val64);
  let result : fp80 = __f80_div(src, __x87_read_st(0));
  __x87_write_st(0, result);
  Ok(())
}

// FIDIV m32int — ST(0) = ST(0) / int32.
val exec_fidiv_i32 : dword -> ExecutionResult
function exec_fidiv_i32(val32) = {
  let src : fp80 = __f80_from_int32(val32);
  let result : fp80 = __f80_div(__x87_read_st(0), src);
  __x87_write_st(0, result);
  Ok(())
}

// FIDIVR m32int — ST(0) = int32 / ST(0) (reversed).
val exec_fidivr_i32 : dword -> ExecutionResult
function exec_fidivr_i32(val32) = {
  let src : fp80 = __f80_from_int32(val32);
  let result : fp80 = __f80_div(src, __x87_read_st(0));
  __x87_write_st(0, result);
  Ok(())
}
// FDIVR/FDIVRP/FIDIVR — Reverse Divide (integer operand forms)
// FIADD/FIMUL/FIDIV i16 forms not covered by fadd/fmul/fdiv.sail.

// FIDIVR m16int — ST(0) = int16 / ST(0) (reversed).
val exec_fidivr_i16 : word -> ExecutionResult
function exec_fidivr_i16(val16) = {
  let src : fp80 = __f80_from_int16(val16);
  let result : fp80 = __f80_div(src, __x87_read_st(0));
  __x87_write_st(0, result);
  Ok(())
}

// FIDIV m16int — ST(0) = ST(0) / int16.
val exec_fidiv_i16 : word -> ExecutionResult
function exec_fidiv_i16(val16) = {
  let src : fp80 = __f80_from_int16(val16);
  let result : fp80 = __f80_div(__x87_read_st(0), src);
  __x87_write_st(0, result);
  Ok(())
}

// FIADD m16int — ST(0) = ST(0) + int16.
val exec_fiadd_i16 : word -> ExecutionResult
function exec_fiadd_i16(val16) = {
  let src : fp80 = __f80_from_int16(val16);
  let result : fp80 = __f80_add(__x87_read_st(0), src);
  __x87_write_st(0, result);
  Ok(())
}

// FIMUL m16int — ST(0) = ST(0) * int16.
val exec_fimul_i16 : word -> ExecutionResult
function exec_fimul_i16(val16) = {
  let src : fp80 = __f80_from_int16(val16);
  let result : fp80 = __f80_mul(__x87_read_st(0), src);
  __x87_write_st(0, result);
  Ok(())
}
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
// FILD — Load Integer
//
// Converts a signed integer source operand into extended-precision
// floating-point format and pushes the value onto the FPU stack.

// FILD m16int — push int16 converted to f80.
val exec_fild_i16 : word -> ExecutionResult
function exec_fild_i16(val16) = {
  __x87_push(__f80_from_int16(val16));
  Ok(())
}

// FILD m32int — push int32 converted to f80.
val exec_fild_i32 : dword -> ExecutionResult
function exec_fild_i32(val32) = {
  __x87_push(__f80_from_int32(val32));
  Ok(())
}

// FILD m64int — push int64 converted to f80.
val exec_fild_i64 : qword -> ExecutionResult
function exec_fild_i64(val64) = {
  __x87_push(__f80_from_int64(val64));
  Ok(())
}
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
// FBLD — Load Binary Coded Decimal
//
// Converts an 80-bit packed BCD value from memory to extended-precision
// floating-point and pushes it onto the FPU stack.

val exec_fbld : fp80 -> ExecutionResult
function exec_fbld(src) = {
  let val80 : fp80 = __f80_from_bcd(src);
  __x87_push(val80);
  Ok(())
}
// FBSTP — Store BCD Integer and Pop
//
// Converts ST(0) to an 80-bit packed BCD value, stores it to memory,
// and pops the register stack.

val exec_fbstp : unit -> fp80
function exec_fbstp() = {
  let v : fp80 = __x87_pop();
  __f80_to_bcd(v)
}
// FABS — Absolute Value
// FCHS — Change Sign
//
// These instructions operate on ST(0) in-place.

// FABS — Replace ST(0) with its absolute value.
val exec_fabs : unit -> ExecutionResult
function exec_fabs() = {
  let result : fp80 = __f80_abs(__x87_read_st(0));
  __x87_write_st(0, result);
  Ok(())
}

// FCHS — Negate ST(0) (change its sign).
val exec_fchs : unit -> ExecutionResult
function exec_fchs() = {
  let result : fp80 = __f80_chs(__x87_read_st(0));
  __x87_write_st(0, result);
  Ok(())
}
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
// FNOP — No Operation (x87)
//
// Performs no FPU operation. Checks for pending unmasked FP exceptions.

val exec_fnop : unit -> ExecutionResult
function exec_fnop() = Ok(())
// FSQRT — Square Root
//
// Computes the square root of ST(0) and stores the result in ST(0).

val exec_fsqrt : unit -> ExecutionResult
function exec_fsqrt() = {
  let result : fp80 = __f80_sqrt(__x87_read_st(0));
  __x87_write_st(0, result);
  Ok(())
}
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
// FXCH — Exchange Register Contents
//
// Exchanges the contents of ST(0) and ST(i).

val exec_fxch : int -> ExecutionResult
function exec_fxch(i) = {
  let v0 : fp80 = __x87_read_st(0);
  let vi : fp80 = __x87_read_st(i);
  __x87_write_st(0, vi);
  __x87_write_st(i, v0);
  Ok(())
}
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
// FXTRACT -- Extract Exponent and Significand
//
// Separates ST(0) into its exponent and significand.
// The exponent replaces ST(0), then the significand is pushed onto the stack.
// After the operation, ST(0) = significand, ST(1) = exponent.

val exec_fxtract : unit -> ExecutionResult
function exec_fxtract() = {
  let val80 : fp80 = __x87_read_st(0);
  let exponent : fp80 = __f80_extract_exponent(val80);
  let significand : fp80 = __f80_extract_significand(val80);
  __x87_write_st(0, exponent);
  __x87_push(significand);
  Ok(())
}
// FYL2X -- Compute y * log2(x)
//
// Computes ST(1) * log2(ST(0)), stores result in ST(1), then pops.
// After the operation, ST(0) contains the result.

val exec_fyl2x : unit -> ExecutionResult
function exec_fyl2x() = {
  let x : fp80 = __x87_read_st(0);
  let y : fp80 = __x87_read_st(1);
  let result : fp80 = __f80_yl2x(y, x);
  let _ = __x87_pop();
  __x87_write_st(0, result);
  Ok(())
}
// FYL2XP1 -- Compute y * log2(x + 1)
//
// Computes ST(1) * log2(ST(0) + 1.0), stores result in ST(1), then pops.
// After the operation, ST(0) contains the result.

val exec_fyl2xp1 : unit -> ExecutionResult
function exec_fyl2xp1() = {
  let x : fp80 = __x87_read_st(0);
  let y : fp80 = __x87_read_st(1);
  let result : fp80 = __f80_yl2xp1(y, x);
  let _ = __x87_pop();
  __x87_write_st(0, result);
  Ok(())
}
// FCMOVcc — Floating-Point Conditional Move
//
// Tests EFLAGS condition codes and moves ST(i) to ST(0) if condition is true.
// Conditions test CF, ZF, PF from the integer EFLAGS register.

// FCMOVB ST(0), ST(i) — Move if below (CF=1).
val exec_fcmovb : int -> ExecutionResult
function exec_fcmovb(i) = {
  if CF == bitone then __x87_write_st(0, __x87_read_st(i));
  Ok(())
}

// FCMOVE ST(0), ST(i) — Move if equal (ZF=1).
val exec_fcmove : int -> ExecutionResult
function exec_fcmove(i) = {
  if ZF == bitone then __x87_write_st(0, __x87_read_st(i));
  Ok(())
}

// FCMOVBE ST(0), ST(i) — Move if below or equal (CF=1 or ZF=1).
val exec_fcmovbe : int -> ExecutionResult
function exec_fcmovbe(i) = {
  if CF == bitone | ZF == bitone then __x87_write_st(0, __x87_read_st(i));
  Ok(())
}

// FCMOVU ST(0), ST(i) — Move if unordered (PF=1).
val exec_fcmovu : int -> ExecutionResult
function exec_fcmovu(i) = {
  if PF == bitone then __x87_write_st(0, __x87_read_st(i));
  Ok(())
}

// FCMOVNB ST(0), ST(i) — Move if not below (CF=0).
val exec_fcmovnb : int -> ExecutionResult
function exec_fcmovnb(i) = {
  if CF == bitzero then __x87_write_st(0, __x87_read_st(i));
  Ok(())
}

// FCMOVNE ST(0), ST(i) — Move if not equal (ZF=0).
val exec_fcmovne : int -> ExecutionResult
function exec_fcmovne(i) = {
  if ZF == bitzero then __x87_write_st(0, __x87_read_st(i));
  Ok(())
}

// FCMOVNBE ST(0), ST(i) — Move if not below or equal (CF=0 and ZF=0).
val exec_fcmovnbe : int -> ExecutionResult
function exec_fcmovnbe(i) = {
  if CF == bitzero & ZF == bitzero then __x87_write_st(0, __x87_read_st(i));
  Ok(())
}

// FCMOVNU ST(0), ST(i) — Move if not unordered (PF=0).
val exec_fcmovnu : int -> ExecutionResult
function exec_fcmovnu(i) = {
  if PF == bitzero then __x87_write_st(0, __x87_read_st(i));
  Ok(())
}
// FSAVE/FNSAVE — Store x87 FPU State
// FRSTOR — Restore x87 FPU State
//
// These instructions save/restore the complete x87 FPU state
// (environment + all 8 data registers). Modeled via external functions.

// FNSAVE — Save FPU state to memory, then reinitialize.
// Returns the full FPU state as a bitvector.
val exec_fnsave : unit -> bits(864)
function exec_fnsave() = {
  let state : bits(864) = __x87_save_state();
  __x87_init();
  state
}

// FRSTOR — Restore FPU state from memory.
val exec_frstor : bits(864) -> ExecutionResult
function exec_frstor(src) = {
  __x87_load_state(src);
  Ok(())
}

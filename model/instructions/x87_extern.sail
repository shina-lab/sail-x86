// x87 FPU External Functions
//
// The x87 stack and control state are managed externally.
// The x87 FPU has an 8-register stack (ST(0) through ST(7)) of 80-bit
// extended precision values. The full x87 state includes the stack pointer,
// status word, control word, and tag word.

// =========================================================================
// Stack access
// =========================================================================

// Read ST(i) — the i-th register from the top of the x87 stack.
val __x87_read_st : int -> fp80

// Write a value to ST(i).
val __x87_write_st : (int, fp80) -> unit

// Push a value onto the x87 stack (decrement TOP, write to new ST(0)).
val __x87_push : fp80 -> unit

// Pop the top of the x87 stack (read ST(0), increment TOP).
val __x87_pop : unit -> fp80

// =========================================================================
// Status/control word access
// =========================================================================

// Read the x87 status word.
val __x87_get_sw : unit -> word

// Write the x87 status word.
val __x87_set_sw : word -> unit

// Read the x87 control word.
val __x87_get_cw : unit -> word

// Write the x87 control word.
val __x87_set_cw : word -> unit

// =========================================================================
// 80-bit extended precision arithmetic
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

// Returns 0.0 in 80-bit extended precision.
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

// Extract the unbiased exponent as an 80-bit FP value.
val __f80_extract_exponent : fp80 -> fp80

// Extract the significand with exponent 0 (biased 3FFF) (used by FXTRACT).
val __f80_extract_significand : fp80 -> fp80

// =========================================================================
// Transcendental operations
// =========================================================================

// Compute y * log2(x) (used by FYL2X). Takes (y, x).
val __f80_yl2x : (fp80, fp80) -> fp80

// Compute y * log2(x + 1) (used by FYL2XP1). Takes (y, x).
val __f80_yl2xp1 : (fp80, fp80) -> fp80

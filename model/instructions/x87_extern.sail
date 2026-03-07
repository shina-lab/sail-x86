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

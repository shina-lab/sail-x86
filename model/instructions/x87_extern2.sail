// x87 FPU External Functions — Extended
//
// Additional external functions for x87 instructions not covered
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
// FPU state management (for FINIT, FLDENV, FSTENV, FSAVE, FRSTOR, etc.)
// =========================================================================

val __x87_init : unit -> unit
val __x87_free : int -> unit
val __x87_get_tag : unit -> word
val __x87_set_tag : word -> unit
val __x87_save_env : unit -> bits(224)
val __x87_load_env : bits(224) -> unit
val __x87_save_state : unit -> bits(864)
val __x87_load_state : bits(864) -> unit

// =========================================================================
// Stack pointer manipulation
// =========================================================================

val __x87_dec_top : unit -> unit
val __x87_inc_top : unit -> unit

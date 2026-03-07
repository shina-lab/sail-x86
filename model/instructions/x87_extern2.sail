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

val __x87_get_tag : unit -> word
function __x87_get_tag() = x87_tw

val __x87_set_tag : word -> unit
function __x87_set_tag(v) = { x87_tw = v }

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

// VRANGEPD — Range Restriction Calculation For Packed Float64 Values (AVX-512 DQ)
// VRANGEPS — Range Restriction Calculation For Packed Float32 Values (AVX-512 DQ)
// VRANGESD — Range Restriction Calculation From a Pair of Scalar Float64 Values (AVX-512 DQ)
// VRANGESS — Range Restriction Calculation From a Pair of Scalar Float32 Values (AVX-512 DQ)
//
// These instructions compute a range operation (min, max, min-abs, max-abs)
// selected by an immediate control on pairs of floating-point values.
// The sign of the result is also controlled by the immediate.
// Modeled as external functions (no YMM/ZMM infrastructure).

val __vrangepd : unit -> ExecutionResult
val exec_vrangepd : unit -> ExecutionResult
function exec_vrangepd() = __vrangepd()

val __vrangeps : unit -> ExecutionResult
val exec_vrangeps : unit -> ExecutionResult
function exec_vrangeps() = __vrangeps()

val __vrangesd : unit -> ExecutionResult
val exec_vrangesd : unit -> ExecutionResult
function exec_vrangesd() = __vrangesd()

val __vrangess : unit -> ExecutionResult
val exec_vrangess : unit -> ExecutionResult
function exec_vrangess() = __vrangess()

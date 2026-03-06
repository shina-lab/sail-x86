// VREDUCEPD — Perform Reduction Transformation on Packed Float64 Values (AVX-512 DQ)
// VREDUCEPH — Perform Reduction Transformation on Packed Float16 Values (AVX-512 FP16)
// VREDUCEPS — Perform Reduction Transformation on Packed Float32 Values (AVX-512 DQ)
// VREDUCESD — Perform Reduction Transformation on Scalar Float64 Value (AVX-512 DQ)
// VREDUCESH — Perform Reduction Transformation on Scalar Float16 Value (AVX-512 FP16)
// VREDUCESS — Perform Reduction Transformation on Scalar Float32 Value (AVX-512 DQ)
//
// These instructions extract the reduced value (the fractional part after
// rounding to a specified number of fraction bits) from floating-point
// values: result = src - round(src). The immediate byte controls the
// rounding mode and number of fraction bits.
// Modeled as external functions (no YMM/ZMM infrastructure).

val __vreducepd : unit -> ExecutionResult
val exec_vreducepd : unit -> ExecutionResult
function exec_vreducepd() = __vreducepd()

val __vreduceph : unit -> ExecutionResult
val exec_vreduceph : unit -> ExecutionResult
function exec_vreduceph() = __vreduceph()

val __vreduceps : unit -> ExecutionResult
val exec_vreduceps : unit -> ExecutionResult
function exec_vreduceps() = __vreduceps()

val __vreducesd : unit -> ExecutionResult
val exec_vreducesd : unit -> ExecutionResult
function exec_vreducesd() = __vreducesd()

val __vreducesh : unit -> ExecutionResult
val exec_vreducesh : unit -> ExecutionResult
function exec_vreducesh() = __vreducesh()

val __vreducess : unit -> ExecutionResult
val exec_vreducess : unit -> ExecutionResult
function exec_vreducess() = __vreducess()

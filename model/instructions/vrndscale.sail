// VRNDSCALEPD — Round Packed Float64 Values To Include A Given Number Of Fraction Bits (AVX-512)
// VRNDSCALEPH — Round Packed Float16 Values To Include A Given Number Of Fraction Bits (AVX-512 FP16)
// VRNDSCALEPS — Round Packed Float32 Values To Include A Given Number Of Fraction Bits (AVX-512)
// VRNDSCALESD — Round Scalar Float64 Value To Include A Given Number Of Fraction Bits (AVX-512)
// VRNDSCALESH — Round Scalar Float16 Value To Include A Given Number Of Fraction Bits (AVX-512 FP16)
// VRNDSCALESS — Round Scalar Float32 Value To Include A Given Number Of Fraction Bits (AVX-512)
//
// These AVX-512 instructions round floating-point values using an immediate
// control byte that specifies rounding mode and number of fraction bits.
// Modeled as external functions (no YMM/ZMM infrastructure).

val __vrndscalepd : unit -> ExecutionResult
val exec_vrndscalepd : unit -> ExecutionResult
function exec_vrndscalepd() = __vrndscalepd()

val __vrndscaleph : unit -> ExecutionResult
val exec_vrndscaleph : unit -> ExecutionResult
function exec_vrndscaleph() = __vrndscaleph()

val __vrndscaleps : unit -> ExecutionResult
val exec_vrndscaleps : unit -> ExecutionResult
function exec_vrndscaleps() = __vrndscaleps()

val __vrndscalesd : unit -> ExecutionResult
val exec_vrndscalesd : unit -> ExecutionResult
function exec_vrndscalesd() = __vrndscalesd()

val __vrndscalesh : unit -> ExecutionResult
val exec_vrndscalesh : unit -> ExecutionResult
function exec_vrndscalesh() = __vrndscalesh()

val __vrndscaless : unit -> ExecutionResult
val exec_vrndscaless : unit -> ExecutionResult
function exec_vrndscaless() = __vrndscaless()

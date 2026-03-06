// VRSQRT14PD — Compute Approximate Reciprocal of Square Roots of Packed Float64 (AVX-512)
// VRSQRT14PS — Compute Approximate Reciprocal of Square Roots of Packed Float32 (AVX-512)
// VRSQRT14SD — Compute Approximate Reciprocal of Square Root of Scalar Float64 (AVX-512)
// VRSQRT14SS — Compute Approximate Reciprocal of Square Root of Scalar Float32 (AVX-512)
// VRSQRT28PD — Compute Approximate Reciprocal of Square Roots of Packed Float64 (AVX-512ER)
// VRSQRT28PS — Compute Approximate Reciprocal of Square Roots of Packed Float32 (AVX-512ER)
// VRSQRT28SD — Compute Approximate Reciprocal of Square Root of Scalar Float64 (AVX-512ER)
// VRSQRT28SS — Compute Approximate Reciprocal of Square Root of Scalar Float32 (AVX-512ER)
// VRSQRTPH — Compute Reciprocal of Square Roots of Packed Float16 (AVX-512 FP16)
// VRSQRTSH — Compute Reciprocal of Square Root of Scalar Float16 (AVX-512 FP16)
//
// These instructions compute approximate reciprocal square roots.
// VRSQRT14 provides ~14 bits of precision, VRSQRT28 provides ~28 bits.
// Modeled as external functions (no YMM/ZMM infrastructure).

val __vrsqrt14pd : unit -> ExecutionResult
val exec_vrsqrt14pd : unit -> ExecutionResult
function exec_vrsqrt14pd() = __vrsqrt14pd()

val __vrsqrt14ps : unit -> ExecutionResult
val exec_vrsqrt14ps : unit -> ExecutionResult
function exec_vrsqrt14ps() = __vrsqrt14ps()

val __vrsqrt14sd : unit -> ExecutionResult
val exec_vrsqrt14sd : unit -> ExecutionResult
function exec_vrsqrt14sd() = __vrsqrt14sd()

val __vrsqrt14ss : unit -> ExecutionResult
val exec_vrsqrt14ss : unit -> ExecutionResult
function exec_vrsqrt14ss() = __vrsqrt14ss()

val __vrsqrt28pd : unit -> ExecutionResult
val exec_vrsqrt28pd : unit -> ExecutionResult
function exec_vrsqrt28pd() = __vrsqrt28pd()

val __vrsqrt28ps : unit -> ExecutionResult
val exec_vrsqrt28ps : unit -> ExecutionResult
function exec_vrsqrt28ps() = __vrsqrt28ps()

val __vrsqrt28sd : unit -> ExecutionResult
val exec_vrsqrt28sd : unit -> ExecutionResult
function exec_vrsqrt28sd() = __vrsqrt28sd()

val __vrsqrt28ss : unit -> ExecutionResult
val exec_vrsqrt28ss : unit -> ExecutionResult
function exec_vrsqrt28ss() = __vrsqrt28ss()

val __vrsqrtph : unit -> ExecutionResult
val exec_vrsqrtph : unit -> ExecutionResult
function exec_vrsqrtph() = __vrsqrtph()

val __vrsqrtsh : unit -> ExecutionResult
val exec_vrsqrtsh : unit -> ExecutionResult
function exec_vrsqrtsh() = __vrsqrtsh()

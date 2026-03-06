// VRCP14PD — Compute Approximate Reciprocals of Packed Float64 Values (AVX-512)
// VRCP14PS — Compute Approximate Reciprocals of Packed Float32 Values (AVX-512)
// VRCP14SD — Compute Approximate Reciprocal of Scalar Float64 Value (AVX-512)
// VRCP14SS — Compute Approximate Reciprocal of Scalar Float32 Value (AVX-512)
//
// These instructions compute approximate reciprocals with a relative error
// bound of 2^-14. Modeled as external functions (no YMM/ZMM infrastructure).

val __vrcp14pd : unit -> ExecutionResult
val exec_vrcp14pd : unit -> ExecutionResult
function exec_vrcp14pd() = __vrcp14pd()

val __vrcp14ps : unit -> ExecutionResult
val exec_vrcp14ps : unit -> ExecutionResult
function exec_vrcp14ps() = __vrcp14ps()

val __vrcp14sd : unit -> ExecutionResult
val exec_vrcp14sd : unit -> ExecutionResult
function exec_vrcp14sd() = __vrcp14sd()

val __vrcp14ss : unit -> ExecutionResult
val exec_vrcp14ss : unit -> ExecutionResult
function exec_vrcp14ss() = __vrcp14ss()

// VRCP28PD — Compute Approximate Reciprocals of Packed Float64 Values to 2^-28 (AVX-512 ER)
// VRCP28PS — Compute Approximate Reciprocals of Packed Float32 Values to 2^-28 (AVX-512 ER)
// VRCP28SD — Compute Approximate Reciprocal of Scalar Float64 Value to 2^-28 (AVX-512 ER)
// VRCP28SS — Compute Approximate Reciprocal of Scalar Float32 Value to 2^-28 (AVX-512 ER)
//
// These instructions compute approximate reciprocals with a relative error
// bound of 2^-28. Modeled as external functions (no YMM/ZMM infrastructure).

val __vrcp28pd : unit -> ExecutionResult
val exec_vrcp28pd : unit -> ExecutionResult
function exec_vrcp28pd() = __vrcp28pd()

val __vrcp28ps : unit -> ExecutionResult
val exec_vrcp28ps : unit -> ExecutionResult
function exec_vrcp28ps() = __vrcp28ps()

val __vrcp28sd : unit -> ExecutionResult
val exec_vrcp28sd : unit -> ExecutionResult
function exec_vrcp28sd() = __vrcp28sd()

val __vrcp28ss : unit -> ExecutionResult
val exec_vrcp28ss : unit -> ExecutionResult
function exec_vrcp28ss() = __vrcp28ss()

// VRCPPH — Compute Approximate Reciprocals of Packed Float16 Values (AVX-512 FP16)
// VRCPSH — Compute Approximate Reciprocal of Scalar Float16 Value (AVX-512 FP16)
//
// These instructions compute approximate reciprocals of half-precision
// floating-point values. Modeled as external functions (no YMM/ZMM infrastructure).

val __vrcpph : unit -> ExecutionResult
val exec_vrcpph : unit -> ExecutionResult
function exec_vrcpph() = __vrcpph()

val __vrcpsh : unit -> ExecutionResult
val exec_vrcpsh : unit -> ExecutionResult
function exec_vrcpsh() = __vrcpsh()

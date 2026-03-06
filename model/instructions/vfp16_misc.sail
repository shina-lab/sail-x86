// VSQRTPH — Compute Square Roots of Packed Float16 Values (AVX-512 FP16)
// VSQRTSH — Compute Square Root of Scalar Float16 Value (AVX-512 FP16)
// VSUBPH — Subtract Packed Float16 Values (AVX-512 FP16)
// VSUBSH — Subtract Scalar Float16 Value (AVX-512 FP16)
// VUCOMISH — Unordered Compare Scalar Float16 Value and Set EFLAGS (AVX-512 FP16)
//
// AVX-512 FP16 miscellaneous instructions.
// Modeled as external functions (no YMM/ZMM infrastructure).

val __vsqrtph : unit -> ExecutionResult
val exec_vsqrtph : unit -> ExecutionResult
function exec_vsqrtph() = __vsqrtph()

val __vsqrtsh : unit -> ExecutionResult
val exec_vsqrtsh : unit -> ExecutionResult
function exec_vsqrtsh() = __vsqrtsh()

val __vsubph : unit -> ExecutionResult
val exec_vsubph : unit -> ExecutionResult
function exec_vsubph() = __vsubph()

val __vsubsh : unit -> ExecutionResult
val exec_vsubsh : unit -> ExecutionResult
function exec_vsubsh() = __vsubsh()

val __vucomish : unit -> ExecutionResult
val exec_vucomish : unit -> ExecutionResult
function exec_vucomish() = __vucomish()

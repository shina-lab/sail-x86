// VSHUFF32X4 — Shuffle Packed Float32 Values at 128-bit Granularity (AVX-512)
// VSHUFF64X2 — Shuffle Packed Float64 Values at 128-bit Granularity (AVX-512)
// VSHUFI32X4 — Shuffle Packed Integer Values at 128-bit Granularity (AVX-512)
// VSHUFI64X2 — Shuffle Packed Integer Values at 128-bit Granularity (AVX-512)
//
// These instructions shuffle 128-bit lanes from two source operands
// into the destination, controlled by an immediate byte.
// Modeled as external functions (no YMM/ZMM infrastructure).

val __vshuff32x4 : unit -> ExecutionResult
val exec_vshuff32x4 : unit -> ExecutionResult
function exec_vshuff32x4() = __vshuff32x4()

val __vshuff64x2 : unit -> ExecutionResult
val exec_vshuff64x2 : unit -> ExecutionResult
function exec_vshuff64x2() = __vshuff64x2()

val __vshufi32x4 : unit -> ExecutionResult
val exec_vshufi32x4 : unit -> ExecutionResult
function exec_vshufi32x4() = __vshufi32x4()

val __vshufi64x2 : unit -> ExecutionResult
val exec_vshufi64x2 : unit -> ExecutionResult
function exec_vshufi64x2() = __vshufi64x2()

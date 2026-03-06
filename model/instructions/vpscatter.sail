// VPSCATTERDD — Scatter Packed Dword Values with Signed Dword Indices (AVX-512)
// VPSCATTERDQ — Scatter Packed Qword Values with Signed Dword Indices (AVX-512)
// VPSCATTERQD — Scatter Packed Dword Values with Signed Qword Indices (AVX-512)
// VPSCATTERQQ — Scatter Packed Qword Values with Signed Qword Indices (AVX-512)
//
// These instructions store packed integer values to memory using VSIB
// addressing. Each element is written to the address formed by the base,
// a signed index from one vector operand, and a scale factor. A mask
// register controls which elements are stored.
// Modeled as external functions (no YMM/ZMM infrastructure).

val __vpscatterdd : unit -> ExecutionResult
val exec_vpscatterdd : unit -> ExecutionResult
function exec_vpscatterdd() = __vpscatterdd()

val __vpscatterdq : unit -> ExecutionResult
val exec_vpscatterdq : unit -> ExecutionResult
function exec_vpscatterdq() = __vpscatterdq()

val __vpscatterqd : unit -> ExecutionResult
val exec_vpscatterqd : unit -> ExecutionResult
function exec_vpscatterqd() = __vpscatterqd()

val __vpscatterqq : unit -> ExecutionResult
val exec_vpscatterqq : unit -> ExecutionResult
function exec_vpscatterqq() = __vpscatterqq()

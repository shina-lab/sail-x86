// VPGATHERDD — Gather Packed Dword Values Using Signed Dword Indices (AVX2/AVX-512)
// VPGATHERDQ — Gather Packed Qword Values Using Signed Dword Indices (AVX2/AVX-512)
// VPGATHERQD — Gather Packed Dword Values Using Signed Qword Indices (AVX2/AVX-512)
// VPGATHERQQ — Gather Packed Qword Values Using Signed Qword Indices (AVX2/AVX-512)
//
// These instructions gather integer values from memory using VSIB addressing.
// Each element is loaded from the address formed by the base, the signed
// index from one vector operand, and a scale factor. A mask register
// controls which elements are loaded.
// Modeled as external functions (no YMM/ZMM infrastructure).

val __vpgatherdd : unit -> ExecutionResult
val exec_vpgatherdd : unit -> ExecutionResult
function exec_vpgatherdd() = __vpgatherdd()

val __vpgatherdq : unit -> ExecutionResult
val exec_vpgatherdq : unit -> ExecutionResult
function exec_vpgatherdq() = __vpgatherdq()

val __vpgatherqd : unit -> ExecutionResult
val exec_vpgatherqd : unit -> ExecutionResult
function exec_vpgatherqd() = __vpgatherqd()

val __vpgatherqq : unit -> ExecutionResult
val exec_vpgatherqq : unit -> ExecutionResult
function exec_vpgatherqq() = __vpgatherqq()

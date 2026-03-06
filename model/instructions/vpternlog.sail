// VPTERNLOGD — Bitwise Ternary Logic on Packed Dword Values (AVX-512)
// VPTERNLOGQ — Bitwise Ternary Logic on Packed Qword Values (AVX-512)
//
// These instructions compute a bitwise ternary function specified by an
// immediate byte on three source operands. The immediate encodes a truth
// table for the 256 possible three-input Boolean functions.
// Modeled as external functions (no YMM/ZMM infrastructure).

val __vpternlogd : unit -> ExecutionResult
val exec_vpternlogd : unit -> ExecutionResult
function exec_vpternlogd() = __vpternlogd()

val __vpternlogq : unit -> ExecutionResult
val exec_vpternlogq : unit -> ExecutionResult
function exec_vpternlogq() = __vpternlogq()

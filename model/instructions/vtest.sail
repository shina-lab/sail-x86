// VTESTPD — Packed Bit Test (AVX)
// VTESTPS — Packed Bit Test (AVX)
//
// These AVX instructions perform bitwise AND and AND-NOT between two XMM/YMM
// registers and set ZF and CF based on the results (sign bits only).
// Modeled as external functions (no YMM/ZMM infrastructure).

val __vtestpd : unit -> ExecutionResult
val exec_vtestpd : unit -> ExecutionResult
function exec_vtestpd() = __vtestpd()

val __vtestps : unit -> ExecutionResult
val exec_vtestps : unit -> ExecutionResult
function exec_vtestps() = __vtestps()

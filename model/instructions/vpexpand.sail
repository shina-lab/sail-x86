// VPEXPANDB — Expand Packed Byte Integer Values (AVX-512 VBMI2)
// VPEXPANDW — Expand Packed Word Integer Values (AVX-512 VBMI2)
// VPEXPANDD — Expand Packed Doubleword Integer Values (AVX-512)
// VPEXPANDQ — Expand Packed Quadword Integer Values (AVX-512)
//
// These instructions load sparse elements from a source operand into
// contiguous positions in the destination, controlled by a write mask.
// Modeled as external functions (no YMM/ZMM infrastructure).

val __vpexpandb : unit -> ExecutionResult
val exec_vpexpandb : unit -> ExecutionResult
function exec_vpexpandb() = __vpexpandb()

val __vpexpandw : unit -> ExecutionResult
val exec_vpexpandw : unit -> ExecutionResult
function exec_vpexpandw() = __vpexpandw()

val __vpexpandd : unit -> ExecutionResult
val exec_vpexpandd : unit -> ExecutionResult
function exec_vpexpandd() = __vpexpandd()

val __vpexpandq : unit -> ExecutionResult
val exec_vpexpandq : unit -> ExecutionResult
function exec_vpexpandq() = __vpexpandq()

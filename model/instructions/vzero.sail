// VZEROALL — Zero All YMM Registers (AVX)
// VZEROUPPER — Zero Upper Bits of YMM Registers (AVX)
//
// VZEROALL zeros all YMM registers (YMM0-YMM15).
// VZEROUPPER zeros the upper 128 bits of all YMM registers.
// Both require YMM/ZMM state management. Modeled as external functions.

val __vzeroall : unit -> ExecutionResult
val exec_vzeroall : unit -> ExecutionResult
function exec_vzeroall() = __vzeroall()

val __vzeroupper : unit -> ExecutionResult
val exec_vzeroupper : unit -> ExecutionResult
function exec_vzeroupper() = __vzeroupper()

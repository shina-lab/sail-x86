// POPA/POPAD — Pop All General-Purpose Registers
// PUSHA/PUSHAD — Push All General-Purpose Registers
//
// These instructions are invalid in 64-bit mode and are used only
// in 16/32-bit real/protected modes. Due to their complex interaction
// with the stack and multiple registers in legacy modes, they are
// modeled as external operations.

val __popa : unit -> ExecutionResult
val __popad : unit -> ExecutionResult
val __pusha : unit -> ExecutionResult
val __pushad : unit -> ExecutionResult

val exec_popa : unit -> ExecutionResult
function exec_popa() = __popa()

val exec_popad : unit -> ExecutionResult
function exec_popad() = __popad()

val exec_pusha : unit -> ExecutionResult
function exec_pusha() = __pusha()

val exec_pushad : unit -> ExecutionResult
function exec_pushad() = __pushad()

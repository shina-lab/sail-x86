// SENTER — Enter Safer Extensions Technology (Intel TXT)
// SEXIT — Exit Safer Extensions Technology (Intel TXT)
//
// These are privileged instructions for Intel Trusted Execution
// Technology. They have complex system-level effects.
// Modeled as external.

val __senter : unit -> ExecutionResult
val __sexit : unit -> ExecutionResult

val exec_senter : unit -> ExecutionResult
function exec_senter() = __senter()

val exec_sexit : unit -> ExecutionResult
function exec_sexit() = __sexit()

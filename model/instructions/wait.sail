// WAIT/FWAIT — Wait for Pending FP Exceptions
//
// Checks for and handles pending unmasked x87 FPU exceptions.
// WAIT and FWAIT are synonymous. The processor checks for pending
// unmasked FP exceptions before proceeding.
// Modeled as external since it requires checking FPU exception state.

val __wait : unit -> ExecutionResult
val exec_wait : unit -> ExecutionResult
function exec_wait() = __wait()

val exec_fwait : unit -> ExecutionResult
function exec_fwait() = __wait()

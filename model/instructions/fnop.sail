// FNOP — No Operation (x87)
//
// Performs no FPU operation. Checks for pending unmasked FP exceptions.

val exec_fnop : unit -> ExecutionResult
function exec_fnop() = Ok(())

// RSM — Resume from System Management Mode
//
// Returns from SMM by restoring processor state from the SMM save area.
// This is a privileged system instruction with complex state restoration.
// Modeled as external.

val __rsm : unit -> ExecutionResult

val exec_rsm : unit -> ExecutionResult
function exec_rsm() = __rsm()

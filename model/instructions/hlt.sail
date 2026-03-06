// HLT — Halt
//
// Stops instruction execution. An interrupt or reset resumes execution.
// No flags affected. Requires CPL=0 in protected mode.

val exec_hlt : unit -> ExecutionResult
function exec_hlt() = Halt(())

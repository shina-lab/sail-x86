// SAVEPREVSSP — Save Previous Shadow Stack Pointer
//
// Saves the previous shadow stack pointer as a shadow stack restore
// token on the previous shadow stack. Part of CET.
// No flags affected. Modeled as external.

val __saveprevssp : unit -> ExecutionResult

val exec_saveprevssp : unit -> ExecutionResult
function exec_saveprevssp() = __saveprevssp()

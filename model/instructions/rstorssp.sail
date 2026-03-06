// RSTORSSP — Restore Saved Shadow Stack Pointer
//
// Restores a previously saved shadow stack pointer from the shadow stack
// token at the specified memory address. Part of CET.
// No flags affected. Modeled as external due to shadow stack complexity.

val __rstorssp : qword -> ExecutionResult

val exec_rstorssp : (qword) -> ExecutionResult
function exec_rstorssp(addr) = __rstorssp(addr)

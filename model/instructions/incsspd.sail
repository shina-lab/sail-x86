// INCSSPD/INCSSPQ -- Increment Shadow Stack Pointer
//
// Increments the shadow stack pointer (SSP) by the number of entries
// specified in the low 8 bits of the source register. Each entry is
// 4 bytes (INCSSPD) or 8 bytes (INCSSPQ).
// This is a CET shadow stack instruction. We model it as external.

val __incsspd : dword -> ExecutionResult
val __incsspq : qword -> ExecutionResult

val exec_incsspd : dword -> ExecutionResult
function exec_incsspd(src) = __incsspd(src)

val exec_incsspq : qword -> ExecutionResult
function exec_incsspq(src) = __incsspq(src)

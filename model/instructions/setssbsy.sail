// SETSSBSY — Mark Shadow Stack Busy
//
// Sets the busy flag in the shadow stack supervisor token at the
// address in IA32_PL0_SSP. Part of CET.
// No flags affected. Modeled as external.

val __setssbsy : unit -> ExecutionResult

val exec_setssbsy : unit -> ExecutionResult
function exec_setssbsy() = __setssbsy()

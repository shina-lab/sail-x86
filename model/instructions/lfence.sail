// LFENCE — Load Fence
// SFENCE — Store Fence
// MFENCE — Memory Fence
//
// These instructions provide memory ordering guarantees.
// They have no architectural effect on registers or flags, so
// we model them as no-ops.

val exec_lfence : unit -> ExecutionResult
function exec_lfence() = Ok(())

val exec_sfence : unit -> ExecutionResult
function exec_sfence() = Ok(())

val exec_mfence : unit -> ExecutionResult
function exec_mfence() = Ok(())

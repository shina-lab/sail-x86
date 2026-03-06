// PREFETCHh — Prefetch Data Into Caches
//
// These are performance hints with no architectural effect on
// registers, flags, or program-visible memory state. They are
// modeled as no-ops.

val exec_prefetcht0 : unit -> ExecutionResult
function exec_prefetcht0() = Ok(())

val exec_prefetcht1 : unit -> ExecutionResult
function exec_prefetcht1() = Ok(())

val exec_prefetcht2 : unit -> ExecutionResult
function exec_prefetcht2() = Ok(())

val exec_prefetchnta : unit -> ExecutionResult
function exec_prefetchnta() = Ok(())

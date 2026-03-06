// PREFETCHW — Prefetch Data Into Caches in Anticipation of a Write
// PREFETCHWT1 — Prefetch With Intent to Write and T1 Hint
//
// These are performance hints with no architectural effect on
// registers, flags, or program-visible memory state. They are
// modeled as no-ops.

val exec_prefetchw : unit -> ExecutionResult
function exec_prefetchw() = Ok(())

val exec_prefetchwt1 : unit -> ExecutionResult
function exec_prefetchwt1() = Ok(())

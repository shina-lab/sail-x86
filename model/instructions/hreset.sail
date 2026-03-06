// HRESET -- History Reset
//
// Requests the processor to reset prediction history for features
// indicated by EAX. Requires CPL=0.
// We model this as a no-op since prediction history is a microarchitectural
// concern that does not affect architectural state.

val exec_hreset : unit -> ExecutionResult
function exec_hreset() = Ok(())

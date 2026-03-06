// MWAIT — Monitor Wait
//
// Enters an implementation-dependent optimized state while waiting
// for a write to the address range set up by MONITOR. This is a
// hint; the processor may exit the optimized state at any time.
// ECX provides extension hints, EAX provides additional hints.
// No flags affected. Requires CPL=0 unless ECX[0]=1 (interrupt-break).
// Modeled as a no-op since the wait behavior is an execution
// environment concern.

val exec_mwait : unit -> ExecutionResult
function exec_mwait() = Ok(())

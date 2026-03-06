// PAUSE — Spin Loop Hint
//
// Provides a hint to the processor that the code is in a spin-wait loop.
// Improves performance and power consumption. Semantically a NOP.

val exec_pause : unit -> ExecutionResult
function exec_pause() = Ok(())

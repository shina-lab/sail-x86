// ENDBR32/ENDBR64 — End Branch (CET Indirect Branch Tracking)
//
// These are CET shadow stack hints. They are effectively no-ops
// for the purpose of this model.

// ENDBR32 — Terminate an Indirect Branch in 32-bit and Compatibility Mode.
val exec_endbr32 : unit -> ExecutionResult
function exec_endbr32() = Ok(())

// ENDBR64 — Terminate an Indirect Branch in 64-bit Mode.
val exec_endbr64 : unit -> ExecutionResult
function exec_endbr64() = Ok(())

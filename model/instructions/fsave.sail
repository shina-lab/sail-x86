// FSAVE/FNSAVE — Store x87 FPU State
// FRSTOR — Restore x87 FPU State
//
// These instructions save/restore the complete x87 FPU state
// (environment + all 8 data registers). Modeled via external functions.

// FNSAVE — Save FPU state to memory, then reinitialize.
// Returns the full FPU state as a bitvector.
val exec_fnsave : unit -> bits(864)
function exec_fnsave() = {
  let state : bits(864) = __x87_save_state();
  __x87_init();
  state
}

// FRSTOR — Restore FPU state from memory.
val exec_frstor : bits(864) -> ExecutionResult
function exec_frstor(src) = {
  __x87_load_state(src);
  Ok(())
}

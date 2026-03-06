// BOUND — Check Array Index Against Bounds
//
// Available in 16/32-bit mode only (invalid in 64-bit mode).
// Raises #BR (exception 5) if the index is out of bounds.
// The exact memory layout and checking logic is implementation-dependent,
// so we model this as an external call.

val __bound_check : (qword, qword, qword) -> ExecutionResult

val exec_bound : (gpr_idx, qword, qword) -> ExecutionResult
function exec_bound(idx, lower, upper) = {
  let index = read_gpr64(idx);
  __bound_check(index, lower, upper)
}

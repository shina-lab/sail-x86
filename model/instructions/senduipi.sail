// SENDUIPI — Send User Interprocessor Interrupt
//
// Sends a user inter-processor interrupt to the target specified
// by the UITT entry indexed by the source register.
// No flags affected. Modeled as external.

val __senduipi : qword -> ExecutionResult

val exec_senduipi : (gpr_idx) -> ExecutionResult
function exec_senduipi(src) = {
  let idx : qword = read_gpr64(src);
  __senduipi(idx)
}

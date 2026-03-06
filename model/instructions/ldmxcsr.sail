// LDMXCSR — Load MXCSR Register
// STMXCSR — Store MXCSR Register
//
// LDMXCSR loads the MXCSR register from a 32-bit memory operand.
// STMXCSR stores the MXCSR register to a 32-bit memory operand.
// The MXCSR register controls SSE rounding mode, flush-to-zero,
// denormals-are-zeros, and exception masks/flags.
// We model MXCSR access as external calls.

val __ldmxcsr : dword -> unit
val __stmxcsr : unit -> dword

val exec_ldmxcsr : dword -> ExecutionResult
function exec_ldmxcsr(val32) = {
  __ldmxcsr(val32);
  Ok(())
}

val exec_stmxcsr : unit -> dword
function exec_stmxcsr() = __stmxcsr()

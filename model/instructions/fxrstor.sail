// FXRSTOR -- Restore x87 FPU, MMX, XMM, and MXCSR State
//
// Restores the x87 FPU, MMX, XMM, and MXCSR register state from a
// 512-byte memory image. The exact layout depends on operating mode.
// We model this as an external operation.

val __fxrstor : qword -> ExecutionResult

val exec_fxrstor : qword -> ExecutionResult
function exec_fxrstor(addr) = __fxrstor(addr)

val __fxrstor64 : qword -> ExecutionResult

val exec_fxrstor64 : qword -> ExecutionResult
function exec_fxrstor64(addr) = __fxrstor64(addr)

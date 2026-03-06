// FXSAVE -- Save x87 FPU, MMX, XMM, and MXCSR State
//
// Saves the x87 FPU, MMX, XMM, and MXCSR register state to a
// 512-byte memory region. The exact layout depends on operating mode.
// We model this as an external operation.

val __fxsave : qword -> ExecutionResult

val exec_fxsave : qword -> ExecutionResult
function exec_fxsave(addr) = __fxsave(addr)

val __fxsave64 : qword -> ExecutionResult

val exec_fxsave64 : qword -> ExecutionResult
function exec_fxsave64(addr) = __fxsave64(addr)

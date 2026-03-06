// XSAVE — Save Processor Extended States
// XSAVEC — Save Processor Extended States with Compaction
// XSAVEOPT — Save Processor Extended States Optimized
// XSAVES — Save Processor Extended States Supervisor
// XRSTOR — Restore Processor Extended States
// XRSTORS — Restore Processor Extended States Supervisor
//
// These instructions save/restore extended processor state components
// (x87 FPU, SSE, AVX, etc.) to/from memory. The state components are
// selected by EDX:EAX (the XSTATE_BV bitmap). Memory layout depends
// on the specific variant (standard, compacted, optimized, supervisor).
// All modeled as external functions due to complex extended state management.

val __xsave : unit -> ExecutionResult
val exec_xsave : unit -> ExecutionResult
function exec_xsave() = __xsave()

val __xsavec : unit -> ExecutionResult
val exec_xsavec : unit -> ExecutionResult
function exec_xsavec() = __xsavec()

val __xsaveopt : unit -> ExecutionResult
val exec_xsaveopt : unit -> ExecutionResult
function exec_xsaveopt() = __xsaveopt()

val __xsaves : unit -> ExecutionResult
val exec_xsaves : unit -> ExecutionResult
function exec_xsaves() = __xsaves()

val __xrstor : unit -> ExecutionResult
val exec_xrstor : unit -> ExecutionResult
function exec_xrstor() = __xrstor()

val __xrstors : unit -> ExecutionResult
val exec_xrstors : unit -> ExecutionResult
function exec_xrstors() = __xrstors()

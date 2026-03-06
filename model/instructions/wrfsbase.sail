// WRFSBASE — Write FS Segment Base
// WRGSBASE — Write GS Segment Base
//
// These instructions write the FS or GS segment base register from a
// general-purpose register. Requires FSGSBASE feature (CR4.FSGSBASE=1).
// System-level instructions modeled as external functions.

val __wrfsbase : unit -> ExecutionResult
val exec_wrfsbase : unit -> ExecutionResult
function exec_wrfsbase() = __wrfsbase()

val __wrgsbase : unit -> ExecutionResult
val exec_wrgsbase : unit -> ExecutionResult
function exec_wrgsbase() = __wrgsbase()

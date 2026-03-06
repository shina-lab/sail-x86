// PTWRITE — Write Data to a Processor Trace Packet
//
// Writes the value of the source operand to a Processor Trace packet.
// This is a trace/debug facility with no architectural effect on
// registers or flags. Modeled as a no-op.

val exec_ptwrite32 : dword -> ExecutionResult
function exec_ptwrite32(_val) = Ok(())

val exec_ptwrite64 : qword -> ExecutionResult
function exec_ptwrite64(_val) = Ok(())

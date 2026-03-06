// Cache Line Hint and Privileged Instructions
//
// CLFLUSH — Cache Line Flush (no-op hint)
// CLFLUSHOPT — Cache Line Flush Optimized (no-op hint)
// CLDEMOTE — Cache Line Demote (no-op hint)
// CLWB — Cache Line Write Back (no-op hint)
// CLAC — Clear AC Flag in EFLAGS (privileged)
// CLTS — Clear Task-Switched Flag in CR0 (privileged)
// CLUI — Clear User Interrupt Flag (privileged)
// CLRSSBSY — Clear Busy Flag in a Supervisor Shadow Stack Token (privileged)

// CLFLUSH — no-op hint, no architectural effect
val exec_clflush : qword -> ExecutionResult
function exec_clflush(_addr) = Ok(())

// CLFLUSHOPT — no-op hint, no architectural effect
val exec_clflushopt : qword -> ExecutionResult
function exec_clflushopt(_addr) = Ok(())

// CLDEMOTE — no-op hint, no architectural effect
val exec_cldemote : qword -> ExecutionResult
function exec_cldemote(_addr) = Ok(())

// CLWB — no-op hint, no architectural effect
val exec_clwb : qword -> ExecutionResult
function exec_clwb(_addr) = Ok(())

// CLAC — Clear AC Flag in EFLAGS (privileged, modeled as external)
val __clac : unit -> ExecutionResult
val exec_clac : unit -> ExecutionResult
function exec_clac() = __clac()

// CLTS — Clear Task-Switched Flag in CR0 (privileged, modeled as external)
val __clts : unit -> ExecutionResult
val exec_clts : unit -> ExecutionResult
function exec_clts() = __clts()

// CLUI — Clear User Interrupt Flag (privileged, modeled as external)
val __clui : unit -> ExecutionResult
val exec_clui : unit -> ExecutionResult
function exec_clui() = __clui()

// CLRSSBSY — Clear Busy Flag in Supervisor Shadow Stack Token (privileged, modeled as external)
val __clrssbsy : qword -> ExecutionResult
val exec_clrssbsy : qword -> ExecutionResult
function exec_clrssbsy(addr) = __clrssbsy(addr)

// WRMSR — Write to Model Specific Register
// WRPKRU — Write Data to User Page Key Register
// WRSSD/WRSSQ — Write to Shadow Stack (CET)
// WRUSSD/WRUSSQ — Write to User Shadow Stack (CET)
//
// System/privileged write instructions.
// WRMSR writes EDX:EAX to the MSR specified in ECX (requires CPL=0).
// WRPKRU writes EAX to PKRU (user-mode protection keys register).
// WRSSD/WRSSQ write to supervisor shadow stack memory.
// WRUSSD/WRUSSQ write to user shadow stack memory.
// All modeled as external functions.

val __wrmsr : unit -> ExecutionResult
val exec_wrmsr : unit -> ExecutionResult
function exec_wrmsr() = __wrmsr()

val __wrpkru : unit -> ExecutionResult
val exec_wrpkru : unit -> ExecutionResult
function exec_wrpkru() = __wrpkru()

val __wrssd : unit -> ExecutionResult
val exec_wrssd : unit -> ExecutionResult
function exec_wrssd() = __wrssd()

val __wrssq : unit -> ExecutionResult
val exec_wrssq : unit -> ExecutionResult
function exec_wrssq() = __wrssq()

val __wrussd : unit -> ExecutionResult
val exec_wrussd : unit -> ExecutionResult
function exec_wrussd() = __wrussd()

val __wrussq : unit -> ExecutionResult
val exec_wrussq : unit -> ExecutionResult
function exec_wrussq() = __wrussq()

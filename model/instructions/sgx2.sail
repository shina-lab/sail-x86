// SGX2 Leaf Functions
//
// These are individual SGX leaf functions invoked via ENCLS/ENCLU.
// Each is modeled as a single external function.

// =========================================================================
// EMODT — Change the Type of an EPC Page (ENCLS leaf)
// =========================================================================

val __emodt : unit -> ExecutionResult
val exec_emodt : unit -> ExecutionResult
function exec_emodt() = __emodt()

// =========================================================================
// EPA — Add Version Array Page (ENCLS leaf)
// =========================================================================

val __epa : unit -> ExecutionResult
val exec_epa : unit -> ExecutionResult
function exec_epa() = __epa()

// =========================================================================
// ERDINFO — Read Type and Status Information About an EPC Page (ENCLS leaf)
// =========================================================================

val __erdinfo : unit -> ExecutionResult
val exec_erdinfo : unit -> ExecutionResult
function exec_erdinfo() = __erdinfo()

// =========================================================================
// EREMOVE — Remove a Page from the EPC (ENCLS leaf)
// =========================================================================

val __eremove : unit -> ExecutionResult
val exec_eremove : unit -> ExecutionResult
function exec_eremove() = __eremove()

// =========================================================================
// EREPORT — Create a Cryptographic Report of the Enclave (ENCLU leaf)
// =========================================================================

val __ereport : unit -> ExecutionResult
val exec_ereport : unit -> ExecutionResult
function exec_ereport() = __ereport()

// =========================================================================
// ERESUME — Re-Enter an Enclave (ENCLU leaf)
// =========================================================================

val __eresume : unit -> ExecutionResult
val exec_eresume : unit -> ExecutionResult
function exec_eresume() = __eresume()

// =========================================================================
// ESETCONTEXT — Set the SECS.MISCSELECT Field (ENCLS leaf)
// =========================================================================

val __esetcontext : unit -> ExecutionResult
val exec_esetcontext : unit -> ExecutionResult
function exec_esetcontext() = __esetcontext()

// =========================================================================
// ETRACK — Activate EBLOCK Checks (ENCLS leaf)
// =========================================================================

val __etrack : unit -> ExecutionResult
val exec_etrack : unit -> ExecutionResult
function exec_etrack() = __etrack()

// =========================================================================
// ETRACKC — Activate EBLOCK Checks (ENCLS leaf, different leaf number)
// =========================================================================

val __etrackc : unit -> ExecutionResult
val exec_etrackc : unit -> ExecutionResult
function exec_etrackc() = __etrackc()

// =========================================================================
// EWB — Evict EPC Page and Write Back (ENCLS leaf)
// =========================================================================

val __ewb : unit -> ExecutionResult
val exec_ewb : unit -> ExecutionResult
function exec_ewb() = __ewb()

// =========================================================================
// ENTERACCS — Execute an Authenticated Code Module (GETSEC leaf)
// =========================================================================

val __enteraccs : unit -> ExecutionResult
val exec_enteraccs : unit -> ExecutionResult
function exec_enteraccs() = __enteraccs()

// =========================================================================
// EXITAC — Exit Authenticated Code Execution Mode (GETSEC leaf)
// =========================================================================

val __exitac : unit -> ExecutionResult
val exec_exitac : unit -> ExecutionResult
function exec_exitac() = __exitac()

// XABORT — Transaction Abort (TSX)
// XBEGIN — Transaction Begin (TSX)
// XEND — Transaction End (TSX)
// XTEST — Test If In Transactional Execution (TSX)
// XACQUIRE/XRELEASE — Hardware Lock Elision Prefixes (HLE)
//
// TSX transactional memory instructions. XABORT explicitly aborts a
// transaction with a reason code. XBEGIN starts a transaction with a
// fallback address. XEND commits a transaction. XTEST sets ZF=0 if
// executing in a transactional region, ZF=1 otherwise.
// XACQUIRE and XRELEASE are HLE lock prefixes; they are no-ops for
// this specification since HLE is architecturally invisible when not
// in a transaction.
// All TSX instructions are modeled as external functions.

val __xabort : unit -> ExecutionResult
val exec_xabort : unit -> ExecutionResult
function exec_xabort() = __xabort()

val __xbegin : unit -> ExecutionResult
val exec_xbegin : unit -> ExecutionResult
function exec_xbegin() = __xbegin()

val __xend : unit -> ExecutionResult
val exec_xend : unit -> ExecutionResult
function exec_xend() = __xend()

val __xtest : unit -> ExecutionResult
val exec_xtest : unit -> ExecutionResult
function exec_xtest() = __xtest()

// XACQUIRE/XRELEASE — HLE lock prefixes are no-ops in this specification.
// They are hint prefixes on LOCK-prefixed instructions and have no
// architectural effect when HLE is not active.

val exec_xacquire : unit -> ExecutionResult
function exec_xacquire() = Ok(())

val exec_xrelease : unit -> ExecutionResult
function exec_xrelease() = Ok(())

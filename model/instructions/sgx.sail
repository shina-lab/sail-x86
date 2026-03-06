// SGX Enclave Instructions
//
// All SGX leaf functions are modeled as single external functions.
// ENCLS — privileged enclave functions (ring 0)
// ENCLU — user-level enclave functions (ring 3)
// ENCLV — virtualization enclave functions

// =========================================================================
// ENCLS — Execute an Enclave System Function of Specified Leaf Number
// =========================================================================

val __encls : unit -> ExecutionResult
val exec_encls : unit -> ExecutionResult
function exec_encls() = __encls()

// =========================================================================
// ENCLU — Execute an Enclave User Function of Specified Leaf Number
// =========================================================================

val __enclu : unit -> ExecutionResult
val exec_enclu : unit -> ExecutionResult
function exec_enclu() = __enclu()

// =========================================================================
// ENCLV — Execute an Enclave VMM Function of Specified Leaf Number
// =========================================================================

val __enclv : unit -> ExecutionResult
val exec_enclv : unit -> ExecutionResult
function exec_enclv() = __enclv()

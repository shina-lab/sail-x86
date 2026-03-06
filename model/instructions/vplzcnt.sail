// VPLZCNTD — Count the Number of Leading Zero Bits for Packed Dword Values (AVX-512 CD)
// VPLZCNTQ — Count the Number of Leading Zero Bits for Packed Qword Values (AVX-512 CD)
//
// These instructions count the number of leading zero bits in each packed
// doubleword or quadword element, writing the count to the destination.
// Modeled as external functions (no YMM/ZMM infrastructure).

val __vplzcntd : unit -> ExecutionResult
val exec_vplzcntd : unit -> ExecutionResult
function exec_vplzcntd() = __vplzcntd()

val __vplzcntq : unit -> ExecutionResult
val exec_vplzcntq : unit -> ExecutionResult
function exec_vplzcntq() = __vplzcntq()

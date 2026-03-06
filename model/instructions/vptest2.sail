// VPTESTMB — Logical AND and Set Mask for Packed Byte Values (AVX-512 BW)
// VPTESTMW — Logical AND and Set Mask for Packed Word Values (AVX-512 BW)
// VPTESTMD — Logical AND and Set Mask for Packed Dword Values (AVX-512)
// VPTESTMQ — Logical AND and Set Mask for Packed Qword Values (AVX-512)
//
// For each element, compute the bitwise AND of the two sources. If the
// result is non-zero, set the corresponding mask bit to 1; otherwise 0.
// Modeled as external functions (no YMM/ZMM infrastructure).

val __vptestmb : unit -> ExecutionResult
val exec_vptestmb : unit -> ExecutionResult
function exec_vptestmb() = __vptestmb()

val __vptestmw : unit -> ExecutionResult
val exec_vptestmw : unit -> ExecutionResult
function exec_vptestmw() = __vptestmw()

val __vptestmd : unit -> ExecutionResult
val exec_vptestmd : unit -> ExecutionResult
function exec_vptestmd() = __vptestmd()

val __vptestmq : unit -> ExecutionResult
val exec_vptestmq : unit -> ExecutionResult
function exec_vptestmq() = __vptestmq()

// VPTESTNMB — Logical NAND and Set Mask for Packed Byte Values (AVX-512 BW)
// VPTESTNMW — Logical NAND and Set Mask for Packed Word Values (AVX-512 BW)
// VPTESTNMD — Logical NAND and Set Mask for Packed Dword Values (AVX-512)
// VPTESTNMQ — Logical NAND and Set Mask for Packed Qword Values (AVX-512)
//
// For each element, compute the bitwise AND of the two sources. If the
// result is zero, set the corresponding mask bit to 1; otherwise 0.

val __vptestnmb : unit -> ExecutionResult
val exec_vptestnmb : unit -> ExecutionResult
function exec_vptestnmb() = __vptestnmb()

val __vptestnmw : unit -> ExecutionResult
val exec_vptestnmw : unit -> ExecutionResult
function exec_vptestnmw() = __vptestnmw()

val __vptestnmd : unit -> ExecutionResult
val exec_vptestnmd : unit -> ExecutionResult
function exec_vptestnmd() = __vptestnmd()

val __vptestnmq : unit -> ExecutionResult
val exec_vptestnmq : unit -> ExecutionResult
function exec_vptestnmq() = __vptestnmq()

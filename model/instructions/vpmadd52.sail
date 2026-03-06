// VPMADD52HUQ — Packed Multiply of Unsigned 52-bit Integers and Add High 52-bit Products (AVX-512 IFMA)
// VPMADD52LUQ — Packed Multiply of Unsigned 52-bit Integers and Add Low 52-bit Products (AVX-512 IFMA)
//
// These instructions multiply packed unsigned 52-bit integers from two
// sources and add either the high or low 52 bits of each product to the
// corresponding quadword element of the destination accumulator.
// Modeled as external functions (no YMM/ZMM infrastructure).

val __vpmadd52huq : unit -> ExecutionResult
val exec_vpmadd52huq : unit -> ExecutionResult
function exec_vpmadd52huq() = __vpmadd52huq()

val __vpmadd52luq : unit -> ExecutionResult
val exec_vpmadd52luq : unit -> ExecutionResult
function exec_vpmadd52luq() = __vpmadd52luq()

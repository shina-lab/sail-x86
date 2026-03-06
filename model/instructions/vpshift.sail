// VPSHLD — Concatenate and Shift Packed Data Left Logical (AVX-512 VBMI2)
//
// Concatenates pairs of elements from two sources, then shifts the
// concatenated value left by an immediate count, storing the high half.

val __vpshld : unit -> ExecutionResult
val exec_vpshld : unit -> ExecutionResult
function exec_vpshld() = __vpshld()

// VPSHLDV — Concatenate and Variable Shift Packed Data Left Logical (AVX-512 VBMI2)
//
// Same as VPSHLD but uses per-element shift counts from a third operand.

val __vpshldv : unit -> ExecutionResult
val exec_vpshldv : unit -> ExecutionResult
function exec_vpshldv() = __vpshldv()

// VPSHRD — Concatenate and Shift Packed Data Right Logical (AVX-512 VBMI2)
//
// Concatenates pairs of elements from two sources, then shifts the
// concatenated value right by an immediate count, storing the low half.

val __vpshrd : unit -> ExecutionResult
val exec_vpshrd : unit -> ExecutionResult
function exec_vpshrd() = __vpshrd()

// VPSHRDV — Concatenate and Variable Shift Packed Data Right Logical (AVX-512 VBMI2)
//
// Same as VPSHRD but uses per-element shift counts from a third operand.

val __vpshrdv : unit -> ExecutionResult
val exec_vpshrdv : unit -> ExecutionResult
function exec_vpshrdv() = __vpshrdv()

// VPSHUFBITQMB — Shuffle Bits from Quadword Elements Using Byte Indices into Mask (AVX-512 BITALG)
//
// For each byte position, uses the byte value as a bit index into the
// corresponding quadword element and writes the selected bit to the mask.

val __vpshufbitqmb : unit -> ExecutionResult
val exec_vpshufbitqmb : unit -> ExecutionResult
function exec_vpshufbitqmb() = __vpshufbitqmb()

// VPSLLVW — Variable Bit Shift Left Logical Packed Word (AVX-512 BW)
// VPSLLVD — Variable Bit Shift Left Logical Packed Dword (AVX2/AVX-512)
// VPSLLVQ — Variable Bit Shift Left Logical Packed Qword (AVX2/AVX-512)
//
// Shift each element left by the per-element count in the source operand.

val __vpsllvw : unit -> ExecutionResult
val exec_vpsllvw : unit -> ExecutionResult
function exec_vpsllvw() = __vpsllvw()

val __vpsllvd : unit -> ExecutionResult
val exec_vpsllvd : unit -> ExecutionResult
function exec_vpsllvd() = __vpsllvd()

val __vpsllvq : unit -> ExecutionResult
val exec_vpsllvq : unit -> ExecutionResult
function exec_vpsllvq() = __vpsllvq()

// VPSRAVW — Variable Bit Shift Right Arithmetic Packed Word (AVX-512 BW)
// VPSRAVD — Variable Bit Shift Right Arithmetic Packed Dword (AVX2/AVX-512)
// VPSRAVQ — Variable Bit Shift Right Arithmetic Packed Qword (AVX-512)
//
// Arithmetic shift each element right by the per-element count in the source.

val __vpsravw : unit -> ExecutionResult
val exec_vpsravw : unit -> ExecutionResult
function exec_vpsravw() = __vpsravw()

val __vpsravd : unit -> ExecutionResult
val exec_vpsravd : unit -> ExecutionResult
function exec_vpsravd() = __vpsravd()

val __vpsravq : unit -> ExecutionResult
val exec_vpsravq : unit -> ExecutionResult
function exec_vpsravq() = __vpsravq()

// VPSRLVW — Variable Bit Shift Right Logical Packed Word (AVX-512 BW)
// VPSRLVD — Variable Bit Shift Right Logical Packed Dword (AVX2/AVX-512)
// VPSRLVQ — Variable Bit Shift Right Logical Packed Qword (AVX2/AVX-512)
//
// Logical shift each element right by the per-element count in the source.

val __vpsrlvw : unit -> ExecutionResult
val exec_vpsrlvw : unit -> ExecutionResult
function exec_vpsrlvw() = __vpsrlvw()

val __vpsrlvd : unit -> ExecutionResult
val exec_vpsrlvd : unit -> ExecutionResult
function exec_vpsrlvd() = __vpsrlvd()

val __vpsrlvq : unit -> ExecutionResult
val exec_vpsrlvq : unit -> ExecutionResult
function exec_vpsrlvq() = __vpsrlvq()

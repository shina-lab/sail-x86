// VPROLD — Rotate Packed Dwords Left by Immediate (AVX-512)
// VPROLVD — Rotate Packed Dwords Left by Variable (AVX-512)
// VPROLQ — Rotate Packed Qwords Left by Immediate (AVX-512)
// VPROLVQ — Rotate Packed Qwords Left by Variable (AVX-512)
//
// These instructions rotate each packed element left by an immediate or
// per-element count from a source register.
// Modeled as external functions (no YMM/ZMM infrastructure).

val __vprold : unit -> ExecutionResult
val exec_vprold : unit -> ExecutionResult
function exec_vprold() = __vprold()

val __vprolvd : unit -> ExecutionResult
val exec_vprolvd : unit -> ExecutionResult
function exec_vprolvd() = __vprolvd()

val __vprolq : unit -> ExecutionResult
val exec_vprolq : unit -> ExecutionResult
function exec_vprolq() = __vprolq()

val __vprolvq : unit -> ExecutionResult
val exec_vprolvq : unit -> ExecutionResult
function exec_vprolvq() = __vprolvq()

// VPRORD — Rotate Packed Dwords Right by Immediate (AVX-512)
// VPRORVD — Rotate Packed Dwords Right by Variable (AVX-512)
// VPRORQ — Rotate Packed Qwords Right by Immediate (AVX-512)
// VPRORVQ — Rotate Packed Qwords Right by Variable (AVX-512)
//
// These instructions rotate each packed element right by an immediate or
// per-element count from a source register.

val __vprord : unit -> ExecutionResult
val exec_vprord : unit -> ExecutionResult
function exec_vprord() = __vprord()

val __vprorvd : unit -> ExecutionResult
val exec_vprorvd : unit -> ExecutionResult
function exec_vprorvd() = __vprorvd()

val __vprorq : unit -> ExecutionResult
val exec_vprorq : unit -> ExecutionResult
function exec_vprorq() = __vprorq()

val __vprorvq : unit -> ExecutionResult
val exec_vprorvq : unit -> ExecutionResult
function exec_vprorvq() = __vprorvq()

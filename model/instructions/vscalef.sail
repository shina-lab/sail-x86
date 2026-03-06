// VSCALEFPD — Scale Packed Float64 Values With Float64 Values (AVX-512)
// VSCALEFPH — Scale Packed Float16 Values With Float16 Values (AVX-512 FP16)
// VSCALEFPS — Scale Packed Float32 Values With Float32 Values (AVX-512)
// VSCALEFSD — Scale Scalar Float64 Value With Float64 Value (AVX-512)
// VSCALEFSH — Scale Scalar Float16 Value With Float16 Value (AVX-512 FP16)
// VSCALEFSS — Scale Scalar Float32 Value With Float32 Value (AVX-512)
//
// These instructions scale floating-point values by powers of two:
// DEST = SRC1 * 2^floor(SRC2). Modeled as external functions.

val __vscalefpd : unit -> ExecutionResult
val exec_vscalefpd : unit -> ExecutionResult
function exec_vscalefpd() = __vscalefpd()

val __vscalefph : unit -> ExecutionResult
val exec_vscalefph : unit -> ExecutionResult
function exec_vscalefph() = __vscalefph()

val __vscalefps : unit -> ExecutionResult
val exec_vscalefps : unit -> ExecutionResult
function exec_vscalefps() = __vscalefps()

val __vscalefsd : unit -> ExecutionResult
val exec_vscalefsd : unit -> ExecutionResult
function exec_vscalefsd() = __vscalefsd()

val __vscalefsh : unit -> ExecutionResult
val exec_vscalefsh : unit -> ExecutionResult
function exec_vscalefsh() = __vscalefsh()

val __vscalefss : unit -> ExecutionResult
val exec_vscalefss : unit -> ExecutionResult
function exec_vscalefss() = __vscalefss()

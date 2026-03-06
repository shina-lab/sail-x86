// VFIXUPIMMPD — Fix Up Special Packed Float64 Values (AVX-512)
// VFIXUPIMMPS — Fix Up Special Packed Float32 Values (AVX-512)
// VFIXUPIMMSD — Fix Up Special Scalar Float64 Value (AVX-512)
// VFIXUPIMMSS — Fix Up Special Scalar Float32 Value (AVX-512)
//
// These instructions fix up special floating-point values (NaN, Inf, denormals,
// etc.) in the destination using a lookup table encoded as integer values in
// the source operand, controlled by an immediate byte.
// EVEX.128/256/512 encodings with writemask support.
// No flags affected.

// External declarations
val __vfixupimmpd : unit -> ExecutionResult
val __vfixupimmps : unit -> ExecutionResult
val __vfixupimmsd : unit -> ExecutionResult
val __vfixupimmss : unit -> ExecutionResult

// VFIXUPIMMPD — Fix Up Special Packed Float64 Values
// EVEX.128/256/512: xmm1/ymm1/zmm1 {k1}{z} := VFIXUPIMMPD(xmm2/ymm2/zmm2, xmm3/ymm3/zmm3/m, imm8)
val exec_vfixupimmpd : unit -> ExecutionResult
function exec_vfixupimmpd() = __vfixupimmpd()

// VFIXUPIMMPS — Fix Up Special Packed Float32 Values
// EVEX.128/256/512: xmm1/ymm1/zmm1 {k1}{z} := VFIXUPIMMPS(xmm2/ymm2/zmm2, xmm3/ymm3/zmm3/m, imm8)
val exec_vfixupimmps : unit -> ExecutionResult
function exec_vfixupimmps() = __vfixupimmps()

// VFIXUPIMMSD — Fix Up Special Scalar Float64 Value
// EVEX.LIG: xmm1 {k1}{z} := VFIXUPIMMSD(xmm2, xmm3/m64, imm8)
val exec_vfixupimmsd : unit -> ExecutionResult
function exec_vfixupimmsd() = __vfixupimmsd()

// VFIXUPIMMSS — Fix Up Special Scalar Float32 Value
// EVEX.LIG: xmm1 {k1}{z} := VFIXUPIMMSS(xmm2, xmm3/m32, imm8)
val exec_vfixupimmss : unit -> ExecutionResult
function exec_vfixupimmss() = __vfixupimmss()

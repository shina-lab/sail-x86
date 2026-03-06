// VGETEXPPD — Convert Exponents of Packed Float64 Values to Float64 Values (AVX-512)
// VGETEXPPH — Convert Exponents of Packed Float16 Values to Float16 Values (AVX-512 FP16)
// VGETEXPPS — Convert Exponents of Packed Float32 Values to Float32 Values (AVX-512)
// VGETEXPSD — Convert Exponent of Scalar Float64 Value to Float64 Value (AVX-512)
// VGETEXPSH — Convert Exponent of Scalar Float16 Value to Float16 Value (AVX-512 FP16)
// VGETEXPSS — Convert Exponent of Scalar Float32 Value to Float32 Value (AVX-512)
//
// These instructions convert the biased exponent of each FP element to an
// FP value representing the unbiased integer exponent. For a normal FP value
// with exponent E, the result is floor(log2(|x|)) as an FP number.
// EVEX encoded with writemask support. No flags affected.

// External declarations
val __vgetexppd : unit -> ExecutionResult
val __vgetexpph : unit -> ExecutionResult
val __vgetexpps : unit -> ExecutionResult
val __vgetexpsd : unit -> ExecutionResult
val __vgetexpsh : unit -> ExecutionResult
val __vgetexpss : unit -> ExecutionResult

// VGETEXPPD — Convert Exponents of Packed Float64 Values
// EVEX.128/256/512: xmm1/ymm1/zmm1 {k1}{z} := VGETEXPPD(xmm2/ymm2/zmm2/m)
val exec_vgetexppd : unit -> ExecutionResult
function exec_vgetexppd() = __vgetexppd()

// VGETEXPPH — Convert Exponents of Packed Float16 Values
// EVEX.128/256/512: xmm1/ymm1/zmm1 {k1}{z} := VGETEXPPH(xmm2/ymm2/zmm2/m)
val exec_vgetexpph : unit -> ExecutionResult
function exec_vgetexpph() = __vgetexpph()

// VGETEXPPS — Convert Exponents of Packed Float32 Values
// EVEX.128/256/512: xmm1/ymm1/zmm1 {k1}{z} := VGETEXPPS(xmm2/ymm2/zmm2/m)
val exec_vgetexpps : unit -> ExecutionResult
function exec_vgetexpps() = __vgetexpps()

// VGETEXPSD — Convert Exponent of Scalar Float64 Value
// EVEX.LIG: xmm1 {k1}{z} := VGETEXPSD(xmm2, xmm3/m64)
val exec_vgetexpsd : unit -> ExecutionResult
function exec_vgetexpsd() = __vgetexpsd()

// VGETEXPSH — Convert Exponent of Scalar Float16 Value
// EVEX.LIG: xmm1 {k1}{z} := VGETEXPSH(xmm2, xmm3/m16)
val exec_vgetexpsh : unit -> ExecutionResult
function exec_vgetexpsh() = __vgetexpsh()

// VGETEXPSS — Convert Exponent of Scalar Float32 Value
// EVEX.LIG: xmm1 {k1}{z} := VGETEXPSS(xmm2, xmm3/m32)
val exec_vgetexpss : unit -> ExecutionResult
function exec_vgetexpss() = __vgetexpss()

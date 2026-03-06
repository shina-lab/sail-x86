// VGETMANTPD — Extract Float64 Vector of Normalized Mantissas from Float64 Vector (AVX-512)
// VGETMANTPH — Extract Float16 Vector of Normalized Mantissas from Float16 Vector (AVX-512 FP16)
// VGETMANTPS — Extract Float32 Vector of Normalized Mantissas from Float32 Vector (AVX-512)
//
// These instructions extract the normalized mantissa from each FP element,
// using the sign control and mantissa interval normalization specified by
// the immediate byte. The result mantissa is in the range [1, 2) or [1/2, 1)
// depending on the interval control.
// EVEX encoded with writemask support. No flags affected.
//
// Scalar variants (VGETMANTSD/SH/SS) are in vgetmant2.sail.

// External declarations
val __vgetmantpd : unit -> ExecutionResult
val __vgetmantph : unit -> ExecutionResult
val __vgetmantps : unit -> ExecutionResult

// VGETMANTPD — Extract Float64 Vector of Normalized Mantissas
// EVEX.128/256/512: xmm1/ymm1/zmm1 {k1}{z} := VGETMANTPD(xmm2/ymm2/zmm2/m, imm8)
val exec_vgetmantpd : unit -> ExecutionResult
function exec_vgetmantpd() = __vgetmantpd()

// VGETMANTPH — Extract Float16 Vector of Normalized Mantissas
// EVEX.128/256/512: xmm1/ymm1/zmm1 {k1}{z} := VGETMANTPH(xmm2/ymm2/zmm2/m, imm8)
val exec_vgetmantph : unit -> ExecutionResult
function exec_vgetmantph() = __vgetmantph()

// VGETMANTPS — Extract Float32 Vector of Normalized Mantissas
// EVEX.128/256/512: xmm1/ymm1/zmm1 {k1}{z} := VGETMANTPS(xmm2/ymm2/zmm2/m, imm8)
val exec_vgetmantps : unit -> ExecutionResult
function exec_vgetmantps() = __vgetmantps()

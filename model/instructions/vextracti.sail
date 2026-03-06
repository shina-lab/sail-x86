// VEXTRACTI128 — Extract 128 Bits of Integer Data (AVX2)
// VEXTRACTI32X4 — Extract 128 Bits of Packed Doubleword Integer Values (AVX-512)
// VEXTRACTI64X2 — Extract 128 Bits of Packed Quadword Integer Values (AVX-512)
// VEXTRACTI32X8 — Extract 256 Bits of Packed Doubleword Integer Values (AVX-512)
// VEXTRACTI64X4 — Extract 256 Bits of Packed Quadword Integer Values (AVX-512)
//
// These instructions extract a portion of integer data from a YMM or ZMM
// register and store the result in an XMM/YMM register or memory location.
// Modeled as external functions (AVX/AVX-512 with YMM/ZMM operands).
// No flags affected.

// External declarations
val __vextracti128  : unit -> ExecutionResult
val __vextracti32x4 : unit -> ExecutionResult
val __vextracti64x2 : unit -> ExecutionResult
val __vextracti32x8 : unit -> ExecutionResult
val __vextracti64x4 : unit -> ExecutionResult

// VEXTRACTI128 — Extract 128 bits of integer data from ymm2
// VEX.256: xmm1/m128 := ymm2[imm8[0]*128+127 : imm8[0]*128]
val exec_vextracti128 : unit -> ExecutionResult
function exec_vextracti128() = __vextracti128()

// VEXTRACTI32X4 — Extract 128 bits of packed dword integer values
// EVEX.256/512: xmm1 {k1}{z} := ymm2/zmm2[selected 128-bit lane]
val exec_vextracti32x4 : unit -> ExecutionResult
function exec_vextracti32x4() = __vextracti32x4()

// VEXTRACTI64X2 — Extract 128 bits of packed qword integer values
// EVEX.256/512: xmm1 {k1}{z} := ymm2/zmm2[selected 128-bit lane]
val exec_vextracti64x2 : unit -> ExecutionResult
function exec_vextracti64x2() = __vextracti64x2()

// VEXTRACTI32X8 — Extract 256 bits of packed dword integer values
// EVEX.512: ymm1 {k1}{z} := zmm2[imm8[0]*256+255 : imm8[0]*256]
val exec_vextracti32x8 : unit -> ExecutionResult
function exec_vextracti32x8() = __vextracti32x8()

// VEXTRACTI64X4 — Extract 256 bits of packed qword integer values
// EVEX.512: ymm1 {k1}{z} := zmm2[imm8[0]*256+255 : imm8[0]*256]
val exec_vextracti64x4 : unit -> ExecutionResult
function exec_vextracti64x4() = __vextracti64x4()

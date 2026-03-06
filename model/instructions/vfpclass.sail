// VFPCLASSPD — Tests Types of Packed Float64 Values (AVX-512)
// VFPCLASSPH — Tests Types of Packed Float16 Values (AVX-512 FP16)
// VFPCLASSPS — Tests Types of Packed Float32 Values (AVX-512)
// VFPCLASSSD — Tests Types of Scalar Float64 Value (AVX-512)
// VFPCLASSSH — Tests Types of Scalar Float16 Value (AVX-512 FP16)
// VFPCLASSSS — Tests Types of Scalar Float32 Value (AVX-512)
//
// Tests each FP element for the categories specified by the imm8 mask
// (NaN, +0, -0, +Inf, -Inf, denormal, finite negative, SNaN). The results
// of each test are OR-ed together per element and written to a mask register.
// EVEX encoded with writemask support. No flags affected.

// External declarations
val __vfpclasspd : unit -> ExecutionResult
val __vfpclassph : unit -> ExecutionResult
val __vfpclassps : unit -> ExecutionResult
val __vfpclasssd : unit -> ExecutionResult
val __vfpclasssh : unit -> ExecutionResult
val __vfpclassss : unit -> ExecutionResult

// VFPCLASSPD — Tests Types of Packed Float64 Values
// EVEX.128/256/512: k2 {k1} := VFPCLASSPD(xmm2/ymm2/zmm2/m, imm8)
val exec_vfpclasspd : unit -> ExecutionResult
function exec_vfpclasspd() = __vfpclasspd()

// VFPCLASSPH — Tests Types of Packed Float16 Values
// EVEX.128/256/512: k2 {k1} := VFPCLASSPH(xmm2/ymm2/zmm2/m, imm8)
val exec_vfpclassph : unit -> ExecutionResult
function exec_vfpclassph() = __vfpclassph()

// VFPCLASSPS — Tests Types of Packed Float32 Values
// EVEX.128/256/512: k2 {k1} := VFPCLASSPS(xmm2/ymm2/zmm2/m, imm8)
val exec_vfpclassps : unit -> ExecutionResult
function exec_vfpclassps() = __vfpclassps()

// VFPCLASSSD — Tests Types of Scalar Float64 Value
// EVEX.LIG: k2 {k1} := VFPCLASSSD(xmm2/m64, imm8)
val exec_vfpclasssd : unit -> ExecutionResult
function exec_vfpclasssd() = __vfpclasssd()

// VFPCLASSSH — Tests Types of Scalar Float16 Value
// EVEX.LIG: k2 {k1} := VFPCLASSSH(xmm2/m16, imm8)
val exec_vfpclasssh : unit -> ExecutionResult
function exec_vfpclasssh() = __vfpclasssh()

// VFPCLASSSS — Tests Types of Scalar Float32 Value
// EVEX.LIG: k2 {k1} := VFPCLASSSS(xmm2/m32, imm8)
val exec_vfpclassss : unit -> ExecutionResult
function exec_vfpclassss() = __vfpclassss()

// AVX/AVX-512 Extract Packed Floating-Point Values
//
// VEXTRACTF128 — VEX.256 encoded, AVX
// VEXTRACTF32X4 — EVEX.256/512 encoded, AVX512F
// VEXTRACTF64X2 — EVEX.256/512 encoded, AVX512DQ
// VEXTRACTF32X8 — EVEX.512 only, AVX512DQ
// VEXTRACTF64X4 — EVEX.512 only, AVX512DQ
//
// All extract a 128-bit or 256-bit lane from a YMM/ZMM register,
// selected by imm8, and store to xmm/ymm or memory.
// These require YMM/ZMM infrastructure we do not model,
// so they are declared as external functions.
// No flags are affected.

// VEXTRACTF128 — Extract 128 bits of packed FP values from ymm2
// VEX.256, AVX
val __vextractf128 : unit -> unit

val exec_vextractf128 : unit -> ExecutionResult
function exec_vextractf128() = {
  __vextractf128();
  Ok(())
}

// VEXTRACTF32X4 — Extract 128 bits of packed single-precision FP values
// EVEX.256/512, AVX512F
val __vextractf32x4 : unit -> unit

val exec_vextractf32x4 : unit -> ExecutionResult
function exec_vextractf32x4() = {
  __vextractf32x4();
  Ok(())
}

// VEXTRACTF64X2 — Extract 128 bits of packed double-precision FP values
// EVEX.256/512, AVX512DQ
val __vextractf64x2 : unit -> unit

val exec_vextractf64x2 : unit -> ExecutionResult
function exec_vextractf64x2() = {
  __vextractf64x2();
  Ok(())
}

// VEXTRACTF32X8 — Extract 256 bits of packed single-precision FP values
// EVEX.512 only, AVX512DQ
val __vextractf32x8 : unit -> unit

val exec_vextractf32x8 : unit -> ExecutionResult
function exec_vextractf32x8() = {
  __vextractf32x8();
  Ok(())
}

// VEXTRACTF64X4 — Extract 256 bits of packed double-precision FP values
// EVEX.512 only, AVX512DQ
val __vextractf64x4 : unit -> unit

val exec_vextractf64x4 : unit -> ExecutionResult
function exec_vextractf64x4() = {
  __vextractf64x4();
  Ok(())
}

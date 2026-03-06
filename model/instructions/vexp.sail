// AVX-512 Exponential and Expand Instructions
//
// All instructions here are EVEX-encoded and require YMM/ZMM infrastructure
// we do not model, so they are declared as external functions.
// No flags are affected.

// =========================================================================
// VEXP2PD — Approximation to the Exponential 2^x of Packed Double-Precision FP
// =========================================================================
//
// EVEX.512 only, AVX512ER
// Computes 2^x approximation with less than 2^-23 relative error for
// each packed double-precision element.
val __vexp2pd : unit -> unit

val exec_vexp2pd : unit -> ExecutionResult
function exec_vexp2pd() = {
  __vexp2pd();
  Ok(())
}

// =========================================================================
// VEXP2PS — Approximation to the Exponential 2^x of Packed Single-Precision FP
// =========================================================================
//
// EVEX.512 only, AVX512ER
// Computes 2^x approximation with less than 2^-23 relative error for
// each packed single-precision element.
val __vexp2ps : unit -> unit

val exec_vexp2ps : unit -> ExecutionResult
function exec_vexp2ps() = {
  __vexp2ps();
  Ok(())
}

// =========================================================================
// VEXPANDPD — Load Sparse Packed Double-Precision FP Values From Dense Memory
// =========================================================================
//
// EVEX.128/256/512, AVX512F
// Expands (loads sparsely) packed double-precision FP values using writemask.
val __vexpandpd : unit -> unit

val exec_vexpandpd : unit -> ExecutionResult
function exec_vexpandpd() = {
  __vexpandpd();
  Ok(())
}

// =========================================================================
// VEXPANDPS — Load Sparse Packed Single-Precision FP Values From Dense Memory
// =========================================================================
//
// EVEX.128/256/512, AVX512F
// Expands (loads sparsely) packed single-precision FP values using writemask.
val __vexpandps : unit -> unit

val exec_vexpandps : unit -> ExecutionResult
function exec_vexpandps() = {
  __vexpandps();
  Ok(())
}

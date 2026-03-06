// Miscellaneous AVX-512 and Privileged Instructions
//
// VDBPSADBW, VDPBF16PS — EVEX-encoded, modeled as external functions.
// VERR/VERW — Privileged segment verification, modeled as external functions.

// =========================================================================
// VDBPSADBW — Double Block Packed Sum-Absolute-Differences on Unsigned Bytes
// =========================================================================
//
// EVEX.128/256/512, AVX512BW
// Computes packed SAD word results from unsigned byte blocks, using
// shuffle controls from imm8. No flags affected.
val __vdbpsadbw : unit -> unit

val exec_vdbpsadbw : unit -> ExecutionResult
function exec_vdbpsadbw() = {
  __vdbpsadbw();
  Ok(())
}

// =========================================================================
// VDPBF16PS — Dot Product of BF16 Pairs Accumulated Into Packed Single Precision
// =========================================================================
//
// EVEX.128/256/512, AVX512_BF16
// Multiplies BF16 pairs and accumulates results as packed single-precision
// floating-point values. No flags affected.
val __vdpbf16ps : unit -> unit

val exec_vdpbf16ps : unit -> ExecutionResult
function exec_vdpbf16ps() = {
  __vdpbf16ps();
  Ok(())
}

// =========================================================================
// VERR — Verify a Segment for Reading
// VERW — Verify a Segment for Writing
// =========================================================================
//
// Privileged instructions that verify segment access rights.
// VERR sets ZF=1 if the segment specified by r/m16 can be read.
// VERW sets ZF=1 if the segment specified by r/m16 can be written.
// These involve descriptor table lookups and privilege checks,
// so they are modeled as external functions.

// Returns true if the segment selector is readable.
val __verr : word -> bool

val exec_verr : word -> ExecutionResult
function exec_verr(selector) = {
  let readable = __verr(selector);
  ZF = if readable then bitone else bitzero;
  Ok(())
}

// Returns true if the segment selector is writable.
val __verw : word -> bool

val exec_verw : word -> ExecutionResult
function exec_verw(selector) = {
  let writable = __verw(selector);
  ZF = if writable then bitone else bitzero;
  Ok(())
}

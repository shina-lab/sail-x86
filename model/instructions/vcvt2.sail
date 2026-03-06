// AVX/AVX-512/EVEX Conversion Instructions (Group 2)
//
// All instructions here are EVEX-encoded and require YMM/ZMM register
// infrastructure we do not model, so they are declared as external functions.
// No flags are affected by any of these instructions.

// =========================================================================
// FP16 -> Integer conversions
// =========================================================================

// VCVTPH2UQQ — Convert Packed FP16 Values to Unsigned Quadword Integers
// EVEX.128/256/512, AVX512-FP16
val __vcvtph2uqq : unit -> unit

val exec_vcvtph2uqq : unit -> ExecutionResult
function exec_vcvtph2uqq() = {
  __vcvtph2uqq();
  Ok(())
}

// VCVTPH2UW — Convert Packed FP16 Values to Unsigned Word Integers
// EVEX.128/256/512, AVX512-FP16
val __vcvtph2uw : unit -> unit

val exec_vcvtph2uw : unit -> ExecutionResult
function exec_vcvtph2uw() = {
  __vcvtph2uw();
  Ok(())
}

// VCVTPH2W — Convert Packed FP16 Values to Signed Word Integers
// EVEX.128/256/512, AVX512-FP16
val __vcvtph2w : unit -> unit

val exec_vcvtph2w : unit -> ExecutionResult
function exec_vcvtph2w() = {
  __vcvtph2w();
  Ok(())
}

// =========================================================================
// FP32 -> FP16 / Integer conversions
// =========================================================================

// VCVTPS2PH — Convert Single-Precision FP to 16-bit FP
// VEX.128/256 (F16C), EVEX.128/256/512 (AVX512F)
val __vcvtps2ph : unit -> unit

val exec_vcvtps2ph : unit -> ExecutionResult
function exec_vcvtps2ph() = {
  __vcvtps2ph();
  Ok(())
}

// VCVTPS2PHX — Convert Single-Precision FP to FP16 (AVX512-FP16)
// EVEX.128/256/512
val __vcvtps2phx : unit -> unit

val exec_vcvtps2phx : unit -> ExecutionResult
function exec_vcvtps2phx() = {
  __vcvtps2phx();
  Ok(())
}

// VCVTPS2QQ — Convert Packed Single-Precision FP to Signed Quadword Integers
// EVEX.128/256/512, AVX512DQ
val __vcvtps2qq : unit -> unit

val exec_vcvtps2qq : unit -> ExecutionResult
function exec_vcvtps2qq() = {
  __vcvtps2qq();
  Ok(())
}

// VCVTPS2UDQ — Convert Packed Single-Precision FP to Unsigned Doubleword Integers
// EVEX.128/256/512, AVX512F
val __vcvtps2udq : unit -> unit

val exec_vcvtps2udq : unit -> ExecutionResult
function exec_vcvtps2udq() = {
  __vcvtps2udq();
  Ok(())
}

// VCVTPS2UQQ — Convert Packed Single-Precision FP to Unsigned Quadword Integers
// EVEX.128/256/512, AVX512DQ
val __vcvtps2uqq : unit -> unit

val exec_vcvtps2uqq : unit -> ExecutionResult
function exec_vcvtps2uqq() = {
  __vcvtps2uqq();
  Ok(())
}

// =========================================================================
// Quadword Integer -> FP conversions
// =========================================================================

// VCVTQQ2PD — Convert Packed Signed Quadword Integers to Packed Double-Precision FP
// EVEX.128/256/512, AVX512DQ
val __vcvtqq2pd : unit -> unit

val exec_vcvtqq2pd : unit -> ExecutionResult
function exec_vcvtqq2pd() = {
  __vcvtqq2pd();
  Ok(())
}

// VCVTQQ2PH — Convert Packed Signed Quadword Integers to Packed FP16
// EVEX.128/256/512, AVX512-FP16
val __vcvtqq2ph : unit -> unit

val exec_vcvtqq2ph : unit -> ExecutionResult
function exec_vcvtqq2ph() = {
  __vcvtqq2ph();
  Ok(())
}

// VCVTQQ2PS — Convert Packed Signed Quadword Integers to Packed Single-Precision FP
// EVEX.128/256/512, AVX512DQ
val __vcvtqq2ps : unit -> unit

val exec_vcvtqq2ps : unit -> ExecutionResult
function exec_vcvtqq2ps() = {
  __vcvtqq2ps();
  Ok(())
}

// =========================================================================
// Scalar SD/SH/SS conversions
// =========================================================================

// VCVTSD2SH — Convert Low FP64 Value to an FP16 Value
// EVEX.LLIG, AVX512-FP16
val __vcvtsd2sh : unit -> unit

val exec_vcvtsd2sh : unit -> ExecutionResult
function exec_vcvtsd2sh() = {
  __vcvtsd2sh();
  Ok(())
}

// VCVTSD2USI — Convert Scalar Double-Precision FP to Unsigned Integer
// EVEX.LLIG, AVX512F, r32 (W0) or r64 (W1)
val __vcvtsd2usi : unit -> unit

val exec_vcvtsd2usi : unit -> ExecutionResult
function exec_vcvtsd2usi() = {
  __vcvtsd2usi();
  Ok(())
}

// VCVTSH2SD — Convert Low FP16 Value to FP64 Value
// EVEX.LLIG, AVX512-FP16
val __vcvtsh2sd : unit -> unit

val exec_vcvtsh2sd : unit -> ExecutionResult
function exec_vcvtsh2sd() = {
  __vcvtsh2sd();
  Ok(())
}

// VCVTSH2SI — Convert Low FP16 Value to Signed Integer
// EVEX.LLIG, AVX512-FP16, r32 (W0) or r64 (W1)
val __vcvtsh2si : unit -> unit

val exec_vcvtsh2si : unit -> ExecutionResult
function exec_vcvtsh2si() = {
  __vcvtsh2si();
  Ok(())
}

// VCVTSH2SS — Convert Low FP16 Value to FP32 Value
// EVEX.LLIG, AVX512-FP16
val __vcvtsh2ss : unit -> unit

val exec_vcvtsh2ss : unit -> ExecutionResult
function exec_vcvtsh2ss() = {
  __vcvtsh2ss();
  Ok(())
}

// VCVTSH2USI — Convert Low FP16 Value to Unsigned Integer
// EVEX.LLIG, AVX512-FP16, r32 (W0) or r64 (W1)
val __vcvtsh2usi : unit -> unit

val exec_vcvtsh2usi : unit -> ExecutionResult
function exec_vcvtsh2usi() = {
  __vcvtsh2usi();
  Ok(())
}

// VCVTSI2SH — Convert Signed Integer to FP16 Value
// EVEX.LLIG, AVX512-FP16, r/m32 (W0) or r/m64 (W1)
val __vcvtsi2sh : unit -> unit

val exec_vcvtsi2sh : unit -> ExecutionResult
function exec_vcvtsi2sh() = {
  __vcvtsi2sh();
  Ok(())
}

// VCVTSS2SH — Convert Low FP32 Value to FP16 Value
// EVEX.LLIG, AVX512-FP16
val __vcvtss2sh : unit -> unit

val exec_vcvtss2sh : unit -> ExecutionResult
function exec_vcvtss2sh() = {
  __vcvtss2sh();
  Ok(())
}

// VCVTSS2USI — Convert Scalar Single-Precision FP to Unsigned Integer
// EVEX.LLIG, AVX512F, r32 (W0) or r64 (W1)
val __vcvtss2usi : unit -> unit

val exec_vcvtss2usi : unit -> ExecutionResult
function exec_vcvtss2usi() = {
  __vcvtss2usi();
  Ok(())
}

// =========================================================================
// Unsigned Doubleword Integer -> FP conversions
// =========================================================================

// VCVTUDQ2PD — Convert Packed Unsigned Doubleword Integers to Packed Double-Precision FP
// EVEX.128/256/512, AVX512F
val __vcvtudq2pd : unit -> unit

val exec_vcvtudq2pd : unit -> ExecutionResult
function exec_vcvtudq2pd() = {
  __vcvtudq2pd();
  Ok(())
}

// VCVTUDQ2PH — Convert Packed Unsigned Doubleword Integers to Packed FP16
// EVEX.128/256/512, AVX512-FP16
val __vcvtudq2ph : unit -> unit

val exec_vcvtudq2ph : unit -> ExecutionResult
function exec_vcvtudq2ph() = {
  __vcvtudq2ph();
  Ok(())
}

// VCVTUDQ2PS — Convert Packed Unsigned Doubleword Integers to Packed Single-Precision FP
// EVEX.128/256/512, AVX512F
val __vcvtudq2ps : unit -> unit

val exec_vcvtudq2ps : unit -> ExecutionResult
function exec_vcvtudq2ps() = {
  __vcvtudq2ps();
  Ok(())
}

// =========================================================================
// Unsigned Quadword Integer -> FP conversions
// =========================================================================

// VCVTUQQ2PD — Convert Packed Unsigned Quadword Integers to Packed Double-Precision FP
// EVEX.128/256/512, AVX512DQ
val __vcvtuqq2pd : unit -> unit

val exec_vcvtuqq2pd : unit -> ExecutionResult
function exec_vcvtuqq2pd() = {
  __vcvtuqq2pd();
  Ok(())
}

// VCVTUQQ2PH — Convert Packed Unsigned Quadword Integers to Packed FP16
// EVEX.128/256/512, AVX512-FP16
val __vcvtuqq2ph : unit -> unit

val exec_vcvtuqq2ph : unit -> ExecutionResult
function exec_vcvtuqq2ph() = {
  __vcvtuqq2ph();
  Ok(())
}

// VCVTUQQ2PS — Convert Packed Unsigned Quadword Integers to Packed Single-Precision FP
// EVEX.128/256/512, AVX512DQ
val __vcvtuqq2ps : unit -> unit

val exec_vcvtuqq2ps : unit -> ExecutionResult
function exec_vcvtuqq2ps() = {
  __vcvtuqq2ps();
  Ok(())
}

// =========================================================================
// Unsigned Scalar Integer -> FP conversions
// =========================================================================

// VCVTUSI2SD — Convert Unsigned Integer to Scalar Double-Precision FP
// EVEX.LLIG, AVX512F, r/m32 (W0) or r/m64 (W1)
val __vcvtusi2sd : unit -> unit

val exec_vcvtusi2sd : unit -> ExecutionResult
function exec_vcvtusi2sd() = {
  __vcvtusi2sd();
  Ok(())
}

// VCVTUSI2SH — Convert Unsigned Integer to Scalar FP16
// EVEX.LLIG, AVX512-FP16, r/m32 (W0) or r/m64 (W1)
val __vcvtusi2sh : unit -> unit

val exec_vcvtusi2sh : unit -> ExecutionResult
function exec_vcvtusi2sh() = {
  __vcvtusi2sh();
  Ok(())
}

// VCVTUSI2SS — Convert Unsigned Integer to Scalar Single-Precision FP
// EVEX.LLIG, AVX512F, r/m32 (W0) or r/m64 (W1)
val __vcvtusi2ss : unit -> unit

val exec_vcvtusi2ss : unit -> ExecutionResult
function exec_vcvtusi2ss() = {
  __vcvtusi2ss();
  Ok(())
}

// =========================================================================
// Word Integer -> FP16 conversions
// =========================================================================

// VCVTUW2PH — Convert Packed Unsigned Word Integers to Packed FP16
// EVEX.128/256/512, AVX512-FP16
val __vcvtuw2ph : unit -> unit

val exec_vcvtuw2ph : unit -> ExecutionResult
function exec_vcvtuw2ph() = {
  __vcvtuw2ph();
  Ok(())
}

// VCVTW2PH — Convert Packed Signed Word Integers to Packed FP16
// EVEX.128/256/512, AVX512-FP16
val __vcvtw2ph : unit -> unit

val exec_vcvtw2ph : unit -> ExecutionResult
function exec_vcvtw2ph() = {
  __vcvtw2ph();
  Ok(())
}

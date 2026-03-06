// AVX-512/EVEX Truncating Conversion Instructions
//
// All VCVTT* instructions convert with truncation (round toward zero).
// These are EVEX-encoded and require YMM/ZMM infrastructure we do not model,
// so they are declared as external functions.
// No flags are affected.

// =========================================================================
// FP64 -> Integer truncating conversions
// =========================================================================

// VCVTTPD2QQ — Convert with Truncation Packed Double-Precision FP to Signed Quadword Integers
// EVEX.128/256/512, AVX512DQ
val __vcvttpd2qq : unit -> unit

val exec_vcvttpd2qq : unit -> ExecutionResult
function exec_vcvttpd2qq() = {
  __vcvttpd2qq();
  Ok(())
}

// VCVTTPD2UDQ — Convert with Truncation Packed Double-Precision FP to Unsigned Doubleword Integers
// EVEX.128/256/512, AVX512F
val __vcvttpd2udq : unit -> unit

val exec_vcvttpd2udq : unit -> ExecutionResult
function exec_vcvttpd2udq() = {
  __vcvttpd2udq();
  Ok(())
}

// VCVTTPD2UQQ — Convert with Truncation Packed Double-Precision FP to Unsigned Quadword Integers
// EVEX.128/256/512, AVX512DQ
val __vcvttpd2uqq : unit -> unit

val exec_vcvttpd2uqq : unit -> ExecutionResult
function exec_vcvttpd2uqq() = {
  __vcvttpd2uqq();
  Ok(())
}

// =========================================================================
// FP16 -> Integer truncating conversions
// =========================================================================

// VCVTTPH2DQ — Convert with Truncation Packed FP16 Values to Signed Doubleword Integers
// EVEX.128/256/512, AVX512-FP16
val __vcvttph2dq : unit -> unit

val exec_vcvttph2dq : unit -> ExecutionResult
function exec_vcvttph2dq() = {
  __vcvttph2dq();
  Ok(())
}

// VCVTTPH2QQ — Convert with Truncation Packed FP16 Values to Signed Quadword Integers
// EVEX.128/256/512, AVX512-FP16
val __vcvttph2qq : unit -> unit

val exec_vcvttph2qq : unit -> ExecutionResult
function exec_vcvttph2qq() = {
  __vcvttph2qq();
  Ok(())
}

// VCVTTPH2UDQ — Convert with Truncation Packed FP16 Values to Unsigned Doubleword Integers
// EVEX.128/256/512, AVX512-FP16
val __vcvttph2udq : unit -> unit

val exec_vcvttph2udq : unit -> ExecutionResult
function exec_vcvttph2udq() = {
  __vcvttph2udq();
  Ok(())
}

// VCVTTPH2UQQ — Convert with Truncation Packed FP16 Values to Unsigned Quadword Integers
// EVEX.128/256/512, AVX512-FP16
val __vcvttph2uqq : unit -> unit

val exec_vcvttph2uqq : unit -> ExecutionResult
function exec_vcvttph2uqq() = {
  __vcvttph2uqq();
  Ok(())
}

// VCVTTPH2UW — Convert with Truncation Packed FP16 Values to Unsigned Word Integers
// EVEX.128/256/512, AVX512-FP16
val __vcvttph2uw : unit -> unit

val exec_vcvttph2uw : unit -> ExecutionResult
function exec_vcvttph2uw() = {
  __vcvttph2uw();
  Ok(())
}

// VCVTTPH2W — Convert with Truncation Packed FP16 Values to Signed Word Integers
// EVEX.128/256/512, AVX512-FP16
val __vcvttph2w : unit -> unit

val exec_vcvttph2w : unit -> ExecutionResult
function exec_vcvttph2w() = {
  __vcvttph2w();
  Ok(())
}

// =========================================================================
// FP32 -> Integer truncating conversions
// =========================================================================

// VCVTTPS2QQ — Convert with Truncation Packed Single-Precision FP to Signed Quadword Integers
// EVEX.128/256/512, AVX512DQ
val __vcvttps2qq : unit -> unit

val exec_vcvttps2qq : unit -> ExecutionResult
function exec_vcvttps2qq() = {
  __vcvttps2qq();
  Ok(())
}

// VCVTTPS2UDQ — Convert with Truncation Packed Single-Precision FP to Unsigned Doubleword Integers
// EVEX.128/256/512, AVX512F
val __vcvttps2udq : unit -> unit

val exec_vcvttps2udq : unit -> ExecutionResult
function exec_vcvttps2udq() = {
  __vcvttps2udq();
  Ok(())
}

// VCVTTPS2UQQ — Convert with Truncation Packed Single-Precision FP to Unsigned Quadword Integers
// EVEX.128/256/512, AVX512DQ
val __vcvttps2uqq : unit -> unit

val exec_vcvttps2uqq : unit -> ExecutionResult
function exec_vcvttps2uqq() = {
  __vcvttps2uqq();
  Ok(())
}

// =========================================================================
// Scalar truncating conversions to unsigned integers
// =========================================================================

// VCVTTSD2USI — Convert with Truncation Scalar Double-Precision FP to Unsigned Integer
// EVEX.LLIG, AVX512F, r32 (W0) or r64 (W1)
val __vcvttsd2usi : unit -> unit

val exec_vcvttsd2usi : unit -> ExecutionResult
function exec_vcvttsd2usi() = {
  __vcvttsd2usi();
  Ok(())
}

// VCVTTSH2SI — Convert with Truncation Low FP16 Value to Signed Integer
// EVEX.LLIG, AVX512-FP16, r32 (W0) or r64 (W1)
val __vcvttsh2si : unit -> unit

val exec_vcvttsh2si : unit -> ExecutionResult
function exec_vcvttsh2si() = {
  __vcvttsh2si();
  Ok(())
}

// VCVTTSH2USI — Convert with Truncation Low FP16 Value to Unsigned Integer
// EVEX.LLIG, AVX512-FP16, r32 (W0) or r64 (W1)
val __vcvttsh2usi : unit -> unit

val exec_vcvttsh2usi : unit -> ExecutionResult
function exec_vcvttsh2usi() = {
  __vcvttsh2usi();
  Ok(())
}

// VCVTTSS2USI — Convert with Truncation Scalar Single-Precision FP to Unsigned Integer
// EVEX.LLIG, AVX512F, r32 (W0) or r64 (W1)
val __vcvttss2usi : unit -> unit

val exec_vcvttss2usi : unit -> ExecutionResult
function exec_vcvttss2usi() = {
  __vcvttss2usi();
  Ok(())
}

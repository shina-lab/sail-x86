// VBROADCAST — Broadcast Floating-Point Data
//
// AVX/AVX-512 instructions that replicate a scalar or smaller vector element
// across all elements of the destination. Require YMM/ZMM infrastructure.
// Modeled as external.

// VBROADCASTSS — Broadcast single-precision FP value
val __vbroadcastss : dword -> zmmword

val exec_vbroadcastss : (simd_idx, xmmword) -> ExecutionResult
function exec_vbroadcastss(dst, src) = {
  let val32 : dword = src[31..0];
  let result : zmmword = __vbroadcastss(val32);
  write_zmm(dst, result);
  Ok(())
}

// VBROADCASTSD — Broadcast double-precision FP value
val __vbroadcastsd : qword -> zmmword

val exec_vbroadcastsd : (simd_idx, xmmword) -> ExecutionResult
function exec_vbroadcastsd(dst, src) = {
  let val64 : qword = src[63..0];
  let result : zmmword = __vbroadcastsd(val64);
  write_zmm(dst, result);
  Ok(())
}

// VBROADCASTF128 — Broadcast 128-bit FP data
val __vbroadcastf128 : xmmword -> zmmword

val exec_vbroadcastf128 : (simd_idx, xmmword) -> ExecutionResult
function exec_vbroadcastf128(dst, src) = {
  let result : zmmword = __vbroadcastf128(src);
  write_zmm(dst, result);
  Ok(())
}

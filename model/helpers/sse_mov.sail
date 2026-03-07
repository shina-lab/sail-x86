// MOVAPS/MOVAPD — Move Aligned Packed FP (Single/Double)
// MOVUPS/MOVUPD — Move Unaligned Packed FP (Single/Double)
// All move 128-bit XMM values. No flags affected.

val exec_movaps : (simd_idx, xmmword) -> ExecutionResult
function exec_movaps(dst, src) = {
  write_xmm_legacy(dst, src);
  Ok()
}

val exec_movapd : (simd_idx, xmmword) -> ExecutionResult
function exec_movapd(dst, src) = {
  write_xmm_legacy(dst, src);
  Ok()
}

val exec_movups : (simd_idx, xmmword) -> ExecutionResult
function exec_movups(dst, src) = {
  write_xmm_legacy(dst, src);
  Ok()
}

val exec_movupd_load : (simd_idx, xmmword) -> ExecutionResult
function exec_movupd_load(dst, src) = {
  write_xmm_legacy(dst, src);
  Ok()
}
// MOVDQA/MOVDQU — Move Aligned/Unaligned Double Quadword

val exec_movdqa : (simd_idx, xmmword) -> ExecutionResult
function exec_movdqa(dst, src) = {
  write_xmm_legacy(dst, src);
  Ok()
}

val exec_movdqu : (simd_idx, xmmword) -> ExecutionResult
function exec_movdqu(dst, src) = {
  write_xmm_legacy(dst, src);
  Ok()
}
// MOVSD — Move Scalar Double Precision FP

val exec_movsd_xmm : (simd_idx, xmmword) -> ExecutionResult
function exec_movsd_xmm(dst, src) = {
  var xmm : xmmword = read_xmm(dst);
  xmm[63..0] = src[63..0];
  write_xmm_legacy(dst, xmm);
  Ok()
}
// MOVSS — Move Scalar Single Precision FP

val exec_movss_xmm : (simd_idx, xmmword) -> ExecutionResult
function exec_movss_xmm(dst, src) = {
  var xmm : xmmword = read_xmm(dst);
  xmm[31..0] = src[31..0];
  write_xmm_legacy(dst, xmm);
  Ok()
}
// MOVSHDUP — Move and Duplicate Odd Single-FP (SSE3)
// MOVSLDUP — Move and Duplicate Even Single-FP (SSE3)

val exec_movshdup : (simd_idx, xmmword) -> ExecutionResult
function exec_movshdup(dst, src) = {
  write_xmm_legacy(dst, src[127..96] @ src[127..96] @ src[63..32] @ src[63..32]);
  Ok()
}

val exec_movsldup : (simd_idx, xmmword) -> ExecutionResult
function exec_movsldup(dst, src) = {
  write_xmm_legacy(dst, src[95..64] @ src[95..64] @ src[31..0] @ src[31..0]);
  Ok()
}
// LDMXCSR/STMXCSR — Load/Store MXCSR Register

val __ldmxcsr : dword -> unit
val __stmxcsr : unit -> dword

val exec_stmxcsr : unit -> dword
function exec_stmxcsr() = __stmxcsr()

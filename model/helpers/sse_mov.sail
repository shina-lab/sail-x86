// MOVAPS/MOVAPD — Move Aligned Packed FP (Single/Double)
// MOVUPS/MOVUPD — Move Unaligned Packed FP (Single/Double)
// All move 128-bit XMM values. Aligned variants require 16-byte alignment
// (enforced by hardware, not modeled here). No flags affected.

val exec_movaps : (simd_idx, xmmword) -> ExecutionResult
function exec_movaps(dst, src) = {
  write_xmm_legacy(dst, src);
  Ok(())
}

val exec_movapd : (simd_idx, xmmword) -> ExecutionResult
function exec_movapd(dst, src) = {
  write_xmm_legacy(dst, src);
  Ok(())
}

val exec_movups : (simd_idx, xmmword) -> ExecutionResult
function exec_movups(dst, src) = {
  write_xmm_legacy(dst, src);
  Ok(())
}

// MOVUPD — Move Unaligned Packed Double-Precision FP
// MOVUPS — Move Unaligned Packed Single-Precision FP
// Moves 128-bit XMM values. Alignment checking is a runtime concern,
// not modeled in the spec. No flags affected.

val exec_movupd_load : (simd_idx, xmmword) -> ExecutionResult
function exec_movupd_load(dst, src) = {
  let v : xmmword = src;
  write_xmm_legacy(dst, v);
  Ok(())
}
// MOVDQA/MOVDQU — Move Aligned/Unaligned Double Quadword
// Moves 128-bit integer data between XMM registers or memory.
// No flags affected.

val exec_movdqa : (simd_idx, xmmword) -> ExecutionResult
function exec_movdqa(dst, src) = {
  write_xmm_legacy(dst, src);
  Ok(())
}

val exec_movdqu : (simd_idx, xmmword) -> ExecutionResult
function exec_movdqu(dst, src) = {
  write_xmm_legacy(dst, src);
  Ok(())
}
// MOVD — Move Doubleword to/from XMM
// MOVQ — Move Quadword to/from XMM
//
// MOVD moves 32 bits between a GPR (or memory) and the low 32 bits of an
// XMM register.  MOVQ moves 64 bits similarly.  When writing to XMM, the
// upper bits of the destination are zeroed (legacy SSE behavior preserves
// upper 128->512 bits, zeros 32/64->128).

// MOVD reg/mem32 -> XMM
val exec_movd_to_xmm : (simd_idx, dword) -> ExecutionResult
function exec_movd_to_xmm(dst, val32) = {
  write_xmm_legacy(dst, zero_extend(val32));
  Ok(())
}

// MOVQ reg/mem64 -> XMM
val exec_movq_to_xmm : (simd_idx, qword) -> ExecutionResult
function exec_movq_to_xmm(dst, val64) = {
  write_xmm_legacy(dst, zero_extend(val64));
  Ok(())
}

// MOVHLPS — Move Packed Single-Precision FP High to Low
// dst[63:0] = src[127:64], dst[127:64] preserved.
// MOVLHPS — Move Packed Single-Precision FP Low to High
// dst[127:64] = src[63:0], dst[63:0] preserved.
// No flags affected.

val exec_movhlps : (simd_idx, xmmword) -> ExecutionResult
function exec_movhlps(dst, src) = {
  let high : qword = read_xmm(dst)[127..64];
  let src_high : qword = src[127..64];
  write_xmm_legacy(dst, high @ src_high);
  Ok(())
}

val exec_movlhps : (simd_idx, xmmword) -> ExecutionResult
function exec_movlhps(dst, src) = {
  let low : qword = read_xmm(dst)[63..0];
  let src_low : qword = src[63..0];
  write_xmm_legacy(dst, src_low @ low);
  Ok(())
}
// MOVLPD/MOVLPS — Move Low Packed FP
// Moves 64 bits to/from XMM[63:0]. Upper 64 bits preserved.
// MOVHPD/MOVHPS — Move High Packed FP
// Moves 64 bits to/from XMM[127:64]. Lower 64 bits preserved.
// No flags affected.

val exec_movlpd : (simd_idx, qword) -> ExecutionResult
function exec_movlpd(dst, src) = {
  var xmm : xmmword = read_xmm(dst);
  xmm[63..0] = src;
  write_xmm_legacy(dst, xmm);
  Ok(())
}

val exec_movlps : (simd_idx, qword) -> ExecutionResult
function exec_movlps(dst, src) = {
  var xmm : xmmword = read_xmm(dst);
  xmm[63..0] = src;
  write_xmm_legacy(dst, xmm);
  Ok(())
}

val exec_movhpd : (simd_idx, qword) -> ExecutionResult
function exec_movhpd(dst, src) = {
  var xmm : xmmword = read_xmm(dst);
  xmm[127..64] = src;
  write_xmm_legacy(dst, xmm);
  Ok(())
}

val exec_movhps : (simd_idx, qword) -> ExecutionResult
function exec_movhps(dst, src) = {
  var xmm : xmmword = read_xmm(dst);
  xmm[127..64] = src;
  write_xmm_legacy(dst, xmm);
  Ok(())
}
// MOVSD — Move Scalar Double Precision FP
// Moves 64-bit double from src XMM[63:0] to dst XMM[63:0].
// When both operands are XMM, upper bits of dst preserved.
// No flags affected.

val exec_movsd_xmm : (simd_idx, xmmword) -> ExecutionResult
function exec_movsd_xmm(dst, src) = {
  var xmm : xmmword = read_xmm(dst);
  xmm[63..0] = src[63..0];
  write_xmm_legacy(dst, xmm);
  Ok(())
}
// MOVSS — Move Scalar Single Precision FP
// Moves 32-bit float from src XMM[31:0] to dst XMM[31:0].
// When both operands are XMM, upper bits of dst preserved.
// No flags affected.

val exec_movss_xmm : (simd_idx, xmmword) -> ExecutionResult
function exec_movss_xmm(dst, src) = {
  var xmm : xmmword = read_xmm(dst);
  xmm[31..0] = src[31..0];
  write_xmm_legacy(dst, xmm);
  Ok(())
}
// MOVQ — Move Quadword between XMM registers
//
// Copies the low 64 bits of the source XMM to the low 64 bits of the
// destination XMM. The upper 64 bits of the 128-bit destination are zeroed.
// Upper bits (128->512) are preserved per legacy SSE convention.

val exec_movq_xmm : (simd_idx, xmmword) -> ExecutionResult
function exec_movq_xmm(dst, src) = {
  write_xmm_legacy(dst, zero_extend(src[63..0]));
  Ok(())
}
// MOVDDUP — Move and Duplicate Double-FP (SSE3)
// Duplicates the low qword of src into both lanes. No flags affected.

val exec_movddup : (simd_idx, xmmword) -> ExecutionResult
function exec_movddup(dst, src) = {
  let s : xmmword = src;
  write_xmm_legacy(dst, s[63..0] @ s[63..0]);
  Ok(())
}
// MOVSHDUP — Move and Duplicate Odd Single-FP (SSE3)
// MOVSLDUP — Move and Duplicate Even Single-FP (SSE3)
// No flags affected.

val exec_movshdup : (simd_idx, xmmword) -> ExecutionResult
function exec_movshdup(dst, src) = {
  let s : xmmword = src;
  write_xmm_legacy(dst, s[127..96] @ s[127..96] @ s[63..32] @ s[63..32]);
  Ok(())
}

val exec_movsldup : (simd_idx, xmmword) -> ExecutionResult
function exec_movsldup(dst, src) = {
  let s : xmmword = src;
  write_xmm_legacy(dst, s[95..64] @ s[95..64] @ s[31..0] @ s[31..0]);
  Ok(())
}
// MOVMSKPS — Extract Packed Single-Precision Floating-Point Sign Mask
// Creates a 4-bit mask from the MSB of each 32-bit single in XMM. No flags affected.

val exec_movmskps : (gpr_idx, xmmword) -> ExecutionResult
function exec_movmskps(dst, s) = {
  let mask : bits(4) = s[127] @ s[95] @ s[63] @ s[31];
  write_gpr32(dst, zero_extend(mask));
  Ok(())
}
// MOVMSKPD — Extract Packed Double-Precision Floating-Point Sign Mask
// Creates a 2-bit mask from the MSB of each 64-bit double in XMM. No flags affected.

val exec_movmskpd : (gpr_idx, xmmword) -> ExecutionResult
function exec_movmskpd(dst, s) = {
  let mask : bits(2) = s[127] @ s[63];
  write_gpr32(dst, zero_extend(mask));
  Ok(())
}
// MOVNTPD — Store Packed Double-FP Using Non-Temporal Hint
// MOVNTPS — Store Packed Single-FP Using Non-Temporal Hint
//
// Non-temporal stores are semantically equivalent to regular stores for
// spec purposes. The non-temporal hint tells the processor to minimize
// cache pollution but has no effect on program-visible state.
// The decoder handles addressing; these functions simply pass through
// the 128-bit value to be stored.

val exec_movntpd : (xmmword) -> xmmword
function exec_movntpd(src) = src

val exec_movntps : (xmmword) -> xmmword
function exec_movntps(src) = src

// MOVNTDQA — Load Double Quadword Non-Temporal Aligned Hint
//
// Non-temporal load is semantically equivalent to a regular 128-bit
// aligned load for spec purposes. The hint tells the processor to
// minimize cache pollution but has no effect on program-visible state.

val exec_movntdqa : (simd_idx, xmmword) -> ExecutionResult
function exec_movntdqa(dst, src) = {
  write_xmm_legacy(dst, src);
  Ok(())
}
// LDMXCSR — Load MXCSR Register
// STMXCSR — Store MXCSR Register
//
// LDMXCSR loads the MXCSR register from a 32-bit memory operand.
// STMXCSR stores the MXCSR register to a 32-bit memory operand.
// The MXCSR register controls SSE rounding mode, flush-to-zero,
// denormals-are-zeros, and exception masks/flags.
// We model MXCSR access as external calls.

val __ldmxcsr : dword -> unit
val __stmxcsr : unit -> dword

val exec_ldmxcsr : dword -> ExecutionResult
function exec_ldmxcsr(val32) = {
  __ldmxcsr(val32);
  Ok(())
}

val exec_stmxcsr : unit -> dword
function exec_stmxcsr() = __stmxcsr()
// STMXCSR — Store MXCSR Register
//
// Note: STMXCSR is already defined in ldmxcsr.sail alongside LDMXCSR.
// This file exists as a placeholder to document that fact.
// See ldmxcsr.sail for the exec_stmxcsr function and __stmxcsr external.
// EMMS — Empty MMX Technology State
// No-op in our XMM-only model.

val exec_emms : unit -> ExecutionResult
function exec_emms() = Ok(())

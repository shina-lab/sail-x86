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

val exec_movupd : (simd_idx, xmmword) -> ExecutionResult
function exec_movupd(dst, src) = {
  write_xmm_legacy(dst, src);
  Ok(())
}

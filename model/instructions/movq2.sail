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

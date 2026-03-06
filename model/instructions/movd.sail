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

// MOVD XMM -> reg32
val exec_movd_from_xmm : (gpr_idx, xmmword) -> ExecutionResult
function exec_movd_from_xmm(dst, src) = {
  write_gpr32(dst, src[31..0]);
  Ok(())
}

// MOVQ reg/mem64 -> XMM
val exec_movq_to_xmm : (simd_idx, qword) -> ExecutionResult
function exec_movq_to_xmm(dst, val64) = {
  write_xmm_legacy(dst, zero_extend(val64));
  Ok(())
}

// MOVQ XMM -> reg64
val exec_movq_from_xmm : (gpr_idx, xmmword) -> ExecutionResult
function exec_movq_from_xmm(dst, src) = {
  write_gpr64(dst, src[63..0]);
  Ok(())
}

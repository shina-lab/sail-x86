// ANDPS/ANDNPS/ORPS/XORPS — Packed Single Precision FP Bitwise Logical
// Pure bitwise operations on 128-bit XMM registers. No flags affected.

val exec_andps : (simd_idx, xmmword) -> ExecutionResult
function exec_andps(dst, src) = {
  write_xmm_legacy(dst, read_xmm(dst) & src);
  Ok(())
}

val exec_andnps : (simd_idx, xmmword) -> ExecutionResult
function exec_andnps(dst, src) = {
  write_xmm_legacy(dst, ~(read_xmm(dst)) & src);
  Ok(())
}

val exec_orps : (simd_idx, xmmword) -> ExecutionResult
function exec_orps(dst, src) = {
  write_xmm_legacy(dst, read_xmm(dst) | src);
  Ok(())
}

val exec_xorps : (simd_idx, xmmword) -> ExecutionResult
function exec_xorps(dst, src) = {
  write_xmm_legacy(dst, xor_vec(read_xmm(dst), src));
  Ok(())
}

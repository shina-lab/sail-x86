// ANDPD/ANDNPD/ORPD/XORPD — Packed Double Precision FP Bitwise Logical
// These are pure bitwise operations on 128-bit XMM registers. No flags affected.

val exec_andpd : (simd_idx, xmmword) -> ExecutionResult
function exec_andpd(dst, src) = {
  write_xmm_legacy(dst, read_xmm(dst) & src);
  Ok(())
}

val exec_andnpd : (simd_idx, xmmword) -> ExecutionResult
function exec_andnpd(dst, src) = {
  write_xmm_legacy(dst, ~(read_xmm(dst)) & src);
  Ok(())
}

val exec_orpd : (simd_idx, xmmword) -> ExecutionResult
function exec_orpd(dst, src) = {
  write_xmm_legacy(dst, read_xmm(dst) | src);
  Ok(())
}

val exec_xorpd : (simd_idx, xmmword) -> ExecutionResult
function exec_xorpd(dst, src) = {
  write_xmm_legacy(dst, xor_vec(read_xmm(dst), src));
  Ok(())
}

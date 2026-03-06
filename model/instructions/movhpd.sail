// MOVHPD — Move High Packed Double-Precision FP
// Load: moves 64-bit memory value into XMM[127:64], preserving XMM[63:0].
// Store: returns XMM[127:64] as a 64-bit value.
// No flags affected.

val exec_movhpd_load : (simd_idx, qword) -> ExecutionResult
function exec_movhpd_load(dst, mem_val) = {
  let low : qword = read_xmm(dst)[63..0];
  write_xmm_legacy(dst, mem_val @ low);
  Ok(())
}

val exec_movhpd_store : (simd_idx) -> qword
function exec_movhpd_store(dst) = read_xmm(dst)[127..64]

// MOVHPS -- Move High Packed Single-Precision FP Values
//
// Load form: moves 64-bit memory value into XMM[127:64], preserving XMM[63:0].
// Store form: returns XMM[127:64] as a 64-bit value.
// No flags affected.

// MOVHPS xmm, m64 (load)
val exec_movhps_load : (simd_idx, qword) -> ExecutionResult
function exec_movhps_load(dst, mem_val) = {
  let low : qword = read_xmm(dst)[63..0];
  write_xmm_legacy(dst, mem_val @ low);
  Ok(())
}

// MOVHPS m64, xmm (store)
val exec_movhps_store : (xmmword) -> qword
function exec_movhps_store(src) = src[127..64]

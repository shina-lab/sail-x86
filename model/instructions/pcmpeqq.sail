// PCMPEQQ — Compare Packed Qword Data for Equal (SSE4.1)
//
// Compares two 64-bit (qword) lanes for equality.
// Each lane is set to all-ones if equal, all-zeros otherwise.

val exec_pcmpeqq : (simd_idx, xmmword) -> ExecutionResult
function exec_pcmpeqq(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    (if a[127..64] == b[127..64] then ones() else zeros() : qword) @
    (if a[63..0] == b[63..0] then ones() else zeros() : qword);
  write_xmm_legacy(dst, r);
  Ok(())
}

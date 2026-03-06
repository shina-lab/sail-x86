// PCMPGTQ — Compare Packed Signed Qword Data for Greater Than (SSE4.2)
//
// Compares two signed 64-bit (qword) lanes.
// Each lane is set to all-ones if signed(dst) > signed(src), all-zeros otherwise.

val exec_pcmpgtq : (simd_idx, xmmword) -> ExecutionResult
function exec_pcmpgtq(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    (if signed(a[127..64]) > signed(b[127..64]) then ones() else zeros() : qword) @
    (if signed(a[63..0]) > signed(b[63..0]) then ones() else zeros() : qword);
  write_xmm_legacy(dst, r);
  Ok(())
}

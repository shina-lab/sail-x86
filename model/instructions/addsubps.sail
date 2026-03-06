// ADDSUBPS — Packed Single-FP Add/Subtract (SSE3)
// Lanes 0,2: subtract; Lanes 1,3: add. No flags affected.

val exec_addsubps : (simd_idx, xmmword) -> ExecutionResult
function exec_addsubps(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let d0 : dword = __f32_sub(a[31..0], b[31..0]);
  let d1 : dword = __f32_add(a[63..32], b[63..32]);
  let d2 : dword = __f32_sub(a[95..64], b[95..64]);
  let d3 : dword = __f32_add(a[127..96], b[127..96]);
  write_xmm_legacy(dst, d3 @ d2 @ d1 @ d0);
  Ok(())
}

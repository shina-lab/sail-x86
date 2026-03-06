// BLENDPS — Blend Packed Single-FP (SSE4.1)
// imm8[0..3] each select the corresponding lane: 0=dst, 1=src.
// No flags affected.

val exec_blendps : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_blendps(dst, src, imm8) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let d0 : dword = if imm8[0] == bitone then b[31..0] else a[31..0];
  let d1 : dword = if imm8[1] == bitone then b[63..32] else a[63..32];
  let d2 : dword = if imm8[2] == bitone then b[95..64] else a[95..64];
  let d3 : dword = if imm8[3] == bitone then b[127..96] else a[127..96];
  write_xmm_legacy(dst, d3 @ d2 @ d1 @ d0);
  Ok(())
}

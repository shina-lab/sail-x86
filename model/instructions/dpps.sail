// DPPS — Dot Product of Packed Single-FP (SSE4.1)
// imm8[7:4] selects which products to include, imm8[3:0] selects output lanes.
// No flags affected.

val exec_dpps : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_dpps(dst, src, imm8) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let zero : dword = 0x00000000;
  let temp0 : dword = if imm8[4] == bitone then __f32_mul(a[31..0], b[31..0]) else zero;
  let temp1 : dword = if imm8[5] == bitone then __f32_mul(a[63..32], b[63..32]) else zero;
  let temp2 : dword = if imm8[6] == bitone then __f32_mul(a[95..64], b[95..64]) else zero;
  let temp3 : dword = if imm8[7] == bitone then __f32_mul(a[127..96], b[127..96]) else zero;
  let sum01 : dword = __f32_add(temp0, temp1);
  let sum23 : dword = __f32_add(temp2, temp3);
  let sum : dword = __f32_add(sum01, sum23);
  let d0 : dword = if imm8[0] == bitone then sum else zero;
  let d1 : dword = if imm8[1] == bitone then sum else zero;
  let d2 : dword = if imm8[2] == bitone then sum else zero;
  let d3 : dword = if imm8[3] == bitone then sum else zero;
  write_xmm_legacy(dst, d3 @ d2 @ d1 @ d0);
  Ok(())
}

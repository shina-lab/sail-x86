// SHUFPS — Shuffle Packed Single-Precision FP Values
// imm8[1:0] selects result[31:0] from dst's 4 dwords.
// imm8[3:2] selects result[63:32] from dst's 4 dwords.
// imm8[5:4] selects result[95:64] from src's 4 dwords.
// imm8[7:6] selects result[127:96] from src's 4 dwords.
// No flags affected.

val select_dword : (xmmword, bits(2)) -> dword
function select_dword(v, sel) = {
  let idx : range(0, 3) = unsigned(sel);
  v[(idx * 32 + 31) .. (idx * 32)]
}

val exec_shufps : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_shufps(dst, src, imm8) = {
  let d : xmmword = read_xmm(dst);
  let s : xmmword = src;
  let d0 : dword = select_dword(d, imm8[1..0]);
  let d1 : dword = select_dword(d, imm8[3..2]);
  let d2 : dword = select_dword(s, imm8[5..4]);
  let d3 : dword = select_dword(s, imm8[7..6]);
  write_xmm_legacy(dst, d3 @ d2 @ d1 @ d0);
  Ok(())
}

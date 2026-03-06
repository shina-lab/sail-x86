// PSHUFD — Shuffle Packed Doublewords
// Selects dwords from src based on imm8 control. No flags affected.

val exec_pshufd : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_pshufd(dst, src, imm8) = {
  let s : xmmword = src;
  let sel0 : range(0, 3) = unsigned(imm8[1..0]);
  let sel1 : range(0, 3) = unsigned(imm8[3..2]);
  let sel2 : range(0, 3) = unsigned(imm8[5..4]);
  let sel3 : range(0, 3) = unsigned(imm8[7..6]);
  let d0 : dword = s[(sel0 * 32 + 31) .. (sel0 * 32)];
  let d1 : dword = s[(sel1 * 32 + 31) .. (sel1 * 32)];
  let d2 : dword = s[(sel2 * 32 + 31) .. (sel2 * 32)];
  let d3 : dword = s[(sel3 * 32 + 31) .. (sel3 * 32)];
  write_xmm_legacy(dst, d3 @ d2 @ d1 @ d0);
  Ok(())
}

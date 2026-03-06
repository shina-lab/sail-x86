// PSHUFW — Shuffle Packed Words (MMX)
// Selects words from 64-bit MMX source based on imm8 control.
// No flags affected. This is an MMX instruction operating on 64-bit values.
// Modeled as operating on the low 64 bits of XMM registers.

val exec_pshufw : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_pshufw(dst, src, imm8) = {
  let s : xmmword = src;
  let sel0 : range(0, 3) = unsigned(imm8[1..0]);
  let sel1 : range(0, 3) = unsigned(imm8[3..2]);
  let sel2 : range(0, 3) = unsigned(imm8[5..4]);
  let sel3 : range(0, 3) = unsigned(imm8[7..6]);
  let w0 : word = s[(sel0 * 16 + 15) .. (sel0 * 16)];
  let w1 : word = s[(sel1 * 16 + 15) .. (sel1 * 16)];
  let w2 : word = s[(sel2 * 16 + 15) .. (sel2 * 16)];
  let w3 : word = s[(sel3 * 16 + 15) .. (sel3 * 16)];
  write_xmm_legacy(dst, zero_extend(w3 @ w2 @ w1 @ w0));
  Ok(())
}

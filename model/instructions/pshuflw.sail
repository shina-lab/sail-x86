// PSHUFLW — Shuffle Packed Low Words
// High qword copied unchanged from src. Low qword: 4 words selected
// from src's low qword by imm8. No flags affected.

val select_low_word : (xmmword, bits(2)) -> word
function select_low_word(v, sel) = {
  let idx : range(0, 3) = unsigned(sel);
  v[(idx * 16 + 15) .. (idx * 16)]
}

val exec_pshuflw : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_pshuflw(dst, src, imm8) = {
  let s : xmmword = src;
  let high : qword = s[127..64];
  let w0 : word = select_low_word(s, imm8[1..0]);
  let w1 : word = select_low_word(s, imm8[3..2]);
  let w2 : word = select_low_word(s, imm8[5..4]);
  let w3 : word = select_low_word(s, imm8[7..6]);
  write_xmm_legacy(dst, high @ w3 @ w2 @ w1 @ w0);
  Ok(())
}

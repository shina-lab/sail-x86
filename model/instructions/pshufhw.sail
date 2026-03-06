// PSHUFHW — Shuffle Packed High Words
// Low qword copied unchanged from src. High qword: 4 words selected
// from src's high qword by imm8. No flags affected.

val select_high_word : (xmmword, bits(2)) -> word
function select_high_word(v, sel) = {
  let idx : range(0, 3) = unsigned(sel);
  v[(idx * 16 + 79) .. (idx * 16 + 64)]
}

val exec_pshufhw : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_pshufhw(dst, src, imm8) = {
  let s : xmmword = src;
  let low : qword = s[63..0];
  let w0 : word = select_high_word(s, imm8[1..0]);
  let w1 : word = select_high_word(s, imm8[3..2]);
  let w2 : word = select_high_word(s, imm8[5..4]);
  let w3 : word = select_high_word(s, imm8[7..6]);
  write_xmm_legacy(dst, w3 @ w2 @ w1 @ w0 @ low);
  Ok(())
}

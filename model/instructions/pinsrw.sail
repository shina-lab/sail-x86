// PINSRW — Insert Word
// Insert a 16-bit value into XMM at position selected by imm8[2..0].
// Other words unchanged. No flags affected.

val insert_word : (xmmword, word, range(0, 7)) -> xmmword
function insert_word(v, w, sel) = {
  match sel {
    0 => v[127..16] @ w,
    1 => v[127..32] @ w @ v[15..0],
    2 => v[127..48] @ w @ v[31..0],
    3 => v[127..64] @ w @ v[47..0],
    4 => v[127..80] @ w @ v[63..0],
    5 => v[127..96] @ w @ v[79..0],
    6 => v[127..112] @ w @ v[95..0],
    7 => w @ v[111..0]
  }
}

val exec_pinsrw : (simd_idx, word, byte) -> ExecutionResult
function exec_pinsrw(dst, val16, imm8) = {
  let v : xmmword = read_xmm(dst);
  let sel : range(0, 7) = unsigned(imm8[2..0]);
  let r : xmmword = insert_word(v, val16, sel);
  write_xmm_legacy(dst, r);
  Ok(())
}

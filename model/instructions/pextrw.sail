// PEXTRW — Extract Word
// Extract a 16-bit word from XMM selected by imm8[2..0], zero-extend to 32-bit,
// write to GPR. No flags affected.

val exec_pextrw : (gpr_idx, xmmword, byte) -> ExecutionResult
function exec_pextrw(dst, s, imm8) = {
  let sel : range(0, 7) = unsigned(imm8[2..0]);
  let word : word = match sel {
    0 => s[15..0],
    1 => s[31..16],
    2 => s[47..32],
    3 => s[63..48],
    4 => s[79..64],
    5 => s[95..80],
    6 => s[111..96],
    7 => s[127..112]
  };
  write_gpr32(dst, zero_extend(word));
  Ok(())
}

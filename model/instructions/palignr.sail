// PALIGNR — Packed Align Right (SSSE3)
// Concatenates dst:src, shifts right by imm8 bytes, takes low 128 bits.
// No flags affected.

val palignr_shift : (ymmword, int) -> xmmword
function palignr_shift(concat, shift_bytes) = {
  if shift_bytes <= 0 then concat[127..0]
  else if shift_bytes >= 32 then zeros()
  else (concat >> (shift_bytes * 8))[127..0]
}

val exec_palignr : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_palignr(dst, src, imm8) = {
  let d : xmmword = read_xmm(dst);
  let s : xmmword = src;
  let r : xmmword = palignr_shift(d @ s, unsigned(imm8));
  write_xmm_legacy(dst, r);
  Ok(())
}

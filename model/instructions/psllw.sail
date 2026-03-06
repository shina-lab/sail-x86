// PSLLW/PSLLD/PSLLQ — Shift Packed Data Left Logical
// PSRLW/PSRLD/PSRLQ — Shift Packed Data Right Logical
// PSRAW/PSRAD — Shift Packed Data Right Arithmetic
// Shift count from imm8 or XMM. No flags affected.

val sll16 : (word, int) -> word
function sll16(v, count) = if count > 15 | count < 0 then zeros() else v << count

val sll32 : (dword, int) -> dword
function sll32(v, count) = if count > 31 | count < 0 then zeros() else v << count

val sll64 : (qword, int) -> qword
function sll64(v, count) = if count > 63 | count < 0 then zeros() else v << count

val srl16 : (word, int) -> word
function srl16(v, count) = if count > 15 | count < 0 then zeros() else v >> count

val srl32 : (dword, int) -> dword
function srl32(v, count) = if count > 31 | count < 0 then zeros() else v >> count

val srl64 : (qword, int) -> qword
function srl64(v, count) = if count > 63 | count < 0 then zeros() else v >> count

val sra16 : (word, int) -> word
function sra16(v, count) = {
  if count <= 0 then v
  else if count > 15 then shift_right_arith(v, 15)
  else shift_right_arith(v, count)
}

val sra32 : (dword, int) -> dword
function sra32(v, count) = {
  if count <= 0 then v
  else if count > 31 then shift_right_arith(v, 31)
  else shift_right_arith(v, count)
}

val exec_psllw_imm : (simd_idx, byte) -> ExecutionResult
function exec_psllw_imm(dst, imm8) = {
  let c : int = unsigned(imm8);
  let a : xmmword = read_xmm(dst);
  let r : xmmword =
    sll16(a[127..112], c) @ sll16(a[111..96], c) @
    sll16(a[95..80], c) @ sll16(a[79..64], c) @
    sll16(a[63..48], c) @ sll16(a[47..32], c) @
    sll16(a[31..16], c) @ sll16(a[15..0], c);
  write_xmm_legacy(dst, r);
  Ok(())
}

val exec_pslld_imm : (simd_idx, byte) -> ExecutionResult
function exec_pslld_imm(dst, imm8) = {
  let c : int = unsigned(imm8);
  let a : xmmword = read_xmm(dst);
  let r : xmmword =
    sll32(a[127..96], c) @ sll32(a[95..64], c) @
    sll32(a[63..32], c) @ sll32(a[31..0], c);
  write_xmm_legacy(dst, r);
  Ok(())
}

val exec_psllq_imm : (simd_idx, byte) -> ExecutionResult
function exec_psllq_imm(dst, imm8) = {
  let c : int = unsigned(imm8);
  let a : xmmword = read_xmm(dst);
  let r : xmmword = sll64(a[127..64], c) @ sll64(a[63..0], c);
  write_xmm_legacy(dst, r);
  Ok(())
}

val exec_psrlw_imm : (simd_idx, byte) -> ExecutionResult
function exec_psrlw_imm(dst, imm8) = {
  let c : int = unsigned(imm8);
  let a : xmmword = read_xmm(dst);
  let r : xmmword =
    srl16(a[127..112], c) @ srl16(a[111..96], c) @
    srl16(a[95..80], c) @ srl16(a[79..64], c) @
    srl16(a[63..48], c) @ srl16(a[47..32], c) @
    srl16(a[31..16], c) @ srl16(a[15..0], c);
  write_xmm_legacy(dst, r);
  Ok(())
}

val exec_psrld_imm : (simd_idx, byte) -> ExecutionResult
function exec_psrld_imm(dst, imm8) = {
  let c : int = unsigned(imm8);
  let a : xmmword = read_xmm(dst);
  let r : xmmword =
    srl32(a[127..96], c) @ srl32(a[95..64], c) @
    srl32(a[63..32], c) @ srl32(a[31..0], c);
  write_xmm_legacy(dst, r);
  Ok(())
}

val exec_psrlq_imm : (simd_idx, byte) -> ExecutionResult
function exec_psrlq_imm(dst, imm8) = {
  let c : int = unsigned(imm8);
  let a : xmmword = read_xmm(dst);
  let r : xmmword = srl64(a[127..64], c) @ srl64(a[63..0], c);
  write_xmm_legacy(dst, r);
  Ok(())
}

val exec_psraw_imm : (simd_idx, byte) -> ExecutionResult
function exec_psraw_imm(dst, imm8) = {
  let c : int = unsigned(imm8);
  let a : xmmword = read_xmm(dst);
  let r : xmmword =
    sra16(a[127..112], c) @ sra16(a[111..96], c) @
    sra16(a[95..80], c) @ sra16(a[79..64], c) @
    sra16(a[63..48], c) @ sra16(a[47..32], c) @
    sra16(a[31..16], c) @ sra16(a[15..0], c);
  write_xmm_legacy(dst, r);
  Ok(())
}

val exec_psrad_imm : (simd_idx, byte) -> ExecutionResult
function exec_psrad_imm(dst, imm8) = {
  let c : int = unsigned(imm8);
  let a : xmmword = read_xmm(dst);
  let r : xmmword =
    sra32(a[127..96], c) @ sra32(a[95..64], c) @
    sra32(a[63..32], c) @ sra32(a[31..0], c);
  write_xmm_legacy(dst, r);
  Ok(())
}

// Shift-by-XMM variants: count comes from low 64 bits of source XMM.

val exec_psllw_xmm : (simd_idx, xmmword) -> ExecutionResult
function exec_psllw_xmm(dst, src) = {
  let c : int = unsigned(src[63..0]);
  let a : xmmword = read_xmm(dst);
  let r : xmmword =
    sll16(a[127..112], c) @ sll16(a[111..96], c) @
    sll16(a[95..80], c) @ sll16(a[79..64], c) @
    sll16(a[63..48], c) @ sll16(a[47..32], c) @
    sll16(a[31..16], c) @ sll16(a[15..0], c);
  write_xmm_legacy(dst, r);
  Ok(())
}

val exec_pslld_xmm : (simd_idx, xmmword) -> ExecutionResult
function exec_pslld_xmm(dst, src) = {
  let c : int = unsigned(src[63..0]);
  let a : xmmword = read_xmm(dst);
  let r : xmmword =
    sll32(a[127..96], c) @ sll32(a[95..64], c) @
    sll32(a[63..32], c) @ sll32(a[31..0], c);
  write_xmm_legacy(dst, r);
  Ok(())
}

val exec_psllq_xmm : (simd_idx, xmmword) -> ExecutionResult
function exec_psllq_xmm(dst, src) = {
  let c : int = unsigned(src[63..0]);
  let a : xmmword = read_xmm(dst);
  let r : xmmword = sll64(a[127..64], c) @ sll64(a[63..0], c);
  write_xmm_legacy(dst, r);
  Ok(())
}

val exec_psrlw_xmm : (simd_idx, xmmword) -> ExecutionResult
function exec_psrlw_xmm(dst, src) = {
  let c : int = unsigned(src[63..0]);
  let a : xmmword = read_xmm(dst);
  let r : xmmword =
    srl16(a[127..112], c) @ srl16(a[111..96], c) @
    srl16(a[95..80], c) @ srl16(a[79..64], c) @
    srl16(a[63..48], c) @ srl16(a[47..32], c) @
    srl16(a[31..16], c) @ srl16(a[15..0], c);
  write_xmm_legacy(dst, r);
  Ok(())
}

val exec_psrld_xmm : (simd_idx, xmmword) -> ExecutionResult
function exec_psrld_xmm(dst, src) = {
  let c : int = unsigned(src[63..0]);
  let a : xmmword = read_xmm(dst);
  let r : xmmword =
    srl32(a[127..96], c) @ srl32(a[95..64], c) @
    srl32(a[63..32], c) @ srl32(a[31..0], c);
  write_xmm_legacy(dst, r);
  Ok(())
}

val exec_psrlq_xmm : (simd_idx, xmmword) -> ExecutionResult
function exec_psrlq_xmm(dst, src) = {
  let c : int = unsigned(src[63..0]);
  let a : xmmword = read_xmm(dst);
  let r : xmmword = srl64(a[127..64], c) @ srl64(a[63..0], c);
  write_xmm_legacy(dst, r);
  Ok(())
}

val exec_psraw_xmm : (simd_idx, xmmword) -> ExecutionResult
function exec_psraw_xmm(dst, src) = {
  let c : int = unsigned(src[63..0]);
  let a : xmmword = read_xmm(dst);
  let r : xmmword =
    sra16(a[127..112], c) @ sra16(a[111..96], c) @
    sra16(a[95..80], c) @ sra16(a[79..64], c) @
    sra16(a[63..48], c) @ sra16(a[47..32], c) @
    sra16(a[31..16], c) @ sra16(a[15..0], c);
  write_xmm_legacy(dst, r);
  Ok(())
}

val exec_psrad_xmm : (simd_idx, xmmword) -> ExecutionResult
function exec_psrad_xmm(dst, src) = {
  let c : int = unsigned(src[63..0]);
  let a : xmmword = read_xmm(dst);
  let r : xmmword =
    sra32(a[127..96], c) @ sra32(a[95..64], c) @
    sra32(a[63..32], c) @ sra32(a[31..0], c);
  write_xmm_legacy(dst, r);
  Ok(())
}

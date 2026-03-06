// PMINSB/PMINSW/PMINSD — Packed Minimum Signed Integers
// PMINSB and PMINSD are SSE4.1; PMINSW is SSE2.
// No flags affected.

val min_s8 : (byte, byte) -> byte
function min_s8(a, b) = if signed(a) < signed(b) then a else b

val min_s16 : (word, word) -> word
function min_s16(a, b) = if signed(a) < signed(b) then a else b

val min_s32 : (dword, dword) -> dword
function min_s32(a, b) = if signed(a) < signed(b) then a else b

val exec_pminsb : (simd_idx, xmmword) -> ExecutionResult
function exec_pminsb(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    min_s8(a[127..120], b[127..120]) @ min_s8(a[119..112], b[119..112]) @
    min_s8(a[111..104], b[111..104]) @ min_s8(a[103..96], b[103..96]) @
    min_s8(a[95..88], b[95..88]) @ min_s8(a[87..80], b[87..80]) @
    min_s8(a[79..72], b[79..72]) @ min_s8(a[71..64], b[71..64]) @
    min_s8(a[63..56], b[63..56]) @ min_s8(a[55..48], b[55..48]) @
    min_s8(a[47..40], b[47..40]) @ min_s8(a[39..32], b[39..32]) @
    min_s8(a[31..24], b[31..24]) @ min_s8(a[23..16], b[23..16]) @
    min_s8(a[15..8], b[15..8]) @ min_s8(a[7..0], b[7..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

val exec_pminsw : (simd_idx, xmmword) -> ExecutionResult
function exec_pminsw(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    min_s16(a[127..112], b[127..112]) @ min_s16(a[111..96], b[111..96]) @
    min_s16(a[95..80], b[95..80]) @ min_s16(a[79..64], b[79..64]) @
    min_s16(a[63..48], b[63..48]) @ min_s16(a[47..32], b[47..32]) @
    min_s16(a[31..16], b[31..16]) @ min_s16(a[15..0], b[15..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

val exec_pminsd : (simd_idx, xmmword) -> ExecutionResult
function exec_pminsd(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    min_s32(a[127..96], b[127..96]) @ min_s32(a[95..64], b[95..64]) @
    min_s32(a[63..32], b[63..32]) @ min_s32(a[31..0], b[31..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

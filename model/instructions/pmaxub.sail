// PMAXUB/PMAXUW/PMAXUD — Packed Maximum Unsigned Integers
// PMAXUB is SSE2; PMAXUW and PMAXUD are SSE4.1.
// No flags affected.

val max_u8 : (byte, byte) -> byte
function max_u8(a, b) = if unsigned(a) > unsigned(b) then a else b

val max_u16 : (word, word) -> word
function max_u16(a, b) = if unsigned(a) > unsigned(b) then a else b

val max_u32 : (dword, dword) -> dword
function max_u32(a, b) = if unsigned(a) > unsigned(b) then a else b

val exec_pmaxub : (simd_idx, xmmword) -> ExecutionResult
function exec_pmaxub(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    max_u8(a[127..120], b[127..120]) @ max_u8(a[119..112], b[119..112]) @
    max_u8(a[111..104], b[111..104]) @ max_u8(a[103..96], b[103..96]) @
    max_u8(a[95..88], b[95..88]) @ max_u8(a[87..80], b[87..80]) @
    max_u8(a[79..72], b[79..72]) @ max_u8(a[71..64], b[71..64]) @
    max_u8(a[63..56], b[63..56]) @ max_u8(a[55..48], b[55..48]) @
    max_u8(a[47..40], b[47..40]) @ max_u8(a[39..32], b[39..32]) @
    max_u8(a[31..24], b[31..24]) @ max_u8(a[23..16], b[23..16]) @
    max_u8(a[15..8], b[15..8]) @ max_u8(a[7..0], b[7..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

val exec_pmaxuw : (simd_idx, xmmword) -> ExecutionResult
function exec_pmaxuw(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    max_u16(a[127..112], b[127..112]) @ max_u16(a[111..96], b[111..96]) @
    max_u16(a[95..80], b[95..80]) @ max_u16(a[79..64], b[79..64]) @
    max_u16(a[63..48], b[63..48]) @ max_u16(a[47..32], b[47..32]) @
    max_u16(a[31..16], b[31..16]) @ max_u16(a[15..0], b[15..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

val exec_pmaxud : (simd_idx, xmmword) -> ExecutionResult
function exec_pmaxud(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    max_u32(a[127..96], b[127..96]) @ max_u32(a[95..64], b[95..64]) @
    max_u32(a[63..32], b[63..32]) @ max_u32(a[31..0], b[31..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

// PUNPCKLBW — Unpack Low Data (Bytes to Words)
// PUNPCKLWD — Unpack Low Data (Words to Doublewords)
// PUNPCKLDQ — Unpack Low Data (Doublewords to Quadwords)
// PUNPCKLQDQ — Unpack Low Data (Quadwords to Double Quadword)
// Interleave low-order data elements from dst and src. No flags affected.

val exec_punpcklbw : (simd_idx, xmmword) -> ExecutionResult
function exec_punpcklbw(dst, src) = {
  let d : xmmword = read_xmm(dst);
  let s : xmmword = src;
  let result : xmmword =
    s[63..56] @ d[63..56] @
    s[55..48] @ d[55..48] @
    s[47..40] @ d[47..40] @
    s[39..32] @ d[39..32] @
    s[31..24] @ d[31..24] @
    s[23..16] @ d[23..16] @
    s[15..8]  @ d[15..8]  @
    s[7..0]   @ d[7..0];
  write_xmm_legacy(dst, result);
  Ok(())
}

val exec_punpcklwd : (simd_idx, xmmword) -> ExecutionResult
function exec_punpcklwd(dst, src) = {
  let d : xmmword = read_xmm(dst);
  let s : xmmword = src;
  let result : xmmword =
    s[63..48] @ d[63..48] @
    s[47..32] @ d[47..32] @
    s[31..16] @ d[31..16] @
    s[15..0]  @ d[15..0];
  write_xmm_legacy(dst, result);
  Ok(())
}

val exec_punpckldq : (simd_idx, xmmword) -> ExecutionResult
function exec_punpckldq(dst, src) = {
  let d : xmmword = read_xmm(dst);
  let s : xmmword = src;
  let result : xmmword =
    s[63..32] @ d[63..32] @
    s[31..0]  @ d[31..0];
  write_xmm_legacy(dst, result);
  Ok(())
}

val exec_punpcklqdq : (simd_idx, xmmword) -> ExecutionResult
function exec_punpcklqdq(dst, src) = {
  let d : xmmword = read_xmm(dst);
  let s : xmmword = src;
  write_xmm_legacy(dst, s[63..0] @ d[63..0]);
  Ok(())
}

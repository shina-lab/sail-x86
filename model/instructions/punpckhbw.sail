// PUNPCKHBW — Unpack High Data (Bytes to Words)
// PUNPCKHWD — Unpack High Data (Words to Doublewords)
// PUNPCKHDQ — Unpack High Data (Doublewords to Quadwords)
// PUNPCKHQDQ — Unpack High Data (Quadwords to Double Quadword)
// Interleave high-order data elements from dst and src. No flags affected.

val exec_punpckhbw : (simd_idx, xmmword) -> ExecutionResult
function exec_punpckhbw(dst, src) = {
  let d : xmmword = read_xmm(dst);
  let s : xmmword = src;
  let result : xmmword =
    s[127..120] @ d[127..120] @
    s[119..112] @ d[119..112] @
    s[111..104] @ d[111..104] @
    s[103..96]  @ d[103..96]  @
    s[95..88]   @ d[95..88]   @
    s[87..80]   @ d[87..80]   @
    s[79..72]   @ d[79..72]   @
    s[71..64]   @ d[71..64];
  write_xmm_legacy(dst, result);
  Ok(())
}

val exec_punpckhwd : (simd_idx, xmmword) -> ExecutionResult
function exec_punpckhwd(dst, src) = {
  let d : xmmword = read_xmm(dst);
  let s : xmmword = src;
  let result : xmmword =
    s[127..112] @ d[127..112] @
    s[111..96]  @ d[111..96]  @
    s[95..80]   @ d[95..80]   @
    s[79..64]   @ d[79..64];
  write_xmm_legacy(dst, result);
  Ok(())
}

val exec_punpckhdq : (simd_idx, xmmword) -> ExecutionResult
function exec_punpckhdq(dst, src) = {
  let d : xmmword = read_xmm(dst);
  let s : xmmword = src;
  let result : xmmword =
    s[127..96] @ d[127..96] @
    s[95..64]  @ d[95..64];
  write_xmm_legacy(dst, result);
  Ok(())
}

val exec_punpckhqdq : (simd_idx, xmmword) -> ExecutionResult
function exec_punpckhqdq(dst, src) = {
  let d : xmmword = read_xmm(dst);
  let s : xmmword = src;
  write_xmm_legacy(dst, s[127..64] @ d[127..64]);
  Ok(())
}

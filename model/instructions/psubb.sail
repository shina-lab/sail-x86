// PSUBB/PSUBW/PSUBD/PSUBQ — Subtract Packed Integers
// Wrapping subtraction per lane. No flags affected.

val exec_psubb : (simd_idx, xmmword) -> ExecutionResult
function exec_psubb(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    (a[127..120] - b[127..120]) @ (a[119..112] - b[119..112]) @
    (a[111..104] - b[111..104]) @ (a[103..96] - b[103..96]) @
    (a[95..88] - b[95..88]) @ (a[87..80] - b[87..80]) @
    (a[79..72] - b[79..72]) @ (a[71..64] - b[71..64]) @
    (a[63..56] - b[63..56]) @ (a[55..48] - b[55..48]) @
    (a[47..40] - b[47..40]) @ (a[39..32] - b[39..32]) @
    (a[31..24] - b[31..24]) @ (a[23..16] - b[23..16]) @
    (a[15..8] - b[15..8]) @ (a[7..0] - b[7..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

val exec_psubw : (simd_idx, xmmword) -> ExecutionResult
function exec_psubw(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword = (a[127..112] - b[127..112]) @
                       (a[111..96] - b[111..96]) @
                       (a[95..80] - b[95..80]) @
                       (a[79..64] - b[79..64]) @
                       (a[63..48] - b[63..48]) @
                       (a[47..32] - b[47..32]) @
                       (a[31..16] - b[31..16]) @
                       (a[15..0] - b[15..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

val exec_psubd : (simd_idx, xmmword) -> ExecutionResult
function exec_psubd(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword = (a[127..96] - b[127..96]) @
                       (a[95..64] - b[95..64]) @
                       (a[63..32] - b[63..32]) @
                       (a[31..0] - b[31..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

val exec_psubq : (simd_idx, xmmword) -> ExecutionResult
function exec_psubq(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword = (a[127..64] - b[127..64]) @ (a[63..0] - b[63..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

// PHSUBW/PHSUBD — Packed Horizontal Subtract (SSSE3)
// No flags affected.

val exec_phsubw : (simd_idx, xmmword) -> ExecutionResult
function exec_phsubw(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    (b[127..112] - b[111..96]) @ (b[95..80] - b[79..64]) @
    (b[63..48] - b[47..32]) @ (b[31..16] - b[15..0]) @
    (a[127..112] - a[111..96]) @ (a[95..80] - a[79..64]) @
    (a[63..48] - a[47..32]) @ (a[31..16] - a[15..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

val exec_phsubd : (simd_idx, xmmword) -> ExecutionResult
function exec_phsubd(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    (b[127..96] - b[95..64]) @ (b[63..32] - b[31..0]) @
    (a[127..96] - a[95..64]) @ (a[63..32] - a[31..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

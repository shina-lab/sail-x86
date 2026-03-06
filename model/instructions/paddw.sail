// PADDW/PADDD/PADDQ — Add Packed Integers (16/32/64-bit lanes)
// Wrapping addition per lane. No flags affected.

val exec_paddw : (simd_idx, xmmword) -> ExecutionResult
function exec_paddw(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword = (a[127..112] + b[127..112]) @
                       (a[111..96] + b[111..96]) @
                       (a[95..80] + b[95..80]) @
                       (a[79..64] + b[79..64]) @
                       (a[63..48] + b[63..48]) @
                       (a[47..32] + b[47..32]) @
                       (a[31..16] + b[31..16]) @
                       (a[15..0] + b[15..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

val exec_paddd : (simd_idx, xmmword) -> ExecutionResult
function exec_paddd(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword = (a[127..96] + b[127..96]) @
                       (a[95..64] + b[95..64]) @
                       (a[63..32] + b[63..32]) @
                       (a[31..0] + b[31..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

val exec_paddq : (simd_idx, xmmword) -> ExecutionResult
function exec_paddq(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword = (a[127..64] + b[127..64]) @ (a[63..0] + b[63..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

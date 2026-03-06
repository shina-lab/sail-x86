// PMULLW — Multiply Packed Signed Integers and Store Low Result (16-bit)
// PMULHW — Multiply Packed Signed Integers and Store High Result (16-bit)
// PMULHUW — Multiply Packed Unsigned Integers and Store High Result (16-bit)
// No flags affected.

val mul_lo16 : (word, word) -> word
function mul_lo16(a, b) = {
  let product : int = signed(a) * signed(b);
  to_bits_truncate(product)
}

val mul_hi16s : (word, word) -> word
function mul_hi16s(a, b) = {
  let product : dword = to_bits_truncate(signed(a) * signed(b));
  product[31..16]
}

val mul_hi16u : (word, word) -> word
function mul_hi16u(a, b) = {
  let product : dword = to_bits_truncate(unsigned(a) * unsigned(b));
  product[31..16]
}

val exec_pmullw : (simd_idx, xmmword) -> ExecutionResult
function exec_pmullw(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    mul_lo16(a[127..112], b[127..112]) @ mul_lo16(a[111..96], b[111..96]) @
    mul_lo16(a[95..80], b[95..80]) @ mul_lo16(a[79..64], b[79..64]) @
    mul_lo16(a[63..48], b[63..48]) @ mul_lo16(a[47..32], b[47..32]) @
    mul_lo16(a[31..16], b[31..16]) @ mul_lo16(a[15..0], b[15..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

val exec_pmulhw : (simd_idx, xmmword) -> ExecutionResult
function exec_pmulhw(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    mul_hi16s(a[127..112], b[127..112]) @ mul_hi16s(a[111..96], b[111..96]) @
    mul_hi16s(a[95..80], b[95..80]) @ mul_hi16s(a[79..64], b[79..64]) @
    mul_hi16s(a[63..48], b[63..48]) @ mul_hi16s(a[47..32], b[47..32]) @
    mul_hi16s(a[31..16], b[31..16]) @ mul_hi16s(a[15..0], b[15..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

val exec_pmulhuw : (simd_idx, xmmword) -> ExecutionResult
function exec_pmulhuw(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    mul_hi16u(a[127..112], b[127..112]) @ mul_hi16u(a[111..96], b[111..96]) @
    mul_hi16u(a[95..80], b[95..80]) @ mul_hi16u(a[79..64], b[79..64]) @
    mul_hi16u(a[63..48], b[63..48]) @ mul_hi16u(a[47..32], b[47..32]) @
    mul_hi16u(a[31..16], b[31..16]) @ mul_hi16u(a[15..0], b[15..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

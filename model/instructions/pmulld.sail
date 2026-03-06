// PMULLD — Multiply Packed Signed Dword Integers and Store Low Result (SSE4.1)
// No flags affected.

val mul_lo32 : (dword, dword) -> dword
function mul_lo32(a, b) = {
  let product : int = signed(a) * signed(b);
  to_bits_truncate(product)
}

val exec_pmulld : (simd_idx, xmmword) -> ExecutionResult
function exec_pmulld(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    mul_lo32(a[127..96], b[127..96]) @ mul_lo32(a[95..64], b[95..64]) @
    mul_lo32(a[63..32], b[63..32]) @ mul_lo32(a[31..0], b[31..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

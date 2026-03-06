// PMADDWD — Multiply and Add Packed Integers
// Multiplies pairs of signed 16-bit integers, then adds adjacent 32-bit products.
// No flags affected.

val exec_pmaddwd : (simd_idx, xmmword) -> ExecutionResult
function exec_pmaddwd(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let d3 : dword = to_bits_truncate(signed(a[127..112]) * signed(b[127..112]) +
                                        signed(a[111..96]) * signed(b[111..96]));
  let d2 : dword = to_bits_truncate(signed(a[95..80]) * signed(b[95..80]) +
                                        signed(a[79..64]) * signed(b[79..64]));
  let d1 : dword = to_bits_truncate(signed(a[63..48]) * signed(b[63..48]) +
                                        signed(a[47..32]) * signed(b[47..32]));
  let d0 : dword = to_bits_truncate(signed(a[31..16]) * signed(b[31..16]) +
                                        signed(a[15..0]) * signed(b[15..0]));
  let r : xmmword = d3 @ d2 @ d1 @ d0;
  write_xmm_legacy(dst, r);
  Ok(())
}

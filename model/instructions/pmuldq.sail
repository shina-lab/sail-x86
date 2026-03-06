// PMULDQ — Multiply Packed Signed Doubleword Integers (SSE4.1)
// Multiplies signed 32-bit integers from even-numbered dword lanes,
// producing 64-bit results. No flags affected.

val exec_pmuldq : (simd_idx, xmmword) -> ExecutionResult
function exec_pmuldq(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let hi : qword = to_bits_truncate(signed(a[95..64]) * signed(b[95..64]));
  let lo : qword = to_bits_truncate(signed(a[31..0]) * signed(b[31..0]));
  let r : xmmword = hi @ lo;
  write_xmm_legacy(dst, r);
  Ok(())
}

// PMULUDQ — Multiply Packed Unsigned Doubleword Integers
// Multiplies unsigned 32-bit integers from even dword lanes, producing 64-bit results.
// No flags affected.

val exec_pmuludq : (simd_idx, xmmword) -> ExecutionResult
function exec_pmuludq(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let hi : qword = to_bits_truncate(unsigned(a[95..64]) * unsigned(b[95..64]));
  let lo : qword = to_bits_truncate(unsigned(a[31..0]) * unsigned(b[31..0]));
  let r : xmmword = hi @ lo;
  write_xmm_legacy(dst, r);
  Ok(())
}

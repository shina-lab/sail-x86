// PMINSQ — Minimum of Packed Signed Qword Integers (AVX-512)
// No flags affected.

val min_s64 : (qword, qword) -> qword
function min_s64(a, b) = if signed(a) < signed(b) then a else b

val exec_pminsq : (simd_idx, xmmword) -> ExecutionResult
function exec_pminsq(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    min_s64(a[127..64], b[127..64]) @ min_s64(a[63..0], b[63..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

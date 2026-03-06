// PHADDSW — Packed Horizontal Add with Saturation (SSSE3)
// Adds adjacent signed 16-bit integers horizontally with signed saturation.
// No flags affected.

val exec_phaddsw : (simd_idx, xmmword) -> ExecutionResult
function exec_phaddsw(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    sat_add_s16(b[127..112], b[111..96]) @ sat_add_s16(b[95..80], b[79..64]) @
    sat_add_s16(b[63..48], b[47..32]) @ sat_add_s16(b[31..16], b[15..0]) @
    sat_add_s16(a[127..112], a[111..96]) @ sat_add_s16(a[95..80], a[79..64]) @
    sat_add_s16(a[63..48], a[47..32]) @ sat_add_s16(a[31..16], a[15..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

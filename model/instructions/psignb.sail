// PSIGNB/PSIGNW/PSIGND — Packed Sign (SSSE3)
// For each lane: if src < 0, negate dst; if src == 0, zero; if src > 0, keep dst.
// No flags affected.

val psign8 : (byte, byte) -> byte
function psign8(a, b) =
  if signed(b) < 0 then (0x00 - a)
  else if b == zeros() then zeros()
  else a

val psign16 : (word, word) -> word
function psign16(a, b) =
  if signed(b) < 0 then (0x0000 - a)
  else if b == zeros() then zeros()
  else a

val psign32 : (dword, dword) -> dword
function psign32(a, b) =
  if signed(b) < 0 then (0x00000000 - a)
  else if b == zeros() then zeros()
  else a

val exec_psignb : (simd_idx, xmmword) -> ExecutionResult
function exec_psignb(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    psign8(a[127..120], b[127..120]) @ psign8(a[119..112], b[119..112]) @
    psign8(a[111..104], b[111..104]) @ psign8(a[103..96], b[103..96]) @
    psign8(a[95..88], b[95..88]) @ psign8(a[87..80], b[87..80]) @
    psign8(a[79..72], b[79..72]) @ psign8(a[71..64], b[71..64]) @
    psign8(a[63..56], b[63..56]) @ psign8(a[55..48], b[55..48]) @
    psign8(a[47..40], b[47..40]) @ psign8(a[39..32], b[39..32]) @
    psign8(a[31..24], b[31..24]) @ psign8(a[23..16], b[23..16]) @
    psign8(a[15..8], b[15..8]) @ psign8(a[7..0], b[7..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

val exec_psignw : (simd_idx, xmmword) -> ExecutionResult
function exec_psignw(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    psign16(a[127..112], b[127..112]) @ psign16(a[111..96], b[111..96]) @
    psign16(a[95..80], b[95..80]) @ psign16(a[79..64], b[79..64]) @
    psign16(a[63..48], b[63..48]) @ psign16(a[47..32], b[47..32]) @
    psign16(a[31..16], b[31..16]) @ psign16(a[15..0], b[15..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

val exec_psignd : (simd_idx, xmmword) -> ExecutionResult
function exec_psignd(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    psign32(a[127..96], b[127..96]) @ psign32(a[95..64], b[95..64]) @
    psign32(a[63..32], b[63..32]) @ psign32(a[31..0], b[31..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

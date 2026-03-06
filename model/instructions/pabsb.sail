// PABSB/PABSW/PABSD — Packed Absolute Value (SSSE3)
// No flags affected.

val abs8 : byte -> byte
function abs8(x) = if x[7] == bitone then (0x00 - x) else x

val abs16 : word -> word
function abs16(x) = if x[15] == bitone then (0x0000 - x) else x

val abs32 : dword -> dword
function abs32(x) = if x[31] == bitone then (0x00000000 - x) else x

val exec_pabsb : (simd_idx, xmmword) -> ExecutionResult
function exec_pabsb(dst, src) = {
  let b : xmmword = src;
  let r : xmmword =
    abs8(b[127..120]) @ abs8(b[119..112]) @
    abs8(b[111..104]) @ abs8(b[103..96]) @
    abs8(b[95..88]) @ abs8(b[87..80]) @
    abs8(b[79..72]) @ abs8(b[71..64]) @
    abs8(b[63..56]) @ abs8(b[55..48]) @
    abs8(b[47..40]) @ abs8(b[39..32]) @
    abs8(b[31..24]) @ abs8(b[23..16]) @
    abs8(b[15..8]) @ abs8(b[7..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

val exec_pabsw : (simd_idx, xmmword) -> ExecutionResult
function exec_pabsw(dst, src) = {
  let b : xmmword = src;
  let r : xmmword =
    abs16(b[127..112]) @ abs16(b[111..96]) @
    abs16(b[95..80]) @ abs16(b[79..64]) @
    abs16(b[63..48]) @ abs16(b[47..32]) @
    abs16(b[31..16]) @ abs16(b[15..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

val exec_pabsd : (simd_idx, xmmword) -> ExecutionResult
function exec_pabsd(dst, src) = {
  let b : xmmword = src;
  let r : xmmword =
    abs32(b[127..96]) @ abs32(b[95..64]) @
    abs32(b[63..32]) @ abs32(b[31..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

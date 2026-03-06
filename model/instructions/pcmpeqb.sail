// PCMPEQB/PCMPEQW/PCMPEQD — Compare Packed Integers for Equal
// PCMPGTB/PCMPGTW/PCMPGTD — Compare Packed Signed Integers for Greater Than
// Result is all-ones if true, all-zeros if false per lane.

val cmp_eq8 : (byte, byte) -> byte
function cmp_eq8(a, b) = if a == b then ones() else zeros()

val cmp_gt8 : (byte, byte) -> byte
function cmp_gt8(a, b) = if signed(a) > signed(b) then ones() else zeros()

val exec_pcmpeqb : (simd_idx, xmmword) -> ExecutionResult
function exec_pcmpeqb(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    cmp_eq8(a[127..120], b[127..120]) @ cmp_eq8(a[119..112], b[119..112]) @
    cmp_eq8(a[111..104], b[111..104]) @ cmp_eq8(a[103..96], b[103..96]) @
    cmp_eq8(a[95..88], b[95..88]) @ cmp_eq8(a[87..80], b[87..80]) @
    cmp_eq8(a[79..72], b[79..72]) @ cmp_eq8(a[71..64], b[71..64]) @
    cmp_eq8(a[63..56], b[63..56]) @ cmp_eq8(a[55..48], b[55..48]) @
    cmp_eq8(a[47..40], b[47..40]) @ cmp_eq8(a[39..32], b[39..32]) @
    cmp_eq8(a[31..24], b[31..24]) @ cmp_eq8(a[23..16], b[23..16]) @
    cmp_eq8(a[15..8], b[15..8]) @ cmp_eq8(a[7..0], b[7..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

val cmp_eq16 : (word, word) -> word
function cmp_eq16(a, b) = if a == b then ones() else zeros()

val exec_pcmpeqw : (simd_idx, xmmword) -> ExecutionResult
function exec_pcmpeqw(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    cmp_eq16(a[127..112], b[127..112]) @ cmp_eq16(a[111..96], b[111..96]) @
    cmp_eq16(a[95..80], b[95..80]) @ cmp_eq16(a[79..64], b[79..64]) @
    cmp_eq16(a[63..48], b[63..48]) @ cmp_eq16(a[47..32], b[47..32]) @
    cmp_eq16(a[31..16], b[31..16]) @ cmp_eq16(a[15..0], b[15..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

val exec_pcmpeqd : (simd_idx, xmmword) -> ExecutionResult
function exec_pcmpeqd(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    (if a[127..96] == b[127..96] then ones() else zeros() : dword) @
    (if a[95..64] == b[95..64] then ones() else zeros() : dword) @
    (if a[63..32] == b[63..32] then ones() else zeros() : dword) @
    (if a[31..0] == b[31..0] then ones() else zeros() : dword);
  write_xmm_legacy(dst, r);
  Ok(())
}

val exec_pcmpgtb : (simd_idx, xmmword) -> ExecutionResult
function exec_pcmpgtb(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    cmp_gt8(a[127..120], b[127..120]) @ cmp_gt8(a[119..112], b[119..112]) @
    cmp_gt8(a[111..104], b[111..104]) @ cmp_gt8(a[103..96], b[103..96]) @
    cmp_gt8(a[95..88], b[95..88]) @ cmp_gt8(a[87..80], b[87..80]) @
    cmp_gt8(a[79..72], b[79..72]) @ cmp_gt8(a[71..64], b[71..64]) @
    cmp_gt8(a[63..56], b[63..56]) @ cmp_gt8(a[55..48], b[55..48]) @
    cmp_gt8(a[47..40], b[47..40]) @ cmp_gt8(a[39..32], b[39..32]) @
    cmp_gt8(a[31..24], b[31..24]) @ cmp_gt8(a[23..16], b[23..16]) @
    cmp_gt8(a[15..8], b[15..8]) @ cmp_gt8(a[7..0], b[7..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

val cmp_gt16 : (word, word) -> word
function cmp_gt16(a, b) = if signed(a) > signed(b) then ones() else zeros()

val exec_pcmpgtw : (simd_idx, xmmword) -> ExecutionResult
function exec_pcmpgtw(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    cmp_gt16(a[127..112], b[127..112]) @ cmp_gt16(a[111..96], b[111..96]) @
    cmp_gt16(a[95..80], b[95..80]) @ cmp_gt16(a[79..64], b[79..64]) @
    cmp_gt16(a[63..48], b[63..48]) @ cmp_gt16(a[47..32], b[47..32]) @
    cmp_gt16(a[31..16], b[31..16]) @ cmp_gt16(a[15..0], b[15..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

val exec_pcmpgtd : (simd_idx, xmmword) -> ExecutionResult
function exec_pcmpgtd(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    (if signed(a[127..96]) > signed(b[127..96]) then ones() else zeros() : dword) @
    (if signed(a[95..64]) > signed(b[95..64]) then ones() else zeros() : dword) @
    (if signed(a[63..32]) > signed(b[63..32]) then ones() else zeros() : dword) @
    (if signed(a[31..0]) > signed(b[31..0]) then ones() else zeros() : dword);
  write_xmm_legacy(dst, r);
  Ok(())
}

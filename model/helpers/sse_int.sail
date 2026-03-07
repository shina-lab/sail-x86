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
  Ok()
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
  Ok()
}

val exec_pabsd : (simd_idx, xmmword) -> ExecutionResult
function exec_pabsd(dst, src) = {
  let b : xmmword = src;
  let r : xmmword =
    abs32(b[127..96]) @ abs32(b[95..64]) @
    abs32(b[63..32]) @ abs32(b[31..0]);
  write_xmm_legacy(dst, r);
  Ok()
}
// PACKSSWB — Pack with Signed Saturation (words to bytes)
// PACKSSDW — Pack with Signed Saturation (dwords to words)
// No flags affected.

val sat_s16_to_s8 : word -> byte
function sat_s16_to_s8(x) = {
  let v = signed(x);
  if v > 127 then 0x7F
  else if v < -128 then 0x80
  else x[7..0]
}

val sat_s32_to_s16 : dword -> word
function sat_s32_to_s16(x) = {
  let v = signed(x);
  if v > 32767 then 0x7FFF
  else if v < -32768 then 0x8000
  else x[15..0]
}

val exec_packsswb : (simd_idx, xmmword) -> ExecutionResult
function exec_packsswb(dst, src) = {
  let d : xmmword = read_xmm(dst);
  let s : xmmword = src;
  let r : xmmword =
    sat_s16_to_s8(s[127..112]) @ sat_s16_to_s8(s[111..96]) @
    sat_s16_to_s8(s[95..80])   @ sat_s16_to_s8(s[79..64]) @
    sat_s16_to_s8(s[63..48])   @ sat_s16_to_s8(s[47..32]) @
    sat_s16_to_s8(s[31..16])   @ sat_s16_to_s8(s[15..0]) @
    sat_s16_to_s8(d[127..112]) @ sat_s16_to_s8(d[111..96]) @
    sat_s16_to_s8(d[95..80])   @ sat_s16_to_s8(d[79..64]) @
    sat_s16_to_s8(d[63..48])   @ sat_s16_to_s8(d[47..32]) @
    sat_s16_to_s8(d[31..16])   @ sat_s16_to_s8(d[15..0]);
  write_xmm_legacy(dst, r);
  Ok()
}

val exec_packssdw : (simd_idx, xmmword) -> ExecutionResult
function exec_packssdw(dst, src) = {
  let d : xmmword = read_xmm(dst);
  let s : xmmword = src;
  let r : xmmword =
    sat_s32_to_s16(s[127..96]) @ sat_s32_to_s16(s[95..64]) @
    sat_s32_to_s16(s[63..32])  @ sat_s32_to_s16(s[31..0]) @
    sat_s32_to_s16(d[127..96]) @ sat_s32_to_s16(d[95..64]) @
    sat_s32_to_s16(d[63..32])  @ sat_s32_to_s16(d[31..0]);
  write_xmm_legacy(dst, r);
  Ok()
}
// PACKUSDW — Pack Dwords to Words with Unsigned Saturation (SSE4.1)
// Packs 4 signed dwords from dst and 4 from src into 8 unsigned words.
// No flags affected.

val sat_s32_to_u16 : dword -> word
function sat_s32_to_u16(v) = {
  let sv : int = signed(v);
  if sv < 0 then 0x0000
  else if sv > 65535 then 0xFFFF
  else v[15..0]
}

val exec_packusdw : (simd_idx, xmmword) -> ExecutionResult
function exec_packusdw(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let w0 : word = sat_s32_to_u16(a[31..0]);
  let w1 : word = sat_s32_to_u16(a[63..32]);
  let w2 : word = sat_s32_to_u16(a[95..64]);
  let w3 : word = sat_s32_to_u16(a[127..96]);
  let w4 : word = sat_s32_to_u16(b[31..0]);
  let w5 : word = sat_s32_to_u16(b[63..32]);
  let w6 : word = sat_s32_to_u16(b[95..64]);
  let w7 : word = sat_s32_to_u16(b[127..96]);
  write_xmm_legacy(dst, w7 @ w6 @ w5 @ w4 @ w3 @ w2 @ w1 @ w0);
  Ok()
}
// PACKUSWB — Pack with Unsigned Saturation (words to bytes)
// No flags affected.

val sat_s16_to_u8 : word -> byte
function sat_s16_to_u8(x) = {
  let v = signed(x);
  if v > 255 then 0xFF
  else if v < 0 then 0x00
  else x[7..0]
}

val exec_packuswb : (simd_idx, xmmword) -> ExecutionResult
function exec_packuswb(dst, src) = {
  let d : xmmword = read_xmm(dst);
  let s : xmmword = src;
  let r : xmmword =
    sat_s16_to_u8(s[127..112]) @ sat_s16_to_u8(s[111..96]) @
    sat_s16_to_u8(s[95..80])   @ sat_s16_to_u8(s[79..64]) @
    sat_s16_to_u8(s[63..48])   @ sat_s16_to_u8(s[47..32]) @
    sat_s16_to_u8(s[31..16])   @ sat_s16_to_u8(s[15..0]) @
    sat_s16_to_u8(d[127..112]) @ sat_s16_to_u8(d[111..96]) @
    sat_s16_to_u8(d[95..80])   @ sat_s16_to_u8(d[79..64]) @
    sat_s16_to_u8(d[63..48])   @ sat_s16_to_u8(d[47..32]) @
    sat_s16_to_u8(d[31..16])   @ sat_s16_to_u8(d[15..0]);
  write_xmm_legacy(dst, r);
  Ok()
}
// PADDB — Add Packed Byte Integers
//
// Adds 16 pairs of 8-bit integers from two 128-bit XMM registers.
// Overflow wraps around (carry is ignored). No flags affected.

// Legacy SSE: PADDB xmm1, xmm2
val exec_paddb_xmm : (simd_idx, xmmword) -> ExecutionResult
function exec_paddb_xmm(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  var result : xmmword = zeros();
  result[7..0]     = a[7..0]     + b[7..0];
  result[15..8]    = a[15..8]    + b[15..8];
  result[23..16]   = a[23..16]   + b[23..16];
  result[31..24]   = a[31..24]   + b[31..24];
  result[39..32]   = a[39..32]   + b[39..32];
  result[47..40]   = a[47..40]   + b[47..40];
  result[55..48]   = a[55..48]   + b[55..48];
  result[63..56]   = a[63..56]   + b[63..56];
  result[71..64]   = a[71..64]   + b[71..64];
  result[79..72]   = a[79..72]   + b[79..72];
  result[87..80]   = a[87..80]   + b[87..80];
  result[95..88]   = a[95..88]   + b[95..88];
  result[103..96]  = a[103..96]  + b[103..96];
  result[111..104] = a[111..104] + b[111..104];
  result[119..112] = a[119..112] + b[119..112];
  result[127..120] = a[127..120] + b[127..120];
  write_xmm_legacy(dst, result);
  Ok()
}

// PADDSB/PADDSW — Add Packed Signed Integers with Signed Saturation
// PADDUSB/PADDUSW — Add Packed Unsigned Integers with Unsigned Saturation
// No flags affected.

val sat_add_s8 : (byte, byte) -> byte
function sat_add_s8(a, b) = {
  let sum : int = signed(a) + signed(b);
  let clamped : int = if sum < -128 then -128
                      else if sum > 127 then 127
                      else sum;
  to_bits_truncate(clamped)
}

val sat_add_s16 : (word, word) -> word
function sat_add_s16(a, b) = {
  let sum : int = signed(a) + signed(b);
  let clamped : int = if sum < -32768 then -32768
                      else if sum > 32767 then 32767
                      else sum;
  to_bits_truncate(clamped)
}

val sat_add_u8 : (byte, byte) -> byte
function sat_add_u8(a, b) = {
  let sum : int = unsigned(a) + unsigned(b);
  let clamped : int = if sum > 255 then 255 else sum;
  to_bits_truncate(clamped)
}

val sat_add_u16 : (word, word) -> word
function sat_add_u16(a, b) = {
  let sum : int = unsigned(a) + unsigned(b);
  let clamped : int = if sum > 65535 then 65535 else sum;
  to_bits_truncate(clamped)
}

val exec_paddsb : (simd_idx, xmmword) -> ExecutionResult
function exec_paddsb(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    sat_add_s8(a[127..120], b[127..120]) @ sat_add_s8(a[119..112], b[119..112]) @
    sat_add_s8(a[111..104], b[111..104]) @ sat_add_s8(a[103..96], b[103..96]) @
    sat_add_s8(a[95..88], b[95..88]) @ sat_add_s8(a[87..80], b[87..80]) @
    sat_add_s8(a[79..72], b[79..72]) @ sat_add_s8(a[71..64], b[71..64]) @
    sat_add_s8(a[63..56], b[63..56]) @ sat_add_s8(a[55..48], b[55..48]) @
    sat_add_s8(a[47..40], b[47..40]) @ sat_add_s8(a[39..32], b[39..32]) @
    sat_add_s8(a[31..24], b[31..24]) @ sat_add_s8(a[23..16], b[23..16]) @
    sat_add_s8(a[15..8], b[15..8]) @ sat_add_s8(a[7..0], b[7..0]);
  write_xmm_legacy(dst, r);
  Ok()
}

val exec_paddsw : (simd_idx, xmmword) -> ExecutionResult
function exec_paddsw(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    sat_add_s16(a[127..112], b[127..112]) @ sat_add_s16(a[111..96], b[111..96]) @
    sat_add_s16(a[95..80], b[95..80]) @ sat_add_s16(a[79..64], b[79..64]) @
    sat_add_s16(a[63..48], b[63..48]) @ sat_add_s16(a[47..32], b[47..32]) @
    sat_add_s16(a[31..16], b[31..16]) @ sat_add_s16(a[15..0], b[15..0]);
  write_xmm_legacy(dst, r);
  Ok()
}

val exec_paddusb : (simd_idx, xmmword) -> ExecutionResult
function exec_paddusb(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    sat_add_u8(a[127..120], b[127..120]) @ sat_add_u8(a[119..112], b[119..112]) @
    sat_add_u8(a[111..104], b[111..104]) @ sat_add_u8(a[103..96], b[103..96]) @
    sat_add_u8(a[95..88], b[95..88]) @ sat_add_u8(a[87..80], b[87..80]) @
    sat_add_u8(a[79..72], b[79..72]) @ sat_add_u8(a[71..64], b[71..64]) @
    sat_add_u8(a[63..56], b[63..56]) @ sat_add_u8(a[55..48], b[55..48]) @
    sat_add_u8(a[47..40], b[47..40]) @ sat_add_u8(a[39..32], b[39..32]) @
    sat_add_u8(a[31..24], b[31..24]) @ sat_add_u8(a[23..16], b[23..16]) @
    sat_add_u8(a[15..8], b[15..8]) @ sat_add_u8(a[7..0], b[7..0]);
  write_xmm_legacy(dst, r);
  Ok()
}

val exec_paddusw : (simd_idx, xmmword) -> ExecutionResult
function exec_paddusw(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    sat_add_u16(a[127..112], b[127..112]) @ sat_add_u16(a[111..96], b[111..96]) @
    sat_add_u16(a[95..80], b[95..80]) @ sat_add_u16(a[79..64], b[79..64]) @
    sat_add_u16(a[63..48], b[63..48]) @ sat_add_u16(a[47..32], b[47..32]) @
    sat_add_u16(a[31..16], b[31..16]) @ sat_add_u16(a[15..0], b[15..0]);
  write_xmm_legacy(dst, r);
  Ok()
}
// PADDW/PADDD/PADDQ — Add Packed Integers (16/32/64-bit lanes)
// Wrapping addition per lane. No flags affected.

val exec_paddw : (simd_idx, xmmword) -> ExecutionResult
function exec_paddw(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword = (a[127..112] + b[127..112]) @
                       (a[111..96] + b[111..96]) @
                       (a[95..80] + b[95..80]) @
                       (a[79..64] + b[79..64]) @
                       (a[63..48] + b[63..48]) @
                       (a[47..32] + b[47..32]) @
                       (a[31..16] + b[31..16]) @
                       (a[15..0] + b[15..0]);
  write_xmm_legacy(dst, r);
  Ok()
}

val exec_paddd : (simd_idx, xmmword) -> ExecutionResult
function exec_paddd(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword = (a[127..96] + b[127..96]) @
                       (a[95..64] + b[95..64]) @
                       (a[63..32] + b[63..32]) @
                       (a[31..0] + b[31..0]);
  write_xmm_legacy(dst, r);
  Ok()
}

val exec_paddq : (simd_idx, xmmword) -> ExecutionResult
function exec_paddq(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword = (a[127..64] + b[127..64]) @ (a[63..0] + b[63..0]);
  write_xmm_legacy(dst, r);
  Ok()
}
// PALIGNR — Packed Align Right (SSSE3)
// Concatenates dst:src, shifts right by imm8 bytes, takes low 128 bits.
// No flags affected.

val palignr_shift : (ymmword, int) -> xmmword
function palignr_shift(concat, shift_bytes) = {
  if shift_bytes <= 0 then concat[127..0]
  else if shift_bytes >= 32 then zeros()
  else (concat >> (shift_bytes * 8))[127..0]
}

val exec_palignr : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_palignr(dst, src, imm8) = {
  let d : xmmword = read_xmm(dst);
  let s : xmmword = src;
  let r : xmmword = palignr_shift(d @ s, unsigned(imm8));
  write_xmm_legacy(dst, r);
  Ok()
}
// PAND — Logical AND (packed)
//
// 128-bit SSE: xmm1 := xmm1 AND xmm2/m128 (upper bits unmodified)
// VEX.128:    xmm1 := xmm2 AND xmm3/m128 (upper bits zeroed)
// No flags affected.

// Legacy SSE: PAND xmm1, xmm2
val exec_pand_xmm : (simd_idx, xmmword) -> ExecutionResult
function exec_pand_xmm(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  write_xmm_legacy(dst, a & b);
  Ok()
}

// PANDN — Bitwise Logical AND NOT of Packed Integers
// POR — Bitwise Logical OR of Packed Integers
// No flags affected.

val exec_pandn : (simd_idx, xmmword) -> ExecutionResult
function exec_pandn(dst, src) = {
  write_xmm_legacy(dst, ~(read_xmm(dst)) & src);
  Ok()
}

val exec_por : (simd_idx, xmmword) -> ExecutionResult
function exec_por(dst, src) = {
  write_xmm_legacy(dst, read_xmm(dst) | src);
  Ok()
}
// PAVGB/PAVGW — Average Packed Integers with Rounding
// No flags affected.

val avg8 : (byte, byte) -> byte
function avg8(a, b) = {
  let sum : bits(9) = (0b0 @ a) + (0b0 @ b) + 0b000000001;
  sum[8..1]
}

val avg16 : (word, word) -> word
function avg16(a, b) = {
  let sum : bits(17) = (0b0 @ a) + (0b0 @ b) + 0b00000000000000001;
  sum[16..1]
}

val exec_pavgb : (simd_idx, xmmword) -> ExecutionResult
function exec_pavgb(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    avg8(a[127..120], b[127..120]) @ avg8(a[119..112], b[119..112]) @
    avg8(a[111..104], b[111..104]) @ avg8(a[103..96], b[103..96]) @
    avg8(a[95..88], b[95..88]) @ avg8(a[87..80], b[87..80]) @
    avg8(a[79..72], b[79..72]) @ avg8(a[71..64], b[71..64]) @
    avg8(a[63..56], b[63..56]) @ avg8(a[55..48], b[55..48]) @
    avg8(a[47..40], b[47..40]) @ avg8(a[39..32], b[39..32]) @
    avg8(a[31..24], b[31..24]) @ avg8(a[23..16], b[23..16]) @
    avg8(a[15..8], b[15..8]) @ avg8(a[7..0], b[7..0]);
  write_xmm_legacy(dst, r);
  Ok()
}

val exec_pavgw : (simd_idx, xmmword) -> ExecutionResult
function exec_pavgw(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    avg16(a[127..112], b[127..112]) @ avg16(a[111..96], b[111..96]) @
    avg16(a[95..80], b[95..80]) @ avg16(a[79..64], b[79..64]) @
    avg16(a[63..48], b[63..48]) @ avg16(a[47..32], b[47..32]) @
    avg16(a[31..16], b[31..16]) @ avg16(a[15..0], b[15..0]);
  write_xmm_legacy(dst, r);
  Ok()
}
// PBLENDW — Blend Packed Words (SSE4.1)
// imm8[0..7] each select the corresponding word lane: 0=dst, 1=src.
// No flags affected.

val exec_pblendw : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_pblendw(dst, src, imm8) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let w0 : word = if imm8[0] == bitone then b[15..0]    else a[15..0];
  let w1 : word = if imm8[1] == bitone then b[31..16]   else a[31..16];
  let w2 : word = if imm8[2] == bitone then b[47..32]   else a[47..32];
  let w3 : word = if imm8[3] == bitone then b[63..48]   else a[63..48];
  let w4 : word = if imm8[4] == bitone then b[79..64]   else a[79..64];
  let w5 : word = if imm8[5] == bitone then b[95..80]   else a[95..80];
  let w6 : word = if imm8[6] == bitone then b[111..96]  else a[111..96];
  let w7 : word = if imm8[7] == bitone then b[127..112] else a[127..112];
  write_xmm_legacy(dst, w7 @ w6 @ w5 @ w4 @ w3 @ w2 @ w1 @ w0);
  Ok()
}
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
  Ok()
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
  Ok()
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
  Ok()
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
  Ok()
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
  Ok()
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
  Ok()
}
// PCMPEQQ — Compare Packed Qword Data for Equal (SSE4.1)
//
// Compares two 64-bit (qword) lanes for equality.
// Each lane is set to all-ones if equal, all-zeros otherwise.

val exec_pcmpeqq : (simd_idx, xmmword) -> ExecutionResult
function exec_pcmpeqq(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    (if a[127..64] == b[127..64] then ones() else zeros() : qword) @
    (if a[63..0] == b[63..0] then ones() else zeros() : qword);
  write_xmm_legacy(dst, r);
  Ok()
}
// PCMPESTRI — Packed Compare Explicit Length Strings, Return Index (SSE4.2)
//
// Compares two string fragments using imm8 control. The explicit lengths
// are in EAX (for xmm1) and EDX (for xmm2/m128). The result index is
// returned in ECX. Flags CF, ZF, SF, OF, AF, PF are set based on the
// result IntRes2.
//
// This is a very complex operation; modeled as external.

val __pcmpestri : (xmmword, dword, xmmword, dword, byte) -> (dword, bit, bit, bit, bit)

val exec_pcmpestri : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_pcmpestri(dst, src, imm8) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let la : dword = read_gpr32(RAX);
  let lb : dword = read_gpr32(RDX);
  let (idx, cf_val, zf_val, sf_val, of_val) = __pcmpestri(a, la, b, lb, imm8);
  write_gpr32(RCX, idx);
  CF = cf_val;
  ZF = zf_val;
  SF = sf_val;
  OF = of_val;
  AF = bitzero;
  PF = bitzero;
  Ok()
}
// PCMPESTRM — Packed Compare Explicit Length Strings, Return Mask (SSE4.2)
//
// Compares two string fragments using imm8 control. The explicit lengths
// are in EAX (for xmm1) and EDX (for xmm2/m128). The result mask is
// returned in XMM0. Flags CF, ZF, SF, OF, AF, PF are set.
//
// This is a very complex operation; modeled as external.

val __pcmpestrm : (xmmword, dword, xmmword, dword, byte) -> (xmmword, bit, bit, bit, bit)

val exec_pcmpestrm : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_pcmpestrm(dst, src, imm8) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let la : dword = read_gpr32(RAX);
  let lb : dword = read_gpr32(RDX);
  let (mask, cf_val, zf_val, sf_val, of_val) = __pcmpestrm(a, la, b, lb, imm8);
  write_xmm_legacy(0, mask);
  CF = cf_val;
  ZF = zf_val;
  SF = sf_val;
  OF = of_val;
  AF = bitzero;
  PF = bitzero;
  Ok()
}
// PCMPGTQ — Compare Packed Signed Qword Data for Greater Than (SSE4.2)
//
// Compares two signed 64-bit (qword) lanes.
// Each lane is set to all-ones if signed(dst) > signed(src), all-zeros otherwise.

val exec_pcmpgtq : (simd_idx, xmmword) -> ExecutionResult
function exec_pcmpgtq(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    (if signed(a[127..64]) > signed(b[127..64]) then ones() else zeros() : qword) @
    (if signed(a[63..0]) > signed(b[63..0]) then ones() else zeros() : qword);
  write_xmm_legacy(dst, r);
  Ok()
}
// PCMPISTRI — Packed Compare Implicit Length Strings, Return Index (SSE4.2)
//
// Compares two null-terminated string fragments using imm8 control.
// Lengths are implicit (determined by null characters in the operands).
// The result index is returned in ECX.
// Flags CF, ZF, SF, OF, AF, PF are set.
//
// This is a very complex operation; modeled as external.

val __pcmpistri : (xmmword, xmmword, byte) -> (dword, bit, bit, bit, bit)

val exec_pcmpistri : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_pcmpistri(dst, src, imm8) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let (idx, cf_val, zf_val, sf_val, of_val) = __pcmpistri(a, b, imm8);
  write_gpr32(RCX, idx);
  CF = cf_val;
  ZF = zf_val;
  SF = sf_val;
  OF = of_val;
  AF = bitzero;
  PF = bitzero;
  Ok()
}
// PCMPISTRM — Packed Compare Implicit Length Strings, Return Mask (SSE4.2)
//
// Compares two null-terminated string fragments using imm8 control.
// Lengths are implicit (determined by null characters in the operands).
// The result mask is returned in XMM0.
// Flags CF, ZF, SF, OF, AF, PF are set.
//
// This is a very complex operation; modeled as external.

val __pcmpistrm : (xmmword, xmmword, byte) -> (xmmword, bit, bit, bit, bit)

val exec_pcmpistrm : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_pcmpistrm(dst, src, imm8) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let (mask, cf_val, zf_val, sf_val, of_val) = __pcmpistrm(a, b, imm8);
  write_xmm_legacy(0, mask);
  CF = cf_val;
  ZF = zf_val;
  SF = sf_val;
  OF = of_val;
  AF = bitzero;
  PF = bitzero;
  Ok()
}
// PEXTRB — Extract Byte (SSE4.1)
// PEXTRD — Extract Dword (SSE4.1)
// PEXTRQ — Extract Qword (SSE4.1)
// No flags affected.

val extract_byte_from_xmm : (xmmword, byte) -> byte
function extract_byte_from_xmm(s, imm8) = {
  let sel : range(0, 15) = unsigned(imm8[3..0]);
  match sel {
    0  => s[7..0],
    1  => s[15..8],
    2  => s[23..16],
    3  => s[31..24],
    4  => s[39..32],
    5  => s[47..40],
    6  => s[55..48],
    7  => s[63..56],
    8  => s[71..64],
    9  => s[79..72],
    10 => s[87..80],
    11 => s[95..88],
    12 => s[103..96],
    13 => s[111..104],
    14 => s[119..112],
    15 => s[127..120]
  }
}

val extract_dword_from_xmm : (xmmword, byte) -> dword
function extract_dword_from_xmm(s, imm8) = {
  let sel : range(0, 3) = unsigned(imm8[1..0]);
  match sel {
    0 => s[31..0],
    1 => s[63..32],
    2 => s[95..64],
    3 => s[127..96]
  }
}

val extract_qword_from_xmm : (xmmword, byte) -> qword
function extract_qword_from_xmm(s, imm8) = {
  let sel : range(0, 1) = unsigned(imm8[0..0]);
  match sel {
    0 => s[63..0],
    1 => s[127..64]
  }
}
// PEXTRW — Extract Word
// Extract a 16-bit word from XMM selected by imm8[2..0], zero-extend to 32-bit,
// write to GPR. No flags affected.

val exec_pextrw : (gpr_idx, xmmword, byte) -> ExecutionResult
function exec_pextrw(dst, s, imm8) = {
  let sel : range(0, 7) = unsigned(imm8[2..0]);
  let word : word = match sel {
    0 => s[15..0],
    1 => s[31..16],
    2 => s[47..32],
    3 => s[63..48],
    4 => s[79..64],
    5 => s[95..80],
    6 => s[111..96],
    7 => s[127..112]
  };
  write_gpr32(dst, zero_extend(word));
  Ok()
}
// PINSRB — Insert Byte (SSE4.1)
// PINSRD — Insert Dword (SSE4.1)
// PINSRQ — Insert Qword (SSE4.1)
// No flags affected.

val insert_byte : (xmmword, byte, range(0, 15)) -> xmmword
function insert_byte(v, b, sel) = {
  match sel {
    0  => v[127..8] @ b,
    1  => v[127..16] @ b @ v[7..0],
    2  => v[127..24] @ b @ v[15..0],
    3  => v[127..32] @ b @ v[23..0],
    4  => v[127..40] @ b @ v[31..0],
    5  => v[127..48] @ b @ v[39..0],
    6  => v[127..56] @ b @ v[47..0],
    7  => v[127..64] @ b @ v[55..0],
    8  => v[127..72] @ b @ v[63..0],
    9  => v[127..80] @ b @ v[71..0],
    10 => v[127..88] @ b @ v[79..0],
    11 => v[127..96] @ b @ v[87..0],
    12 => v[127..104] @ b @ v[95..0],
    13 => v[127..112] @ b @ v[103..0],
    14 => v[127..120] @ b @ v[111..0],
    15 => b @ v[119..0]
  }
}

val exec_pinsrb : (simd_idx, byte, byte) -> ExecutionResult
function exec_pinsrb(dst, val8, imm8) = {
  let v : xmmword = read_xmm(dst);
  let sel : range(0, 15) = unsigned(imm8[3..0]);
  let r : xmmword = insert_byte(v, val8, sel);
  write_xmm_legacy(dst, r);
  Ok()
}

val insert_dword : (xmmword, dword, range(0, 3)) -> xmmword
function insert_dword(v, d, sel) = {
  match sel {
    0 => v[127..32] @ d,
    1 => v[127..64] @ d @ v[31..0],
    2 => v[127..96] @ d @ v[63..0],
    3 => d @ v[95..0]
  }
}

val exec_pinsrd : (simd_idx, dword, byte) -> ExecutionResult
function exec_pinsrd(dst, val32, imm8) = {
  let v : xmmword = read_xmm(dst);
  let sel : range(0, 3) = unsigned(imm8[1..0]);
  let r : xmmword = insert_dword(v, val32, sel);
  write_xmm_legacy(dst, r);
  Ok()
}

val exec_pinsrq : (simd_idx, qword, byte) -> ExecutionResult
function exec_pinsrq(dst, val64, imm8) = {
  let v : xmmword = read_xmm(dst);
  let sel : range(0, 1) = unsigned(imm8[0..0]);
  let r : xmmword = match sel {
    0 => v[127..64] @ val64,
    1 => val64 @ v[63..0]
  };
  write_xmm_legacy(dst, r);
  Ok()
}
// PINSRW — Insert Word
// Insert a 16-bit value into XMM at position selected by imm8[2..0].
// Other words unchanged. No flags affected.

val insert_word : (xmmword, word, range(0, 7)) -> xmmword
function insert_word(v, w, sel) = {
  match sel {
    0 => v[127..16] @ w,
    1 => v[127..32] @ w @ v[15..0],
    2 => v[127..48] @ w @ v[31..0],
    3 => v[127..64] @ w @ v[47..0],
    4 => v[127..80] @ w @ v[63..0],
    5 => v[127..96] @ w @ v[79..0],
    6 => v[127..112] @ w @ v[95..0],
    7 => w @ v[111..0]
  }
}

val exec_pinsrw : (simd_idx, word, byte) -> ExecutionResult
function exec_pinsrw(dst, val16, imm8) = {
  let v : xmmword = read_xmm(dst);
  let sel : range(0, 7) = unsigned(imm8[2..0]);
  let r : xmmword = insert_word(v, val16, sel);
  write_xmm_legacy(dst, r);
  Ok()
}
// PMADDUBSW — Multiply and Add Packed Signed and Unsigned Bytes (SSSE3)
// Multiplies unsigned bytes from src1 with signed bytes from src2,
// then adds adjacent pairs with signed saturation to produce 16-bit results.
// No flags affected.

val pmaddubsw_pair : (byte, byte, byte, byte) -> word
function pmaddubsw_pair(a_even, b_even, a_odd, b_odd) = {
  let p1 : int = unsigned(a_even) * signed(b_even);
  let p2 : int = unsigned(a_odd) * signed(b_odd);
  let sum : int = p1 + p2;
  if sum > 32767 then 0x7FFF
  else if sum < -32768 then 0x8000
  else to_bits_truncate(sum) : word
}

val exec_pmaddubsw : (simd_idx, xmmword) -> ExecutionResult
function exec_pmaddubsw(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    pmaddubsw_pair(a[127..120], b[127..120], a[119..112], b[119..112]) @
    pmaddubsw_pair(a[111..104], b[111..104], a[103..96], b[103..96]) @
    pmaddubsw_pair(a[95..88], b[95..88], a[87..80], b[87..80]) @
    pmaddubsw_pair(a[79..72], b[79..72], a[71..64], b[71..64]) @
    pmaddubsw_pair(a[63..56], b[63..56], a[55..48], b[55..48]) @
    pmaddubsw_pair(a[47..40], b[47..40], a[39..32], b[39..32]) @
    pmaddubsw_pair(a[31..24], b[31..24], a[23..16], b[23..16]) @
    pmaddubsw_pair(a[15..8], b[15..8], a[7..0], b[7..0]);
  write_xmm_legacy(dst, r);
  Ok()
}
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
  Ok()
}
// PMAXSB/PMAXSW/PMAXSD — Packed Maximum Signed Integers
// PMAXSB and PMAXSD are SSE4.1; PMAXSW is SSE2.
// No flags affected.

val max_s8 : (byte, byte) -> byte
function max_s8(a, b) = if signed(a) > signed(b) then a else b

val max_s16 : (word, word) -> word
function max_s16(a, b) = if signed(a) > signed(b) then a else b

val max_s32 : (dword, dword) -> dword
function max_s32(a, b) = if signed(a) > signed(b) then a else b

val exec_pmaxsb : (simd_idx, xmmword) -> ExecutionResult
function exec_pmaxsb(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    max_s8(a[127..120], b[127..120]) @ max_s8(a[119..112], b[119..112]) @
    max_s8(a[111..104], b[111..104]) @ max_s8(a[103..96], b[103..96]) @
    max_s8(a[95..88], b[95..88]) @ max_s8(a[87..80], b[87..80]) @
    max_s8(a[79..72], b[79..72]) @ max_s8(a[71..64], b[71..64]) @
    max_s8(a[63..56], b[63..56]) @ max_s8(a[55..48], b[55..48]) @
    max_s8(a[47..40], b[47..40]) @ max_s8(a[39..32], b[39..32]) @
    max_s8(a[31..24], b[31..24]) @ max_s8(a[23..16], b[23..16]) @
    max_s8(a[15..8], b[15..8]) @ max_s8(a[7..0], b[7..0]);
  write_xmm_legacy(dst, r);
  Ok()
}

val exec_pmaxsw : (simd_idx, xmmword) -> ExecutionResult
function exec_pmaxsw(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    max_s16(a[127..112], b[127..112]) @ max_s16(a[111..96], b[111..96]) @
    max_s16(a[95..80], b[95..80]) @ max_s16(a[79..64], b[79..64]) @
    max_s16(a[63..48], b[63..48]) @ max_s16(a[47..32], b[47..32]) @
    max_s16(a[31..16], b[31..16]) @ max_s16(a[15..0], b[15..0]);
  write_xmm_legacy(dst, r);
  Ok()
}

val exec_pmaxsd : (simd_idx, xmmword) -> ExecutionResult
function exec_pmaxsd(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    max_s32(a[127..96], b[127..96]) @ max_s32(a[95..64], b[95..64]) @
    max_s32(a[63..32], b[63..32]) @ max_s32(a[31..0], b[31..0]);
  write_xmm_legacy(dst, r);
  Ok()
}
// PMAXUB/PMAXUW/PMAXUD — Packed Maximum Unsigned Integers
// PMAXUB is SSE2; PMAXUW and PMAXUD are SSE4.1.
// No flags affected.

val max_u8 : (byte, byte) -> byte
function max_u8(a, b) = if unsigned(a) > unsigned(b) then a else b

val max_u16 : (word, word) -> word
function max_u16(a, b) = if unsigned(a) > unsigned(b) then a else b

val max_u32 : (dword, dword) -> dword
function max_u32(a, b) = if unsigned(a) > unsigned(b) then a else b

val exec_pmaxub : (simd_idx, xmmword) -> ExecutionResult
function exec_pmaxub(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    max_u8(a[127..120], b[127..120]) @ max_u8(a[119..112], b[119..112]) @
    max_u8(a[111..104], b[111..104]) @ max_u8(a[103..96], b[103..96]) @
    max_u8(a[95..88], b[95..88]) @ max_u8(a[87..80], b[87..80]) @
    max_u8(a[79..72], b[79..72]) @ max_u8(a[71..64], b[71..64]) @
    max_u8(a[63..56], b[63..56]) @ max_u8(a[55..48], b[55..48]) @
    max_u8(a[47..40], b[47..40]) @ max_u8(a[39..32], b[39..32]) @
    max_u8(a[31..24], b[31..24]) @ max_u8(a[23..16], b[23..16]) @
    max_u8(a[15..8], b[15..8]) @ max_u8(a[7..0], b[7..0]);
  write_xmm_legacy(dst, r);
  Ok()
}

val exec_pmaxuw : (simd_idx, xmmword) -> ExecutionResult
function exec_pmaxuw(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    max_u16(a[127..112], b[127..112]) @ max_u16(a[111..96], b[111..96]) @
    max_u16(a[95..80], b[95..80]) @ max_u16(a[79..64], b[79..64]) @
    max_u16(a[63..48], b[63..48]) @ max_u16(a[47..32], b[47..32]) @
    max_u16(a[31..16], b[31..16]) @ max_u16(a[15..0], b[15..0]);
  write_xmm_legacy(dst, r);
  Ok()
}

val exec_pmaxud : (simd_idx, xmmword) -> ExecutionResult
function exec_pmaxud(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    max_u32(a[127..96], b[127..96]) @ max_u32(a[95..64], b[95..64]) @
    max_u32(a[63..32], b[63..32]) @ max_u32(a[31..0], b[31..0]);
  write_xmm_legacy(dst, r);
  Ok()
}
// PMINSB/PMINSW/PMINSD — Packed Minimum Signed Integers
// PMINSB and PMINSD are SSE4.1; PMINSW is SSE2.
// No flags affected.

val min_s8 : (byte, byte) -> byte
function min_s8(a, b) = if signed(a) < signed(b) then a else b

val min_s16 : (word, word) -> word
function min_s16(a, b) = if signed(a) < signed(b) then a else b

val min_s32 : (dword, dword) -> dword
function min_s32(a, b) = if signed(a) < signed(b) then a else b

val exec_pminsb : (simd_idx, xmmword) -> ExecutionResult
function exec_pminsb(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    min_s8(a[127..120], b[127..120]) @ min_s8(a[119..112], b[119..112]) @
    min_s8(a[111..104], b[111..104]) @ min_s8(a[103..96], b[103..96]) @
    min_s8(a[95..88], b[95..88]) @ min_s8(a[87..80], b[87..80]) @
    min_s8(a[79..72], b[79..72]) @ min_s8(a[71..64], b[71..64]) @
    min_s8(a[63..56], b[63..56]) @ min_s8(a[55..48], b[55..48]) @
    min_s8(a[47..40], b[47..40]) @ min_s8(a[39..32], b[39..32]) @
    min_s8(a[31..24], b[31..24]) @ min_s8(a[23..16], b[23..16]) @
    min_s8(a[15..8], b[15..8]) @ min_s8(a[7..0], b[7..0]);
  write_xmm_legacy(dst, r);
  Ok()
}

val exec_pminsw : (simd_idx, xmmword) -> ExecutionResult
function exec_pminsw(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    min_s16(a[127..112], b[127..112]) @ min_s16(a[111..96], b[111..96]) @
    min_s16(a[95..80], b[95..80]) @ min_s16(a[79..64], b[79..64]) @
    min_s16(a[63..48], b[63..48]) @ min_s16(a[47..32], b[47..32]) @
    min_s16(a[31..16], b[31..16]) @ min_s16(a[15..0], b[15..0]);
  write_xmm_legacy(dst, r);
  Ok()
}

val exec_pminsd : (simd_idx, xmmword) -> ExecutionResult
function exec_pminsd(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    min_s32(a[127..96], b[127..96]) @ min_s32(a[95..64], b[95..64]) @
    min_s32(a[63..32], b[63..32]) @ min_s32(a[31..0], b[31..0]);
  write_xmm_legacy(dst, r);
  Ok()
}
// PMINUB/PMINUW/PMINUD — Packed Minimum Unsigned Integers
// PMINUB is SSE2; PMINUW and PMINUD are SSE4.1.
// No flags affected.

val min_u8 : (byte, byte) -> byte
function min_u8(a, b) = if unsigned(a) < unsigned(b) then a else b

val min_u16 : (word, word) -> word
function min_u16(a, b) = if unsigned(a) < unsigned(b) then a else b

val min_u32 : (dword, dword) -> dword
function min_u32(a, b) = if unsigned(a) < unsigned(b) then a else b

val exec_pminub : (simd_idx, xmmword) -> ExecutionResult
function exec_pminub(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    min_u8(a[127..120], b[127..120]) @ min_u8(a[119..112], b[119..112]) @
    min_u8(a[111..104], b[111..104]) @ min_u8(a[103..96], b[103..96]) @
    min_u8(a[95..88], b[95..88]) @ min_u8(a[87..80], b[87..80]) @
    min_u8(a[79..72], b[79..72]) @ min_u8(a[71..64], b[71..64]) @
    min_u8(a[63..56], b[63..56]) @ min_u8(a[55..48], b[55..48]) @
    min_u8(a[47..40], b[47..40]) @ min_u8(a[39..32], b[39..32]) @
    min_u8(a[31..24], b[31..24]) @ min_u8(a[23..16], b[23..16]) @
    min_u8(a[15..8], b[15..8]) @ min_u8(a[7..0], b[7..0]);
  write_xmm_legacy(dst, r);
  Ok()
}

val exec_pminuw : (simd_idx, xmmword) -> ExecutionResult
function exec_pminuw(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    min_u16(a[127..112], b[127..112]) @ min_u16(a[111..96], b[111..96]) @
    min_u16(a[95..80], b[95..80]) @ min_u16(a[79..64], b[79..64]) @
    min_u16(a[63..48], b[63..48]) @ min_u16(a[47..32], b[47..32]) @
    min_u16(a[31..16], b[31..16]) @ min_u16(a[15..0], b[15..0]);
  write_xmm_legacy(dst, r);
  Ok()
}

val exec_pminud : (simd_idx, xmmword) -> ExecutionResult
function exec_pminud(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    min_u32(a[127..96], b[127..96]) @ min_u32(a[95..64], b[95..64]) @
    min_u32(a[63..32], b[63..32]) @ min_u32(a[31..0], b[31..0]);
  write_xmm_legacy(dst, r);
  Ok()
}
// PMOVMSKB — Move Byte Mask
// Creates a 16-bit mask from the MSB of each byte in XMM. No flags affected.

val exec_pmovmskb : (gpr_idx, xmmword) -> ExecutionResult
function exec_pmovmskb(dst, s) = {
  let mask : word = s[127] @ s[119] @ s[111] @ s[103] @
                         s[95]  @ s[87]  @ s[79]  @ s[71] @
                         s[63]  @ s[55]  @ s[47]  @ s[39] @
                         s[31]  @ s[23]  @ s[15]  @ s[7];
  write_gpr32(dst, zero_extend(mask));
  Ok()
}
// PMOVSX — Packed Move with Sign Extend (SSE4.1)
// Sign-extends packed integers from smaller to larger element sizes.
// No flags affected.

val sx8_16 : byte -> word
function sx8_16(v) = sign_extend(v)

val sx8_32 : byte -> dword
function sx8_32(v) = sign_extend(v)

val sx8_64 : byte -> qword
function sx8_64(v) = sign_extend(v)

val sx16_32 : word -> dword
function sx16_32(v) = sign_extend(v)

val sx16_64 : word -> qword
function sx16_64(v) = sign_extend(v)

val sx32_64 : dword -> qword
function sx32_64(v) = sign_extend(v)

// PMOVSXBW: 8 x i8 -> 8 x i16
val exec_pmovsxbw : (simd_idx, xmmword) -> ExecutionResult
function exec_pmovsxbw(dst, src) = {
  let s : xmmword = src;
  let r : xmmword =
    sx8_16(s[63..56]) @ sx8_16(s[55..48]) @
    sx8_16(s[47..40]) @ sx8_16(s[39..32]) @
    sx8_16(s[31..24]) @ sx8_16(s[23..16]) @
    sx8_16(s[15..8])  @ sx8_16(s[7..0]);
  write_xmm_legacy(dst, r);
  Ok()
}

// PMOVSXBD: 4 x i8 -> 4 x i32
val exec_pmovsxbd : (simd_idx, xmmword) -> ExecutionResult
function exec_pmovsxbd(dst, src) = {
  let s : xmmword = src;
  let r : xmmword =
    sx8_32(s[31..24]) @ sx8_32(s[23..16]) @
    sx8_32(s[15..8])  @ sx8_32(s[7..0]);
  write_xmm_legacy(dst, r);
  Ok()
}

// PMOVSXBQ: 2 x i8 -> 2 x i64
val exec_pmovsxbq : (simd_idx, xmmword) -> ExecutionResult
function exec_pmovsxbq(dst, src) = {
  let s : xmmword = src;
  let r : xmmword =
    sx8_64(s[15..8]) @ sx8_64(s[7..0]);
  write_xmm_legacy(dst, r);
  Ok()
}

// PMOVSXWD: 4 x i16 -> 4 x i32
val exec_pmovsxwd : (simd_idx, xmmword) -> ExecutionResult
function exec_pmovsxwd(dst, src) = {
  let s : xmmword = src;
  let r : xmmword =
    sx16_32(s[63..48]) @ sx16_32(s[47..32]) @
    sx16_32(s[31..16]) @ sx16_32(s[15..0]);
  write_xmm_legacy(dst, r);
  Ok()
}

// PMOVSXWQ: 2 x i16 -> 2 x i64
val exec_pmovsxwq : (simd_idx, xmmword) -> ExecutionResult
function exec_pmovsxwq(dst, src) = {
  let s : xmmword = src;
  let r : xmmword =
    sx16_64(s[31..16]) @ sx16_64(s[15..0]);
  write_xmm_legacy(dst, r);
  Ok()
}

// PMOVSXDQ: 2 x i32 -> 2 x i64
val exec_pmovsxdq : (simd_idx, xmmword) -> ExecutionResult
function exec_pmovsxdq(dst, src) = {
  let s : xmmword = src;
  let r : xmmword =
    sx32_64(s[63..32]) @ sx32_64(s[31..0]);
  write_xmm_legacy(dst, r);
  Ok()
}
// PMOVZX — Packed Move with Zero Extend (SSE4.1)
// Zero-extends packed integers from smaller to larger element sizes.
// No flags affected.

val zx8_16 : byte -> word
function zx8_16(v) = zero_extend(v)

val zx8_32 : byte -> dword
function zx8_32(v) = zero_extend(v)

val zx8_64 : byte -> qword
function zx8_64(v) = zero_extend(v)

val zx16_32 : word -> dword
function zx16_32(v) = zero_extend(v)

val zx16_64 : word -> qword
function zx16_64(v) = zero_extend(v)

val zx32_64 : dword -> qword
function zx32_64(v) = zero_extend(v)

// PMOVZXBW: 8 x u8 -> 8 x u16
val exec_pmovzxbw : (simd_idx, xmmword) -> ExecutionResult
function exec_pmovzxbw(dst, src) = {
  let s : xmmword = src;
  let r : xmmword =
    zx8_16(s[63..56]) @ zx8_16(s[55..48]) @
    zx8_16(s[47..40]) @ zx8_16(s[39..32]) @
    zx8_16(s[31..24]) @ zx8_16(s[23..16]) @
    zx8_16(s[15..8])  @ zx8_16(s[7..0]);
  write_xmm_legacy(dst, r);
  Ok()
}

// PMOVZXBD: 4 x u8 -> 4 x u32
val exec_pmovzxbd : (simd_idx, xmmword) -> ExecutionResult
function exec_pmovzxbd(dst, src) = {
  let s : xmmword = src;
  let r : xmmword =
    zx8_32(s[31..24]) @ zx8_32(s[23..16]) @
    zx8_32(s[15..8])  @ zx8_32(s[7..0]);
  write_xmm_legacy(dst, r);
  Ok()
}

// PMOVZXBQ: 2 x u8 -> 2 x u64
val exec_pmovzxbq : (simd_idx, xmmword) -> ExecutionResult
function exec_pmovzxbq(dst, src) = {
  let s : xmmword = src;
  let r : xmmword =
    zx8_64(s[15..8]) @ zx8_64(s[7..0]);
  write_xmm_legacy(dst, r);
  Ok()
}

// PMOVZXWD: 4 x u16 -> 4 x u32
val exec_pmovzxwd : (simd_idx, xmmword) -> ExecutionResult
function exec_pmovzxwd(dst, src) = {
  let s : xmmword = src;
  let r : xmmword =
    zx16_32(s[63..48]) @ zx16_32(s[47..32]) @
    zx16_32(s[31..16]) @ zx16_32(s[15..0]);
  write_xmm_legacy(dst, r);
  Ok()
}

// PMOVZXWQ: 2 x u16 -> 2 x u64
val exec_pmovzxwq : (simd_idx, xmmword) -> ExecutionResult
function exec_pmovzxwq(dst, src) = {
  let s : xmmword = src;
  let r : xmmword =
    zx16_64(s[31..16]) @ zx16_64(s[15..0]);
  write_xmm_legacy(dst, r);
  Ok()
}

// PMOVZXDQ: 2 x u32 -> 2 x u64
val exec_pmovzxdq : (simd_idx, xmmword) -> ExecutionResult
function exec_pmovzxdq(dst, src) = {
  let s : xmmword = src;
  let r : xmmword =
    zx32_64(s[63..32]) @ zx32_64(s[31..0]);
  write_xmm_legacy(dst, r);
  Ok()
}
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
  Ok()
}
// PMULHRSW — Packed Multiply High with Round and Scale (SSSE3)
// No flags affected.

val mulhrsw : (word, word) -> word
function mulhrsw(a, b) = {
  let product : dword = to_bits_truncate(signed(a) * signed(b));
  let rounded : dword = product + 0x00004000;
  // Take bits [30..15] which is equivalent to arithmetic right shift by 15
  rounded[30..15]
}

val exec_pmulhrsw : (simd_idx, xmmword) -> ExecutionResult
function exec_pmulhrsw(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    mulhrsw(a[127..112], b[127..112]) @ mulhrsw(a[111..96], b[111..96]) @
    mulhrsw(a[95..80], b[95..80]) @ mulhrsw(a[79..64], b[79..64]) @
    mulhrsw(a[63..48], b[63..48]) @ mulhrsw(a[47..32], b[47..32]) @
    mulhrsw(a[31..16], b[31..16]) @ mulhrsw(a[15..0], b[15..0]);
  write_xmm_legacy(dst, r);
  Ok()
}
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
  Ok()
}
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
  Ok()
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
  Ok()
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
  Ok()
}
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
  Ok()
}
// PSADBW — Compute Sum of Absolute Differences
// Computes absolute differences of unsigned byte pairs, then sums each 8-byte group.
// Result is zero-extended to 64 bits per qword lane. No flags affected.

val abs_diff8 : (byte, byte) -> int
function abs_diff8(a, b) = {
  let diff : int = unsigned(a) - unsigned(b);
  if diff < 0 then negate(diff) else diff
}

val exec_psadbw : (simd_idx, xmmword) -> ExecutionResult
function exec_psadbw(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let sum_hi : int = abs_diff8(a[127..120], b[127..120]) +
                     abs_diff8(a[119..112], b[119..112]) +
                     abs_diff8(a[111..104], b[111..104]) +
                     abs_diff8(a[103..96], b[103..96]) +
                     abs_diff8(a[95..88], b[95..88]) +
                     abs_diff8(a[87..80], b[87..80]) +
                     abs_diff8(a[79..72], b[79..72]) +
                     abs_diff8(a[71..64], b[71..64]);
  let sum_lo : int = abs_diff8(a[63..56], b[63..56]) +
                     abs_diff8(a[55..48], b[55..48]) +
                     abs_diff8(a[47..40], b[47..40]) +
                     abs_diff8(a[39..32], b[39..32]) +
                     abs_diff8(a[31..24], b[31..24]) +
                     abs_diff8(a[23..16], b[23..16]) +
                     abs_diff8(a[15..8], b[15..8]) +
                     abs_diff8(a[7..0], b[7..0]);
  let hi : qword = to_bits_truncate(sum_hi);
  let lo : qword = to_bits_truncate(sum_lo);
  let r : xmmword = hi @ lo;
  write_xmm_legacy(dst, r);
  Ok()
}
// PSHUFB — Packed Shuffle Bytes (SSSE3)
// Each byte in result is selected from dst by the low 4 bits of the corresponding
// byte in src. If the high bit of the selector byte is set, the result byte is zero.
// No flags affected.

val pshufb_byte : (xmmword, byte) -> byte
function pshufb_byte(data, mask) = {
  if mask[7] == bitone then 0x00
  else {
    let idx : range(0, 15) = unsigned(mask[3..0]);
    match idx {
      0  => data[7..0],
      1  => data[15..8],
      2  => data[23..16],
      3  => data[31..24],
      4  => data[39..32],
      5  => data[47..40],
      6  => data[55..48],
      7  => data[63..56],
      8  => data[71..64],
      9  => data[79..72],
      10 => data[87..80],
      11 => data[95..88],
      12 => data[103..96],
      13 => data[111..104],
      14 => data[119..112],
      15 => data[127..120]
    }
  }
}

val exec_pshufb : (simd_idx, xmmword) -> ExecutionResult
function exec_pshufb(dst, src) = {
  let d : xmmword = read_xmm(dst);
  let s : xmmword = src;
  let r : xmmword =
    pshufb_byte(d, s[127..120]) @ pshufb_byte(d, s[119..112]) @
    pshufb_byte(d, s[111..104]) @ pshufb_byte(d, s[103..96]) @
    pshufb_byte(d, s[95..88])   @ pshufb_byte(d, s[87..80]) @
    pshufb_byte(d, s[79..72])   @ pshufb_byte(d, s[71..64]) @
    pshufb_byte(d, s[63..56])   @ pshufb_byte(d, s[55..48]) @
    pshufb_byte(d, s[47..40])   @ pshufb_byte(d, s[39..32]) @
    pshufb_byte(d, s[31..24])   @ pshufb_byte(d, s[23..16]) @
    pshufb_byte(d, s[15..8])    @ pshufb_byte(d, s[7..0]);
  write_xmm_legacy(dst, r);
  Ok()
}
// PSHUFD — Shuffle Packed Doublewords
// Selects dwords from src based on imm8 control. No flags affected.

val exec_pshufd : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_pshufd(dst, src, imm8) = {
  let s : xmmword = src;
  let sel0 : range(0, 3) = unsigned(imm8[1..0]);
  let sel1 : range(0, 3) = unsigned(imm8[3..2]);
  let sel2 : range(0, 3) = unsigned(imm8[5..4]);
  let sel3 : range(0, 3) = unsigned(imm8[7..6]);
  let d0 : dword = s[(sel0 * 32 + 31) .. (sel0 * 32)];
  let d1 : dword = s[(sel1 * 32 + 31) .. (sel1 * 32)];
  let d2 : dword = s[(sel2 * 32 + 31) .. (sel2 * 32)];
  let d3 : dword = s[(sel3 * 32 + 31) .. (sel3 * 32)];
  write_xmm_legacy(dst, d3 @ d2 @ d1 @ d0);
  Ok()
}
// PSHUFHW — Shuffle Packed High Words
// Low qword copied unchanged from src. High qword: 4 words selected
// from src's high qword by imm8. No flags affected.

val select_high_word : (xmmword, bits(2)) -> word
function select_high_word(v, sel) = {
  let idx : range(0, 3) = unsigned(sel);
  v[(idx * 16 + 79) .. (idx * 16 + 64)]
}

val exec_pshufhw : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_pshufhw(dst, src, imm8) = {
  let s : xmmword = src;
  let low : qword = s[63..0];
  let w0 : word = select_high_word(s, imm8[1..0]);
  let w1 : word = select_high_word(s, imm8[3..2]);
  let w2 : word = select_high_word(s, imm8[5..4]);
  let w3 : word = select_high_word(s, imm8[7..6]);
  write_xmm_legacy(dst, w3 @ w2 @ w1 @ w0 @ low);
  Ok()
}
// PSHUFLW — Shuffle Packed Low Words
// High qword copied unchanged from src. Low qword: 4 words selected
// from src's low qword by imm8. No flags affected.

val select_low_word : (xmmword, bits(2)) -> word
function select_low_word(v, sel) = {
  let idx : range(0, 3) = unsigned(sel);
  v[(idx * 16 + 15) .. (idx * 16)]
}

val exec_pshuflw : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_pshuflw(dst, src, imm8) = {
  let s : xmmword = src;
  let high : qword = s[127..64];
  let w0 : word = select_low_word(s, imm8[1..0]);
  let w1 : word = select_low_word(s, imm8[3..2]);
  let w2 : word = select_low_word(s, imm8[5..4]);
  let w3 : word = select_low_word(s, imm8[7..6]);
  write_xmm_legacy(dst, high @ w3 @ w2 @ w1 @ w0);
  Ok()
}
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
  Ok()
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
  Ok()
}

val exec_psignd : (simd_idx, xmmword) -> ExecutionResult
function exec_psignd(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    psign32(a[127..96], b[127..96]) @ psign32(a[95..64], b[95..64]) @
    psign32(a[63..32], b[63..32]) @ psign32(a[31..0], b[31..0]);
  write_xmm_legacy(dst, r);
  Ok()
}
// PSLLDQ — Shift Double Quadword Left Logical (byte granularity)
// PSRLDQ — Shift Double Quadword Right Logical (byte granularity)
// Shifts entire 128-bit value left/right by imm8 bytes, filling with zeros.
// No flags affected.

val sll128 : (xmmword, int) -> xmmword
function sll128(v, count) = if count > 127 | count < 0 then zeros() else v << count

val srl128 : (xmmword, int) -> xmmword
function srl128(v, count) = if count > 127 | count < 0 then zeros() else v >> count

val exec_pslldq : (simd_idx, byte) -> ExecutionResult
function exec_pslldq(dst, imm8) = {
  let c : int = unsigned(imm8);
  let byte_count : int = if c > 15 then 16 else c;
  let a : xmmword = read_xmm(dst);
  let r : xmmword = sll128(a, byte_count * 8);
  write_xmm_legacy(dst, r);
  Ok()
}

val exec_psrldq : (simd_idx, byte) -> ExecutionResult
function exec_psrldq(dst, imm8) = {
  let c : int = unsigned(imm8);
  let byte_count : int = if c > 15 then 16 else c;
  let a : xmmword = read_xmm(dst);
  let r : xmmword = srl128(a, byte_count * 8);
  write_xmm_legacy(dst, r);
  Ok()
}
// PSLLW/PSLLD/PSLLQ — Shift Packed Data Left Logical
// PSRLW/PSRLD/PSRLQ — Shift Packed Data Right Logical
// PSRAW/PSRAD — Shift Packed Data Right Arithmetic
// Shift count from imm8 or XMM. No flags affected.

val sll16 : (word, int) -> word
function sll16(v, count) = if count > 15 | count < 0 then zeros() else v << count

val sll32 : (dword, int) -> dword
function sll32(v, count) = if count > 31 | count < 0 then zeros() else v << count

val sll64 : (qword, int) -> qword
function sll64(v, count) = if count > 63 | count < 0 then zeros() else v << count

val srl16 : (word, int) -> word
function srl16(v, count) = if count > 15 | count < 0 then zeros() else v >> count

val srl32 : (dword, int) -> dword
function srl32(v, count) = if count > 31 | count < 0 then zeros() else v >> count

val srl64 : (qword, int) -> qword
function srl64(v, count) = if count > 63 | count < 0 then zeros() else v >> count

val sra16 : (word, int) -> word
function sra16(v, count) = {
  if count <= 0 then v
  else if count > 15 then shift_right_arith(v, 15)
  else shift_right_arith(v, count)
}

val sra32 : (dword, int) -> dword
function sra32(v, count) = {
  if count <= 0 then v
  else if count > 31 then shift_right_arith(v, 31)
  else shift_right_arith(v, count)
}

val exec_psllw_imm : (simd_idx, byte) -> ExecutionResult
function exec_psllw_imm(dst, imm8) = {
  let c : int = unsigned(imm8);
  let a : xmmword = read_xmm(dst);
  let r : xmmword =
    sll16(a[127..112], c) @ sll16(a[111..96], c) @
    sll16(a[95..80], c) @ sll16(a[79..64], c) @
    sll16(a[63..48], c) @ sll16(a[47..32], c) @
    sll16(a[31..16], c) @ sll16(a[15..0], c);
  write_xmm_legacy(dst, r);
  Ok()
}

val exec_pslld_imm : (simd_idx, byte) -> ExecutionResult
function exec_pslld_imm(dst, imm8) = {
  let c : int = unsigned(imm8);
  let a : xmmword = read_xmm(dst);
  let r : xmmword =
    sll32(a[127..96], c) @ sll32(a[95..64], c) @
    sll32(a[63..32], c) @ sll32(a[31..0], c);
  write_xmm_legacy(dst, r);
  Ok()
}

val exec_psllq_imm : (simd_idx, byte) -> ExecutionResult
function exec_psllq_imm(dst, imm8) = {
  let c : int = unsigned(imm8);
  let a : xmmword = read_xmm(dst);
  let r : xmmword = sll64(a[127..64], c) @ sll64(a[63..0], c);
  write_xmm_legacy(dst, r);
  Ok()
}

val exec_psrlw_imm : (simd_idx, byte) -> ExecutionResult
function exec_psrlw_imm(dst, imm8) = {
  let c : int = unsigned(imm8);
  let a : xmmword = read_xmm(dst);
  let r : xmmword =
    srl16(a[127..112], c) @ srl16(a[111..96], c) @
    srl16(a[95..80], c) @ srl16(a[79..64], c) @
    srl16(a[63..48], c) @ srl16(a[47..32], c) @
    srl16(a[31..16], c) @ srl16(a[15..0], c);
  write_xmm_legacy(dst, r);
  Ok()
}

val exec_psrld_imm : (simd_idx, byte) -> ExecutionResult
function exec_psrld_imm(dst, imm8) = {
  let c : int = unsigned(imm8);
  let a : xmmword = read_xmm(dst);
  let r : xmmword =
    srl32(a[127..96], c) @ srl32(a[95..64], c) @
    srl32(a[63..32], c) @ srl32(a[31..0], c);
  write_xmm_legacy(dst, r);
  Ok()
}

val exec_psrlq_imm : (simd_idx, byte) -> ExecutionResult
function exec_psrlq_imm(dst, imm8) = {
  let c : int = unsigned(imm8);
  let a : xmmword = read_xmm(dst);
  let r : xmmword = srl64(a[127..64], c) @ srl64(a[63..0], c);
  write_xmm_legacy(dst, r);
  Ok()
}

val exec_psraw_imm : (simd_idx, byte) -> ExecutionResult
function exec_psraw_imm(dst, imm8) = {
  let c : int = unsigned(imm8);
  let a : xmmword = read_xmm(dst);
  let r : xmmword =
    sra16(a[127..112], c) @ sra16(a[111..96], c) @
    sra16(a[95..80], c) @ sra16(a[79..64], c) @
    sra16(a[63..48], c) @ sra16(a[47..32], c) @
    sra16(a[31..16], c) @ sra16(a[15..0], c);
  write_xmm_legacy(dst, r);
  Ok()
}

val exec_psrad_imm : (simd_idx, byte) -> ExecutionResult
function exec_psrad_imm(dst, imm8) = {
  let c : int = unsigned(imm8);
  let a : xmmword = read_xmm(dst);
  let r : xmmword =
    sra32(a[127..96], c) @ sra32(a[95..64], c) @
    sra32(a[63..32], c) @ sra32(a[31..0], c);
  write_xmm_legacy(dst, r);
  Ok()
}

// Shift-by-XMM variants: count comes from low 64 bits of source XMM.

val exec_psllw_xmm : (simd_idx, xmmword) -> ExecutionResult
function exec_psllw_xmm(dst, src) = {
  let c : int = unsigned(src[63..0]);
  let a : xmmword = read_xmm(dst);
  let r : xmmword =
    sll16(a[127..112], c) @ sll16(a[111..96], c) @
    sll16(a[95..80], c) @ sll16(a[79..64], c) @
    sll16(a[63..48], c) @ sll16(a[47..32], c) @
    sll16(a[31..16], c) @ sll16(a[15..0], c);
  write_xmm_legacy(dst, r);
  Ok()
}

val exec_pslld_xmm : (simd_idx, xmmword) -> ExecutionResult
function exec_pslld_xmm(dst, src) = {
  let c : int = unsigned(src[63..0]);
  let a : xmmword = read_xmm(dst);
  let r : xmmword =
    sll32(a[127..96], c) @ sll32(a[95..64], c) @
    sll32(a[63..32], c) @ sll32(a[31..0], c);
  write_xmm_legacy(dst, r);
  Ok()
}

val exec_psllq_xmm : (simd_idx, xmmword) -> ExecutionResult
function exec_psllq_xmm(dst, src) = {
  let c : int = unsigned(src[63..0]);
  let a : xmmword = read_xmm(dst);
  let r : xmmword = sll64(a[127..64], c) @ sll64(a[63..0], c);
  write_xmm_legacy(dst, r);
  Ok()
}

val exec_psrlw_xmm : (simd_idx, xmmword) -> ExecutionResult
function exec_psrlw_xmm(dst, src) = {
  let c : int = unsigned(src[63..0]);
  let a : xmmword = read_xmm(dst);
  let r : xmmword =
    srl16(a[127..112], c) @ srl16(a[111..96], c) @
    srl16(a[95..80], c) @ srl16(a[79..64], c) @
    srl16(a[63..48], c) @ srl16(a[47..32], c) @
    srl16(a[31..16], c) @ srl16(a[15..0], c);
  write_xmm_legacy(dst, r);
  Ok()
}

val exec_psrld_xmm : (simd_idx, xmmword) -> ExecutionResult
function exec_psrld_xmm(dst, src) = {
  let c : int = unsigned(src[63..0]);
  let a : xmmword = read_xmm(dst);
  let r : xmmword =
    srl32(a[127..96], c) @ srl32(a[95..64], c) @
    srl32(a[63..32], c) @ srl32(a[31..0], c);
  write_xmm_legacy(dst, r);
  Ok()
}

val exec_psrlq_xmm : (simd_idx, xmmword) -> ExecutionResult
function exec_psrlq_xmm(dst, src) = {
  let c : int = unsigned(src[63..0]);
  let a : xmmword = read_xmm(dst);
  let r : xmmword = srl64(a[127..64], c) @ srl64(a[63..0], c);
  write_xmm_legacy(dst, r);
  Ok()
}

val exec_psraw_xmm : (simd_idx, xmmword) -> ExecutionResult
function exec_psraw_xmm(dst, src) = {
  let c : int = unsigned(src[63..0]);
  let a : xmmword = read_xmm(dst);
  let r : xmmword =
    sra16(a[127..112], c) @ sra16(a[111..96], c) @
    sra16(a[95..80], c) @ sra16(a[79..64], c) @
    sra16(a[63..48], c) @ sra16(a[47..32], c) @
    sra16(a[31..16], c) @ sra16(a[15..0], c);
  write_xmm_legacy(dst, r);
  Ok()
}

val exec_psrad_xmm : (simd_idx, xmmword) -> ExecutionResult
function exec_psrad_xmm(dst, src) = {
  let c : int = unsigned(src[63..0]);
  let a : xmmword = read_xmm(dst);
  let r : xmmword =
    sra32(a[127..96], c) @ sra32(a[95..64], c) @
    sra32(a[63..32], c) @ sra32(a[31..0], c);
  write_xmm_legacy(dst, r);
  Ok()
}
// PSUBB/PSUBW/PSUBD/PSUBQ — Subtract Packed Integers
// Wrapping subtraction per lane. No flags affected.

val exec_psubb : (simd_idx, xmmword) -> ExecutionResult
function exec_psubb(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    (a[127..120] - b[127..120]) @ (a[119..112] - b[119..112]) @
    (a[111..104] - b[111..104]) @ (a[103..96] - b[103..96]) @
    (a[95..88] - b[95..88]) @ (a[87..80] - b[87..80]) @
    (a[79..72] - b[79..72]) @ (a[71..64] - b[71..64]) @
    (a[63..56] - b[63..56]) @ (a[55..48] - b[55..48]) @
    (a[47..40] - b[47..40]) @ (a[39..32] - b[39..32]) @
    (a[31..24] - b[31..24]) @ (a[23..16] - b[23..16]) @
    (a[15..8] - b[15..8]) @ (a[7..0] - b[7..0]);
  write_xmm_legacy(dst, r);
  Ok()
}

val exec_psubw : (simd_idx, xmmword) -> ExecutionResult
function exec_psubw(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword = (a[127..112] - b[127..112]) @
                       (a[111..96] - b[111..96]) @
                       (a[95..80] - b[95..80]) @
                       (a[79..64] - b[79..64]) @
                       (a[63..48] - b[63..48]) @
                       (a[47..32] - b[47..32]) @
                       (a[31..16] - b[31..16]) @
                       (a[15..0] - b[15..0]);
  write_xmm_legacy(dst, r);
  Ok()
}

val exec_psubd : (simd_idx, xmmword) -> ExecutionResult
function exec_psubd(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword = (a[127..96] - b[127..96]) @
                       (a[95..64] - b[95..64]) @
                       (a[63..32] - b[63..32]) @
                       (a[31..0] - b[31..0]);
  write_xmm_legacy(dst, r);
  Ok()
}

val exec_psubq : (simd_idx, xmmword) -> ExecutionResult
function exec_psubq(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword = (a[127..64] - b[127..64]) @ (a[63..0] - b[63..0]);
  write_xmm_legacy(dst, r);
  Ok()
}
// PSUBSB/PSUBSW — Subtract Packed Signed Integers with Signed Saturation
// PSUBUSB/PSUBUSW — Subtract Packed Unsigned Integers with Unsigned Saturation
// No flags affected.

val sat_sub_s8 : (byte, byte) -> byte
function sat_sub_s8(a, b) = {
  let diff : int = signed(a) - signed(b);
  let clamped : int = if diff < -128 then -128
                      else if diff > 127 then 127
                      else diff;
  to_bits_truncate(clamped)
}

val sat_sub_s16 : (word, word) -> word
function sat_sub_s16(a, b) = {
  let diff : int = signed(a) - signed(b);
  let clamped : int = if diff < -32768 then -32768
                      else if diff > 32767 then 32767
                      else diff;
  to_bits_truncate(clamped)
}

val sat_sub_u8 : (byte, byte) -> byte
function sat_sub_u8(a, b) = {
  let diff : int = unsigned(a) - unsigned(b);
  let clamped : int = if diff < 0 then 0 else diff;
  to_bits_truncate(clamped)
}

val sat_sub_u16 : (word, word) -> word
function sat_sub_u16(a, b) = {
  let diff : int = unsigned(a) - unsigned(b);
  let clamped : int = if diff < 0 then 0 else diff;
  to_bits_truncate(clamped)
}

val exec_psubsb : (simd_idx, xmmword) -> ExecutionResult
function exec_psubsb(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    sat_sub_s8(a[127..120], b[127..120]) @ sat_sub_s8(a[119..112], b[119..112]) @
    sat_sub_s8(a[111..104], b[111..104]) @ sat_sub_s8(a[103..96], b[103..96]) @
    sat_sub_s8(a[95..88], b[95..88]) @ sat_sub_s8(a[87..80], b[87..80]) @
    sat_sub_s8(a[79..72], b[79..72]) @ sat_sub_s8(a[71..64], b[71..64]) @
    sat_sub_s8(a[63..56], b[63..56]) @ sat_sub_s8(a[55..48], b[55..48]) @
    sat_sub_s8(a[47..40], b[47..40]) @ sat_sub_s8(a[39..32], b[39..32]) @
    sat_sub_s8(a[31..24], b[31..24]) @ sat_sub_s8(a[23..16], b[23..16]) @
    sat_sub_s8(a[15..8], b[15..8]) @ sat_sub_s8(a[7..0], b[7..0]);
  write_xmm_legacy(dst, r);
  Ok()
}

val exec_psubsw : (simd_idx, xmmword) -> ExecutionResult
function exec_psubsw(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    sat_sub_s16(a[127..112], b[127..112]) @ sat_sub_s16(a[111..96], b[111..96]) @
    sat_sub_s16(a[95..80], b[95..80]) @ sat_sub_s16(a[79..64], b[79..64]) @
    sat_sub_s16(a[63..48], b[63..48]) @ sat_sub_s16(a[47..32], b[47..32]) @
    sat_sub_s16(a[31..16], b[31..16]) @ sat_sub_s16(a[15..0], b[15..0]);
  write_xmm_legacy(dst, r);
  Ok()
}

val exec_psubusb : (simd_idx, xmmword) -> ExecutionResult
function exec_psubusb(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    sat_sub_u8(a[127..120], b[127..120]) @ sat_sub_u8(a[119..112], b[119..112]) @
    sat_sub_u8(a[111..104], b[111..104]) @ sat_sub_u8(a[103..96], b[103..96]) @
    sat_sub_u8(a[95..88], b[95..88]) @ sat_sub_u8(a[87..80], b[87..80]) @
    sat_sub_u8(a[79..72], b[79..72]) @ sat_sub_u8(a[71..64], b[71..64]) @
    sat_sub_u8(a[63..56], b[63..56]) @ sat_sub_u8(a[55..48], b[55..48]) @
    sat_sub_u8(a[47..40], b[47..40]) @ sat_sub_u8(a[39..32], b[39..32]) @
    sat_sub_u8(a[31..24], b[31..24]) @ sat_sub_u8(a[23..16], b[23..16]) @
    sat_sub_u8(a[15..8], b[15..8]) @ sat_sub_u8(a[7..0], b[7..0]);
  write_xmm_legacy(dst, r);
  Ok()
}

val exec_psubusw : (simd_idx, xmmword) -> ExecutionResult
function exec_psubusw(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    sat_sub_u16(a[127..112], b[127..112]) @ sat_sub_u16(a[111..96], b[111..96]) @
    sat_sub_u16(a[95..80], b[95..80]) @ sat_sub_u16(a[79..64], b[79..64]) @
    sat_sub_u16(a[63..48], b[63..48]) @ sat_sub_u16(a[47..32], b[47..32]) @
    sat_sub_u16(a[31..16], b[31..16]) @ sat_sub_u16(a[15..0], b[15..0]);
  write_xmm_legacy(dst, r);
  Ok()
}
// PTEST — Logical Compare (SSE4.1)
// Sets ZF if (src1 AND src2) is all zeros.
// Sets CF if (NOT(src1) AND src2) is all zeros.
// Clears OF, AF, PF, SF.

val exec_ptest : (xmmword, xmmword) -> ExecutionResult
function exec_ptest(src1, src2) = {
  let a : xmmword = src1;
  let b : xmmword = src2;
  let temp1 : xmmword = a & b;
  let temp2 : xmmword = (not_vec(a)) & b;
  ZF = bool_to_bit(temp1 == zeros());
  CF = bool_to_bit(temp2 == zeros());
  OF = bitzero;
  AF = bitzero;
  PF = bitzero;
  SF = bitzero;
  Ok()
}
// PUNPCKHBW — Unpack High Data (Bytes to Words)
// PUNPCKHWD — Unpack High Data (Words to Doublewords)
// PUNPCKHDQ — Unpack High Data (Doublewords to Quadwords)
// PUNPCKHQDQ — Unpack High Data (Quadwords to Double Quadword)
// Interleave high-order data elements from dst and src. No flags affected.

val exec_punpckhbw : (simd_idx, xmmword) -> ExecutionResult
function exec_punpckhbw(dst, src) = {
  let d : xmmword = read_xmm(dst);
  let s : xmmword = src;
  let result : xmmword =
    s[127..120] @ d[127..120] @
    s[119..112] @ d[119..112] @
    s[111..104] @ d[111..104] @
    s[103..96]  @ d[103..96]  @
    s[95..88]   @ d[95..88]   @
    s[87..80]   @ d[87..80]   @
    s[79..72]   @ d[79..72]   @
    s[71..64]   @ d[71..64];
  write_xmm_legacy(dst, result);
  Ok()
}

val exec_punpckhwd : (simd_idx, xmmword) -> ExecutionResult
function exec_punpckhwd(dst, src) = {
  let d : xmmword = read_xmm(dst);
  let s : xmmword = src;
  let result : xmmword =
    s[127..112] @ d[127..112] @
    s[111..96]  @ d[111..96]  @
    s[95..80]   @ d[95..80]   @
    s[79..64]   @ d[79..64];
  write_xmm_legacy(dst, result);
  Ok()
}

val exec_punpckhdq : (simd_idx, xmmword) -> ExecutionResult
function exec_punpckhdq(dst, src) = {
  let d : xmmword = read_xmm(dst);
  let s : xmmword = src;
  let result : xmmword =
    s[127..96] @ d[127..96] @
    s[95..64]  @ d[95..64];
  write_xmm_legacy(dst, result);
  Ok()
}

val exec_punpckhqdq : (simd_idx, xmmword) -> ExecutionResult
function exec_punpckhqdq(dst, src) = {
  let d : xmmword = read_xmm(dst);
  let s : xmmword = src;
  write_xmm_legacy(dst, s[127..64] @ d[127..64]);
  Ok()
}
// PUNPCKLBW — Unpack Low Data (Bytes to Words)
// PUNPCKLWD — Unpack Low Data (Words to Doublewords)
// PUNPCKLDQ — Unpack Low Data (Doublewords to Quadwords)
// PUNPCKLQDQ — Unpack Low Data (Quadwords to Double Quadword)
// Interleave low-order data elements from dst and src. No flags affected.

val exec_punpcklbw : (simd_idx, xmmword) -> ExecutionResult
function exec_punpcklbw(dst, src) = {
  let d : xmmword = read_xmm(dst);
  let s : xmmword = src;
  let result : xmmword =
    s[63..56] @ d[63..56] @
    s[55..48] @ d[55..48] @
    s[47..40] @ d[47..40] @
    s[39..32] @ d[39..32] @
    s[31..24] @ d[31..24] @
    s[23..16] @ d[23..16] @
    s[15..8]  @ d[15..8]  @
    s[7..0]   @ d[7..0];
  write_xmm_legacy(dst, result);
  Ok()
}

val exec_punpcklwd : (simd_idx, xmmword) -> ExecutionResult
function exec_punpcklwd(dst, src) = {
  let d : xmmword = read_xmm(dst);
  let s : xmmword = src;
  let result : xmmword =
    s[63..48] @ d[63..48] @
    s[47..32] @ d[47..32] @
    s[31..16] @ d[31..16] @
    s[15..0]  @ d[15..0];
  write_xmm_legacy(dst, result);
  Ok()
}

val exec_punpckldq : (simd_idx, xmmword) -> ExecutionResult
function exec_punpckldq(dst, src) = {
  let d : xmmword = read_xmm(dst);
  let s : xmmword = src;
  let result : xmmword =
    s[63..32] @ d[63..32] @
    s[31..0]  @ d[31..0];
  write_xmm_legacy(dst, result);
  Ok()
}

val exec_punpcklqdq : (simd_idx, xmmword) -> ExecutionResult
function exec_punpcklqdq(dst, src) = {
  let d : xmmword = read_xmm(dst);
  let s : xmmword = src;
  write_xmm_legacy(dst, s[63..0] @ d[63..0]);
  Ok()
}
// PXOR — Logical Exclusive OR (packed)
//
// 128-bit bitwise XOR on XMM registers. No flags affected.

// Legacy SSE: PXOR xmm1, xmm2
val exec_pxor_xmm : (simd_idx, xmmword) -> ExecutionResult
function exec_pxor_xmm(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  write_xmm_legacy(dst, a ^ b);
  Ok()
}

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
  Ok()
}
// PHADDW/PHADDD — Packed Horizontal Add (SSSE3)
// No flags affected.

val exec_phaddw : (simd_idx, xmmword) -> ExecutionResult
function exec_phaddw(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    (b[127..112] + b[111..96]) @ (b[95..80] + b[79..64]) @
    (b[63..48] + b[47..32]) @ (b[31..16] + b[15..0]) @
    (a[127..112] + a[111..96]) @ (a[95..80] + a[79..64]) @
    (a[63..48] + a[47..32]) @ (a[31..16] + a[15..0]);
  write_xmm_legacy(dst, r);
  Ok()
}

val exec_phaddd : (simd_idx, xmmword) -> ExecutionResult
function exec_phaddd(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    (b[127..96] + b[95..64]) @ (b[63..32] + b[31..0]) @
    (a[127..96] + a[95..64]) @ (a[63..32] + a[31..0]);
  write_xmm_legacy(dst, r);
  Ok()
}
// PHMINPOSUW — Packed Horizontal Minimum of Unsigned Words (SSE4.1)
// Finds the minimum unsigned word and its index. No flags affected.

val exec_phminposuw : (simd_idx, xmmword) -> ExecutionResult
function exec_phminposuw(dst, src) = {
  let s : xmmword = src;
  let w0 : word = s[15..0];
  let w1 : word = s[31..16];
  let w2 : word = s[47..32];
  let w3 : word = s[63..48];
  let w4 : word = s[79..64];
  let w5 : word = s[95..80];
  let w6 : word = s[111..96];
  let w7 : word = s[127..112];
  // Find minimum value and index (lowest index wins on tie)
  let min_val : word = w0;
  let min_idx : word = 0x0000;
  let (min_val, min_idx) = if unsigned(w1) < unsigned(min_val) then (w1, 0x0001) else (min_val, min_idx);
  let (min_val, min_idx) = if unsigned(w2) < unsigned(min_val) then (w2, 0x0002) else (min_val, min_idx);
  let (min_val, min_idx) = if unsigned(w3) < unsigned(min_val) then (w3, 0x0003) else (min_val, min_idx);
  let (min_val, min_idx) = if unsigned(w4) < unsigned(min_val) then (w4, 0x0004) else (min_val, min_idx);
  let (min_val, min_idx) = if unsigned(w5) < unsigned(min_val) then (w5, 0x0005) else (min_val, min_idx);
  let (min_val, min_idx) = if unsigned(w6) < unsigned(min_val) then (w6, 0x0006) else (min_val, min_idx);
  let (min_val, min_idx) = if unsigned(w7) < unsigned(min_val) then (w7, 0x0007) else (min_val, min_idx);
  write_xmm_legacy(dst, zeros(96) @ min_idx @ min_val);
  Ok()
}
// PHSUBSW — Packed Horizontal Subtract with Saturation (SSSE3)
// Subtracts adjacent signed 16-bit integers horizontally with signed saturation.
// No flags affected.

val exec_phsubsw : (simd_idx, xmmword) -> ExecutionResult
function exec_phsubsw(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    sat_sub_s16(b[127..112], b[111..96]) @ sat_sub_s16(b[95..80], b[79..64]) @
    sat_sub_s16(b[63..48], b[47..32]) @ sat_sub_s16(b[31..16], b[15..0]) @
    sat_sub_s16(a[127..112], a[111..96]) @ sat_sub_s16(a[95..80], a[79..64]) @
    sat_sub_s16(a[63..48], a[47..32]) @ sat_sub_s16(a[31..16], a[15..0]);
  write_xmm_legacy(dst, r);
  Ok()
}
// PHSUBW/PHSUBD — Packed Horizontal Subtract (SSSE3)
// No flags affected.

val exec_phsubw : (simd_idx, xmmword) -> ExecutionResult
function exec_phsubw(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    (b[127..112] - b[111..96]) @ (b[95..80] - b[79..64]) @
    (b[63..48] - b[47..32]) @ (b[31..16] - b[15..0]) @
    (a[127..112] - a[111..96]) @ (a[95..80] - a[79..64]) @
    (a[63..48] - a[47..32]) @ (a[31..16] - a[15..0]);
  write_xmm_legacy(dst, r);
  Ok()
}

val exec_phsubd : (simd_idx, xmmword) -> ExecutionResult
function exec_phsubd(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword =
    (b[127..96] - b[95..64]) @ (b[63..32] - b[31..0]) @
    (a[127..96] - a[95..64]) @ (a[63..32] - a[31..0]);
  write_xmm_legacy(dst, r);
  Ok()
}
// EXTRACTPS — Extract Packed Floating-Point Values (SSE4.1)
//
// Extracts a single-precision float from an XMM register at the offset
// specified by imm8[1:0] and stores the 32-bit result in a GPR or memory.
// In 64-bit mode with a GPR destination, the upper 32 bits are zeroed.
// No flags affected.
//
// Uses extract_dword_from_xmm from pextrb.sail (same operation as PEXTRD).
// INSERTPS — Insert Scalar Single-FP (SSE4.1)
// Selects a float from src, inserts into dst at specified position, then zeroes selected lanes.
// No flags affected.

val exec_insertps : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_insertps(dst, src, imm8) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  // Select source float using imm8[7:6]
  let src_sel : range(0, 3) = unsigned(imm8[7..6]);
  let src_float : dword = b[(src_sel * 32 + 31) .. (src_sel * 32)];
  // Insert at destination position using imm8[5:4]
  let dst_sel : range(0, 3) = unsigned(imm8[5..4]);
  let t0 : dword = if dst_sel == 0 then src_float else a[31..0];
  let t1 : dword = if dst_sel == 1 then src_float else a[63..32];
  let t2 : dword = if dst_sel == 2 then src_float else a[95..64];
  let t3 : dword = if dst_sel == 3 then src_float else a[127..96];
  // Zero lanes indicated by imm8[3:0]
  let d0 : dword = if imm8[0] == bitone then 0x00000000 else t0;
  let d1 : dword = if imm8[1] == bitone then 0x00000000 else t1;
  let d2 : dword = if imm8[2] == bitone then 0x00000000 else t2;
  let d3 : dword = if imm8[3] == bitone then 0x00000000 else t3;
  write_xmm_legacy(dst, d3 @ d2 @ d1 @ d0);
  Ok()
}
// MPSADBW — Multiple Sum of Absolute Differences (SSE4.1)
// Complex operation modeled as external. No flags affected.

val __mpsadbw : (xmmword, xmmword, byte) -> xmmword

val exec_mpsadbw : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_mpsadbw(dst, src, imm8) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  write_xmm_legacy(dst, __mpsadbw(a, b, imm8));
  Ok()
}
// MASKMOVDQU -- Store Selected Bytes of Double Quadword
//
// Selectively writes bytes from the source XMM register to memory at
// DS:DI/EDI/RDI. Each byte in the mask XMM register controls whether
// the corresponding byte is written (high bit = 1 means write).
// No flags affected.

val __maskmovdqu : (xmmword, xmmword, qword) -> unit

val exec_maskmovdqu : (xmmword, xmmword, qword) -> ExecutionResult
function exec_maskmovdqu(data, mask, addr) = {
  __maskmovdqu(data, mask, addr);
  Ok()
}
// AES-NI Instructions
// AESENC, AESDEC, AESENCLAST, AESDECLAST — AES round operations
// AESIMC — AES Inverse Mix Columns
// AESKEYGENASSIST — AES Round Key Generation Assist
//
// All AES round operations (ShiftRows, SubBytes, MixColumns, etc.) are
// complex cryptographic primitives modeled as external functions.
// No flags affected.

// External AES primitives
val __aesenc : (xmmword, xmmword) -> xmmword
val __aesdec : (xmmword, xmmword) -> xmmword
val __aesenclast : (xmmword, xmmword) -> xmmword
val __aesdeclast : (xmmword, xmmword) -> xmmword
val __aesimc : xmmword -> xmmword
val __aeskeygenassist : (xmmword, byte) -> xmmword

// AESENC — Perform One Round of an AES Encryption Flow
// DEST[127:0] := ShiftRows(SubBytes(MixColumns(SRC1))) XOR SRC2
val exec_aesenc : (simd_idx, xmmword) -> ExecutionResult
function exec_aesenc(dst, src) = {
  let state : xmmword = read_xmm(dst);
  let roundkey : xmmword = src;
  write_xmm_legacy(dst, __aesenc(state, roundkey));
  Ok()
}

// AESDEC — Perform One Round of an AES Decryption Flow
// DEST[127:0] := InvShiftRows(InvSubBytes(InvMixColumns(SRC1))) XOR SRC2
val exec_aesdec : (simd_idx, xmmword) -> ExecutionResult
function exec_aesdec(dst, src) = {
  let state : xmmword = read_xmm(dst);
  let roundkey : xmmword = src;
  write_xmm_legacy(dst, __aesdec(state, roundkey));
  Ok()
}

// AESENCLAST — Perform Last Round of an AES Encryption Flow
// DEST[127:0] := ShiftRows(SubBytes(SRC1)) XOR SRC2 (no MixColumns)
val exec_aesenclast : (simd_idx, xmmword) -> ExecutionResult
function exec_aesenclast(dst, src) = {
  let state : xmmword = read_xmm(dst);
  let roundkey : xmmword = src;
  write_xmm_legacy(dst, __aesenclast(state, roundkey));
  Ok()
}

// AESDECLAST — Perform Last Round of an AES Decryption Flow
// DEST[127:0] := InvShiftRows(InvSubBytes(SRC1)) XOR SRC2 (no InvMixColumns)
val exec_aesdeclast : (simd_idx, xmmword) -> ExecutionResult
function exec_aesdeclast(dst, src) = {
  let state : xmmword = read_xmm(dst);
  let roundkey : xmmword = src;
  write_xmm_legacy(dst, __aesdeclast(state, roundkey));
  Ok()
}

// AESIMC — Perform the AES InvMixColumns Transformation
// DEST[127:0] := InvMixColumns(SRC)
val exec_aesimc : (simd_idx, xmmword) -> ExecutionResult
function exec_aesimc(dst, src) = {
  let s : xmmword = src;
  write_xmm_legacy(dst, __aesimc(s));
  Ok()
}

// AESKEYGENASSIST — AES Round Key Generation Assist
// Uses SubWord and RotWord on dwords from SRC, XORs with RCON from imm8.
val exec_aeskeygenassist : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_aeskeygenassist(dst, src, imm8) = {
  let s : xmmword = src;
  write_xmm_legacy(dst, __aeskeygenassist(s, imm8));
  Ok()
}
// PCLMULQDQ — Carry-Less Multiplication Quadword
//
// Performs carry-less (polynomial) multiplication of two 64-bit values
// selected from src and dst by imm8. The 128-bit result is stored in dst.
// imm8[0] selects which qword of dst, imm8[4] selects which qword of src.
// No flags affected.
//
// The carry-less multiply operation is complex; modeled as external.

val __pclmulqdq : (qword, qword) -> xmmword

val exec_pclmulqdq : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_pclmulqdq(dst, src, imm8) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let sel_a : qword = if imm8[0] == bitone then a[127..64] else a[63..0];
  let sel_b : qword = if imm8[4] == bitone then b[127..64] else b[63..0];
  let result : xmmword = __pclmulqdq(sel_a, sel_b);
  write_xmm_legacy(dst, result);
  Ok()
}

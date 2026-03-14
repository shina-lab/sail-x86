// x86-64 — SSE Integer Operations
//
// SSE/SSE2/SSSE3/SSE4.1/SSE4.2 packed integer arithmetic, logical,
// shift, pack/unpack, compare, AES-NI, and PCLMULQDQ.

// Forward declaration — defined in insn_mmx.sail (compiled after this file)
val dispatch_mmx : (range(0, 255), Prefixes) -> unit

// =========================================================================
// SSE integer helper functions
// =========================================================================

// CRC32 — Accumulate CRC32C (Castagnoli) value
// Polynomial: 0x1EDC6F41 (reflected: 0x82F63B78)
// Processes one byte at a time using the reflected algorithm.
val crc32c_byte : (bits(32), byte) -> bits(32)
function crc32c_byte(crc, data) = {
  var c : bits(32) = crc ^ zero_extend(data);
  foreach (i from 0 to 7) {
    c = (0b0 @ c[31..1]) ^ (sign_extend(c[0..0]) & 0x82F63B78)
  };
  c
}

val crc32c_16 : (bits(32), bits(16)) -> bits(32)
function crc32c_16(crc, data) = {
  let c1 = crc32c_byte(crc, data[7..0]);
  crc32c_byte(c1, data[15..8])
}

val crc32c_32 : (bits(32), bits(32)) -> bits(32)
function crc32c_32(crc, data) = {
  let c1 = crc32c_byte(crc, data[7..0]);
  let c2 = crc32c_byte(c1, data[15..8]);
  let c3 = crc32c_byte(c2, data[23..16]);
  crc32c_byte(c3, data[31..24])
}

val crc32c_64 : (bits(32), bits(64)) -> bits(32)
function crc32c_64(crc, data) = {
  let c1 = crc32c_32(crc, data[31..0]);
  crc32c_32(c1, data[63..32])
}

// PABSB/PABSW/PABSD — Packed Absolute Value (SSSE3)
// No flags affected.
// Branchless: mask = sign-extend of MSB; (x ^ mask) - mask
val abs8 : byte -> byte
function abs8(x) = { let m : byte = sign_extend(x[7..7]); (x ^ m) - m }

val abs16 : word -> word
function abs16(x) = { let m : word = sign_extend(x[15..15]); (x ^ m) - m }

val abs32 : dword -> dword
function abs32(x) = { let m : dword = sign_extend(x[31..31]); (x ^ m) - m }

val abs64 : qword -> qword
function abs64(x) = { let m : qword = sign_extend(x[63..63]); (x ^ m) - m }

// PACKSSWB — Pack with Signed Saturation (words to bytes)
// PACKSSDW — Pack with Signed Saturation (dwords to words)
// No flags affected.
// Branchless: check if upper bits are sign-extension of truncated value.
val sat_s16_to_s8 : word -> byte
function sat_s16_to_s8(x) = {
  let sign : bits(1) = x[15..15];
  let diff : byte = x[14..7] ^ sign_extend(sign);
  let out_of_range : bits(1) = or_reduce_8(diff);
  let out_mask : byte = sign_extend(out_of_range);
  let clamp_val : byte = sign_extend(sign) ^ 0x7F;
  (clamp_val & out_mask) | (x[7..0] & ~(out_mask))
}

val sat_s32_to_s16 : dword -> word
function sat_s32_to_s16(x) = {
  let sign : bits(1) = x[31..31];
  let diff : word = x[30..15] ^ sign_extend(sign);
  let out_of_range : bits(1) = or_reduce_16(diff);
  let out_mask : word = sign_extend(out_of_range);
  let clamp_val : word = sign_extend(sign) ^ 0x7FFF;
  (clamp_val & out_mask) | (x[15..0] & ~(out_mask))
}

// VPMOVS — Signed saturation truncation (wider → narrower)
// Branchless: check if bits above target width are proper sign-extension.

val sat_s32_to_s8 : dword -> byte
function sat_s32_to_s8(x) = {
  let sign : bits(1) = x[31..31];
  let diff : bits(24) = x[30..7] ^ sign_extend(sign);
  let out_of_range : bits(1) = or_reduce_8(diff[23..16] | diff[15..8] | diff[7..0]);
  let out_mask : byte = sign_extend(out_of_range);
  let clamp_val : byte = sign_extend(sign) ^ 0x7F;
  (clamp_val & out_mask) | (x[7..0] & ~(out_mask))
}

val sat_s64_to_s8 : qword -> byte
function sat_s64_to_s8(x) = {
  let sign : bits(1) = x[63..63];
  let diff : bits(56) = x[62..7] ^ sign_extend(sign);
  let folded : byte = diff[55..48] | diff[47..40] | diff[39..32] | diff[31..24] | diff[23..16] | diff[15..8] | diff[7..0];
  let out_of_range : bits(1) = or_reduce_8(folded);
  let out_mask : byte = sign_extend(out_of_range);
  let clamp_val : byte = sign_extend(sign) ^ 0x7F;
  (clamp_val & out_mask) | (x[7..0] & ~(out_mask))
}

val sat_s64_to_s16 : qword -> word
function sat_s64_to_s16(x) = {
  let sign : bits(1) = x[63..63];
  let diff : bits(48) = x[62..15] ^ sign_extend(sign);
  let folded : word = diff[47..32] | diff[31..16] | diff[15..0];
  let out_of_range : bits(1) = or_reduce_16(folded);
  let out_mask : word = sign_extend(out_of_range);
  let clamp_val : word = sign_extend(sign) ^ 0x7FFF;
  (clamp_val & out_mask) | (x[15..0] & ~(out_mask))
}

val sat_s64_to_s32 : qword -> dword
function sat_s64_to_s32(x) = {
  let sign : bits(1) = x[63..63];
  let diff : dword = x[62..31] ^ sign_extend(sign);
  let out_of_range : bits(1) = or_reduce_32(diff);
  let out_mask : dword = sign_extend(out_of_range);
  let clamp_val : dword = sign_extend(sign) ^ 0x7FFFFFFF;
  (clamp_val & out_mask) | (x[31..0] & ~(out_mask))
}

// PACKUSDW — Pack Dwords to Words with Unsigned Saturation (SSE4.1)
// Packs 4 signed dwords from dst and 4 from src into 8 unsigned words.
// No flags affected.
// Branchless: zero negative values, then saturate positive overflow.
val sat_s32_to_u16 : dword -> word
function sat_s32_to_u16(v) = {
  let neg_mask : dword = sign_extend(v[31..31]);
  let pos_val : dword = v & ~(neg_mask);
  let overflow : bits(1) = or_reduce_16(pos_val[31..16]);
  let over_mask : word = sign_extend(overflow);
  pos_val[15..0] | over_mask
}

// PACKUSWB — Pack with Unsigned Saturation (words to bytes)
// No flags affected.
// Branchless: zero negative values, then saturate positive overflow.
val sat_s16_to_u8 : word -> byte
function sat_s16_to_u8(x) = {
  let neg_mask : word = sign_extend(x[15..15]);
  let pos_val : word = x & ~(neg_mask);
  let overflow : bits(1) = or_reduce_8(pos_val[15..8]);
  let over_mask : byte = sign_extend(overflow);
  pos_val[7..0] | over_mask
}

// VPMOVUS — Unsigned saturation truncation (wider → narrower)
// Branchless: if any upper bit is set, OR result with all-ones.

val sat_trunc_u_w2b : word -> byte
function sat_trunc_u_w2b(x) = {
  let overflow : byte = sign_extend(or_reduce_8(x[15..8]));
  x[7..0] | overflow
}

val sat_trunc_u_d2w : dword -> word
function sat_trunc_u_d2w(x) = {
  let overflow : word = sign_extend(or_reduce_16(x[31..16]));
  x[15..0] | overflow
}

val sat_trunc_u_d2b : dword -> byte
function sat_trunc_u_d2b(x) = {
  let overflow : byte = sign_extend(or_reduce_8(x[31..24] | x[23..16] | x[15..8]));
  x[7..0] | overflow
}

val sat_trunc_u_q2b : qword -> byte
function sat_trunc_u_q2b(x) = {
  let overflow : byte = sign_extend(or_reduce_8(x[63..56] | x[55..48] | x[47..40] | x[39..32] | x[31..24] | x[23..16] | x[15..8]));
  x[7..0] | overflow
}

val sat_trunc_u_q2w : qword -> word
function sat_trunc_u_q2w(x) = {
  let overflow : word = sign_extend(or_reduce_16(x[63..48] | x[47..32] | x[31..16]));
  x[15..0] | overflow
}

val sat_trunc_u_q2d : qword -> dword
function sat_trunc_u_q2d(x) = {
  let overflow : dword = sign_extend(or_reduce_32(x[63..32]));
  x[31..0] | overflow
}

// PADDSB/PADDSW — Add Packed Signed Integers with Signed Saturation
// PADDUSB/PADDUSW — Add Packed Unsigned Integers with Unsigned Saturation
// No flags affected.
// Branchless: detect overflow/underflow via sign bits of wide sum.
val sat_add_s8 : (byte, byte) -> byte
function sat_add_s8(a, b) = {
  let wide : bits(9) = sign_extend(a) + sign_extend(b);
  let ov : bits(1) = ~(wide[8..8]) & wide[7..7];
  let uf : bits(1) = wide[8..8] & ~(wide[7..7]);
  let ov_mask : byte = sign_extend(ov);
  let uf_mask : byte = sign_extend(uf);
  (0x7F & ov_mask) | (0x80 & uf_mask) | (wide[7..0] & ~(ov_mask) & ~(uf_mask))
}

val sat_add_s16 : (word, word) -> word
function sat_add_s16(a, b) = {
  let wide : bits(17) = sign_extend(a) + sign_extend(b);
  let ov : bits(1) = ~(wide[16..16]) & wide[15..15];
  let uf : bits(1) = wide[16..16] & ~(wide[15..15]);
  let ov_mask : word = sign_extend(ov);
  let uf_mask : word = sign_extend(uf);
  (0x7FFF & ov_mask) | (0x8000 & uf_mask) | (wide[15..0] & ~(ov_mask) & ~(uf_mask))
}

// Branchless: carry bit of wide sum → saturate to all-1s.
val sat_add_u8 : (byte, byte) -> byte
function sat_add_u8(a, b) = {
  let wide : bits(9) = (0b0 @ a) + (0b0 @ b);
  let sat : byte = sign_extend(wide[8..8]);
  wide[7..0] | sat
}

val sat_add_u16 : (word, word) -> word
function sat_add_u16(a, b) = {
  let wide : bits(17) = (0b0 @ a) + (0b0 @ b);
  let sat : word = sign_extend(wide[16..16]);
  wide[15..0] | sat
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

// PCMPEQB/PCMPEQW/PCMPEQD — Compare Packed Integers for Equal
// PCMPGTB/PCMPGTW/PCMPGTD — Compare Packed Signed Integers for Greater Than
// Result is all-ones if true, all-zeros if false per lane.
//
// All comparison helpers use the wide intermediate in TWO extract positions
// (high bit + low bits) to prevent Isla from inlining the subtraction and
// then incorrectly distributing extract over bvsub.
//
// cmp_eq: (0 @ (a^b)) - 1 borrows iff a^b == 0 iff a == b.
//   When a==b: result = 0x1FF, low=0xFF, high=1 → 0xFF & 0xFF = 0xFF.
//   When a!=b: result = [0,0xFE], low=xor-1, high=0 → anything & 0x00 = 0x00.
//
// cmp_gt (signed): convert to unsigned via XOR sign bit, compute sat_sub,
//   then convert nonzero to all-ones mask using the borrow trick.

val cmp_eq8 : (byte, byte) -> byte
function cmp_eq8(a, b) = {
  let xd : bits(9) = (0b0 @ xor_vec(a, b)) - 0b000000001;
  xd[7..0] & sign_extend(xd[8..8])
}

val cmp_gt8 : (byte, byte) -> byte
function cmp_gt8(a, b) = {
  // a > b signed iff (a^0x80) > (b^0x80) unsigned iff sat_sub > 0
  let ds : bits(9) = (0b0 @ (a ^ 0x80)) - (0b0 @ (b ^ 0x80));
  let d : byte = ds[7..0] & sign_extend(~(ds[8..8]));
  // d != 0 → borrow on d-1 is 0 → mask = ~(low & 0xFF) = 0xFF
  // d == 0 → borrow on d-1 is 1 → mask = ~(0xFF & 0xFF) = 0x00
  let probe : bits(9) = (0b0 @ d) - 0b000000001;
  ~(probe[7..0] & sign_extend(probe[8..8]))
}

val cmp_eq16 : (word, word) -> word
function cmp_eq16(a, b) = {
  let xd : bits(17) = (0b0 @ xor_vec(a, b)) - 0b00000000000000001;
  xd[15..0] & sign_extend(xd[16..16])
}

val cmp_gt16 : (word, word) -> word
function cmp_gt16(a, b) = {
  let ds : bits(17) = (0b0 @ (a ^ 0x8000)) - (0b0 @ (b ^ 0x8000));
  let d : word = ds[15..0] & sign_extend(~(ds[16..16]));
  let probe : bits(17) = (0b0 @ d) - 0b00000000000000001;
  ~(probe[15..0] & sign_extend(probe[16..16]))
}

val cmp_eq32 : (dword, dword) -> dword
function cmp_eq32(a, b) = {
  let xd : bits(33) = (0b0 @ xor_vec(a, b)) - 0b000000000000000000000000000000001;
  xd[31..0] & sign_extend(xd[32..32])
}

val cmp_gt32 : (dword, dword) -> dword
function cmp_gt32(a, b) = {
  let ds : bits(33) = (0b0 @ (a ^ 0x80000000)) - (0b0 @ (b ^ 0x80000000));
  let d : dword = ds[31..0] & sign_extend(~(ds[32..32]));
  let probe : bits(33) = (0b0 @ d) - 0b000000000000000000000000000000001;
  ~(probe[31..0] & sign_extend(probe[32..32]))
}

val cmp_eq64 : (qword, qword) -> qword
function cmp_eq64(a, b) = {
  let xd : bits(65) = (0b0 @ xor_vec(a, b)) - zero_extend(0b1 : bits(1));
  zeros() - zero_extend(xd[64..64])
}

val cmp_gt64 : (qword, qword) -> qword
function cmp_gt64(a, b) = {
  let a65 : bits(65) = sign_extend(a);
  let b65 : bits(65) = sign_extend(b);
  let diff : bits(65) = b65 - a65;
  zeros() - zero_extend(diff[64..64])
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

// PCMPESTRM — Packed Compare Explicit Length Strings, Return Mask (SSE4.2)
//
// Compares two string fragments using imm8 control. The explicit lengths
// are in EAX (for xmm1) and EDX (for xmm2/m128). The result mask is
// returned in XMM0. Flags CF, ZF, SF, OF, AF, PF are set.
//
// This is a very complex operation; modeled as external.
val __pcmpestrm : (xmmword, dword, xmmword, dword, byte) -> (xmmword, bit, bit, bit, bit)

// PCMPISTRI — Packed Compare Implicit Length Strings, Return Index (SSE4.2)
//
// Compares two null-terminated string fragments using imm8 control.
// Lengths are implicit (determined by null characters in the operands).
// The result index is returned in ECX.
// Flags CF, ZF, SF, OF, AF, PF are set.
//
// This is a very complex operation; modeled as external.
val __pcmpistri : (xmmword, xmmword, byte) -> (dword, bit, bit, bit, bit)

// PCMPISTRM — Packed Compare Implicit Length Strings, Return Mask (SSE4.2)
//
// Compares two null-terminated string fragments using imm8 control.
// Lengths are implicit (determined by null characters in the operands).
// The result mask is returned in XMM0.
// Flags CF, ZF, SF, OF, AF, PF are set.
//
// This is a very complex operation; modeled as external.
val __pcmpistrm : (xmmword, xmmword, byte) -> (xmmword, bit, bit, bit, bit)

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

val insert_dword : (xmmword, dword, range(0, 3)) -> xmmword
function insert_dword(v, d, sel) = {
  match sel {
    0 => v[127..32] @ d,
    1 => v[127..64] @ d @ v[31..0],
    2 => v[127..96] @ d @ v[63..0],
    3 => d @ v[95..0]
  }
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

// PMADDUBSW — Multiply and Add Packed Signed and Unsigned Bytes (SSSE3)
// Multiplies unsigned bytes from src1 with signed bytes from src2,
// then adds adjacent pairs with signed saturation to produce 16-bit results.
// No flags affected.
val pmaddubsw_pair : (byte, byte, byte, byte) -> word
function pmaddubsw_pair(a_even, b_even, a_odd, b_odd) = {
  let p1 : int = unsigned(a_even) * signed(b_even);
  let p2 : int = unsigned(a_odd) * signed(b_odd);
  let sum : int = p1 + p2;
  // Branchless signed saturation to 16-bit via 17-bit overflow detection
  let wide : bits(17) = get_slice_int(17, sum, 0);
  let sign : bits(1) = wide[16..16];
  let of_mask : word = sign_extend(sign ^ wide[15..15]);
  let sat : word = sign_extend(sign) ^ 0x7FFF;
  (sat & of_mask) | (wide[15..0] & not_vec(of_mask))
}

val max_s64 : (qword, qword) -> qword
function max_s64(a, b) = {
  let diff : bits(65) = sign_extend(b) - sign_extend(a);
  let mask : qword = zeros() - zero_extend(diff[64..64]);
  (a & mask) | (b & ~(mask))
}

val min_s64 : (qword, qword) -> qword
function min_s64(a, b) = {
  let diff : bits(65) = sign_extend(a) - sign_extend(b);
  let mask : qword = zeros() - zero_extend(diff[64..64]);
  (a & mask) | (b & ~(mask))
}

val max_u64 : (qword, qword) -> qword
function max_u64(a, b) = {
  let diff : bits(65) = (0b0 @ a) - (0b0 @ b);
  let mask : qword = zeros() - zero_extend(diff[64..64]);
  (b & mask) | (a & ~(mask))
}

val min_u64 : (qword, qword) -> qword
function min_u64(a, b) = {
  let diff : bits(65) = (0b0 @ a) - (0b0 @ b);
  let mask : qword = zeros() - zero_extend(diff[64..64]);
  (a & mask) | (b & ~(mask))
}

// PMOVSX — Packed Move with Sign Extend (SSE4.1)
// Sign-extends packed integers from smaller to larger element sizes.
// No flags affected.
val sx8_16 : byte -> word
function sx8_16(v) = sign_extend(v)

val sx8_32 : byte -> dword
function sx8_32(v) = sign_extend(v)

val sx16_32 : word -> dword
function sx16_32(v) = sign_extend(v)

// PMOVZX — Packed Move with Zero Extend (SSE4.1)
// Zero-extends packed integers from smaller to larger element sizes.
// No flags affected.
val zx8_16 : byte -> word
function zx8_16(v) = zero_extend(v)

val zx8_32 : byte -> dword
function zx8_32(v) = zero_extend(v)

val zx16_32 : word -> dword
function zx16_32(v) = zero_extend(v)

// PMULHRSW — Packed Multiply High with Round and Scale (SSSE3)
// No flags affected.
val mulhrsw : (word, word) -> word
function mulhrsw(a, b) = {
  let product : dword = to_bits_truncate(signed(a) * signed(b));
  let rounded : dword = product + 0x00004000;

  // Take bits [30..15] which is equivalent to arithmetic right shift by 15
  rounded[30..15]
}

// PMULLD — Multiply Packed Signed Dword Integers and Store Low Result (SSE4.1)
// No flags affected.
val mul_lo32 : (dword, dword) -> dword
function mul_lo32(a, b) = {
  let product : int = signed(a) * signed(b);
  to_bits_truncate(product)
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

// PSADBW — Compute Sum of Absolute Differences
// Computes absolute differences of unsigned byte pairs, then sums each 8-byte group.
// Result is zero-extended to 64 bits per qword lane. No flags affected.
val abs_diff8 : (byte, byte) -> int
function abs_diff8(a, b) = {
  let d1 : bits(9) = (0b0 @ a) - (0b0 @ b);
  let d2 : bits(9) = (0b0 @ b) - (0b0 @ a);
  let m1 : byte = sign_extend(~(d1[8..8]));
  let m2 : byte = sign_extend(~(d2[8..8]));
  unsigned((d1[7..0] & m1) | (d2[7..0] & m2))
}

// PSHUFB — Packed Shuffle Bytes (SSSE3)
// Each byte in result is selected from dst by the low 4 bits of the corresponding
// byte in src. If the high bit of the selector byte is set, the result byte is zero.
// No flags affected.
// Branchless: shift right by idx*8, take low byte, AND with zero-mask.
val pshufb_byte : (xmmword, byte) -> byte
function pshufb_byte(data, mask) = {
  let idx : range(0, 15) = unsigned(mask[3..0]);
  let selected : byte = (data >> (idx * 8))[7..0];
  selected & sign_extend(~(mask[7..7]))
}

// PSHUFHW — Shuffle Packed High Words
// Low qword copied unchanged from src. High qword: 4 words selected
// from src's high qword by imm8. No flags affected.
val select_high_word : (xmmword, bits(2)) -> word
function select_high_word(v, sel) = {
  let idx : range(0, 3) = unsigned(sel);
  v[(idx * 16 + 79) .. (idx * 16 + 64)]
}

// PSHUFLW — Shuffle Packed Low Words
// High qword copied unchanged from src. Low qword: 4 words selected
// from src's low qword by imm8. No flags affected.
val select_low_word : (xmmword, bits(2)) -> word
function select_low_word(v, sel) = {
  let idx : range(0, 3) = unsigned(sel);
  v[(idx * 16 + 15) .. (idx * 16)]
}

// PSIGNB/PSIGNW/PSIGND — Packed Sign (SSSE3)
// For each lane: if src < 0, negate dst; if src == 0, zero; if src > 0, keep dst.
// No flags affected.
// Branchless: neg_mask selects negation, nonzero mask zeros when b==0.
val psign8 : (byte, byte) -> byte
function psign8(a, b) = {
  let neg_mask : byte = sign_extend(b[7..7]);
  let borrow : bits(9) = (0b0 @ b) - 0b000000001;
  let nonzero : byte = sign_extend(~(borrow[8..8]));
  ((a ^ neg_mask) - neg_mask) & nonzero
}

val psign16 : (word, word) -> word
function psign16(a, b) = {
  let neg_mask : word = sign_extend(b[15..15]);
  let borrow : bits(17) = (0b0 @ b) - zero_extend(0b1);
  let nonzero : word = sign_extend(~(borrow[16..16]));
  ((a ^ neg_mask) - neg_mask) & nonzero
}

val psign32 : (dword, dword) -> dword
function psign32(a, b) = {
  let neg_mask : dword = sign_extend(b[31..31]);
  let borrow : bits(33) = (0b0 @ b) - zero_extend(0b1);
  let nonzero : dword = sign_extend(~(borrow[32..32]));
  ((a ^ neg_mask) - neg_mask) & nonzero
}

// PSLLW/PSLLD/PSLLQ — Shift Packed Data Left Logical
// PSRLW/PSRLD/PSRLQ — Shift Packed Data Right Logical
// PSRAW/PSRAD — Shift Packed Data Right Arithmetic
// Shift count from imm8 or XMM. No flags affected.
val sll16 : (word, int) -> word
function sll16(v, count) = { assert(count >= 0); v << count }

val sll32 : (dword, int) -> dword
function sll32(v, count) = { assert(count >= 0); v << count }

val sll64 : (qword, int) -> qword
function sll64(v, count) = { assert(count >= 0); v << count }

val srl16 : (word, int) -> word
function srl16(v, count) = { assert(count >= 0); v >> count }

val srl32 : (dword, int) -> dword
function srl32(v, count) = { assert(count >= 0); v >> count }

val srl64 : (qword, int) -> qword
function srl64(v, count) = { assert(count >= 0); v >> count }

val sra16 : (word, int) -> word
function sra16(v, count) = { assert(count >= 0); sail_arith_shiftright(v, count) }

val sra32 : (dword, int) -> dword
function sra32(v, count) = { assert(count >= 0); sail_arith_shiftright(v, count) }

// PSUBSB/PSUBSW — Subtract Packed Signed Integers with Signed Saturation
// PSUBUSB/PSUBUSW — Subtract Packed Unsigned Integers with Unsigned Saturation
// No flags affected.
// Branchless: detect overflow/underflow via sign bits of wide difference.
val sat_sub_s8 : (byte, byte) -> byte
function sat_sub_s8(a, b) = {
  let wide : bits(9) = sign_extend(a) - sign_extend(b);
  let ov : bits(1) = ~(wide[8..8]) & wide[7..7];
  let uf : bits(1) = wide[8..8] & ~(wide[7..7]);
  let ov_mask : byte = sign_extend(ov);
  let uf_mask : byte = sign_extend(uf);
  (0x7F & ov_mask) | (0x80 & uf_mask) | (wide[7..0] & ~(ov_mask) & ~(uf_mask))
}

val sat_sub_s16 : (word, word) -> word
function sat_sub_s16(a, b) = {
  let wide : bits(17) = sign_extend(a) - sign_extend(b);
  let ov : bits(1) = ~(wide[16..16]) & wide[15..15];
  let uf : bits(1) = wide[16..16] & ~(wide[15..15]);
  let ov_mask : word = sign_extend(ov);
  let uf_mask : word = sign_extend(uf);
  (0x7FFF & ov_mask) | (0x8000 & uf_mask) | (wide[15..0] & ~(ov_mask) & ~(uf_mask))
}

// Branchless: borrow bit of wide difference → mask to zero.
val sat_sub_u8 : (byte, byte) -> byte
function sat_sub_u8(a, b) = {
  let wide : bits(9) = (0b0 @ a) - (0b0 @ b);
  let mask : byte = sign_extend(~(wide[8..8]));
  wide[7..0] & mask
}

val sat_sub_u16 : (word, word) -> word
function sat_sub_u16(a, b) = {
  let wide : bits(17) = (0b0 @ a) - (0b0 @ b);
  let mask : word = sign_extend(~(wide[16..16]));
  wide[15..0] & mask
}

val sat_sub_u32 : (dword, dword) -> dword
function sat_sub_u32(a, b) = {
  let wide : bits(33) = (0b0 @ a) - (0b0 @ b);
  let mask : dword = sign_extend(~(wide[32..32]));
  wide[31..0] & mask
}

// Unsigned min/max expressed via sat_sub to avoid an Isla symbolic execution
// bug where extract(N,N) is incorrectly distributed over bvsub when the
// (N+1)-bit intermediate has only one reference.
//
// min_u(a, b) = a - sat_sub_u(a, b):
//   if a >= b: a - (a - b) = b = min(a, b)
//   if a <  b: a - 0       = a = min(a, b)
//
// max_u(a, b) = a + sat_sub_u(b, a):
//   if a >= b: a + 0       = a = max(a, b)
//   if a <  b: a + (b - a) = b = max(a, b)

// PMINUB/PMINUW/PMINUD — Packed Minimum Unsigned Integers
val min_u8 : (byte, byte) -> byte
function min_u8(a, b) = a - sat_sub_u8(a, b)

val min_u16 : (word, word) -> word
function min_u16(a, b) = a - sat_sub_u16(a, b)

val min_u32 : (dword, dword) -> dword
function min_u32(a, b) = a - sat_sub_u32(a, b)

// PMAXUB/PMAXUW/PMAXUD — Packed Maximum Unsigned Integers
val max_u8 : (byte, byte) -> byte
function max_u8(a, b) = a + sat_sub_u8(b, a)

val max_u16 : (word, word) -> word
function max_u16(a, b) = a + sat_sub_u16(b, a)

val max_u32 : (dword, dword) -> dword
function max_u32(a, b) = a + sat_sub_u32(b, a)

// Signed min/max use XOR with sign bit to convert to unsigned comparison.

// PMINSB/PMINSW/PMINSD — Packed Minimum Signed Integers
val min_s8 : (byte, byte) -> byte
function min_s8(a, b) = min_u8(a ^ 0x80, b ^ 0x80) ^ 0x80

val min_s16 : (word, word) -> word
function min_s16(a, b) = min_u16(a ^ 0x8000, b ^ 0x8000) ^ 0x8000

val min_s32 : (dword, dword) -> dword
function min_s32(a, b) = min_u32(a ^ 0x80000000, b ^ 0x80000000) ^ 0x80000000

// PMAXSB/PMAXSW/PMAXSD — Packed Maximum Signed Integers
val max_s8 : (byte, byte) -> byte
function max_s8(a, b) = max_u8(a ^ 0x80, b ^ 0x80) ^ 0x80

val max_s16 : (word, word) -> word
function max_s16(a, b) = max_u16(a ^ 0x8000, b ^ 0x8000) ^ 0x8000

val max_s32 : (dword, dword) -> dword
function max_s32(a, b) = max_u32(a ^ 0x80000000, b ^ 0x80000000) ^ 0x80000000

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

// MPSADBW — Multiple Sum of Absolute Differences (SSE4.1)
// Complex operation modeled as external. No flags affected.
val __mpsadbw : (xmmword, xmmword, byte) -> xmmword

// MASKMOVDQU -- Store Selected Bytes of Double Quadword
//
// Selectively writes bytes from the source XMM register to memory at
// DS:DI/EDI/RDI. Each byte in the mask XMM register controls whether
// the corresponding byte is written (high bit = 1 means write).
// No flags affected.
val __maskmovdqu : (xmmword, xmmword, qword) -> unit

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

// External GFNI primitives
val __gf2p8mulb : (xmmword, xmmword) -> xmmword
val __gf2p8affineqb : (xmmword, xmmword, byte) -> xmmword
val __gf2p8affineinvqb : (xmmword, xmmword, byte) -> xmmword

// External SHA primitives
val __sha1rnds4 : (xmmword, xmmword, byte) -> xmmword
val __sha1nexte : (xmmword, xmmword) -> xmmword
val __sha1msg1 : (xmmword, xmmword) -> xmmword
val __sha1msg2 : (xmmword, xmmword) -> xmmword
val __sha256rnds2 : (xmmword, xmmword, xmmword) -> xmmword
val __sha256msg1 : (xmmword, xmmword) -> xmmword
val __sha256msg2 : (xmmword, xmmword) -> xmmword

// PCLMULQDQ — Carry-Less Multiplication Quadword
//
// Performs carry-less (polynomial) multiplication of two 64-bit values
// selected from src and dst by imm8. The 128-bit result is stored in dst.
// imm8[0] selects which qword of dst, imm8[4] selects which qword of src.
// No flags affected.
//
// The carry-less multiply operation is complex; modeled as external.
val __pclmulqdq : (qword, qword) -> xmmword

val dispatch_2byte_sse_int : (range(0, 255), Prefixes) -> unit
function dispatch_2byte_sse_int(op, pfx) = {
  match op {
    // 0F 60-6B: PUNPCK*/PACKSSWB/PCMPGT*/PUNPCK*/PACKSSDW/PCMPEQ*
    op if 96 <= op & op <= 107 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(addr) => mem_read128(addr),
        };
        let sub_op : range(0, 15) = op - 96;
        match sub_op {
          // PUNPCKLBW xmm1, xmm2/m128
          0 => {
            let d : xmmword = read_xmm(xreg);
            let s : xmmword = src_xmm;
            let result : xmmword =
              s[63..56] @ d[63..56] @
              s[55..48] @ d[55..48] @
              s[47..40] @ d[47..40] @
              s[39..32] @ d[39..32] @
              s[31..24] @ d[31..24] @
              s[23..16] @ d[23..16] @
              s[15..8]  @ d[15..8]  @
              s[7..0]   @ d[7..0];
            write_xmm_legacy(xreg, result)
          },
          // PUNPCKLWD xmm1, xmm2/m128
          1 => {
            let d : xmmword = read_xmm(xreg);
            let s : xmmword = src_xmm;
            let result : xmmword =
              s[63..48] @ d[63..48] @
              s[47..32] @ d[47..32] @
              s[31..16] @ d[31..16] @
              s[15..0]  @ d[15..0];
            write_xmm_legacy(xreg, result)
          },
          // PUNPCKLDQ xmm1, xmm2/m128
          2 => {
            let d : xmmword = read_xmm(xreg);
            let s : xmmword = src_xmm;
            let result : xmmword =
              s[63..32] @ d[63..32] @
              s[31..0]  @ d[31..0];
            write_xmm_legacy(xreg, result)
          },
          // PACKSSWB xmm1, xmm2/m128
          3 => {
            let d : xmmword = read_xmm(xreg);
            let s : xmmword = src_xmm;
            let r : xmmword =
              sat_s16_to_s8(s[127..112]) @ sat_s16_to_s8(s[111..96]) @
              sat_s16_to_s8(s[95..80])   @ sat_s16_to_s8(s[79..64]) @
              sat_s16_to_s8(s[63..48])   @ sat_s16_to_s8(s[47..32]) @
              sat_s16_to_s8(s[31..16])   @ sat_s16_to_s8(s[15..0]) @
              sat_s16_to_s8(d[127..112]) @ sat_s16_to_s8(d[111..96]) @
              sat_s16_to_s8(d[95..80])   @ sat_s16_to_s8(d[79..64]) @
              sat_s16_to_s8(d[63..48])   @ sat_s16_to_s8(d[47..32]) @
              sat_s16_to_s8(d[31..16])   @ sat_s16_to_s8(d[15..0]);
            write_xmm_legacy(xreg, r)
          },
          // PCMPGTB xmm1, xmm2/m128
          4 => {
            let a : xmmword = read_xmm(xreg);
            let b : xmmword = src_xmm;
            let r : xmmword =
              cmp_gt8(a[127..120], b[127..120]) @ cmp_gt8(a[119..112], b[119..112]) @
              cmp_gt8(a[111..104], b[111..104]) @ cmp_gt8(a[103..96], b[103..96]) @
              cmp_gt8(a[95..88], b[95..88]) @ cmp_gt8(a[87..80], b[87..80]) @
              cmp_gt8(a[79..72], b[79..72]) @ cmp_gt8(a[71..64], b[71..64]) @
              cmp_gt8(a[63..56], b[63..56]) @ cmp_gt8(a[55..48], b[55..48]) @
              cmp_gt8(a[47..40], b[47..40]) @ cmp_gt8(a[39..32], b[39..32]) @
              cmp_gt8(a[31..24], b[31..24]) @ cmp_gt8(a[23..16], b[23..16]) @
              cmp_gt8(a[15..8], b[15..8]) @ cmp_gt8(a[7..0], b[7..0]);
            write_xmm_legacy(xreg, r)
          },
          // PCMPGTW xmm1, xmm2/m128
          5 => {
            let a : xmmword = read_xmm(xreg);
            let b : xmmword = src_xmm;
            let r : xmmword =
              cmp_gt16(a[127..112], b[127..112]) @ cmp_gt16(a[111..96], b[111..96]) @
              cmp_gt16(a[95..80], b[95..80]) @ cmp_gt16(a[79..64], b[79..64]) @
              cmp_gt16(a[63..48], b[63..48]) @ cmp_gt16(a[47..32], b[47..32]) @
              cmp_gt16(a[31..16], b[31..16]) @ cmp_gt16(a[15..0], b[15..0]);
            write_xmm_legacy(xreg, r)
          },
          // PCMPGTD xmm1, xmm2/m128
          6 => {
            let a : xmmword = read_xmm(xreg);
            let b : xmmword = src_xmm;
            let r : xmmword =
              cmp_gt32(a[127..96], b[127..96]) @
              cmp_gt32(a[95..64], b[95..64]) @
              cmp_gt32(a[63..32], b[63..32]) @
              cmp_gt32(a[31..0], b[31..0]);
            write_xmm_legacy(xreg, r)
          },
          // PACKUSWB xmm1, xmm2/m128
          7 => {
            let d : xmmword = read_xmm(xreg);
            let s : xmmword = src_xmm;
            let r : xmmword =
              sat_s16_to_u8(s[127..112]) @ sat_s16_to_u8(s[111..96]) @
              sat_s16_to_u8(s[95..80])   @ sat_s16_to_u8(s[79..64]) @
              sat_s16_to_u8(s[63..48])   @ sat_s16_to_u8(s[47..32]) @
              sat_s16_to_u8(s[31..16])   @ sat_s16_to_u8(s[15..0]) @
              sat_s16_to_u8(d[127..112]) @ sat_s16_to_u8(d[111..96]) @
              sat_s16_to_u8(d[95..80])   @ sat_s16_to_u8(d[79..64]) @
              sat_s16_to_u8(d[63..48])   @ sat_s16_to_u8(d[47..32]) @
              sat_s16_to_u8(d[31..16])   @ sat_s16_to_u8(d[15..0]);
            write_xmm_legacy(xreg, r)
          },
          // PUNPCKHBW xmm1, xmm2/m128
          8 => {
            let d : xmmword = read_xmm(xreg);
            let s : xmmword = src_xmm;
            let result : xmmword =
              s[127..120] @ d[127..120] @
              s[119..112] @ d[119..112] @
              s[111..104] @ d[111..104] @
              s[103..96]  @ d[103..96]  @
              s[95..88]   @ d[95..88]   @
              s[87..80]   @ d[87..80]   @
              s[79..72]   @ d[79..72]   @
              s[71..64]   @ d[71..64];
            write_xmm_legacy(xreg, result)
          },
          // PUNPCKHWD xmm1, xmm2/m128
          9 => {
            let d : xmmword = read_xmm(xreg);
            let s : xmmword = src_xmm;
            let result : xmmword =
              s[127..112] @ d[127..112] @
              s[111..96]  @ d[111..96]  @
              s[95..80]   @ d[95..80]   @
              s[79..64]   @ d[79..64];
            write_xmm_legacy(xreg, result)
          },
          // PUNPCKHDQ xmm1, xmm2/m128
          10 => {
            let d : xmmword = read_xmm(xreg);
            let s : xmmword = src_xmm;
            let result : xmmword =
              s[127..96] @ d[127..96] @
              s[95..64]  @ d[95..64];
            write_xmm_legacy(xreg, result)
          },
          // PACKSSDW xmm1, xmm2/m128
          11 => {
            let d : xmmword = read_xmm(xreg);
            let s : xmmword = src_xmm;
            let r : xmmword =
              sat_s32_to_s16(s[127..96]) @ sat_s32_to_s16(s[95..64]) @
              sat_s32_to_s16(s[63..32])  @ sat_s32_to_s16(s[31..0]) @
              sat_s32_to_s16(d[127..96]) @ sat_s32_to_s16(d[95..64]) @
              sat_s32_to_s16(d[63..32])  @ sat_s32_to_s16(d[31..0]);
            write_xmm_legacy(xreg, r)
          },
          _ => raise_UD(),
        }
      }
    },

    // 0F 6C: PUNPCKLQDQ (SSE2 only, no MMX form)
    108 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then raise_UD();
      let modrm = fetch_byte();
      let xreg = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src_xmm : xmmword = match rm {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
        RM_mem(addr) => mem_read128(addr),
      };
      let d : xmmword = read_xmm(xreg);
      let s : xmmword = src_xmm;
      write_xmm_legacy(xreg, s[63..0] @ d[63..0])
    },

    // 0F 6D: PUNPCKHQDQ (SSE2 only, no MMX form)
    109 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then raise_UD();
      let modrm = fetch_byte();
      let xreg = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src_xmm : xmmword = match rm {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
        RM_mem(addr) => mem_read128(addr),
      };
      let d : xmmword = read_xmm(xreg);
      let s : xmmword = src_xmm;
      write_xmm_legacy(xreg, s[127..64] @ d[127..64])
    },

    // 0F 6E: MOVD/MOVQ xmm, r/m32 (or r/m64 with REX.W)
    //        MOVD/MOVQ mm, r/m32 (or r/m64 with REX.W) when no prefix
    110 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        if pfx.rex_w then {
          let v : qword = match rm {
            RM_reg(idx) => read_gpr64(idx),
            RM_mem(addr) => mem_read64(addr),
          };
          write_xmm_legacy(xreg, zero_extend(v))
        } else {
          let v : dword = match rm {
            RM_reg(idx) => read_gpr32(idx),
            RM_mem(addr) => mem_read32(addr),
          };
          write_xmm_legacy(xreg, zero_extend(v))
        }
      }
    },

    // 0F 6F: MOVDQA/MOVDQU xmm, xmm/m128 / MOVQ mm, mm/m64 (no prefix)
    111 => {
      let mp = get_mandatory_prefix(pfx);
      if mp == MP_NONE then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        match rm {
          RM_reg(_) => {
            match mp {
              MP_66 => exec_movdqa(xreg, read_xmm(modrm_xmm_rm(modrm, pfx))),
              MP_F3 => exec_movdqu(xreg, read_xmm(modrm_xmm_rm(modrm, pfx))),
              _     => raise_UD(),
            }
          },
          RM_mem(addr) => write_xmm_legacy(xreg, mem_read128(addr)),
        }
      }
    },

    // 0F 70: PSHUFD/PSHUFHW/PSHUFLW / PSHUFW (no prefix)
    112 => {
      let mp = get_mandatory_prefix(pfx);
      if mp == MP_NONE then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(addr) => mem_read128(addr),
        };
        let imm = fetch_byte();
        match mp {
          // PSHUFD xmm1, xmm2/m128, imm8
          MP_66 => {
            let s : xmmword = src_xmm;
            let sel0 : range(0, 3) = unsigned(imm[1..0]);
            let sel1 : range(0, 3) = unsigned(imm[3..2]);
            let sel2 : range(0, 3) = unsigned(imm[5..4]);
            let sel3 : range(0, 3) = unsigned(imm[7..6]);
            let d0 : dword = s[(sel0 * 32 + 31) .. (sel0 * 32)];
            let d1 : dword = s[(sel1 * 32 + 31) .. (sel1 * 32)];
            let d2 : dword = s[(sel2 * 32 + 31) .. (sel2 * 32)];
            let d3 : dword = s[(sel3 * 32 + 31) .. (sel3 * 32)];
            write_xmm_legacy(xreg, d3 @ d2 @ d1 @ d0)
          },
          // PSHUFHW xmm1, xmm2/m128, imm8
          MP_F3 => {
            let s : xmmword = src_xmm;
            let low : qword = s[63..0];
            let w0 : word = select_high_word(s, imm[1..0]);
            let w1 : word = select_high_word(s, imm[3..2]);
            let w2 : word = select_high_word(s, imm[5..4]);
            let w3 : word = select_high_word(s, imm[7..6]);
            write_xmm_legacy(xreg, w3 @ w2 @ w1 @ w0 @ low)
          },
          // PSHUFLW xmm1, xmm2/m128, imm8
          MP_F2 => {
            let s : xmmword = src_xmm;
            let high : qword = s[127..64];
            let w0 : word = select_low_word(s, imm[1..0]);
            let w1 : word = select_low_word(s, imm[3..2]);
            let w2 : word = select_low_word(s, imm[5..4]);
            let w3 : word = select_low_word(s, imm[7..6]);
            write_xmm_legacy(xreg, high @ w3 @ w2 @ w1 @ w0)
          },
          _     => raise_UD(),
        }
      }
    },

    // 0F 71: Group 12 — PSRLW/PSRAW/PSLLW imm8 (66 or no prefix)
    113 => {
      let mp = get_mandatory_prefix(pfx);
      if mp == MP_NONE then {
        dispatch_mmx(op, pfx)
      } else {
        if mp != MP_66 then raise_UD();
        let modrm = fetch_byte();
        let reg_field : range(0, 7) = unsigned(modrm[5..3]);
        let _ = decode_rm(modrm, pfx);
        let xreg = modrm_xmm_rm(modrm, pfx);
        let imm = fetch_byte();
        match reg_field {
          // PSRLW xmm1, imm8
          2 => {
            let c : int = unsigned(imm);
            let a : xmmword = read_xmm(xreg);
            let r : xmmword =
              srl16(a[127..112], c) @ srl16(a[111..96], c) @
              srl16(a[95..80], c) @ srl16(a[79..64], c) @
              srl16(a[63..48], c) @ srl16(a[47..32], c) @
              srl16(a[31..16], c) @ srl16(a[15..0], c);
            write_xmm_legacy(xreg, r)
          },
          // PSRAW xmm1, imm8
          4 => {
            let c : int = unsigned(imm);
            let a : xmmword = read_xmm(xreg);
            let r : xmmword =
              sra16(a[127..112], c) @ sra16(a[111..96], c) @
              sra16(a[95..80], c) @ sra16(a[79..64], c) @
              sra16(a[63..48], c) @ sra16(a[47..32], c) @
              sra16(a[31..16], c) @ sra16(a[15..0], c);
            write_xmm_legacy(xreg, r)
          },
          // PSLLW xmm1, imm8
          6 => {
            let c : int = unsigned(imm);
            let a : xmmword = read_xmm(xreg);
            let r : xmmword =
              sll16(a[127..112], c) @ sll16(a[111..96], c) @
              sll16(a[95..80], c) @ sll16(a[79..64], c) @
              sll16(a[63..48], c) @ sll16(a[47..32], c) @
              sll16(a[31..16], c) @ sll16(a[15..0], c);
            write_xmm_legacy(xreg, r)
          },
          _ => raise_UD(),
        }
      }
    },

    // 0F 72: Group 13 — PSRLD/PSRAD/PSLLD imm8 (66 or no prefix)
    114 => {
      let mp = get_mandatory_prefix(pfx);
      if mp == MP_NONE then {
        dispatch_mmx(op, pfx)
      } else {
        if mp != MP_66 then raise_UD();
        let modrm = fetch_byte();
        let reg_field : range(0, 7) = unsigned(modrm[5..3]);
        let _ = decode_rm(modrm, pfx);
        let xreg = modrm_xmm_rm(modrm, pfx);
        let imm = fetch_byte();
        match reg_field {
          // PSRLD xmm1, imm8
          2 => {
            let c : int = unsigned(imm);
            let a : xmmword = read_xmm(xreg);
            let r : xmmword =
              srl32(a[127..96], c) @ srl32(a[95..64], c) @
              srl32(a[63..32], c) @ srl32(a[31..0], c);
            write_xmm_legacy(xreg, r)
          },
          // PSRAD xmm1, imm8
          4 => {
            let c : int = unsigned(imm);
            let a : xmmword = read_xmm(xreg);
            let r : xmmword =
              sra32(a[127..96], c) @ sra32(a[95..64], c) @
              sra32(a[63..32], c) @ sra32(a[31..0], c);
            write_xmm_legacy(xreg, r)
          },
          // PSLLD xmm1, imm8
          6 => {
            let c : int = unsigned(imm);
            let a : xmmword = read_xmm(xreg);
            let r : xmmword =
              sll32(a[127..96], c) @ sll32(a[95..64], c) @
              sll32(a[63..32], c) @ sll32(a[31..0], c);
            write_xmm_legacy(xreg, r)
          },
          _ => raise_UD(),
        }
      }
    },

    // 0F 73: Group 14 — PSRLQ/PSRLDQ/PSLLQ/PSLLDQ imm8 (66 or no prefix)
    115 => {
      let mp = get_mandatory_prefix(pfx);
      if mp == MP_NONE then {
        dispatch_mmx(op, pfx)
      } else {
        if mp != MP_66 then raise_UD();
        let modrm = fetch_byte();
        let reg_field : range(0, 7) = unsigned(modrm[5..3]);
        let _ = decode_rm(modrm, pfx);
        let xreg = modrm_xmm_rm(modrm, pfx);
        let imm = fetch_byte();
        match reg_field {
          // PSRLQ xmm1, imm8
          2 => {
            let c : int = unsigned(imm);
            let a : xmmword = read_xmm(xreg);
            let r : xmmword = srl64(a[127..64], c) @ srl64(a[63..0], c);
            write_xmm_legacy(xreg, r)
          },
          // PSRLDQ xmm1, imm8
          3 => {
            let c : range(0, 255) = unsigned(imm);
            let a : xmmword = read_xmm(xreg);
            write_xmm_legacy(xreg, a >> (c * 8))
          },
          // PSLLQ xmm1, imm8
          6 => {
            let c : int = unsigned(imm);
            let a : xmmword = read_xmm(xreg);
            let r : xmmword = sll64(a[127..64], c) @ sll64(a[63..0], c);
            write_xmm_legacy(xreg, r)
          },
          // PSLLDQ xmm1, imm8
          7 => {
            let c : range(0, 255) = unsigned(imm);
            let a : xmmword = read_xmm(xreg);
            write_xmm_legacy(xreg, a << (c * 8))
          },
          _ => raise_UD(),
        }
      }
    },

    // 0F 74-76: PCMPEQB/PCMPEQW/PCMPEQD (66 prefix)
    op if 116 <= op & op <= 118 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(addr) => mem_read128(addr),
        };
        match op {
          // PCMPEQB xmm1, xmm2/m128
          116 => {
            let a : xmmword = read_xmm(xreg);
            let b : xmmword = src_xmm;
            let r : xmmword =
              cmp_eq8(a[127..120], b[127..120]) @ cmp_eq8(a[119..112], b[119..112]) @
              cmp_eq8(a[111..104], b[111..104]) @ cmp_eq8(a[103..96], b[103..96]) @
              cmp_eq8(a[95..88], b[95..88]) @ cmp_eq8(a[87..80], b[87..80]) @
              cmp_eq8(a[79..72], b[79..72]) @ cmp_eq8(a[71..64], b[71..64]) @
              cmp_eq8(a[63..56], b[63..56]) @ cmp_eq8(a[55..48], b[55..48]) @
              cmp_eq8(a[47..40], b[47..40]) @ cmp_eq8(a[39..32], b[39..32]) @
              cmp_eq8(a[31..24], b[31..24]) @ cmp_eq8(a[23..16], b[23..16]) @
              cmp_eq8(a[15..8], b[15..8]) @ cmp_eq8(a[7..0], b[7..0]);
            write_xmm_legacy(xreg, r)
          },
          // PCMPEQW xmm1, xmm2/m128
          117 => {
            let a : xmmword = read_xmm(xreg);
            let b : xmmword = src_xmm;
            let r : xmmword =
              cmp_eq16(a[127..112], b[127..112]) @ cmp_eq16(a[111..96], b[111..96]) @
              cmp_eq16(a[95..80], b[95..80]) @ cmp_eq16(a[79..64], b[79..64]) @
              cmp_eq16(a[63..48], b[63..48]) @ cmp_eq16(a[47..32], b[47..32]) @
              cmp_eq16(a[31..16], b[31..16]) @ cmp_eq16(a[15..0], b[15..0]);
            write_xmm_legacy(xreg, r)
          },
          // PCMPEQD xmm1, xmm2/m128
          _   => {
            let a : xmmword = read_xmm(xreg);
            let b : xmmword = src_xmm;
            let r : xmmword =
              cmp_eq32(a[127..96], b[127..96]) @
              cmp_eq32(a[95..64], b[95..64]) @
              cmp_eq32(a[63..32], b[63..32]) @
              cmp_eq32(a[31..0], b[31..0]);
            write_xmm_legacy(xreg, r)
          },
        }
      }
    },

    // 0F 7E: MOVD/MOVQ r/m32, xmm (66) / MOVQ xmm,xmm/m64 (F3) / MOVD r/m32, mm (NP)
    126 => {
      let mp = get_mandatory_prefix(pfx);
      if mp == MP_NONE then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let rm = decode_rm(modrm, pfx);
        match mp {
          // MOVD/MOVQ r/m, xmm
          MP_66 => {
            let src_xmm = modrm_xmm_reg(modrm, pfx);
            let v = read_xmm(src_xmm);
            if pfx.rex_w then {
              match rm {
                RM_reg(idx) => write_gpr64(idx, v[63..0]),
                RM_mem(addr) => mem_write64(addr, v[63..0]),
              };
            } else {
              match rm {
                RM_reg(idx) => write_gpr32(idx, v[31..0]),
                RM_mem(addr) => mem_write32(addr, v[31..0]),
              };
            }
          },
          // MOVQ xmm1, xmm2/m64
          MP_F3 => {
            let xreg = modrm_xmm_reg(modrm, pfx);
            match rm {
              RM_reg(_) => {
                let src = read_xmm(modrm_xmm_rm(modrm, pfx));
                write_xmm_legacy(xreg, zero_extend(src[63..0]))
              },
              RM_mem(addr) => {
                let v : xmmword = zero_extend(mem_read64(addr));
                write_xmm(xreg, v)
              },
            }
          },
          _ => raise_UD(),
        }
      }
    },

    // 0F 7F: MOVDQA/MOVDQU xmm/m128, xmm / MOVQ mm/m64, mm (NP)
    127 => {
      let mp = get_mandatory_prefix(pfx);
      if mp == MP_NONE then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        match rm {
          RM_reg(_) => {
            let dst_xmm = modrm_xmm_rm(modrm, pfx);
            match mp {
              MP_66 => exec_movdqa(dst_xmm, read_xmm(xreg)),
              MP_F3 => exec_movdqu(dst_xmm, read_xmm(xreg)),
              _     => raise_UD(),
            }
          },
          RM_mem(addr) => {
            mem_write128(addr, read_xmm(xreg))
          },
        }
      }
    },

    // 0F D7: PMOVMSKB r, xmm (66 prefix)
    215 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let reg = modrm_reg(modrm, pfx);
        let _ = decode_rm(modrm, pfx);
        let src_xmm : xmmword = read_xmm(modrm_xmm_rm(modrm, pfx));
        let mask : word = src_xmm[127] @ src_xmm[119] @ src_xmm[111] @ src_xmm[103] @
                               src_xmm[95]  @ src_xmm[87]  @ src_xmm[79]  @ src_xmm[71] @
                               src_xmm[63]  @ src_xmm[55]  @ src_xmm[47]  @ src_xmm[39] @
                               src_xmm[31]  @ src_xmm[23]  @ src_xmm[15]  @ src_xmm[7];
        write_gpr32(reg, zero_extend(mask))
      }
    },

    // 0F DB: PAND xmm, xmm/m128 (66 prefix)
    219 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(addr) => mem_read128(addr),
        };
        let a : xmmword = read_xmm(xreg);
        let b : xmmword = src_xmm;
        write_xmm_legacy(xreg, a & b)
      }
    },

    // 0F DF: PANDN xmm, xmm/m128 (66 prefix)
    223 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(addr) => mem_read128(addr),
        };
        write_xmm_legacy(xreg, ~(read_xmm(xreg)) & src_xmm)
      }
    },

    // 0F E5: PMULHW xmm, xmm/m128 (66 prefix)
    229 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(addr) => mem_read128(addr),
        };
        let a : xmmword = read_xmm(xreg);
        let b : xmmword = src_xmm;
        let r : xmmword =
          mul_hi16s(a[127..112], b[127..112]) @ mul_hi16s(a[111..96], b[111..96]) @
          mul_hi16s(a[95..80], b[95..80]) @ mul_hi16s(a[79..64], b[79..64]) @
          mul_hi16s(a[63..48], b[63..48]) @ mul_hi16s(a[47..32], b[47..32]) @
          mul_hi16s(a[31..16], b[31..16]) @ mul_hi16s(a[15..0], b[15..0]);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F EB: POR xmm, xmm/m128 (66 prefix)
    235 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(addr) => mem_read128(addr),
        };
        write_xmm_legacy(xreg, read_xmm(xreg) | src_xmm)
      }
    },

    // 0F EF: PXOR xmm, xmm/m128 (66 prefix)
    239 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(addr) => mem_read128(addr),
        };
        let a : xmmword = read_xmm(xreg);
        let b : xmmword = src_xmm;
        write_xmm_legacy(xreg, a ^ b)
      }
    },

    // 0F D4: PADDQ (66 prefix)
    212 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(addr) => mem_read128(addr),
        };
        let a : xmmword = read_xmm(xreg);
        let b : xmmword = src_xmm;
        let r : xmmword = (a[127..64] + b[127..64]) @ (a[63..0] + b[63..0]);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F F4: PMULUDQ (66 prefix)
    244 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(addr) => mem_read128(addr),
        };
        let a : xmmword = read_xmm(xreg);
        let b : xmmword = src_xmm;
        let hi : qword = to_bits_truncate(unsigned(a[95..64]) * unsigned(b[95..64]));
        let lo : qword = to_bits_truncate(unsigned(a[31..0]) * unsigned(b[31..0]));
        let r : xmmword = hi @ lo;
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F F8: PSUBB (66 prefix)
    248 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(addr) => mem_read128(addr),
        };
        let a : xmmword = read_xmm(xreg);
        let b : xmmword = src_xmm;
        let r : xmmword =
          (a[127..120] - b[127..120]) @ (a[119..112] - b[119..112]) @
          (a[111..104] - b[111..104]) @ (a[103..96] - b[103..96]) @
          (a[95..88] - b[95..88]) @ (a[87..80] - b[87..80]) @
          (a[79..72] - b[79..72]) @ (a[71..64] - b[71..64]) @
          (a[63..56] - b[63..56]) @ (a[55..48] - b[55..48]) @
          (a[47..40] - b[47..40]) @ (a[39..32] - b[39..32]) @
          (a[31..24] - b[31..24]) @ (a[23..16] - b[23..16]) @
          (a[15..8] - b[15..8]) @ (a[7..0] - b[7..0]);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F F9: PSUBW (66 prefix)
    249 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(addr) => mem_read128(addr),
        };
        let a : xmmword = read_xmm(xreg);
        let b : xmmword = src_xmm;
        let r : xmmword = (a[127..112] - b[127..112]) @
                             (a[111..96] - b[111..96]) @
                             (a[95..80] - b[95..80]) @
                             (a[79..64] - b[79..64]) @
                             (a[63..48] - b[63..48]) @
                             (a[47..32] - b[47..32]) @
                             (a[31..16] - b[31..16]) @
                             (a[15..0] - b[15..0]);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F FA: PSUBD (66 prefix)
    250 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(addr) => mem_read128(addr),
        };
        let a : xmmword = read_xmm(xreg);
        let b : xmmword = src_xmm;
        let r : xmmword = (a[127..96] - b[127..96]) @
                             (a[95..64] - b[95..64]) @
                             (a[63..32] - b[63..32]) @
                             (a[31..0] - b[31..0]);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F FB: PSUBQ (66 prefix)
    251 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(addr) => mem_read128(addr),
        };
        let a : xmmword = read_xmm(xreg);
        let b : xmmword = src_xmm;
        let r : xmmword = (a[127..64] - b[127..64]) @ (a[63..0] - b[63..0]);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F FC: PADDB (66 prefix)
    252 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(addr) => mem_read128(addr),
        };
        let a : xmmword = read_xmm(xreg);
        let b : xmmword = src_xmm;
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
        write_xmm_legacy(xreg, result)
      }
    },

    // 0F FD: PADDW (66 prefix)
    253 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(addr) => mem_read128(addr),
        };
        let a : xmmword = read_xmm(xreg);
        let b : xmmword = src_xmm;
        let r : xmmword = (a[127..112] + b[127..112]) @
                             (a[111..96] + b[111..96]) @
                             (a[95..80] + b[95..80]) @
                             (a[79..64] + b[79..64]) @
                             (a[63..48] + b[63..48]) @
                             (a[47..32] + b[47..32]) @
                             (a[31..16] + b[31..16]) @
                             (a[15..0] + b[15..0]);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F FE: PADDD (66 prefix)
    254 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(addr) => mem_read128(addr),
        };
        let a : xmmword = read_xmm(xreg);
        let b : xmmword = src_xmm;
        let r : xmmword = (a[127..96] + b[127..96]) @
                             (a[95..64] + b[95..64]) @
                             (a[63..32] + b[63..32]) @
                             (a[31..0] + b[31..0]);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F E0: PAVGB (66 prefix)
    224 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(addr) => mem_read128(addr),
        };
        let a : xmmword = read_xmm(xreg);
        let b : xmmword = src_xmm;
        let r : xmmword =
          avg8(a[127..120], b[127..120]) @ avg8(a[119..112], b[119..112]) @
          avg8(a[111..104], b[111..104]) @ avg8(a[103..96], b[103..96]) @
          avg8(a[95..88], b[95..88]) @ avg8(a[87..80], b[87..80]) @
          avg8(a[79..72], b[79..72]) @ avg8(a[71..64], b[71..64]) @
          avg8(a[63..56], b[63..56]) @ avg8(a[55..48], b[55..48]) @
          avg8(a[47..40], b[47..40]) @ avg8(a[39..32], b[39..32]) @
          avg8(a[31..24], b[31..24]) @ avg8(a[23..16], b[23..16]) @
          avg8(a[15..8], b[15..8]) @ avg8(a[7..0], b[7..0]);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F DA: PMINUB (66 prefix)
    218 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(addr) => mem_read128(addr),
        };
        let a : xmmword = read_xmm(xreg);
        let b : xmmword = src_xmm;
        let r : xmmword =
          min_u8(a[127..120], b[127..120]) @ min_u8(a[119..112], b[119..112]) @
          min_u8(a[111..104], b[111..104]) @ min_u8(a[103..96], b[103..96]) @
          min_u8(a[95..88], b[95..88]) @ min_u8(a[87..80], b[87..80]) @
          min_u8(a[79..72], b[79..72]) @ min_u8(a[71..64], b[71..64]) @
          min_u8(a[63..56], b[63..56]) @ min_u8(a[55..48], b[55..48]) @
          min_u8(a[47..40], b[47..40]) @ min_u8(a[39..32], b[39..32]) @
          min_u8(a[31..24], b[31..24]) @ min_u8(a[23..16], b[23..16]) @
          min_u8(a[15..8], b[15..8]) @ min_u8(a[7..0], b[7..0]);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F DE: PMAXUB (66 prefix)
    222 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(addr) => mem_read128(addr),
        };
        let a : xmmword = read_xmm(xreg);
        let b : xmmword = src_xmm;
        let r : xmmword =
          max_u8(a[127..120], b[127..120]) @ max_u8(a[119..112], b[119..112]) @
          max_u8(a[111..104], b[111..104]) @ max_u8(a[103..96], b[103..96]) @
          max_u8(a[95..88], b[95..88]) @ max_u8(a[87..80], b[87..80]) @
          max_u8(a[79..72], b[79..72]) @ max_u8(a[71..64], b[71..64]) @
          max_u8(a[63..56], b[63..56]) @ max_u8(a[55..48], b[55..48]) @
          max_u8(a[47..40], b[47..40]) @ max_u8(a[39..32], b[39..32]) @
          max_u8(a[31..24], b[31..24]) @ max_u8(a[23..16], b[23..16]) @
          max_u8(a[15..8], b[15..8]) @ max_u8(a[7..0], b[7..0]);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F F6: PSADBW (66 prefix)
    246 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(addr) => mem_read128(addr),
        };
        let a : xmmword = read_xmm(xreg);
        let b : xmmword = src_xmm;
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
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F E7: MOVNTDQ m128, xmm (66 prefix) / MOVNTQ m64, mm (no prefix)
    231 => {
      let mp = get_mandatory_prefix(pfx);
      if mp == MP_NONE then {
        dispatch_mmx(op, pfx)
      } else {
        if mp != MP_66 then raise_UD();
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        match rm {
          RM_mem(addr) => {
            mem_write128(addr, read_xmm(xreg))
          },
          RM_reg(_) => raise_UD(),
        }
      }
    },

    // 0F C4: PINSRW xmm, r32/m16, imm8 (66 prefix)
    196 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let v : word = match rm {
          RM_reg(idx) => read_gpr16(idx),
          RM_mem(addr) => mem_read16(addr),
        };
        let imm = fetch_byte();
        let v_0 : xmmword = read_xmm(xreg);
        let sel : range(0, 7) = unsigned(imm[2..0]);
        let r : xmmword = insert_word(v_0, v, sel);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F C5: PEXTRW r32, xmm, imm8 (66 prefix)
    197 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let reg = modrm_reg(modrm, pfx);
        let _ = decode_rm(modrm, pfx);
        let src_xmm : xmmword = read_xmm(modrm_xmm_rm(modrm, pfx));
        let imm = fetch_byte();
        let sel : range(0, 7) = unsigned(imm[2..0]);
        let word : word = match sel {
          0 => src_xmm[15..0],
          1 => src_xmm[31..16],
          2 => src_xmm[47..32],
          3 => src_xmm[63..48],
          4 => src_xmm[79..64],
          5 => src_xmm[95..80],
          6 => src_xmm[111..96],
          7 => src_xmm[127..112]
        };
        write_gpr32(reg, zero_extend(word))
      }
    },

    // 0F D1: PSRLW xmm, xmm/m128 (66 prefix)
    209 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, rm, pfx);
        let c : int = unsigned(src_xmm[63..0]);
        let a : xmmword = read_xmm(xreg);
        let r : xmmword =
          srl16(a[127..112], c) @ srl16(a[111..96], c) @
          srl16(a[95..80], c) @ srl16(a[79..64], c) @
          srl16(a[63..48], c) @ srl16(a[47..32], c) @
          srl16(a[31..16], c) @ srl16(a[15..0], c);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F D2: PSRLD xmm, xmm/m128 (66 prefix)
    210 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, rm, pfx);
        let c : int = unsigned(src_xmm[63..0]);
        let a : xmmword = read_xmm(xreg);
        let r : xmmword =
          srl32(a[127..96], c) @ srl32(a[95..64], c) @
          srl32(a[63..32], c) @ srl32(a[31..0], c);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F D3: PSRLQ xmm, xmm/m128 (66 prefix)
    211 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, rm, pfx);
        let c : int = unsigned(src_xmm[63..0]);
        let a : xmmword = read_xmm(xreg);
        let r : xmmword = srl64(a[127..64], c) @ srl64(a[63..0], c);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F D5: PMULLW (66 prefix)
    213 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, rm, pfx);
        let a : xmmword = read_xmm(xreg);
        let b : xmmword = src_xmm;
        let r : xmmword =
          mul_lo16(a[127..112], b[127..112]) @ mul_lo16(a[111..96], b[111..96]) @
          mul_lo16(a[95..80], b[95..80]) @ mul_lo16(a[79..64], b[79..64]) @
          mul_lo16(a[63..48], b[63..48]) @ mul_lo16(a[47..32], b[47..32]) @
          mul_lo16(a[31..16], b[31..16]) @ mul_lo16(a[15..0], b[15..0]);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F D6: MOVQ xmm1/m64, xmm2 (66 prefix)
    214 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let src_xmm = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let v : qword = read_xmm(src_xmm)[63..0];
        match rm {
          RM_reg(_) => {
            let dst = modrm_xmm_rm(modrm, pfx);
            write_xmm_legacy(dst, zero_extend(v))
          },
          RM_mem(addr) => mem_write64(addr, v),
        }
      }
    },

    // 0F D8: PSUBUSB (66 prefix)
    216 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, rm, pfx);
        let a : xmmword = read_xmm(xreg);
        let b : xmmword = src_xmm;
        let r : xmmword =
          sat_sub_u8(a[127..120], b[127..120]) @ sat_sub_u8(a[119..112], b[119..112]) @
          sat_sub_u8(a[111..104], b[111..104]) @ sat_sub_u8(a[103..96], b[103..96]) @
          sat_sub_u8(a[95..88], b[95..88]) @ sat_sub_u8(a[87..80], b[87..80]) @
          sat_sub_u8(a[79..72], b[79..72]) @ sat_sub_u8(a[71..64], b[71..64]) @
          sat_sub_u8(a[63..56], b[63..56]) @ sat_sub_u8(a[55..48], b[55..48]) @
          sat_sub_u8(a[47..40], b[47..40]) @ sat_sub_u8(a[39..32], b[39..32]) @
          sat_sub_u8(a[31..24], b[31..24]) @ sat_sub_u8(a[23..16], b[23..16]) @
          sat_sub_u8(a[15..8], b[15..8]) @ sat_sub_u8(a[7..0], b[7..0]);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F D9: PSUBUSW (66 prefix)
    217 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, rm, pfx);
        let a : xmmword = read_xmm(xreg);
        let b : xmmword = src_xmm;
        let r : xmmword =
          sat_sub_u16(a[127..112], b[127..112]) @ sat_sub_u16(a[111..96], b[111..96]) @
          sat_sub_u16(a[95..80], b[95..80]) @ sat_sub_u16(a[79..64], b[79..64]) @
          sat_sub_u16(a[63..48], b[63..48]) @ sat_sub_u16(a[47..32], b[47..32]) @
          sat_sub_u16(a[31..16], b[31..16]) @ sat_sub_u16(a[15..0], b[15..0]);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F DC: PADDUSB (66 prefix)
    220 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, rm, pfx);
        let a : xmmword = read_xmm(xreg);
        let b : xmmword = src_xmm;
        let r : xmmword =
          sat_add_u8(a[127..120], b[127..120]) @ sat_add_u8(a[119..112], b[119..112]) @
          sat_add_u8(a[111..104], b[111..104]) @ sat_add_u8(a[103..96], b[103..96]) @
          sat_add_u8(a[95..88], b[95..88]) @ sat_add_u8(a[87..80], b[87..80]) @
          sat_add_u8(a[79..72], b[79..72]) @ sat_add_u8(a[71..64], b[71..64]) @
          sat_add_u8(a[63..56], b[63..56]) @ sat_add_u8(a[55..48], b[55..48]) @
          sat_add_u8(a[47..40], b[47..40]) @ sat_add_u8(a[39..32], b[39..32]) @
          sat_add_u8(a[31..24], b[31..24]) @ sat_add_u8(a[23..16], b[23..16]) @
          sat_add_u8(a[15..8], b[15..8]) @ sat_add_u8(a[7..0], b[7..0]);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F DD: PADDUSW (66 prefix)
    221 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, rm, pfx);
        let a : xmmword = read_xmm(xreg);
        let b : xmmword = src_xmm;
        let r : xmmword =
          sat_add_u16(a[127..112], b[127..112]) @ sat_add_u16(a[111..96], b[111..96]) @
          sat_add_u16(a[95..80], b[95..80]) @ sat_add_u16(a[79..64], b[79..64]) @
          sat_add_u16(a[63..48], b[63..48]) @ sat_add_u16(a[47..32], b[47..32]) @
          sat_add_u16(a[31..16], b[31..16]) @ sat_add_u16(a[15..0], b[15..0]);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F E1: PSRAW xmm, xmm/m128 (66 prefix)
    225 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, rm, pfx);
        let c : int = unsigned(src_xmm[63..0]);
        let a : xmmword = read_xmm(xreg);
        let r : xmmword =
          sra16(a[127..112], c) @ sra16(a[111..96], c) @
          sra16(a[95..80], c) @ sra16(a[79..64], c) @
          sra16(a[63..48], c) @ sra16(a[47..32], c) @
          sra16(a[31..16], c) @ sra16(a[15..0], c);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F E2: PSRAD xmm, xmm/m128 (66 prefix)
    226 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, rm, pfx);
        let c : int = unsigned(src_xmm[63..0]);
        let a : xmmword = read_xmm(xreg);
        let r : xmmword =
          sra32(a[127..96], c) @ sra32(a[95..64], c) @
          sra32(a[63..32], c) @ sra32(a[31..0], c);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F E3: PAVGW (66 prefix)
    227 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, rm, pfx);
        let a : xmmword = read_xmm(xreg);
        let b : xmmword = src_xmm;
        let r : xmmword =
          avg16(a[127..112], b[127..112]) @ avg16(a[111..96], b[111..96]) @
          avg16(a[95..80], b[95..80]) @ avg16(a[79..64], b[79..64]) @
          avg16(a[63..48], b[63..48]) @ avg16(a[47..32], b[47..32]) @
          avg16(a[31..16], b[31..16]) @ avg16(a[15..0], b[15..0]);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F E4: PMULHUW (66 prefix)
    228 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, rm, pfx);
        let a : xmmword = read_xmm(xreg);
        let b : xmmword = src_xmm;
        let r : xmmword =
          mul_hi16u(a[127..112], b[127..112]) @ mul_hi16u(a[111..96], b[111..96]) @
          mul_hi16u(a[95..80], b[95..80]) @ mul_hi16u(a[79..64], b[79..64]) @
          mul_hi16u(a[63..48], b[63..48]) @ mul_hi16u(a[47..32], b[47..32]) @
          mul_hi16u(a[31..16], b[31..16]) @ mul_hi16u(a[15..0], b[15..0]);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F E8: PSUBSB (66 prefix)
    232 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, rm, pfx);
        let a : xmmword = read_xmm(xreg);
        let b : xmmword = src_xmm;
        let r : xmmword =
          sat_sub_s8(a[127..120], b[127..120]) @ sat_sub_s8(a[119..112], b[119..112]) @
          sat_sub_s8(a[111..104], b[111..104]) @ sat_sub_s8(a[103..96], b[103..96]) @
          sat_sub_s8(a[95..88], b[95..88]) @ sat_sub_s8(a[87..80], b[87..80]) @
          sat_sub_s8(a[79..72], b[79..72]) @ sat_sub_s8(a[71..64], b[71..64]) @
          sat_sub_s8(a[63..56], b[63..56]) @ sat_sub_s8(a[55..48], b[55..48]) @
          sat_sub_s8(a[47..40], b[47..40]) @ sat_sub_s8(a[39..32], b[39..32]) @
          sat_sub_s8(a[31..24], b[31..24]) @ sat_sub_s8(a[23..16], b[23..16]) @
          sat_sub_s8(a[15..8], b[15..8]) @ sat_sub_s8(a[7..0], b[7..0]);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F E9: PSUBSW (66 prefix)
    233 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, rm, pfx);
        let a : xmmword = read_xmm(xreg);
        let b : xmmword = src_xmm;
        let r : xmmword =
          sat_sub_s16(a[127..112], b[127..112]) @ sat_sub_s16(a[111..96], b[111..96]) @
          sat_sub_s16(a[95..80], b[95..80]) @ sat_sub_s16(a[79..64], b[79..64]) @
          sat_sub_s16(a[63..48], b[63..48]) @ sat_sub_s16(a[47..32], b[47..32]) @
          sat_sub_s16(a[31..16], b[31..16]) @ sat_sub_s16(a[15..0], b[15..0]);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F EC: PADDSB (66 prefix)
    236 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, rm, pfx);
        let a : xmmword = read_xmm(xreg);
        let b : xmmword = src_xmm;
        let r : xmmword =
          sat_add_s8(a[127..120], b[127..120]) @ sat_add_s8(a[119..112], b[119..112]) @
          sat_add_s8(a[111..104], b[111..104]) @ sat_add_s8(a[103..96], b[103..96]) @
          sat_add_s8(a[95..88], b[95..88]) @ sat_add_s8(a[87..80], b[87..80]) @
          sat_add_s8(a[79..72], b[79..72]) @ sat_add_s8(a[71..64], b[71..64]) @
          sat_add_s8(a[63..56], b[63..56]) @ sat_add_s8(a[55..48], b[55..48]) @
          sat_add_s8(a[47..40], b[47..40]) @ sat_add_s8(a[39..32], b[39..32]) @
          sat_add_s8(a[31..24], b[31..24]) @ sat_add_s8(a[23..16], b[23..16]) @
          sat_add_s8(a[15..8], b[15..8]) @ sat_add_s8(a[7..0], b[7..0]);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F ED: PADDSW (66 prefix)
    237 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, rm, pfx);
        let a : xmmword = read_xmm(xreg);
        let b : xmmword = src_xmm;
        let r : xmmword =
          sat_add_s16(a[127..112], b[127..112]) @ sat_add_s16(a[111..96], b[111..96]) @
          sat_add_s16(a[95..80], b[95..80]) @ sat_add_s16(a[79..64], b[79..64]) @
          sat_add_s16(a[63..48], b[63..48]) @ sat_add_s16(a[47..32], b[47..32]) @
          sat_add_s16(a[31..16], b[31..16]) @ sat_add_s16(a[15..0], b[15..0]);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F F0: LDDQU xmm, m128 (F2 prefix)
    240 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_F2 then raise_UD();
      let modrm = fetch_byte();
      let xreg = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      match rm {
        RM_mem(addr) => {
          write_xmm(xreg, mem_read128(addr))
        },
        RM_reg(_) => raise_UD(),
      }
    },

    // 0F F1: PSLLW xmm, xmm/m128 (66 prefix)
    241 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, rm, pfx);
        let c : int = unsigned(src_xmm[63..0]);
        let a : xmmword = read_xmm(xreg);
        let r : xmmword =
          sll16(a[127..112], c) @ sll16(a[111..96], c) @
          sll16(a[95..80], c) @ sll16(a[79..64], c) @
          sll16(a[63..48], c) @ sll16(a[47..32], c) @
          sll16(a[31..16], c) @ sll16(a[15..0], c);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F F2: PSLLD xmm, xmm/m128 (66 prefix)
    242 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, rm, pfx);
        let c : int = unsigned(src_xmm[63..0]);
        let a : xmmword = read_xmm(xreg);
        let r : xmmword =
          sll32(a[127..96], c) @ sll32(a[95..64], c) @
          sll32(a[63..32], c) @ sll32(a[31..0], c);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F F3: PSLLQ xmm, xmm/m128 (66 prefix)
    243 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, rm, pfx);
        let c : int = unsigned(src_xmm[63..0]);
        let a : xmmword = read_xmm(xreg);
        let r : xmmword = sll64(a[127..64], c) @ sll64(a[63..0], c);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F F5: PMADDWD (66 prefix)
    245 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, rm, pfx);
        let a : xmmword = read_xmm(xreg);
        let b : xmmword = src_xmm;
        let d3 : dword = to_bits_truncate(signed(a[127..112]) * signed(b[127..112]) +
                                              signed(a[111..96]) * signed(b[111..96]));
        let d2 : dword = to_bits_truncate(signed(a[95..80]) * signed(b[95..80]) +
                                              signed(a[79..64]) * signed(b[79..64]));
        let d1 : dword = to_bits_truncate(signed(a[63..48]) * signed(b[63..48]) +
                                              signed(a[47..32]) * signed(b[47..32]));
        let d0 : dword = to_bits_truncate(signed(a[31..16]) * signed(b[31..16]) +
                                              signed(a[15..0]) * signed(b[15..0]));
        let r : xmmword = d3 @ d2 @ d1 @ d0;
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F F7: MASKMOVDQU xmm, xmm (66 prefix)
    247 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let _ = decode_rm(modrm, pfx);
        let src_xmm : xmmword = read_xmm(modrm_xmm_rm(modrm, pfx));
        let addr = read_gpr64(RDI);
        __maskmovdqu(read_xmm(xreg), src_xmm, addr)
      }
    },

    // 0F EE: PMAXSW (66 prefix)
    238 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, rm, pfx);
        let a : xmmword = read_xmm(xreg);
        let b : xmmword = src_xmm;
        let r : xmmword =
          max_s16(a[127..112], b[127..112]) @ max_s16(a[111..96], b[111..96]) @
          max_s16(a[95..80], b[95..80]) @ max_s16(a[79..64], b[79..64]) @
          max_s16(a[63..48], b[63..48]) @ max_s16(a[47..32], b[47..32]) @
          max_s16(a[31..16], b[31..16]) @ max_s16(a[15..0], b[15..0]);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F EA: PMINSW (66 prefix)
    234 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, rm, pfx);
        let a : xmmword = read_xmm(xreg);
        let b : xmmword = src_xmm;
        let r : xmmword =
          min_s16(a[127..112], b[127..112]) @ min_s16(a[111..96], b[111..96]) @
          min_s16(a[95..80], b[95..80]) @ min_s16(a[79..64], b[79..64]) @
          min_s16(a[63..48], b[63..48]) @ min_s16(a[47..32], b[47..32]) @
          min_s16(a[31..16], b[31..16]) @ min_s16(a[15..0], b[15..0]);
        write_xmm_legacy(xreg, r)
      }
    },
    _ => raise_UD(),
  }
}

// =========================================================================
// 3-Byte Opcode Map: SSE Integer Operations
// =========================================================================
val blend_byte : (byte, byte, bits(1)) -> byte
function blend_byte(a, b, sel) = { let m : byte = sign_extend(sel); (a & ~(m)) | (b & m) }

// 0F 38 xx — SSE integer operations (SSSE3, SSE4.1, SSE4.2, AES-NI)
val dispatch_3byte_38_sse_int : (byte, Prefixes) -> unit
function dispatch_3byte_38_sse_int(opcode, pfx) = {
  let op : range(0, 255) = unsigned(opcode);
  let mp = get_mandatory_prefix(pfx);
  if mp != MP_66 then raise_UD();
  let modrm = fetch_byte();
  let xreg = modrm_xmm_reg(modrm, pfx);
  let rm = decode_rm(modrm, pfx);
  let src_xmm : xmmword = decode_xmm_src(modrm, rm, pfx);
  match op {

    // SSSE3 — PSHUFB
    0  => {
      let d : xmmword = read_xmm(xreg);
      let s : xmmword = src_xmm;
      let r : xmmword =
        pshufb_byte(d, s[127..120]) @ pshufb_byte(d, s[119..112]) @
        pshufb_byte(d, s[111..104]) @ pshufb_byte(d, s[103..96]) @
        pshufb_byte(d, s[95..88])   @ pshufb_byte(d, s[87..80]) @
        pshufb_byte(d, s[79..72])   @ pshufb_byte(d, s[71..64]) @
        pshufb_byte(d, s[63..56])   @ pshufb_byte(d, s[55..48]) @
        pshufb_byte(d, s[47..40])   @ pshufb_byte(d, s[39..32]) @
        pshufb_byte(d, s[31..24])   @ pshufb_byte(d, s[23..16]) @
        pshufb_byte(d, s[15..8])    @ pshufb_byte(d, s[7..0]);
      write_xmm_legacy(xreg, r)
    },
    // PHADDW xmm1, xmm2/m128
    1  => {
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      let r : xmmword =
        (b[127..112] + b[111..96]) @ (b[95..80] + b[79..64]) @
        (b[63..48] + b[47..32]) @ (b[31..16] + b[15..0]) @
        (a[127..112] + a[111..96]) @ (a[95..80] + a[79..64]) @
        (a[63..48] + a[47..32]) @ (a[31..16] + a[15..0]);
      write_xmm_legacy(xreg, r)
    },
    // PHADDD xmm1, xmm2/m128
    2  => {
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      let r : xmmword =
        (b[127..96] + b[95..64]) @ (b[63..32] + b[31..0]) @
        (a[127..96] + a[95..64]) @ (a[63..32] + a[31..0]);
      write_xmm_legacy(xreg, r)
    },
    // PHADDSW xmm1, xmm2/m128
    3  => {
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      let r : xmmword =
        sat_add_s16(b[127..112], b[111..96]) @ sat_add_s16(b[95..80], b[79..64]) @
        sat_add_s16(b[63..48], b[47..32]) @ sat_add_s16(b[31..16], b[15..0]) @
        sat_add_s16(a[127..112], a[111..96]) @ sat_add_s16(a[95..80], a[79..64]) @
        sat_add_s16(a[63..48], a[47..32]) @ sat_add_s16(a[31..16], a[15..0]);
      write_xmm_legacy(xreg, r)
    },
    // PMADDUBSW xmm1, xmm2/m128
    4  => {
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      let r : xmmword =
        pmaddubsw_pair(a[127..120], b[127..120], a[119..112], b[119..112]) @
        pmaddubsw_pair(a[111..104], b[111..104], a[103..96], b[103..96]) @
        pmaddubsw_pair(a[95..88], b[95..88], a[87..80], b[87..80]) @
        pmaddubsw_pair(a[79..72], b[79..72], a[71..64], b[71..64]) @
        pmaddubsw_pair(a[63..56], b[63..56], a[55..48], b[55..48]) @
        pmaddubsw_pair(a[47..40], b[47..40], a[39..32], b[39..32]) @
        pmaddubsw_pair(a[31..24], b[31..24], a[23..16], b[23..16]) @
        pmaddubsw_pair(a[15..8], b[15..8], a[7..0], b[7..0]);
      write_xmm_legacy(xreg, r)
    },
    // PHSUBW xmm1, xmm2/m128
    5  => {
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      let r : xmmword =
        (b[111..96] - b[127..112]) @ (b[79..64] - b[95..80]) @
        (b[47..32] - b[63..48]) @ (b[15..0] - b[31..16]) @
        (a[111..96] - a[127..112]) @ (a[79..64] - a[95..80]) @
        (a[47..32] - a[63..48]) @ (a[15..0] - a[31..16]);
      write_xmm_legacy(xreg, r)
    },
    // PHSUBD xmm1, xmm2/m128
    6  => {
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      let r : xmmword =
        (b[95..64] - b[127..96]) @ (b[31..0] - b[63..32]) @
        (a[95..64] - a[127..96]) @ (a[31..0] - a[63..32]);
      write_xmm_legacy(xreg, r)
    },
    // PHSUBSW xmm1, xmm2/m128
    7  => {
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      let r : xmmword =
        sat_sub_s16(b[111..96], b[127..112]) @ sat_sub_s16(b[79..64], b[95..80]) @
        sat_sub_s16(b[47..32], b[63..48]) @ sat_sub_s16(b[15..0], b[31..16]) @
        sat_sub_s16(a[111..96], a[127..112]) @ sat_sub_s16(a[79..64], a[95..80]) @
        sat_sub_s16(a[47..32], a[63..48]) @ sat_sub_s16(a[15..0], a[31..16]);
      write_xmm_legacy(xreg, r)
    },
    // PSIGNB xmm1, xmm2/m128
    8  => {
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      let r : xmmword =
        psign8(a[127..120], b[127..120]) @ psign8(a[119..112], b[119..112]) @
        psign8(a[111..104], b[111..104]) @ psign8(a[103..96], b[103..96]) @
        psign8(a[95..88], b[95..88]) @ psign8(a[87..80], b[87..80]) @
        psign8(a[79..72], b[79..72]) @ psign8(a[71..64], b[71..64]) @
        psign8(a[63..56], b[63..56]) @ psign8(a[55..48], b[55..48]) @
        psign8(a[47..40], b[47..40]) @ psign8(a[39..32], b[39..32]) @
        psign8(a[31..24], b[31..24]) @ psign8(a[23..16], b[23..16]) @
        psign8(a[15..8], b[15..8]) @ psign8(a[7..0], b[7..0]);
      write_xmm_legacy(xreg, r)
    },
    // PSIGNW xmm1, xmm2/m128
    9  => {
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      let r : xmmword =
        psign16(a[127..112], b[127..112]) @ psign16(a[111..96], b[111..96]) @
        psign16(a[95..80], b[95..80]) @ psign16(a[79..64], b[79..64]) @
        psign16(a[63..48], b[63..48]) @ psign16(a[47..32], b[47..32]) @
        psign16(a[31..16], b[31..16]) @ psign16(a[15..0], b[15..0]);
      write_xmm_legacy(xreg, r)
    },
    // PSIGND xmm1, xmm2/m128
    10 => {
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      let r : xmmword =
        psign32(a[127..96], b[127..96]) @ psign32(a[95..64], b[95..64]) @
        psign32(a[63..32], b[63..32]) @ psign32(a[31..0], b[31..0]);
      write_xmm_legacy(xreg, r)
    },
    // PMULHRSW xmm1, xmm2/m128
    11 => {
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      let r : xmmword =
        mulhrsw(a[127..112], b[127..112]) @ mulhrsw(a[111..96], b[111..96]) @
        mulhrsw(a[95..80], b[95..80]) @ mulhrsw(a[79..64], b[79..64]) @
        mulhrsw(a[63..48], b[63..48]) @ mulhrsw(a[47..32], b[47..32]) @
        mulhrsw(a[31..16], b[31..16]) @ mulhrsw(a[15..0], b[15..0]);
      write_xmm_legacy(xreg, r)
    },

    // SSE4.1 — PBLENDVB (implicit XMM0 mask)
    16 => {
      let a : xmmword = read_xmm(xreg);
      let m : xmmword = read_xmm(0);
      let r0  : byte = blend_byte(a[7..0],     src_xmm[7..0],     m[7..7]);
      let r1  : byte = blend_byte(a[15..8],    src_xmm[15..8],    m[15..15]);
      let r2  : byte = blend_byte(a[23..16],   src_xmm[23..16],   m[23..23]);
      let r3  : byte = blend_byte(a[31..24],   src_xmm[31..24],   m[31..31]);
      let r4  : byte = blend_byte(a[39..32],   src_xmm[39..32],   m[39..39]);
      let r5  : byte = blend_byte(a[47..40],   src_xmm[47..40],   m[47..47]);
      let r6  : byte = blend_byte(a[55..48],   src_xmm[55..48],   m[55..55]);
      let r7  : byte = blend_byte(a[63..56],   src_xmm[63..56],   m[63..63]);
      let r8  : byte = blend_byte(a[71..64],   src_xmm[71..64],   m[71..71]);
      let r9  : byte = blend_byte(a[79..72],   src_xmm[79..72],   m[79..79]);
      let r10 : byte = blend_byte(a[87..80],   src_xmm[87..80],   m[87..87]);
      let r11 : byte = blend_byte(a[95..88],   src_xmm[95..88],   m[95..95]);
      let r12 : byte = blend_byte(a[103..96],  src_xmm[103..96],  m[103..103]);
      let r13 : byte = blend_byte(a[111..104], src_xmm[111..104], m[111..111]);
      let r14 : byte = blend_byte(a[119..112], src_xmm[119..112], m[119..119]);
      let r15 : byte = blend_byte(a[127..120], src_xmm[127..120], m[127..127]);
      write_xmm_legacy(xreg, r15 @ r14 @ r13 @ r12 @ r11 @ r10 @ r9 @ r8 @ r7 @ r6 @ r5 @ r4 @ r3 @ r2 @ r1 @ r0)
    },

    // SSE4.1 — PTEST
    23 => {
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      let temp1 : xmmword = a & b;
      let temp2 : xmmword = (not_vec(a)) & b;
      ZF = (~(or_reduce_64(temp1[127..64] | temp1[63..0])))[0];
      CF = (~(or_reduce_64(temp2[127..64] | temp2[63..0])))[0];
      OF = bitzero;
      AF = bitzero;
      PF = bitzero;
      SF = bitzero
    },

    // SSSE3 — PABSB
    28 => {
      let b : xmmword = src_xmm;
      let r : xmmword =
        abs8(b[127..120]) @ abs8(b[119..112]) @
        abs8(b[111..104]) @ abs8(b[103..96]) @
        abs8(b[95..88]) @ abs8(b[87..80]) @
        abs8(b[79..72]) @ abs8(b[71..64]) @
        abs8(b[63..56]) @ abs8(b[55..48]) @
        abs8(b[47..40]) @ abs8(b[39..32]) @
        abs8(b[31..24]) @ abs8(b[23..16]) @
        abs8(b[15..8]) @ abs8(b[7..0]);
      write_xmm_legacy(xreg, r)
    },
    // PABSW xmm1, xmm2/m128
    29 => {
      let b : xmmword = src_xmm;
      let r : xmmword =
        abs16(b[127..112]) @ abs16(b[111..96]) @
        abs16(b[95..80]) @ abs16(b[79..64]) @
        abs16(b[63..48]) @ abs16(b[47..32]) @
        abs16(b[31..16]) @ abs16(b[15..0]);
      write_xmm_legacy(xreg, r)
    },
    // PABSD xmm1, xmm2/m128
    30 => {
      let b : xmmword = src_xmm;
      let r : xmmword =
        abs32(b[127..96]) @ abs32(b[95..64]) @
        abs32(b[63..32]) @ abs32(b[31..0]);
      write_xmm_legacy(xreg, r)
    },

    // SSE4.1 — PMOVSXBW
    32 => {
      let s : xmmword = src_xmm;
      let r : xmmword =
        sx8_16(s[63..56]) @ sx8_16(s[55..48]) @
        sx8_16(s[47..40]) @ sx8_16(s[39..32]) @
        sx8_16(s[31..24]) @ sx8_16(s[23..16]) @
        sx8_16(s[15..8])  @ sx8_16(s[7..0]);
      write_xmm_legacy(xreg, r)
    },
    // PMOVSXBD xmm1, xmm2/m32
    33 => {
      let s : xmmword = src_xmm;
      let r : xmmword =
        sx8_32(s[31..24]) @ sx8_32(s[23..16]) @
        sx8_32(s[15..8])  @ sx8_32(s[7..0]);
      write_xmm_legacy(xreg, r)
    },
    // PMOVSXBQ xmm1, xmm2/m16
    34 => {
      let s : xmmword = src_xmm;
      let hi : qword = sign_extend(s[15..8]);
      let lo : qword = sign_extend(s[7..0]);
      write_xmm_legacy(xreg, hi @ lo)
    },
    // PMOVSXWD xmm1, xmm2/m64
    35 => {
      let s : xmmword = src_xmm;
      let r : xmmword =
        sx16_32(s[63..48]) @ sx16_32(s[47..32]) @
        sx16_32(s[31..16]) @ sx16_32(s[15..0]);
      write_xmm_legacy(xreg, r)
    },
    // PMOVSXWQ xmm1, xmm2/m32
    36 => {
      let s : xmmword = src_xmm;
      let hi : qword = sign_extend(s[31..16]);
      let lo : qword = sign_extend(s[15..0]);
      write_xmm_legacy(xreg, hi @ lo)
    },
    // PMOVSXDQ xmm1, xmm2/m64
    37 => {
      let s : xmmword = src_xmm;
      let hi : qword = sign_extend(s[63..32]);
      let lo : qword = sign_extend(s[31..0]);
      write_xmm_legacy(xreg, hi @ lo)
    },

    // SSE4.1 — PMULDQ
    40 => {
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      let hi : qword = to_bits_truncate(signed(a[95..64]) * signed(b[95..64]));
      let lo : qword = to_bits_truncate(signed(a[31..0]) * signed(b[31..0]));
      let r : xmmword = hi @ lo;
      write_xmm_legacy(xreg, r)
    },
    // PCMPEQQ xmm1, xmm2/m128
    41 => {
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      let r : xmmword = cmp_eq64(a[127..64], b[127..64]) @ cmp_eq64(a[63..0], b[63..0]);
      write_xmm_legacy(xreg, r)
    },
    // MOVNTDQA xmm, m128
    42 => {
      match rm {
        RM_mem(addr) => {
          write_xmm_legacy(xreg, mem_read128(addr))
        },
        RM_reg(_) => raise_UD(),
      }
    },
    // PACKUSDW xmm1, xmm2/m128
    43 => {
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      let w0 : word = sat_s32_to_u16(a[31..0]);
      let w1 : word = sat_s32_to_u16(a[63..32]);
      let w2 : word = sat_s32_to_u16(a[95..64]);
      let w3 : word = sat_s32_to_u16(a[127..96]);
      let w4 : word = sat_s32_to_u16(b[31..0]);
      let w5 : word = sat_s32_to_u16(b[63..32]);
      let w6 : word = sat_s32_to_u16(b[95..64]);
      let w7 : word = sat_s32_to_u16(b[127..96]);
      write_xmm_legacy(xreg, w7 @ w6 @ w5 @ w4 @ w3 @ w2 @ w1 @ w0)
    },

    // SSE4.1 — PMOVZXBW
    48 => {
      let s : xmmword = src_xmm;
      let r : xmmword =
        zx8_16(s[63..56]) @ zx8_16(s[55..48]) @
        zx8_16(s[47..40]) @ zx8_16(s[39..32]) @
        zx8_16(s[31..24]) @ zx8_16(s[23..16]) @
        zx8_16(s[15..8])  @ zx8_16(s[7..0]);
      write_xmm_legacy(xreg, r)
    },
    // PMOVZXBD xmm1, xmm2/m32
    49 => {
      let s : xmmword = src_xmm;
      let r : xmmword =
        zx8_32(s[31..24]) @ zx8_32(s[23..16]) @
        zx8_32(s[15..8])  @ zx8_32(s[7..0]);
      write_xmm_legacy(xreg, r)
    },
    // PMOVZXBQ xmm1, xmm2/m16
    50 => {
      let s : xmmword = src_xmm;
      let hi : qword = zero_extend(s[15..8]);
      let lo : qword = zero_extend(s[7..0]);
      write_xmm_legacy(xreg, hi @ lo)
    },
    // PMOVZXWD xmm1, xmm2/m64
    51 => {
      let s : xmmword = src_xmm;
      let r : xmmword =
        zx16_32(s[63..48]) @ zx16_32(s[47..32]) @
        zx16_32(s[31..16]) @ zx16_32(s[15..0]);
      write_xmm_legacy(xreg, r)
    },
    // PMOVZXWQ xmm1, xmm2/m32
    52 => {
      let s : xmmword = src_xmm;
      let hi : qword = zero_extend(s[31..16]);
      let lo : qword = zero_extend(s[15..0]);
      write_xmm_legacy(xreg, hi @ lo)
    },
    // PMOVZXDQ xmm1, xmm2/m64
    53 => {
      let s : xmmword = src_xmm;
      let hi : qword = zero_extend(s[63..32]);
      let lo : qword = zero_extend(s[31..0]);
      write_xmm_legacy(xreg, hi @ lo)
    },

    // SSE4.2 — PCMPGTQ
    55 => {
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      let r : xmmword = cmp_gt64(a[127..64], b[127..64]) @ cmp_gt64(a[63..0], b[63..0]);
      write_xmm_legacy(xreg, r)
    },

    // SSE4.1 — PMINSB
    56 => {
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      let r : xmmword =
        min_s8(a[127..120], b[127..120]) @ min_s8(a[119..112], b[119..112]) @
        min_s8(a[111..104], b[111..104]) @ min_s8(a[103..96], b[103..96]) @
        min_s8(a[95..88], b[95..88]) @ min_s8(a[87..80], b[87..80]) @
        min_s8(a[79..72], b[79..72]) @ min_s8(a[71..64], b[71..64]) @
        min_s8(a[63..56], b[63..56]) @ min_s8(a[55..48], b[55..48]) @
        min_s8(a[47..40], b[47..40]) @ min_s8(a[39..32], b[39..32]) @
        min_s8(a[31..24], b[31..24]) @ min_s8(a[23..16], b[23..16]) @
        min_s8(a[15..8], b[15..8]) @ min_s8(a[7..0], b[7..0]);
      write_xmm_legacy(xreg, r)
    },
    // PMINSD xmm1, xmm2/m128
    57 => {
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      let r : xmmword =
        min_s32(a[127..96], b[127..96]) @ min_s32(a[95..64], b[95..64]) @
        min_s32(a[63..32], b[63..32]) @ min_s32(a[31..0], b[31..0]);
      write_xmm_legacy(xreg, r)
    },
    // PMINUW xmm1, xmm2/m128
    58 => {
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      let r : xmmword =
        min_u16(a[127..112], b[127..112]) @ min_u16(a[111..96], b[111..96]) @
        min_u16(a[95..80], b[95..80]) @ min_u16(a[79..64], b[79..64]) @
        min_u16(a[63..48], b[63..48]) @ min_u16(a[47..32], b[47..32]) @
        min_u16(a[31..16], b[31..16]) @ min_u16(a[15..0], b[15..0]);
      write_xmm_legacy(xreg, r)
    },
    // PMINUD xmm1, xmm2/m128
    59 => {
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      let r : xmmword =
        min_u32(a[127..96], b[127..96]) @ min_u32(a[95..64], b[95..64]) @
        min_u32(a[63..32], b[63..32]) @ min_u32(a[31..0], b[31..0]);
      write_xmm_legacy(xreg, r)
    },
    // PMAXSB xmm1, xmm2/m128
    60 => {
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      let r : xmmword =
        max_s8(a[127..120], b[127..120]) @ max_s8(a[119..112], b[119..112]) @
        max_s8(a[111..104], b[111..104]) @ max_s8(a[103..96], b[103..96]) @
        max_s8(a[95..88], b[95..88]) @ max_s8(a[87..80], b[87..80]) @
        max_s8(a[79..72], b[79..72]) @ max_s8(a[71..64], b[71..64]) @
        max_s8(a[63..56], b[63..56]) @ max_s8(a[55..48], b[55..48]) @
        max_s8(a[47..40], b[47..40]) @ max_s8(a[39..32], b[39..32]) @
        max_s8(a[31..24], b[31..24]) @ max_s8(a[23..16], b[23..16]) @
        max_s8(a[15..8], b[15..8]) @ max_s8(a[7..0], b[7..0]);
      write_xmm_legacy(xreg, r)
    },
    // PMAXSD xmm1, xmm2/m128
    61 => {
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      let r : xmmword =
        max_s32(a[127..96], b[127..96]) @ max_s32(a[95..64], b[95..64]) @
        max_s32(a[63..32], b[63..32]) @ max_s32(a[31..0], b[31..0]);
      write_xmm_legacy(xreg, r)
    },
    // PMAXUW xmm1, xmm2/m128
    62 => {
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      let r : xmmword =
        max_u16(a[127..112], b[127..112]) @ max_u16(a[111..96], b[111..96]) @
        max_u16(a[95..80], b[95..80]) @ max_u16(a[79..64], b[79..64]) @
        max_u16(a[63..48], b[63..48]) @ max_u16(a[47..32], b[47..32]) @
        max_u16(a[31..16], b[31..16]) @ max_u16(a[15..0], b[15..0]);
      write_xmm_legacy(xreg, r)
    },
    // PMAXUD xmm1, xmm2/m128
    63 => {
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      let r : xmmword =
        max_u32(a[127..96], b[127..96]) @ max_u32(a[95..64], b[95..64]) @
        max_u32(a[63..32], b[63..32]) @ max_u32(a[31..0], b[31..0]);
      write_xmm_legacy(xreg, r)
    },

    // SSE4.1 — PMULLD
    64 => {
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      let r : xmmword =
        mul_lo32(a[127..96], b[127..96]) @ mul_lo32(a[95..64], b[95..64]) @
        mul_lo32(a[63..32], b[63..32]) @ mul_lo32(a[31..0], b[31..0]);
      write_xmm_legacy(xreg, r)
    },
    // PHMINPOSUW xmm1, xmm2/m128
    65 => {
      let s : xmmword = src_xmm;
      let w0 : word = s[15..0];
      let w1 : word = s[31..16];
      let w2 : word = s[47..32];
      let w3 : word = s[63..48];
      let w4 : word = s[79..64];
      let w5 : word = s[95..80];
      let w6 : word = s[111..96];
      let w7 : word = s[127..112];

      // Find minimum value and index (lowest index wins on tie) — branchless
      var mv : word = w0;
      var mi : word = 0x0000;

      let d1 : bits(17) = (0b0 @ w1) - (0b0 @ mv);
      let u1 : word = zeros() - zero_extend(d1[16..16]);
      mv = (w1 & u1) | (mv & not_vec(u1));
      mi = (0x0001 & u1) | (mi & not_vec(u1));

      let d2 : bits(17) = (0b0 @ w2) - (0b0 @ mv);
      let u2 : word = zeros() - zero_extend(d2[16..16]);
      mv = (w2 & u2) | (mv & not_vec(u2));
      mi = (0x0002 & u2) | (mi & not_vec(u2));

      let d3 : bits(17) = (0b0 @ w3) - (0b0 @ mv);
      let u3 : word = zeros() - zero_extend(d3[16..16]);
      mv = (w3 & u3) | (mv & not_vec(u3));
      mi = (0x0003 & u3) | (mi & not_vec(u3));

      let d4 : bits(17) = (0b0 @ w4) - (0b0 @ mv);
      let u4 : word = zeros() - zero_extend(d4[16..16]);
      mv = (w4 & u4) | (mv & not_vec(u4));
      mi = (0x0004 & u4) | (mi & not_vec(u4));

      let d5 : bits(17) = (0b0 @ w5) - (0b0 @ mv);
      let u5 : word = zeros() - zero_extend(d5[16..16]);
      mv = (w5 & u5) | (mv & not_vec(u5));
      mi = (0x0005 & u5) | (mi & not_vec(u5));

      let d6 : bits(17) = (0b0 @ w6) - (0b0 @ mv);
      let u6 : word = zeros() - zero_extend(d6[16..16]);
      mv = (w6 & u6) | (mv & not_vec(u6));
      mi = (0x0006 & u6) | (mi & not_vec(u6));

      let d7 : bits(17) = (0b0 @ w7) - (0b0 @ mv);
      let u7 : word = zeros() - zero_extend(d7[16..16]);
      mv = (w7 & u7) | (mv & not_vec(u7));
      mi = (0x0007 & u7) | (mi & not_vec(u7));

      write_xmm_legacy(xreg, zeros(96) @ mi @ mv)
    },

    // AES-NI — AESIMC
    219 => {
      let s : xmmword = src_xmm;
      write_xmm_legacy(xreg, __aesimc(s))
    },
    // AES-NI — AESENC
    220 => {
      let state : xmmword = read_xmm(xreg);
      let roundkey : xmmword = src_xmm;
      write_xmm_legacy(xreg, __aesenc(state, roundkey))
    },
    // AES-NI — AESENCLAST (0F 38 DD)
    221 => {
      let state : xmmword = read_xmm(xreg);
      let roundkey : xmmword = src_xmm;
      write_xmm_legacy(xreg, __aesenclast(state, roundkey))
    },
    // AES-NI — AESDEC (0F 38 DE)
    222 => {
      let state : xmmword = read_xmm(xreg);
      let roundkey : xmmword = src_xmm;
      write_xmm_legacy(xreg, __aesdec(state, roundkey))
    },
    // AES-NI — AESDECLAST
    223 => {
      let state : xmmword = read_xmm(xreg);
      let roundkey : xmmword = src_xmm;
      write_xmm_legacy(xreg, __aesdeclast(state, roundkey))
    },

    // GFNI — GF2P8MULB (66 0F 38 CF)
    207 => {
      write_xmm_legacy(xreg, __gf2p8mulb(read_xmm(xreg), src_xmm))
    },

    _ => raise_UD(),
  }
}

// 0F 3A xx — SSE integer operations (PBLENDW, PALIGNR, PEXTR*, PINSR*,
//            MPSADBW, PCLMULQDQ, PCMPxSTRx, AESKEYGENASSIST)
val dispatch_3byte_3a_sse_int : (byte, Prefixes) -> unit
function dispatch_3byte_3a_sse_int(opcode, pfx) = {
  let op : range(0, 255) = unsigned(opcode);
  let mp = get_mandatory_prefix(pfx);
  if mp != MP_66 then raise_UD();
  let modrm = fetch_byte();
  let xreg = modrm_xmm_reg(modrm, pfx);
  let rm = decode_rm(modrm, pfx);
  match op {

    // SSE4.1 — PBLENDW
    14 => {
      let src_xmm = decode_xmm_src(modrm, rm, pfx);
      let imm = fetch_byte();
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      write_xmm_legacy(xreg,
        blend16(a[127..112], b[127..112], imm[7..7]) @
        blend16(a[111..96],  b[111..96],  imm[6..6]) @
        blend16(a[95..80],   b[95..80],   imm[5..5]) @
        blend16(a[79..64],   b[79..64],   imm[4..4]) @
        blend16(a[63..48],   b[63..48],   imm[3..3]) @
        blend16(a[47..32],   b[47..32],   imm[2..2]) @
        blend16(a[31..16],   b[31..16],   imm[1..1]) @
        blend16(a[15..0],    b[15..0],    imm[0..0]))
    },

    // SSSE3 — PALIGNR
    15 => {
      let src_xmm = decode_xmm_src(modrm, rm, pfx);
      let imm = fetch_byte();
      let d : xmmword = read_xmm(xreg);
      let s : xmmword = src_xmm;
      let concat : ymmword = d @ s;
      let shift_bytes : range(0, 255) = unsigned(imm);
      let r : xmmword = (concat >> (shift_bytes * 8))[127..0];
      write_xmm_legacy(xreg, r)
    },

    // SSE4.1 — PEXTRB r/m8, xmm, imm8
    20 => {
      let imm = fetch_byte();
      let v = extract_byte_from_xmm(read_xmm(xreg), imm);
      match rm {
        RM_reg(_) => {
          let dst_reg = modrm_rm_reg(modrm, pfx);
          write_gpr32(dst_reg, zero_extend(v));
        },
        RM_mem(addr) => mem_write8(fixup_addr(addr), v),
      }
    },

    // SSE4.1 — PEXTRD/PEXTRQ r/m, xmm, imm8
    22 => {
      let imm = fetch_byte();
      let src = read_xmm(xreg);
      match rm {
        RM_reg(_) => {
          let dst_reg = modrm_rm_reg(modrm, pfx);
          if pfx.rex_w then write_gpr64(dst_reg, extract_qword_from_xmm(src, imm))
          else write_gpr32(dst_reg, extract_dword_from_xmm(src, imm))
        },
        RM_mem(addr) => {
          let a = fixup_addr(addr);
          if pfx.rex_w then mem_write64(a, extract_qword_from_xmm(src, imm))
          else mem_write32(a, extract_dword_from_xmm(src, imm))
        },
      }
    },

    // SSE4.1 — PINSRB xmm, r/m8, imm8
    32 => {
      let imm = fetch_byte();
      let v : byte = match rm {
        RM_reg(idx) => read_gpr8l(idx),
        RM_mem(addr) => mem_read8(addr),
      };
      let v_0 : xmmword = read_xmm(xreg);
      let sel : range(0, 15) = unsigned(imm[3..0]);
      let r : xmmword = insert_byte(v_0, v, sel);
      write_xmm_legacy(xreg, r)
    },

    // SSE4.1 — PINSRD/PINSRQ xmm, r/m, imm8
    34 => {
      let imm = fetch_byte();
      if pfx.rex_w then {
        let v : qword = match rm {
          RM_reg(idx) => read_gpr64(idx),
          RM_mem(addr) => mem_read64(addr),
        };
        let v_0 : xmmword = read_xmm(xreg);
        let sel : range(0, 1) = unsigned(imm[0..0]);
        let r : xmmword = match sel {
          0 => v_0[127..64] @ v,
          1 => v @ v_0[63..0]
        };
        write_xmm_legacy(xreg, r)
      } else {
        let v : dword = match rm {
          RM_reg(idx) => read_gpr32(idx),
          RM_mem(addr) => mem_read32(addr),
        };
        let v_0 : xmmword = read_xmm(xreg);
        let sel : range(0, 3) = unsigned(imm[1..0]);
        let r : xmmword = insert_dword(v_0, v, sel);
        write_xmm_legacy(xreg, r)
      }
    },

    // SSE4.1 — MPSADBW
    66 => {
      let src_xmm = decode_xmm_src(modrm, rm, pfx);
      let imm = fetch_byte();
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      write_xmm_legacy(xreg, __mpsadbw(a, b, imm))
    },

    // PCLMULQDQ xmm1, xmm2/m128, imm8
    68 => {
      let src_xmm = decode_xmm_src(modrm, rm, pfx);
      let imm = fetch_byte();
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      let sel_a : qword = blend64(a[63..0], a[127..64], imm[0..0]);
      let sel_b : qword = blend64(b[63..0], b[127..64], imm[4..4]);
      let result : xmmword = __pclmulqdq(sel_a, sel_b);
      write_xmm_legacy(xreg, result)
    },

    // SSE4.2 — PCMPESTRM
    96 => {
      let src_xmm = decode_xmm_src(modrm, rm, pfx);
      let imm = fetch_byte();
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      let la : dword = read_gpr32(RAX);
      let lb : dword = read_gpr32(RDX);
      let (mask, cf_val, zf_val, sf_val, of_val) = __pcmpestrm(a, la, b, lb, imm);
      write_xmm_legacy(0, mask);
      CF = cf_val;
      ZF = zf_val;
      SF = sf_val;
      OF = of_val;
      AF = bitzero;
      PF = bitzero
    },
    // SSE4.2 — PCMPESTRI
    97 => {
      let src_xmm = decode_xmm_src(modrm, rm, pfx);
      let imm = fetch_byte();
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      let la : dword = read_gpr32(RAX);
      let lb : dword = read_gpr32(RDX);
      let (idx, cf_val, zf_val, sf_val, of_val) = __pcmpestri(a, la, b, lb, imm);
      write_gpr32(RCX, idx);
      CF = cf_val;
      ZF = zf_val;
      SF = sf_val;
      OF = of_val;
      AF = bitzero;
      PF = bitzero
    },
    // SSE4.2 — PCMPISTRM
    98 => {
      let src_xmm = decode_xmm_src(modrm, rm, pfx);
      let imm = fetch_byte();
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      let (mask, cf_val, zf_val, sf_val, of_val) = __pcmpistrm(a, b, imm);
      write_xmm_legacy(0, mask);
      CF = cf_val;
      ZF = zf_val;
      SF = sf_val;
      OF = of_val;
      AF = bitzero;
      PF = bitzero
    },
    // SSE4.2 — PCMPISTRI
    99 => {
      let src_xmm = decode_xmm_src(modrm, rm, pfx);
      let imm = fetch_byte();
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      let (idx, cf_val, zf_val, sf_val, of_val) = __pcmpistri(a, b, imm);
      write_gpr32(RCX, idx);
      CF = cf_val;
      ZF = zf_val;
      SF = sf_val;
      OF = of_val;
      AF = bitzero;
      PF = bitzero
    },

    // AES-NI — AESKEYGENASSIST
    223 => {
      let src_xmm = decode_xmm_src(modrm, rm, pfx);
      let imm = fetch_byte();
      let s : xmmword = src_xmm;
      write_xmm_legacy(xreg, __aeskeygenassist(s, imm))
    },

    // GFNI — GF2P8AFFINEQB (66 0F 3A CE)
    206 => {
      let src_xmm = decode_xmm_src(modrm, rm, pfx);
      let imm = fetch_byte();
      write_xmm_legacy(xreg, __gf2p8affineqb(read_xmm(xreg), src_xmm, imm))
    },

    // GFNI — GF2P8AFFINEINVQB (66 0F 3A CF)
    207 => {
      let src_xmm = decode_xmm_src(modrm, rm, pfx);
      let imm = fetch_byte();
      write_xmm_legacy(xreg, __gf2p8affineinvqb(read_xmm(xreg), src_xmm, imm))
    },

    _ => raise_UD(),
  }
}

// x86-64 — Branchless bit-manipulation helpers
//
// Pure utility functions used across multiple instruction files.
// All are branch-free to support formal verification tools (Isla/SMT).

// Branchless POPCNT
val popcount : forall 'n, 0 < 'n & 'n <= 64. bits('n) -> range(0, 'n)
function popcount(v) = {
  let x : qword = zero_extend(v);
  let x = (x & 0x5555555555555555) + ((x >> 1)  & 0x5555555555555555);
  let x = (x & 0x3333333333333333) + ((x >> 2)  & 0x3333333333333333);
  let x = (x & 0x0f0f0f0f0f0f0f0f) + ((x >> 4)  & 0x0f0f0f0f0f0f0f0f);
  let x = (x & 0x00ff00ff00ff00ff) + ((x >> 8)  & 0x00ff00ff00ff00ff);
  let x = (x & 0x0000ffff0000ffff) + ((x >> 16) & 0x0000ffff0000ffff);
  let x = (x & 0x00000000ffffffff) + ((x >> 32) & 0x00000000ffffffff);
  let x = unsigned(x);
  assert(x <= 'n);
  x
}

// or_reduce: 1 if any bit is set, 0 otherwise (branchless tree reduction).
val or_reduce : forall 'n, 0 < 'n & 'n <= 512. bits('n) -> bits(1)
function or_reduce(v) = {
  let x : zmmword = zero_extend(v);
  let x = x | (x >> 1);
  let x = x | (x >> 2);
  let x = x | (x >> 4);
  let x = x | (x >> 8);
  let x = x | (x >> 16);
  let x = x | (x >> 32);
  let x = x | (x >> 64);
  let x = x | (x >> 128);
  let x = x | (x >> 256);
  x[0]
}

// is_nonzero: 0 if all bits are zero, 1 otherwise.
val is_nonzero : forall 'n, 0 < 'n & 'n <= 512. bits('n) -> bit
function is_nonzero(v) = or_reduce(v)[0]

// is_zero: 1 if all bits are zero, 0 otherwise.
val is_zero : forall 'n, 0 < 'n & 'n <= 512. bits('n) -> bit
function is_zero(v) = ~(is_nonzero(v))

// is_eq: 1 if a == b, 0 otherwise.
val is_eq : forall 'n, 0 < 'n & 'n <= 64. (bits('n), bits('n)) -> bit
function is_eq(a, b) = is_zero(a ^ b)

// is_gt: 1 if a > b (signed), 0 otherwise.
val is_gt : forall 'n, 0 < 'n & 'n <= 64. (bits('n), bits('n)) -> bit
function is_gt(a, b) = {
  let diff : bits('n + 1) = sign_extend(b) - sign_extend(a);
  diff['n]
}

// is_gt_u: 1 if a > b (unsigned), 0 otherwise.
val is_gt_u : forall 'n, 0 < 'n & 'n <= 64. (bits('n), bits('n)) -> bit
function is_gt_u(a, b) = {
  let diff : bits('n + 1) = zero_extend(b) - zero_extend(a);
  diff['n]
}

// is_ne: 1 if a != b, 0 otherwise.
val is_ne : forall 'n, 0 < 'n & 'n <= 64. (bits('n), bits('n)) -> bit
function is_ne(a, b) = is_nonzero(a ^ b)

// is_lt_u: 1 if a < b (unsigned), 0 otherwise.
val is_lt_u : forall 'n, 0 < 'n & 'n <= 64. (bits('n), bits('n)) -> bit
function is_lt_u(a, b) = is_gt_u(b, a)

// is_ge_u: 1 if a >= b (unsigned), 0 otherwise.
val is_ge_u : forall 'n, 0 < 'n & 'n <= 64. (bits('n), bits('n)) -> bit
function is_ge_u(a, b) = ~(is_gt_u(b, a))

// is_le_u: 1 if a <= b (unsigned), 0 otherwise.
val is_le_u : forall 'n, 0 < 'n & 'n <= 64. (bits('n), bits('n)) -> bit
function is_le_u(a, b) = ~(is_gt_u(a, b))

// Rotate left/right by a bounded integer amount.
val rotl : forall 'm 'n, 'm >= 'n >= 0. (bits('m), int('n)) -> bits('m)
function rotl(v, shift) = (v << shift) | (v >> ('m - shift))

val rotr : forall 'm 'n, 'm >= 'n >= 0. (bits('m), int('n)) -> bits('m)
function rotr(v, shift) = (v >> shift) | (v << ('m - shift))

// Branchless blend: select a or b per element based on a single bit.
// sel=0 -> a, sel=1 -> b.
val blend : forall 'n, 0 < 'n. (bits('n), bits('n), bit) -> bits('n)
function blend(a, b, sel) = {
  let m : bits('n) = sign_extend(sel);
  (a & ~(m)) | (b & m)
}

// =========================================================================
// Comparison helpers (return full-width masks)
// =========================================================================

// All-ones if a == b, all-zeros otherwise.
val cmp_eq : forall 'n, 0 < 'n & 'n <= 64. (bits('n), bits('n)) -> bits('n)
function cmp_eq(a, b) = sign_extend(is_eq(a, b))

// All-ones if a > b (signed), all-zeros otherwise.
val cmp_gt : forall 'n, 0 < 'n & 'n <= 64. (bits('n), bits('n)) -> bits('n)
function cmp_gt(a, b) = sign_extend(is_gt(a, b))

// =========================================================================
// Min/max
// =========================================================================

// PSIGN: negate if b < 0, zero if b == 0, keep if b > 0.
val psign : forall 'n, 0 < 'n & 'n <= 64. (bits('n), bits('n)) -> bits('n)
function psign(a, b) = {
  let neg_mask : bits('n) = sign_extend(b['n - 1]);
  ((a ^ neg_mask) - neg_mask) & sign_extend(is_nonzero(b))
}

val max_s : forall 'n, 0 < 'n & 'n <= 64. (bits('n), bits('n)) -> bits('n)
function max_s(a, b) = blend(a, b, is_gt(b, a))

val min_s : forall 'n, 0 < 'n & 'n <= 64. (bits('n), bits('n)) -> bits('n)
function min_s(a, b) = blend(a, b, is_gt(a, b))

val max_u : forall 'n, 0 < 'n & 'n <= 64. (bits('n), bits('n)) -> bits('n)
function max_u(a, b) = blend(a, b, is_gt_u(b, a))

val min_u : forall 'n, 0 < 'n & 'n <= 64. (bits('n), bits('n)) -> bits('n)
function min_u(a, b) = blend(a, b, is_gt_u(a, b))

// =========================================================================
// Bit-scan / count helpers
// =========================================================================

// Branchless CLZ via smear (fill all bits below MSB) then popcount.
val clz : forall 'n, 0 < 'n & 'n <= 64. bits('n) -> range(0, 'n)
function clz(v) = {
  let x1 : bits('n) = v  | (v  >> 1);
  let x2 : bits('n) = x1 | (x1 >> 2);
  let x3 : bits('n) = x2 | (x2 >> 4);
  let x4 : bits('n) = x3 | (x3 >> 8);
  let x5 : bits('n) = x4 | (x4 >> 16);
  let x6 : bits('n) = x5 | (x5 >> 32);
  'n - popcount(x6)
}

// Branchless CTZ via popcount: ctz(v) = popcount(~v & (v - 1))
val ctz : forall 'n, 0 < 'n & 'n <= 64. bits('n) -> range(0, 'n)
function ctz(v) = popcount(~(v) & (v - 1))

// BSR (bit scan reverse): index of highest set bit = width - 1 - clz(v).
// Precondition: v != 0 (BSR is undefined for zero).
val bsr : forall 'n, 0 < 'n & 'n <= 64. bits('n) -> range(0, 'n - 1)
function bsr(v) = {
  let x = clz(v);
  assert(x < 'n);
  'n - 1 - x
}

// =========================================================================
// Byte manipulation
// =========================================================================

// BSWAP — Reverse byte order of a bitvector.
val bswap : forall 'n, 'n in {16, 32, 64}. bits('n) -> bits('n)
function bswap(v) = {
  match 'n {
    16 => v[7..0] @ v[15..8],
    32 => v[7..0] @ v[15..8] @ v[23..16] @ v[31..24],
    64 => v[7..0] @ v[15..8] @ v[23..16] @ v[31..24] @ v[39..32] @ v[47..40] @ v[55..48] @ v[63..56]
  }
}

// =========================================================================
// Absolute value, saturation arithmetic, and rounding average
// =========================================================================

// Branchless absolute value: mask = sign-extend of MSB; (x ^ mask) - mask
val abs : forall 'n, 'n > 0. bits('n) -> bits('n)
function abs(x) = {
  let m : bits('n) = sign_extend(x['n - 1]);
  (x ^ m) - m
}

// Signed saturating add.
val sat_add_s : forall 'n, 0 < 'n & 'n <= 64. (bits('n), bits('n)) -> bits('n)
function sat_add_s(a, b) = {
  let wide : bits('n + 1) = sign_extend(a) + sign_extend(b);
  let result : bits('n) = wide[('n - 1) .. 0];
  let overflow : bit = wide['n] ^ result['n - 1];
  let msb_only : bits('n) = zero_extend(0b1) << ('n - 1);
  let clamp : bits('n) = msb_only ^ sign_extend(~(wide['n]));
  blend(result, clamp, overflow)
}

// Unsigned saturating add.
val sat_add_u : forall 'n, 0 < 'n & 'n <= 64. (bits('n), bits('n)) -> bits('n)
function sat_add_u(a, b) = {
  let wide : bits('n + 1) = zero_extend(a) + zero_extend(b);
  wide[('n - 1) .. 0] | sign_extend(wide['n])
}

val sat_sub_s : forall 'n, 0 < 'n & 'n <= 64. (bits('n), bits('n)) -> bits('n)
function sat_sub_s(a, b) = {
  let wide : bits('n + 1) = sign_extend(a) - sign_extend(b);
  let result : bits('n) = wide[('n - 1) .. 0];
  let overflow : bit = wide['n] ^ result['n - 1];
  let msb_only : bits('n) = zero_extend(0b1) << ('n - 1);
  let clamp : bits('n) = msb_only ^ sign_extend(~(wide['n]));
  blend(result, clamp, overflow)
}

val sat_sub_u : forall 'n, 0 < 'n & 'n <= 64. (bits('n), bits('n)) -> bits('n)
function sat_sub_u(a, b) = {
  let wide : bits('n + 1) = zero_extend(a) - zero_extend(b);
  wide[('n - 1) .. 0] & sign_extend(~(wide['n]))
}

// Rounding average: (a + b + 1) >> 1
val avg : forall 'n, 0 < 'n & 'n <= 64. (bits('n), bits('n)) -> bits('n)
function avg(a, b) = {
  let sum : bits('n + 1) = zero_extend(a) + zero_extend(b) + 1;
  sum['n .. 1]
}

// Signed saturation: clamp signed x to [-(2^(dst-1)), 2^(dst-1)-1], truncate.
val sat_s : forall 'n 'dst, 0 < 'dst & 'dst < 'n & 'n <= 64.
  (implicit('dst), bits('n)) -> bits('dst)
function sat_s(dst, x) = {
  let hi : bits('n) = zero_extend(ones(dst - 1));
  let lo : bits('n) = ~(hi);
  min_s(max_s(x, lo), hi)[('dst - 1)..0]
}

// Signed-to-unsigned saturation: clamp signed x to [0, 2^dst-1], truncate.
val sat_su : forall 'n 'dst, 0 < 'dst & 'dst < 'n & 'n <= 64.
  (implicit('dst), bits('n)) -> bits('dst)
function sat_su(dst, x) = {
  let hi : bits('n) = zero_extend(ones(dst));
  let lo : bits('n) = zeros();
  min_s(max_s(x, lo), hi)[('dst - 1)..0]
}

// Unsigned saturation: clamp unsigned x to [0, 2^dst-1], truncate.
val sat_u : forall 'n 'dst, 0 < 'dst & 'dst < 'n & 'n <= 64.
  (implicit('dst), bits('n)) -> bits('dst)
function sat_u(dst, x) = {
  let hi : bits('n) = zero_extend(ones(dst));
  min_u(x, hi)[('dst - 1)..0]
}

// PSHUFB: per-byte shuffle within a 128-bit lane.
// Each result byte is selected from src by the low 4 bits of the corresponding
// ctrl byte. If ctrl byte's high bit is set, the result byte is zero.
val pshufb : (bits(128), bits(128)) -> bits(128)
function pshufb(src, ctrl) = {
  var r : bits(128) = zeros();
  foreach (i from 0 to 15) {
    let lo = i * 8;
    let mask : byte = velem(8, ctrl, i);
    let selected : byte = velem(8, src, mask[3..0]);
    r[(lo + 7)..lo] = selected & sign_extend(~(mask[7]))
  };
  r
}

// PMADDUBSW per-pair: unsigned*signed byte multiply, add adjacent, saturate to word.
val pmaddubsw_pair : (byte, byte, byte, byte) -> word
function pmaddubsw_pair(a_even, b_even, a_odd, b_odd) = {
  let p1 : int = unsigned(a_even) * signed(b_even);
  let p2 : int = unsigned(a_odd) * signed(b_odd);
  let sum : int = p1 + p2;
  let wide : bits(17) = get_slice_int(17, sum, 0);
  let sign : bits(1) = wide[16];
  let of_mask : word = sign_extend(sign ^ wide[15]);
  let sat : word = sign_extend(sign) ^ 0x7FFF;
  (sat & of_mask) | (wide[15..0] & ~(of_mask))
}

// Absolute difference of unsigned bytes.
val abs_diff : forall 'n, 'n > 0. (bits('n), bits('n)) -> int
function abs_diff(a, b) = {
  let d1 = (0b0 @ a) - (0b0 @ b);
  let d2 = (0b0 @ b) - (0b0 @ a);
  let m1 : bits('n) = sign_extend(~(d1['n]));
  let m2 : bits('n) = sign_extend(~(d2['n]));
  unsigned((d1['n-1..0] & m1) | (d2['n-1..0] & m2))
}

// PSADBW: sum of absolute differences of 8 unsigned byte pairs, zero-extended to 64 bits.
val psadbw : (bits(64), bits(64)) -> bits(64)
function psadbw(a, b) =
  zero_extend(get_slice_int(16,
    abs_diff(a[63..56], b[63..56]) + abs_diff(a[55..48], b[55..48]) +
    abs_diff(a[47..40], b[47..40]) + abs_diff(a[39..32], b[39..32]) +
    abs_diff(a[31..24], b[31..24]) + abs_diff(a[23..16], b[23..16]) +
    abs_diff(a[15..8],  b[15..8])  + abs_diff(a[7..0],   b[7..0]), 0))

// FP16 <-> FP32 conversion.
val fp16_to_fp32 : bits(16) -> bits(32)
function fp16_to_fp32(h) = {
  let sign : bits(1) = h[15..15];
  let exp5 : bits(5) = h[14..10];
  let frac10 : bits(10) = h[9..0];
  let inf_nan : bit = is_eq(exp5, 0b11111);
  let zero_exp : bit = is_eq(exp5, 0b00000);
  let frac_nz : bit = is_nonzero(frac10);
  let normal_body : bits(31) = (zero_extend(exp5) + 0x70) @ frac10 @ 0b0000000000000;
  let lz = clz(frac10);
  let denorm_body : bits(31) =
    to_bits(8, 112 - lz) @ (frac10 << (lz + 1)) @ 0b0000000000000;
  let infnan_body : bits(31) = 0xFF @ frac10 @ 0b0000000000000;
  let body : bits(31) = blend(normal_body, denorm_body, zero_exp & frac_nz);
  let body : bits(31) = blend(body, zeros(), zero_exp & ~(frac_nz));
  let body : bits(31) = blend(body, infnan_body, inf_nan);
  sign @ body
}

val fp32_to_fp16 : (bits(32), bits(2)) -> bits(16)
function fp32_to_fp16(f, rc) = {
  let sign : bits(1) = f[31..31];
  let exp8 : bits(8) = f[30..23];
  let frac23 : bits(23) = f[22..0];
  let is_inf_nan : bit = is_eq(exp8, 0xFF);
  let is_overflow : bit = is_gt_u(exp8, 0x8E) & ~(is_inf_nan);
  let is_underflow : bit = is_lt_u(exp8, 0x67);
  let is_denorm_out : bit = is_lt_u(exp8, 0x71) & ~(is_underflow);
  let norm_top15 : bits(15) = (exp8 - 0x70)[4..0] @ frac23[22..13];
  let norm_round : bit = frac23[12];
  let norm_sticky : bit = is_nonzero(frac23[11..0]);
  let shift_amt = unsigned(0x71 - exp8);
  let shifted : bits(37) = ((0b1 @ frac23) @ 0b0000000000000) >> shift_amt;
  let denorm_top15 : bits(15) = 0b00000 @ shifted[35..26];
  let denorm_round : bit = shifted[25];
  let denorm_sticky : bit = is_nonzero(shifted[24..0]);
  let top15 : bits(15) = blend(norm_top15, denorm_top15, is_denorm_out);
  let round_bit : bit = (norm_round & ~(is_denorm_out)) | (denorm_round & is_denorm_out);
  let sticky_bit : bit = (norm_sticky & ~(is_denorm_out)) | (denorm_sticky & is_denorm_out);
  let rs : bit = round_bit | sticky_bit;
  let rne_up : bit = round_bit & (sticky_bit | top15[0]);
  let down_up : bit = sign[0] & rs;
  let up_up : bit = ~(sign[0]) & rs;
  let lo : bit = (rne_up & ~(rc[0])) | (down_up & rc[0]);
  let hi : bit = (up_up & ~(rc[0]));
  let round_up : bit = (lo & ~(rc[1])) | (hi & rc[1]);
  let result15 : bits(15) = top15 + zero_extend(round_up);
  let body : bits(15) = result15;
  let body : bits(15) = blend(body, zeros(), is_underflow);
  let body : bits(15) = blend(body, 0b11111 @ zeros(10), is_overflow);
  let body : bits(15) = blend(body, 0b11111 @ frac23[22..13], is_inf_nan);
  sign @ body
}

// Multiply high with rounding and scale: ((a*b) >> (n-2) + 1) >> 1
val mulhrs : forall 'n, 'n in {8, 16, 32, 64}. (bits('n), bits('n)) -> bits('n)
function mulhrs(a, b) = {
  let prod : bits('n * 2) = to_bits_truncate(signed(a) * signed(b));
  let shifted = prod >>> ('n - 2);
  let rounded : bits('n * 2) = to_bits_truncate(signed(shifted) + 1);
  (rounded >>> 1)[('n - 1)..0]
}

// =========================================================================
// GFNI primitives (GF(2^8) with irreducible polynomial x^8+x^4+x^3+x+1)
// =========================================================================

val gf2p8_mul : (byte, byte) -> byte
function gf2p8_mul(a, b) = {
  var result : bits(9) = zeros();
  var aa : bits(9) = zero_extend(a);
  foreach (i from 0 to 7) {
    result = result ^ (sign_extend(b[i..i]) & aa);
    aa = aa << 1;
    aa = aa ^ (sign_extend(aa[8]) & 0b100011011) // 0x11B
  };
  result[7..0]
}

val gf2p8_affine : (byte, qword, byte) -> byte
function gf2p8_affine(src, matrix, imm8) = {
  var r : byte = zeros();
  foreach (i from 0 to 7) {
    let row_lo : range(0, 56) = (7 - i) * 8;
    let row : byte = matrix[(row_lo + 7)..row_lo];
    let product : byte = src & row;
    let x4 : bits(4) = product[7..4] ^ product[3..0];
    let x2 : bits(2) = x4[3..2] ^ x4[1..0];
    let bit : bit = (x2[1] ^ x2[0])[0];
    r[i] = bit ^ imm8[i];
  };
  r
}

val gf2p8_inv : byte -> byte
function gf2p8_inv(x) = {
  let x2 = gf2p8_mul(x, x);
  let x3 = gf2p8_mul(x2, x);
  let x6 = gf2p8_mul(x3, x3);
  let x12 = gf2p8_mul(x6, x6);
  let x15 = gf2p8_mul(x12, x3);
  let x30 = gf2p8_mul(x15, x15);
  let x60 = gf2p8_mul(x30, x30);
  let x63 = gf2p8_mul(x60, x3);
  let x126 = gf2p8_mul(x63, x63);
  let x252 = gf2p8_mul(x126, x126);
  gf2p8_mul(x252, x2)
}

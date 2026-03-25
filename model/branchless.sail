// x86-64 — Branchless bit-manipulation helpers
//
// Pure utility functions used across multiple instruction files.
// All are branch-free to support formal verification tools (Isla/SMT).

// Branchless POPCNT
val popcount : forall 'n, 0 < 'n & 'n <= 64. bits('n) -> range(0, 'n)
function popcount(v) = {
  let x1 : qword = zero_extend(v);
  let x2 = (x1 & 0x5555555555555555) + ((x1 >> 1)  & 0x5555555555555555);
  let x3 = (x2 & 0x3333333333333333) + ((x2 >> 2)  & 0x3333333333333333);
  let x4 = (x3 & 0x0f0f0f0f0f0f0f0f) + ((x3 >> 4)  & 0x0f0f0f0f0f0f0f0f);
  let x5 = (x4 & 0x00ff00ff00ff00ff) + ((x4 >> 8)  & 0x00ff00ff00ff00ff);
  let x6 = (x5 & 0x0000ffff0000ffff) + ((x5 >> 16) & 0x0000ffff0000ffff);
  let x7 = (x6 & 0x00000000ffffffff) + ((x6 >> 32) & 0x00000000ffffffff);
  let x = unsigned(x7);
  assert(x <= 'n);
  x
}

// or_reduce: 1 if any bit is set, 0 otherwise (branchless tree reduction).
val or_reduce : forall 'n, 0 < 'n & 'n <= 64. bits('n) -> bits(1)
function or_reduce(v) = {
  let x1 : qword = zero_extend(v);
  let x2 = x1 | (x1 >> 1);
  let x3 = x2 | (x2 >> 2);
  let x4 = x3 | (x3 >> 4);
  let x5 = x4 | (x4 >> 8);
  let x6 = x5 | (x5 >> 16);
  let x7 = x6 | (x6 >> 32);
  x7[0]
}

// is_nonzero: 0 if all bits are zero, 1 otherwise.
val is_nonzero : forall 'n, 0 < 'n & 'n <= 64. bits('n) -> bit
function is_nonzero(v) = or_reduce(v)[0]

// is_zero: 1 if all bits are zero, 0 otherwise.
val is_zero : forall 'n, 0 < 'n & 'n <= 64. bits('n) -> bit
function is_zero(v) = (~(or_reduce(v)))[0]

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

// Rounding average: (a + b + 1) >> 1
val avg : forall 'n, 0 < 'n & 'n <= 64. (bits('n), bits('n)) -> bits('n)
function avg(a, b) = {
  let sum : bits('n + 1) = zero_extend(a) + zero_extend(b) + 1;
  sum['n .. 1]
}

// Signed saturation: clamp to target signed range, truncate.
val sat_s8 : forall 'n, 8 < 'n & 'n <= 64. bits('n) -> byte
function sat_s8(x) = {
  let lo : bits('n) = sign_extend(0x80);
  let hi : bits('n) = sign_extend(0x7F);
  min_s(max_s(x, lo), hi)[7..0]
}

val sat_s16 : forall 'n, 16 < 'n & 'n <= 64. bits('n) -> word
function sat_s16(x) = {
  let lo : bits('n) = sign_extend(0x8000);
  let hi : bits('n) = sign_extend(0x7FFF);
  min_s(max_s(x, lo), hi)[15..0]
}

val sat_s32 : forall 'n, 32 < 'n & 'n <= 64. bits('n) -> dword
function sat_s32(x) = {
  let lo : bits('n) = sign_extend(0x80000000);
  let hi : bits('n) = sign_extend(0x7FFFFFFF);
  min_s(max_s(x, lo), hi)[31..0]
}

// Signed-to-unsigned saturation: clamp to [0, max_unsigned], truncate.
val sat_su8 : forall 'n, 8 < 'n & 'n <= 64. bits('n) -> byte
function sat_su8(x) = {
  let hi : bits('n) = zero_extend(0xFF);
  min_s(max_s(x, zeros()), hi)[7..0]
}

val sat_su16 : forall 'n, 16 < 'n & 'n <= 64. bits('n) -> word
function sat_su16(x) = {
  let hi : bits('n) = zero_extend(0xFFFF);
  min_s(max_s(x, zeros()), hi)[15..0]
}

// Unsigned saturation: clamp to target unsigned range, truncate.
val sat_u8 : forall 'n, 8 < 'n & 'n <= 64. bits('n) -> byte
function sat_u8(x) = {
  let hi : bits('n) = zero_extend(0xFF);
  min_u(x, hi)[7..0]
}

val sat_u16 : forall 'n, 16 < 'n & 'n <= 64. bits('n) -> word
function sat_u16(x) = {
  let hi : bits('n) = zero_extend(0xFFFF);
  min_u(x, hi)[15..0]
}

val sat_u32 : forall 'n, 32 < 'n & 'n <= 64. bits('n) -> dword
function sat_u32(x) = {
  let hi : bits('n) = zero_extend(0xFFFFFFFF);
  min_u(x, hi)[31..0]
}

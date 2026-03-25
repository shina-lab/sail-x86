$include "../model/prelude.sail"

val is_gt : forall 'n, 0 < 'n & 'n <= 64. (bits('n), bits('n)) -> bit
function is_gt(a, b) = {
  let diff : bits('n + 1) = sign_extend(b) - sign_extend(a);
  diff['n]
}

val is_gt_u : forall 'n, 0 < 'n & 'n <= 64. (bits('n), bits('n)) -> bit
function is_gt_u(a, b) = {
  let diff : bits('n + 1) = zero_extend(b) - zero_extend(a);
  diff['n]
}

val blend : forall 'n, 0 < 'n. (bits('n), bits('n), bit) -> bits('n)
function blend(a, b, sel) = {
  let m : bits('n) = sign_extend(sel);
  (a & ~(m)) | (b & m)
}

// Proof: ranges comparison — unsigned b >= a_lo ≡ ~(is_gt_u(a_lo, b))
//
// Old code (byte mode, unsigned):
//   bool_to_bit(unsigned(b[(b_lo + 7) .. b_lo]) >= unsigned(a[(a_lo_lo + 7) .. a_lo_lo]))
//
// New code:
//   ~(is_gt_u(lo8, b8))
//
// where b8 = b[(j*8+7)..(j*8)] and lo8 = a[(i*8+7)..(i*8)]

$property
function prop_ge_unsigned_8(x : bits(8), y : bits(8)) -> bool = {
  // ORIGINAL
  let orig : bit = bool_to_bit(unsigned(x) >= unsigned(y));
  // BRANCHLESS — x >= y ≡ ~(y > x)
  let branchless : bit = ~(is_gt_u(y, x));
  orig == branchless
}

$property
function prop_ge_unsigned_16(x : bits(16), y : bits(16)) -> bool = {
  let orig : bit = bool_to_bit(unsigned(x) >= unsigned(y));
  let branchless : bit = ~(is_gt_u(y, x));
  orig == branchless
}

// Proof: ranges comparison — signed b >= a_lo ≡ ~(is_gt(a_lo, b))
//
// Old code (byte mode, signed):
//   bool_to_bit(signed(b[(b_lo + 7) .. b_lo]) >= signed(a[(a_lo_lo + 7) .. a_lo_lo]))
//
// New code:
//   ~(is_gt(lo8, b8))

$property
function prop_ge_signed_8(x : bits(8), y : bits(8)) -> bool = {
  // ORIGINAL
  let orig : bit = bool_to_bit(signed(x) >= signed(y));
  // BRANCHLESS — x >= y ≡ ~(y > x)
  let branchless : bit = ~(is_gt(y, x));
  orig == branchless
}

$property
function prop_ge_signed_16(x : bits(16), y : bits(16)) -> bool = {
  let orig : bit = bool_to_bit(signed(x) >= signed(y));
  let branchless : bit = ~(is_gt(y, x));
  orig == branchless
}

// Proof: ranges comparison — unsigned b <= a_hi ≡ ~(is_gt_u(b, a_hi))
$property
function prop_le_unsigned_8(x : bits(8), y : bits(8)) -> bool = {
  let orig : bit = bool_to_bit(unsigned(x) <= unsigned(y));
  let branchless : bit = ~(is_gt_u(x, y));
  orig == branchless
}

// Proof: ranges comparison — signed b <= a_hi ≡ ~(is_gt(b, a_hi))
$property
function prop_le_signed_8(x : bits(8), y : bits(8)) -> bool = {
  let orig : bit = bool_to_bit(signed(x) <= signed(y));
  let branchless : bit = ~(is_gt(x, y));
  orig == branchless
}

$property
function prop_le_unsigned_16(x : bits(16), y : bits(16)) -> bool = {
  let orig : bit = bool_to_bit(unsigned(x) <= unsigned(y));
  let branchless : bit = ~(is_gt_u(x, y));
  orig == branchless
}

$property
function prop_le_signed_16(x : bits(16), y : bits(16)) -> bool = {
  let orig : bit = bool_to_bit(signed(x) <= signed(y));
  let branchless : bit = ~(is_gt(x, y));
  orig == branchless
}

// Proof: signed/unsigned selection via blend
//
// Old code:
//   if imm8[1] == bitone
//   then bool_to_bit(signed(b) >= signed(a))
//   else bool_to_bit(unsigned(b) >= unsigned(a))
//
// New code:
//   blend(~(is_gt_u(a, b)), ~(is_gt(a, b)), imm8[1])

$property
function prop_signedness_blend_8(x : bits(8), y : bits(8), sel : bits(1)) -> bool = {
  // ORIGINAL — if sel then signed else unsigned
  let orig : bit =
    if sel == bitone
    then bool_to_bit(signed(x) >= signed(y))
    else bool_to_bit(unsigned(x) >= unsigned(y));
  // BRANCHLESS
  let branchless : bit = blend(~(is_gt_u(y, x)), ~(is_gt(y, x)), sel[0]);
  orig == branchless
}

// Proof: blend selects signed/unsigned for >= (byte)
//
// Old:  if imm8[1] == bitone
//       then bool_to_bit(signed(bb) >= signed(ab))
//       else bool_to_bit(unsigned(bb) >= unsigned(ab))
// New:  blend(bool_to_bit(unsigned(bb) >= unsigned(ab)),
//             bool_to_bit(signed(bb) >= signed(ab)), imm8[1])

$property
function prop_blend_ge_8(x : bits(8), y : bits(8), sel : bits(1)) -> bool = {
  let orig : bit =
    if sel == bitone
    then bool_to_bit(signed(x) >= signed(y))
    else bool_to_bit(unsigned(x) >= unsigned(y));
  let branchless : bit = blend(bool_to_bit(unsigned(x) >= unsigned(y)),
                                bool_to_bit(signed(x) >= signed(y)), sel[0]);
  orig == branchless
}

// Proof: blend selects signed/unsigned for >= (word)
$property
function prop_blend_ge_16(x : bits(16), y : bits(16), sel : bits(1)) -> bool = {
  let orig : bit =
    if sel == bitone
    then bool_to_bit(signed(x) >= signed(y))
    else bool_to_bit(unsigned(x) >= unsigned(y));
  let branchless : bit = blend(bool_to_bit(unsigned(x) >= unsigned(y)),
                                bool_to_bit(signed(x) >= signed(y)), sel[0]);
  orig == branchless
}

// Proof: blend selects signed/unsigned for <= (byte)
//
// Old:  if imm8[1] == bitone
//       then bool_to_bit(signed(bb) <= signed(ab))
//       else bool_to_bit(unsigned(bb) <= unsigned(ab))
// New:  blend(bool_to_bit(unsigned(bb) <= unsigned(ab)),
//             bool_to_bit(signed(bb) <= signed(ab)), imm8[1])

$property
function prop_blend_le_8(x : bits(8), y : bits(8), sel : bits(1)) -> bool = {
  let orig : bit =
    if sel == bitone
    then bool_to_bit(signed(x) <= signed(y))
    else bool_to_bit(unsigned(x) <= unsigned(y));
  let branchless : bit = blend(bool_to_bit(unsigned(x) <= unsigned(y)),
                                bool_to_bit(signed(x) <= signed(y)), sel[0]);
  orig == branchless
}

// Proof: blend selects signed/unsigned for <= (word)
$property
function prop_blend_le_16(x : bits(16), y : bits(16), sel : bits(1)) -> bool = {
  let orig : bit =
    if sel == bitone
    then bool_to_bit(signed(x) <= signed(y))
    else bool_to_bit(unsigned(x) <= unsigned(y));
  let branchless : bit = blend(bool_to_bit(unsigned(x) <= unsigned(y)),
                                bool_to_bit(signed(x) <= signed(y)), sel[0]);
  orig == branchless
}

// Proof: range validity masking
//
// Old code:
//   let lo_valid = i < la & j < lb;
//   let hi_valid = (i + 1) < la & j < lb;
//   if lo_valid & hi_valid then {
//     ...compute ge_lo, le_hi...
//     in_range = in_range | (ge_lo & le_hi)
//   }
//
// New code:
//   ...compute ge_lo, le_hi unconditionally...
//   let valid : bit = bool_to_bit(i < la & j < lb & (i + 1) < la);
//   in_range = in_range | (ge_lo & le_hi & valid)

$property
function prop_validity_mask(in_range : bit, ge_lo : bit, le_hi : bit,
                            i_lt_la : bool, j_lt_lb : bool, i1_lt_la : bool) -> bool = {
  // ORIGINAL
  let lo_valid = i_lt_la & j_lt_lb;
  let hi_valid = i1_lt_la & j_lt_lb;
  let orig : bit =
    if lo_valid & hi_valid then in_range | (ge_lo & le_hi)
    else in_range;
  // BRANCHLESS
  let valid : bit = bool_to_bit(i_lt_la & j_lt_lb & i1_lt_la);
  let branchless : bit = in_range | (ge_lo & le_hi & valid);
  orig == branchless
}

// Equivalence proof: bool_to_bit equality → is_eq
//
// Old code:
//   bool_to_bit(a[(a_lo + 7) .. a_lo] == b[(b_lo + 7) .. b_lo])
//
// New code:
//   is_eq(a[(a_lo + 7) .. a_lo], b[(b_lo + 7) .. b_lo])
//
// where is_eq(a, b) = is_zero(a ^ b) = ~(or_reduce(a ^ b))[0]

$include "../model/prelude.sail"

val or_reduce : forall 'n, 0 < 'n & 'n <= 64. bits('n) -> bits(1)
function or_reduce(v) = {
  let x1 : bits(64) = zero_extend(v);
  let x2 = x1 | (x1 >> 1);
  let x3 = x2 | (x2 >> 2);
  let x4 = x3 | (x3 >> 4);
  let x5 = x4 | (x4 >> 8);
  let x6 = x5 | (x5 >> 16);
  let x7 = x6 | (x6 >> 32);
  x7[0]
}

val is_zero : forall 'n, 0 < 'n & 'n <= 64. bits('n) -> bit
function is_zero(v) = (~(or_reduce(v)))[0]

val is_eq : forall 'n, 0 < 'n & 'n <= 64. (bits('n), bits('n)) -> bit
function is_eq(a, b) = is_zero(a ^ b)

$property
function prop_bool_to_bit_eq_8(a : bits(8), b : bits(8)) -> bool = {
  let orig : bit = bool_to_bit(a == b);
  let branchless : bit = is_eq(a, b);
  orig == branchless
}

$property
function prop_bool_to_bit_eq_16(a : bits(16), b : bits(16)) -> bool = {
  let orig : bit = bool_to_bit(a == b);
  let branchless : bit = is_eq(a, b);
  orig == branchless
}

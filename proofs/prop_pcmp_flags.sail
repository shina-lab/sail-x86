// Equivalence proof: PCMPxSTRx flags branch elimination
//
// Old: bool_to_bit(int_res2 != zeros())
// New: is_nonzero(int_res2)
//
// Old: bool_to_bit(lb < (ub + 1))
// New: is_gt_u(to_bits(5, ub + 1), to_bits(5, lb))

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

val is_nonzero : forall 'n, 0 < 'n & 'n <= 64. bits('n) -> bit
function is_nonzero(v) = or_reduce(v)[0]

$property
function prop_cf_nonzero(x : bits(16)) -> bool = {
  let orig : bit = bool_to_bit(x != zeros());
  let branchless : bit = is_nonzero(x);
  orig == branchless
}

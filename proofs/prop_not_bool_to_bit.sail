// Equivalence proof: bool_to_bit(not_bool(x)) ≡ ~(bool_to_bit(x))
//
// Eliminates one branch (not_bool) from the expression.

$include "../model/prelude.sail"

$property
function prop_not_bool_to_bit(x : bool) -> bool = {
  let orig : bit = bool_to_bit(not_bool(x));
  let branchless : bit = ~(bool_to_bit(x));
  orig == branchless
}

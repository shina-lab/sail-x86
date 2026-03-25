// Equivalence proof: equal ordered validity branch elimination
//
// Old code:
//   if a_valid & b_valid then
//     all_match = all_match & bool_res[k * 16 + k_off]
//   else if ~(a_valid) then
//     ()  // needle exhausted, keep all_match unchanged (AND 1)
//   else
//     all_match = bitzero  // haystack exhausted, force false (AND 0)
//
// New code:
//   all_match = all_match & (~(va[k_off]) | (bool_res[k * 16 + k_off] & vb[k]))

$include "../model/prelude.sail"

$property
function prop_equal_ordered(acc : bit, eq : bit, a_valid : bool, b_valid : bool) -> bool = {
  // Old code
  let orig : bit =
    if a_valid & b_valid then acc & eq
    else if ~(a_valid) then acc
    else bitzero;
  // New code
  let av : bit = bool_to_bit(a_valid);
  let bv : bit = bool_to_bit(b_valid);
  let branchless : bit = acc & (~(av) | (eq & bv));
  orig == branchless
}

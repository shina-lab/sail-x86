// Equivalence proof: equal each validity override elimination
//
// Old code:
//   let a_valid = i < la;
//   let b_valid = i < lb;
//   if a_valid & b_valid then
//     int_res1[i] = bool_res[i * 16 + i]
//   else if ~(a_valid) & ~(b_valid) then
//     int_res1[i] = bitone
//   else
//     int_res1[i] = bitzero
//
// New code:
//   int_res1[i] = (bool_res[i * 16 + i] & va[i] & vb[i]) | (~(va[i]) & ~(vb[i]))

$include "../model/prelude.sail"

$property
function prop_equal_each(eq : bit, a_valid : bool, b_valid : bool) -> bool = {
  // Old code
  let orig : bit =
    if a_valid & b_valid then eq
    else if ~(a_valid) & ~(b_valid) then bitone
    else bitzero;
  // New code
  let av : bit = bool_to_bit(a_valid);
  let bv : bit = bool_to_bit(b_valid);
  let branchless : bit = (eq & av & bv) | (~(av) & ~(bv));
  orig == branchless
}

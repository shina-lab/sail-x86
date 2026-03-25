// Equivalence proof: equal any validity branch elimination
//
// Old code:
//   if i < la & j < lb then
//     any_match = any_match | bool_res[j * 16 + i]
//
// New code:
//   let valid : bit = va[i] & vb[j];
//   any_match = any_match | (bool_res[j * 16 + i] & valid)
//
// where va = ~(0xFFFF << la), vb = ~(0xFFFF << lb)

$include "../model/prelude.sail"

$property
function prop_equal_any_validity(acc : bit, v : bit, i_lt_la : bool, j_lt_lb : bool) -> bool = {
  // Old code
  let orig : bit =
    if i_lt_la & j_lt_lb then acc | v
    else acc;
  // New code
  let valid : bit = bool_to_bit(i_lt_la) & bool_to_bit(j_lt_lb);
  let branchless : bit = acc | (v & valid);
  orig == branchless
}

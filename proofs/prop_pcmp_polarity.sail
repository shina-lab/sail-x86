// Equivalence proof: masked negative polarity branch elimination
//
// Old code:
//   var r : bits(16) = int_res1;
//   foreach (i from 0 to 15) {
//     if i <= ub & i < lb then
//       r[i] = ~(int_res1[i])
//   };
//   r
//
// New code (for ub=7):
//   int_res1 ^ (vb & 0x00FF)
//
// New code (for ub=15):
//   int_res1 ^ vb
//
// where vb = ~(0xFFFF << lb)
//
// This works because XOR with 1 flips a bit, XOR with 0 keeps it.

$include "../model/prelude.sail"

// Prove for a single bit position
$property
function prop_masked_neg_bit(x : bit, should_flip : bool) -> bool = {
  // Old: if should_flip then ~(x) else x
  let orig : bit = if should_flip then ~(x) else x;
  // New: x XOR flip_bit
  let branchless : bit = x ^ bool_to_bit(should_flip);
  orig == branchless
}

// Prove vb[i] == bool_to_bit(i < lb) is already in prop_pcmp_ranges_full.sail
// (prop_validity_bit). So vb & ub_mask gives exactly the flip mask.

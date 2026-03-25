// Equivalence proof: validity bitmask for PCMPxSTRx ranges aggregation
//
// Step 4: Replace bool_to_bit validity with precomputed bitmask.
//
// Old code:
//   let valid : bit = bool_to_bit(i < la & j < lb & (i + 1) < la);
//
// New code:
//   let va : bits(16) = ~(0xFFFF << la);
//   let vb : bits(16) = ~(0xFFFF << lb);
//   ...
//   let valid : bit = va[i] & va[i + 1] & vb[j];

$include "../model/prelude.sail"

// Core lemma: bit i of ~(0xFFFF << n) is set iff i < n
$property
function prop_validity_bit(n : bits(5), i : bits(4)) -> bool = {
  let n_int = unsigned(n);
  let i_int = unsigned(i);
  let mask : bits(16) = ~(0xFFFF << n_int);
  if i_int <= 15 then
    mask[i_int] == bool_to_bit(i_int < n_int)
  else true
}

// Full validity: old bool_to_bit expression == new bitmask expression
$property
function prop_validity_combined(la : bits(5), lb : bits(5), i : bits(4), j : bits(4)) -> bool = {
  let la_int = unsigned(la);
  let lb_int = unsigned(lb);
  let i_int = unsigned(i);
  let j_int = unsigned(j);
  if i_int <= 14 & j_int <= 15 then {
    let va : bits(16) = ~(0xFFFF << la_int);
    let vb : bits(16) = ~(0xFFFF << lb_int);
    // Old code
    let orig : bit = bool_to_bit(i_int < la_int & j_int < lb_int & (i_int + 1) < la_int);
    // New code
    let branchless : bit = va[i_int] & va[i_int + 1] & vb[j_int];
    orig == branchless
  } else true
}

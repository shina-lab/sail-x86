$include "../model/prelude.sail"

// Nonzero detection: if x != zeros() then bitone else bitzero
// Branchless: ~(((0b0 @ x) - 1)[N..N]) where N = width of x

$property
function prop_nonzero_25(x : bits(25)) -> bool = {
  let orig : bits(1) = if x != zeros() then 0b1 else 0b0;
  let wide : bits(26) = (0b0 @ x) - 1;
  let branchless : bits(1) = ~(wide[25..25]);
  orig == branchless
}

$property
function prop_nonzero_12(x : bits(12)) -> bool = {
  let orig : bits(1) = if x != zeros() then 0b1 else 0b0;
  let wide : bits(13) = (0b0 @ x) - 1;
  let branchless : bits(1) = ~(wide[12..12]);
  orig == branchless
}

// Equivalence proof: branchless VERR/VERW bit selection
// VERR: readable = if is_code then R_bit else 1  ≡  R_bit | ~(is_code)
// VERW: writable = if is_code then 0 else W_bit  ≡  W_bit & ~(is_code)

$include "../model/prelude.sail"

$property
function prop_verr(is_code : bit, r_bit : bit) -> bool = {
  let orig : bit = if is_code == bitone then r_bit else bitone;
  let branchless : bit = r_bit | ~(is_code);
  orig == branchless
}

$property
function prop_verw(is_code : bit, w_bit : bit) -> bool = {
  let orig : bit = if is_code == bitone then bitzero else w_bit;
  let branchless : bit = w_bit & ~(is_code);
  orig == branchless
}

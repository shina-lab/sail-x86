// Equivalence proof: branchless REX register index extension
//
// Original: if rex == bitone then r + 8 else r
// Branchless: r + 8 * unsigned(zero_extend(rex) : bits(4))

$include "../model/prelude.sail"

$property
function prop_rex_reg_idx(rex : bit, r : bits(3)) -> bool = {
  let base : int = unsigned(r);
  let orig : int = if rex == bitone then base + 8 else base;
  let branchless : int = base + 8 * unsigned(zero_extend(rex) : bits(4));
  orig == branchless
}

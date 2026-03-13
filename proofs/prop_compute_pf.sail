// Equivalence proof: branchless compute_PF
// Old: bool_to_bit(p == bitzero) where p is XOR of 8 individual bits
// New: tree-reduce XOR as bits(1), then invert with ~

$include "../model/prelude.sail"

// Original (branching) — uses bool_to_bit on equality test
val compute_PF_orig : bits(8) -> bit
function compute_PF_orig(val8) = {
  let p = val8[0] ^ val8[1] ^ val8[2] ^ val8[3] ^
          val8[4] ^ val8[5] ^ val8[6] ^ val8[7];
  // PF=1 means even parity, so invert
  bool_to_bit(p == bitzero)
}

// New (branchless) — tree reduction in bits(1) domain
val compute_PF_branchless : bits(8) -> bit
function compute_PF_branchless(val8) = {
  let r4 : bits(4) = val8[7..4] ^ val8[3..0];
  let r2 : bits(2) = r4[3..2] ^ r4[1..0];
  let r1 : bits(1) = r2[1..1] ^ r2[0..0];
  (~(r1))[0]
}

$property
function prop_compute_PF(val8 : bits(8)) -> bool =
  compute_PF_orig(val8) == compute_PF_branchless(val8)

// Equivalence proof: RDRAND/RDSEED branchless conversion
//
// Old: if cf == 1 then dest = rnd else dest = zeros()
// New: dest = rnd & sign_extend(cf)
//
// cf=1: sign_extend(1) = all-ones, AND is identity → rnd
// cf=0: sign_extend(0) = all-zeros, AND zeroes out → zeros()

$include "../model/prelude.sail"

$property
function prop_rdrand(rnd : bits(32), cf : bit) -> bool = {
  let orig : bits(32) = if cf == 0b1 then rnd else zeros();
  let m : bits(32) = sign_extend(cf);
  let branchless : bits(32) = rnd & m;
  orig == branchless
}

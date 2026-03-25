// Equivalence proof: PCLMULQDQ branch elimination
//
// Old code:
//   if x[i] == bitone then
//     result = result ^ (zero_extend(y) << i)
//
// New code:
//   result = result ^ ((zero_extend(y) << i) & sign_extend(x[i]))
//
// When x[i]=1: sign_extend(1) = all-ones, AND is identity, XOR applies
// When x[i]=0: sign_extend(0) = all-zeros, AND zeroes out, XOR is no-op

$include "../model/prelude.sail"

$property
function prop_pclmul_step(acc : bits(128), shifted : bits(128), sel : bit) -> bool = {
  // Old: if sel == bitone then acc ^ shifted else acc
  let orig : bits(128) =
    if sel == bitone then acc ^ shifted
    else acc;
  // New: acc ^ (shifted & sign_extend(sel))
  let mask : bits(128) = sign_extend(sel);
  let branchless : bits(128) = acc ^ (shifted & mask);
  orig == branchless
}

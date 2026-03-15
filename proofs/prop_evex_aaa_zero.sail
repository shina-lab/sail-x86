// Equivalence proof: branchless evex_aaa == 0 check
//
// Original: bool_to_bit(pfx.evex_aaa == 0)
// Branchless: (~(or_reduce_8(zero_extend(to_bits(3, pfx.evex_aaa)))))[0]

$include "../model/prelude.sail"

val or_reduce_8 : bits(8) -> bits(1)
function or_reduce_8(v) = {
  let r4 : bits(4) = v[7..4] | v[3..0];
  let r2 : bits(2) = r4[3..2] | r4[1..0];
  r2[1..1] | r2[0..0]
}

$property
function prop_evex_aaa_zero(aaa : bits(3)) -> bool = {
  let val_r : range(0, 7) = unsigned(aaa);
  let orig : bit = bool_to_bit(val_r == 0);
  let branchless : bit = (~(or_reduce_8(zero_extend(aaa))))[0];
  orig == branchless
}

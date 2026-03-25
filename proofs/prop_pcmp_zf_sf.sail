// Equivalence proof: PCMPxSTRx ZF/SF flag bool_to_bit elimination
//
// Old: bool_to_bit(lb < (ub + 1))
// New: is_gt_u(to_bits(5, ub + 1), to_bits(5, lb))
//
// Both lb and ub+1 fit in 5 bits (range 0..16), so unsigned comparison works.

$include "../model/prelude.sail"

val is_gt_u5 : (bits(5), bits(5)) -> bit
function is_gt_u5(a, b) = {
  let diff : bits(6) = zero_extend(b) - zero_extend(a);
  diff[5]
}

$property
function prop_zf_sf(lb : bits(5), ub_plus_1 : bits(5)) -> bool = {
  let lb_int = unsigned(lb);
  let ub1_int = unsigned(ub_plus_1);
  if lb_int <= 16 & ub1_int <= 16 then {
    let orig : bit = bool_to_bit(lb_int < ub1_int);
    let branchless : bit = is_gt_u5(ub_plus_1, lb);
    orig == branchless
  } else true
}

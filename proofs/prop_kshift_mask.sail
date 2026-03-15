// Equivalence proof: branchless KSHIFT mask selection
//
// Original: let mask : qword = if pfx.vex_w then WIDE else NARROW
// Branchless: let w_mask : qword = zeros() - zero_extend(bool_to_bit(pfx.vex_w));
//             let mask : qword = (DIFF & w_mask) | NARROW

$include "../model/prelude.sail"

// KSHIFTR/LW/B: if vex_w then 0x000000000000FFFF else 0x00000000000000FF
$property
function prop_kshift_wb(vex_w : bool) -> bool = {
  let orig : bits(64) = if vex_w then 0x000000000000FFFF else 0x00000000000000FF;
  let w_mask : bits(64) = zeros() - zero_extend(bool_to_bit(vex_w));
  let branchless : bits(64) = (0x000000000000FF00 & w_mask) | 0x00000000000000FF;
  orig == branchless
}

// KSHIFTR/LD/Q: if vex_w then 0xFFFFFFFFFFFFFFFF else 0x00000000FFFFFFFF
$property
function prop_kshift_dq(vex_w : bool) -> bool = {
  let orig : bits(64) = if vex_w then 0xFFFFFFFFFFFFFFFF else 0x00000000FFFFFFFF;
  let w_mask : bits(64) = zeros() - zero_extend(bool_to_bit(vex_w));
  let branchless : bits(64) = (0xFFFFFFFF00000000 & w_mask) | 0x00000000FFFFFFFF;
  orig == branchless
}

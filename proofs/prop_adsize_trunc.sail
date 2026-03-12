$include "../model/prelude.sail"

// Prove: branchless address-size truncation
// Pattern: if has_adsize then zero_extend(ea[31..0]) else ea
//        → ea & (no_trunc | 0x00000000FFFFFFFF)
// where no_trunc = zeros() - zero_extend(bool_to_bit(not_bool(has_adsize)))

$property
function prop_adsize_trunc(ea : bits(64), has_adsize : bool) -> bool = {
  let orig : bits(64) = if has_adsize then zero_extend(ea[31..0]) else ea;
  let no_trunc : bits(64) = zeros() - zero_extend(bool_to_bit(not_bool(has_adsize)));
  let mask : bits(64) = no_trunc | 0x00000000FFFFFFFF;
  let branchless : bits(64) = ea & mask;
  orig == branchless
}

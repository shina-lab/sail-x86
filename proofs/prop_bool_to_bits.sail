$include "../model/prelude.sail"

// Test: can zero_extend accept bool_to_bit output?
$property
function prop_bool_to_qword(a : bits(8), b : bits(8)) -> bool = {
  let cond : bool = unsigned(a) > unsigned(b);
  let orig : bits(64) = if cond then 0x0000000000000001 else zeros();
  let branchless : bits(64) = zero_extend(bool_to_bit(cond));
  orig == branchless
}

// Test: bool-to-mask via subtraction
$property
function prop_bool_to_mask32(a : bits(8), b : bits(8)) -> bool = {
  let cond : bool = unsigned(a) > unsigned(b);
  let orig : bits(32) = if cond then ones() else zeros();
  let branchless : bits(32) = zeros() - zero_extend(bool_to_bit(cond));
  orig == branchless
}

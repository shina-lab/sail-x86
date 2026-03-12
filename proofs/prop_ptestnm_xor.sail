$include "../model/prelude.sail"

// Prove: if is_negate then ~mask else mask  ≡  mask ^ negate_mask
// where negate_mask = zeros() - zero_extend(bool_to_bit(is_negate))

$property
function prop_ptestnm_xor_byte(mask : bits(8), is_negate : bool) -> bool = {
  let orig : bits(8) = if is_negate then not_vec(mask) else mask;
  let negate_mask : bits(8) = zeros() - zero_extend(bool_to_bit(is_negate));
  let branchless : bits(8) = mask ^ negate_mask;
  orig == branchless
}

$property
function prop_ptestnm_xor_word(mask : bits(16), is_negate : bool) -> bool = {
  let orig : bits(16) = if is_negate then not_vec(mask) else mask;
  let negate_mask : bits(16) = zeros() - zero_extend(bool_to_bit(is_negate));
  let branchless : bits(16) = mask ^ negate_mask;
  orig == branchless
}

$property
function prop_ptestnm_xor_dword(mask : bits(32), is_negate : bool) -> bool = {
  let orig : bits(32) = if is_negate then not_vec(mask) else mask;
  let negate_mask : bits(32) = zeros() - zero_extend(bool_to_bit(is_negate));
  let branchless : bits(32) = mask ^ negate_mask;
  orig == branchless
}

$property
function prop_ptestnm_xor_qword(mask : bits(64), is_negate : bool) -> bool = {
  let orig : bits(64) = if is_negate then not_vec(mask) else mask;
  let negate_mask : bits(64) = zeros() - zero_extend(bool_to_bit(is_negate));
  let branchless : bits(64) = mask ^ negate_mask;
  orig == branchless
}

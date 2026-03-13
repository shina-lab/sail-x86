// Proof: branchless ZF using borrow from (0b0 @ result) - 1
$include "../model/prelude.sail"

$property
function prop_zf_borrow_8(result : bits(8)) -> bool = {
  let orig : bit = bool_to_bit(result == zeros());
  let wide : bits(9) = (0b0 @ result) - 1;
  let branchless : bit = wide[8];
  orig == branchless
}

$property
function prop_zf_borrow_16(result : bits(16)) -> bool = {
  let orig : bit = bool_to_bit(result == zeros());
  let wide : bits(17) = (0b0 @ result) - 1;
  let branchless : bit = wide[16];
  orig == branchless
}

$property
function prop_zf_borrow_32(result : bits(32)) -> bool = {
  let orig : bit = bool_to_bit(result == zeros());
  let wide : bits(33) = (0b0 @ result) - 1;
  let branchless : bit = wide[32];
  orig == branchless
}

$property
function prop_zf_borrow_64(result : bits(64)) -> bool = {
  let orig : bit = bool_to_bit(result == zeros());
  let wide : bits(65) = (0b0 @ result) - 1;
  let branchless : bit = wide[64];
  orig == branchless
}

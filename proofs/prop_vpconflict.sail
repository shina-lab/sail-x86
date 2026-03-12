default Order dec

$include <prelude.sail>

overload operator - = {sub_bits}
overload operator + = {add_bits}
overload operator ^ = {xor_vec}
overload operator & = {and_vec, and_bool}
overload operator | = {or_vec}
overload zeros = {sail_zeros}

val bool_to_bit : bool -> bit
function bool_to_bit(b) = if b then bitone else bitzero

// Prove: mask[j] = bool_to_bit(j < i & elem_i == elem_j) is equivalent to
// the original nested-if conditional OR with shifted 1-bit.

// For dword with 4 elements: prove the full mask matches.
// We hardcode the shifted constants to avoid needing << operator.
$property
function prop_vpconflictd_element(elem_i : bits(32), e0 : bits(32), e1 : bits(32), e2 : bits(32), e3 : bits(32), i_bits : bits(2)) -> bool = {
  let i : range(0, 3) = unsigned(i_bits);

  // Original: conditional OR accumulation
  var mask_orig : bits(32) = 0x00000000;
  if 0 < i then { if elem_i == e0 then mask_orig = mask_orig | 0x00000001 };
  if 1 < i then { if elem_i == e1 then mask_orig = mask_orig | 0x00000002 };
  if 2 < i then { if elem_i == e2 then mask_orig = mask_orig | 0x00000004 };
  if 3 < i then { if elem_i == e3 then mask_orig = mask_orig | 0x00000008 };

  // Branchless: direct bit assignment
  var mask_new : bits(32) = 0x00000000;
  mask_new[0] = bool_to_bit(0 < i & elem_i == e0);
  mask_new[1] = bool_to_bit(1 < i & elem_i == e1);
  mask_new[2] = bool_to_bit(2 < i & elem_i == e2);
  mask_new[3] = bool_to_bit(3 < i & elem_i == e3);

  mask_orig == mask_new
}

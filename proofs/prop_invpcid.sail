$include "../model/prelude.sail"

// INVPCID descriptor validation: replace bool_to_bit with branchless ops.
// inv_type is known to be 0-3 (checked earlier), so only low 2 bits matter.

$property
function prop_invpcid_fault(inv_type : bits(2), reserved : bits(52), top17 : bits(17)) -> bool = {
  // Original (branching via bool_to_bit)
  let orig_01 : bits(1) = bool_to_bit(unsigned(inv_type) <= 1);
  let orig_0 : bits(1) = bool_to_bit(inv_type == 0b00);
  let orig_bad : bits(1) = bool_to_bit(reserved != zeros());
  let orig_nc : bits(1) = bool_to_bit(top17 != zeros() & top17 != ones());
  let orig : bits(1) = (orig_01 & orig_bad) | (orig_0 & orig_nc);

  // Branchless
  let is_type_01 : bits(1) = ~(inv_type[1..1]);
  let is_type_0 : bits(1) = ~(inv_type[1..1] | inv_type[0..0]);
  let bad_reserved : bits(1) = ~(((0b0 @ reserved) - 1)[52..52]);
  // non-canonical: top17 bits not all the same. XOR with sign-extend of MSB
  // gives zero iff all bits match MSB (canonical).
  let diff : bits(17) = top17 ^ sign_extend(top17[16..16]);
  let non_canonical : bits(1) = ~(((0b0 @ diff) - 1)[17..17]);
  let branchless : bits(1) = (is_type_01 & bad_reserved) | (is_type_0 & non_canonical);

  orig == branchless
}

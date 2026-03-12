$include "../model/prelude.sail"

// Prove that logical shifts on 16-bit values produce zeros when shift >= 16.

$property
function prop_kshiftr_16(src : bits(16), shift_bits : bits(8)) -> bool = {
  let shift : range(0, 255) = unsigned(shift_bits);
  let orig : bits(16) = if shift >= 16 then zeros() else sail_shiftright(src, shift);
  let branchless : bits(16) = sail_shiftright(src, shift);
  orig == branchless
}

$property
function prop_kshiftl_16(src : bits(16), shift_bits : bits(8)) -> bool = {
  let shift : range(0, 255) = unsigned(shift_bits);
  let orig : bits(16) = if shift >= 16 then zeros() else sail_shiftleft(src, shift);
  let branchless : bits(16) = sail_shiftleft(src, shift);
  orig == branchless
}

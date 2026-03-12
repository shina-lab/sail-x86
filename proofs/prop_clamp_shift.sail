$include "../model/prelude.sail"

// Prove: branchless bitvector clamp_shift_count == branchy int version
// Original: clamp_shift_count(unsigned(raw)) where
//   clamp_shift_count(c) = if c > 255 then 255 else if c < 0 then 0 else c
// New: clamp_shift_bv64(raw) using saturation mask

val clamp_shift_count_orig : int -> range(0, 255)
function clamp_shift_count_orig(c) = {
  let r : range(0, 255) = if c > 255 then 255 else if c < 0 then 0 else c;
  r
}

val clamp_shift_bv64 : bits(64) -> range(0, 255)
function clamp_shift_bv64(raw) = {
  let hi_nonzero : bit = bool_to_bit(raw[63..8] != zeros());
  let sat_mask : bits(8) = zeros() - zero_extend(hi_nonzero);
  unsigned(raw[7..0] | sat_mask)
}

$property
function prop_clamp_shift(raw : bits(64)) -> bool =
  clamp_shift_count_orig(unsigned(raw)) == clamp_shift_bv64(raw)

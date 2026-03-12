$include "../model/prelude.sail"

// --- Branchless helpers (textually identical to model code) ---

val max_u8 : (bits(8), bits(8)) -> bits(8)
function max_u8(a, b) = {
  let diff : bits(9) = (0b0 @ a) - (0b0 @ b);
  let mask : bits(8) = zeros() - zero_extend(diff[8..8]);
  (b & mask) | (a & ~(mask))
}

val min_u8 : (bits(8), bits(8)) -> bits(8)
function min_u8(a, b) = {
  let diff : bits(9) = (0b0 @ a) - (0b0 @ b);
  let mask : bits(8) = zeros() - zero_extend(diff[8..8]);
  (a & mask) | (b & ~(mask))
}

// ================================================================
// Proof: abs_diff8 using max_u8/min_u8 matches branchy version
// ================================================================

$property
function prop_abs_diff8(a : bits(8), b : bits(8)) -> bool = {
  let diff : int = unsigned(a) - unsigned(b);
  let orig : int = if diff < 0 then negate(diff) else diff;
  let branchless : int = unsigned(max_u8(a, b) - min_u8(a, b));
  orig == branchless
}

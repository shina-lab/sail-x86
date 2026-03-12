$include "../model/prelude.sail"

// Prove: branchless EVEX k-mask merging
// Pattern: if aaa == 0 then X else X & kreg  →  X & (no_mask | kreg)
// where no_mask = zeros() - zero_extend(bool_to_bit(aaa == 0))

// Variant 1: mask needs zero_extend (byte → qword)
$property
function prop_evex_kmask_byte(mask : bits(8), kreg_val : bits(64), aaa_zero : bool) -> bool = {
  let orig : bits(64) = if aaa_zero then zero_extend(mask) else zero_extend(mask) & kreg_val;
  let no_mask : bits(64) = zeros() - zero_extend(bool_to_bit(aaa_zero));
  let branchless : bits(64) = zero_extend(mask) & (no_mask | kreg_val);
  orig == branchless
}

// Variant 2: mask needs zero_extend (word → qword)
$property
function prop_evex_kmask_word(mask : bits(16), kreg_val : bits(64), aaa_zero : bool) -> bool = {
  let orig : bits(64) = if aaa_zero then zero_extend(mask) else zero_extend(mask) & kreg_val;
  let no_mask : bits(64) = zeros() - zero_extend(bool_to_bit(aaa_zero));
  let branchless : bits(64) = zero_extend(mask) & (no_mask | kreg_val);
  orig == branchless
}

// Variant 3: mask needs zero_extend (dword → qword)
$property
function prop_evex_kmask_dword(mask : bits(32), kreg_val : bits(64), aaa_zero : bool) -> bool = {
  let orig : bits(64) = if aaa_zero then zero_extend(mask) else zero_extend(mask) & kreg_val;
  let no_mask : bits(64) = zeros() - zero_extend(bool_to_bit(aaa_zero));
  let branchless : bits(64) = zero_extend(mask) & (no_mask | kreg_val);
  orig == branchless
}

// Variant 4: mask is already qword
$property
function prop_evex_kmask_qword(mask : bits(64), kreg_val : bits(64), aaa_zero : bool) -> bool = {
  let orig : bits(64) = if aaa_zero then mask else mask & kreg_val;
  let no_mask : bits(64) = zeros() - zero_extend(bool_to_bit(aaa_zero));
  let branchless : bits(64) = mask & (no_mask | kreg_val);
  orig == branchless
}

// Variant 5: ones() pattern (read effective mask)
$property
function prop_evex_kmask_ones(kreg_val : bits(64), aaa_zero : bool) -> bool = {
  let orig : bits(64) = if aaa_zero then ones() else kreg_val;
  let no_mask : bits(64) = zeros() - zero_extend(bool_to_bit(aaa_zero));
  let branchless : bits(64) = no_mask | kreg_val;
  orig == branchless
}

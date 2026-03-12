$include "../model/prelude.sail"

// Prove: branchless zeroing-merge initialization
// Pattern: if zeroing then zeros() else old_dst
//        → old_dst & (zeros() - zero_extend(bool_to_bit(not_bool(zeroing))))

$property
function prop_zeroing_merge_128(old_dst : bits(128), zeroing : bool) -> bool = {
  let orig : bits(128) = if zeroing then zeros() else old_dst;
  let keep_mask : bits(128) = zeros() - zero_extend(bool_to_bit(not_bool(zeroing)));
  let branchless : bits(128) = old_dst & keep_mask;
  orig == branchless
}

$property
function prop_zeroing_merge_256(old_dst : bits(256), zeroing : bool) -> bool = {
  let orig : bits(256) = if zeroing then zeros() else old_dst;
  let keep_mask : bits(256) = zeros() - zero_extend(bool_to_bit(not_bool(zeroing)));
  let branchless : bits(256) = old_dst & keep_mask;
  orig == branchless
}

$property
function prop_zeroing_merge_512(old_dst : bits(512), zeroing : bool) -> bool = {
  let orig : bits(512) = if zeroing then zeros() else old_dst;
  let keep_mask : bits(512) = zeros() - zero_extend(bool_to_bit(not_bool(zeroing)));
  let branchless : bits(512) = old_dst & keep_mask;
  orig == branchless
}

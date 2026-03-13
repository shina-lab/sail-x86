// Equivalence proof: branchless CMOVcc via mask blend
// Pattern: if cond then src else dst ≡ (src & mask) | (dst & ~mask)
// where mask = zeros() - zero_extend(cond_bit)

$include "../model/prelude.sail"

// 8-bit
$property
function prop_cmovcc_8(src : bits(8), dst : bits(8), cond : bit) -> bool = {
  let orig : bits(8) = if cond == bitone then src else dst;
  let mask : bits(8) = zeros() - zero_extend(cond);
  let branchless : bits(8) = (src & mask) | (dst & ~(mask));
  orig == branchless
}

// 16-bit
$property
function prop_cmovcc_16(src : bits(16), dst : bits(16), cond : bit) -> bool = {
  let orig : bits(16) = if cond == bitone then src else dst;
  let mask : bits(16) = zeros() - zero_extend(cond);
  let branchless : bits(16) = (src & mask) | (dst & ~(mask));
  orig == branchless
}

// 32-bit
$property
function prop_cmovcc_32(src : bits(32), dst : bits(32), cond : bit) -> bool = {
  let orig : bits(32) = if cond == bitone then src else dst;
  let mask : bits(32) = zeros() - zero_extend(cond);
  let branchless : bits(32) = (src & mask) | (dst & ~(mask));
  orig == branchless
}

// 64-bit
$property
function prop_cmovcc_64(src : bits(64), dst : bits(64), cond : bit) -> bool = {
  let orig : bits(64) = if cond == bitone then src else dst;
  let mask : bits(64) = zeros() - zero_extend(cond);
  let branchless : bits(64) = (src & mask) | (dst & ~(mask));
  orig == branchless
}

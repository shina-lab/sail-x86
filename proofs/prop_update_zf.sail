// Equivalence proof: branchless ZF computation
// Old: bool_to_bit(result == zeros())
// New: ~(or_reduce) — already-proven branchless tree reduction

$include "../model/prelude.sail"

// or_reduce functions (from types.sail)
val or_reduce_8 : bits(8) -> bits(1)
function or_reduce_8(v) = {
  let r4 : bits(4) = v[7..4] | v[3..0];
  let r2 : bits(2) = r4[3..2] | r4[1..0];
  r2[1..1] | r2[0..0]
}

val or_reduce_16 : bits(16) -> bits(1)
function or_reduce_16(v) = or_reduce_8(v[15..8] | v[7..0])

val or_reduce_32 : bits(32) -> bits(1)
function or_reduce_32(v) = or_reduce_16(v[31..16] | v[15..0])

val or_reduce_64 : bits(64) -> bits(1)
function or_reduce_64(v) = or_reduce_32(v[63..32] | v[31..0])

$property
function prop_zf_8(result : bits(8)) -> bool = {
  let orig : bit = bool_to_bit(result == zeros());
  let branchless : bit = (~(or_reduce_8(result)))[0];
  orig == branchless
}

$property
function prop_zf_16(result : bits(16)) -> bool = {
  let orig : bit = bool_to_bit(result == zeros());
  let branchless : bit = (~(or_reduce_16(result)))[0];
  orig == branchless
}

$property
function prop_zf_32(result : bits(32)) -> bool = {
  let orig : bit = bool_to_bit(result == zeros());
  let branchless : bit = (~(or_reduce_32(result)))[0];
  orig == branchless
}

$property
function prop_zf_64(result : bits(64)) -> bool = {
  let orig : bit = bool_to_bit(result == zeros());
  let branchless : bit = (~(or_reduce_64(result)))[0];
  orig == branchless
}

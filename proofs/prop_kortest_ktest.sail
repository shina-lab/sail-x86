// Equivalence proof: branchless KORTEST/KTEST flag computation
//
// Original: ZF = bool_to_bit(result == zeros())
// Branchless: ZF = (~(or_reduce_64(result)))[0]
//
// Original: CF = bool_to_bit(result == mask)
// Branchless: CF = (~(or_reduce_64(result ^ mask)))[0]

$include "../model/prelude.sail"

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

// KORTEST ZF: bool_to_bit(result == zeros()) ≡ (~(or_reduce_64(result)))[0]
$property
function prop_kortest_zf(result : bits(64)) -> bool = {
  let orig : bit = bool_to_bit(result == zeros());
  let branchless : bit = (~(or_reduce_64(result)))[0];
  orig == branchless
}

// KORTEST CF: bool_to_bit(result == mask) ≡ (~(or_reduce_64(result ^ mask)))[0]
$property
function prop_kortest_cf(result : bits(64), mask : bits(64)) -> bool = {
  let orig : bit = bool_to_bit(result == mask);
  let branchless : bit = (~(or_reduce_64(result ^ mask)))[0];
  orig == branchless
}

// KTEST ZF: bool_to_bit((v1 & v2) == zeros()) ≡ (~(or_reduce_64(v1 & v2)))[0]
$property
function prop_ktest_zf(v1 : bits(64), v2 : bits(64)) -> bool = {
  let orig : bit = bool_to_bit((v1 & v2) == zeros());
  let branchless : bit = (~(or_reduce_64(v1 & v2)))[0];
  orig == branchless
}

// KTEST CF: bool_to_bit((~(v1) & v2 & mask) == zeros()) ≡ (~(or_reduce_64(~(v1) & v2 & mask)))[0]
$property
function prop_ktest_cf(v1 : bits(64), v2 : bits(64), mask : bits(64)) -> bool = {
  let orig : bit = bool_to_bit((~(v1) & v2 & mask) == zeros());
  let branchless : bit = (~(or_reduce_64(~(v1) & v2 & mask)))[0];
  orig == branchless
}

// Equivalence proofs for branchless PTEST/VPTEST zero checks
// Pattern: bool_to_bit(x == zeros()) → (~(or_reduce(folded)))[0]

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

// 128-bit zero check: fold to 64-bit then or_reduce
$property
function prop_ptest_zf_128(x : bits(128)) -> bool = {
  let orig : bit = bool_to_bit(x == zeros());
  let branchless : bit = (~(or_reduce_64(x[127..64] | x[63..0])))[0];
  orig == branchless
}

// 256-bit zero check
$property
function prop_ptest_zf_256(x : bits(256)) -> bool = {
  let orig : bit = bool_to_bit(x == zeros());
  let folded : bits(64) = x[255..192] | x[191..128] | x[127..64] | x[63..0];
  let branchless : bit = (~(or_reduce_64(folded)))[0];
  orig == branchless
}

// 16-bit zero check (KTEST)
$property
function prop_ktest_zf_16(x : bits(16)) -> bool = {
  let orig : bit = bool_to_bit(x == zeros());
  let branchless : bit = (~(or_reduce_16(x)))[0];
  orig == branchless
}

// 16-bit all-ones check (KORTEST)
$property
function prop_kortest_cf_16(x : bits(16)) -> bool = {
  let orig : bit = bool_to_bit(x == ones());
  let branchless : bit = (~(or_reduce_16(~(x))))[0];
  orig == branchless
}

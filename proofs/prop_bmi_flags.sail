// Equivalence proofs for BMI flag branchless conversions
// Pattern 1: bool_to_bit(bit == bitone) ≡ bit (identity)
// Pattern 2: bool_to_bit(x == zeros()) via or_reduce (already proven elsewhere)
// Pattern 3: bool_to_bit(x != zeros()) via or_reduce (already proven elsewhere)

$include "../model/prelude.sail"

// SF pattern: bool_to_bit(result[63] == bitone) ≡ result[63]
$property
function prop_sf_bit_identity(x : bit) -> bool = {
  let orig : bit = bool_to_bit(x == bitone);
  orig == x
}

// ZF 64-bit: bool_to_bit(result == zeros()) via or_reduce
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

// ZF 64-bit zero check
$property
function prop_bmi_zf_64(x : bits(64)) -> bool = {
  let orig : bit = bool_to_bit(x == zeros());
  let branchless : bit = (~(or_reduce_64(x)))[0];
  orig == branchless
}

// ZF 32-bit zero check
$property
function prop_bmi_zf_32(x : bits(32)) -> bool = {
  let orig : bit = bool_to_bit(x == zeros());
  let branchless : bit = (~(or_reduce_32(x)))[0];
  orig == branchless
}

// CF nonzero check (BLSI): bool_to_bit(x != zeros()) via or_reduce
$property
function prop_bmi_cf_nonzero_64(x : bits(64)) -> bool = {
  let orig : bit = bool_to_bit(x != zeros());
  let branchless : bit = (or_reduce_64(x))[0];
  orig == branchless
}

$property
function prop_bmi_cf_nonzero_32(x : bits(32)) -> bool = {
  let orig : bit = bool_to_bit(x != zeros());
  let branchless : bit = (or_reduce_32(x))[0];
  orig == branchless
}

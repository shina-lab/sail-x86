// Equivalence proofs: bitvector comparison → branchless bit ops
//
// Pattern 1: bool_to_bit(a == b) ≡ (~(or_reduce(a ^ b)))[0]  (already proven)
// Pattern 2: bool_to_bit(a != b) ≡ (or_reduce(a ^ b))[0]
// Pattern 3: bool_to_bit(a != zeros()) ≡ (or_reduce(a))[0]
// Pattern 4: bool_to_bit(x == bitone) ≡ x  (where x : bit)
// Pattern 5: bool_to_bit(x == bitzero) ≡ ~(x)

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

// Pattern 2: bool_to_bit(a != b) ≡ (or_reduce_8(a ^ b))[0]
$property
function prop_neq_8(a : bits(8), b : bits(8)) -> bool = {
  let orig : bit = bool_to_bit(a != b);
  let branchless : bit = (or_reduce_8(a ^ b))[0];
  orig == branchless
}

// Pattern 3a: bool_to_bit(a != zeros()) ≡ (or_reduce_8(a))[0]
$property
function prop_nonzero_8(a : bits(8)) -> bool = {
  let orig : bit = bool_to_bit(a != zeros());
  let branchless : bit = (or_reduce_8(a))[0];
  orig == branchless
}

// Pattern 3b: 32-bit nonzero
$property
function prop_nonzero_32(a : bits(32)) -> bool = {
  let orig : bit = bool_to_bit(a != zeros());
  let branchless : bit = (or_reduce_32(a))[0];
  orig == branchless
}

// Pattern 4: bool_to_bit(x == bitone) ≡ x
$property
function prop_eq_bitone(x : bit) -> bool = {
  let orig : bit = bool_to_bit(x == bitone);
  orig == x
}

// Pattern 5: bool_to_bit(x == bitzero) ≡ ~(x)
$property
function prop_eq_bitzero(x : bit) -> bool = {
  let orig : bit = bool_to_bit(x == bitzero);
  let branchless : bit = ~(x);
  orig == branchless
}

// Compound: bool_to_bit(a == 0xFF) for 8-bit
$property
function prop_eq_ff(a : bits(8)) -> bool = {
  let orig : bit = bool_to_bit(a == 0xFF);
  let branchless : bit = (~(or_reduce_8(a ^ 0xFF)))[0];
  orig == branchless
}

// Compound: bool_to_bit(a == zeros()) for 8-bit
$property
function prop_eq_zero_8(a : bits(8)) -> bool = {
  let orig : bit = bool_to_bit(a == zeros());
  let branchless : bit = (~(or_reduce_8(a)))[0];
  orig == branchless
}

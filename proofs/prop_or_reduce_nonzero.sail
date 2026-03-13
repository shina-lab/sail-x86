// Equivalence proofs for branchless nonzero check via or_reduce
// Pattern: bool_to_bit(x != zeros()) → (or_reduce_N(x))[0]
// Used in: MUL CF (upper half nonzero check)

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

// MUL 8-bit: upper byte nonzero
$property
function prop_mul_cf_8(result : bits(16)) -> bool = {
  let orig : bit = bool_to_bit(result[15..8] != zeros());
  let branchless : bit = (or_reduce_8(result[15..8]))[0];
  orig == branchless
}

// MUL 16-bit: upper word nonzero
$property
function prop_mul_cf_16(result : bits(32)) -> bool = {
  let orig : bit = bool_to_bit(result[31..16] != zeros());
  let branchless : bit = (or_reduce_16(result[31..16]))[0];
  orig == branchless
}

// MUL 32-bit: upper dword nonzero
$property
function prop_mul_cf_32(result : bits(64)) -> bool = {
  let orig : bit = bool_to_bit(result[63..32] != zeros());
  let branchless : bit = (or_reduce_32(result[63..32]))[0];
  orig == branchless
}

// MUL 64-bit: upper qword nonzero
$property
function prop_mul_cf_64(result : bits(128)) -> bool = {
  let orig : bit = bool_to_bit(result[127..64] != zeros());
  let branchless : bit = (or_reduce_64(result[127..64]))[0];
  orig == branchless
}

// Equivalence proofs: branchless VPCMP comparison predicates
// Replace bool_to_bit(unsigned(a) <op> unsigned(b)) with bitvector ops
// Replace bool_to_bit(signed(a) <op> signed(b)) with bitvector ops

$include "../model/prelude.sail"

val or_reduce_8 : bits(8) -> bits(1)
function or_reduce_8(v) = {
  let r4 : bits(4) = v[7..4] | v[3..0];
  let r2 : bits(2) = r4[3..2] | r4[1..0];
  r2[1..1] | r2[0..0]
}

// --- Unsigned byte predicates ---

// EQ: bool_to_bit(unsigned(a) == unsigned(b)) ≡ (~(or_reduce_8(a ^ b)))[0]
$property
function prop_ucmp_eq_8(a : bits(8), b : bits(8)) -> bool = {
  let orig : bit = bool_to_bit(unsigned(a) == unsigned(b));
  let eq : bits(1) = ~(or_reduce_8(a ^ b));
  orig == eq[0]
}

// LT: bool_to_bit(unsigned(a) < unsigned(b)) ≡ ((0b0 @ a) - (0b0 @ b))[8]
$property
function prop_ucmp_lt_8(a : bits(8), b : bits(8)) -> bool = {
  let orig : bit = bool_to_bit(unsigned(a) < unsigned(b));
  let diff : bits(9) = (0b0 @ a) - (0b0 @ b);
  orig == diff[8]
}

// LE: unsigned(a) <= unsigned(b) ≡ eq | lt
$property
function prop_ucmp_le_8(a : bits(8), b : bits(8)) -> bool = {
  let orig : bit = bool_to_bit(unsigned(a) <= unsigned(b));
  let eq : bits(1) = ~(or_reduce_8(a ^ b));
  let diff : bits(9) = (0b0 @ a) - (0b0 @ b);
  let lt : bits(1) = diff[8..8];
  orig == (eq | lt)[0]
}

// NE
$property
function prop_ucmp_ne_8(a : bits(8), b : bits(8)) -> bool = {
  let orig : bit = bool_to_bit(unsigned(a) != unsigned(b));
  let ne : bits(1) = or_reduce_8(a ^ b);
  orig == ne[0]
}

// GE: ~lt
$property
function prop_ucmp_ge_8(a : bits(8), b : bits(8)) -> bool = {
  let orig : bit = bool_to_bit(unsigned(a) >= unsigned(b));
  let diff : bits(9) = (0b0 @ a) - (0b0 @ b);
  let lt : bits(1) = diff[8..8];
  orig == (~(lt))[0]
}

// GT: ~eq & ~lt
$property
function prop_ucmp_gt_8(a : bits(8), b : bits(8)) -> bool = {
  let orig : bit = bool_to_bit(unsigned(a) > unsigned(b));
  let eq : bits(1) = ~(or_reduce_8(a ^ b));
  let diff : bits(9) = (0b0 @ a) - (0b0 @ b);
  let lt : bits(1) = diff[8..8];
  orig == (~(eq) & ~(lt))[0]
}

// --- Signed byte predicates ---

// Signed LT: SF != OF after a - b
$property
function prop_scmp_lt_8(a : bits(8), b : bits(8)) -> bool = {
  let orig : bit = bool_to_bit(signed(a) < signed(b));
  let diff : bits(8) = a - b;
  let sf : bits(1) = diff[7..7];
  let of_bit : bits(1) = (a[7..7] ^ b[7..7]) & (diff[7..7] ^ a[7..7]);
  let lt : bits(1) = sf ^ of_bit;
  orig == lt[0]
}

// Signed EQ (same as unsigned EQ)
$property
function prop_scmp_eq_8(a : bits(8), b : bits(8)) -> bool = {
  let orig : bit = bool_to_bit(signed(a) == signed(b));
  let eq : bits(1) = ~(or_reduce_8(a ^ b));
  orig == eq[0]
}

// Signed LE: eq | lt
$property
function prop_scmp_le_8(a : bits(8), b : bits(8)) -> bool = {
  let orig : bit = bool_to_bit(signed(a) <= signed(b));
  let diff : bits(8) = a - b;
  let sf : bits(1) = diff[7..7];
  let of_bit : bits(1) = (a[7..7] ^ b[7..7]) & (diff[7..7] ^ a[7..7]);
  let lt : bits(1) = sf ^ of_bit;
  let eq : bits(1) = ~(or_reduce_8(a ^ b));
  orig == (eq | lt)[0]
}

// Signed NE
$property
function prop_scmp_ne_8(a : bits(8), b : bits(8)) -> bool = {
  let orig : bit = bool_to_bit(signed(a) != signed(b));
  let ne : bits(1) = or_reduce_8(a ^ b);
  orig == ne[0]
}

// Signed GE: ~lt
$property
function prop_scmp_ge_8(a : bits(8), b : bits(8)) -> bool = {
  let orig : bit = bool_to_bit(signed(a) >= signed(b));
  let diff : bits(8) = a - b;
  let sf : bits(1) = diff[7..7];
  let of_bit : bits(1) = (a[7..7] ^ b[7..7]) & (diff[7..7] ^ a[7..7]);
  let lt : bits(1) = sf ^ of_bit;
  orig == (~(lt))[0]
}

// Signed GT: ~eq & ~lt
$property
function prop_scmp_gt_8(a : bits(8), b : bits(8)) -> bool = {
  let orig : bit = bool_to_bit(signed(a) > signed(b));
  let diff : bits(8) = a - b;
  let sf : bits(1) = diff[7..7];
  let of_bit : bits(1) = (a[7..7] ^ b[7..7]) & (diff[7..7] ^ a[7..7]);
  let lt : bits(1) = sf ^ of_bit;
  let eq : bits(1) = ~(or_reduce_8(a ^ b));
  orig == (~(eq) & ~(lt))[0]
}

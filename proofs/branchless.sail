// Proof of equivalence between branching and branchless SIMD helpers.
//
// Each $property function asserts that the original (if/then/else) and
// branchless implementations produce identical results for all inputs.
// The Sail SMT target translates these to SMTLIB2 and Z3 proves there
// is no counterexample (i.e., they are equivalent for all bitvector values).
//
// Run:
//   sail --smt --smt-auto --smt-auto-solver z3 /tmp/proof_branchless.sail

default Order dec
$include <prelude.sail>

// ================================================================
// cmp_eq: all-ones if a == b, all-zeros otherwise
// Branchless: (0 @ xor(a,b)) - 1 borrows iff xor==0 iff a==b
// ================================================================

$property
function prop_cmp_eq8(a: bits(8), b: bits(8)) -> bool = {
  let orig : bits(8) = if a == b then sail_ones(8) else sail_zeros(8);
  let xd : bits(9) = sub_bits(0b0 @ xor_vec(a, b), 0b000000001);
  let branchless : bits(8) = sub_bits(sail_zeros(8), 0b0000000 @ xd[8..8]);
  orig == branchless
}

$property
function prop_cmp_eq16(a: bits(16), b: bits(16)) -> bool = {
  let orig : bits(16) = if a == b then sail_ones(16) else sail_zeros(16);
  let xd : bits(17) = sub_bits(0b0 @ xor_vec(a, b), 0b00000000000000001);
  let branchless : bits(16) = sub_bits(sail_zeros(16), sail_zero_extend(xd[16..16], 16));
  orig == branchless
}

// ================================================================
// cmp_gt: all-ones if signed(a) > signed(b), all-zeros otherwise
// Branchless: sign bit of sign_extend(b) - sign_extend(a) is 1 iff a > b
// ================================================================

$property
function prop_cmp_gt8(a: bits(8), b: bits(8)) -> bool = {
  let orig : bits(8) = if signed(a) > signed(b) then sail_ones(8) else sail_zeros(8);
  let diff : bits(9) = sub_bits(sail_sign_extend(b, 9), sail_sign_extend(a, 9));
  let branchless : bits(8) = sub_bits(sail_zeros(8), 0b0000000 @ diff[8..8]);
  orig == branchless
}

$property
function prop_cmp_gt16(a: bits(16), b: bits(16)) -> bool = {
  let orig : bits(16) = if signed(a) > signed(b) then sail_ones(16) else sail_zeros(16);
  let diff : bits(17) = sub_bits(sail_sign_extend(b, 17), sail_sign_extend(a, 17));
  let branchless : bits(16) = sub_bits(sail_zeros(16), sail_zero_extend(diff[16..16], 16));
  orig == branchless
}

// ================================================================
// max_s: signed maximum
// Branchless: mask = all-1s if a > b (signed); select a if mask, else b
// ================================================================

$property
function prop_max_s8(a: bits(8), b: bits(8)) -> bool = {
  let orig : bits(8) = if signed(a) > signed(b) then a else b;
  let diff : bits(9) = sub_bits(sail_sign_extend(b, 9), sail_sign_extend(a, 9));
  let mask : bits(8) = sub_bits(sail_zeros(8), 0b0000000 @ diff[8..8]);
  let branchless = or_vec(and_vec(a, mask), and_vec(b, not_vec(mask)));
  orig == branchless
}

$property
function prop_max_s16(a: bits(16), b: bits(16)) -> bool = {
  let orig : bits(16) = if signed(a) > signed(b) then a else b;
  let diff : bits(17) = sub_bits(sail_sign_extend(b, 17), sail_sign_extend(a, 17));
  let mask : bits(16) = sub_bits(sail_zeros(16), sail_zero_extend(diff[16..16], 16));
  let branchless = or_vec(and_vec(a, mask), and_vec(b, not_vec(mask)));
  orig == branchless
}

$property
function prop_max_s32(a: bits(32), b: bits(32)) -> bool = {
  let orig : bits(32) = if signed(a) > signed(b) then a else b;
  let diff : bits(33) = sub_bits(sail_sign_extend(b, 33), sail_sign_extend(a, 33));
  let mask : bits(32) = sub_bits(sail_zeros(32), sail_zero_extend(diff[32..32], 32));
  let branchless = or_vec(and_vec(a, mask), and_vec(b, not_vec(mask)));
  orig == branchless
}

// ================================================================
// max_u: unsigned maximum
// Branchless: mask = all-1s if a < b (unsigned); select b if mask, else a
// ================================================================

$property
function prop_max_u8(a: bits(8), b: bits(8)) -> bool = {
  let orig : bits(8) = if unsigned(a) > unsigned(b) then a else b;
  let diff : bits(9) = sub_bits(0b0 @ a, 0b0 @ b);
  let mask : bits(8) = sub_bits(sail_zeros(8), 0b0000000 @ diff[8..8]);
  let branchless = or_vec(and_vec(b, mask), and_vec(a, not_vec(mask)));
  orig == branchless
}

$property
function prop_max_u16(a: bits(16), b: bits(16)) -> bool = {
  let orig : bits(16) = if unsigned(a) > unsigned(b) then a else b;
  let diff : bits(17) = sub_bits(0b0 @ a, 0b0 @ b);
  let mask : bits(16) = sub_bits(sail_zeros(16), sail_zero_extend(diff[16..16], 16));
  let branchless = or_vec(and_vec(b, mask), and_vec(a, not_vec(mask)));
  orig == branchless
}

$property
function prop_max_u32(a: bits(32), b: bits(32)) -> bool = {
  let orig : bits(32) = if unsigned(a) > unsigned(b) then a else b;
  let diff : bits(33) = sub_bits(0b0 @ a, 0b0 @ b);
  let mask : bits(32) = sub_bits(sail_zeros(32), sail_zero_extend(diff[32..32], 32));
  let branchless = or_vec(and_vec(b, mask), and_vec(a, not_vec(mask)));
  orig == branchless
}

// ================================================================
// min_s: signed minimum
// Branchless: mask = all-1s if a < b (signed); select a if mask, else b
// ================================================================

$property
function prop_min_s8(a: bits(8), b: bits(8)) -> bool = {
  let orig : bits(8) = if signed(a) < signed(b) then a else b;
  let diff : bits(9) = sub_bits(sail_sign_extend(a, 9), sail_sign_extend(b, 9));
  let mask : bits(8) = sub_bits(sail_zeros(8), 0b0000000 @ diff[8..8]);
  let branchless = or_vec(and_vec(a, mask), and_vec(b, not_vec(mask)));
  orig == branchless
}

$property
function prop_min_s16(a: bits(16), b: bits(16)) -> bool = {
  let orig : bits(16) = if signed(a) < signed(b) then a else b;
  let diff : bits(17) = sub_bits(sail_sign_extend(a, 17), sail_sign_extend(b, 17));
  let mask : bits(16) = sub_bits(sail_zeros(16), sail_zero_extend(diff[16..16], 16));
  let branchless = or_vec(and_vec(a, mask), and_vec(b, not_vec(mask)));
  orig == branchless
}

$property
function prop_min_s32(a: bits(32), b: bits(32)) -> bool = {
  let orig : bits(32) = if signed(a) < signed(b) then a else b;
  let diff : bits(33) = sub_bits(sail_sign_extend(a, 33), sail_sign_extend(b, 33));
  let mask : bits(32) = sub_bits(sail_zeros(32), sail_zero_extend(diff[32..32], 32));
  let branchless = or_vec(and_vec(a, mask), and_vec(b, not_vec(mask)));
  orig == branchless
}

// ================================================================
// min_u: unsigned minimum
// Branchless: mask = all-1s if a < b (unsigned); select a if mask, else b
// ================================================================

$property
function prop_min_u8(a: bits(8), b: bits(8)) -> bool = {
  let orig : bits(8) = if unsigned(a) < unsigned(b) then a else b;
  let diff : bits(9) = sub_bits(0b0 @ a, 0b0 @ b);
  let mask : bits(8) = sub_bits(sail_zeros(8), 0b0000000 @ diff[8..8]);
  let branchless = or_vec(and_vec(a, mask), and_vec(b, not_vec(mask)));
  orig == branchless
}

$property
function prop_min_u16(a: bits(16), b: bits(16)) -> bool = {
  let orig : bits(16) = if unsigned(a) < unsigned(b) then a else b;
  let diff : bits(17) = sub_bits(0b0 @ a, 0b0 @ b);
  let mask : bits(16) = sub_bits(sail_zeros(16), sail_zero_extend(diff[16..16], 16));
  let branchless = or_vec(and_vec(a, mask), and_vec(b, not_vec(mask)));
  orig == branchless
}

$property
function prop_min_u32(a: bits(32), b: bits(32)) -> bool = {
  let orig : bits(32) = if unsigned(a) < unsigned(b) then a else b;
  let diff : bits(33) = sub_bits(0b0 @ a, 0b0 @ b);
  let mask : bits(32) = sub_bits(sail_zeros(32), sail_zero_extend(diff[32..32], 32));
  let branchless = or_vec(and_vec(a, mask), and_vec(b, not_vec(mask)));
  orig == branchless
}

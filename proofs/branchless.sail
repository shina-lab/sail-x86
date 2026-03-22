// Proof of equivalence between branching and branchless SIMD helpers.
//
// Each $property function asserts that the original (if/then/else) and
// branchless implementations produce identical results for all inputs.
// The Sail SMT target translates these to SMTLIB2 and Z3 proves there
// is no counterexample (i.e., they are equivalent for all bitvector values).
//
// Run:
//   sail --smt --smt-auto --smt-auto-solver z3 proofs/branchless.sail

$include "../model/prelude.sail"

// ================================================================
// cmp_eq: all-ones if a == b, all-zeros otherwise
// Branchless: (0 @ xor(a,b)) - 1 borrows iff xor==0 iff a==b
// ================================================================

$property
function prop_cmp_eq8(a: bits(8), b: bits(8)) -> bool = {
  let orig : bits(8) = if a == b then ones() else zeros();
  let xd : bits(9) = (0b0 @ (a ^ b)) - 0b000000001;
  let branchless : bits(8) = zeros() - zero_extend(xd[8..8]);
  orig == branchless
}

$property
function prop_cmp_eq16(a: bits(16), b: bits(16)) -> bool = {
  let orig : bits(16) = if a == b then ones() else zeros();
  let xd : bits(17) = (0b0 @ (a ^ b)) - 0b00000000000000001;
  let branchless : bits(16) = zeros() - zero_extend(xd[16..16]);
  orig == branchless
}

// ================================================================
// cmp_gt: all-ones if signed(a) > signed(b), all-zeros otherwise
// Branchless: sign bit of sign_extend(b) - sign_extend(a) is 1 iff a > b
// ================================================================

$property
function prop_cmp_gt8(a: bits(8), b: bits(8)) -> bool = {
  let orig : bits(8) = if signed(a) > signed(b) then ones() else zeros();
  let a9 : bits(9) = sign_extend(a);
  let b9 : bits(9) = sign_extend(b);
  let diff : bits(9) = b9 - a9;
  let branchless : bits(8) = zeros() - zero_extend(diff[8..8]);
  orig == branchless
}

$property
function prop_cmp_gt16(a: bits(16), b: bits(16)) -> bool = {
  let orig : bits(16) = if signed(a) > signed(b) then ones() else zeros();
  let diff : bits(17) = sign_extend(b) - sign_extend(a);
  let branchless : bits(16) = zeros() - zero_extend(diff[16..16]);
  orig == branchless
}

// ================================================================
// max_s: signed maximum
// Branchless: mask = all-1s if a > b (signed); select a if mask, else b
// ================================================================

$property
function prop_max_s8(a: bits(8), b: bits(8)) -> bool = {
  let orig : bits(8) = if signed(a) > signed(b) then a else b;
  let diff : bits(9) = sign_extend(b) - sign_extend(a);
  let mask : byte = zeros() - zero_extend(diff[8..8]);
  let branchless = (a & mask) | (b & ~(mask));
  orig == branchless
}

$property
function prop_max_s16(a: bits(16), b: bits(16)) -> bool = {
  let orig : bits(16) = if signed(a) > signed(b) then a else b;
  let diff : bits(17) = sign_extend(b) - sign_extend(a);
  let mask : word = zeros() - zero_extend(diff[16..16]);
  let branchless = (a & mask) | (b & ~(mask));
  orig == branchless
}

$property
function prop_max_s32(a: bits(32), b: bits(32)) -> bool = {
  let orig : bits(32) = if signed(a) > signed(b) then a else b;
  let diff : bits(33) = sign_extend(b) - sign_extend(a);
  let mask : dword = zeros() - zero_extend(diff[32..32]);
  let branchless = (a & mask) | (b & ~(mask));
  orig == branchless
}

// ================================================================
// max_u: unsigned maximum
// Branchless: mask = all-1s if a < b (unsigned); select b if mask, else a
// ================================================================

$property
function prop_max_u8(a: bits(8), b: bits(8)) -> bool = {
  let orig : bits(8) = if unsigned(a) > unsigned(b) then a else b;
  let diff : bits(9) = (0b0 @ a) - (0b0 @ b);
  let mask : byte = zeros() - zero_extend(diff[8..8]);
  let branchless = (b & mask) | (a & ~(mask));
  orig == branchless
}

$property
function prop_max_u16(a: bits(16), b: bits(16)) -> bool = {
  let orig : bits(16) = if unsigned(a) > unsigned(b) then a else b;
  let diff : bits(17) = (0b0 @ a) - (0b0 @ b);
  let mask : word = zeros() - zero_extend(diff[16..16]);
  let branchless = (b & mask) | (a & ~(mask));
  orig == branchless
}

$property
function prop_max_u32(a: bits(32), b: bits(32)) -> bool = {
  let orig : bits(32) = if unsigned(a) > unsigned(b) then a else b;
  let diff : bits(33) = (0b0 @ a) - (0b0 @ b);
  let mask : dword = zeros() - zero_extend(diff[32..32]);
  let branchless = (b & mask) | (a & ~(mask));
  orig == branchless
}

// ================================================================
// min_s: signed minimum
// Branchless: mask = all-1s if a < b (signed); select a if mask, else b
// ================================================================

$property
function prop_min_s8(a: bits(8), b: bits(8)) -> bool = {
  let orig : bits(8) = if signed(a) < signed(b) then a else b;
  let diff : bits(9) = sign_extend(a) - sign_extend(b);
  let mask : byte = zeros() - zero_extend(diff[8..8]);
  let branchless = (a & mask) | (b & ~(mask));
  orig == branchless
}

$property
function prop_min_s16(a: bits(16), b: bits(16)) -> bool = {
  let orig : bits(16) = if signed(a) < signed(b) then a else b;
  let diff : bits(17) = sign_extend(a) - sign_extend(b);
  let mask : word = zeros() - zero_extend(diff[16..16]);
  let branchless = (a & mask) | (b & ~(mask));
  orig == branchless
}

$property
function prop_min_s32(a: bits(32), b: bits(32)) -> bool = {
  let orig : bits(32) = if signed(a) < signed(b) then a else b;
  let diff : bits(33) = sign_extend(a) - sign_extend(b);
  let mask : dword = zeros() - zero_extend(diff[32..32]);
  let branchless = (a & mask) | (b & ~(mask));
  orig == branchless
}

// ================================================================
// min_u: unsigned minimum
// Branchless: mask = all-1s if a < b (unsigned); select a if mask, else b
// ================================================================

$property
function prop_min_u8(a: bits(8), b: bits(8)) -> bool = {
  let orig : bits(8) = if unsigned(a) < unsigned(b) then a else b;
  let diff : bits(9) = (0b0 @ a) - (0b0 @ b);
  let mask : byte = zeros() - zero_extend(diff[8..8]);
  let branchless = (a & mask) | (b & ~(mask));
  orig == branchless
}

$property
function prop_min_u16(a: bits(16), b: bits(16)) -> bool = {
  let orig : bits(16) = if unsigned(a) < unsigned(b) then a else b;
  let diff : bits(17) = (0b0 @ a) - (0b0 @ b);
  let mask : word = zeros() - zero_extend(diff[16..16]);
  let branchless = (a & mask) | (b & ~(mask));
  orig == branchless
}

$property
function prop_min_u32(a: bits(32), b: bits(32)) -> bool = {
  let orig : bits(32) = if unsigned(a) < unsigned(b) then a else b;
  let diff : bits(33) = (0b0 @ a) - (0b0 @ b);
  let mask : dword = zeros() - zero_extend(diff[32..32]);
  let branchless = (a & mask) | (b & ~(mask));
  orig == branchless
}

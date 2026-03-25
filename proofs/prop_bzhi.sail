// Equivalence proof: BZHI branchless conversion
//
// Old:
//   if index >= os then { result = src1; CF = 1 }
//   else { result = (src1 << (os - index)) >> (os - index); CF = 0 }
//
// New:
//   let clamped = min(index, os)
//   let shift_amt = os - clamped
//   result = (src1 << shift_amt) >> shift_amt
//   CF = is_ge_u(index, os)
//
// When index >= os: clamped = os, shift_amt = 0, result = src1. CF = 1.
// When index < os: clamped = index, shift_amt = os - index. CF = 0.

$include "../model/prelude.sail"

val is_gt_u : forall 'n, 0 < 'n & 'n <= 64. (bits('n), bits('n)) -> bit
function is_gt_u(a, b) = {
  let diff : bits('n + 1) = zero_extend(b) - zero_extend(a);
  diff['n]
}

val is_ge_u : forall 'n, 0 < 'n & 'n <= 64. (bits('n), bits('n)) -> bit
function is_ge_u(a, b) = ~(is_gt_u(b, a))

val blend : forall 'n, 0 < 'n. (bits('n), bits('n), bit) -> bits('n)
function blend(a, b, sel) = {
  let m : bits('n) = sign_extend(sel);
  (a & ~(m)) | (b & m)
}

val min_u : forall 'n, 0 < 'n & 'n <= 64. (bits('n), bits('n)) -> bits('n)
function min_u(a, b) = blend(a, b, is_gt_u(a, b))

$property
function prop_bzhi(src1 : bits(32), index : bits(9)) -> bool = {
  let os = 32;
  let idx = unsigned(index);
  // Old
  let (orig_result, orig_cf) : (bits(32), bit) =
    if idx >= os then (src1, 0b1)
    else {
      let sa : range(0, 255) = os - idx;
      ((src1 << sa) >> sa, 0b0)
    };
  // New
  let clamped = unsigned(min_u(index, to_bits(9, os)));
  assert(clamped <= os);
  let shift_amt = os - clamped;
  let new_result : bits(32) = (src1 << shift_amt) >> shift_amt;
  let new_cf : bit = is_ge_u(index, to_bits(9, os));
  orig_result == new_result & orig_cf == new_cf
}

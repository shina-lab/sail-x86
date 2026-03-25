// Equivalence proof: SHLD/SHRD branchless conversion
//
// Three branches eliminated:
//   1. count == 0 → no-op: blend(old, new, is_nonzero(count))
//   2. count == 1 → OF special: computed unconditionally (undefined for count!=1)
//   3. count > os → undefined: blend(result, undefined, is_gt_u(count, os))
//
// Clamp count to [0, os] via min_u for safe index computation.
// CF index clamp: count + unsigned(is_zero(count)) avoids index -1 at count==0.

$include "../model/prelude.sail"

val or_reduce : forall 'n, 0 < 'n & 'n <= 64. bits('n) -> bits(1)
function or_reduce(v) = {
  let x1 : bits(64) = zero_extend(v);
  let x2 = x1 | (x1 >> 1);
  let x3 = x2 | (x2 >> 2);
  let x4 = x3 | (x3 >> 4);
  let x5 = x4 | (x4 >> 8);
  let x6 = x5 | (x5 >> 16);
  let x7 = x6 | (x6 >> 32);
  x7[0]
}

val is_nonzero : forall 'n, 0 < 'n & 'n <= 64. bits('n) -> bit
function is_nonzero(v) = or_reduce(v)[0]

val is_zero : forall 'n, 0 < 'n & 'n <= 64. bits('n) -> bit
function is_zero(v) = (~(or_reduce(v)))[0]

val is_gt_u : forall 'n, 0 < 'n & 'n <= 64. (bits('n), bits('n)) -> bit
function is_gt_u(a, b) = {
  let diff : bits('n + 1) = zero_extend(b) - zero_extend(a);
  diff['n]
}

val blend : forall 'n, 0 < 'n. (bits('n), bits('n), bit) -> bits('n)
function blend(a, b, sel) = {
  let m : bits('n) = sign_extend(sel);
  (a & ~(m)) | (b & m)
}

val min_u : forall 'n, 0 < 'n & 'n <= 64. (bits('n), bits('n)) -> bits('n)
function min_u(a, b) = blend(a, b, is_gt_u(a, b))

// Prove: clamped count via min_u equals original guarded count
$property
function prop_clamp_count(count : bits(6), os : bits(7)) -> bool = {
  let os_int = unsigned(os);
  let count_int = unsigned(count);
  if os_int > 0 & os_int <= 64 then {
    // Old: if count > os then <undefined path> else <use count>
    // New: min_u(count, os) — gives count when count <= os, os when count > os
    let clamped = unsigned(min_u(to_bits(7, count_int), os));
    if count_int <= os_int then clamped == count_int
    else clamped == os_int
  } else true
}

// Prove: is_gt_u correctly detects count > os for blend with undefined
$property
function prop_count_gt_os(count : bits(6), os : bits(7)) -> bool = {
  let gt : bit = is_gt_u(to_bits(7, unsigned(count)), os);
  if unsigned(count) > unsigned(os) then gt == 0b1
  else gt == 0b0
}

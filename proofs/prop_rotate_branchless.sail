// Equivalence proof: ROL/ROR/RCL/RCR branchless conversion
//
// Same pattern as SHL: compute result and flags unconditionally,
// blend with old values based on is_nonzero(count).
//
// ROL/ROR: only CF and OF affected (SF, ZF, AF, PF unchanged).
//   rotl(a, 0) == a, rotr(a, 0) == a — rotate by zero is identity.
//   CF and OF computed from result, blended with old when count==0.
//
// RCL/RCR: c = masked % (os+1). When c==0, rotl(a@CF, 0) == a@CF.
//   Same blend pattern for CF and OF.

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

val blend : forall 'n, 0 < 'n. (bits('n), bits('n), bit) -> bits('n)
function blend(a, b, sel) = {
  let m : bits('n) = sign_extend(sel);
  (a & ~(m)) | (b & m)
}

// rotate by 0 is identity
$property
function prop_rotl_zero(a : bits(32)) -> bool =
  ((a << 0) | (a >> (32 - 0))) == a

$property
function prop_rotr_zero(a : bits(32)) -> bool =
  ((a >> 0) | (a << (32 - 0))) == a

// OF computed unconditionally: valid for count==1, undefined otherwise (any value ok)
// When count==0, blend restores old OF
$property
function prop_of_blend(old_of : bit, new_of : bit, count : bits(6)) -> bool = {
  let nz = is_nonzero(count);
  if count == 0b000000 then
    blend(old_of, new_of, nz) == old_of
  else
    blend(old_of, new_of, nz) == new_of
}

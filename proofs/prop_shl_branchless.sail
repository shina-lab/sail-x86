// Equivalence proof: SHL count==0 no-op via blend
//
// Old code:
//   if count == 0 then a
//   else { result = a << count; update flags; result }
//
// New code:
//   result = a << count;  // a << 0 == a
//   ... compute flags unconditionally ...
//   blend(a, result, is_nonzero(count))  // count==0 → a, count>0 → result
//   blend(old_flag, new_flag, is_nonzero(count))  // count==0 → preserve flags
//
// Key identities:
//   a << 0 == a  (shift by zero is identity)
//   blend(a, a, sel) == a  (blending identical values)
//   So blend(a, a << 0, nz) == blend(a, a, nz) == a when count==0  ✓

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

// When count==0, blend(old, new, is_nonzero(0)) returns old
$property
function prop_count_zero_noop(old_val : bits(32), new_val : bits(32),
                               old_flag : bit, new_flag : bit) -> bool = {
  let count_bv : bits(6) = 0b000000;
  let nz : bit = is_nonzero(count_bv);
  // blend with nz=0 returns first argument (old)
  blend(old_val, new_val, nz) == old_val &
  blend(old_flag, new_flag, nz) == old_flag
}

// When count>0, blend(old, new, is_nonzero(count)) returns new
$property
function prop_count_nonzero_update(old_val : bits(32), new_val : bits(32),
                                    old_flag : bit, new_flag : bit,
                                    count : bits(6)) -> bool = {
  let nz : bit = is_nonzero(count);
  if count != 0b000000 then
    blend(old_val, new_val, nz) == new_val &
    blend(old_flag, new_flag, nz) == new_flag
  else true
}

// a << 0 == a
$property
function prop_shift_zero_identity(a : bits(32)) -> bool =
  (a << 0) == a

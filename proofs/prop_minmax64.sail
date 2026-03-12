// Full-width equivalence proofs for 64-bit min/max branchless helpers.

default Order dec
$include <prelude.sail>

overload operator - = {sub_bits}
overload operator & = {and_vec}
overload operator | = {or_vec}
overload zeros = {sail_zeros}
overload zero_extend = {sail_zero_extend}
overload sign_extend = {sail_sign_extend}

val not_vec_bits : forall 'n. bits('n) -> bits('n)
function not_vec_bits(x) = not_vec(x)

val max_s64 : (bits(64), bits(64)) -> bits(64)
function max_s64(a, b) = {
  let diff : bits(65) = sign_extend(b, 65) - sign_extend(a, 65);
  let mask : bits(64) = zeros(64) - zero_extend(diff[64..64], 64);
  (a & mask) | (b & not_vec_bits(mask))
}

val min_s64 : (bits(64), bits(64)) -> bits(64)
function min_s64(a, b) = {
  let diff : bits(65) = sign_extend(a, 65) - sign_extend(b, 65);
  let mask : bits(64) = zeros(64) - zero_extend(diff[64..64], 64);
  (a & mask) | (b & not_vec_bits(mask))
}

val max_u64 : (bits(64), bits(64)) -> bits(64)
function max_u64(a, b) = {
  let diff : bits(65) = zero_extend(b, 65) - zero_extend(a, 65);
  let mask : bits(64) = zeros(64) - zero_extend(diff[64..64], 64);
  (a & mask) | (b & not_vec_bits(mask))
}

val min_u64 : (bits(64), bits(64)) -> bits(64)
function min_u64(a, b) = {
  let diff : bits(65) = zero_extend(a, 65) - zero_extend(b, 65);
  let mask : bits(64) = zeros(64) - zero_extend(diff[64..64], 64);
  (a & mask) | (b & not_vec_bits(mask))
}

// max_s64: 128-bit (2 qword lanes)
$property
function prop_pmaxsq_128(a: bits(128), b: bits(128)) -> bool = {
  let r1_orig : bits(64) = if signed(a[127..64]) > signed(b[127..64]) then a[127..64] else b[127..64];
  let r0_orig : bits(64) = if signed(a[63..0])   > signed(b[63..0])   then a[63..0]   else b[63..0];
  let orig : bits(128) = r1_orig @ r0_orig;
  let branchless : bits(128) = max_s64(a[127..64], b[127..64]) @ max_s64(a[63..0], b[63..0]);
  orig == branchless
}

// min_s64: 128-bit (2 qword lanes)
$property
function prop_pminsq_128(a: bits(128), b: bits(128)) -> bool = {
  let r1_orig : bits(64) = if signed(a[127..64]) > signed(b[127..64]) then b[127..64] else a[127..64];
  let r0_orig : bits(64) = if signed(a[63..0])   > signed(b[63..0])   then b[63..0]   else a[63..0];
  let orig : bits(128) = r1_orig @ r0_orig;
  let branchless : bits(128) = min_s64(a[127..64], b[127..64]) @ min_s64(a[63..0], b[63..0]);
  orig == branchless
}

// max_u64: 128-bit (2 qword lanes)
$property
function prop_pmaxuq_128(a: bits(128), b: bits(128)) -> bool = {
  let r1_orig : bits(64) = if unsigned(a[127..64]) > unsigned(b[127..64]) then a[127..64] else b[127..64];
  let r0_orig : bits(64) = if unsigned(a[63..0])   > unsigned(b[63..0])   then a[63..0]   else b[63..0];
  let orig : bits(128) = r1_orig @ r0_orig;
  let branchless : bits(128) = max_u64(a[127..64], b[127..64]) @ max_u64(a[63..0], b[63..0]);
  orig == branchless
}

// min_u64: 128-bit (2 qword lanes)
$property
function prop_pminuq_128(a: bits(128), b: bits(128)) -> bool = {
  let r1_orig : bits(64) = if unsigned(a[127..64]) > unsigned(b[127..64]) then b[127..64] else a[127..64];
  let r0_orig : bits(64) = if unsigned(a[63..0])   > unsigned(b[63..0])   then b[63..0]   else a[63..0];
  let orig : bits(128) = r1_orig @ r0_orig;
  let branchless : bits(128) = min_u64(a[127..64], b[127..64]) @ min_u64(a[63..0], b[63..0]);
  orig == branchless
}

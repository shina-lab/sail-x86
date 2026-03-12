// Full-width equivalence proofs for PCMPGTQ branchless conversion.

default Order dec
$include <prelude.sail>

overload operator - = {sub_bits}
overload zeros = {sail_zeros}
overload ones = {sail_ones}
overload zero_extend = {sail_zero_extend}
overload sign_extend = {sail_sign_extend}

val cmp_gt64 : (bits(64), bits(64)) -> bits(64)
function cmp_gt64(a, b) = {
  let a65 : bits(65) = sign_extend(a, 65);
  let b65 : bits(65) = sign_extend(b, 65);
  let diff : bits(65) = b65 - a65;
  zeros(64) - zero_extend(diff[64..64], 64)
}

// SSE4.2 PCMPGTQ: 128-bit (2 qword lanes)
$property
function prop_pcmpgtq_sse(a: bits(128), b: bits(128)) -> bool = {
  let r1 : bits(64) = if signed(a[127..64]) > signed(b[127..64]) then ones(64) else zeros(64);
  let r0 : bits(64) = if signed(a[63..0])   > signed(b[63..0])   then ones(64) else zeros(64);
  let orig : bits(128) = r1 @ r0;
  let branchless : bits(128) = cmp_gt64(a[127..64], b[127..64]) @ cmp_gt64(a[63..0], b[63..0]);
  orig == branchless
}

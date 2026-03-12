$include "../model/prelude.sail"

// Prove branchless signed saturation from int to 32-bit.
// VPDPWSSDS: dst + signed(s1)*signed(s2) pairs, saturated to [-2^31, 2^31-1].
// Sum range fits in 33-bit signed.

$property
function prop_sat_int_to_s32(dst : bits(32), s1 : bits(32), s2 : bits(32)) -> bool = {
  let p0 : int = signed(s1[15..0]) * signed(s2[15..0]);
  let p1 : int = signed(s1[31..16]) * signed(s2[31..16]);
  let sum : int = signed(dst) + p0 + p1;

  // Original (branching)
  let orig : bits(32) =
    if sum > 2147483647 then 0x7FFFFFFF
    else if sum < negate(2147483648) then 0x80000000
    else get_slice_int(32, sum, 0);

  // Branchless: convert to 33-bit, detect overflow, select
  let wide : bits(33) = get_slice_int(33, sum, 0);
  let sign : bits(1) = wide[32..32];
  let of_mask : bits(32) = sign_extend(sign ^ wide[31..31]);
  let sat : bits(32) = sign_extend(sign) ^ 0x7FFFFFFF;
  let branchless : bits(32) = (sat & of_mask) | (wide[31..0] & not_vec(of_mask));

  orig == branchless
}

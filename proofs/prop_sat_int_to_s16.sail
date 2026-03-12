$include "../model/prelude.sail"

// Prove branchless signed saturation from int to 16-bit.
// PMADDUBSW: unsigned(a)*signed(b) pairs, sum saturated to [-32768, 32767].
// Sum range: [-65280, 65025], fits in 17-bit signed.

$property
function prop_sat_int_to_s16(a_even : bits(8), b_even : bits(8), a_odd : bits(8), b_odd : bits(8)) -> bool = {
  let p1 : int = unsigned(a_even) * signed(b_even);
  let p2 : int = unsigned(a_odd) * signed(b_odd);
  let sum : int = p1 + p2;

  // Original (branching)
  let orig : bits(16) =
    if sum > 32767 then 0x7FFF
    else if sum < negate(32768) then 0x8000
    else get_slice_int(16, sum, 0);

  // Branchless: convert to 17-bit, detect overflow, select
  let wide : bits(17) = get_slice_int(17, sum, 0);
  let sign : bits(1) = wide[16..16];
  let of_mask : bits(16) = sign_extend(sign ^ wide[15..15]);
  let sat : bits(16) = sign_extend(sign) ^ 0x7FFF;
  let branchless : bits(16) = (sat & of_mask) | (wide[15..0] & not_vec(of_mask));

  orig == branchless
}

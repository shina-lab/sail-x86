$include "../model/prelude.sail"

// Prove: branchless INSERTPS destination lane selection
// Original: if dst_sel == i then src else lane_i (4-way branch)
// New: blend via all-ones/zeros mask from bool_to_bit

$property
function prop_insertps_dst(a : bits(128), src_float : bits(32), dst_sel : bits(2)) -> bool = {
  let sel : range(0, 3) = unsigned(dst_sel);

  // Original (branchy)
  let t0 : bits(32) = if sel == 0 then src_float else a[31..0];
  let t1 : bits(32) = if sel == 1 then src_float else a[63..32];
  let t2 : bits(32) = if sel == 2 then src_float else a[95..64];
  let t3 : bits(32) = if sel == 3 then src_float else a[127..96];
  let orig : bits(128) = t3 @ t2 @ t1 @ t0;

  // Branchless
  let m0 : bits(32) = zeros() - zero_extend(bool_to_bit(sel == 0));
  let m1 : bits(32) = zeros() - zero_extend(bool_to_bit(sel == 1));
  let m2 : bits(32) = zeros() - zero_extend(bool_to_bit(sel == 2));
  let m3 : bits(32) = zeros() - zero_extend(bool_to_bit(sel == 3));
  let b0 : bits(32) = (src_float & m0) | (a[31..0] & not_vec(m0));
  let b1 : bits(32) = (src_float & m1) | (a[63..32] & not_vec(m1));
  let b2 : bits(32) = (src_float & m2) | (a[95..64] & not_vec(m2));
  let b3 : bits(32) = (src_float & m3) | (a[127..96] & not_vec(m3));
  let branchless : bits(128) = b3 @ b2 @ b1 @ b0;

  orig == branchless
}

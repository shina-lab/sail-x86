// Equivalence proof: Euclidean division remainder adjustment
//
// Old code:
//   if r >= 0 then (q * scale, r) else ((q - 1) * scale, r + os)
//
// New code (branchless):
//   let r_bv : bits(7) = get_slice_int(7, r, 0);
//   let sign : int = negate(unsigned(r_bv[6]));  // 0 or -1
//   byte_disp = (q + sign) * scale
//   bit_num   = r - sign * os
//
// sign = 0 when r >= 0 (bit 6 = 0), -1 when r < 0 (bit 6 = 1).

$include "../model/prelude.sail"

$property
function prop_euclid_adj(q : bits(8), r : bits(7), os : bits(7), scale : bits(4)) -> bool = {
  let q_int = signed(q);
  let r_int = signed(r);
  let os_int = unsigned(os);
  let scale_int = unsigned(scale);
  if os_int > 0 then {
    // Old: branch on r >= 0
    let (byte_disp_old, bit_num_old) : (int, int) =
      if r_int >= 0 then (q_int * scale_int, r_int)
      else ((q_int - 1) * scale_int, r_int + os_int);
    // New: extract sign from bitvector, no branch
    let sign : int = negate(unsigned(r[6]));
    let byte_disp_new = (q_int + sign) * scale_int;
    let bit_num_new = r_int - sign * os_int;
    byte_disp_old == byte_disp_new & bit_num_old == bit_num_new
  } else true
}

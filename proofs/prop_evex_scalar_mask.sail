// Equivalence proof: EVEX scalar writemask branchless conversion
//
// Old:
//   if mask_bit then write(result)
//   else if evex_z then write(result[hi] @ zeros)
//   else write(result[hi] @ old[lo])
//
// New (evex_z is instruction-constant, mask_bit is data):
//   let merge = blend(old[lo], zeros, evex_z)  // instruction-constant mux
//   let lo = blend(merge, result[lo], mask_bit) // data-dependent mux
//   write(result[hi] @ lo)

$include "../model/prelude.sail"

val blend : forall 'n, 0 < 'n. (bits('n), bits('n), bit) -> bits('n)
function blend(a, b, sel) = {
  let m : bits('n) = sign_extend(sel);
  (a & ~(m)) | (b & m)
}

$property
function prop_scalar_mask(result_lo : bits(32), old_lo : bits(32),
                           mask_bit : bit, evex_z : bit) -> bool = {
  let orig : bits(32) =
    if mask_bit == 0b1 then result_lo
    else if evex_z == 0b1 then zeros()
    else old_lo;
  let merge : bits(32) = blend(old_lo, zeros(), evex_z);
  let branchless : bits(32) = blend(merge, result_lo, mask_bit);
  orig == branchless
}

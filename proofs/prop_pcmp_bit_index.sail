// Equivalence proof: pcmp_bit_index branchless rewrite
//
// Transformation 1 (BSR sentinel):
//   Old: if int_res2 == zeros() then 0 else bsr(zero_extend(int_res2))
//   New: bsr(zero_extend(int_res2) | 0x0000000000000001)
//   When int_res2 != 0: the sentinel bit 0 doesn't affect BSR (BSR finds
//   the highest set bit, and int_res2 has a bit >= 0 set).
//   When int_res2 == 0: BSR finds the sentinel → returns 0.
//   The zero case is overridden by the blend below, so the value doesn't matter.
//
// Transformation 2 (blend replaces if):
//   Old: if is_zero | idx > ub then ub + 1 else idx
//   New: blend(idx, ub + 1, is_zero | is_gt_u(idx, ub))
//   This is the standard conditional → blend pattern.

$include "../model/prelude.sail"

type qword = bits(64)

val popcount : forall 'n, 0 < 'n & 'n <= 64. bits('n) -> range(0, 'n)
function popcount(v) = {
  let x1 : qword = zero_extend(v);
  let x2 = (x1 & 0x5555555555555555) + ((x1 >> 1) & 0x5555555555555555);
  let x3 = (x2 & 0x3333333333333333) + ((x2 >> 2) & 0x3333333333333333);
  let x4 = (x3 & 0x0f0f0f0f0f0f0f0f) + ((x3 >> 4) & 0x0f0f0f0f0f0f0f0f);
  let x5 = (x4 & 0x00ff00ff00ff00ff) + ((x4 >> 8) & 0x00ff00ff00ff00ff);
  let x6 = (x5 & 0x0000ffff0000ffff) + ((x5 >> 16) & 0x0000ffff0000ffff);
  let x7 = (x6 & 0x00000000ffffffff) + ((x6 >> 32) & 0x00000000ffffffff);
  let x = unsigned(x7);
  assert(x <= 'n);
  x
}

val bsr64 : qword -> range(0, 63)
function bsr64(v) = {
  let x1 = v  | (v  >> 1);
  let x2 = x1 | (x1 >> 2);
  let x3 = x2 | (x2 >> 4);
  let x4 = x3 | (x3 >> 8);
  let x5 = x4 | (x4 >> 16);
  let x6 = x5 | (x5 >> 32);
  let n = popcount(x6);
  assert(n > 0);
  n - 1
}

// Prove: for nonzero int_res2, bsr with sentinel == bsr without sentinel
// (sentinel at bit 0 doesn't affect highest set bit when there's a higher bit)
$property
function prop_bsr_sentinel(int_res2 : bits(8)) -> bool = {
  if int_res2 != zeros() then {
    let without : range(0, 63) = bsr64(zero_extend(int_res2));
    let with_sentinel : range(0, 63) = bsr64(zero_extend(int_res2) | 0x0000000000000001);
    without == with_sentinel
  } else true
}

// Prove: blend replaces if for the out-of-range check
$property
function prop_blend_out_of_range(idx : bits(5), ub_plus_1 : bits(5),
                                  zf : bit, gt : bit) -> bool = {
  let idx_int = unsigned(idx);
  let ub1_int = unsigned(ub_plus_1);
  let out_of_range : bit = zf | gt;
  // Old
  let orig : bits(5) = if out_of_range == 0b1 then ub_plus_1 else idx;
  // New
  let m : bits(5) = sign_extend(out_of_range);
  let branchless : bits(5) = (idx & ~(m)) | (ub_plus_1 & m);
  orig == branchless
}

$include "../model/prelude.sail"

val blend64 : (bits(64), bits(64), bits(1)) -> bits(64)
function blend64(a, b, sel) = { let m : bits(64) = sign_extend(sel); (a & ~(m)) | (b & m) }

// ================================================================
// Proof: shufpd_lane using blend64 matches branchy version
// ================================================================

$property
function prop_shufpd_lane(src1 : bits(128), src2 : bits(128), ctrl0 : bits(1), ctrl1 : bits(1)) -> bool = {
  let lo_orig : bits(64) = if ctrl0 == 0b1 then src1[127..64] else src1[63..0];
  let hi_orig : bits(64) = if ctrl1 == 0b1 then src2[127..64] else src2[63..0];
  let orig : bits(128) = hi_orig @ lo_orig;
  let lo_new : bits(64) = blend64(src1[63..0], src1[127..64], ctrl0);
  let hi_new : bits(64) = blend64(src2[63..0], src2[127..64], ctrl1);
  let branchless : bits(128) = hi_new @ lo_new;
  orig == branchless
}

// Equivalence proof: FCMOVcc branchless conversion
//
// Old: if FLAG then x87_write_st(0, st(i))  [else st(0) unchanged]
// New: x87_write_st(0, blend(old_st0, st(i), FLAG))
//
// When FLAG=1: blend returns st(i), written to st(0). ✓
// When FLAG=0: blend returns old_st0, written to st(0) = no change. ✓

$include "../model/prelude.sail"

val blend : forall 'n, 0 < 'n. (bits('n), bits('n), bit) -> bits('n)
function blend(a, b, sel) = {
  let m : bits('n) = sign_extend(sel);
  (a & ~(m)) | (b & m)
}

$property
function prop_fcmov(old_st0 : bits(80), sti_val : bits(80), flag : bit) -> bool = {
  let orig : bits(80) = if flag == 0b1 then sti_val else old_st0;
  let branchless : bits(80) = blend(old_st0, sti_val, flag);
  orig == branchless
}

// Equivalence proof: CMPXCHG branchless conversion
//
// Old:
//   if ZF == 0b1 then { dest = src }
//   else { RAX = dest_val; dest = dest_val }
//
// New:
//   dest = blend(dest_val, src, ZF)
//   RAX = blend(dest_val, old_RAX, ZF)

$include "../model/prelude.sail"

val blend : forall 'n, 0 < 'n. (bits('n), bits('n), bit) -> bits('n)
function blend(a, b, sel) = {
  let m : bits('n) = sign_extend(sel);
  (a & ~(m)) | (b & m)
}

$property
function prop_cmpxchg_dest(dest_val : bits(32), src : bits(32), zf : bit) -> bool = {
  let orig : bits(32) = if zf == 0b1 then src else dest_val;
  let branchless : bits(32) = blend(dest_val, src, zf);
  orig == branchless
}

$property
function prop_cmpxchg_rax(dest_val : bits(32), old_rax : bits(32), zf : bit) -> bool = {
  let orig : bits(32) = if zf == 0b1 then old_rax else dest_val;
  let branchless : bits(32) = blend(dest_val, old_rax, zf);
  orig == branchless
}

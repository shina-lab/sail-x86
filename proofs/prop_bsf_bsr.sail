// Equivalence proof: BSF/BSR branchless conversion
//
// Old code:
//   if src_val == zeros() then { ZF = 1; PF = compute_PF(0x00) }
//   else { ZF = 0; PF = compute_PF(result[7..0]); v(reg) = result }
//
// New code:
//   let zf = is_zero(src_val);
//   ZF = zf;
//   PF = blend(compute_PF(result[7..0]), compute_PF(0x00), zf);
//   v(reg) = blend(result, old_dest, zf);
//
// blend(a, b, sel): sel=0 → a, sel=1 → b

$include "../model/prelude.sail"

val or_reduce : forall 'n, 0 < 'n & 'n <= 64. bits('n) -> bits(1)
function or_reduce(v) = {
  let x1 : bits(64) = zero_extend(v);
  let x2 = x1 | (x1 >> 1);
  let x3 = x2 | (x2 >> 2);
  let x4 = x3 | (x3 >> 4);
  let x5 = x4 | (x4 >> 8);
  let x6 = x5 | (x5 >> 16);
  let x7 = x6 | (x6 >> 32);
  x7[0]
}

val is_zero : forall 'n, 0 < 'n & 'n <= 64. bits('n) -> bit
function is_zero(v) = (~(or_reduce(v)))[0]

val blend : forall 'n, 0 < 'n. (bits('n), bits('n), bit) -> bits('n)
function blend(a, b, sel) = {
  let m : bits('n) = sign_extend(sel);
  (a & ~(m)) | (b & m)
}

// Prove: ZF assignment
$property
function prop_bsf_zf(src : bits(32)) -> bool = {
  let orig_zf : bit = if src == zeros() then 0b1 else 0b0;
  let new_zf : bit = is_zero(src);
  orig_zf == new_zf
}

// Prove: PF blend selects correctly
$property
function prop_bsf_pf(pf_nonzero : bit, pf_zero : bit, src : bits(32)) -> bool = {
  let orig_pf : bit = if src == zeros() then pf_zero else pf_nonzero;
  let zf : bit = is_zero(src);
  let new_pf : bit = blend(pf_nonzero, pf_zero, zf);
  orig_pf == new_pf
}

// Prove: dest blend preserves old value when zero, writes new when nonzero
$property
function prop_bsf_dest(old_dest : bits(32), new_result : bits(32), src : bits(32)) -> bool = {
  // Old: if zero then old_dest (unchanged), else new_result
  let orig : bits(32) = if src == zeros() then old_dest else new_result;
  let zf : bit = is_zero(src);
  let branchless : bits(32) = blend(new_result, old_dest, zf);
  orig == branchless
}

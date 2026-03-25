// Equivalence proof: BEXTR branchless conversion
//
// Old:
//   if start < os then {
//     let shifted = src >> start;
//     if len >= os then result = shifted
//     else result = (shifted << (os-len)) >> (os-len)
//   } else result = 0
//
// New:
//   let cs = min(start, os); let cl = min(len, os)
//   result = (src >> cs << (os - cl)) >> (os - cl)

$include "../model/prelude.sail"

val is_gt_u : forall 'n, 0 < 'n & 'n <= 64. (bits('n), bits('n)) -> bit
function is_gt_u(a, b) = {
  let diff : bits('n + 1) = zero_extend(b) - zero_extend(a);
  diff['n]
}

val blend : forall 'n, 0 < 'n. (bits('n), bits('n), bit) -> bits('n)
function blend(a, b, sel) = {
  let m : bits('n) = sign_extend(sel);
  (a & ~(m)) | (b & m)
}

val min_u : forall 'n, 0 < 'n & 'n <= 64. (bits('n), bits('n)) -> bits('n)
function min_u(a, b) = blend(a, b, is_gt_u(a, b))

$property
function prop_bextr(src : bits(32), start : bits(9), len : bits(9)) -> bool = {
  let os = 32;
  let s = unsigned(start);
  let l = unsigned(len);
  // Old
  var orig : bits(32) = zeros();
  if s < os then {
    let shifted : bits(32) = src >> s;
    if l >= os then orig = shifted
    else {
      let sa : range(0, 255) = os - l;
      orig = (shifted << sa) >> sa
    }
  };
  // New
  let cs = unsigned(min_u(start, to_bits(9, os)));
  assert(cs <= os);
  let cl = unsigned(min_u(len, to_bits(9, os)));
  assert(cl <= os);
  let shifted : bits(32) = src >> cs;
  let sa = os - cl;
  let branchless : bits(32) = (shifted << sa) >> sa;
  orig == branchless
}

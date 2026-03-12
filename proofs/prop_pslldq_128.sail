$include "../model/prelude.sail"

type xmmword = bits(128)

$property
function prop_pslldq_128(a : xmmword, count_bits : bits(8)) -> bool = {
  let count : range(0, 255) = unsigned(count_bits);

  // Original (clamped):
  let cnt_orig = if count > 15 then 16 else count;
  let orig : xmmword = a << (cnt_orig * 8);

  // New (unclamped):
  let branchless : xmmword = a << (count * 8);

  orig == branchless
}

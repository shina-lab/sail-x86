$include "../model/prelude.sail"

type word    = bits(16)
type xmmword = bits(128)

$property
function prop_psllw_imm_128(a : xmmword, count_bits : bits(8)) -> bool = {
  let count : range(0, 255) = unsigned(count_bits);

  // Original (branching):
  var orig : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    orig[(lo + 15)..lo] = if count >= 16 then zeros() else a[(lo + 15)..lo] << count;
  };

  // New (branchless):
  var branchless : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    branchless[(lo + 15)..lo] = a[(lo + 15)..lo] << count;
  };

  orig == branchless
}

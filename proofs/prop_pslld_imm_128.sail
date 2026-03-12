$include "../model/prelude.sail"

type dword   = bits(32)
type xmmword = bits(128)

$property
function prop_pslld_imm_128(a : xmmword, count_bits : bits(8)) -> bool = {
  let count : range(0, 255) = unsigned(count_bits);

  // Original (branching):
  var orig : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    orig[(lo + 31)..lo] = if count >= 32 then zeros() else a[(lo + 31)..lo] << count;
  };

  // New (branchless):
  var branchless : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    branchless[(lo + 31)..lo] = a[(lo + 31)..lo] << count;
  };

  orig == branchless
}

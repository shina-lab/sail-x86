$include "../model/prelude.sail"

type word    = bits(16)
type xmmword = bits(128)

overload operator - = {sub_bits}
overload operator + = {add_bits}
overload operator ^ = {xor_vec}
overload operator & = {and_vec}
overload operator | = {or_vec}

// Prove that logical right shift on 16-bit elements already produces zeros
// when count >= 16, so the `if count >= 16 then zeros() else ...` branch
// is redundant.

$property
function prop_psrlw_imm_128(a : xmmword, count_bits : bits(8)) -> bool = {
  let count : range(0, 255) = unsigned(count_bits);

  // Original (branching):
  var orig : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    orig[(lo + 15)..lo] = if count >= 16 then zeros() else a[(lo + 15)..lo] >> count;
  };

  // New (branchless):
  var branchless : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    branchless[(lo + 15)..lo] = a[(lo + 15)..lo] >> count;
  };

  orig == branchless
}

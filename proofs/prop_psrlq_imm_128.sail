$include "../model/prelude.sail"

type qword   = bits(64)
type xmmword = bits(128)

// Prove that logical right shift on 64-bit elements already produces zeros
// when count >= 64, so the branch is redundant.

$property
function prop_psrlq_imm_128(a : xmmword, count_bits : bits(8)) -> bool = {
  let count : range(0, 255) = unsigned(count_bits);

  // Original (branching):
  var orig : xmmword = zeros();
  orig[63..0] = if count >= 64 then zeros() else a[63..0] >> count;
  orig[127..64] = if count >= 64 then zeros() else a[127..64] >> count;

  // New (branchless):
  var branchless : xmmword = zeros();
  branchless[63..0] = a[63..0] >> count;
  branchless[127..64] = a[127..64] >> count;

  orig == branchless
}

$include "../model/prelude.sail"

type qword = bits(64)

// ================================================================
// Proof: popcount_qword branchless version matches branching version
//
// Same per-bit change as popcount_dword:
//   if mask[i] == bitone then count = count + 1
// becomes:
//   count = count + unsigned(mask[i..i])
// ================================================================

// Per-bit: the branching increment equals unsigned(bit)
$property
function prop_popcount_bit(mask : qword) -> bool = {
  var all_ok : bool = true;
  foreach (i from 0 to 63) {
    let orig : int = if mask[i] == bitone then 1 else 0;
    let branchless : int = unsigned(mask[i..i]);
    all_ok = all_ok & (orig == branchless);
  };
  all_ok
}

// Full function equivalence for upto=16 (manageable size)
val popcount_qword_orig : (qword, int) -> int
function popcount_qword_orig(mask, upto) = {
  var count : int = 0;
  foreach (i from 0 to 63) {
    if i < upto then {
      if mask[i] == bitone then count = count + 1;
    };
  };
  count
}

val popcount_qword_new : (qword, int) -> int
function popcount_qword_new(mask, upto) = {
  var count : int = 0;
  foreach (i from 0 to 63) {
    if i < upto then {
      count = count + unsigned(mask[i..i]);
    };
  };
  count
}

$property
function prop_popcount_qword_0(mask : qword) -> bool =
  popcount_qword_orig(mask, 0) == popcount_qword_new(mask, 0)

$property
function prop_popcount_qword_16(mask : qword) -> bool =
  popcount_qword_orig(mask, 16) == popcount_qword_new(mask, 16)

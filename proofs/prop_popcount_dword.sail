$include "../model/prelude.sail"

type dword = bits(32)

// ================================================================
// Proof: popcount_dword branchless version matches branching version
//
// The only change is replacing:
//   if mask[i] == bitone then count = count + 1
// with:
//   count = count + unsigned(mask[i..i])
//
// We prove per-bit equivalence (the surrounding loop and i < upto
// guard are structurally identical and unchanged).
// ================================================================

// Per-bit: the branching increment equals unsigned(bit)
$property
function prop_popcount_bit(mask : dword) -> bool = {
  var all_ok : bool = true;
  foreach (i from 0 to 31) {
    let orig : int = if mask[i] == bitone then 1 else 0;
    let branchless : int = unsigned(mask[i..i]);
    all_ok = all_ok & (orig == branchless);
  };
  all_ok
}

// Full function equivalence for upto=16 (manageable size)
val popcount_dword_orig : (dword, int) -> int
function popcount_dword_orig(mask, upto) = {
  var count : int = 0;
  foreach (i from 0 to 31) {
    if i < upto then {
      if mask[i] == bitone then count = count + 1;
    };
  };
  count
}

val popcount_dword_new : (dword, int) -> int
function popcount_dword_new(mask, upto) = {
  var count : int = 0;
  foreach (i from 0 to 31) {
    if i < upto then {
      count = count + unsigned(mask[i..i]);
    };
  };
  count
}

$property
function prop_popcount_dword_0(mask : dword) -> bool =
  popcount_dword_orig(mask, 0) == popcount_dword_new(mask, 0)

$property
function prop_popcount_dword_16(mask : dword) -> bool =
  popcount_dword_orig(mask, 16) == popcount_dword_new(mask, 16)

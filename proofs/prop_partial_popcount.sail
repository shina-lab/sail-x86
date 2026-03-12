default Order dec

$include <prelude.sail>

overload operator - = {sub_bits}
overload operator + = {add_bits}
overload operator & = {and_vec}
overload operator | = {or_vec}
overload zeros = {sail_zeros}

val "shiftl" : forall 'm 'n, 'n >= 0. (bits('m), int('n)) -> bits('m)

val popcount8 : bits(8) -> range(0, 8)
function popcount8(v) =
  unsigned(v[0..0]) + unsigned(v[1..1]) + unsigned(v[2..2]) + unsigned(v[3..3]) +
  unsigned(v[4..4]) + unsigned(v[5..5]) + unsigned(v[6..6]) + unsigned(v[7..7])

// Prove: popcount of lower `upto` bits via mask == loop-based partial popcount
$property
function prop_partial_popcount8(mask : bits(8), upto_bits : bits(4)) -> bool = {
  let upto : range(0, 15) = unsigned(upto_bits);

  // Original: loop-based partial popcount
  var count : int = 0;
  foreach (i from 0 to 7) {
    if i < upto then {
      if mask[i] == bitone then count = count + 1;
    };
  };

  // Branchless: mask lower bits, then popcount
  let lo_mask : bits(8) = shiftl(0x01 : bits(8), upto) - 0x01;
  let branchless : int = popcount8(mask & lo_mask);

  count == branchless
}

val popcount16 : bits(16) -> range(0, 16)
function popcount16(v) =
  popcount8(v[7..0]) + popcount8(v[15..8])

$property
function prop_partial_popcount16(mask : bits(16), upto_bits : bits(5)) -> bool = {
  let upto : range(0, 31) = unsigned(upto_bits);

  var count : int = 0;
  foreach (i from 0 to 15) {
    if i < upto then {
      if mask[i] == bitone then count = count + 1;
    };
  };

  let lo_mask : bits(16) = shiftl(0x0001 : bits(16), upto) - 0x0001;
  let branchless : int = popcount16(mask & lo_mask);

  count == branchless
}

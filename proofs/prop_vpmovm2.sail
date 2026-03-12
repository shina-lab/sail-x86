// Full-width equivalence proofs for VPMOVM2B/W/D/Q branchless conversion.
// Pattern: if k[i] == bitone then ones/0xFF/... else zeros/0x00/...
//        → zeros() - zero_extend([k[i]])

default Order dec
$include <prelude.sail>

overload operator - = {sub_bits}
overload zeros = {sail_zeros}
overload zero_extend = {sail_zero_extend}

// VPMOVM2B 128-bit: 16 byte lanes from mask bits
$property
function prop_vpmovm2b_128(k: bits(64)) -> bool = {
  var orig : bits(128) = sail_zeros(128);
  foreach (i from 0 to 15) {
    let lo : range(0, 120) = i * 8;
    orig[(lo + 7)..lo] = if k[i] == bitone then 0xFF else 0x00;
  };
  var branchless : bits(128) = sail_zeros(128);
  foreach (i from 0 to 15) {
    let lo : range(0, 120) = i * 8;
    branchless[(lo + 7)..lo] = zeros(8) - zero_extend([k[i]], 8);
  };
  orig == branchless
}

// VPMOVM2W 128-bit: 8 word lanes from mask bits
$property
function prop_vpmovm2w_128(k: bits(64)) -> bool = {
  var orig : bits(128) = sail_zeros(128);
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    orig[(lo + 15)..lo] = if k[i] == bitone then 0xFFFF else 0x0000;
  };
  var branchless : bits(128) = sail_zeros(128);
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    branchless[(lo + 15)..lo] = zeros(16) - zero_extend([k[i]], 16);
  };
  orig == branchless
}

// VPMOVM2D 128-bit: 4 dword lanes from mask bits
$property
function prop_vpmovm2d_128(k: bits(64)) -> bool = {
  var orig : bits(128) = sail_zeros(128);
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    orig[(lo + 31)..lo] = if k[i] == bitone then 0xFFFFFFFF else 0x00000000;
  };
  var branchless : bits(128) = sail_zeros(128);
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    branchless[(lo + 31)..lo] = zeros(32) - zero_extend([k[i]], 32);
  };
  orig == branchless
}

// VPMOVM2Q 128-bit: 2 qword lanes from mask bits
$property
function prop_vpmovm2q_128(k: bits(64)) -> bool = {
  var orig : bits(128) = sail_zeros(128);
  foreach (i from 0 to 1) {
    let lo : range(0, 64) = i * 64;
    orig[(lo + 63)..lo] = if k[i] == bitone then sail_ones(64) else sail_zeros(64);
  };
  var branchless : bits(128) = sail_zeros(128);
  foreach (i from 0 to 1) {
    let lo : range(0, 64) = i * 64;
    branchless[(lo + 63)..lo] = zeros(64) - zero_extend([k[i]], 64);
  };
  orig == branchless
}

// Full-width equivalence proofs for EVEX VPCMPEQQ k-mask branchless conversion.
// EVEX VPCMPEQQ produces a k-mask byte (1 bit per qword lane), not all-ones/zeros.
// Original: if src1[lane] == src2[lane] then mask = mask | to_bits(8, pow2(i))
// New:      mask[i] = cmp_eq64(src1[lane], src2[lane])[0]

default Order dec
$include <prelude.sail>

overload operator - = {sub_bits}
overload zeros = {sail_zeros}
overload zero_extend = {sail_zero_extend}

val cmp_eq64 : (bits(64), bits(64)) -> bits(64)
function cmp_eq64(a, b) = {
  let xd : bits(65) = (0b0 @ (a ^ b)) - zero_extend(0b1 : bits(1), 65);
  zeros(64) - zero_extend(xd[64..64], 64)
}

// EVEX VPCMPEQQ 128-bit: 2 qword lanes → 2-bit mask in byte
$property
function prop_vpcmpeqq_evex128(src1 : bits(128), src2 : bits(128)) -> bool = {
  // Original (branching)
  var mask : bits(8) = 0x00;
  if src1[63..0] == src2[63..0] then mask = mask | 0x01;
  if src1[127..64] == src2[127..64] then mask = mask | 0x02;

  // New (branchless)
  var branchless : bits(8) = 0x00;
  branchless[0] = cmp_eq64(src1[63..0], src2[63..0])[0];
  branchless[1] = cmp_eq64(src1[127..64], src2[127..64])[0];

  mask == branchless
}

// EVEX VPCMPEQQ 256-bit: 4 qword lanes → 4-bit mask in byte
$property
function prop_vpcmpeqq_evex256(src1 : bits(256), src2 : bits(256)) -> bool = {
  // Original (branching)
  var mask : bits(8) = 0x00;
  if src1[63..0] == src2[63..0] then mask = mask | 0x01;
  if src1[127..64] == src2[127..64] then mask = mask | 0x02;
  if src1[191..128] == src2[191..128] then mask = mask | 0x04;
  if src1[255..192] == src2[255..192] then mask = mask | 0x08;

  // New (branchless)
  var branchless : bits(8) = 0x00;
  branchless[0] = cmp_eq64(src1[63..0], src2[63..0])[0];
  branchless[1] = cmp_eq64(src1[127..64], src2[127..64])[0];
  branchless[2] = cmp_eq64(src1[191..128], src2[191..128])[0];
  branchless[3] = cmp_eq64(src1[255..192], src2[255..192])[0];

  mask == branchless
}

// EVEX VPCMPEQQ 512-bit: 8 qword lanes → 8-bit mask
$property
function prop_vpcmpeqq_evex512(src1 : bits(512), src2 : bits(512)) -> bool = {
  // Original (branching)
  var mask : bits(8) = 0x00;
  if src1[63..0] == src2[63..0] then mask = mask | 0x01;
  if src1[127..64] == src2[127..64] then mask = mask | 0x02;
  if src1[191..128] == src2[191..128] then mask = mask | 0x04;
  if src1[255..192] == src2[255..192] then mask = mask | 0x08;
  if src1[319..256] == src2[319..256] then mask = mask | 0x10;
  if src1[383..320] == src2[383..320] then mask = mask | 0x20;
  if src1[447..384] == src2[447..384] then mask = mask | 0x40;
  if src1[511..448] == src2[511..448] then mask = mask | 0x80;

  // New (branchless)
  var branchless : bits(8) = 0x00;
  branchless[0] = cmp_eq64(src1[63..0], src2[63..0])[0];
  branchless[1] = cmp_eq64(src1[127..64], src2[127..64])[0];
  branchless[2] = cmp_eq64(src1[191..128], src2[191..128])[0];
  branchless[3] = cmp_eq64(src1[255..192], src2[255..192])[0];
  branchless[4] = cmp_eq64(src1[319..256], src2[319..256])[0];
  branchless[5] = cmp_eq64(src1[383..320], src2[383..320])[0];
  branchless[6] = cmp_eq64(src1[447..384], src2[447..384])[0];
  branchless[7] = cmp_eq64(src1[511..448], src2[511..448])[0];

  mask == branchless
}

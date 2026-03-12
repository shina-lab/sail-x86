// Full-width equivalence proofs for PCMPGTD / VPCMPGTD branchless conversion.
//
// Proves all variants: MMX (64-bit), SSE (128-bit), VEX (128/256-bit),
// and EVEX mask (128/256/512-bit).

default Order dec
$include <prelude.sail>

overload operator - = {sub_bits}
overload zeros = {sail_zeros}
overload ones = {sail_ones}
overload zero_extend = {sail_zero_extend}
overload sign_extend = {sail_sign_extend}

val cmp_gt32 : (bits(32), bits(32)) -> bits(32)
function cmp_gt32(a, b) = {
  let a33 : bits(33) = sign_extend(a, 33);
  let b33 : bits(33) = sign_extend(b, 33);
  let diff : bits(33) = b33 - a33;
  zeros(32) - zero_extend(diff[32..32], 32)
}

// MMX PCMPGTD: 64-bit (2 dword lanes)
$property
function prop_pcmpgtd_mmx(a: bits(64), b: bits(64)) -> bool = {
  let r1 : bits(32) = if signed(a[63..32]) > signed(b[63..32]) then ones(32) else zeros(32);
  let r0 : bits(32) = if signed(a[31..0])  > signed(b[31..0])  then ones(32) else zeros(32);
  let orig : bits(64) = r1 @ r0;

  let branchless : bits(64) = cmp_gt32(a[63..32], b[63..32]) @ cmp_gt32(a[31..0], b[31..0]);

  orig == branchless
}

// SSE PCMPGTD: 128-bit (4 dword lanes)
$property
function prop_pcmpgtd_sse(a: bits(128), b: bits(128)) -> bool = {
  let r3 : bits(32) = if signed(a[127..96]) > signed(b[127..96]) then ones(32) else zeros(32);
  let r2 : bits(32) = if signed(a[95..64])  > signed(b[95..64])  then ones(32) else zeros(32);
  let r1 : bits(32) = if signed(a[63..32])  > signed(b[63..32])  then ones(32) else zeros(32);
  let r0 : bits(32) = if signed(a[31..0])   > signed(b[31..0])   then ones(32) else zeros(32);
  let orig : bits(128) = r3 @ r2 @ r1 @ r0;

  let branchless : bits(128) =
    cmp_gt32(a[127..96], b[127..96]) @
    cmp_gt32(a[95..64], b[95..64]) @
    cmp_gt32(a[63..32], b[63..32]) @
    cmp_gt32(a[31..0], b[31..0]);

  orig == branchless
}

// VEX VPCMPGTD 256-bit (8 dword lanes)
$property
function prop_pcmpgtd_vex256(a: bits(256), b: bits(256)) -> bool = {
  let r7 : bits(32) = if signed(a[255..224]) > signed(b[255..224]) then ones(32) else zeros(32);
  let r6 : bits(32) = if signed(a[223..192]) > signed(b[223..192]) then ones(32) else zeros(32);
  let r5 : bits(32) = if signed(a[191..160]) > signed(b[191..160]) then ones(32) else zeros(32);
  let r4 : bits(32) = if signed(a[159..128]) > signed(b[159..128]) then ones(32) else zeros(32);
  let r3 : bits(32) = if signed(a[127..96])  > signed(b[127..96])  then ones(32) else zeros(32);
  let r2 : bits(32) = if signed(a[95..64])   > signed(b[95..64])   then ones(32) else zeros(32);
  let r1 : bits(32) = if signed(a[63..32])   > signed(b[63..32])   then ones(32) else zeros(32);
  let r0 : bits(32) = if signed(a[31..0])    > signed(b[31..0])    then ones(32) else zeros(32);
  let orig : bits(256) = r7 @ r6 @ r5 @ r4 @ r3 @ r2 @ r1 @ r0;

  let branchless : bits(256) =
    cmp_gt32(a[255..224], b[255..224]) @ cmp_gt32(a[223..192], b[223..192]) @
    cmp_gt32(a[191..160], b[191..160]) @ cmp_gt32(a[159..128], b[159..128]) @
    cmp_gt32(a[127..96], b[127..96]) @ cmp_gt32(a[95..64], b[95..64]) @
    cmp_gt32(a[63..32], b[63..32]) @ cmp_gt32(a[31..0], b[31..0]);

  orig == branchless
}

// EVEX VPCMPGTD mask 128-bit (4 lanes → 4-bit mask in byte)
$property
function prop_pcmpgtd_evex128(a: bits(128), b: bits(128)) -> bool = {
  var orig : bits(8) = zeros(8);
  if signed(a[31..0])   > signed(b[31..0])   then orig[0] = bitone;
  if signed(a[63..32])  > signed(b[63..32])  then orig[1] = bitone;
  if signed(a[95..64])  > signed(b[95..64])  then orig[2] = bitone;
  if signed(a[127..96]) > signed(b[127..96]) then orig[3] = bitone;

  var branchless : bits(8) = zeros(8);
  let _ = branchless[0] = cmp_gt32(a[31..0], b[31..0])[0];
  let _ = branchless[1] = cmp_gt32(a[63..32], b[63..32])[0];
  let _ = branchless[2] = cmp_gt32(a[95..64], b[95..64])[0];
  let _ = branchless[3] = cmp_gt32(a[127..96], b[127..96])[0];

  orig == branchless
}

// EVEX VPCMPGTD mask 256-bit (8 lanes → 8-bit mask)
$property
function prop_pcmpgtd_evex256(a: bits(256), b: bits(256)) -> bool = {
  var orig : bits(8) = zeros(8);
  if signed(a[31..0])    > signed(b[31..0])    then orig[0] = bitone;
  if signed(a[63..32])   > signed(b[63..32])   then orig[1] = bitone;
  if signed(a[95..64])   > signed(b[95..64])   then orig[2] = bitone;
  if signed(a[127..96])  > signed(b[127..96])  then orig[3] = bitone;
  if signed(a[159..128]) > signed(b[159..128]) then orig[4] = bitone;
  if signed(a[191..160]) > signed(b[191..160]) then orig[5] = bitone;
  if signed(a[223..192]) > signed(b[223..192]) then orig[6] = bitone;
  if signed(a[255..224]) > signed(b[255..224]) then orig[7] = bitone;

  var branchless : bits(8) = zeros(8);
  let _ = branchless[0] = cmp_gt32(a[31..0], b[31..0])[0];
  let _ = branchless[1] = cmp_gt32(a[63..32], b[63..32])[0];
  let _ = branchless[2] = cmp_gt32(a[95..64], b[95..64])[0];
  let _ = branchless[3] = cmp_gt32(a[127..96], b[127..96])[0];
  let _ = branchless[4] = cmp_gt32(a[159..128], b[159..128])[0];
  let _ = branchless[5] = cmp_gt32(a[191..160], b[191..160])[0];
  let _ = branchless[6] = cmp_gt32(a[223..192], b[223..192])[0];
  let _ = branchless[7] = cmp_gt32(a[255..224], b[255..224])[0];

  orig == branchless
}

// EVEX VPCMPGTD mask 512-bit (16 lanes → 16-bit mask)
$property
function prop_pcmpgtd_evex512(a: bits(512), b: bits(512)) -> bool = {
  var orig : bits(16) = zeros(16);
  if signed(a[31..0])    > signed(b[31..0])    then orig[0] = bitone;
  if signed(a[63..32])   > signed(b[63..32])   then orig[1] = bitone;
  if signed(a[95..64])   > signed(b[95..64])   then orig[2] = bitone;
  if signed(a[127..96])  > signed(b[127..96])  then orig[3] = bitone;
  if signed(a[159..128]) > signed(b[159..128]) then orig[4] = bitone;
  if signed(a[191..160]) > signed(b[191..160]) then orig[5] = bitone;
  if signed(a[223..192]) > signed(b[223..192]) then orig[6] = bitone;
  if signed(a[255..224]) > signed(b[255..224]) then orig[7] = bitone;
  if signed(a[287..256]) > signed(b[287..256]) then orig[8] = bitone;
  if signed(a[319..288]) > signed(b[319..288]) then orig[9] = bitone;
  if signed(a[351..320]) > signed(b[351..320]) then orig[10] = bitone;
  if signed(a[383..352]) > signed(b[383..352]) then orig[11] = bitone;
  if signed(a[415..384]) > signed(b[415..384]) then orig[12] = bitone;
  if signed(a[447..416]) > signed(b[447..416]) then orig[13] = bitone;
  if signed(a[479..448]) > signed(b[479..448]) then orig[14] = bitone;
  if signed(a[511..480]) > signed(b[511..480]) then orig[15] = bitone;

  var branchless : bits(16) = zeros(16);
  let _ = branchless[0]  = cmp_gt32(a[31..0], b[31..0])[0];
  let _ = branchless[1]  = cmp_gt32(a[63..32], b[63..32])[0];
  let _ = branchless[2]  = cmp_gt32(a[95..64], b[95..64])[0];
  let _ = branchless[3]  = cmp_gt32(a[127..96], b[127..96])[0];
  let _ = branchless[4]  = cmp_gt32(a[159..128], b[159..128])[0];
  let _ = branchless[5]  = cmp_gt32(a[191..160], b[191..160])[0];
  let _ = branchless[6]  = cmp_gt32(a[223..192], b[223..192])[0];
  let _ = branchless[7]  = cmp_gt32(a[255..224], b[255..224])[0];
  let _ = branchless[8]  = cmp_gt32(a[287..256], b[287..256])[0];
  let _ = branchless[9]  = cmp_gt32(a[319..288], b[319..288])[0];
  let _ = branchless[10] = cmp_gt32(a[351..320], b[351..320])[0];
  let _ = branchless[11] = cmp_gt32(a[383..352], b[383..352])[0];
  let _ = branchless[12] = cmp_gt32(a[415..384], b[415..384])[0];
  let _ = branchless[13] = cmp_gt32(a[447..416], b[447..416])[0];
  let _ = branchless[14] = cmp_gt32(a[479..448], b[479..448])[0];
  let _ = branchless[15] = cmp_gt32(a[511..480], b[511..480])[0];

  orig == branchless
}

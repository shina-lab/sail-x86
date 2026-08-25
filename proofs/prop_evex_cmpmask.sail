// Full-width equivalence proofs for EVEX compare-to-mask branchless conversion.
// Uses fixed indexing instead of loops to avoid Sail SMT encoding issues.

$include "../model/prelude.sail"


val cmp_eq8 : (bits(8), bits(8)) -> bits(8)
function cmp_eq8(a, b) = {
  let xd : bits(9) = (0b0 @ (a ^ b)) - 0b000000001;
  zeros(8) - zero_extend(xd[8..8])
}

val cmp_gt8 : (bits(8), bits(8)) -> bits(8)
function cmp_gt8(a, b) = {
  let a9 : bits(9) = sign_extend(a);
  let b9 : bits(9) = sign_extend(b);
  let diff : bits(9) = b9 - a9;
  zeros(8) - zero_extend(diff[8..8])
}

val cmp_eq16 : (bits(16), bits(16)) -> bits(16)
function cmp_eq16(a, b) = {
  let xd : bits(17) = (0b0 @ (a ^ b)) - 0b00000000000000001;
  zeros(16) - zero_extend(xd[16..16])
}

val cmp_gt16 : (bits(16), bits(16)) -> bits(16)
function cmp_gt16(a, b) = {
  let a17 : bits(17) = sign_extend(a);
  let b17 : bits(17) = sign_extend(b);
  let diff : bits(17) = b17 - a17;
  zeros(16) - zero_extend(diff[16..16])
}

val cmp_eq32 : (bits(32), bits(32)) -> bits(32)
function cmp_eq32(a, b) = {
  let xd : bits(33) = (0b0 @ (a ^ b)) - 0b000000000000000000000000000000001;
  zeros(32) - zero_extend(xd[32..32])
}

// VPCMPEQB mask 128-bit: 16 byte lanes → 16-bit mask
$property
function prop_pcmpeqb_mask_128(a: bits(128), b: bits(128)) -> bool = {
  var orig : bits(16) = zeros(16);
  if a[7..0]     == b[7..0]     then orig[0]  = bitone;
  if a[15..8]    == b[15..8]    then orig[1]  = bitone;
  if a[23..16]   == b[23..16]   then orig[2]  = bitone;
  if a[31..24]   == b[31..24]   then orig[3]  = bitone;
  if a[39..32]   == b[39..32]   then orig[4]  = bitone;
  if a[47..40]   == b[47..40]   then orig[5]  = bitone;
  if a[55..48]   == b[55..48]   then orig[6]  = bitone;
  if a[63..56]   == b[63..56]   then orig[7]  = bitone;
  if a[71..64]   == b[71..64]   then orig[8]  = bitone;
  if a[79..72]   == b[79..72]   then orig[9]  = bitone;
  if a[87..80]   == b[87..80]   then orig[10] = bitone;
  if a[95..88]   == b[95..88]   then orig[11] = bitone;
  if a[103..96]  == b[103..96]  then orig[12] = bitone;
  if a[111..104] == b[111..104] then orig[13] = bitone;
  if a[119..112] == b[119..112] then orig[14] = bitone;
  if a[127..120] == b[127..120] then orig[15] = bitone;

  let branchless : bits(16) =
    [cmp_eq8(a[127..120], b[127..120])[0]] @
    [cmp_eq8(a[119..112], b[119..112])[0]] @
    [cmp_eq8(a[111..104], b[111..104])[0]] @
    [cmp_eq8(a[103..96], b[103..96])[0]] @
    [cmp_eq8(a[95..88], b[95..88])[0]] @
    [cmp_eq8(a[87..80], b[87..80])[0]] @
    [cmp_eq8(a[79..72], b[79..72])[0]] @
    [cmp_eq8(a[71..64], b[71..64])[0]] @
    [cmp_eq8(a[63..56], b[63..56])[0]] @
    [cmp_eq8(a[55..48], b[55..48])[0]] @
    [cmp_eq8(a[47..40], b[47..40])[0]] @
    [cmp_eq8(a[39..32], b[39..32])[0]] @
    [cmp_eq8(a[31..24], b[31..24])[0]] @
    [cmp_eq8(a[23..16], b[23..16])[0]] @
    [cmp_eq8(a[15..8], b[15..8])[0]] @
    [cmp_eq8(a[7..0], b[7..0])[0]];

  orig == branchless
}

// VPCMPEQD mask 128-bit: 4 dword lanes → 4-bit mask in byte
$property
function prop_pcmpeqd_mask_128(a: bits(128), b: bits(128)) -> bool = {
  var orig : bits(8) = zeros(8);
  if a[31..0]    == b[31..0]    then orig[0] = bitone;
  if a[63..32]   == b[63..32]   then orig[1] = bitone;
  if a[95..64]   == b[95..64]   then orig[2] = bitone;
  if a[127..96]  == b[127..96]  then orig[3] = bitone;

  var branchless : bits(8) = zeros(8);
  let _ = branchless[0] = cmp_eq32(a[31..0], b[31..0])[0];
  let _ = branchless[1] = cmp_eq32(a[63..32], b[63..32])[0];
  let _ = branchless[2] = cmp_eq32(a[95..64], b[95..64])[0];
  let _ = branchless[3] = cmp_eq32(a[127..96], b[127..96])[0];

  orig == branchless
}

// VPCMPEQW mask 128-bit: 8 word lanes → 8-bit mask
$property
function prop_pcmpeqw_mask_128(a: bits(128), b: bits(128)) -> bool = {
  var orig : bits(8) = zeros(8);
  if a[15..0]    == b[15..0]    then orig[0] = bitone;
  if a[31..16]   == b[31..16]   then orig[1] = bitone;
  if a[47..32]   == b[47..32]   then orig[2] = bitone;
  if a[63..48]   == b[63..48]   then orig[3] = bitone;
  if a[79..64]   == b[79..64]   then orig[4] = bitone;
  if a[95..80]   == b[95..80]   then orig[5] = bitone;
  if a[111..96]  == b[111..96]  then orig[6] = bitone;
  if a[127..112] == b[127..112] then orig[7] = bitone;

  var branchless : bits(8) = zeros(8);
  let _ = branchless[0] = cmp_eq16(a[15..0], b[15..0])[0];
  let _ = branchless[1] = cmp_eq16(a[31..16], b[31..16])[0];
  let _ = branchless[2] = cmp_eq16(a[47..32], b[47..32])[0];
  let _ = branchless[3] = cmp_eq16(a[63..48], b[63..48])[0];
  let _ = branchless[4] = cmp_eq16(a[79..64], b[79..64])[0];
  let _ = branchless[5] = cmp_eq16(a[95..80], b[95..80])[0];
  let _ = branchless[6] = cmp_eq16(a[111..96], b[111..96])[0];
  let _ = branchless[7] = cmp_eq16(a[127..112], b[127..112])[0];

  orig == branchless
}

// VPCMPGTB mask 128-bit: 16 byte lanes → 16-bit mask
$property
function prop_pcmpgtb_mask_128(a: bits(128), b: bits(128)) -> bool = {
  var orig : bits(16) = zeros(16);
  if signed(a[7..0])     > signed(b[7..0])     then orig[0]  = bitone;
  if signed(a[15..8])    > signed(b[15..8])     then orig[1]  = bitone;
  if signed(a[23..16])   > signed(b[23..16])   then orig[2]  = bitone;
  if signed(a[31..24])   > signed(b[31..24])   then orig[3]  = bitone;
  if signed(a[39..32])   > signed(b[39..32])   then orig[4]  = bitone;
  if signed(a[47..40])   > signed(b[47..40])   then orig[5]  = bitone;
  if signed(a[55..48])   > signed(b[55..48])   then orig[6]  = bitone;
  if signed(a[63..56])   > signed(b[63..56])   then orig[7]  = bitone;
  if signed(a[71..64])   > signed(b[71..64])   then orig[8]  = bitone;
  if signed(a[79..72])   > signed(b[79..72])   then orig[9]  = bitone;
  if signed(a[87..80])   > signed(b[87..80])   then orig[10] = bitone;
  if signed(a[95..88])   > signed(b[95..88])   then orig[11] = bitone;
  if signed(a[103..96])  > signed(b[103..96])  then orig[12] = bitone;
  if signed(a[111..104]) > signed(b[111..104]) then orig[13] = bitone;
  if signed(a[119..112]) > signed(b[119..112]) then orig[14] = bitone;
  if signed(a[127..120]) > signed(b[127..120]) then orig[15] = bitone;

  let branchless : bits(16) =
    [cmp_gt8(a[127..120], b[127..120])[0]] @
    [cmp_gt8(a[119..112], b[119..112])[0]] @
    [cmp_gt8(a[111..104], b[111..104])[0]] @
    [cmp_gt8(a[103..96], b[103..96])[0]] @
    [cmp_gt8(a[95..88], b[95..88])[0]] @
    [cmp_gt8(a[87..80], b[87..80])[0]] @
    [cmp_gt8(a[79..72], b[79..72])[0]] @
    [cmp_gt8(a[71..64], b[71..64])[0]] @
    [cmp_gt8(a[63..56], b[63..56])[0]] @
    [cmp_gt8(a[55..48], b[55..48])[0]] @
    [cmp_gt8(a[47..40], b[47..40])[0]] @
    [cmp_gt8(a[39..32], b[39..32])[0]] @
    [cmp_gt8(a[31..24], b[31..24])[0]] @
    [cmp_gt8(a[23..16], b[23..16])[0]] @
    [cmp_gt8(a[15..8], b[15..8])[0]] @
    [cmp_gt8(a[7..0], b[7..0])[0]];

  orig == branchless
}

// VPCMPGTW mask 128-bit: 8 word lanes → 8-bit mask
$property
function prop_pcmpgtw_mask_128(a: bits(128), b: bits(128)) -> bool = {
  var orig : bits(8) = zeros(8);
  if signed(a[15..0])    > signed(b[15..0])    then orig[0] = bitone;
  if signed(a[31..16])   > signed(b[31..16])   then orig[1] = bitone;
  if signed(a[47..32])   > signed(b[47..32])   then orig[2] = bitone;
  if signed(a[63..48])   > signed(b[63..48])   then orig[3] = bitone;
  if signed(a[79..64])   > signed(b[79..64])   then orig[4] = bitone;
  if signed(a[95..80])   > signed(b[95..80])   then orig[5] = bitone;
  if signed(a[111..96])  > signed(b[111..96])  then orig[6] = bitone;
  if signed(a[127..112]) > signed(b[127..112]) then orig[7] = bitone;

  var branchless : bits(8) = zeros(8);
  let _ = branchless[0] = cmp_gt16(a[15..0], b[15..0])[0];
  let _ = branchless[1] = cmp_gt16(a[31..16], b[31..16])[0];
  let _ = branchless[2] = cmp_gt16(a[47..32], b[47..32])[0];
  let _ = branchless[3] = cmp_gt16(a[63..48], b[63..48])[0];
  let _ = branchless[4] = cmp_gt16(a[79..64], b[79..64])[0];
  let _ = branchless[5] = cmp_gt16(a[95..80], b[95..80])[0];
  let _ = branchless[6] = cmp_gt16(a[111..96], b[111..96])[0];
  let _ = branchless[7] = cmp_gt16(a[127..112], b[127..112])[0];

  orig == branchless
}

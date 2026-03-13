$include "../model/prelude.sail"

// --- blend helpers (textually identical to model code) ---

val blend_byte : (bits(8), bits(8), bits(1)) -> bits(8)
function blend_byte(a, b, sel) = { let m : bits(8) = sign_extend(sel); (a & ~(m)) | (b & m) }

val blend16 : (bits(16), bits(16), bits(1)) -> bits(16)
function blend16(a, b, sel) = { let m : bits(16) = sign_extend(sel); (a & ~(m)) | (b & m) }

val blend32 : (bits(32), bits(32), bits(1)) -> bits(32)
function blend32(a, b, sel) = { let m : bits(32) = sign_extend(sel); (a & ~(m)) | (b & m) }

val blend64 : (bits(64), bits(64), bits(1)) -> bits(64)
function blend64(a, b, sel) = { let m : bits(64) = sign_extend(sel); (a & ~(m)) | (b & m) }

// ================================================================
// VPBLENDMD 128-bit: 4 dword lanes, k-mask blend with zeroing
// ================================================================
// Original: var result = dst & z_keep; foreach i { if k[i] then src2 else if !z then src1 }
// Branchless: let src1_eff = src1 & z_keep; foreach i { blend32(src1_eff, src2, k[i]) }

$property
function prop_vpblendmd_128(src1 : bits(128), src2 : bits(128), k : bits(4), z : bits(1), dst : bits(128)) -> bool = {
  let z_keep : bits(128) = zeros() - zero_extend(~(z));

  // Original (branching)
  var orig : bits(128) = dst & z_keep;
  if k[0] == bitone then orig[31..0] = src2[31..0]
  else if z == 0b0 then orig[31..0] = src1[31..0];
  if k[1] == bitone then orig[63..32] = src2[63..32]
  else if z == 0b0 then orig[63..32] = src1[63..32];
  if k[2] == bitone then orig[95..64] = src2[95..64]
  else if z == 0b0 then orig[95..64] = src1[95..64];
  if k[3] == bitone then orig[127..96] = src2[127..96]
  else if z == 0b0 then orig[127..96] = src1[127..96];

  // New (branchless)
  let src1_eff : bits(128) = src1 & z_keep;
  let branchless : bits(128) =
    blend32(src1_eff[127..96], src2[127..96], k[3..3]) @
    blend32(src1_eff[95..64], src2[95..64], k[2..2]) @
    blend32(src1_eff[63..32], src2[63..32], k[1..1]) @
    blend32(src1_eff[31..0], src2[31..0], k[0..0]);

  orig == branchless
}

// ================================================================
// VPBLENDMQ 128-bit: 2 qword lanes
// ================================================================

$property
function prop_vpblendmq_128(src1 : bits(128), src2 : bits(128), k : bits(2), z : bits(1), dst : bits(128)) -> bool = {
  let z_keep : bits(128) = zeros() - zero_extend(~(z));

  // Original (branching)
  var orig : bits(128) = dst & z_keep;
  if k[0] == bitone then orig[63..0] = src2[63..0]
  else if z == 0b0 then orig[63..0] = src1[63..0];
  if k[1] == bitone then orig[127..64] = src2[127..64]
  else if z == 0b0 then orig[127..64] = src1[127..64];

  // New (branchless)
  let src1_eff : bits(128) = src1 & z_keep;
  let branchless : bits(128) =
    blend64(src1_eff[127..64], src2[127..64], k[1..1]) @
    blend64(src1_eff[63..0], src2[63..0], k[0..0]);

  orig == branchless
}

// ================================================================
// VPBLENDMW 128-bit: 8 word lanes
// ================================================================

$property
function prop_vpblendmw_128(src1 : bits(128), src2 : bits(128), k : bits(8), z : bits(1), dst : bits(128)) -> bool = {
  let z_keep : bits(128) = zeros() - zero_extend(~(z));

  // Original (branching)
  var orig : bits(128) = dst & z_keep;
  if k[0] == bitone then orig[15..0] = src2[15..0]
  else if z == 0b0 then orig[15..0] = src1[15..0];
  if k[1] == bitone then orig[31..16] = src2[31..16]
  else if z == 0b0 then orig[31..16] = src1[31..16];
  if k[2] == bitone then orig[47..32] = src2[47..32]
  else if z == 0b0 then orig[47..32] = src1[47..32];
  if k[3] == bitone then orig[63..48] = src2[63..48]
  else if z == 0b0 then orig[63..48] = src1[63..48];
  if k[4] == bitone then orig[79..64] = src2[79..64]
  else if z == 0b0 then orig[79..64] = src1[79..64];
  if k[5] == bitone then orig[95..80] = src2[95..80]
  else if z == 0b0 then orig[95..80] = src1[95..80];
  if k[6] == bitone then orig[111..96] = src2[111..96]
  else if z == 0b0 then orig[111..96] = src1[111..96];
  if k[7] == bitone then orig[127..112] = src2[127..112]
  else if z == 0b0 then orig[127..112] = src1[127..112];

  // New (branchless)
  let src1_eff : bits(128) = src1 & z_keep;
  let branchless : bits(128) =
    blend16(src1_eff[127..112], src2[127..112], k[7..7]) @
    blend16(src1_eff[111..96], src2[111..96], k[6..6]) @
    blend16(src1_eff[95..80], src2[95..80], k[5..5]) @
    blend16(src1_eff[79..64], src2[79..64], k[4..4]) @
    blend16(src1_eff[63..48], src2[63..48], k[3..3]) @
    blend16(src1_eff[47..32], src2[47..32], k[2..2]) @
    blend16(src1_eff[31..16], src2[31..16], k[1..1]) @
    blend16(src1_eff[15..0], src2[15..0], k[0..0]);

  orig == branchless
}

// ================================================================
// VPBLENDMB 128-bit: 16 byte lanes
// ================================================================

$property
function prop_vpblendmb_128(src1 : bits(128), src2 : bits(128), k : bits(16), z : bits(1), dst : bits(128)) -> bool = {
  let z_keep : bits(128) = zeros() - zero_extend(~(z));

  // Original (branching)
  var orig : bits(128) = dst & z_keep;
  if k[0] == bitone then orig[7..0] = src2[7..0]
  else if z == 0b0 then orig[7..0] = src1[7..0];
  if k[1] == bitone then orig[15..8] = src2[15..8]
  else if z == 0b0 then orig[15..8] = src1[15..8];
  if k[2] == bitone then orig[23..16] = src2[23..16]
  else if z == 0b0 then orig[23..16] = src1[23..16];
  if k[3] == bitone then orig[31..24] = src2[31..24]
  else if z == 0b0 then orig[31..24] = src1[31..24];
  if k[4] == bitone then orig[39..32] = src2[39..32]
  else if z == 0b0 then orig[39..32] = src1[39..32];
  if k[5] == bitone then orig[47..40] = src2[47..40]
  else if z == 0b0 then orig[47..40] = src1[47..40];
  if k[6] == bitone then orig[55..48] = src2[55..48]
  else if z == 0b0 then orig[55..48] = src1[55..48];
  if k[7] == bitone then orig[63..56] = src2[63..56]
  else if z == 0b0 then orig[63..56] = src1[63..56];
  if k[8] == bitone then orig[71..64] = src2[71..64]
  else if z == 0b0 then orig[71..64] = src1[71..64];
  if k[9] == bitone then orig[79..72] = src2[79..72]
  else if z == 0b0 then orig[79..72] = src1[79..72];
  if k[10] == bitone then orig[87..80] = src2[87..80]
  else if z == 0b0 then orig[87..80] = src1[87..80];
  if k[11] == bitone then orig[95..88] = src2[95..88]
  else if z == 0b0 then orig[95..88] = src1[95..88];
  if k[12] == bitone then orig[103..96] = src2[103..96]
  else if z == 0b0 then orig[103..96] = src1[103..96];
  if k[13] == bitone then orig[111..104] = src2[111..104]
  else if z == 0b0 then orig[111..104] = src1[111..104];
  if k[14] == bitone then orig[119..112] = src2[119..112]
  else if z == 0b0 then orig[119..112] = src1[119..112];
  if k[15] == bitone then orig[127..120] = src2[127..120]
  else if z == 0b0 then orig[127..120] = src1[127..120];

  // New (branchless)
  let src1_eff : bits(128) = src1 & z_keep;
  let branchless : bits(128) =
    blend_byte(src1_eff[127..120], src2[127..120], k[15..15]) @
    blend_byte(src1_eff[119..112], src2[119..112], k[14..14]) @
    blend_byte(src1_eff[111..104], src2[111..104], k[13..13]) @
    blend_byte(src1_eff[103..96], src2[103..96], k[12..12]) @
    blend_byte(src1_eff[95..88], src2[95..88], k[11..11]) @
    blend_byte(src1_eff[87..80], src2[87..80], k[10..10]) @
    blend_byte(src1_eff[79..72], src2[79..72], k[9..9]) @
    blend_byte(src1_eff[71..64], src2[71..64], k[8..8]) @
    blend_byte(src1_eff[63..56], src2[63..56], k[7..7]) @
    blend_byte(src1_eff[55..48], src2[55..48], k[6..6]) @
    blend_byte(src1_eff[47..40], src2[47..40], k[5..5]) @
    blend_byte(src1_eff[39..32], src2[39..32], k[4..4]) @
    blend_byte(src1_eff[31..24], src2[31..24], k[3..3]) @
    blend_byte(src1_eff[23..16], src2[23..16], k[2..2]) @
    blend_byte(src1_eff[15..8], src2[15..8], k[1..1]) @
    blend_byte(src1_eff[7..0], src2[7..0], k[0..0]);

  orig == branchless
}

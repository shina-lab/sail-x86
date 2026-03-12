// Full-width equivalence proofs for unsigned min/max branchless helpers.

default Order dec
$include <prelude.sail>

overload operator - = {sub_bits}
overload operator & = {and_vec}
overload operator | = {or_vec}
overload zeros = {sail_zeros}
overload zero_extend = {sail_zero_extend}

val not_vec_bits : forall 'n. bits('n) -> bits('n)
function not_vec_bits(x) = not_vec(x)

// --- unsigned min helpers ---

val min_u8 : (bits(8), bits(8)) -> bits(8)
function min_u8(a, b) = {
  let diff : bits(9) = (0b0 @ a) - (0b0 @ b);
  let mask : bits(8) = zeros(8) - zero_extend(diff[8..8], 8);
  (a & mask) | (b & not_vec_bits(mask))
}

val min_u16 : (bits(16), bits(16)) -> bits(16)
function min_u16(a, b) = {
  let diff : bits(17) = (0b0 @ a) - (0b0 @ b);
  let mask : bits(16) = zeros(16) - zero_extend(diff[16..16], 16);
  (a & mask) | (b & not_vec_bits(mask))
}

val min_u32 : (bits(32), bits(32)) -> bits(32)
function min_u32(a, b) = {
  let diff : bits(33) = (0b0 @ a) - (0b0 @ b);
  let mask : bits(32) = zeros(32) - zero_extend(diff[32..32], 32);
  (a & mask) | (b & not_vec_bits(mask))
}

// --- unsigned max helpers ---

val max_u8 : (bits(8), bits(8)) -> bits(8)
function max_u8(a, b) = {
  let diff : bits(9) = (0b0 @ a) - (0b0 @ b);
  let mask : bits(8) = zeros(8) - zero_extend(diff[8..8], 8);
  (b & mask) | (a & not_vec_bits(mask))
}

val max_u16 : (bits(16), bits(16)) -> bits(16)
function max_u16(a, b) = {
  let diff : bits(17) = (0b0 @ a) - (0b0 @ b);
  let mask : bits(16) = zeros(16) - zero_extend(diff[16..16], 16);
  (b & mask) | (a & not_vec_bits(mask))
}

val max_u32 : (bits(32), bits(32)) -> bits(32)
function max_u32(a, b) = {
  let diff : bits(33) = (0b0 @ a) - (0b0 @ b);
  let mask : bits(32) = zeros(32) - zero_extend(diff[32..32], 32);
  (b & mask) | (a & not_vec_bits(mask))
}

// =========================================================================
// min_u8: 128-bit (16 byte lanes)
// =========================================================================
$property
function prop_pminub_128(a: bits(128), b: bits(128)) -> bool = {
  let orig : bits(128) =
    (if unsigned(a[127..120]) < unsigned(b[127..120]) then a[127..120] else b[127..120]) @
    (if unsigned(a[119..112]) < unsigned(b[119..112]) then a[119..112] else b[119..112]) @
    (if unsigned(a[111..104]) < unsigned(b[111..104]) then a[111..104] else b[111..104]) @
    (if unsigned(a[103..96])  < unsigned(b[103..96])  then a[103..96]  else b[103..96])  @
    (if unsigned(a[95..88])   < unsigned(b[95..88])   then a[95..88]   else b[95..88])   @
    (if unsigned(a[87..80])   < unsigned(b[87..80])   then a[87..80]   else b[87..80])   @
    (if unsigned(a[79..72])   < unsigned(b[79..72])   then a[79..72]   else b[79..72])   @
    (if unsigned(a[71..64])   < unsigned(b[71..64])   then a[71..64]   else b[71..64])   @
    (if unsigned(a[63..56])   < unsigned(b[63..56])   then a[63..56]   else b[63..56])   @
    (if unsigned(a[55..48])   < unsigned(b[55..48])   then a[55..48]   else b[55..48])   @
    (if unsigned(a[47..40])   < unsigned(b[47..40])   then a[47..40]   else b[47..40])   @
    (if unsigned(a[39..32])   < unsigned(b[39..32])   then a[39..32]   else b[39..32])   @
    (if unsigned(a[31..24])   < unsigned(b[31..24])   then a[31..24]   else b[31..24])   @
    (if unsigned(a[23..16])   < unsigned(b[23..16])   then a[23..16]   else b[23..16])   @
    (if unsigned(a[15..8])    < unsigned(b[15..8])    then a[15..8]    else b[15..8])    @
    (if unsigned(a[7..0])     < unsigned(b[7..0])     then a[7..0]     else b[7..0]);
  let branchless : bits(128) =
    min_u8(a[127..120], b[127..120]) @ min_u8(a[119..112], b[119..112]) @
    min_u8(a[111..104], b[111..104]) @ min_u8(a[103..96],  b[103..96])  @
    min_u8(a[95..88],   b[95..88])   @ min_u8(a[87..80],   b[87..80])   @
    min_u8(a[79..72],   b[79..72])   @ min_u8(a[71..64],   b[71..64])   @
    min_u8(a[63..56],   b[63..56])   @ min_u8(a[55..48],   b[55..48])   @
    min_u8(a[47..40],   b[47..40])   @ min_u8(a[39..32],   b[39..32])   @
    min_u8(a[31..24],   b[31..24])   @ min_u8(a[23..16],   b[23..16])   @
    min_u8(a[15..8],    b[15..8])    @ min_u8(a[7..0],     b[7..0]);
  orig == branchless
}

// =========================================================================
// min_u16: 128-bit (8 word lanes)
// =========================================================================
$property
function prop_pminuw_128(a: bits(128), b: bits(128)) -> bool = {
  let orig : bits(128) =
    (if unsigned(a[127..112]) < unsigned(b[127..112]) then a[127..112] else b[127..112]) @
    (if unsigned(a[111..96])  < unsigned(b[111..96])  then a[111..96]  else b[111..96])  @
    (if unsigned(a[95..80])   < unsigned(b[95..80])   then a[95..80]   else b[95..80])   @
    (if unsigned(a[79..64])   < unsigned(b[79..64])   then a[79..64]   else b[79..64])   @
    (if unsigned(a[63..48])   < unsigned(b[63..48])   then a[63..48]   else b[63..48])   @
    (if unsigned(a[47..32])   < unsigned(b[47..32])   then a[47..32]   else b[47..32])   @
    (if unsigned(a[31..16])   < unsigned(b[31..16])   then a[31..16]   else b[31..16])   @
    (if unsigned(a[15..0])    < unsigned(b[15..0])    then a[15..0]    else b[15..0]);
  let branchless : bits(128) =
    min_u16(a[127..112], b[127..112]) @ min_u16(a[111..96],  b[111..96])  @
    min_u16(a[95..80],   b[95..80])   @ min_u16(a[79..64],   b[79..64])   @
    min_u16(a[63..48],   b[63..48])   @ min_u16(a[47..32],   b[47..32])   @
    min_u16(a[31..16],   b[31..16])   @ min_u16(a[15..0],    b[15..0]);
  orig == branchless
}

// =========================================================================
// min_u32: 128-bit (4 dword lanes)
// =========================================================================
$property
function prop_pminud_128(a: bits(128), b: bits(128)) -> bool = {
  let orig : bits(128) =
    (if unsigned(a[127..96]) < unsigned(b[127..96]) then a[127..96] else b[127..96]) @
    (if unsigned(a[95..64])  < unsigned(b[95..64])  then a[95..64]  else b[95..64])  @
    (if unsigned(a[63..32])  < unsigned(b[63..32])  then a[63..32]  else b[63..32])  @
    (if unsigned(a[31..0])   < unsigned(b[31..0])   then a[31..0]   else b[31..0]);
  let branchless : bits(128) =
    min_u32(a[127..96], b[127..96]) @
    min_u32(a[95..64],  b[95..64])  @
    min_u32(a[63..32],  b[63..32])  @
    min_u32(a[31..0],   b[31..0]);
  orig == branchless
}

// =========================================================================
// max_u8: 128-bit (16 byte lanes)
// =========================================================================
$property
function prop_pmaxub_128(a: bits(128), b: bits(128)) -> bool = {
  let orig : bits(128) =
    (if unsigned(a[127..120]) > unsigned(b[127..120]) then a[127..120] else b[127..120]) @
    (if unsigned(a[119..112]) > unsigned(b[119..112]) then a[119..112] else b[119..112]) @
    (if unsigned(a[111..104]) > unsigned(b[111..104]) then a[111..104] else b[111..104]) @
    (if unsigned(a[103..96])  > unsigned(b[103..96])  then a[103..96]  else b[103..96])  @
    (if unsigned(a[95..88])   > unsigned(b[95..88])   then a[95..88]   else b[95..88])   @
    (if unsigned(a[87..80])   > unsigned(b[87..80])   then a[87..80]   else b[87..80])   @
    (if unsigned(a[79..72])   > unsigned(b[79..72])   then a[79..72]   else b[79..72])   @
    (if unsigned(a[71..64])   > unsigned(b[71..64])   then a[71..64]   else b[71..64])   @
    (if unsigned(a[63..56])   > unsigned(b[63..56])   then a[63..56]   else b[63..56])   @
    (if unsigned(a[55..48])   > unsigned(b[55..48])   then a[55..48]   else b[55..48])   @
    (if unsigned(a[47..40])   > unsigned(b[47..40])   then a[47..40]   else b[47..40])   @
    (if unsigned(a[39..32])   > unsigned(b[39..32])   then a[39..32]   else b[39..32])   @
    (if unsigned(a[31..24])   > unsigned(b[31..24])   then a[31..24]   else b[31..24])   @
    (if unsigned(a[23..16])   > unsigned(b[23..16])   then a[23..16]   else b[23..16])   @
    (if unsigned(a[15..8])    > unsigned(b[15..8])    then a[15..8]    else b[15..8])    @
    (if unsigned(a[7..0])     > unsigned(b[7..0])     then a[7..0]     else b[7..0]);
  let branchless : bits(128) =
    max_u8(a[127..120], b[127..120]) @ max_u8(a[119..112], b[119..112]) @
    max_u8(a[111..104], b[111..104]) @ max_u8(a[103..96],  b[103..96])  @
    max_u8(a[95..88],   b[95..88])   @ max_u8(a[87..80],   b[87..80])   @
    max_u8(a[79..72],   b[79..72])   @ max_u8(a[71..64],   b[71..64])   @
    max_u8(a[63..56],   b[63..56])   @ max_u8(a[55..48],   b[55..48])   @
    max_u8(a[47..40],   b[47..40])   @ max_u8(a[39..32],   b[39..32])   @
    max_u8(a[31..24],   b[31..24])   @ max_u8(a[23..16],   b[23..16])   @
    max_u8(a[15..8],    b[15..8])    @ max_u8(a[7..0],     b[7..0]);
  orig == branchless
}

// =========================================================================
// max_u16: 128-bit (8 word lanes)
// =========================================================================
$property
function prop_pmaxuw_128(a: bits(128), b: bits(128)) -> bool = {
  let orig : bits(128) =
    (if unsigned(a[127..112]) > unsigned(b[127..112]) then a[127..112] else b[127..112]) @
    (if unsigned(a[111..96])  > unsigned(b[111..96])  then a[111..96]  else b[111..96])  @
    (if unsigned(a[95..80])   > unsigned(b[95..80])   then a[95..80]   else b[95..80])   @
    (if unsigned(a[79..64])   > unsigned(b[79..64])   then a[79..64]   else b[79..64])   @
    (if unsigned(a[63..48])   > unsigned(b[63..48])   then a[63..48]   else b[63..48])   @
    (if unsigned(a[47..32])   > unsigned(b[47..32])   then a[47..32]   else b[47..32])   @
    (if unsigned(a[31..16])   > unsigned(b[31..16])   then a[31..16]   else b[31..16])   @
    (if unsigned(a[15..0])    > unsigned(b[15..0])    then a[15..0]    else b[15..0]);
  let branchless : bits(128) =
    max_u16(a[127..112], b[127..112]) @ max_u16(a[111..96],  b[111..96])  @
    max_u16(a[95..80],   b[95..80])   @ max_u16(a[79..64],   b[79..64])   @
    max_u16(a[63..48],   b[63..48])   @ max_u16(a[47..32],   b[47..32])   @
    max_u16(a[31..16],   b[31..16])   @ max_u16(a[15..0],    b[15..0]);
  orig == branchless
}

// =========================================================================
// max_u32: 128-bit (4 dword lanes)
// =========================================================================
$property
function prop_pmaxud_128(a: bits(128), b: bits(128)) -> bool = {
  let orig : bits(128) =
    (if unsigned(a[127..96]) > unsigned(b[127..96]) then a[127..96] else b[127..96]) @
    (if unsigned(a[95..64])  > unsigned(b[95..64])  then a[95..64]  else b[95..64])  @
    (if unsigned(a[63..32])  > unsigned(b[63..32])  then a[63..32]  else b[63..32])  @
    (if unsigned(a[31..0])   > unsigned(b[31..0])   then a[31..0]   else b[31..0]);
  let branchless : bits(128) =
    max_u32(a[127..96], b[127..96]) @
    max_u32(a[95..64],  b[95..64])  @
    max_u32(a[63..32],  b[63..32])  @
    max_u32(a[31..0],   b[31..0]);
  orig == branchless
}

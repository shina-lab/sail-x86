$include "../model/prelude.sail"

type byte    = bits(8)
type word    = bits(16)
type dword   = bits(32)
type qword   = bits(64)
type xmmword = bits(128)
type ymmword = bits(256)
type zmmword = bits(512)

// Local or_reduce helpers (same as model/types.sail)
val or_reduce_8 : byte -> bits(1)
function or_reduce_8(v) = {
  let v4 : bits(4) = v[7..4] | v[3..0];
  let v2 : bits(2) = v4[3..2] | v4[1..0];
  (v2[1..1] | v2[0..0])
}

val or_reduce_16 : word -> bits(1)
function or_reduce_16(v) = or_reduce_8(v[15..8] | v[7..0])

val or_reduce_32 : dword -> bits(1)
function or_reduce_32(v) = or_reduce_16(v[31..16] | v[15..0])

val or_reduce_64 : qword -> bits(1)
function or_reduce_64(v) = or_reduce_32(v[63..32] | v[31..0])

// ================================================================
// Proof: or_reduce_32(x) == 0b1 iff x != zeros()
// (This is the fundamental lemma behind all VPTESTM conversions)
// ================================================================

$property
function prop_or_reduce_32_nonzero(x : dword) -> bool = {
  let is_nonzero : bool = (x != zeros());
  let or_bit : bool = (or_reduce_32(x) == 0b1);
  is_nonzero == or_bit
}

$property
function prop_or_reduce_8_nonzero(x : byte) -> bool = {
  let is_nonzero : bool = (x != zeros());
  let or_bit : bool = (or_reduce_8(x) == 0b1);
  is_nonzero == or_bit
}

$property
function prop_or_reduce_16_nonzero(x : word) -> bool = {
  let is_nonzero : bool = (x != zeros());
  let or_bit : bool = (or_reduce_16(x) == 0b1);
  is_nonzero == or_bit
}

$property
function prop_or_reduce_64_nonzero(x : qword) -> bool = {
  let is_nonzero : bool = (x != zeros());
  let or_bit : bool = (or_reduce_64(x) == 0b1);
  is_nonzero == or_bit
}

// ================================================================
// Proof: ptestmd_128 unrolled matches branchless
// (foreach doesn't encode in SMT; this unrolled version is what the
//  foreach actually computes)
// ================================================================

val avx_ptestmd_128_unrolled : (xmmword, xmmword) -> byte
function avx_ptestmd_128_unrolled(a, b) = {
  var r : byte = zeros();
  if (a[31..0]   & b[31..0])   != zeros() then r[0] = bitone;
  if (a[63..32]  & b[63..32])  != zeros() then r[1] = bitone;
  if (a[95..64]  & b[95..64])  != zeros() then r[2] = bitone;
  if (a[127..96] & b[127..96]) != zeros() then r[3] = bitone;
  r
}

val avx_ptestmd_128_new : (xmmword, xmmword) -> byte
function avx_ptestmd_128_new(a, b) =
  0x0 @
  or_reduce_32(a[127..96] & b[127..96]) @
  or_reduce_32(a[95..64]  & b[95..64]) @
  or_reduce_32(a[63..32]  & b[63..32]) @
  or_reduce_32(a[31..0]   & b[31..0])

$property
function prop_ptestmd_128(a : xmmword, b : xmmword) -> bool =
  avx_ptestmd_128_unrolled(a, b) == avx_ptestmd_128_new(a, b)

// ================================================================
// ptestnmd_128 (NOT variant)
// ================================================================

val avx_ptestnmd_128_unrolled : (xmmword, xmmword) -> byte
function avx_ptestnmd_128_unrolled(a, b) = {
  var r : byte = zeros();
  if (a[31..0]   & b[31..0])   == zeros() then r[0] = bitone;
  if (a[63..32]  & b[63..32])  == zeros() then r[1] = bitone;
  if (a[95..64]  & b[95..64])  == zeros() then r[2] = bitone;
  if (a[127..96] & b[127..96]) == zeros() then r[3] = bitone;
  r
}

val avx_ptestnmd_128_new : (xmmword, xmmword) -> byte
function avx_ptestnmd_128_new(a, b) =
  0x0 @
  (~(or_reduce_32(a[127..96] & b[127..96]))) @
  (~(or_reduce_32(a[95..64]  & b[95..64]))) @
  (~(or_reduce_32(a[63..32]  & b[63..32]))) @
  (~(or_reduce_32(a[31..0]   & b[31..0])))

$property
function prop_ptestnmd_128(a : xmmword, b : xmmword) -> bool =
  avx_ptestnmd_128_unrolled(a, b) == avx_ptestnmd_128_new(a, b)

// ================================================================
// ptestmb_128: 16 × 8-bit
// ================================================================

val avx_ptestmb_128_unrolled : (xmmword, xmmword) -> word
function avx_ptestmb_128_unrolled(a, b) = {
  var r : word = zeros();
  if (a[7..0]     & b[7..0])     != zeros() then r[0]  = bitone;
  if (a[15..8]    & b[15..8])    != zeros() then r[1]  = bitone;
  if (a[23..16]   & b[23..16])   != zeros() then r[2]  = bitone;
  if (a[31..24]   & b[31..24])   != zeros() then r[3]  = bitone;
  if (a[39..32]   & b[39..32])   != zeros() then r[4]  = bitone;
  if (a[47..40]   & b[47..40])   != zeros() then r[5]  = bitone;
  if (a[55..48]   & b[55..48])   != zeros() then r[6]  = bitone;
  if (a[63..56]   & b[63..56])   != zeros() then r[7]  = bitone;
  if (a[71..64]   & b[71..64])   != zeros() then r[8]  = bitone;
  if (a[79..72]   & b[79..72])   != zeros() then r[9]  = bitone;
  if (a[87..80]   & b[87..80])   != zeros() then r[10] = bitone;
  if (a[95..88]   & b[95..88])   != zeros() then r[11] = bitone;
  if (a[103..96]  & b[103..96])  != zeros() then r[12] = bitone;
  if (a[111..104] & b[111..104]) != zeros() then r[13] = bitone;
  if (a[119..112] & b[119..112]) != zeros() then r[14] = bitone;
  if (a[127..120] & b[127..120]) != zeros() then r[15] = bitone;
  r
}

val avx_ptestmb_128_new : (xmmword, xmmword) -> word
function avx_ptestmb_128_new(a, b) =
  or_reduce_8(a[127..120] & b[127..120]) @
  or_reduce_8(a[119..112] & b[119..112]) @
  or_reduce_8(a[111..104] & b[111..104]) @
  or_reduce_8(a[103..96]  & b[103..96]) @
  or_reduce_8(a[95..88]   & b[95..88]) @
  or_reduce_8(a[87..80]   & b[87..80]) @
  or_reduce_8(a[79..72]   & b[79..72]) @
  or_reduce_8(a[71..64]   & b[71..64]) @
  or_reduce_8(a[63..56]   & b[63..56]) @
  or_reduce_8(a[55..48]   & b[55..48]) @
  or_reduce_8(a[47..40]   & b[47..40]) @
  or_reduce_8(a[39..32]   & b[39..32]) @
  or_reduce_8(a[31..24]   & b[31..24]) @
  or_reduce_8(a[23..16]   & b[23..16]) @
  or_reduce_8(a[15..8]    & b[15..8]) @
  or_reduce_8(a[7..0]     & b[7..0])

$property
function prop_ptestmb_128(a : xmmword, b : xmmword) -> bool =
  avx_ptestmb_128_unrolled(a, b) == avx_ptestmb_128_new(a, b)

// ================================================================
// ptestmw_128: 8 × 16-bit
// ================================================================

val avx_ptestmw_128_unrolled : (xmmword, xmmword) -> byte
function avx_ptestmw_128_unrolled(a, b) = {
  var r : byte = zeros();
  if (a[15..0]    & b[15..0])    != zeros() then r[0] = bitone;
  if (a[31..16]   & b[31..16])   != zeros() then r[1] = bitone;
  if (a[47..32]   & b[47..32])   != zeros() then r[2] = bitone;
  if (a[63..48]   & b[63..48])   != zeros() then r[3] = bitone;
  if (a[79..64]   & b[79..64])   != zeros() then r[4] = bitone;
  if (a[95..80]   & b[95..80])   != zeros() then r[5] = bitone;
  if (a[111..96]  & b[111..96])  != zeros() then r[6] = bitone;
  if (a[127..112] & b[127..112]) != zeros() then r[7] = bitone;
  r
}

val avx_ptestmw_128_new : (xmmword, xmmword) -> byte
function avx_ptestmw_128_new(a, b) =
  or_reduce_16(a[127..112] & b[127..112]) @
  or_reduce_16(a[111..96]  & b[111..96]) @
  or_reduce_16(a[95..80]   & b[95..80]) @
  or_reduce_16(a[79..64]   & b[79..64]) @
  or_reduce_16(a[63..48]   & b[63..48]) @
  or_reduce_16(a[47..32]   & b[47..32]) @
  or_reduce_16(a[31..16]   & b[31..16]) @
  or_reduce_16(a[15..0]    & b[15..0])

$property
function prop_ptestmw_128(a : xmmword, b : xmmword) -> bool =
  avx_ptestmw_128_unrolled(a, b) == avx_ptestmw_128_new(a, b)

$include "../model/prelude.sail"

type byte    = bits(8)
type word    = bits(16)
type dword   = bits(32)
type qword   = bits(64)
type xmmword = bits(128)
type ymmword = bits(256)
type zmmword = bits(512)

// ================================================================
// VPMOVD2M_128: extract MSB of each dword (4 elements) → qword mask
// ================================================================

val avx_vpmovd2m_128_orig : xmmword -> qword
function avx_vpmovd2m_128_orig(src) = {
  var result : qword = zeros();
  if src[31]  == bitone then result = result | (zero_extend(0b1 : bits(1)) << 0);
  if src[63]  == bitone then result = result | (zero_extend(0b1 : bits(1)) << 1);
  if src[95]  == bitone then result = result | (zero_extend(0b1 : bits(1)) << 2);
  if src[127] == bitone then result = result | (zero_extend(0b1 : bits(1)) << 3);
  result
}

val avx_vpmovd2m_128_new : xmmword -> qword
function avx_vpmovd2m_128_new(src) = {
  let mask : bits(4) = src[127..127] @ src[95..95] @ src[63..63] @ src[31..31];
  let r : qword = zero_extend(mask);
  r
}

$property
function prop_vpmovd2m_128(src : xmmword) -> bool =
  avx_vpmovd2m_128_orig(src) == avx_vpmovd2m_128_new(src)

// ================================================================
// VPMOVQ2M_128: extract MSB of each qword (2 elements)
// ================================================================

val avx_vpmovq2m_128_orig : xmmword -> qword
function avx_vpmovq2m_128_orig(src) = {
  var result : qword = zeros();
  if src[63]  == bitone then result = result | (zero_extend(0b1 : bits(1)) << 0);
  if src[127] == bitone then result = result | (zero_extend(0b1 : bits(1)) << 1);
  result
}

val avx_vpmovq2m_128_new : xmmword -> qword
function avx_vpmovq2m_128_new(src) = {
  let mask : bits(2) = src[127..127] @ src[63..63];
  let r : qword = zero_extend(mask);
  r
}

$property
function prop_vpmovq2m_128(src : xmmword) -> bool =
  avx_vpmovq2m_128_orig(src) == avx_vpmovq2m_128_new(src)

// ================================================================
// VPMOVW2M_128: extract MSB of each word (8 elements)
// ================================================================

val avx_vpmovw2m_128_orig : xmmword -> qword
function avx_vpmovw2m_128_orig(src) = {
  var result : qword = zeros();
  if src[15]  == bitone then result = result | (zero_extend(0b1 : bits(1)) << 0);
  if src[31]  == bitone then result = result | (zero_extend(0b1 : bits(1)) << 1);
  if src[47]  == bitone then result = result | (zero_extend(0b1 : bits(1)) << 2);
  if src[63]  == bitone then result = result | (zero_extend(0b1 : bits(1)) << 3);
  if src[79]  == bitone then result = result | (zero_extend(0b1 : bits(1)) << 4);
  if src[95]  == bitone then result = result | (zero_extend(0b1 : bits(1)) << 5);
  if src[111] == bitone then result = result | (zero_extend(0b1 : bits(1)) << 6);
  if src[127] == bitone then result = result | (zero_extend(0b1 : bits(1)) << 7);
  result
}

val avx_vpmovw2m_128_new : xmmword -> qword
function avx_vpmovw2m_128_new(src) = {
  let mask : byte =
    src[127..127] @ src[111..111] @ src[95..95] @ src[79..79] @
    src[63..63] @ src[47..47] @ src[31..31] @ src[15..15];
  let r : qword = zero_extend(mask);
  r
}

$property
function prop_vpmovw2m_128(src : xmmword) -> bool =
  avx_vpmovw2m_128_orig(src) == avx_vpmovw2m_128_new(src)

// ================================================================
// VPMOVB2M_128: extract MSB of each byte (16 elements)
// ================================================================

val avx_vpmovb2m_128_orig : xmmword -> qword
function avx_vpmovb2m_128_orig(src) = {
  var result : qword = zeros();
  if src[7]   == bitone then result = result | (zero_extend(0b1 : bits(1)) << 0);
  if src[15]  == bitone then result = result | (zero_extend(0b1 : bits(1)) << 1);
  if src[23]  == bitone then result = result | (zero_extend(0b1 : bits(1)) << 2);
  if src[31]  == bitone then result = result | (zero_extend(0b1 : bits(1)) << 3);
  if src[39]  == bitone then result = result | (zero_extend(0b1 : bits(1)) << 4);
  if src[47]  == bitone then result = result | (zero_extend(0b1 : bits(1)) << 5);
  if src[55]  == bitone then result = result | (zero_extend(0b1 : bits(1)) << 6);
  if src[63]  == bitone then result = result | (zero_extend(0b1 : bits(1)) << 7);
  if src[71]  == bitone then result = result | (zero_extend(0b1 : bits(1)) << 8);
  if src[79]  == bitone then result = result | (zero_extend(0b1 : bits(1)) << 9);
  if src[87]  == bitone then result = result | (zero_extend(0b1 : bits(1)) << 10);
  if src[95]  == bitone then result = result | (zero_extend(0b1 : bits(1)) << 11);
  if src[103] == bitone then result = result | (zero_extend(0b1 : bits(1)) << 12);
  if src[111] == bitone then result = result | (zero_extend(0b1 : bits(1)) << 13);
  if src[119] == bitone then result = result | (zero_extend(0b1 : bits(1)) << 14);
  if src[127] == bitone then result = result | (zero_extend(0b1 : bits(1)) << 15);
  result
}

val avx_vpmovb2m_128_new : xmmword -> qword
function avx_vpmovb2m_128_new(src) = {
  let mask : word =
    src[127..127] @ src[119..119] @ src[111..111] @ src[103..103] @
    src[95..95] @ src[87..87] @ src[79..79] @ src[71..71] @
    src[63..63] @ src[55..55] @ src[47..47] @ src[39..39] @
    src[31..31] @ src[23..23] @ src[15..15] @ src[7..7];
  let r : qword = zero_extend(mask);
  r
}

$property
function prop_vpmovb2m_128(src : xmmword) -> bool =
  avx_vpmovb2m_128_orig(src) == avx_vpmovb2m_128_new(src)

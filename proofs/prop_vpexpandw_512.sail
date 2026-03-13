$include "../model/prelude.sail"

// --- Helpers ---

val popcount32 : bits(32) -> range(0, 32)
function popcount32(v) =
  unsigned(v[0..0]) + unsigned(v[1..1]) + unsigned(v[2..2]) + unsigned(v[3..3]) +
  unsigned(v[4..4]) + unsigned(v[5..5]) + unsigned(v[6..6]) + unsigned(v[7..7]) +
  unsigned(v[8..8]) + unsigned(v[9..9]) + unsigned(v[10..10]) + unsigned(v[11..11]) +
  unsigned(v[12..12]) + unsigned(v[13..13]) + unsigned(v[14..14]) + unsigned(v[15..15]) +
  unsigned(v[16..16]) + unsigned(v[17..17]) + unsigned(v[18..18]) + unsigned(v[19..19]) +
  unsigned(v[20..20]) + unsigned(v[21..21]) + unsigned(v[22..22]) + unsigned(v[23..23]) +
  unsigned(v[24..24]) + unsigned(v[25..25]) + unsigned(v[26..26]) + unsigned(v[27..27]) +
  unsigned(v[28..28]) + unsigned(v[29..29]) + unsigned(v[30..30]) + unsigned(v[31..31])

val below_mask32 : int -> bits(32)
function below_mask32(i) = match i {
  0 => 0x00000000,
  1 => 0x00000001,
  2 => 0x00000003,
  3 => 0x00000007,
  4 => 0x0000000F,
  5 => 0x0000001F,
  6 => 0x0000003F,
  7 => 0x0000007F,
  8 => 0x000000FF,
  9 => 0x000001FF,
  10 => 0x000003FF,
  11 => 0x000007FF,
  12 => 0x00000FFF,
  13 => 0x00001FFF,
  14 => 0x00003FFF,
  15 => 0x00007FFF,
  16 => 0x0000FFFF,
  17 => 0x0001FFFF,
  18 => 0x0003FFFF,
  19 => 0x0007FFFF,
  20 => 0x000FFFFF,
  21 => 0x001FFFFF,
  22 => 0x003FFFFF,
  23 => 0x007FFFFF,
  24 => 0x00FFFFFF,
  25 => 0x01FFFFFF,
  26 => 0x03FFFFFF,
  27 => 0x07FFFFFF,
  28 => 0x0FFFFFFF,
  29 => 0x1FFFFFFF,
  30 => 0x3FFFFFFF,
  _ => 0x7FFFFFFF,
}

val popcount_below32 : (bits(32), int) -> int
function popcount_below32(mask, upto) = {
  assert(upto >= 0);
  popcount32(and_vec(mask, below_mask32(upto)))
}

val extract_word_512 : (bits(512), int) -> bits(16)
function extract_word_512(src, j) = match j {
  0 => src[15..0],
  1 => src[31..16],
  2 => src[47..32],
  3 => src[63..48],
  4 => src[79..64],
  5 => src[95..80],
  6 => src[111..96],
  7 => src[127..112],
  8 => src[143..128],
  9 => src[159..144],
  10 => src[175..160],
  11 => src[191..176],
  12 => src[207..192],
  13 => src[223..208],
  14 => src[239..224],
  15 => src[255..240],
  16 => src[271..256],
  17 => src[287..272],
  18 => src[303..288],
  19 => src[319..304],
  20 => src[335..320],
  21 => src[351..336],
  22 => src[367..352],
  23 => src[383..368],
  24 => src[399..384],
  25 => src[415..400],
  26 => src[431..416],
  27 => src[447..432],
  28 => src[463..448],
  29 => src[479..464],
  30 => src[495..480],
  _ => src[511..496],
}

val mask_word : (bits(16), bits(1)) -> bits(16)
function mask_word(v, sel) = {
  let m : bits(16) = sub_bits(sail_zeros(16), sail_zero_extend(sel, 16));
  and_vec(v, m)
}

// --- Original (branching) ---

val orig_vpexpandw_512 : (bits(512), bits(32)) -> bits(512)
function orig_vpexpandw_512(src, mask) = {
  var result : bits(512) = zeros();
  foreach (i from 0 to 31) {
    if mask[i] == bitone then {
      let j = popcount_below32(mask, i);
      assert(j >= 0);
      let src_elem : bits(16) = extract_word_512(src, j);
      result[(i * 16 + 15)..(i * 16)] = src_elem;
    };
  };
  result
}

// --- Branchless ---

val branchless_vpexpandw_512 : (bits(512), bits(32)) -> bits(512)
function branchless_vpexpandw_512(src, mask) = {
  var result : bits(512) = zeros();
  foreach (i from 0 to 31) {
    let j = popcount_below32(mask, i);
    assert(j >= 0);
    let src_elem : bits(16) = extract_word_512(src, j);
    result[(i * 16 + 15)..(i * 16)] = mask_word(src_elem, mask[i..i]);
  };
  result
}

// --- Full-width proof ---

$property
function prop_vpexpandw_512(src : bits(512), mask : bits(32)) -> bool = {
  let orig = orig_vpexpandw_512(src, mask);
  let branchless = branchless_vpexpandw_512(src, mask);
  orig == branchless
}

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

val extract_byte_256 : (bits(256), int) -> bits(8)
function extract_byte_256(src, j) = match j {
  0 => src[7..0],
  1 => src[15..8],
  2 => src[23..16],
  3 => src[31..24],
  4 => src[39..32],
  5 => src[47..40],
  6 => src[55..48],
  7 => src[63..56],
  8 => src[71..64],
  9 => src[79..72],
  10 => src[87..80],
  11 => src[95..88],
  12 => src[103..96],
  13 => src[111..104],
  14 => src[119..112],
  15 => src[127..120],
  16 => src[135..128],
  17 => src[143..136],
  18 => src[151..144],
  19 => src[159..152],
  20 => src[167..160],
  21 => src[175..168],
  22 => src[183..176],
  23 => src[191..184],
  24 => src[199..192],
  25 => src[207..200],
  26 => src[215..208],
  27 => src[223..216],
  28 => src[231..224],
  29 => src[239..232],
  30 => src[247..240],
  _ => src[255..248],
}

val mask_byte : (bits(8), bits(1)) -> bits(8)
function mask_byte(v, sel) = {
  let m : bits(8) = sub_bits(sail_zeros(8), sail_zero_extend(sel, 8));
  and_vec(v, m)
}

// --- Original (branching) ---

val orig_vpexpandb_256 : (bits(256), bits(32)) -> bits(256)
function orig_vpexpandb_256(src, mask) = {
  var result : bits(256) = zeros();
  foreach (i from 0 to 31) {
    if mask[i] == bitone then {
      let j = popcount_below32(mask, i);
      assert(j >= 0);
      let src_elem : bits(8) = extract_byte_256(src, j);
      result[(i * 8 + 7)..(i * 8)] = src_elem;
    };
  };
  result
}

// --- Branchless ---

val branchless_vpexpandb_256 : (bits(256), bits(32)) -> bits(256)
function branchless_vpexpandb_256(src, mask) = {
  var result : bits(256) = zeros();
  foreach (i from 0 to 31) {
    let j = popcount_below32(mask, i);
    assert(j >= 0);
    let src_elem : bits(8) = extract_byte_256(src, j);
    result[(i * 8 + 7)..(i * 8)] = mask_byte(src_elem, mask[i..i]);
  };
  result
}

// --- Full-width proof ---

$property
function prop_vpexpandb_256(src : bits(256), mask : bits(32)) -> bool = {
  let orig = orig_vpexpandb_256(src, mask);
  let branchless = branchless_vpexpandb_256(src, mask);
  orig == branchless
}

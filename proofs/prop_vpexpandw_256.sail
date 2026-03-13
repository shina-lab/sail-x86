$include "../model/prelude.sail"

// --- Helpers ---

val popcount16 : bits(16) -> range(0, 16)
function popcount16(v) =
  unsigned(v[0..0]) + unsigned(v[1..1]) + unsigned(v[2..2]) + unsigned(v[3..3]) +
  unsigned(v[4..4]) + unsigned(v[5..5]) + unsigned(v[6..6]) + unsigned(v[7..7]) +
  unsigned(v[8..8]) + unsigned(v[9..9]) + unsigned(v[10..10]) + unsigned(v[11..11]) +
  unsigned(v[12..12]) + unsigned(v[13..13]) + unsigned(v[14..14]) + unsigned(v[15..15])

val below_mask16 : int -> bits(16)
function below_mask16(i) = match i {
  0 => 0x0000,
  1 => 0x0001,
  2 => 0x0003,
  3 => 0x0007,
  4 => 0x000F,
  5 => 0x001F,
  6 => 0x003F,
  7 => 0x007F,
  8 => 0x00FF,
  9 => 0x01FF,
  10 => 0x03FF,
  11 => 0x07FF,
  12 => 0x0FFF,
  13 => 0x1FFF,
  14 => 0x3FFF,
  _ => 0x7FFF,
}

val popcount_below16 : (bits(16), int) -> int
function popcount_below16(mask, upto) = {
  assert(upto >= 0);
  popcount16(and_vec(mask, below_mask16(upto)))
}

val extract_word_256 : (bits(256), int) -> bits(16)
function extract_word_256(src, j) = match j {
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
  _ => src[255..240],
}

val mask_word : (bits(16), bits(1)) -> bits(16)
function mask_word(v, sel) = {
  let m : bits(16) = sub_bits(sail_zeros(16), sail_zero_extend(sel, 16));
  and_vec(v, m)
}

// --- Original (branching) ---

val orig_vpexpandw_256 : (bits(256), bits(16)) -> bits(256)
function orig_vpexpandw_256(src, mask) = {
  var result : bits(256) = zeros();
  foreach (i from 0 to 15) {
    if mask[i] == bitone then {
      let j = popcount_below16(mask, i);
      assert(j >= 0);
      let src_elem : bits(16) = extract_word_256(src, j);
      result[(i * 16 + 15)..(i * 16)] = src_elem;
    };
  };
  result
}

// --- Branchless ---

val branchless_vpexpandw_256 : (bits(256), bits(16)) -> bits(256)
function branchless_vpexpandw_256(src, mask) = {
  var result : bits(256) = zeros();
  foreach (i from 0 to 15) {
    let j = popcount_below16(mask, i);
    assert(j >= 0);
    let src_elem : bits(16) = extract_word_256(src, j);
    result[(i * 16 + 15)..(i * 16)] = mask_word(src_elem, mask[i..i]);
  };
  result
}

// --- Full-width proof ---

$property
function prop_vpexpandw_256(src : bits(256), mask : bits(16)) -> bool = {
  let orig = orig_vpexpandw_256(src, mask);
  let branchless = branchless_vpexpandw_256(src, mask);
  orig == branchless
}

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

val mask_byte : (bits(8), bits(1)) -> bits(8)
function mask_byte(v, sel) = {
  let m : bits(8) = sub_bits(sail_zeros(8), sail_zero_extend(sel, 8));
  and_vec(v, m)
}

// --- Original (branching) ---

val orig_vpcompressb_128 : (bits(128), bits(16)) -> bits(128)
function orig_vpcompressb_128(src, mask) = {
  var result : bits(128) = zeros();
  foreach (i from 0 to 15) {
    if mask[i] == bitone then {
      let j = popcount_below16(mask, i);
      assert(j >= 0);
      let src_elem : bits(8) = truncate(src >> (i * 8), 8);
      result = result | (zero_extend(src_elem) << (j * 8));
    };
  };
  result
}

// --- Branchless ---

val branchless_vpcompressb_128 : (bits(128), bits(16)) -> bits(128)
function branchless_vpcompressb_128(src, mask) = {
  var result : bits(128) = zeros();
  foreach (i from 0 to 15) {
    let j = popcount_below16(mask, i);
    assert(j >= 0);
    let src_elem : bits(8) = truncate(src >> (i * 8), 8);
    result = result | (zero_extend(mask_byte(src_elem, mask[i..i])) << (j * 8));
  };
  result
}

// --- Full-width proof ---

$property
function prop_vpcompressb_128(src : bits(128), mask : bits(16)) -> bool = {
  let orig = orig_vpcompressb_128(src, mask);
  let branchless = branchless_vpcompressb_128(src, mask);
  orig == branchless
}

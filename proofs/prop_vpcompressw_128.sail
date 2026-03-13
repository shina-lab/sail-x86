$include "../model/prelude.sail"

// --- Helpers ---

val popcount8 : bits(8) -> range(0, 8)
function popcount8(v) =
  unsigned(v[0..0]) + unsigned(v[1..1]) + unsigned(v[2..2]) + unsigned(v[3..3]) +
  unsigned(v[4..4]) + unsigned(v[5..5]) + unsigned(v[6..6]) + unsigned(v[7..7])

val below_mask8 : int -> bits(8)
function below_mask8(i) = match i {
  0 => 0x00,
  1 => 0x01,
  2 => 0x03,
  3 => 0x07,
  4 => 0x0F,
  5 => 0x1F,
  6 => 0x3F,
  _ => 0x7F,
}

val popcount_below : (bits(8), int) -> int
function popcount_below(mask, upto) = {
  assert(upto >= 0);
  popcount8(and_vec(mask, below_mask8(upto)))
}

val mask_word : (bits(16), bits(1)) -> bits(16)
function mask_word(v, sel) = {
  let m : bits(16) = sub_bits(sail_zeros(16), sail_zero_extend(sel, 16));
  and_vec(v, m)
}

// --- Original (branching) ---

val orig_vpcompressw_128 : (bits(128), bits(8)) -> bits(128)
function orig_vpcompressw_128(src, mask) = {
  var result : bits(128) = zeros();
  foreach (i from 0 to 7) {
    if mask[i] == bitone then {
      let j = popcount_below(mask, i);
      assert(j >= 0);
      let src_elem : bits(16) = truncate(src >> (i * 16), 16);
      result = result | (zero_extend(src_elem) << (j * 16));
    };
  };
  result
}

// --- Branchless ---

val branchless_vpcompressw_128 : (bits(128), bits(8)) -> bits(128)
function branchless_vpcompressw_128(src, mask) = {
  var result : bits(128) = zeros();
  foreach (i from 0 to 7) {
    let j = popcount_below(mask, i);
    assert(j >= 0);
    let src_elem : bits(16) = truncate(src >> (i * 16), 16);
    result = result | (zero_extend(mask_word(src_elem, mask[i..i])) << (j * 16));
  };
  result
}

// --- Full-width proof ---

$property
function prop_vpcompressw_128(src : bits(128), mask : bits(8)) -> bool = {
  let orig = orig_vpcompressw_128(src, mask);
  let branchless = branchless_vpcompressw_128(src, mask);
  orig == branchless
}

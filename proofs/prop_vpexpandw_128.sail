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

val extract_word_128 : (bits(128), int) -> bits(16)
function extract_word_128(src, j) = match j {
  0 => src[15..0],
  1 => src[31..16],
  2 => src[47..32],
  3 => src[63..48],
  4 => src[79..64],
  5 => src[95..80],
  6 => src[111..96],
  _ => src[127..112],
}

val mask_word : (bits(16), bits(1)) -> bits(16)
function mask_word(v, sel) = {
  let m : bits(16) = sub_bits(sail_zeros(16), sail_zero_extend(sel, 16));
  and_vec(v, m)
}

// --- Original (branching) ---

val orig_vpexpandw_128 : (bits(128), bits(8)) -> bits(128)
function orig_vpexpandw_128(src, mask) = {
  var result : bits(128) = zeros();
  foreach (i from 0 to 7) {
    if mask[i] == bitone then {
      let j = popcount_below(mask, i);
      assert(j >= 0);
      let src_elem : bits(16) = extract_word_128(src, j);
      result[(i * 16 + 15)..(i * 16)] = src_elem;
    };
  };
  result
}

// --- Branchless ---

val branchless_vpexpandw_128 : (bits(128), bits(8)) -> bits(128)
function branchless_vpexpandw_128(src, mask) = {
  var result : bits(128) = zeros();
  foreach (i from 0 to 7) {
    let j = popcount_below(mask, i);
    assert(j >= 0);
    let src_elem : bits(16) = extract_word_128(src, j);
    result[(i * 16 + 15)..(i * 16)] = mask_word(src_elem, mask[i..i]);
  };
  result
}

// --- Full-width proof ---

$property
function prop_vpexpandw_128(src : bits(128), mask : bits(8)) -> bool = {
  let orig = orig_vpexpandw_128(src, mask);
  let branchless = branchless_vpexpandw_128(src, mask);
  orig == branchless
}

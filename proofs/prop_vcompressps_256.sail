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

val mask_dword : (bits(32), bits(1)) -> bits(32)
function mask_dword(v, sel) = {
  let m : bits(32) = sub_bits(sail_zeros(32), sail_zero_extend(sel, 32));
  and_vec(v, m)
}

// --- Original (branching) ---

val orig_vcompressps_256 : (bits(256), bits(8)) -> bits(256)
function orig_vcompressps_256(src, mask) = {
  var result : bits(256) = zeros();
  foreach (i from 0 to 7) {
    if mask[i] == bitone then {
      let j = popcount_below(mask, i);
      assert(j >= 0);
      let src_lo : range(0, 224) = i * 32;
      let src_elem : bits(32) = src[(src_lo + 31)..src_lo];
      result = result | (zero_extend(src_elem) << (j * 32));
    };
  };
  result
}

// --- Branchless ---

val branchless_vcompressps_256 : (bits(256), bits(8)) -> bits(256)
function branchless_vcompressps_256(src, mask) = {
  var result : bits(256) = zeros();
  foreach (i from 0 to 7) {
    let j = popcount_below(mask, i);
    assert(j >= 0);
    let src_lo : range(0, 224) = i * 32;
    let src_elem : bits(32) = src[(src_lo + 31)..src_lo];
    result = result | (zero_extend(mask_dword(src_elem, mask[i..i])) << (j * 32));
  };
  result
}

// --- Full-width proof ---

$property
function prop_vcompressps_256(src : bits(256), mask : bits(8)) -> bool = {
  let orig = orig_vcompressps_256(src, mask);
  let branchless = branchless_vcompressps_256(src, mask);
  orig == branchless
}

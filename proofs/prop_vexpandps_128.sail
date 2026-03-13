$include "../model/prelude.sail"

// --- Helpers ---

val popcount8 : bits(8) -> range(0, 8)
function popcount8(v) =
  unsigned(v[0..0]) + unsigned(v[1..1]) + unsigned(v[2..2]) + unsigned(v[3..3]) +
  unsigned(v[4..4]) + unsigned(v[5..5]) + unsigned(v[6..6]) + unsigned(v[7..7])

// Mask of bits strictly below position i (avoids shiftl for SMT)
val below_mask4 : int -> bits(8)
function below_mask4(i) = match i {
  0 => 0x00,
  1 => 0x01,
  2 => 0x03,
  _ => 0x07,
}

val popcount_below : (bits(8), int) -> int
function popcount_below(mask, upto) = {
  assert(upto >= 0);
  popcount8(and_vec(mask, below_mask4(upto)))
}

// Extract j-th dword from a 128-bit vector (avoids get_slice_int for SMT)
val extract_dword : (bits(128), int) -> bits(32)
function extract_dword(src, j) = match j {
  0 => src[31..0],
  1 => src[63..32],
  2 => src[95..64],
  _ => src[127..96],
}

val mask_dword : (bits(32), bits(1)) -> bits(32)
function mask_dword(v, sel) = {
  let m : bits(32) = sub_bits(sail_zeros(32), sail_zero_extend(sel, 32));
  and_vec(v, m)
}

// --- Original (branching) ---

val orig_vexpandps_128 : (bits(128), bits(8)) -> bits(128)
function orig_vexpandps_128(src, mask) = {
  var result : bits(128) = zeros();
  foreach (i from 0 to 3) {
    if mask[i] == bitone then {
      let j = popcount_below(mask, i);
      assert(j >= 0);
      let dst_lo : range(0, 96) = i * 32;
      let src_elem : bits(32) = extract_dword(src, j);
      result[(dst_lo + 31)..dst_lo] = src_elem;
    };
  };
  result
}

// --- Branchless ---

val branchless_vexpandps_128 : (bits(128), bits(8)) -> bits(128)
function branchless_vexpandps_128(src, mask) = {
  var result : bits(128) = zeros();
  foreach (i from 0 to 3) {
    let j = popcount_below(mask, i);
    assert(j >= 0);
    let dst_lo : range(0, 96) = i * 32;
    let src_elem : bits(32) = extract_dword(src, j);
    result[(dst_lo + 31)..dst_lo] = mask_dword(src_elem, mask[i..i]);
  };
  result
}

// --- Full-width proof ---

$property
function prop_vexpandps_128(src : bits(128), mask : bits(8)) -> bool = {
  let orig = orig_vexpandps_128(src, mask);
  let branchless = branchless_vexpandps_128(src, mask);
  orig == branchless
}

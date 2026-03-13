$include "../model/prelude.sail"

// --- Helpers ---

val popcount8 : bits(8) -> range(0, 8)
function popcount8(v) =
  unsigned(v[0..0]) + unsigned(v[1..1]) + unsigned(v[2..2]) + unsigned(v[3..3]) +
  unsigned(v[4..4]) + unsigned(v[5..5]) + unsigned(v[6..6]) + unsigned(v[7..7])

val below_mask2 : int -> bits(8)
function below_mask2(i) = match i {
  0 => 0x00,
  _ => 0x01,
}

val popcount_below : (bits(8), int) -> int
function popcount_below(mask, upto) = {
  assert(upto >= 0);
  popcount8(and_vec(mask, below_mask2(upto)))
}

val extract_qword_128 : (bits(128), int) -> bits(64)
function extract_qword_128(src, j) = match j {
  0 => src[63..0],
  _ => src[127..64],
}

val mask_qword : (bits(64), bits(1)) -> bits(64)
function mask_qword(v, sel) = {
  let m : bits(64) = sub_bits(sail_zeros(64), sail_zero_extend(sel, 64));
  and_vec(v, m)
}

// --- Original (branching) ---

val orig_vexpandpd_128 : (bits(128), bits(8)) -> bits(128)
function orig_vexpandpd_128(src, mask) = {
  var result : bits(128) = zeros();
  foreach (i from 0 to 1) {
    if mask[i] == bitone then {
      let j = popcount_below(mask, i);
      assert(j >= 0);
      let dst_lo : range(0, 64) = i * 64;
      let src_elem : bits(64) = extract_qword_128(src, j);
      result[(dst_lo + 63)..dst_lo] = src_elem;
    };
  };
  result
}

// --- Branchless ---

val branchless_vexpandpd_128 : (bits(128), bits(8)) -> bits(128)
function branchless_vexpandpd_128(src, mask) = {
  var result : bits(128) = zeros();
  foreach (i from 0 to 1) {
    let j = popcount_below(mask, i);
    assert(j >= 0);
    let dst_lo : range(0, 64) = i * 64;
    let src_elem : bits(64) = extract_qword_128(src, j);
    result[(dst_lo + 63)..dst_lo] = mask_qword(src_elem, mask[i..i]);
  };
  result
}

// --- Full-width proof ---

$property
function prop_vexpandpd_128(src : bits(128), mask : bits(8)) -> bool = {
  let orig = orig_vexpandpd_128(src, mask);
  let branchless = branchless_vexpandpd_128(src, mask);
  orig == branchless
}

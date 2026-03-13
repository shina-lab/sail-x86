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

val mask_qword : (bits(64), bits(1)) -> bits(64)
function mask_qword(v, sel) = {
  let m : bits(64) = sub_bits(sail_zeros(64), sail_zero_extend(sel, 64));
  and_vec(v, m)
}

// --- Original (branching) ---

val orig_vcompresspd_128 : (bits(128), bits(8)) -> bits(128)
function orig_vcompresspd_128(src, mask) = {
  var result : bits(128) = zeros();
  foreach (i from 0 to 1) {
    if mask[i] == bitone then {
      let j = popcount_below(mask, i);
      assert(j >= 0);
      let src_lo : range(0, 64) = i * 64;
      let src_elem : bits(64) = src[(src_lo + 63)..src_lo];
      result = result | (zero_extend(src_elem) << (j * 64));
    };
  };
  result
}

// --- Branchless ---

val branchless_vcompresspd_128 : (bits(128), bits(8)) -> bits(128)
function branchless_vcompresspd_128(src, mask) = {
  var result : bits(128) = zeros();
  foreach (i from 0 to 1) {
    let j = popcount_below(mask, i);
    assert(j >= 0);
    let src_lo : range(0, 64) = i * 64;
    let src_elem : bits(64) = src[(src_lo + 63)..src_lo];
    result = result | (zero_extend(mask_qword(src_elem, mask[i..i])) << (j * 64));
  };
  result
}

// --- Full-width proof ---

$property
function prop_vcompresspd_128(src : bits(128), mask : bits(8)) -> bool = {
  let orig = orig_vcompresspd_128(src, mask);
  let branchless = branchless_vcompresspd_128(src, mask);
  orig == branchless
}

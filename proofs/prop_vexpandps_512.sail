$include "../model/prelude.sail"

// --- Helpers ---

val popcount8 : bits(8) -> range(0, 8)
function popcount8(v) =
  unsigned(v[0..0]) + unsigned(v[1..1]) + unsigned(v[2..2]) + unsigned(v[3..3]) +
  unsigned(v[4..4]) + unsigned(v[5..5]) + unsigned(v[6..6]) + unsigned(v[7..7])

val popcount16 : bits(16) -> range(0, 16)
function popcount16(v) =
  popcount8(v[7..0]) + popcount8(v[15..8])

val below_mask16 : int -> bits(16)
function below_mask16(i) = match i {
  0  => 0x0000,
  1  => 0x0001,
  2  => 0x0003,
  3  => 0x0007,
  4  => 0x000F,
  5  => 0x001F,
  6  => 0x003F,
  7  => 0x007F,
  8  => 0x00FF,
  9  => 0x01FF,
  10 => 0x03FF,
  11 => 0x07FF,
  12 => 0x0FFF,
  13 => 0x1FFF,
  14 => 0x3FFF,
  _  => 0x7FFF,
}

val popcount_below16 : (bits(16), int) -> int
function popcount_below16(mask, upto) = {
  assert(upto >= 0);
  popcount16(and_vec(mask, below_mask16(upto)))
}

val extract_dword_512 : (bits(512), int) -> bits(32)
function extract_dword_512(src, j) = match j {
  0  => src[31..0],
  1  => src[63..32],
  2  => src[95..64],
  3  => src[127..96],
  4  => src[159..128],
  5  => src[191..160],
  6  => src[223..192],
  7  => src[255..224],
  8  => src[287..256],
  9  => src[319..288],
  10 => src[351..320],
  11 => src[383..352],
  12 => src[415..384],
  13 => src[447..416],
  14 => src[479..448],
  _  => src[511..480],
}

val mask_dword : (bits(32), bits(1)) -> bits(32)
function mask_dword(v, sel) = {
  let m : bits(32) = sub_bits(sail_zeros(32), sail_zero_extend(sel, 32));
  and_vec(v, m)
}

// --- Original (branching) ---

val orig_vexpandps_512 : (bits(512), bits(16)) -> bits(512)
function orig_vexpandps_512(src, mask) = {
  var result : bits(512) = zeros();
  foreach (i from 0 to 15) {
    if mask[i] == bitone then {
      let j = popcount_below16(mask, i);
      assert(j >= 0);
      let dst_lo : range(0, 480) = i * 32;
      let src_elem : bits(32) = extract_dword_512(src, j);
      result[(dst_lo + 31)..dst_lo] = src_elem;
    };
  };
  result
}

// --- Branchless ---

val branchless_vexpandps_512 : (bits(512), bits(16)) -> bits(512)
function branchless_vexpandps_512(src, mask) = {
  var result : bits(512) = zeros();
  foreach (i from 0 to 15) {
    let j = popcount_below16(mask, i);
    assert(j >= 0);
    let dst_lo : range(0, 480) = i * 32;
    let src_elem : bits(32) = extract_dword_512(src, j);
    result[(dst_lo + 31)..dst_lo] = mask_dword(src_elem, mask[i..i]);
  };
  result
}

// --- Full-width proof ---

$property
function prop_vexpandps_512(src : bits(512), mask : bits(16)) -> bool = {
  let orig = orig_vexpandps_512(src, mask);
  let branchless = branchless_vexpandps_512(src, mask);
  orig == branchless
}

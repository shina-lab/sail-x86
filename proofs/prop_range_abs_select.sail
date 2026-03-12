$include "../model/prelude.sail"

// Prove that abs_min/abs_max magnitude comparisons can be done branchless.
// Pattern: compare unsigned magnitudes, select full value.
// abs_min: if unsigned(a[30..0]) <= unsigned(b[30..0]) then a else b
// abs_max: if unsigned(a[30..0]) >= unsigned(b[30..0]) then a else b

// f32 abs_min: select a if |a| <= |b|
$property
function prop_abs_min_f32(src1 : bits(32), src2 : bits(32)) -> bool = {
  let orig : bits(32) =
    if unsigned(src1[30..0]) <= unsigned(src2[30..0]) then src1 else src2;
  let diff : bits(32) = (0b0 @ src2[30..0]) - (0b0 @ src1[30..0]);
  let nb : bits(1) = 0b1 ^ diff[31..31];
  let mask : bits(32) = zeros() - zero_extend(nb);
  let branchless : bits(32) = (src1 & mask) | (src2 & not_vec(mask));
  orig == branchless
}

// f32 abs_max: select a if |a| >= |b|
$property
function prop_abs_max_f32(src1 : bits(32), src2 : bits(32)) -> bool = {
  let orig : bits(32) =
    if unsigned(src1[30..0]) >= unsigned(src2[30..0]) then src1 else src2;
  let diff : bits(32) = (0b0 @ src1[30..0]) - (0b0 @ src2[30..0]);
  let nb : bits(1) = 0b1 ^ diff[31..31];
  let mask : bits(32) = zeros() - zero_extend(nb);
  let branchless : bits(32) = (src1 & mask) | (src2 & not_vec(mask));
  orig == branchless
}

// f64 abs_min: select a if |a| <= |b|
$property
function prop_abs_min_f64(src1 : bits(64), src2 : bits(64)) -> bool = {
  let orig : bits(64) =
    if unsigned(src1[62..0]) <= unsigned(src2[62..0]) then src1 else src2;
  let diff : bits(64) = (0b0 @ src2[62..0]) - (0b0 @ src1[62..0]);
  let nb : bits(1) = 0b1 ^ diff[63..63];
  let mask : bits(64) = zeros() - zero_extend(nb);
  let branchless : bits(64) = (src1 & mask) | (src2 & not_vec(mask));
  orig == branchless
}

// f64 abs_max: select a if |a| >= |b|
$property
function prop_abs_max_f64(src1 : bits(64), src2 : bits(64)) -> bool = {
  let orig : bits(64) =
    if unsigned(src1[62..0]) >= unsigned(src2[62..0]) then src1 else src2;
  let diff : bits(64) = (0b0 @ src1[62..0]) - (0b0 @ src2[62..0]);
  let nb : bits(1) = 0b1 ^ diff[63..63];
  let mask : bits(64) = zeros() - zero_extend(nb);
  let branchless : bits(64) = (src1 & mask) | (src2 & not_vec(mask));
  orig == branchless
}

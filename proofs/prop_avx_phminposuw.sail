$include "../model/prelude.sail"

// Prove branchless VEX PHMINPOSUW: same as SSE version but uses a loop.
// We prove the unrolled branchless version matches the original branching loop.

$property
function prop_avx_phminposuw(src : bits(128)) -> bool = {
  // Original (branching loop, unrolled for proof)
  var ov : bits(16) = src[15..0];
  var oi : int = 0;
  // i=1
  let v1 : bits(16) = src[31..16];
  if unsigned(v1) < unsigned(ov) then { ov = v1; oi = 1 };
  let v2 : bits(16) = src[47..32];
  if unsigned(v2) < unsigned(ov) then { ov = v2; oi = 2 };
  let v3 : bits(16) = src[63..48];
  if unsigned(v3) < unsigned(ov) then { ov = v3; oi = 3 };
  let v4 : bits(16) = src[79..64];
  if unsigned(v4) < unsigned(ov) then { ov = v4; oi = 4 };
  let v5 : bits(16) = src[95..80];
  if unsigned(v5) < unsigned(ov) then { ov = v5; oi = 5 };
  let v6 : bits(16) = src[111..96];
  if unsigned(v6) < unsigned(ov) then { ov = v6; oi = 6 };
  let v7 : bits(16) = src[127..112];
  if unsigned(v7) < unsigned(ov) then { ov = v7; oi = 7 };
  let orig_idx : bits(3) = get_slice_int(3, oi, 0);
  let orig : bits(128) = zeros(109) @ orig_idx @ ov;

  // Branchless
  var mv : bits(16) = src[15..0];
  var mi : bits(3) = 0b000;

  let d1 : bits(17) = (0b0 @ v1) - (0b0 @ mv);
  let u1 : bits(16) = zeros() - zero_extend(d1[16..16]);
  mv = (v1 & u1) | (mv & not_vec(u1));
  mi = (0b001 & u1[2..0]) | (mi & not_vec(u1[2..0]));

  let d2 : bits(17) = (0b0 @ v2) - (0b0 @ mv);
  let u2 : bits(16) = zeros() - zero_extend(d2[16..16]);
  mv = (v2 & u2) | (mv & not_vec(u2));
  mi = (0b010 & u2[2..0]) | (mi & not_vec(u2[2..0]));

  let d3 : bits(17) = (0b0 @ v3) - (0b0 @ mv);
  let u3 : bits(16) = zeros() - zero_extend(d3[16..16]);
  mv = (v3 & u3) | (mv & not_vec(u3));
  mi = (0b011 & u3[2..0]) | (mi & not_vec(u3[2..0]));

  let d4 : bits(17) = (0b0 @ v4) - (0b0 @ mv);
  let u4 : bits(16) = zeros() - zero_extend(d4[16..16]);
  mv = (v4 & u4) | (mv & not_vec(u4));
  mi = (0b100 & u4[2..0]) | (mi & not_vec(u4[2..0]));

  let d5 : bits(17) = (0b0 @ v5) - (0b0 @ mv);
  let u5 : bits(16) = zeros() - zero_extend(d5[16..16]);
  mv = (v5 & u5) | (mv & not_vec(u5));
  mi = (0b101 & u5[2..0]) | (mi & not_vec(u5[2..0]));

  let d6 : bits(17) = (0b0 @ v6) - (0b0 @ mv);
  let u6 : bits(16) = zeros() - zero_extend(d6[16..16]);
  mv = (v6 & u6) | (mv & not_vec(u6));
  mi = (0b110 & u6[2..0]) | (mi & not_vec(u6[2..0]));

  let d7 : bits(17) = (0b0 @ v7) - (0b0 @ mv);
  let u7 : bits(16) = zeros() - zero_extend(d7[16..16]);
  mv = (v7 & u7) | (mv & not_vec(u7));
  mi = (0b111 & u7[2..0]) | (mi & not_vec(u7[2..0]));

  let branchless : bits(128) = zeros(109) @ mi @ mv;
  orig == branchless
}

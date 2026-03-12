$include "../model/prelude.sail"

// Prove branchless PHMINPOSUW: find minimum unsigned word and its index.
// Each step: if wi < current_min (strict), update (val, idx).
// Branchless: use borrow bit from subtraction as selection mask.

$property
function prop_phminposuw(s : bits(128)) -> bool = {
  let w0 : bits(16) = s[15..0];
  let w1 : bits(16) = s[31..16];
  let w2 : bits(16) = s[47..32];
  let w3 : bits(16) = s[63..48];
  let w4 : bits(16) = s[79..64];
  let w5 : bits(16) = s[95..80];
  let w6 : bits(16) = s[111..96];
  let w7 : bits(16) = s[127..112];

  // Original (branching)
  let ov : bits(16) = w0;
  let oi : bits(16) = 0x0000;
  let (ov, oi) = if unsigned(w1) < unsigned(ov) then (w1, 0x0001) else (ov, oi);
  let (ov, oi) = if unsigned(w2) < unsigned(ov) then (w2, 0x0002) else (ov, oi);
  let (ov, oi) = if unsigned(w3) < unsigned(ov) then (w3, 0x0003) else (ov, oi);
  let (ov, oi) = if unsigned(w4) < unsigned(ov) then (w4, 0x0004) else (ov, oi);
  let (ov, oi) = if unsigned(w5) < unsigned(ov) then (w5, 0x0005) else (ov, oi);
  let (ov, oi) = if unsigned(w6) < unsigned(ov) then (w6, 0x0006) else (ov, oi);
  let (ov, oi) = if unsigned(w7) < unsigned(ov) then (w7, 0x0007) else (ov, oi);
  let orig : bits(128) = zeros(96) @ oi @ ov;

  // Branchless: borrow bit selects update
  var mv : bits(16) = w0;
  var mi : bits(16) = 0x0000;

  let d1 : bits(17) = (0b0 @ w1) - (0b0 @ mv);
  let u1 : bits(16) = zeros() - zero_extend(d1[16..16]);
  mv = (w1 & u1) | (mv & not_vec(u1));
  mi = (0x0001 & u1) | (mi & not_vec(u1));

  let d2 : bits(17) = (0b0 @ w2) - (0b0 @ mv);
  let u2 : bits(16) = zeros() - zero_extend(d2[16..16]);
  mv = (w2 & u2) | (mv & not_vec(u2));
  mi = (0x0002 & u2) | (mi & not_vec(u2));

  let d3 : bits(17) = (0b0 @ w3) - (0b0 @ mv);
  let u3 : bits(16) = zeros() - zero_extend(d3[16..16]);
  mv = (w3 & u3) | (mv & not_vec(u3));
  mi = (0x0003 & u3) | (mi & not_vec(u3));

  let d4 : bits(17) = (0b0 @ w4) - (0b0 @ mv);
  let u4 : bits(16) = zeros() - zero_extend(d4[16..16]);
  mv = (w4 & u4) | (mv & not_vec(u4));
  mi = (0x0004 & u4) | (mi & not_vec(u4));

  let d5 : bits(17) = (0b0 @ w5) - (0b0 @ mv);
  let u5 : bits(16) = zeros() - zero_extend(d5[16..16]);
  mv = (w5 & u5) | (mv & not_vec(u5));
  mi = (0x0005 & u5) | (mi & not_vec(u5));

  let d6 : bits(17) = (0b0 @ w6) - (0b0 @ mv);
  let u6 : bits(16) = zeros() - zero_extend(d6[16..16]);
  mv = (w6 & u6) | (mv & not_vec(u6));
  mi = (0x0006 & u6) | (mi & not_vec(u6));

  let d7 : bits(17) = (0b0 @ w7) - (0b0 @ mv);
  let u7 : bits(16) = zeros() - zero_extend(d7[16..16]);
  mv = (w7 & u7) | (mv & not_vec(u7));
  mi = (0x0007 & u7) | (mi & not_vec(u7));

  let branchless : bits(128) = zeros(96) @ mi @ mv;
  orig == branchless
}

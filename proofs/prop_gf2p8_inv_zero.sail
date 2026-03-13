$include "../model/prelude.sail"

// GF(2^8) multiply: polynomial multiply modulo x^8 + x^4 + x^3 + x + 1
val gf2p8_mul : (bits(8), bits(8)) -> bits(8)
function gf2p8_mul(a, b) = {
  var result : bits(9) = zeros();
  var aa : bits(9) = zero_extend(a);
  foreach (i from 0 to 7) {
    if b[i] == bitone then result = result ^ aa;
    aa = aa << 1;
    if aa[8] == bitone then aa = aa ^ 0b100011011 // 0x11B
  };
  result[7..0]
}

// Prove that gf2p8_inv's zero check is redundant:
// x^254 already produces 0 for x=0.
$property
function prop_gf2p8_inv_zero_redundant(x : bits(8)) -> bool = {
  // Original (with zero check)
  let orig : bits(8) =
    if x == 0x00 then 0x00
    else {
      let x2 = gf2p8_mul(x, x);
      let x3 = gf2p8_mul(x2, x);
      let x6 = gf2p8_mul(x3, x3);
      let x12 = gf2p8_mul(x6, x6);
      let x15 = gf2p8_mul(x12, x3);
      let x30 = gf2p8_mul(x15, x15);
      let x60 = gf2p8_mul(x30, x30);
      let x63 = gf2p8_mul(x60, x3);
      let x126 = gf2p8_mul(x63, x63);
      let x252 = gf2p8_mul(x126, x126);
      gf2p8_mul(x252, x2)
    };
  // Branchless (no zero check)
  let x2 = gf2p8_mul(x, x);
  let x3 = gf2p8_mul(x2, x);
  let x6 = gf2p8_mul(x3, x3);
  let x12 = gf2p8_mul(x6, x6);
  let x15 = gf2p8_mul(x12, x3);
  let x30 = gf2p8_mul(x15, x15);
  let x60 = gf2p8_mul(x30, x30);
  let x63 = gf2p8_mul(x60, x3);
  let x126 = gf2p8_mul(x63, x63);
  let x252 = gf2p8_mul(x126, x126);
  let branchless : bits(8) = gf2p8_mul(x252, x2);
  orig == branchless
}

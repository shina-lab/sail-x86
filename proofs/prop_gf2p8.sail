$include "../model/prelude.sail"

type byte = bits(8)
type qword = bits(64)

val pc8 : byte -> range(0, 8)
function pc8(v) =
  unsigned(v[0..0]) + unsigned(v[1..1]) + unsigned(v[2..2]) + unsigned(v[3..3]) +
  unsigned(v[4..4]) + unsigned(v[5..5]) + unsigned(v[6..6]) + unsigned(v[7..7])

// --- GF2P8 affine XOR-reduce ---
// Reference: toggle bit for each set bit in product (parity computation)
val xor_reduce_ref : byte -> bit
function xor_reduce_ref(product) = {
  var bit : bit = bitzero;
  foreach (j from 0 to 7) {
    if product[j] == bitone then bit = bool_to_bit(bit == bitzero)
  };
  bit
}

// Branchless: popcount mod 2
val xor_reduce_new : byte -> bit
function xor_reduce_new(product) = bool_to_bit(pc8(product) % 2 == 1)

$property
function prop_xor_reduce(product : byte) -> bool =
  xor_reduce_ref(product) == xor_reduce_new(product)

// --- GF2P8 affine full function ---
val gf2p8_affine_ref : (byte, qword, byte) -> byte
function gf2p8_affine_ref(src, matrix, imm8) = {
  var r : byte = zeros();
  foreach (i from 0 to 7) {
    let row_lo : range(0, 56) = (7 - i) * 8;
    let row : byte = matrix[(row_lo + 7)..row_lo];
    let product : byte = src & row;
    var bit : bit = bitzero;
    foreach (j from 0 to 7) { if product[j] == bitone then bit = bool_to_bit(bit == bitzero) };
    r[i] = bool_to_bit(bit != imm8[i]);
  };
  r
}

val gf2p8_affine_new : (byte, qword, byte) -> byte
function gf2p8_affine_new(src, matrix, imm8) = {
  var r : byte = zeros();
  foreach (i from 0 to 7) {
    let row_lo : range(0, 56) = (7 - i) * 8;
    let row : byte = matrix[(row_lo + 7)..row_lo];
    let product : byte = src & row;
    let bit : bit = bool_to_bit(pc8(product) % 2 == 1);
    r[i] = bool_to_bit(bit != imm8[i]);
  };
  r
}

$property
function prop_gf2p8_affine(src : byte, matrix : qword, imm8 : byte) -> bool =
  gf2p8_affine_ref(src, matrix, imm8) == gf2p8_affine_new(src, matrix, imm8)

// --- GF2P8 multiply ---
val gf2p8_mul_ref : (byte, byte) -> byte
function gf2p8_mul_ref(a, b) = {
  var result : bits(9) = zeros();
  var aa : bits(9) = sail_zero_extend(a, 9);
  foreach (i from 0 to 7) {
    if b[i] == bitone then result = result ^ aa;
    aa = aa << 1;
    if aa[8] == bitone then aa = aa ^ 0b100011011
  };
  result[7..0]
}

val gf2p8_mul_new : (byte, byte) -> byte
function gf2p8_mul_new(a, b) = {
  var result : bits(9) = zeros();
  var aa : bits(9) = sail_zero_extend(a, 9);
  foreach (i from 0 to 7) {
    let bmask : bits(9) = 0b000000000 - (0b00000000 @ [b[i]]);
    result = result ^ (bmask & aa);
    aa = aa << 1;
    let amask : bits(9) = 0b000000000 - (0b00000000 @ [aa[8]]);
    aa = aa ^ (amask & 0b100011011)
  };
  result[7..0]
}

$property
function prop_gf2p8_mul(a : byte, b : byte) -> bool =
  gf2p8_mul_ref(a, b) == gf2p8_mul_new(a, b)

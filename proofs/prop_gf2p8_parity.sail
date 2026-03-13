// Equivalence proofs for GF2P8 XOR-reduce (parity) and bit XOR

$include "../model/prelude.sail"

val popcount8 : bits(8) -> range(0, 8)
function popcount8(v) =
  unsigned(v[0..0]) + unsigned(v[1..1]) + unsigned(v[2..2]) + unsigned(v[3..3]) +
  unsigned(v[4..4]) + unsigned(v[5..5]) + unsigned(v[6..6]) + unsigned(v[7..7])

// XOR-reduce via tree: equivalent to popcount parity
$property
function prop_xor_reduce_parity(v : bits(8)) -> bool = {
  let orig : bit = bool_to_bit(popcount8(v) % 2 == 1);
  let x4 : bits(4) = v[7..4] ^ v[3..0];
  let x2 : bits(2) = x4[3..2] ^ x4[1..0];
  let branchless : bit = (x2[1..1] ^ x2[0..0])[0];
  orig == branchless
}

// bool_to_bit(a != b) for bits ≡ a ^ b
$property
function prop_bit_ne_xor(a : bit, b : bit) -> bool = {
  let orig : bit = bool_to_bit(a != b);
  orig == (a ^ b)
}

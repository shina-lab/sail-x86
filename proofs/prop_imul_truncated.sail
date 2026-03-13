// Equivalence proofs: IMUL truncation check
// Pattern: bool_to_bit(product != signed(result[N-1..0]))
// Replace with: or_reduce(upper_half XOR sign_extend(sign_bit))
// where upper_half = wide_product[2N-1..N], sign_bit = wide_product[N-1..N-1]

$include "../model/prelude.sail"

val or_reduce_8 : bits(8) -> bits(1)
function or_reduce_8(v) = {
  let r4 : bits(4) = v[7..4] | v[3..0];
  let r2 : bits(2) = r4[3..2] | r4[1..0];
  r2[1..1] | r2[0..0]
}

val or_reduce_16 : bits(16) -> bits(1)
function or_reduce_16(v) = or_reduce_8(v[15..8] | v[7..0])

val or_reduce_32 : bits(32) -> bits(1)
function or_reduce_32(v) = or_reduce_16(v[31..16] | v[15..0])

val or_reduce_64 : bits(64) -> bits(1)
function or_reduce_64(v) = or_reduce_32(v[63..32] | v[31..0])

// 8-bit IMUL: signed 8x8 -> 16, check if result fits in 8 signed bits
$property
function prop_imul_trunc_8(a : bits(8), b : bits(8)) -> bool = {
  let product : int = signed(a) * signed(b);
  let result : bits(8) = to_bits_truncate(8, product);
  let orig : bit = bool_to_bit(product != signed(result));
  // Double-width product
  let wide : bits(16) = to_bits_truncate(16, product);
  // Upper half XOR sign extension of bit 7
  let diff : bits(8) = wide[15..8] ^ sign_extend(wide[7..7]);
  let branchless : bit = (or_reduce_8(diff))[0];
  orig == branchless
}

// 16-bit IMUL: signed 16x16 -> 32, check if result fits in 16 signed bits
$property
function prop_imul_trunc_16(a : bits(16), b : bits(16)) -> bool = {
  let product : int = signed(a) * signed(b);
  let result : bits(16) = to_bits_truncate(16, product);
  let orig : bit = bool_to_bit(product != signed(result));
  let wide : bits(32) = to_bits_truncate(32, product);
  let diff : bits(16) = wide[31..16] ^ sign_extend(wide[15..15]);
  let branchless : bit = (or_reduce_16(diff))[0];
  orig == branchless
}

// 32-bit IMUL: signed 32x32 -> 64, check if result fits in 32 signed bits
$property
function prop_imul_trunc_32(a : bits(32), b : bits(32)) -> bool = {
  let product : int = signed(a) * signed(b);
  let result : bits(32) = to_bits_truncate(32, product);
  let orig : bit = bool_to_bit(product != signed(result));
  let wide : bits(64) = to_bits_truncate(64, product);
  let diff : bits(32) = wide[63..32] ^ sign_extend(wide[31..31]);
  let branchless : bit = (or_reduce_32(diff))[0];
  orig == branchless
}

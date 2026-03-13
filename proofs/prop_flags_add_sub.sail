// Equivalence proofs: branchless OF, CF, AF for add/sub
// Replace bool_to_bit on sign-bit comparisons with direct bit ops

$include "../model/prelude.sail"

// OF for addition: signed overflow when both operands have same sign
// but result has different sign
// Old: bool_to_bit((a[N-1] == b[N-1]) & (result[N-1] != a[N-1]))
// New: ~(a[N-1] ^ b[N-1]) & (result[N-1] ^ a[N-1])
//      "same sign inputs" AND "different sign result"

$property
function prop_of_add_8(a : bits(8), b : bits(8)) -> bool = {
  let result = a + b;
  let orig : bit = bool_to_bit((a[7] == b[7]) & (result[7] != a[7]));
  let branchless : bit = (~(a[7..7] ^ b[7..7]) & (result[7..7] ^ a[7..7]))[0];
  orig == branchless
}

$property
function prop_of_add_16(a : bits(16), b : bits(16)) -> bool = {
  let result = a + b;
  let orig : bit = bool_to_bit((a[15] == b[15]) & (result[15] != a[15]));
  let branchless : bit = (~(a[15..15] ^ b[15..15]) & (result[15..15] ^ a[15..15]))[0];
  orig == branchless
}

$property
function prop_of_add_32(a : bits(32), b : bits(32)) -> bool = {
  let result = a + b;
  let orig : bit = bool_to_bit((a[31] == b[31]) & (result[31] != a[31]));
  let branchless : bit = (~(a[31..31] ^ b[31..31]) & (result[31..31] ^ a[31..31]))[0];
  orig == branchless
}

$property
function prop_of_add_64(a : bits(64), b : bits(64)) -> bool = {
  let result = a + b;
  let orig : bit = bool_to_bit((a[63] == b[63]) & (result[63] != a[63]));
  let branchless : bit = (~(a[63..63] ^ b[63..63]) & (result[63..63] ^ a[63..63]))[0];
  orig == branchless
}

// OF for subtraction: signed overflow when operands have different signs
// and result sign differs from first operand
// Old: bool_to_bit((a[N-1] != b[N-1]) & (result[N-1] != a[N-1]))
// New: (a[N-1] ^ b[N-1]) & (result[N-1] ^ a[N-1])

$property
function prop_of_sub_8(a : bits(8), b : bits(8)) -> bool = {
  let result = a - b;
  let orig : bit = bool_to_bit((a[7] != b[7]) & (result[7] != a[7]));
  let branchless : bit = ((a[7..7] ^ b[7..7]) & (result[7..7] ^ a[7..7]))[0];
  orig == branchless
}

$property
function prop_of_sub_32(a : bits(32), b : bits(32)) -> bool = {
  let result = a - b;
  let orig : bit = bool_to_bit((a[31] != b[31]) & (result[31] != a[31]));
  let branchless : bit = ((a[31..31] ^ b[31..31]) & (result[31..31] ^ a[31..31]))[0];
  orig == branchless
}

// CF for addition: unsigned overflow
// Old: bool_to_bit(unsigned(result) != unsigned(a) + unsigned(b))
// New: carry bit from (0b0 @ a) + (0b0 @ b) — the high bit of the (N+1)-bit sum

$property
function prop_cf_add_8(a : bits(8), b : bits(8)) -> bool = {
  let result : bits(8) = a + b;
  let orig : bit = bool_to_bit(unsigned(result) != unsigned(a) + unsigned(b));
  let wide : bits(9) = (0b0 @ a) + (0b0 @ b);
  let branchless : bit = wide[8];
  orig == branchless
}

$property
function prop_cf_add_16(a : bits(16), b : bits(16)) -> bool = {
  let result : bits(16) = a + b;
  let orig : bit = bool_to_bit(unsigned(result) != unsigned(a) + unsigned(b));
  let wide : bits(17) = (0b0 @ a) + (0b0 @ b);
  let branchless : bit = wide[16];
  orig == branchless
}

$property
function prop_cf_add_32(a : bits(32), b : bits(32)) -> bool = {
  let result : bits(32) = a + b;
  let orig : bit = bool_to_bit(unsigned(result) != unsigned(a) + unsigned(b));
  let wide : bits(33) = (0b0 @ a) + (0b0 @ b);
  let branchless : bit = wide[32];
  orig == branchless
}

$property
function prop_cf_add_64(a : bits(64), b : bits(64)) -> bool = {
  let result : bits(64) = a + b;
  let orig : bit = bool_to_bit(unsigned(result) != unsigned(a) + unsigned(b));
  let wide : bits(65) = (0b0 @ a) + (0b0 @ b);
  let branchless : bit = wide[64];
  orig == branchless
}

// CF for subtraction: borrow (unsigned underflow)
// Old: bool_to_bit(unsigned(a) < unsigned(b))
// New: borrow bit from (0b0 @ a) - (0b0 @ b) — the high bit

$property
function prop_cf_sub_8(a : bits(8), b : bits(8)) -> bool = {
  let orig : bit = bool_to_bit(unsigned(a) < unsigned(b));
  let wide : bits(9) = (0b0 @ a) - (0b0 @ b);
  let branchless : bit = wide[8];
  orig == branchless
}

$property
function prop_cf_sub_16(a : bits(16), b : bits(16)) -> bool = {
  let orig : bit = bool_to_bit(unsigned(a) < unsigned(b));
  let wide : bits(17) = (0b0 @ a) - (0b0 @ b);
  let branchless : bit = wide[16];
  orig == branchless
}

$property
function prop_cf_sub_32(a : bits(32), b : bits(32)) -> bool = {
  let orig : bit = bool_to_bit(unsigned(a) < unsigned(b));
  let wide : bits(33) = (0b0 @ a) - (0b0 @ b);
  let branchless : bit = wide[32];
  orig == branchless
}

$property
function prop_cf_sub_64(a : bits(64), b : bits(64)) -> bool = {
  let orig : bit = bool_to_bit(unsigned(a) < unsigned(b));
  let wide : bits(65) = (0b0 @ a) - (0b0 @ b);
  let branchless : bit = wide[64];
  orig == branchless
}

// AF for addition: carry out of bit 3
// Old: bool_to_bit(unsigned(result[3..0]) != unsigned(a[3..0]) + unsigned(b[3..0]))
// New: high bit of (0b0 @ a[3..0]) + (0b0 @ b[3..0])

$property
function prop_af_add_8(a : bits(8), b : bits(8)) -> bool = {
  let result : bits(8) = a + b;
  let orig : bit = bool_to_bit(unsigned(result[3..0]) != unsigned(a[3..0]) + unsigned(b[3..0]));
  let wide : bits(5) = (0b0 @ a[3..0]) + (0b0 @ b[3..0]);
  let branchless : bit = wide[4];
  orig == branchless
}

// AF for subtraction: borrow out of bit 3
// Old: bool_to_bit(unsigned(a[3..0]) < unsigned(b[3..0]))
// New: high bit of (0b0 @ a[3..0]) - (0b0 @ b[3..0])

$property
function prop_af_sub_8(a : bits(8), b : bits(8)) -> bool = {
  let orig : bit = bool_to_bit(unsigned(a[3..0]) < unsigned(b[3..0]));
  let wide : bits(5) = (0b0 @ a[3..0]) - (0b0 @ b[3..0]);
  let branchless : bit = wide[4];
  orig == branchless
}

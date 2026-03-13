// Equivalence proofs for branchless bit XOR patterns
// Pattern: bool_to_bit(a != b) where a,b are bit → (a ^ b)[0]
// Pattern: bool_to_bit(a[N] != b[N]) → (a[N..N] ^ b[N..N])[0]
// Used in: SHLD/SHRD/SHL/ROL/ROR/RCL/RCR OF flag computation

$include "../model/prelude.sail"

// Pattern 1: bool_to_bit(bit != bit) → XOR
$property
function prop_bit_ne(a : bit, b : bit) -> bool = {
  let orig : bit = bool_to_bit(a != b);
  let branchless : bit = (a ^ b)[0];
  orig == branchless
}

// Pattern 2: SHLD/SHRD OF — result[N] != d[N]
$property
function prop_shld_of_16(r : bits(16), d : bits(16)) -> bool = {
  let orig : bit = bool_to_bit(r[15] != d[15]);
  let branchless : bit = (r[15..15] ^ d[15..15])[0];
  orig == branchless
}

$property
function prop_shld_of_32(r : bits(32), d : bits(32)) -> bool = {
  let orig : bit = bool_to_bit(r[31] != d[31]);
  let branchless : bit = (r[31..31] ^ d[31..31])[0];
  orig == branchless
}

$property
function prop_shld_of_64(r : bits(64), d : bits(64)) -> bool = {
  let orig : bit = bool_to_bit(r[63] != d[63]);
  let branchless : bit = (r[63..63] ^ d[63..63])[0];
  orig == branchless
}

// Pattern 3: SHL/ROL/RCL/RCR OF — result[N] != CF (bit register)
$property
function prop_shl_of_8(result : bits(8), cf : bit) -> bool = {
  let orig : bit = bool_to_bit(result[7] != cf);
  let branchless : bit = (result[7..7] ^ cf)[0];
  orig == branchless
}

$property
function prop_shl_of_16(result : bits(16), cf : bit) -> bool = {
  let orig : bit = bool_to_bit(result[15] != cf);
  let branchless : bit = (result[15..15] ^ cf)[0];
  orig == branchless
}

$property
function prop_shl_of_32(result : bits(32), cf : bit) -> bool = {
  let orig : bit = bool_to_bit(result[31] != cf);
  let branchless : bit = (result[31..31] ^ cf)[0];
  orig == branchless
}

$property
function prop_shl_of_64(result : bits(64), cf : bit) -> bool = {
  let orig : bit = bool_to_bit(result[63] != cf);
  let branchless : bit = (result[63..63] ^ cf)[0];
  orig == branchless
}

// Pattern 4: ROR OF — result[N] != result[N-1]
$property
function prop_ror_of_8(result : bits(8)) -> bool = {
  let orig : bit = bool_to_bit(result[7] != result[6]);
  let branchless : bit = (result[7..7] ^ result[6..6])[0];
  orig == branchless
}

$property
function prop_ror_of_16(result : bits(16)) -> bool = {
  let orig : bit = bool_to_bit(result[15] != result[14]);
  let branchless : bit = (result[15..15] ^ result[14..14])[0];
  orig == branchless
}

$property
function prop_ror_of_32(result : bits(32)) -> bool = {
  let orig : bit = bool_to_bit(result[31] != result[30]);
  let branchless : bit = (result[31..31] ^ result[30..30])[0];
  orig == branchless
}

$property
function prop_ror_of_64(result : bits(64)) -> bool = {
  let orig : bit = bool_to_bit(result[63] != result[62]);
  let branchless : bit = (result[63..63] ^ result[62..62])[0];
  orig == branchless
}

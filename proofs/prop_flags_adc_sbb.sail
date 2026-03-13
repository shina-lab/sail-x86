// Equivalence proofs: branchless CF, OF, AF for ADC and SBB

$include "../model/prelude.sail"

// ADC: CF from unsigned overflow with carry_in
// Old: bool_to_bit(unsigned(result) != unsigned(a) + unsigned(b) + c)
//      where c = unsigned(zero_extend(carry_in) : bits(1))
// New: carry bit from wide addition (0b0 @ a) + (0b0 @ b) + zero_extend(carry_in)

$property
function prop_cf_adc_8(a : bits(8), b : bits(8), carry_in : bit) -> bool = {
  let c : int = unsigned(zero_extend(carry_in) : bits(1));
  let result : bits(8) = a + b + zero_extend(carry_in);
  let orig : bit = bool_to_bit(unsigned(result) != unsigned(a) + unsigned(b) + c);
  let wide : bits(9) = (0b0 @ a) + (0b0 @ b) + zero_extend(carry_in);
  let branchless : bit = wide[8];
  orig == branchless
}

$property
function prop_cf_adc_32(a : bits(32), b : bits(32), carry_in : bit) -> bool = {
  let c : int = unsigned(zero_extend(carry_in) : bits(1));
  let result : bits(32) = a + b + zero_extend(carry_in);
  let orig : bit = bool_to_bit(unsigned(result) != unsigned(a) + unsigned(b) + c);
  let wide : bits(33) = (0b0 @ a) + (0b0 @ b) + zero_extend(carry_in);
  let branchless : bit = wide[32];
  orig == branchless
}

$property
function prop_cf_adc_64(a : bits(64), b : bits(64), carry_in : bit) -> bool = {
  let c : int = unsigned(zero_extend(carry_in) : bits(1));
  let result : bits(64) = a + b + zero_extend(carry_in);
  let orig : bit = bool_to_bit(unsigned(result) != unsigned(a) + unsigned(b) + c);
  let wide : bits(65) = (0b0 @ a) + (0b0 @ b) + zero_extend(carry_in);
  let branchless : bit = wide[64];
  orig == branchless
}

// ADC: OF from signed overflow with carry_in
// Old: bool_to_bit(signed(result) != signed(a) + signed(b) + c)
// New: overflow bit from wide signed addition

$property
function prop_of_adc_8(a : bits(8), b : bits(8), carry_in : bit) -> bool = {
  let c : int = unsigned(zero_extend(carry_in) : bits(1));
  let result : bits(8) = a + b + zero_extend(carry_in);
  let orig : bit = bool_to_bit(signed(result) != signed(a) + signed(b) + c);
  let wide : bits(9) = sign_extend(a) + sign_extend(b) + zero_extend(carry_in);
  let branchless : bit = (wide[8..8] ^ wide[7..7])[0];
  orig == branchless
}

$property
function prop_of_adc_32(a : bits(32), b : bits(32), carry_in : bit) -> bool = {
  let c : int = unsigned(zero_extend(carry_in) : bits(1));
  let result : bits(32) = a + b + zero_extend(carry_in);
  let orig : bit = bool_to_bit(signed(result) != signed(a) + signed(b) + c);
  let wide : bits(33) = sign_extend(a) + sign_extend(b) + zero_extend(carry_in);
  let branchless : bit = (wide[32..32] ^ wide[31..31])[0];
  orig == branchless
}

$property
function prop_of_adc_64(a : bits(64), b : bits(64), carry_in : bit) -> bool = {
  let c : int = unsigned(zero_extend(carry_in) : bits(1));
  let result : bits(64) = a + b + zero_extend(carry_in);
  let orig : bit = bool_to_bit(signed(result) != signed(a) + signed(b) + c);
  let wide : bits(65) = sign_extend(a) + sign_extend(b) + zero_extend(carry_in);
  let branchless : bit = (wide[64..64] ^ wide[63..63])[0];
  orig == branchless
}

// ADC: AF from nibble carry with carry_in
$property
function prop_af_adc_8(a : bits(8), b : bits(8), carry_in : bit) -> bool = {
  let c : int = unsigned(zero_extend(carry_in) : bits(1));
  let result : bits(8) = a + b + zero_extend(carry_in);
  let orig : bit = bool_to_bit(unsigned(result[3..0]) != unsigned(a[3..0]) + unsigned(b[3..0]) + c);
  let wide : bits(5) = (0b0 @ a[3..0]) + (0b0 @ b[3..0]) + zero_extend(carry_in);
  let branchless : bit = wide[4];
  orig == branchless
}

// SBB: CF from unsigned underflow with borrow_in
// Old: bool_to_bit(unsigned(a) < unsigned(b) + bw)
// New: borrow bit from wide subtraction

$property
function prop_cf_sbb_8(a : bits(8), b : bits(8), borrow_in : bit) -> bool = {
  let bw : int = unsigned(zero_extend(borrow_in) : bits(1));
  let orig : bit = bool_to_bit(unsigned(a) < unsigned(b) + bw);
  let wide : bits(9) = (0b0 @ a) - (0b0 @ b) - zero_extend(borrow_in);
  let branchless : bit = wide[8];
  orig == branchless
}

$property
function prop_cf_sbb_32(a : bits(32), b : bits(32), borrow_in : bit) -> bool = {
  let bw : int = unsigned(zero_extend(borrow_in) : bits(1));
  let orig : bit = bool_to_bit(unsigned(a) < unsigned(b) + bw);
  let wide : bits(33) = (0b0 @ a) - (0b0 @ b) - zero_extend(borrow_in);
  let branchless : bit = wide[32];
  orig == branchless
}

$property
function prop_cf_sbb_64(a : bits(64), b : bits(64), borrow_in : bit) -> bool = {
  let bw : int = unsigned(zero_extend(borrow_in) : bits(1));
  let orig : bit = bool_to_bit(unsigned(a) < unsigned(b) + bw);
  let wide : bits(65) = (0b0 @ a) - (0b0 @ b) - zero_extend(borrow_in);
  let branchless : bit = wide[64];
  orig == branchless
}

// SBB: OF from signed overflow with borrow_in
// Old: bool_to_bit(signed(result) != signed(a) - signed(b) - bw)

$property
function prop_of_sbb_8(a : bits(8), b : bits(8), borrow_in : bit) -> bool = {
  let bw : int = unsigned(zero_extend(borrow_in) : bits(1));
  let result : bits(8) = a - b - zero_extend(borrow_in);
  let orig : bit = bool_to_bit(signed(result) != signed(a) - signed(b) - bw);
  let wide : bits(9) = sign_extend(a) - sign_extend(b) - zero_extend(borrow_in);
  let branchless : bit = (wide[8..8] ^ wide[7..7])[0];
  orig == branchless
}

$property
function prop_of_sbb_32(a : bits(32), b : bits(32), borrow_in : bit) -> bool = {
  let bw : int = unsigned(zero_extend(borrow_in) : bits(1));
  let result : bits(32) = a - b - zero_extend(borrow_in);
  let orig : bit = bool_to_bit(signed(result) != signed(a) - signed(b) - bw);
  let wide : bits(33) = sign_extend(a) - sign_extend(b) - zero_extend(borrow_in);
  let branchless : bit = (wide[32..32] ^ wide[31..31])[0];
  orig == branchless
}

$property
function prop_of_sbb_64(a : bits(64), b : bits(64), borrow_in : bit) -> bool = {
  let bw : int = unsigned(zero_extend(borrow_in) : bits(1));
  let result : bits(64) = a - b - zero_extend(borrow_in);
  let orig : bit = bool_to_bit(signed(result) != signed(a) - signed(b) - bw);
  let wide : bits(65) = sign_extend(a) - sign_extend(b) - zero_extend(borrow_in);
  let branchless : bit = (wide[64..64] ^ wide[63..63])[0];
  orig == branchless
}

// SBB: AF from nibble borrow with borrow_in
$property
function prop_af_sbb_8(a : bits(8), b : bits(8), borrow_in : bit) -> bool = {
  let bw : int = unsigned(zero_extend(borrow_in) : bits(1));
  let orig : bit = bool_to_bit(unsigned(a[3..0]) < unsigned(b[3..0]) + bw);
  let wide : bits(5) = (0b0 @ a[3..0]) - (0b0 @ b[3..0]) - zero_extend(borrow_in);
  let branchless : bit = wide[4];
  orig == branchless
}

// Equivalence proof for arith_shr overflow case.
// Pattern: if v[N-1] == bitone then ones() else zeros() → zeros() - zero_extend(v[N-1..N-1])

default Order dec
$include <prelude.sail>

overload operator - = {sub_bits}
overload zeros = {sail_zeros}
overload ones = {sail_ones}
overload zero_extend = {sail_zero_extend}

// 16-bit: arith_shr_word overflow (count >= 16)
$property
function prop_arith_shr_word_overflow(v: bits(16)) -> bool = {
  let orig : bits(16) = if v[15] == bitone then ones(16) else zeros(16);
  let branchless : bits(16) = zeros(16) - zero_extend(v[15..15], 16);
  orig == branchless
}

// 32-bit: arith_shr_dword overflow (count >= 32)
$property
function prop_arith_shr_dword_overflow(v: bits(32)) -> bool = {
  let orig : bits(32) = if v[31] == bitone then ones(32) else zeros(32);
  let branchless : bits(32) = zeros(32) - zero_extend(v[31..31], 32);
  orig == branchless
}

// 64-bit: arith_shr_qword overflow (count >= 64)
$property
function prop_arith_shr_qword_overflow(v: bits(64)) -> bool = {
  let orig : bits(64) = if v[63] == bitone then ones(64) else zeros(64);
  let branchless : bits(64) = zeros(64) - zero_extend(v[63..63], 64);
  orig == branchless
}

// Full-width equivalence proofs for CWD/CDQ/CQO branchless conversion.
// Original: if high_bit == 1 then 0xFFFF else 0x0000
// New:      sign_extend(high_bit)

default Order dec
$include <prelude.sail>

overload operator - = {sub_bits}
overload zeros = {sail_zeros}
overload ones = {sail_ones}
overload sign_extend = {sail_sign_extend}

// CWD: 16-bit sign → 16-bit result
$property
function prop_cwd(ax : bits(16)) -> bool = {
  // Original (branching)
  let orig : bits(16) =
    if ax[15] == bitone then 0xFFFF
    else 0x0000;

  // New (branchless)
  let branchless : bits(16) = sign_extend(ax[15..15], 16);

  orig == branchless
}

// CDQ: 32-bit sign → 32-bit result
$property
function prop_cdq(eax : bits(32)) -> bool = {
  // Original (branching)
  let orig : bits(32) =
    if eax[31] == bitone then 0xFFFFFFFF
    else 0x00000000;

  // New (branchless)
  let branchless : bits(32) = sign_extend(eax[31..31], 32);

  orig == branchless
}

// CQO: 64-bit sign → 64-bit result
$property
function prop_cqo(rax : bits(64)) -> bool = {
  // Original (branching)
  let orig : bits(64) =
    if rax[63] == bitone then ones(64)
    else zeros(64);

  // New (branchless)
  let branchless : bits(64) = sign_extend(rax[63..63], 64);

  orig == branchless
}

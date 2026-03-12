// Full-width equivalence proofs for PCMPEQD / VPCMPEQD branchless conversion.

default Order dec
$include <prelude.sail>

overload operator - = {sub_bits}
overload zeros = {sail_zeros}
overload ones = {sail_ones}
overload zero_extend = {sail_zero_extend}

val cmp_eq32 : (bits(32), bits(32)) -> bits(32)
function cmp_eq32(a, b) = {
  let xd : bits(33) = (0b0 @ xor_vec(a, b)) - 0b000000000000000000000000000000001;
  zeros(32) - zero_extend(xd[32..32], 32)
}

// MMX PCMPEQD: 64-bit (2 dword lanes)
$property
function prop_pcmpeqd_mmx(a: bits(64), b: bits(64)) -> bool = {
  let r1 : bits(32) = if a[63..32] == b[63..32] then ones(32) else zeros(32);
  let r0 : bits(32) = if a[31..0]  == b[31..0]  then ones(32) else zeros(32);
  let orig : bits(64) = r1 @ r0;
  let branchless : bits(64) = cmp_eq32(a[63..32], b[63..32]) @ cmp_eq32(a[31..0], b[31..0]);
  orig == branchless
}

// SSE PCMPEQD: 128-bit (4 dword lanes)
$property
function prop_pcmpeqd_sse(a: bits(128), b: bits(128)) -> bool = {
  let r3 : bits(32) = if a[127..96] == b[127..96] then ones(32) else zeros(32);
  let r2 : bits(32) = if a[95..64]  == b[95..64]  then ones(32) else zeros(32);
  let r1 : bits(32) = if a[63..32]  == b[63..32]  then ones(32) else zeros(32);
  let r0 : bits(32) = if a[31..0]   == b[31..0]   then ones(32) else zeros(32);
  let orig : bits(128) = r3 @ r2 @ r1 @ r0;
  let branchless : bits(128) =
    cmp_eq32(a[127..96], b[127..96]) @ cmp_eq32(a[95..64], b[95..64]) @
    cmp_eq32(a[63..32], b[63..32]) @ cmp_eq32(a[31..0], b[31..0]);
  orig == branchless
}

// VEX VPCMPEQD 256-bit (8 dword lanes)
$property
function prop_pcmpeqd_vex256(a: bits(256), b: bits(256)) -> bool = {
  let r7 : bits(32) = if a[255..224] == b[255..224] then ones(32) else zeros(32);
  let r6 : bits(32) = if a[223..192] == b[223..192] then ones(32) else zeros(32);
  let r5 : bits(32) = if a[191..160] == b[191..160] then ones(32) else zeros(32);
  let r4 : bits(32) = if a[159..128] == b[159..128] then ones(32) else zeros(32);
  let r3 : bits(32) = if a[127..96]  == b[127..96]  then ones(32) else zeros(32);
  let r2 : bits(32) = if a[95..64]   == b[95..64]   then ones(32) else zeros(32);
  let r1 : bits(32) = if a[63..32]   == b[63..32]   then ones(32) else zeros(32);
  let r0 : bits(32) = if a[31..0]    == b[31..0]    then ones(32) else zeros(32);
  let orig : bits(256) = r7 @ r6 @ r5 @ r4 @ r3 @ r2 @ r1 @ r0;
  let branchless : bits(256) =
    cmp_eq32(a[255..224], b[255..224]) @ cmp_eq32(a[223..192], b[223..192]) @
    cmp_eq32(a[191..160], b[191..160]) @ cmp_eq32(a[159..128], b[159..128]) @
    cmp_eq32(a[127..96], b[127..96]) @ cmp_eq32(a[95..64], b[95..64]) @
    cmp_eq32(a[63..32], b[63..32]) @ cmp_eq32(a[31..0], b[31..0]);
  orig == branchless
}

// Full-width equivalence proofs for PCMPEQQ / VPCMPEQQ branchless conversion.

$include "../model/prelude.sail"


val cmp_eq64 : (bits(64), bits(64)) -> bits(64)
function cmp_eq64(a, b) = {
  let xd : bits(65) = (0b0 @ (a ^ b)) - zero_extend(0b1 : bits(1));
  zeros(64) - zero_extend(xd[64..64])
}

// SSE PCMPEQQ: 128-bit (2 qword lanes)
$property
function prop_pcmpeqq_sse(a: bits(128), b: bits(128)) -> bool = {
  let r1 : bits(64) = if a[127..64] == b[127..64] then ones(64) else zeros(64);
  let r0 : bits(64) = if a[63..0]   == b[63..0]   then ones(64) else zeros(64);
  let orig : bits(128) = r1 @ r0;
  let branchless : bits(128) = cmp_eq64(a[127..64], b[127..64]) @ cmp_eq64(a[63..0], b[63..0]);
  orig == branchless
}

// VEX VPCMPEQQ 128-bit (2 qword lanes)
$property
function prop_pcmpeqq_vex128(a: bits(128), b: bits(128)) -> bool = {
  let r1 : bits(64) = if a[127..64] == b[127..64] then ones(64) else zeros(64);
  let r0 : bits(64) = if a[63..0]   == b[63..0]   then ones(64) else zeros(64);
  let orig : bits(128) = r1 @ r0;
  let branchless : bits(128) = cmp_eq64(a[127..64], b[127..64]) @ cmp_eq64(a[63..0], b[63..0]);
  orig == branchless
}

// VEX VPCMPEQQ 256-bit (4 qword lanes)
$property
function prop_pcmpeqq_vex256(a: bits(256), b: bits(256)) -> bool = {
  let r3 : bits(64) = if a[255..192] == b[255..192] then ones(64) else zeros(64);
  let r2 : bits(64) = if a[191..128] == b[191..128] then ones(64) else zeros(64);
  let r1 : bits(64) = if a[127..64]  == b[127..64]  then ones(64) else zeros(64);
  let r0 : bits(64) = if a[63..0]    == b[63..0]    then ones(64) else zeros(64);
  let orig : bits(256) = r3 @ r2 @ r1 @ r0;
  let branchless : bits(256) =
    cmp_eq64(a[255..192], b[255..192]) @ cmp_eq64(a[191..128], b[191..128]) @
    cmp_eq64(a[127..64], b[127..64]) @ cmp_eq64(a[63..0], b[63..0]);
  orig == branchless
}

// Equivalence proof: BMI ZF can always use or_reduce_64 when upper bits are zero
//
// When vex_w=0, result[63:32] == 0, so or_reduce_64(result) == or_reduce_32(result[31:0])
// Therefore (~(or_reduce_64(result)))[0] == (~(or_reduce_32(result[31:0])))[0]
// And we can unconditionally use the 64-bit version.

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

// When upper 32 bits are zero, or_reduce_64 == or_reduce_32 on lower half
$property
function prop_bmi_zf(lo : bits(32)) -> bool = {
  let result : bits(64) = zeros(32) @ lo;
  let zf_32 : bit = (~(or_reduce_32(result[31..0])))[0];
  let zf_64 : bit = (~(or_reduce_64(result)))[0];
  zf_32 == zf_64
}

// Full proof: the branchy version equals unconditional 64-bit version
// when vex_w=0 implies upper bits are zero
$property
function prop_bmi_zf_full(lo : bits(32), hi : bits(32), vex_w : bool) -> bool = {
  // Model: when vex_w=false, result is zero-extended 32-bit (hi=0)
  let result : bits(64) = if vex_w then hi @ lo else zeros(32) @ lo;
  let branchy : bit = if vex_w
    then (~(or_reduce_64(result)))[0]
    else (~(or_reduce_32(result[31..0])))[0];
  let branchless : bit = (~(or_reduce_64(result)))[0];
  branchy == branchless
}

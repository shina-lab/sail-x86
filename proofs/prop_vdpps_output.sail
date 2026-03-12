default Order dec

$include <prelude.sail>

overload operator - = {sub_bits}
overload operator + = {add_bits}
overload operator ^ = {xor_vec}
overload operator & = {and_vec}
overload operator | = {or_vec}
overload zeros = {sail_zeros}
overload ones = {sail_ones}
overload ~ = {not_vec}
overload sign_extend = {sail_sign_extend}

// VDPPS output masking: if imm[i] == bitone then sum else zero
// → sum & sign_extend(imm[i..i])
$property
function prop_vdpps_output(sum : bits(32), imm : bits(8)) -> bool = {
  let zero : bits(32) = 0x00000000;
  let orig : bits(128) =
    (if imm[3] == bitone then sum else zero) @
    (if imm[2] == bitone then sum else zero) @
    (if imm[1] == bitone then sum else zero) @
    (if imm[0] == bitone then sum else zero);
  let branchless : bits(128) =
    (sum & sign_extend(imm[3..3])) @
    (sum & sign_extend(imm[2..2])) @
    (sum & sign_extend(imm[1..1])) @
    (sum & sign_extend(imm[0..0]));
  orig == branchless
}

// VDPPD output masking: if imm[i] == bitone then sum else zero
// → sum & sign_extend(imm[i..i])
$property
function prop_vdppd_output(sum : bits(64), imm : bits(8)) -> bool = {
  let zero : bits(64) = 0x0000000000000000;
  let orig : bits(128) =
    (if imm[1] == bitone then sum else zero) @
    (if imm[0] == bitone then sum else zero);
  let branchless : bits(128) =
    (sum & sign_extend(imm[1..1])) @
    (sum & sign_extend(imm[0..0]));
  orig == branchless
}

// VINSERTPS zero mask: if imm8[i] == bitone then 0x0 else ti
// → ti & sign_extend(~(imm8[i..i]))
$property
function prop_insertps_zero(t0 : bits(32), t1 : bits(32), t2 : bits(32), t3 : bits(32), imm8 : bits(8)) -> bool = {
  let orig : bits(128) =
    (if imm8[3] == bitone then 0x00000000 else t3) @
    (if imm8[2] == bitone then 0x00000000 else t2) @
    (if imm8[1] == bitone then 0x00000000 else t1) @
    (if imm8[0] == bitone then 0x00000000 else t0);
  let branchless : bits(128) =
    (t3 & sign_extend(~(imm8[3..3]))) @
    (t2 & sign_extend(~(imm8[2..2]))) @
    (t1 & sign_extend(~(imm8[1..1]))) @
    (t0 & sign_extend(~(imm8[0..0])));
  orig == branchless
}

// VPCLMULQDQ operand select: if imm[0] == bitone then src[127:64] else src[63:0]
// → blend64(src[63:0], src[127:64], imm[0..0])
val blend64 : (bits(64), bits(64), bits(1)) -> bits(64)
function blend64(a, b, sel) = { let m : bits(64) = sign_extend(sel); (a & ~(m)) | (b & m) }

$property
function prop_pclmulqdq_sel(src1 : bits(128), src2 : bits(128), imm : bits(8)) -> bool = {
  let sel_a_orig : bits(64) = if imm[0] == bitone then src1[127..64] else src1[63..0];
  let sel_b_orig : bits(64) = if imm[4] == bitone then src2[127..64] else src2[63..0];
  let sel_a_new : bits(64) = blend64(src1[63..0], src1[127..64], imm[0..0]);
  let sel_b_new : bits(64) = blend64(src2[63..0], src2[127..64], imm[4..4]);
  sel_a_orig == sel_a_new & sel_b_orig == sel_b_new
}

// VPERM2F128/VPERM2I128 conditional zeroing:
// var result = zeros(); if imm[3] == bitzero then result = match ...
// → let selected = match ...; selected & sign_extend(~(imm[3..3]))
$property
function prop_vperm2_zero(selected : bits(128), imm_bit : bits(1)) -> bool = {
  // Original: var result = zeros(); if bit == bitzero then result = selected
  let orig : bits(128) = if imm_bit == bitzero then selected else sail_zeros(128);
  // Branchless: selected & sign_extend(~bit)
  let branchless : bits(128) = selected & sign_extend(~(imm_bit));
  orig == branchless
}

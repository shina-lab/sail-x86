// Equivalence proof: avx_fpclass_f32 bool→bit transformation
//
// Original: returns bool using (exp == 0xFF) & (frac != zeros()) etc.
// Branchless: returns bit using or_reduce for comparisons

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

// Bool version (original)
function fpclass_f32_bool(src : bits(32), imm : bits(8)) -> bool = {
  let sign = src[31];
  let exp : bits(8) = src[30..23];
  let frac : bits(23) = src[22..0];
  let is_qnan = (exp == 0xFF) & (frac != zeros()) & (frac[22] == bitone);
  let is_snan = (exp == 0xFF) & (frac != zeros()) & (frac[22] == bitzero);
  let is_pos_zero = (sign == bitzero) & (exp == 0x00) & (frac == zeros());
  let is_neg_zero = (sign == bitone) & (exp == 0x00) & (frac == zeros());
  let is_pos_inf = (sign == bitzero) & (exp == 0xFF) & (frac == zeros());
  let is_neg_inf = (sign == bitone) & (exp == 0xFF) & (frac == zeros());
  let is_denorm = (exp == 0x00) & (frac != zeros());
  let is_neg_finite = (sign == bitone) & (exp != 0xFF) & not_bool((exp == 0x00) & (frac == zeros()));
  (imm[0] == bitone & is_qnan) |
  (imm[1] == bitone & is_pos_zero) |
  (imm[2] == bitone & is_neg_zero) |
  (imm[3] == bitone & is_pos_inf) |
  (imm[4] == bitone & is_neg_inf) |
  (imm[5] == bitone & is_denorm) |
  (imm[6] == bitone & is_neg_finite) |
  (imm[7] == bitone & is_snan)
}

// Bit version (new branchless)
function fpclass_f32_bit(src : bits(32), imm : bits(8)) -> bit = {
  let sign : bit = src[31];
  let exp : bits(8) = src[30..23];
  let frac : bits(23) = src[22..0];
  let exp_all : bit = (~(or_reduce_8(~(exp))))[0];
  let exp_zero : bit = (~(or_reduce_8(exp)))[0];
  let frac_nz : bit = (or_reduce_32(zero_extend(frac)))[0];
  let frac_zero : bit = ~(frac_nz);
  let is_qnan : bit = exp_all & frac_nz & frac[22];
  let is_snan : bit = exp_all & frac_nz & ~(frac[22]);
  let is_pos_zero : bit = ~(sign) & exp_zero & frac_zero;
  let is_neg_zero : bit = sign & exp_zero & frac_zero;
  let is_pos_inf : bit = ~(sign) & exp_all & frac_zero;
  let is_neg_inf : bit = sign & exp_all & frac_zero;
  let is_denorm : bit = exp_zero & frac_nz;
  let is_neg_finite : bit = sign & ~(exp_all) & ~(exp_zero & frac_zero);
  (imm[0] & is_qnan) |
  (imm[1] & is_pos_zero) |
  (imm[2] & is_neg_zero) |
  (imm[3] & is_pos_inf) |
  (imm[4] & is_neg_inf) |
  (imm[5] & is_denorm) |
  (imm[6] & is_neg_finite) |
  (imm[7] & is_snan)
}

$property
function prop_fpclass_f32(src : bits(32), imm : bits(8)) -> bool = {
  bool_to_bit(fpclass_f32_bool(src, imm)) == fpclass_f32_bit(src, imm)
}

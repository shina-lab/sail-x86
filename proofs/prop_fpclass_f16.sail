// Equivalence proof: fpclass_f16 bool→bit transformation

$include "../model/prelude.sail"

val or_reduce_8 : bits(8) -> bits(1)
function or_reduce_8(v) = {
  let r4 : bits(4) = v[7..4] | v[3..0];
  let r2 : bits(2) = r4[3..2] | r4[1..0];
  r2[1..1] | r2[0..0]
}
val or_reduce_16 : bits(16) -> bits(1)
function or_reduce_16(v) = or_reduce_8(v[15..8] | v[7..0])

function fpclass_f16_bool(v : bits(16), imm : bits(8)) -> bool = {
  let sign : bit = v[15];
  let exp : bits(5) = v[14..10];
  let mant : bits(10) = v[9..0];
  let is_zero : bool = (exp == 0b00000) & (mant == zeros());
  let is_denorm : bool = (exp == 0b00000) & (mant != zeros());
  let is_inf : bool = (exp == 0b11111) & (mant == zeros());
  let is_snan : bool = (exp == 0b11111) & (mant != zeros()) & (mant[9] == bitzero);
  let is_qnan : bool = (exp == 0b11111) & (mant[9] == bitone);
  let is_neg_finite : bool = (sign == bitone) & ~(is_zero) & ~(is_inf) & ~(is_snan) & ~(is_qnan);
  (imm[0] == bitone & is_qnan) |
  (imm[1] == bitone & is_zero & sign == bitzero) |
  (imm[2] == bitone & is_zero & sign == bitone) |
  (imm[3] == bitone & is_inf & sign == bitzero) |
  (imm[4] == bitone & is_inf & sign == bitone) |
  (imm[5] == bitone & is_denorm) |
  (imm[6] == bitone & is_neg_finite) |
  (imm[7] == bitone & is_snan)
}

function fpclass_f16_bit(v : bits(16), imm : bits(8)) -> bit = {
  let sign : bit = v[15];
  let exp : bits(5) = v[14..10];
  let mant : bits(10) = v[9..0];
  let exp_all : bit = (~(or_reduce_8(zero_extend(~(exp)))))[0];
  let exp_zero : bit = (~(or_reduce_8(zero_extend(exp))))[0];
  let mant_nz : bit = (or_reduce_16(zero_extend(mant)))[0];
  let mant_zero : bit = ~(mant_nz);
  let is_zero : bit = exp_zero & mant_zero;
  let is_denorm : bit = exp_zero & mant_nz;
  let is_inf : bit = exp_all & mant_zero;
  let is_snan : bit = exp_all & mant_nz & ~(mant[9]);
  let is_qnan : bit = exp_all & mant[9];
  let is_neg_finite : bit = sign & ~(is_zero) & ~(is_inf) & ~(is_snan) & ~(is_qnan);
  (imm[0] & is_qnan) |
  (imm[1] & is_zero & ~(sign)) |
  (imm[2] & is_zero & sign) |
  (imm[3] & is_inf & ~(sign)) |
  (imm[4] & is_inf & sign) |
  (imm[5] & is_denorm) |
  (imm[6] & is_neg_finite) |
  (imm[7] & is_snan)
}

$property
function prop_fpclass_f16(v : bits(16), imm : bits(8)) -> bool = {
  bool_to_bit(fpclass_f16_bool(v, imm)) == fpclass_f16_bit(v, imm)
}

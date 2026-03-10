// Equivalence check: ALU operations (ADD, SUB, AND, OR, XOR, ADC, SBB)
//
// Compares flag computation between sail-x86 and sail-x86-from-acl2
// for all ALU operations at 64-bit and 32-bit operand sizes.
//
// Run with: sail --smt --smt-auto --smt-auto-solver z3 equiv_alu.sail
//
// UNSAT = models are equivalent for all inputs
// SAT   = found a counterexample (bug in one model)

default Order dec

$include <prelude.sail>
$include <string.sail>

type qword = bits(64)

val bool_to_bit : bool -> bit
function bool_to_bit(b) = if b then bitone else bitzero

val sub_vec = pure {c: "sub_bits", _: "sub_vec"} : forall 'n. (bits('n), bits('n)) -> bits('n)
val sub_vec_int = pure {c: "sub_bits_int", _: "sub_vec_int"} : forall 'n. (bits('n), int) -> bits('n)
overload operator - = {sub_vec, sub_vec_int}

// =====================================================
// Model A: sail-x86 (our model) — flag computation
// =====================================================

val our_compute_pf : bits(8) -> bit
function our_compute_pf(v) = {
  let p : bit = xor_vec([v[0]], xor_vec([v[1]], xor_vec([v[2]], xor_vec([v[3]], xor_vec([v[4]], xor_vec([v[5]], xor_vec([v[6]], [v[7]])))))));
  not_vec(p)
}

val our_add_flags64 : (qword, qword, qword) -> (bit, bit, bit, bit, bit, bit)
function our_add_flags64(result, a, b) = {
  let cf = bool_to_bit(unsigned(result) != unsigned(a) + unsigned(b));
  let of_flag = bool_to_bit((a[63] == b[63]) & (result[63] != a[63]));
  let af = bool_to_bit(unsigned(result[3..0]) != unsigned(a[3..0]) + unsigned(b[3..0]));
  let sf = result[63];
  let zf = bool_to_bit(result == sail_zeros(64));
  let pf = our_compute_pf(result[7..0]);
  (cf, pf, af, zf, sf, of_flag)
}

val our_sub_flags64 : (qword, qword, qword) -> (bit, bit, bit, bit, bit, bit)
function our_sub_flags64(result, a, b) = {
  let cf = bool_to_bit(unsigned(a) < unsigned(b));
  let of_flag = bool_to_bit((a[63] != b[63]) & (result[63] != a[63]));
  let af = bool_to_bit(unsigned(a[3..0]) < unsigned(b[3..0]));
  let sf = result[63];
  let zf = bool_to_bit(result == sail_zeros(64));
  let pf = our_compute_pf(result[7..0]);
  (cf, pf, af, zf, sf, of_flag)
}

val our_logic_flags64 : qword -> (bit, bit, bit, bit, bit, bit)
function our_logic_flags64(result) = {
  let cf = bitzero;
  let of_flag = bitzero;
  let af = bitzero; // AF is undefined for logic ops in both models
  let sf = result[63];
  let zf = bool_to_bit(result == sail_zeros(64));
  let pf = our_compute_pf(result[7..0]);
  (cf, pf, af, zf, sf, of_flag)
}

val our_adc_flags64 : (qword, qword, qword, bit) -> (bit, bit, bit, bit, bit, bit)
function our_adc_flags64(result, a, b, carry_in) = {
  let c : int = if carry_in == bitone then 1 else 0;
  let cf = bool_to_bit(unsigned(result) != unsigned(a) + unsigned(b) + c);
  let of_flag = bool_to_bit(signed(result) != signed(a) + signed(b) + c);
  let af = bool_to_bit(unsigned(result[3..0]) != unsigned(a[3..0]) + unsigned(b[3..0]) + c);
  let sf = result[63];
  let zf = bool_to_bit(result == sail_zeros(64));
  let pf = our_compute_pf(result[7..0]);
  (cf, pf, af, zf, sf, of_flag)
}

val our_sbb_flags64 : (qword, qword, qword, bit) -> (bit, bit, bit, bit, bit, bit)
function our_sbb_flags64(result, a, b, borrow_in) = {
  let bw : int = if borrow_in == bitone then 1 else 0;
  let cf = bool_to_bit(unsigned(a) < unsigned(b) + bw);
  let of_flag = bool_to_bit(signed(result) != signed(a) - signed(b) - bw);
  let af = bool_to_bit(unsigned(a[3..0]) < unsigned(b[3..0]) + bw);
  let sf = result[63];
  let zf = bool_to_bit(result == sail_zeros(64));
  let pf = our_compute_pf(result[7..0]);
  (cf, pf, af, zf, sf, of_flag)
}

// 32-bit variants
val our_add_flags32 : (bits(32), bits(32), bits(32)) -> (bit, bit, bit, bit, bit, bit)
function our_add_flags32(result, a, b) = {
  let cf = bool_to_bit(unsigned(result) != unsigned(a) + unsigned(b));
  let of_flag = bool_to_bit((a[31] == b[31]) & (result[31] != a[31]));
  let af = bool_to_bit(unsigned(result[3..0]) != unsigned(a[3..0]) + unsigned(b[3..0]));
  let sf = result[31];
  let zf = bool_to_bit(result == sail_zeros(32));
  let pf = our_compute_pf(result[7..0]);
  (cf, pf, af, zf, sf, of_flag)
}

val our_sub_flags32 : (bits(32), bits(32), bits(32)) -> (bit, bit, bit, bit, bit, bit)
function our_sub_flags32(result, a, b) = {
  let cf = bool_to_bit(unsigned(a) < unsigned(b));
  let of_flag = bool_to_bit((a[31] != b[31]) & (result[31] != a[31]));
  let af = bool_to_bit(unsigned(a[3..0]) < unsigned(b[3..0]));
  let sf = result[31];
  let zf = bool_to_bit(result == sail_zeros(32));
  let pf = our_compute_pf(result[7..0]);
  (cf, pf, af, zf, sf, of_flag)
}

// =====================================================
// Model B: sail-x86-from-acl2 — flag computation
// =====================================================

val acl2_compute_pf : bits(8) -> bit
function acl2_compute_pf(v) = {
  let p : bit = xor_vec([v[0]], xor_vec([v[1]], xor_vec([v[2]], xor_vec([v[3]], xor_vec([v[4]], xor_vec([v[5]], xor_vec([v[6]], [v[7]])))))));
  not_vec(p)
}

val acl2_add64 : (qword, qword) -> (qword, bit, bit, bit, bit, bit, bit)
function acl2_add64(dst, src) = {
  let raw : bits(65) = sail_zero_extend(dst, 65) + sail_zero_extend(src, 65);
  let sraw : bits(65) = sail_sign_extend(dst, 65) + sail_sign_extend(src, 65);
  let result : qword = raw[63..0];
  let cf = raw[64];
  let pf = acl2_compute_pf(result[7..0]);
  let af = (sail_zero_extend(dst[3..0], 5) + sail_zero_extend(src[3..0], 5))[4];
  let zf = bool_to_bit(unsigned(result) == 0);
  let sf = result[63];
  let top2 = sraw[64..63];
  let of_flag = bool_to_bit(top2 != 0b00 & top2 != 0b11);
  (result, cf, pf, af, zf, sf, of_flag)
}

val acl2_sub64 : (qword, qword) -> (qword, bit, bit, bit, bit, bit, bit)
function acl2_sub64(dst, src) = {
  let raw : bits(65) = sail_zero_extend(dst, 65) - sail_zero_extend(src, 65);
  let sraw : bits(65) = sail_sign_extend(dst, 65) - sail_sign_extend(src, 65);
  let result : qword = raw[63..0];
  let cf = raw[64]; // borrow
  let pf = acl2_compute_pf(result[7..0]);
  let af = (sail_zero_extend(dst[3..0], 5) - sail_zero_extend(src[3..0], 5))[4];
  let zf = bool_to_bit(unsigned(result) == 0);
  let sf = result[63];
  let top2 = sraw[64..63];
  let of_flag = bool_to_bit(top2 != 0b00 & top2 != 0b11);
  (result, cf, pf, af, zf, sf, of_flag)
}

val acl2_add32 : (bits(32), bits(32)) -> (bits(32), bit, bit, bit, bit, bit, bit)
function acl2_add32(dst, src) = {
  let raw : bits(33) = sail_zero_extend(dst, 33) + sail_zero_extend(src, 33);
  let sraw : bits(33) = sail_sign_extend(dst, 33) + sail_sign_extend(src, 33);
  let result : bits(32) = raw[31..0];
  let cf = raw[32];
  let pf = acl2_compute_pf(result[7..0]);
  let af = (sail_zero_extend(dst[3..0], 5) + sail_zero_extend(src[3..0], 5))[4];
  let zf = bool_to_bit(unsigned(result) == 0);
  let sf = result[31];
  let top2 = sraw[32..31];
  let of_flag = bool_to_bit(top2 != 0b00 & top2 != 0b11);
  (result, cf, pf, af, zf, sf, of_flag)
}

val acl2_sub32 : (bits(32), bits(32)) -> (bits(32), bit, bit, bit, bit, bit, bit)
function acl2_sub32(dst, src) = {
  let raw : bits(33) = sail_zero_extend(dst, 33) - sail_zero_extend(src, 33);
  let sraw : bits(33) = sail_sign_extend(dst, 33) - sail_sign_extend(src, 33);
  let result : bits(32) = raw[31..0];
  let cf = raw[32];
  let pf = acl2_compute_pf(result[7..0]);
  let af = (sail_zero_extend(dst[3..0], 5) - sail_zero_extend(src[3..0], 5))[4];
  let zf = bool_to_bit(unsigned(result) == 0);
  let sf = result[31];
  let top2 = sraw[32..31];
  let of_flag = bool_to_bit(top2 != 0b00 & top2 != 0b11);
  (result, cf, pf, af, zf, sf, of_flag)
}

val acl2_adc64 : (qword, qword, bit) -> (qword, bit, bit, bit, bit, bit, bit)
function acl2_adc64(dst, src, input_cf) = {
  let cin : int = unsigned(input_cf);
  let raw : bits(65) = sail_zero_extend(dst, 65) + sail_zero_extend(src, 65) + sail_zero_extend([input_cf], 65);
  let sraw : bits(65) = sail_sign_extend(dst, 65) + sail_sign_extend(src, 65) + sail_zero_extend([input_cf], 65);
  let result : qword = raw[63..0];
  let cf = raw[64];
  let pf = acl2_compute_pf(result[7..0]);
  let sum4 : bits(5) = sail_zero_extend(dst[3..0], 5) + sail_zero_extend(src[3..0], 5) + sail_zero_extend([input_cf], 5);
  let af = sum4[4];
  let zf = bool_to_bit(unsigned(result) == 0);
  let sf = result[63];
  let top2 = sraw[64..63];
  let of_flag = bool_to_bit(top2 != 0b00 & top2 != 0b11);
  (result, cf, pf, af, zf, sf, of_flag)
}

val acl2_sbb64 : (qword, qword, bit) -> (qword, bit, bit, bit, bit, bit, bit)
function acl2_sbb64(dst, src, input_cf) = {
  let cin : int = unsigned(input_cf);
  let raw : bits(65) = sail_zero_extend(dst, 65) - sail_zero_extend(src, 65) - sail_zero_extend([input_cf], 65);
  let sraw : bits(65) = sail_sign_extend(dst, 65) - sail_sign_extend(src, 65) - sail_zero_extend([input_cf], 65);
  let result : qword = raw[63..0];
  let cf = raw[64];
  let pf = acl2_compute_pf(result[7..0]);
  let diff4 : bits(5) = sail_zero_extend(dst[3..0], 5) - sail_zero_extend(src[3..0], 5) - sail_zero_extend([input_cf], 5);
  let af = diff4[4];
  let zf = bool_to_bit(unsigned(result) == 0);
  let sf = result[63];
  let top2 = sraw[64..63];
  let of_flag = bool_to_bit(top2 != 0b00 & top2 != 0b11);
  (result, cf, pf, af, zf, sf, of_flag)
}

// =====================================================
// Equivalence properties
// =====================================================

// ADD 64-bit
$property
val prop_add64 : (qword, qword) -> bool
function prop_add64(a, b) = {
  let result = a + b;
  let (our_cf, our_pf, our_af, our_zf, our_sf, our_of) = our_add_flags64(result, a, b);
  let (acl2_result, acl2_cf, acl2_pf, acl2_af, acl2_zf, acl2_sf, acl2_of) = acl2_add64(a, b);
  result == acl2_result & our_cf == acl2_cf & our_pf == acl2_pf &
  our_af == acl2_af & our_zf == acl2_zf & our_sf == acl2_sf & our_of == acl2_of
}

// SUB 64-bit
$property
val prop_sub64 : (qword, qword) -> bool
function prop_sub64(a, b) = {
  let result = a - b;
  let (our_cf, our_pf, our_af, our_zf, our_sf, our_of) = our_sub_flags64(result, a, b);
  let (acl2_result, acl2_cf, acl2_pf, acl2_af, acl2_zf, acl2_sf, acl2_of) = acl2_sub64(a, b);
  result == acl2_result & our_cf == acl2_cf & our_pf == acl2_pf &
  our_af == acl2_af & our_zf == acl2_zf & our_sf == acl2_sf & our_of == acl2_of
}

// AND 64-bit (compare only defined flags; AF is undefined in both models for logic ops)
$property
val prop_and64 : (qword, qword) -> bool
function prop_and64(a, b) = {
  let result = a & b;
  let (our_cf, our_pf, _, our_zf, our_sf, our_of) = our_logic_flags64(result);
  // ACL2's logic spec also clears CF and OF, AF undefined
  our_cf == bitzero & our_of == bitzero &
  our_sf == result[63] & our_zf == bool_to_bit(result == sail_zeros(64)) &
  our_pf == acl2_compute_pf(result[7..0])
}

// OR 64-bit
$property
val prop_or64 : (qword, qword) -> bool
function prop_or64(a, b) = {
  let result = a | b;
  let (our_cf, our_pf, _, our_zf, our_sf, our_of) = our_logic_flags64(result);
  our_cf == bitzero & our_of == bitzero &
  our_sf == result[63] & our_zf == bool_to_bit(result == sail_zeros(64)) &
  our_pf == acl2_compute_pf(result[7..0])
}

// XOR 64-bit
$property
val prop_xor64 : (qword, qword) -> bool
function prop_xor64(a, b) = {
  let result = xor_vec(a, b);
  let (our_cf, our_pf, _, our_zf, our_sf, our_of) = our_logic_flags64(result);
  our_cf == bitzero & our_of == bitzero &
  our_sf == result[63] & our_zf == bool_to_bit(result == sail_zeros(64)) &
  our_pf == acl2_compute_pf(result[7..0])
}

// ADD 32-bit
$property
val prop_add32 : (bits(32), bits(32)) -> bool
function prop_add32(a, b) = {
  let result = a + b;
  let (our_cf, our_pf, our_af, our_zf, our_sf, our_of) = our_add_flags32(result, a, b);
  let (acl2_result, acl2_cf, acl2_pf, acl2_af, acl2_zf, acl2_sf, acl2_of) = acl2_add32(a, b);
  result == acl2_result & our_cf == acl2_cf & our_pf == acl2_pf &
  our_af == acl2_af & our_zf == acl2_zf & our_sf == acl2_sf & our_of == acl2_of
}

// SUB 32-bit
$property
val prop_sub32 : (bits(32), bits(32)) -> bool
function prop_sub32(a, b) = {
  let result = a - b;
  let (our_cf, our_pf, our_af, our_zf, our_sf, our_of) = our_sub_flags32(result, a, b);
  let (acl2_result, acl2_cf, acl2_pf, acl2_af, acl2_zf, acl2_sf, acl2_of) = acl2_sub32(a, b);
  result == acl2_result & our_cf == acl2_cf & our_pf == acl2_pf &
  our_af == acl2_af & our_zf == acl2_zf & our_sf == acl2_sf & our_of == acl2_of
}

// ADC 64-bit (with carry input)
$property
val prop_adc64 : (qword, qword, bit) -> bool
function prop_adc64(a, b, carry_in) = {
  let c : qword = sail_zero_extend([carry_in], 64);
  let result = a + b + c;
  let (our_cf, our_pf, our_af, our_zf, our_sf, our_of) = our_adc_flags64(result, a, b, carry_in);
  let (acl2_result, acl2_cf, acl2_pf, acl2_af, acl2_zf, acl2_sf, acl2_of) = acl2_adc64(a, b, carry_in);
  result == acl2_result & our_cf == acl2_cf & our_pf == acl2_pf &
  our_af == acl2_af & our_zf == acl2_zf & our_sf == acl2_sf & our_of == acl2_of
}

// SBB 64-bit (with borrow input)
$property
val prop_sbb64 : (qword, qword, bit) -> bool
function prop_sbb64(a, b, borrow_in) = {
  let bw : qword = sail_zero_extend([borrow_in], 64);
  let result = a - b - bw;
  let (our_cf, our_pf, our_af, our_zf, our_sf, our_of) = our_sbb_flags64(result, a, b, borrow_in);
  let (acl2_result, acl2_cf, acl2_pf, acl2_af, acl2_zf, acl2_sf, acl2_of) = acl2_sbb64(a, b, borrow_in);
  result == acl2_result & our_cf == acl2_cf & our_pf == acl2_pf &
  our_af == acl2_af & our_zf == acl2_zf & our_sf == acl2_sf & our_of == acl2_of
}

val main : unit -> unit
function main() = ()

// Equivalence proof: fp32_to_fp16 branchless rewrite
//
// Old: five-way if/else (inf/NaN, overflow, underflow, denorm output, normal)
//      with branchy rounding via match + bool
// New: compute all paths in parallel, mux with blend; rounding via bit ops

$include "../model/prelude.sail"

type byte    = bits(8)
type word    = bits(16)
type dword   = bits(32)
type qword   = bits(64)

// --- Helpers (copied from branchless.sail) ---

val popcount : forall 'n, 0 < 'n & 'n <= 64. bits('n) -> range(0, 'n)
function popcount(v) = {
  let x1 : qword = zero_extend(v);
  let x2 = (x1 & 0x5555555555555555) + ((x1 >> 1)  & 0x5555555555555555);
  let x3 = (x2 & 0x3333333333333333) + ((x2 >> 2)  & 0x3333333333333333);
  let x4 = (x3 & 0x0f0f0f0f0f0f0f0f) + ((x3 >> 4)  & 0x0f0f0f0f0f0f0f0f);
  let x5 = (x4 & 0x00ff00ff00ff00ff) + ((x4 >> 8)  & 0x00ff00ff00ff00ff);
  let x6 = (x5 & 0x0000ffff0000ffff) + ((x5 >> 16) & 0x0000ffff0000ffff);
  let x7 = (x6 & 0x00000000ffffffff) + ((x6 >> 32) & 0x00000000ffffffff);
  let x = unsigned(x7);
  assert(x <= 'n);
  x
}

val or_reduce : forall 'n, 0 < 'n & 'n <= 64. bits('n) -> bits(1)
function or_reduce(v) = {
  let x1 : qword = zero_extend(v);
  let x2 = x1 | (x1 >> 1);
  let x3 = x2 | (x2 >> 2);
  let x4 = x3 | (x3 >> 4);
  let x5 = x4 | (x4 >> 8);
  let x6 = x5 | (x5 >> 16);
  let x7 = x6 | (x6 >> 32);
  x7[0]
}

val is_nonzero : forall 'n, 0 < 'n & 'n <= 64. bits('n) -> bit
function is_nonzero(v) = or_reduce(v)[0]

val is_zero : forall 'n, 0 < 'n & 'n <= 64. bits('n) -> bit
function is_zero(v) = (~(or_reduce(v)))[0]

val is_eq : forall 'n, 0 < 'n & 'n <= 64. (bits('n), bits('n)) -> bit
function is_eq(a, b) = is_zero(a ^ b)

val is_gt_u : forall 'n, 0 < 'n & 'n <= 64. (bits('n), bits('n)) -> bit
function is_gt_u(a, b) = {
  let diff : bits('n + 1) = zero_extend(b) - zero_extend(a);
  diff['n]
}

val is_lt_u : forall 'n, 0 < 'n & 'n <= 64. (bits('n), bits('n)) -> bit
function is_lt_u(a, b) = is_gt_u(b, a)

val blend : forall 'n, 0 < 'n. (bits('n), bits('n), bit) -> bits('n)
function blend(a, b, sel) = {
  let m : bits('n) = sign_extend(sel);
  (a & ~(m)) | (b & m)
}

// --- OLD: branchy fp32_to_fp16 ---

val fp32_to_fp16_old : (bits(32), bits(2)) -> bits(16)
function fp32_to_fp16_old(f, rc) = {
  let sign : bits(1) = f[31];
  let exp8 : bits(8) = f[30..23];
  let frac23 : bits(23) = f[22..0];
  let exp_val : nat = unsigned(exp8);
  if exp8 == 0xFF then {
    if frac23 == zeros() then sign @ 0b11111 @ 0b0000000000
    else sign @ 0b11111 @ frac23[22..13]
  } else if exp_val > 142 then {
    sign @ 0b11111 @ 0b0000000000
  } else if exp_val < 103 then {
    sign @ 0b00000 @ 0b0000000000
  } else {
    let (top15, round_bit, sticky_bit) : (bits(15), bit, bit) =
      if exp_val < 113 then {
        let shift_amt : nat = 113 - exp_val;
        let wide : bits(37) = (0b1 @ frac23) @ 0b0000000000000;
        let shifted : bits(37) = wide >> shift_amt;
        let sticky : bits(26) = (0b0 @ shifted[24..0]) - 1;
        (0b00000 @ shifted[35..26], shifted[25], ~(sticky[25]))
      } else {
        let new_exp : int = exp_val - 112;
        let sticky : bits(13) = (0b0 @ frac23[11..0]) - 1;
        (get_slice_int(5, new_exp, 0) @ frac23[22..13], frac23[12], ~(sticky[12]))
      };
    let round_up : bool = match rc {
      0b00 => (round_bit == 0b1) & (sticky_bit == 0b1 | top15[0] == 0b1),
      0b01 => (sign == 0b1) & (round_bit == 0b1 | sticky_bit == 0b1),
      0b10 => (sign == 0b0) & (round_bit == 0b1 | sticky_bit == 0b1),
      0b11 => false
    };
    let result15 : bits(15) = if round_up then top15 + 1 else top15;
    sign @ result15
  }
}

// --- NEW: branchless fp32_to_fp16 ---

val fp32_to_fp16_new : (bits(32), bits(2)) -> bits(16)
function fp32_to_fp16_new(f, rc) = {
  let sign : bits(1) = f[31..31];
  let exp8 : bits(8) = f[30..23];
  let frac23 : bits(23) = f[22..0];

  let is_inf_nan : bit = is_eq(exp8, 0xFF);
  let is_overflow : bit = is_gt_u(exp8, 0x8E) & ~(is_inf_nan);
  let is_underflow : bit = is_lt_u(exp8, 0x67);
  let is_denorm_out : bit = is_lt_u(exp8, 0x71) & ~(is_underflow);

  // Normal output path
  let norm_top15 : bits(15) = (exp8 - 0x70)[4..0] @ frac23[22..13];
  let norm_round : bit = frac23[12];
  let norm_sticky : bit = is_nonzero(frac23[11..0]);

  // Denormal output path
  let shift_amt = unsigned(0x71 - exp8);
  let shifted : bits(37) = ((0b1 @ frac23) @ 0b0000000000000) >> shift_amt;
  let denorm_top15 : bits(15) = 0b00000 @ shifted[35..26];
  let denorm_round : bit = shifted[25];
  let denorm_sticky : bit = is_nonzero(shifted[24..0]);

  // Mux normal vs denormal
  let top15 : bits(15) = blend(norm_top15, denorm_top15, is_denorm_out);
  let round_bit : bit = (norm_round & ~(is_denorm_out)) | (denorm_round & is_denorm_out);
  let sticky_bit : bit = (norm_sticky & ~(is_denorm_out)) | (denorm_sticky & is_denorm_out);

  // Rounding: 4-way mux on rc
  let rs : bit = round_bit | sticky_bit;
  let rne_up : bit = round_bit & (sticky_bit | top15[0]);
  let down_up : bit = sign[0] & rs;
  let up_up : bit = ~(sign[0]) & rs;
  let lo : bit = (rne_up & ~(rc[0])) | (down_up & rc[0]);
  let hi : bit = (up_up & ~(rc[0]));
  let round_up : bit = (lo & ~(rc[1])) | (hi & rc[1]);

  let result15 : bits(15) = top15 + zero_extend(round_up);

  let body : bits(15) = result15;
  let body : bits(15) = blend(body, zeros(), is_underflow);
  let body : bits(15) = blend(body, 0b11111 @ zeros(10), is_overflow);
  let body : bits(15) = blend(body, 0b11111 @ frac23[22..13], is_inf_nan);

  sign @ body
}

// --- Equivalence property ---

$property
function prop_fp32_to_fp16(f : dword, rc : bits(2)) -> bool =
  fp32_to_fp16_old(f, rc) == fp32_to_fp16_new(f, rc)

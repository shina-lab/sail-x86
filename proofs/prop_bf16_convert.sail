// Equivalence proof: convert_fp32_to_bf16 branchless rewrite
//
// Old: four-way if/else on exp and mantissa
// New: compute all four results, blend based on classification
//
// Cases:
//   exp==0x00          → signed zero: sign @ 0..0
//   exp==0xFF & mant≠0 → QNaN: truncated | 0x0040
//   exp==0xFF & mant=0 → Infinity: x[31..16]
//   else               → Normal: round to nearest even
//
// Branchless: compute normal result always, then blend in special cases.

$include "../model/prelude.sail"

type byte    = bits(8)
type word    = bits(16)
type dword   = bits(32)

val or_reduce : forall 'n, 0 < 'n & 'n <= 64. bits('n) -> bits(1)
function or_reduce(v) = {
  let x1 : bits(64) = zero_extend(v);
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

val blend : forall 'n, 0 < 'n. (bits('n), bits('n), bit) -> bits('n)
function blend(a, b, sel) = {
  let m : bits('n) = sign_extend(sel);
  (a & ~(m)) | (b & m)
}

$property
function prop_bf16(x : dword) -> bool = {
  let exp : byte = x[30..23];
  let mant : bits(23) = x[22..0];
  // OLD: four-way branch
  let orig : word =
    if exp == 0x00 then
      x[31] @ zeros(15)
    else if exp == 0xFF & mant != zeros() then {
      let truncated : word = x[31..16];
      truncated | 0x0040
    } else if exp == 0xFF then
      x[31..16]
    else {
      let lsb : bit = x[16];
      let rounding_bias : dword = 0x00007FFF + zero_extend(lsb);
      let temp : dword = x + rounding_bias;
      temp[31..16]
    };
  // NEW: branchless — compute all results, blend by classification
  let exp_zero : bit = is_zero(exp);
  let exp_all  : bit = is_zero(~(exp));
  let mant_nz  : bit = is_nonzero(mant);
  let r_zero   : word = x[31] @ zeros(15);
  let r_nan    : word = x[31..16] | 0x0040;
  let r_inf    : word = x[31..16];
  let lsb      : bit  = x[16];
  let r_normal : word = (x + 0x00007FFF + zero_extend(lsb))[31..16];
  // Start with normal, override for special cases
  let r1 : word = blend(r_normal, r_zero, exp_zero);         // exp==0 → zero
  let r2 : word = blend(r1, r_inf, exp_all & ~(mant_nz));    // exp==FF & mant==0 → inf
  let r3 : word = blend(r2, r_nan, exp_all & mant_nz);       // exp==FF & mant≠0 → NaN
  let branchless : word = r3;
  orig == branchless
}

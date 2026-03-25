// Equivalence proof: fp16_to_fp32 branchless rewrite
//
// Old: three-way if/else (inf/NaN, zero/denormal with loop, normal)
// New: compute all four results in parallel, mux with blend
//
// The denormal normalization loop (counting leading zeros with foreach)
// is replaced by branchless clz + shift.

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

val blend : forall 'n, 0 < 'n. (bits('n), bits('n), bit) -> bits('n)
function blend(a, b, sel) = {
  let m : bits('n) = sign_extend(sel);
  (a & ~(m)) | (b & m)
}

val clz : forall 'n, 0 < 'n & 'n <= 64. bits('n) -> range(0, 'n)
function clz(v) = {
  let x1 : bits('n) = v  | (v  >> 1);
  let x2 : bits('n) = x1 | (x1 >> 2);
  let x3 : bits('n) = x2 | (x2 >> 4);
  let x4 : bits('n) = x3 | (x3 >> 8);
  let x5 : bits('n) = x4 | (x4 >> 16);
  let x6 : bits('n) = x5 | (x5 >> 32);
  'n - popcount(x6)
}

// --- OLD: branchy fp16_to_fp32 ---

val fp16_to_fp32_old : bits(16) -> bits(32)
function fp16_to_fp32_old(h) = {
  let sign : bits(1) = h[15];
  let exp5 : bits(5) = h[14..10];
  let frac10 : bits(10) = h[9..0];
  if exp5 == 0b11111 then {
    sign @ 0xFF @ frac10 @ 0b0000000000000
  } else if exp5 == 0b00000 then {
    if frac10 == zeros() then {
      sign @ zeros(31)
    } else {
      var shift : nat = 0;
      let f : bits(10) = frac10;
      var done : bool = false;
      foreach (i from 9 downto 0) {
        if ~(done) & f[i] == 0b0 then shift = shift + 1
        else done = true
      };
      let new_exp : int = 112 - shift;
      let shifted : bits(10) = frac10 << (shift + 1);
      sign @ get_slice_int(8, new_exp, 0) @ shifted @ 0b0000000000000
    }
  } else {
    let new_exp : bits(8) = zero_extend(exp5) + 0x70;
    sign @ new_exp @ frac10 @ 0b0000000000000
  }
}

// --- NEW: branchless fp16_to_fp32 ---

val fp16_to_fp32_new : bits(16) -> bits(32)
function fp16_to_fp32_new(h) = {
  let sign : bits(1) = h[15..15];
  let exp5 : bits(5) = h[14..10];
  let frac10 : bits(10) = h[9..0];

  let inf_nan : bit = is_eq(exp5, 0b11111);
  let zero_exp : bit = is_eq(exp5, 0b00000);
  let frac_nz : bit = is_nonzero(frac10);

  let normal_body : bits(31) = (zero_extend(exp5) + 0x70) @ frac10 @ 0b0000000000000;

  let lz = clz(frac10);
  let denorm_body : bits(31) =
    to_bits(8, 112 - lz) @ (frac10 << (lz + 1)) @ 0b0000000000000;

  let infnan_body : bits(31) = 0xFF @ frac10 @ 0b0000000000000;

  let body : bits(31) = blend(normal_body, denorm_body, zero_exp & frac_nz);
  let body : bits(31) = blend(body, zeros(), zero_exp & ~(frac_nz));
  let body : bits(31) = blend(body, infnan_body, inf_nan);

  sign @ body
}

// --- Equivalence property ---

$property
function prop_fp16_to_fp32(h : word) -> bool =
  fp16_to_fp32_old(h) == fp16_to_fp32_new(h)

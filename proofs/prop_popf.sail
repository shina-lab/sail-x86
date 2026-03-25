// Equivalence proof: POPF privilege-conditional flag writes
//
// 16/32-bit:
//   Old: if cur_cpl == 0 then IOPL = new; if cur_cpl <= IOPL then IF = new
//   New: IOPL = blend(old, new, is_eq(cpl, 0)); IF = blend(old, new, ~is_gt_u(cpl, iopl))
//
// 64-bit (restore):
//   Old: if cur_cpl != 0 then IOPL = old; if cur_cpl > IOPL then IF = old
//   New: IOPL = blend(new, old, ~is_eq(cpl, 0)); IF = blend(new, old, is_gt_u(cpl, iopl))

$include "../model/prelude.sail"

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

val is_zero : forall 'n, 0 < 'n & 'n <= 64. bits('n) -> bit
function is_zero(v) = (~(or_reduce(v)))[0]

val is_eq : forall 'n, 0 < 'n & 'n <= 64. (bits('n), bits('n)) -> bit
function is_eq(a, b) = is_zero(a ^ b)

val is_gt_u : forall 'n, 0 < 'n & 'n <= 64. (bits('n), bits('n)) -> bit
function is_gt_u(a, b) = {
  let diff : bits('n + 1) = zero_extend(b) - zero_extend(a);
  diff['n]
}

val blend : forall 'n, 0 < 'n. (bits('n), bits('n), bit) -> bits('n)
function blend(a, b, sel) = {
  let m : bits('n) = sign_extend(sel);
  (a & ~(m)) | (b & m)
}

// 16/32-bit IOPL: if cpl == 0 then new else old
$property
function prop_popf_iopl(old_iopl : bits(2), new_iopl : bits(2), cpl : bits(2)) -> bool = {
  let orig : bits(2) = if cpl == 0b00 then new_iopl else old_iopl;
  let branchless : bits(2) = blend(old_iopl, new_iopl, is_eq(cpl, 0b00));
  orig == branchless
}

// 16/32-bit IF: if cpl <= iopl then new else old
$property
function prop_popf_if(old_if : bit, new_if : bit, cpl : bits(2), iopl : bits(2)) -> bool = {
  let orig : bit = if unsigned(cpl) <= unsigned(iopl) then new_if else old_if;
  let branchless : bit = blend(old_if, new_if, ~(is_gt_u(cpl, iopl)));
  orig == branchless
}

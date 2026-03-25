// Equivalence proof: pcmp_clamp_len branchless rewrite
//
// Old code:
//   let a : int = if signed(raw) < 0 then negate(signed(raw)) else signed(raw);
//   if a >= max_len then max_len
//   else if a < 0 then 0
//   else a
//
// New code:
//   let clamped : dword = min_u(abs(raw), to_bits(32, max_len));
//   unsigned(clamped)
//
// abs(x) = (x ^ sign) - sign  where sign = sign_extend(x[31])
// min_u(a, b) = blend(a, b, is_gt_u(a, b))

$include "../model/prelude.sail"

type dword = bits(32)

val abs32 : dword -> dword
function abs32(x) = {
  let m : dword = sign_extend(x[31]);
  (x ^ m) - m
}

val is_gt_u32 : (dword, dword) -> bit
function is_gt_u32(a, b) = {
  let diff : bits(33) = zero_extend(b) - zero_extend(a);
  diff[32]
}

val blend32 : (dword, dword, bit) -> dword
function blend32(a, b, sel) = {
  let m : dword = sign_extend(sel);
  (a & ~(m)) | (b & m)
}

val min_u32 : (dword, dword) -> dword
function min_u32(a, b) = blend32(a, b, is_gt_u32(a, b))

// Prove for max_len values that PCMPxSTRx actually uses (8 and 16)
$property
function prop_clamp_len_8(raw : dword) -> bool = {
  let max_len = 8;
  // Old code
  let s = signed(raw);
  let a : int = if s < 0 then negate(s) else s;
  let orig : int =
    if a >= max_len then max_len
    else if a < 0 then 0
    else a;
  // New code
  let clamped : dword = min_u32(abs32(raw), to_bits(32, max_len));
  let branchless : int = unsigned(clamped);
  orig == branchless
}

$property
function prop_clamp_len_16(raw : dword) -> bool = {
  let max_len = 16;
  // Old code
  let s = signed(raw);
  let a : int = if s < 0 then negate(s) else s;
  let orig : int =
    if a >= max_len then max_len
    else if a < 0 then 0
    else a;
  // New code
  let clamped : dword = min_u32(abs32(raw), to_bits(32, max_len));
  let branchless : int = unsigned(clamped);
  orig == branchless
}

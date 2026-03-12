$include "../model/prelude.sail"

type word    = bits(16)
type dword   = bits(32)
type qword   = bits(64)

// Prove that clamping is unnecessary for sail_arith_shiftright:
// sail_arith_shiftright already produces all-sign-bits when count >= width.

// Word (16-bit): clamped vs unclamped
$property
function prop_arith_shr_word_clamp(v : word, count : bits(8)) -> bool = {
  let c : range(0, 255) = unsigned(count);
  let clamped = if c > 15 then 16 else c;
  sail_arith_shiftright(v, clamped) == sail_arith_shiftright(v, c)
}

// Dword (32-bit): clamped vs unclamped
$property
function prop_arith_shr_dword_clamp(v : dword, count : bits(8)) -> bool = {
  let c : range(0, 255) = unsigned(count);
  let clamped = if c > 31 then 32 else c;
  sail_arith_shiftright(v, clamped) == sail_arith_shiftright(v, c)
}

// Qword (64-bit): clamped vs unclamped
$property
function prop_arith_shr_qword_clamp(v : qword, count : bits(8)) -> bool = {
  let c : range(0, 255) = unsigned(count);
  let clamped = if c > 63 then 64 else c;
  sail_arith_shiftright(v, clamped) == sail_arith_shiftright(v, c)
}

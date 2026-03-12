$include "../model/prelude.sail"

type word = bits(16)
type dword = bits(32)
type qword = bits(64)

// ================================================================
// Prove that sll/srl/sra range-check branches are redundant:
// Sail's shift operators already handle counts >= element width.
//
// For logical shifts: v << count and v >> count produce zeros
//   when count >= width (bits shift out).
// For arithmetic shifts: sail_arith_shiftright(v, count) sign-fills
//   when count >= width, and returns v when count == 0.
// ================================================================

// --- Logical left shift ---

val sll16_orig : (word, range(0, 255)) -> word
function sll16_orig(v, count) = if count > 15 then zeros() else v << count

val sll16_new : (word, range(0, 255)) -> word
function sll16_new(v, count) = v << count

$property
function prop_sll16(v : word, count : bits(8)) -> bool = {
  let c : range(0, 255) = unsigned(count);
  sll16_orig(v, c) == sll16_new(v, c)
}

val sll32_orig : (dword, range(0, 255)) -> dword
function sll32_orig(v, count) = if count > 31 then zeros() else v << count

val sll32_new : (dword, range(0, 255)) -> dword
function sll32_new(v, count) = v << count

$property
function prop_sll32(v : dword, count : bits(8)) -> bool = {
  let c : range(0, 255) = unsigned(count);
  sll32_orig(v, c) == sll32_new(v, c)
}

val sll64_orig : (qword, range(0, 255)) -> qword
function sll64_orig(v, count) = if count > 63 then zeros() else v << count

val sll64_new : (qword, range(0, 255)) -> qword
function sll64_new(v, count) = v << count

$property
function prop_sll64(v : qword, count : bits(8)) -> bool = {
  let c : range(0, 255) = unsigned(count);
  sll64_orig(v, c) == sll64_new(v, c)
}

// --- Logical right shift ---

val srl16_orig : (word, range(0, 255)) -> word
function srl16_orig(v, count) = if count > 15 then zeros() else v >> count

val srl16_new : (word, range(0, 255)) -> word
function srl16_new(v, count) = v >> count

$property
function prop_srl16(v : word, count : bits(8)) -> bool = {
  let c : range(0, 255) = unsigned(count);
  srl16_orig(v, c) == srl16_new(v, c)
}

val srl32_orig : (dword, range(0, 255)) -> dword
function srl32_orig(v, count) = if count > 31 then zeros() else v >> count

val srl32_new : (dword, range(0, 255)) -> dword
function srl32_new(v, count) = v >> count

$property
function prop_srl32(v : dword, count : bits(8)) -> bool = {
  let c : range(0, 255) = unsigned(count);
  srl32_orig(v, c) == srl32_new(v, c)
}

val srl64_orig : (qword, range(0, 255)) -> qword
function srl64_orig(v, count) = if count > 63 then zeros() else v >> count

val srl64_new : (qword, range(0, 255)) -> qword
function srl64_new(v, count) = v >> count

$property
function prop_srl64(v : qword, count : bits(8)) -> bool = {
  let c : range(0, 255) = unsigned(count);
  srl64_orig(v, c) == srl64_new(v, c)
}

// --- Arithmetic right shift ---
// sra16/sra32 currently use shift_right_arith which is:
//   sign_extend('n + shift, value)[('n - 1 + shift) .. shift]
// This is semantically identical to sail_arith_shiftright (bvashr).
// The new code uses sail_arith_shiftright directly.

val sra16_orig : (word, range(0, 255)) -> word
function sra16_orig(v, count) = {
  if count == 0 then v
  else if count > 15 then sail_arith_shiftright(v, 15)
  else sail_arith_shiftright(v, count)
}

val sra16_new : (word, range(0, 255)) -> word
function sra16_new(v, count) = sail_arith_shiftright(v, count)

$property
function prop_sra16(v : word, count : bits(8)) -> bool = {
  let c : range(0, 255) = unsigned(count);
  sra16_orig(v, c) == sra16_new(v, c)
}

val sra32_orig : (dword, range(0, 255)) -> dword
function sra32_orig(v, count) = {
  if count == 0 then v
  else if count > 31 then sail_arith_shiftright(v, 31)
  else sail_arith_shiftright(v, count)
}

val sra32_new : (dword, range(0, 255)) -> dword
function sra32_new(v, count) = sail_arith_shiftright(v, count)

$property
function prop_sra32(v : dword, count : bits(8)) -> bool = {
  let c : range(0, 255) = unsigned(count);
  sra32_orig(v, c) == sra32_new(v, c)
}

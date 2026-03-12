$include "../model/prelude.sail"

type xmmword = bits(128)
type ymmword = bits(256)

// ================================================================
// Full-width proofs: clamped (original) vs branchless (no clamping)
// for arith_shr_words/dwords/qwords
// ================================================================

// --- Words 128b ---

val arith_shr_words_128b_orig : (xmmword, range(0, 255)) -> xmmword
function arith_shr_words_128b_orig(a, count) = {
  let c = if count > 15 then 16 else count;
  sail_arith_shiftright(a[127..112], c) @
  sail_arith_shiftright(a[111..96], c) @
  sail_arith_shiftright(a[95..80], c) @
  sail_arith_shiftright(a[79..64], c) @
  sail_arith_shiftright(a[63..48], c) @
  sail_arith_shiftright(a[47..32], c) @
  sail_arith_shiftright(a[31..16], c) @
  sail_arith_shiftright(a[15..0], c)
}

val arith_shr_words_128b_new : (xmmword, range(0, 255)) -> xmmword
function arith_shr_words_128b_new(a, count) =
  sail_arith_shiftright(a[127..112], count) @
  sail_arith_shiftright(a[111..96], count) @
  sail_arith_shiftright(a[95..80], count) @
  sail_arith_shiftright(a[79..64], count) @
  sail_arith_shiftright(a[63..48], count) @
  sail_arith_shiftright(a[47..32], count) @
  sail_arith_shiftright(a[31..16], count) @
  sail_arith_shiftright(a[15..0], count)

$property
function prop_arith_shr_words_128b(a : xmmword, count : bits(8)) -> bool = {
  let c : range(0, 255) = unsigned(count);
  arith_shr_words_128b_orig(a, c) == arith_shr_words_128b_new(a, c)
}

// --- Dwords 128b ---

val arith_shr_dwords_128b_orig : (xmmword, range(0, 255)) -> xmmword
function arith_shr_dwords_128b_orig(a, count) = {
  let c = if count > 31 then 32 else count;
  sail_arith_shiftright(a[127..96], c) @
  sail_arith_shiftright(a[95..64], c) @
  sail_arith_shiftright(a[63..32], c) @
  sail_arith_shiftright(a[31..0], c)
}

val arith_shr_dwords_128b_new : (xmmword, range(0, 255)) -> xmmword
function arith_shr_dwords_128b_new(a, count) =
  sail_arith_shiftright(a[127..96], count) @
  sail_arith_shiftright(a[95..64], count) @
  sail_arith_shiftright(a[63..32], count) @
  sail_arith_shiftright(a[31..0], count)

$property
function prop_arith_shr_dwords_128b(a : xmmword, count : bits(8)) -> bool = {
  let c : range(0, 255) = unsigned(count);
  arith_shr_dwords_128b_orig(a, c) == arith_shr_dwords_128b_new(a, c)
}

// --- Qwords 128b ---

val arith_shr_qwords_128b_orig : (xmmword, range(0, 255)) -> xmmword
function arith_shr_qwords_128b_orig(a, count) = {
  let c = if count > 63 then 64 else count;
  sail_arith_shiftright(a[127..64], c) @
  sail_arith_shiftright(a[63..0], c)
}

val arith_shr_qwords_128b_new : (xmmword, range(0, 255)) -> xmmword
function arith_shr_qwords_128b_new(a, count) =
  sail_arith_shiftright(a[127..64], count) @
  sail_arith_shiftright(a[63..0], count)

$property
function prop_arith_shr_qwords_128b(a : xmmword, count : bits(8)) -> bool = {
  let c : range(0, 255) = unsigned(count);
  arith_shr_qwords_128b_orig(a, c) == arith_shr_qwords_128b_new(a, c)
}

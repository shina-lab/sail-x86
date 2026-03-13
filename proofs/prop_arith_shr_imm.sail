$include "../model/prelude.sail"

type word    = bits(16)
type dword   = bits(32)

val arith_shr_word_orig : (word, range(0, 255)) -> word
function arith_shr_word_orig(v, count) = {
  if count == 0 then {
    v
  } else if count >= 16 then {
    zeros() - zero_extend(v[15..15])
  } else {
    let shifted : word = v >> count;
    let sign_bit = v[15];
    var r : word = shifted;
    foreach (i from 0 to 14) {
      let bit_idx : range(0, 15) = 15 - i;
      if i < count then r[bit_idx] = sign_bit;
    };
    r
  }
}

val arith_shr_word_new : (word, range(0, 255)) -> word
function arith_shr_word_new(v, count) = sail_arith_shiftright(v, count)

$property
function prop_arith_shr_word(v : word, count : bits(8)) -> bool = {
  let c : range(0, 255) = unsigned(count);
  arith_shr_word_orig(v, c) == arith_shr_word_new(v, c)
}

// ================================================================
// arith_shr_dword
// ================================================================

val arith_shr_dword_orig : (dword, range(0, 255)) -> dword
function arith_shr_dword_orig(v, count) = {
  if count == 0 then {
    v
  } else if count >= 32 then {
    zeros() - zero_extend(v[31..31])
  } else {
    let shifted : dword = v >> count;
    let sign_bit = v[31];
    var r : dword = shifted;
    foreach (i from 0 to 30) {
      let bit_idx : range(0, 31) = 31 - i;
      if i < count then r[bit_idx] = sign_bit;
    };
    r
  }
}

val arith_shr_dword_new : (dword, range(0, 255)) -> dword
function arith_shr_dword_new(v, count) = sail_arith_shiftright(v, count)

$property
function prop_arith_shr_dword(v : dword, count : bits(8)) -> bool = {
  let c : range(0, 255) = unsigned(count);
  arith_shr_dword_orig(v, c) == arith_shr_dword_new(v, c)
}

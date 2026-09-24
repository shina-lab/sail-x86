$include "../model/prelude.sail"

// Check both signs and every 64-bit shift count against a bounded
// sign-extension reference; the large-count case needs no large vector.

$property
function prop_arith_shift_8(v : bits(8), count : bits(64)) -> bool = {
  let wide : bits(16) = sign_extend(v);
  let expected : bits(8) = if unsigned(count) >= 8
    then sign_extend(v[7..7])
    else (wide >> unsigned(count[6..0]))[7..0];
  (v >>> unsigned(count)) == expected
}

$property
function prop_arith_shift_16(v : bits(16), count : bits(64)) -> bool = {
  let wide : bits(32) = sign_extend(v);
  let expected : bits(16) = if unsigned(count) >= 16
    then sign_extend(v[15..15])
    else (wide >> unsigned(count[6..0]))[15..0];
  (v >>> unsigned(count)) == expected
}

$property
function prop_arith_shift_32(v : bits(32), count : bits(64)) -> bool = {
  let wide : bits(64) = sign_extend(v);
  let expected : bits(32) = if unsigned(count) >= 32
    then sign_extend(v[31..31])
    else (wide >> unsigned(count[6..0]))[31..0];
  (v >>> unsigned(count)) == expected
}

$property
function prop_arith_shift_64(v : bits(64), count : bits(64)) -> bool = {
  let wide : bits(128) = sign_extend(v);
  let expected : bits(64) = if unsigned(count) >= 64
    then sign_extend(v[63..63])
    else (wide >> unsigned(count[6..0]))[63..0];
  (v >>> unsigned(count)) == expected
}

$property
function prop_arith_shift_128(v : bits(128), count : bits(64)) -> bool = {
  let wide : bits(256) = sign_extend(v);
  let expected : bits(128) = if unsigned(count) >= 128
    then sign_extend(v[127..127])
    else (wide >> unsigned(count[6..0]))[127..0];
  (v >>> unsigned(count)) == expected
}

$include "../model/prelude.sail"

type byte    = bits(8)
type word    = bits(16)
type dword   = bits(32)
type qword   = bits(64)
type xmmword = bits(128)

// ================================================================
// VPSRLVD 128: variable logical right shift dwords
// Test whether shift_bits_right already gives zeros for count >= 32
// ================================================================

val avx_psrlvd_128_orig : (xmmword, xmmword) -> xmmword
function avx_psrlvd_128_orig(src, cnt) = {
  var r : xmmword = zeros();
  let c0 : bits(32) = cnt[31..0];
  if unsigned(c0) >= 32 then r[31..0] = zeros()
  else r[31..0] = shift_bits_right(src[31..0], c0);
  let c1 : bits(32) = cnt[63..32];
  if unsigned(c1) >= 32 then r[63..32] = zeros()
  else r[63..32] = shift_bits_right(src[63..32], c1);
  let c2 : bits(32) = cnt[95..64];
  if unsigned(c2) >= 32 then r[95..64] = zeros()
  else r[95..64] = shift_bits_right(src[95..64], c2);
  let c3 : bits(32) = cnt[127..96];
  if unsigned(c3) >= 32 then r[127..96] = zeros()
  else r[127..96] = shift_bits_right(src[127..96], c3);
  r
}

val avx_psrlvd_128_new : (xmmword, xmmword) -> xmmword
function avx_psrlvd_128_new(src, cnt) =
  shift_bits_right(src[127..96], cnt[127..96]) @
  shift_bits_right(src[95..64], cnt[95..64]) @
  shift_bits_right(src[63..32], cnt[63..32]) @
  shift_bits_right(src[31..0], cnt[31..0])

$property
function prop_psrlvd_128(src : xmmword, cnt : xmmword) -> bool =
  avx_psrlvd_128_orig(src, cnt) == avx_psrlvd_128_new(src, cnt)

// ================================================================
// VPSRLVQ 128: variable logical right shift qwords
// ================================================================

val avx_psrlvq_128_orig : (xmmword, xmmword) -> xmmword
function avx_psrlvq_128_orig(src, cnt) = {
  var r : xmmword = zeros();
  let c0 : bits(64) = cnt[63..0];
  if unsigned(c0) >= 64 then r[63..0] = zeros()
  else r[63..0] = shift_bits_right(src[63..0], c0);
  let c1 : bits(64) = cnt[127..64];
  if unsigned(c1) >= 64 then r[127..64] = zeros()
  else r[127..64] = shift_bits_right(src[127..64], c1);
  r
}

val avx_psrlvq_128_new : (xmmword, xmmword) -> xmmword
function avx_psrlvq_128_new(src, cnt) =
  shift_bits_right(src[127..64], cnt[127..64]) @
  shift_bits_right(src[63..0], cnt[63..0])

$property
function prop_psrlvq_128(src : xmmword, cnt : xmmword) -> bool =
  avx_psrlvq_128_orig(src, cnt) == avx_psrlvq_128_new(src, cnt)

// ================================================================
// VPSLLVD 128: variable logical left shift dwords
// ================================================================

val avx_psllvd_128_orig : (xmmword, xmmword) -> xmmword
function avx_psllvd_128_orig(src, cnt) = {
  var r : xmmword = zeros();
  let c0 : bits(32) = cnt[31..0];
  if unsigned(c0) >= 32 then r[31..0] = zeros()
  else r[31..0] = shift_bits_left(src[31..0], c0);
  let c1 : bits(32) = cnt[63..32];
  if unsigned(c1) >= 32 then r[63..32] = zeros()
  else r[63..32] = shift_bits_left(src[63..32], c1);
  let c2 : bits(32) = cnt[95..64];
  if unsigned(c2) >= 32 then r[95..64] = zeros()
  else r[95..64] = shift_bits_left(src[95..64], c2);
  let c3 : bits(32) = cnt[127..96];
  if unsigned(c3) >= 32 then r[127..96] = zeros()
  else r[127..96] = shift_bits_left(src[127..96], c3);
  r
}

val avx_psllvd_128_new : (xmmword, xmmword) -> xmmword
function avx_psllvd_128_new(src, cnt) =
  shift_bits_left(src[127..96], cnt[127..96]) @
  shift_bits_left(src[95..64], cnt[95..64]) @
  shift_bits_left(src[63..32], cnt[63..32]) @
  shift_bits_left(src[31..0], cnt[31..0])

$property
function prop_psllvd_128(src : xmmword, cnt : xmmword) -> bool =
  avx_psllvd_128_orig(src, cnt) == avx_psllvd_128_new(src, cnt)

// ================================================================
// VPSLLVQ 128: variable logical left shift qwords
// ================================================================

val avx_psllvq_128_orig : (xmmword, xmmword) -> xmmword
function avx_psllvq_128_orig(src, cnt) = {
  var r : xmmword = zeros();
  let c0 : bits(64) = cnt[63..0];
  if unsigned(c0) >= 64 then r[63..0] = zeros()
  else r[63..0] = shift_bits_left(src[63..0], c0);
  let c1 : bits(64) = cnt[127..64];
  if unsigned(c1) >= 64 then r[127..64] = zeros()
  else r[127..64] = shift_bits_left(src[127..64], c1);
  r
}

val avx_psllvq_128_new : (xmmword, xmmword) -> xmmword
function avx_psllvq_128_new(src, cnt) =
  shift_bits_left(src[127..64], cnt[127..64]) @
  shift_bits_left(src[63..0], cnt[63..0])

$property
function prop_psllvq_128(src : xmmword, cnt : xmmword) -> bool =
  avx_psllvq_128_orig(src, cnt) == avx_psllvq_128_new(src, cnt)

// ================================================================
// VPSRLVW 128: variable logical right shift words
// ================================================================

val avx_psrlvw_128_orig : (xmmword, xmmword) -> xmmword
function avx_psrlvw_128_orig(src, cnt) = {
  var r : xmmword = zeros();
  let c0 : bits(16) = cnt[15..0];
  if unsigned(c0) >= 16 then r[15..0] = zeros()
  else r[15..0] = shift_bits_right(src[15..0], c0);
  let c1 : bits(16) = cnt[31..16];
  if unsigned(c1) >= 16 then r[31..16] = zeros()
  else r[31..16] = shift_bits_right(src[31..16], c1);
  let c2 : bits(16) = cnt[47..32];
  if unsigned(c2) >= 16 then r[47..32] = zeros()
  else r[47..32] = shift_bits_right(src[47..32], c2);
  let c3 : bits(16) = cnt[63..48];
  if unsigned(c3) >= 16 then r[63..48] = zeros()
  else r[63..48] = shift_bits_right(src[63..48], c3);
  let c4 : bits(16) = cnt[79..64];
  if unsigned(c4) >= 16 then r[79..64] = zeros()
  else r[79..64] = shift_bits_right(src[79..64], c4);
  let c5 : bits(16) = cnt[95..80];
  if unsigned(c5) >= 16 then r[95..80] = zeros()
  else r[95..80] = shift_bits_right(src[95..80], c5);
  let c6 : bits(16) = cnt[111..96];
  if unsigned(c6) >= 16 then r[111..96] = zeros()
  else r[111..96] = shift_bits_right(src[111..96], c6);
  let c7 : bits(16) = cnt[127..112];
  if unsigned(c7) >= 16 then r[127..112] = zeros()
  else r[127..112] = shift_bits_right(src[127..112], c7);
  r
}

val avx_psrlvw_128_new : (xmmword, xmmword) -> xmmword
function avx_psrlvw_128_new(src, cnt) =
  shift_bits_right(src[127..112], cnt[127..112]) @
  shift_bits_right(src[111..96], cnt[111..96]) @
  shift_bits_right(src[95..80], cnt[95..80]) @
  shift_bits_right(src[79..64], cnt[79..64]) @
  shift_bits_right(src[63..48], cnt[63..48]) @
  shift_bits_right(src[47..32], cnt[47..32]) @
  shift_bits_right(src[31..16], cnt[31..16]) @
  shift_bits_right(src[15..0], cnt[15..0])

$property
function prop_psrlvw_128(src : xmmword, cnt : xmmword) -> bool =
  avx_psrlvw_128_orig(src, cnt) == avx_psrlvw_128_new(src, cnt)

// ================================================================
// VPSLLVW 128: variable logical left shift words
// ================================================================

val avx_psllvw_128_orig : (xmmword, xmmword) -> xmmword
function avx_psllvw_128_orig(src, cnt) = {
  var r : xmmword = zeros();
  let c0 : bits(16) = cnt[15..0];
  if unsigned(c0) >= 16 then r[15..0] = zeros()
  else r[15..0] = shift_bits_left(src[15..0], c0);
  let c1 : bits(16) = cnt[31..16];
  if unsigned(c1) >= 16 then r[31..16] = zeros()
  else r[31..16] = shift_bits_left(src[31..16], c1);
  let c2 : bits(16) = cnt[47..32];
  if unsigned(c2) >= 16 then r[47..32] = zeros()
  else r[47..32] = shift_bits_left(src[47..32], c2);
  let c3 : bits(16) = cnt[63..48];
  if unsigned(c3) >= 16 then r[63..48] = zeros()
  else r[63..48] = shift_bits_left(src[63..48], c3);
  let c4 : bits(16) = cnt[79..64];
  if unsigned(c4) >= 16 then r[79..64] = zeros()
  else r[79..64] = shift_bits_left(src[79..64], c4);
  let c5 : bits(16) = cnt[95..80];
  if unsigned(c5) >= 16 then r[95..80] = zeros()
  else r[95..80] = shift_bits_left(src[95..80], c5);
  let c6 : bits(16) = cnt[111..96];
  if unsigned(c6) >= 16 then r[111..96] = zeros()
  else r[111..96] = shift_bits_left(src[111..96], c6);
  let c7 : bits(16) = cnt[127..112];
  if unsigned(c7) >= 16 then r[127..112] = zeros()
  else r[127..112] = shift_bits_left(src[127..112], c7);
  r
}

val avx_psllvw_128_new : (xmmword, xmmword) -> xmmword
function avx_psllvw_128_new(src, cnt) =
  shift_bits_left(src[127..112], cnt[127..112]) @
  shift_bits_left(src[111..96], cnt[111..96]) @
  shift_bits_left(src[95..80], cnt[95..80]) @
  shift_bits_left(src[79..64], cnt[79..64]) @
  shift_bits_left(src[63..48], cnt[63..48]) @
  shift_bits_left(src[47..32], cnt[47..32]) @
  shift_bits_left(src[31..16], cnt[31..16]) @
  shift_bits_left(src[15..0], cnt[15..0])

$property
function prop_psllvw_128(src : xmmword, cnt : xmmword) -> bool =
  avx_psllvw_128_orig(src, cnt) == avx_psllvw_128_new(src, cnt)

// ================================================================
// VPSRAVD 128: variable arithmetic right shift dwords
// sail_arith_shiftright handles overflow (sign-fills when count >= N)
// ================================================================

val avx_psravd_128_orig : (xmmword, xmmword) -> xmmword
function avx_psravd_128_orig(src, cnt) = {
  var r : xmmword = zeros();
  let c0 : range(0, 4294967295) = unsigned(cnt[31..0]);
  let elem0 : bits(32) = src[31..0];
  if c0 >= 32 then {
    if elem0[31] == bitone then r[31..0] = ones()
    else r[31..0] = zeros()
  } else {
    let shift_amt : range(0, 31) = c0;
    r[31..0] = sail_arith_shiftright(elem0, shift_amt);
  };
  let c1 : range(0, 4294967295) = unsigned(cnt[63..32]);
  let elem1 : bits(32) = src[63..32];
  if c1 >= 32 then {
    if elem1[31] == bitone then r[63..32] = ones()
    else r[63..32] = zeros()
  } else {
    let shift_amt : range(0, 31) = c1;
    r[63..32] = sail_arith_shiftright(elem1, shift_amt);
  };
  let c2 : range(0, 4294967295) = unsigned(cnt[95..64]);
  let elem2 : bits(32) = src[95..64];
  if c2 >= 32 then {
    if elem2[31] == bitone then r[95..64] = ones()
    else r[95..64] = zeros()
  } else {
    let shift_amt : range(0, 31) = c2;
    r[95..64] = sail_arith_shiftright(elem2, shift_amt);
  };
  let c3 : range(0, 4294967295) = unsigned(cnt[127..96]);
  let elem3 : bits(32) = src[127..96];
  if c3 >= 32 then {
    if elem3[31] == bitone then r[127..96] = ones()
    else r[127..96] = zeros()
  } else {
    let shift_amt : range(0, 31) = c3;
    r[127..96] = sail_arith_shiftright(elem3, shift_amt);
  };
  r
}

val avx_psravd_128_new : (xmmword, xmmword) -> xmmword
function avx_psravd_128_new(src, cnt) =
  sail_arith_shiftright(src[127..96], unsigned(cnt[127..96])) @
  sail_arith_shiftright(src[95..64], unsigned(cnt[95..64])) @
  sail_arith_shiftright(src[63..32], unsigned(cnt[63..32])) @
  sail_arith_shiftright(src[31..0], unsigned(cnt[31..0]))

$property
function prop_psravd_128(src : xmmword, cnt : xmmword) -> bool =
  avx_psravd_128_orig(src, cnt) == avx_psravd_128_new(src, cnt)

// ================================================================
// VPSRAVQ 128: variable arithmetic right shift qwords
// ================================================================

val avx_psravq_128_orig : (xmmword, xmmword) -> xmmword
function avx_psravq_128_orig(src, cnt) = {
  var r : xmmword = zeros();
  let c0 = unsigned(cnt[63..0]);
  let elem0 : bits(64) = src[63..0];
  if c0 >= 64 then {
    if elem0[63] == bitone then r[63..0] = ones()
    else r[63..0] = zeros()
  } else {
    let shift_amt : range(0, 63) = c0;
    r[63..0] = sail_arith_shiftright(elem0, shift_amt);
  };
  let c1 = unsigned(cnt[127..64]);
  let elem1 : bits(64) = src[127..64];
  if c1 >= 64 then {
    if elem1[63] == bitone then r[127..64] = ones()
    else r[127..64] = zeros()
  } else {
    let shift_amt : range(0, 63) = c1;
    r[127..64] = sail_arith_shiftright(elem1, shift_amt);
  };
  r
}

val avx_psravq_128_new : (xmmword, xmmword) -> xmmword
function avx_psravq_128_new(src, cnt) =
  sail_arith_shiftright(src[127..64], unsigned(cnt[127..64])) @
  sail_arith_shiftright(src[63..0], unsigned(cnt[63..0]))

$property
function prop_psravq_128(src : xmmword, cnt : xmmword) -> bool =
  avx_psravq_128_orig(src, cnt) == avx_psravq_128_new(src, cnt)

// ================================================================
// VPSRAVW 128: variable arithmetic right shift words
// ================================================================

val avx_psravw_128_orig : (xmmword, xmmword) -> xmmword
function avx_psravw_128_orig(src, cnt) = {
  var r : xmmword = zeros();
  let c0 : range(0, 65535) = unsigned(cnt[15..0]);
  let elem0 : bits(16) = src[15..0];
  if c0 >= 16 then {
    if elem0[15] == bitone then r[15..0] = ones()
    else r[15..0] = zeros()
  } else {
    let shift_amt : range(0, 15) = c0;
    r[15..0] = sail_arith_shiftright(elem0, shift_amt);
  };
  let c1 : range(0, 65535) = unsigned(cnt[31..16]);
  let elem1 : bits(16) = src[31..16];
  if c1 >= 16 then {
    if elem1[15] == bitone then r[31..16] = ones()
    else r[31..16] = zeros()
  } else {
    let shift_amt : range(0, 15) = c1;
    r[31..16] = sail_arith_shiftright(elem1, shift_amt);
  };
  let c2 : range(0, 65535) = unsigned(cnt[47..32]);
  let elem2 : bits(16) = src[47..32];
  if c2 >= 16 then {
    if elem2[15] == bitone then r[47..32] = ones()
    else r[47..32] = zeros()
  } else {
    let shift_amt : range(0, 15) = c2;
    r[47..32] = sail_arith_shiftright(elem2, shift_amt);
  };
  let c3 : range(0, 65535) = unsigned(cnt[63..48]);
  let elem3 : bits(16) = src[63..48];
  if c3 >= 16 then {
    if elem3[15] == bitone then r[63..48] = ones()
    else r[63..48] = zeros()
  } else {
    let shift_amt : range(0, 15) = c3;
    r[63..48] = sail_arith_shiftright(elem3, shift_amt);
  };
  let c4 : range(0, 65535) = unsigned(cnt[79..64]);
  let elem4 : bits(16) = src[79..64];
  if c4 >= 16 then {
    if elem4[15] == bitone then r[79..64] = ones()
    else r[79..64] = zeros()
  } else {
    let shift_amt : range(0, 15) = c4;
    r[79..64] = sail_arith_shiftright(elem4, shift_amt);
  };
  let c5 : range(0, 65535) = unsigned(cnt[95..80]);
  let elem5 : bits(16) = src[95..80];
  if c5 >= 16 then {
    if elem5[15] == bitone then r[95..80] = ones()
    else r[95..80] = zeros()
  } else {
    let shift_amt : range(0, 15) = c5;
    r[95..80] = sail_arith_shiftright(elem5, shift_amt);
  };
  let c6 : range(0, 65535) = unsigned(cnt[111..96]);
  let elem6 : bits(16) = src[111..96];
  if c6 >= 16 then {
    if elem6[15] == bitone then r[111..96] = ones()
    else r[111..96] = zeros()
  } else {
    let shift_amt : range(0, 15) = c6;
    r[111..96] = sail_arith_shiftright(elem6, shift_amt);
  };
  let c7 : range(0, 65535) = unsigned(cnt[127..112]);
  let elem7 : bits(16) = src[127..112];
  if c7 >= 16 then {
    if elem7[15] == bitone then r[127..112] = ones()
    else r[127..112] = zeros()
  } else {
    let shift_amt : range(0, 15) = c7;
    r[127..112] = sail_arith_shiftright(elem7, shift_amt);
  };
  r
}

val avx_psravw_128_new : (xmmword, xmmword) -> xmmword
function avx_psravw_128_new(src, cnt) =
  sail_arith_shiftright(src[127..112], unsigned(cnt[127..112])) @
  sail_arith_shiftright(src[111..96], unsigned(cnt[111..96])) @
  sail_arith_shiftright(src[95..80], unsigned(cnt[95..80])) @
  sail_arith_shiftright(src[79..64], unsigned(cnt[79..64])) @
  sail_arith_shiftright(src[63..48], unsigned(cnt[63..48])) @
  sail_arith_shiftright(src[47..32], unsigned(cnt[47..32])) @
  sail_arith_shiftright(src[31..16], unsigned(cnt[31..16])) @
  sail_arith_shiftright(src[15..0], unsigned(cnt[15..0]))

$property
function prop_psravw_128(src : xmmword, cnt : xmmword) -> bool =
  avx_psravw_128_orig(src, cnt) == avx_psravw_128_new(src, cnt)

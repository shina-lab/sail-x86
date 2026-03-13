$include "../model/prelude.sail"

type xmmword = bits(128)

// Prove: avx_psraw_xmm_128 with clamp_shift_count
//     == direct sail_arith_shiftright(elem, unsigned(count_xmm[63..0]))

val avx_psraw_xmm_128_orig : (xmmword, xmmword) -> xmmword
function avx_psraw_xmm_128_orig(a, count_xmm) = {
  let raw = unsigned(count_xmm[63..0]);
  let count : range(0, 255) = if raw > 255 then 255 else if raw < 0 then 0 else raw;
  sail_arith_shiftright(a[127..112], count) @
  sail_arith_shiftright(a[111..96], count) @
  sail_arith_shiftright(a[95..80], count) @
  sail_arith_shiftright(a[79..64], count) @
  sail_arith_shiftright(a[63..48], count) @
  sail_arith_shiftright(a[47..32], count) @
  sail_arith_shiftright(a[31..16], count) @
  sail_arith_shiftright(a[15..0], count)
}

val avx_psraw_xmm_128_new : (xmmword, xmmword) -> xmmword
function avx_psraw_xmm_128_new(a, count_xmm) = {
  let count = unsigned(count_xmm[63..0]);
  sail_arith_shiftright(a[127..112], count) @
  sail_arith_shiftright(a[111..96], count) @
  sail_arith_shiftright(a[95..80], count) @
  sail_arith_shiftright(a[79..64], count) @
  sail_arith_shiftright(a[63..48], count) @
  sail_arith_shiftright(a[47..32], count) @
  sail_arith_shiftright(a[31..16], count) @
  sail_arith_shiftright(a[15..0], count)
}

$property
function prop_psraw_xmm_128(a : xmmword, count_xmm : xmmword) -> bool =
  avx_psraw_xmm_128_orig(a, count_xmm) == avx_psraw_xmm_128_new(a, count_xmm)

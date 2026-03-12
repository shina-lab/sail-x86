$include "../model/prelude.sail"

type byte    = bits(8)
type word    = bits(16)
type dword   = bits(32)
type qword   = bits(64)
type xmmword = bits(128)
type ymmword = bits(256)

val blend32 : (dword, dword, bits(1)) -> dword
function blend32(a, b, sel) = { let m : bits(32) = sign_extend(sel); (a & ~(m)) | (b & m) }

val blend64 : (qword, qword, bits(1)) -> qword
function blend64(a, b, sel) = { let m : bits(64) = sign_extend(sel); (a & ~(m)) | (b & m) }

// ================================================================
// vex_maskmovps_load_128: if MSB(mask_lane) then data else 0
// ================================================================

val vex_maskmovps_load_128_orig : (xmmword, xmmword) -> xmmword
function vex_maskmovps_load_128_orig(mask, data) = {
  var result : xmmword = zeros();
  if mask[31]  == bitone then result[31..0]   = data[31..0];
  if mask[63]  == bitone then result[63..32]  = data[63..32];
  if mask[95]  == bitone then result[95..64]  = data[95..64];
  if mask[127] == bitone then result[127..96] = data[127..96];
  result
}

val vex_maskmovps_load_128_new : (xmmword, xmmword) -> xmmword
function vex_maskmovps_load_128_new(mask, data) =
  blend32(0x00000000, data[127..96], mask[127..127]) @
  blend32(0x00000000, data[95..64],  mask[95..95]) @
  blend32(0x00000000, data[63..32],  mask[63..63]) @
  blend32(0x00000000, data[31..0],   mask[31..31])

$property
function prop_maskmovps_128(mask : xmmword, data : xmmword) -> bool =
  vex_maskmovps_load_128_orig(mask, data) == vex_maskmovps_load_128_new(mask, data)

// ================================================================
// vex_maskmovpd_load_128: 2 × 64-bit
// ================================================================

val vex_maskmovpd_load_128_orig : (xmmword, xmmword) -> xmmword
function vex_maskmovpd_load_128_orig(mask, data) = {
  var result : xmmword = zeros();
  if mask[63]  == bitone then result[63..0]   = data[63..0];
  if mask[127] == bitone then result[127..64] = data[127..64];
  result
}

val vex_maskmovpd_load_128_new : (xmmword, xmmword) -> xmmword
function vex_maskmovpd_load_128_new(mask, data) =
  blend64(0x0000000000000000, data[127..64], mask[127..127]) @
  blend64(0x0000000000000000, data[63..0],   mask[63..63])

$property
function prop_maskmovpd_128(mask : xmmword, data : xmmword) -> bool =
  vex_maskmovpd_load_128_orig(mask, data) == vex_maskmovpd_load_128_new(mask, data)

// ================================================================
// avx_vpermilpd_128: select qwords based on control bits
// ================================================================

val avx_vpermilpd_128_orig : (xmmword, xmmword) -> xmmword
function avx_vpermilpd_128_orig(src, ctrl) = {
  let lo : bits(64) = if ctrl[1] == bitone then src[127..64] else src[63..0];
  let hi : bits(64) = if ctrl[65] == bitone then src[127..64] else src[63..0];
  hi @ lo
}

val avx_vpermilpd_128_new : (xmmword, xmmword) -> xmmword
function avx_vpermilpd_128_new(src, ctrl) = {
  let lo : bits(64) = blend64(src[63..0], src[127..64], ctrl[1..1]);
  let hi : bits(64) = blend64(src[63..0], src[127..64], ctrl[65..65]);
  hi @ lo
}

$property
function prop_vpermilpd_128(src : xmmword, ctrl : xmmword) -> bool =
  avx_vpermilpd_128_orig(src, ctrl) == avx_vpermilpd_128_new(src, ctrl)

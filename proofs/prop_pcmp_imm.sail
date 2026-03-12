$include "../model/prelude.sail"

type byte    = bits(8)
type word    = bits(16)
type dword   = bits(32)
type qword   = bits(64)
type xmmword = bits(128)

// ================================================================
// Predicate functions (copied from model)
// ================================================================

val cmp_ud_pred : (dword, dword, range(0, 7)) -> bool
function cmp_ud_pred(a, b, pred) = match pred {
  0 => unsigned(a) == unsigned(b),
  1 => unsigned(a) < unsigned(b),
  2 => unsigned(a) <= unsigned(b),
  3 => false,
  4 => unsigned(a) != unsigned(b),
  5 => unsigned(a) >= unsigned(b),
  6 => unsigned(a) > unsigned(b),
  _ => true,
}

val cmp_sd_pred : (dword, dword, range(0, 7)) -> bool
function cmp_sd_pred(a, b, pred) = match pred {
  0 => signed(a) == signed(b),
  1 => signed(a) < signed(b),
  2 => signed(a) <= signed(b),
  3 => false,
  4 => signed(a) != signed(b),
  5 => signed(a) >= signed(b),
  6 => signed(a) > signed(b),
  _ => true,
}

val cmp_uq_pred : (qword, qword, range(0, 7)) -> bool
function cmp_uq_pred(a, b, pred) = match pred {
  0 => unsigned(a) == unsigned(b),
  1 => unsigned(a) < unsigned(b),
  2 => unsigned(a) <= unsigned(b),
  3 => false,
  4 => unsigned(a) != unsigned(b),
  5 => unsigned(a) >= unsigned(b),
  6 => unsigned(a) > unsigned(b),
  _ => true,
}

val cmp_sq_pred : (qword, qword, range(0, 7)) -> bool
function cmp_sq_pred(a, b, pred) = match pred {
  0 => signed(a) == signed(b),
  1 => signed(a) < signed(b),
  2 => signed(a) <= signed(b),
  3 => false,
  4 => signed(a) != signed(b),
  5 => signed(a) >= signed(b),
  6 => signed(a) > signed(b),
  _ => true,
}

val cmp_uw_pred : (word, word, range(0, 7)) -> bool
function cmp_uw_pred(a, b, pred) = match pred {
  0 => unsigned(a) == unsigned(b),
  1 => unsigned(a) < unsigned(b),
  2 => unsigned(a) <= unsigned(b),
  3 => false,
  4 => unsigned(a) != unsigned(b),
  5 => unsigned(a) >= unsigned(b),
  6 => unsigned(a) > unsigned(b),
  _ => true,
}

val cmp_sw_pred : (word, word, range(0, 7)) -> bool
function cmp_sw_pred(a, b, pred) = match pred {
  0 => signed(a) == signed(b),
  1 => signed(a) < signed(b),
  2 => signed(a) <= signed(b),
  3 => false,
  4 => signed(a) != signed(b),
  5 => signed(a) >= signed(b),
  6 => signed(a) > signed(b),
  _ => true,
}

val cmp_ub_pred : (byte, byte, range(0, 7)) -> bool
function cmp_ub_pred(a, b, pred) = match pred {
  0 => unsigned(a) == unsigned(b),
  1 => unsigned(a) < unsigned(b),
  2 => unsigned(a) <= unsigned(b),
  3 => false,
  4 => unsigned(a) != unsigned(b),
  5 => unsigned(a) >= unsigned(b),
  6 => unsigned(a) > unsigned(b),
  _ => true,
}

val cmp_sb_pred : (byte, byte, range(0, 7)) -> bool
function cmp_sb_pred(a, b, pred) = match pred {
  0 => signed(a) == signed(b),
  1 => signed(a) < signed(b),
  2 => signed(a) <= signed(b),
  3 => false,
  4 => signed(a) != signed(b),
  5 => signed(a) >= signed(b),
  6 => signed(a) > signed(b),
  _ => true,
}

// ================================================================
// VPCMPUD 128: unsigned dword compare → 4-bit mask in byte
// ================================================================

val avx_pcmpud_128_orig : (xmmword, xmmword, range(0, 7)) -> byte
function avx_pcmpud_128_orig(a, b, pred) = {
  var r : byte = zeros();
  if cmp_ud_pred(a[31..0], b[31..0], pred) then r[0] = bitone;
  if cmp_ud_pred(a[63..32], b[63..32], pred) then r[1] = bitone;
  if cmp_ud_pred(a[95..64], b[95..64], pred) then r[2] = bitone;
  if cmp_ud_pred(a[127..96], b[127..96], pred) then r[3] = bitone;
  r
}

val avx_pcmpud_128_new : (xmmword, xmmword, range(0, 7)) -> byte
function avx_pcmpud_128_new(a, b, pred) = {
  let r : bits(4) =
    bool_to_bit(cmp_ud_pred(a[127..96], b[127..96], pred)) @
    bool_to_bit(cmp_ud_pred(a[95..64], b[95..64], pred)) @
    bool_to_bit(cmp_ud_pred(a[63..32], b[63..32], pred)) @
    bool_to_bit(cmp_ud_pred(a[31..0], b[31..0], pred));
  zero_extend(r)
}

$property
function prop_pcmpud_128(a : xmmword, b : xmmword, pred : bits(3)) -> bool = {
  let p : range(0, 7) = unsigned(pred);
  avx_pcmpud_128_orig(a, b, p) == avx_pcmpud_128_new(a, b, p)
}

// ================================================================
// VPCMPD 128: signed dword compare → 4-bit mask in byte
// ================================================================

val avx_pcmpd_128_orig : (xmmword, xmmword, range(0, 7)) -> byte
function avx_pcmpd_128_orig(a, b, pred) = {
  var r : byte = zeros();
  if cmp_sd_pred(a[31..0], b[31..0], pred) then r[0] = bitone;
  if cmp_sd_pred(a[63..32], b[63..32], pred) then r[1] = bitone;
  if cmp_sd_pred(a[95..64], b[95..64], pred) then r[2] = bitone;
  if cmp_sd_pred(a[127..96], b[127..96], pred) then r[3] = bitone;
  r
}

val avx_pcmpd_128_new : (xmmword, xmmword, range(0, 7)) -> byte
function avx_pcmpd_128_new(a, b, pred) = {
  let r : bits(4) =
    bool_to_bit(cmp_sd_pred(a[127..96], b[127..96], pred)) @
    bool_to_bit(cmp_sd_pred(a[95..64], b[95..64], pred)) @
    bool_to_bit(cmp_sd_pred(a[63..32], b[63..32], pred)) @
    bool_to_bit(cmp_sd_pred(a[31..0], b[31..0], pred));
  zero_extend(r)
}

$property
function prop_pcmpd_128(a : xmmword, b : xmmword, pred : bits(3)) -> bool = {
  let p : range(0, 7) = unsigned(pred);
  avx_pcmpd_128_orig(a, b, p) == avx_pcmpd_128_new(a, b, p)
}

// ================================================================
// VPCMPUQ 128: unsigned qword compare → 2-bit mask in byte
// ================================================================

val avx_pcmpuq_128_orig : (xmmword, xmmword, range(0, 7)) -> byte
function avx_pcmpuq_128_orig(a, b, pred) = {
  var r : byte = zeros();
  if cmp_uq_pred(a[63..0], b[63..0], pred) then r[0] = bitone;
  if cmp_uq_pred(a[127..64], b[127..64], pred) then r[1] = bitone;
  r
}

val avx_pcmpuq_128_new : (xmmword, xmmword, range(0, 7)) -> byte
function avx_pcmpuq_128_new(a, b, pred) = {
  let r : bits(2) =
    bool_to_bit(cmp_uq_pred(a[127..64], b[127..64], pred)) @
    bool_to_bit(cmp_uq_pred(a[63..0], b[63..0], pred));
  zero_extend(r)
}

$property
function prop_pcmpuq_128(a : xmmword, b : xmmword, pred : bits(3)) -> bool = {
  let p : range(0, 7) = unsigned(pred);
  avx_pcmpuq_128_orig(a, b, p) == avx_pcmpuq_128_new(a, b, p)
}

// ================================================================
// VPCMPQ 128: signed qword compare → 2-bit mask in byte
// ================================================================

val avx_pcmpq_128_orig : (xmmword, xmmword, range(0, 7)) -> byte
function avx_pcmpq_128_orig(a, b, pred) = {
  var r : byte = zeros();
  if cmp_sq_pred(a[63..0], b[63..0], pred) then r[0] = bitone;
  if cmp_sq_pred(a[127..64], b[127..64], pred) then r[1] = bitone;
  r
}

val avx_pcmpq_128_new : (xmmword, xmmword, range(0, 7)) -> byte
function avx_pcmpq_128_new(a, b, pred) = {
  let r : bits(2) =
    bool_to_bit(cmp_sq_pred(a[127..64], b[127..64], pred)) @
    bool_to_bit(cmp_sq_pred(a[63..0], b[63..0], pred));
  zero_extend(r)
}

$property
function prop_pcmpq_128(a : xmmword, b : xmmword, pred : bits(3)) -> bool = {
  let p : range(0, 7) = unsigned(pred);
  avx_pcmpq_128_orig(a, b, p) == avx_pcmpq_128_new(a, b, p)
}

// ================================================================
// VPCMPUW 128: unsigned word compare → 8-bit mask
// ================================================================

val avx_pcmpuw_128_orig : (xmmword, xmmword, range(0, 7)) -> byte
function avx_pcmpuw_128_orig(a, b, pred) = {
  var r : byte = zeros();
  if cmp_uw_pred(a[15..0], b[15..0], pred) then r[0] = bitone;
  if cmp_uw_pred(a[31..16], b[31..16], pred) then r[1] = bitone;
  if cmp_uw_pred(a[47..32], b[47..32], pred) then r[2] = bitone;
  if cmp_uw_pred(a[63..48], b[63..48], pred) then r[3] = bitone;
  if cmp_uw_pred(a[79..64], b[79..64], pred) then r[4] = bitone;
  if cmp_uw_pred(a[95..80], b[95..80], pred) then r[5] = bitone;
  if cmp_uw_pred(a[111..96], b[111..96], pred) then r[6] = bitone;
  if cmp_uw_pred(a[127..112], b[127..112], pred) then r[7] = bitone;
  r
}

val avx_pcmpuw_128_new : (xmmword, xmmword, range(0, 7)) -> byte
function avx_pcmpuw_128_new(a, b, pred) =
  bool_to_bit(cmp_uw_pred(a[127..112], b[127..112], pred)) @
  bool_to_bit(cmp_uw_pred(a[111..96], b[111..96], pred)) @
  bool_to_bit(cmp_uw_pred(a[95..80], b[95..80], pred)) @
  bool_to_bit(cmp_uw_pred(a[79..64], b[79..64], pred)) @
  bool_to_bit(cmp_uw_pred(a[63..48], b[63..48], pred)) @
  bool_to_bit(cmp_uw_pred(a[47..32], b[47..32], pred)) @
  bool_to_bit(cmp_uw_pred(a[31..16], b[31..16], pred)) @
  bool_to_bit(cmp_uw_pred(a[15..0], b[15..0], pred))

$property
function prop_pcmpuw_128(a : xmmword, b : xmmword, pred : bits(3)) -> bool = {
  let p : range(0, 7) = unsigned(pred);
  avx_pcmpuw_128_orig(a, b, p) == avx_pcmpuw_128_new(a, b, p)
}

// ================================================================
// VPCMPW 128: signed word compare → 8-bit mask
// ================================================================

val avx_pcmpw_128_orig : (xmmword, xmmword, range(0, 7)) -> byte
function avx_pcmpw_128_orig(a, b, pred) = {
  var r : byte = zeros();
  if cmp_sw_pred(a[15..0], b[15..0], pred) then r[0] = bitone;
  if cmp_sw_pred(a[31..16], b[31..16], pred) then r[1] = bitone;
  if cmp_sw_pred(a[47..32], b[47..32], pred) then r[2] = bitone;
  if cmp_sw_pred(a[63..48], b[63..48], pred) then r[3] = bitone;
  if cmp_sw_pred(a[79..64], b[79..64], pred) then r[4] = bitone;
  if cmp_sw_pred(a[95..80], b[95..80], pred) then r[5] = bitone;
  if cmp_sw_pred(a[111..96], b[111..96], pred) then r[6] = bitone;
  if cmp_sw_pred(a[127..112], b[127..112], pred) then r[7] = bitone;
  r
}

val avx_pcmpw_128_new : (xmmword, xmmword, range(0, 7)) -> byte
function avx_pcmpw_128_new(a, b, pred) =
  bool_to_bit(cmp_sw_pred(a[127..112], b[127..112], pred)) @
  bool_to_bit(cmp_sw_pred(a[111..96], b[111..96], pred)) @
  bool_to_bit(cmp_sw_pred(a[95..80], b[95..80], pred)) @
  bool_to_bit(cmp_sw_pred(a[79..64], b[79..64], pred)) @
  bool_to_bit(cmp_sw_pred(a[63..48], b[63..48], pred)) @
  bool_to_bit(cmp_sw_pred(a[47..32], b[47..32], pred)) @
  bool_to_bit(cmp_sw_pred(a[31..16], b[31..16], pred)) @
  bool_to_bit(cmp_sw_pred(a[15..0], b[15..0], pred))

$property
function prop_pcmpw_128(a : xmmword, b : xmmword, pred : bits(3)) -> bool = {
  let p : range(0, 7) = unsigned(pred);
  avx_pcmpw_128_orig(a, b, p) == avx_pcmpw_128_new(a, b, p)
}

// ================================================================
// VPCMPUB 128: unsigned byte compare → 16-bit mask
// ================================================================

val avx_pcmpub_128_orig : (xmmword, xmmword, range(0, 7)) -> word
function avx_pcmpub_128_orig(a, b, pred) = {
  var r : word = zeros();
  if cmp_ub_pred(a[7..0], b[7..0], pred) then r[0] = bitone;
  if cmp_ub_pred(a[15..8], b[15..8], pred) then r[1] = bitone;
  if cmp_ub_pred(a[23..16], b[23..16], pred) then r[2] = bitone;
  if cmp_ub_pred(a[31..24], b[31..24], pred) then r[3] = bitone;
  if cmp_ub_pred(a[39..32], b[39..32], pred) then r[4] = bitone;
  if cmp_ub_pred(a[47..40], b[47..40], pred) then r[5] = bitone;
  if cmp_ub_pred(a[55..48], b[55..48], pred) then r[6] = bitone;
  if cmp_ub_pred(a[63..56], b[63..56], pred) then r[7] = bitone;
  if cmp_ub_pred(a[71..64], b[71..64], pred) then r[8] = bitone;
  if cmp_ub_pred(a[79..72], b[79..72], pred) then r[9] = bitone;
  if cmp_ub_pred(a[87..80], b[87..80], pred) then r[10] = bitone;
  if cmp_ub_pred(a[95..88], b[95..88], pred) then r[11] = bitone;
  if cmp_ub_pred(a[103..96], b[103..96], pred) then r[12] = bitone;
  if cmp_ub_pred(a[111..104], b[111..104], pred) then r[13] = bitone;
  if cmp_ub_pred(a[119..112], b[119..112], pred) then r[14] = bitone;
  if cmp_ub_pred(a[127..120], b[127..120], pred) then r[15] = bitone;
  r
}

val avx_pcmpub_128_new : (xmmword, xmmword, range(0, 7)) -> word
function avx_pcmpub_128_new(a, b, pred) =
  bool_to_bit(cmp_ub_pred(a[127..120], b[127..120], pred)) @
  bool_to_bit(cmp_ub_pred(a[119..112], b[119..112], pred)) @
  bool_to_bit(cmp_ub_pred(a[111..104], b[111..104], pred)) @
  bool_to_bit(cmp_ub_pred(a[103..96], b[103..96], pred)) @
  bool_to_bit(cmp_ub_pred(a[95..88], b[95..88], pred)) @
  bool_to_bit(cmp_ub_pred(a[87..80], b[87..80], pred)) @
  bool_to_bit(cmp_ub_pred(a[79..72], b[79..72], pred)) @
  bool_to_bit(cmp_ub_pred(a[71..64], b[71..64], pred)) @
  bool_to_bit(cmp_ub_pred(a[63..56], b[63..56], pred)) @
  bool_to_bit(cmp_ub_pred(a[55..48], b[55..48], pred)) @
  bool_to_bit(cmp_ub_pred(a[47..40], b[47..40], pred)) @
  bool_to_bit(cmp_ub_pred(a[39..32], b[39..32], pred)) @
  bool_to_bit(cmp_ub_pred(a[31..24], b[31..24], pred)) @
  bool_to_bit(cmp_ub_pred(a[23..16], b[23..16], pred)) @
  bool_to_bit(cmp_ub_pred(a[15..8], b[15..8], pred)) @
  bool_to_bit(cmp_ub_pred(a[7..0], b[7..0], pred))

$property
function prop_pcmpub_128(a : xmmword, b : xmmword, pred : bits(3)) -> bool = {
  let p : range(0, 7) = unsigned(pred);
  avx_pcmpub_128_orig(a, b, p) == avx_pcmpub_128_new(a, b, p)
}

// ================================================================
// VPCMPB 128: signed byte compare → 16-bit mask
// ================================================================

val avx_pcmpb_128_orig : (xmmword, xmmword, range(0, 7)) -> word
function avx_pcmpb_128_orig(a, b, pred) = {
  var r : word = zeros();
  if cmp_sb_pred(a[7..0], b[7..0], pred) then r[0] = bitone;
  if cmp_sb_pred(a[15..8], b[15..8], pred) then r[1] = bitone;
  if cmp_sb_pred(a[23..16], b[23..16], pred) then r[2] = bitone;
  if cmp_sb_pred(a[31..24], b[31..24], pred) then r[3] = bitone;
  if cmp_sb_pred(a[39..32], b[39..32], pred) then r[4] = bitone;
  if cmp_sb_pred(a[47..40], b[47..40], pred) then r[5] = bitone;
  if cmp_sb_pred(a[55..48], b[55..48], pred) then r[6] = bitone;
  if cmp_sb_pred(a[63..56], b[63..56], pred) then r[7] = bitone;
  if cmp_sb_pred(a[71..64], b[71..64], pred) then r[8] = bitone;
  if cmp_sb_pred(a[79..72], b[79..72], pred) then r[9] = bitone;
  if cmp_sb_pred(a[87..80], b[87..80], pred) then r[10] = bitone;
  if cmp_sb_pred(a[95..88], b[95..88], pred) then r[11] = bitone;
  if cmp_sb_pred(a[103..96], b[103..96], pred) then r[12] = bitone;
  if cmp_sb_pred(a[111..104], b[111..104], pred) then r[13] = bitone;
  if cmp_sb_pred(a[119..112], b[119..112], pred) then r[14] = bitone;
  if cmp_sb_pred(a[127..120], b[127..120], pred) then r[15] = bitone;
  r
}

val avx_pcmpb_128_new : (xmmword, xmmword, range(0, 7)) -> word
function avx_pcmpb_128_new(a, b, pred) =
  bool_to_bit(cmp_sb_pred(a[127..120], b[127..120], pred)) @
  bool_to_bit(cmp_sb_pred(a[119..112], b[119..112], pred)) @
  bool_to_bit(cmp_sb_pred(a[111..104], b[111..104], pred)) @
  bool_to_bit(cmp_sb_pred(a[103..96], b[103..96], pred)) @
  bool_to_bit(cmp_sb_pred(a[95..88], b[95..88], pred)) @
  bool_to_bit(cmp_sb_pred(a[87..80], b[87..80], pred)) @
  bool_to_bit(cmp_sb_pred(a[79..72], b[79..72], pred)) @
  bool_to_bit(cmp_sb_pred(a[71..64], b[71..64], pred)) @
  bool_to_bit(cmp_sb_pred(a[63..56], b[63..56], pred)) @
  bool_to_bit(cmp_sb_pred(a[55..48], b[55..48], pred)) @
  bool_to_bit(cmp_sb_pred(a[47..40], b[47..40], pred)) @
  bool_to_bit(cmp_sb_pred(a[39..32], b[39..32], pred)) @
  bool_to_bit(cmp_sb_pred(a[31..24], b[31..24], pred)) @
  bool_to_bit(cmp_sb_pred(a[23..16], b[23..16], pred)) @
  bool_to_bit(cmp_sb_pred(a[15..8], b[15..8], pred)) @
  bool_to_bit(cmp_sb_pred(a[7..0], b[7..0], pred))

$property
function prop_pcmpb_128(a : xmmword, b : xmmword, pred : bits(3)) -> bool = {
  let p : range(0, 7) = unsigned(pred);
  avx_pcmpb_128_orig(a, b, p) == avx_pcmpb_128_new(a, b, p)
}

// x86-64 — EVEX Immediate Operations (0F3A map)
//
// Insert/extract, permute-imm, ternlog, round, compare-imm,
// classify, shift-imm, GFNI, and FP16 compare.
// Called from dispatch_evex in insn_evex.sail.

val cmp_ub_pred : (byte, byte, range(0, 7)) -> bool
function cmp_ub_pred(a, b, pred) = match pred {
  0 => unsigned(a) == unsigned(b),
  1 => unsigned(a) < unsigned(b),
  2 => unsigned(a) <= unsigned(b),
  3 => false,  // FALSE
  4 => unsigned(a) != unsigned(b),
  5 => unsigned(a) >= unsigned(b),
  6 => unsigned(a) > unsigned(b),
  _ => true,   // TRUE
}

val avx_pcmpub_128 : (xmmword, xmmword, range(0, 7)) -> word
function avx_pcmpub_128(a, b, pred) =
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

val avx_pcmpub_256 : (ymmword, ymmword, range(0, 7)) -> dword
function avx_pcmpub_256(a, b, pred) =
  avx_pcmpub_128(a[255..128], b[255..128], pred) @
  avx_pcmpub_128(a[127..0], b[127..0], pred)

val avx_pcmpub_512 : (zmmword, zmmword, range(0, 7)) -> qword
function avx_pcmpub_512(a, b, pred) =
  avx_pcmpub_256(a[511..256], b[511..256], pred) @
  avx_pcmpub_256(a[255..0], b[255..0], pred)

// VPCMPB: signed byte compare

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

val avx_pcmpb_128 : (xmmword, xmmword, range(0, 7)) -> word
function avx_pcmpb_128(a, b, pred) =
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

val avx_pcmpb_256 : (ymmword, ymmword, range(0, 7)) -> dword
function avx_pcmpb_256(a, b, pred) =
  avx_pcmpb_128(a[255..128], b[255..128], pred) @
  avx_pcmpb_128(a[127..0], b[127..0], pred)

val avx_pcmpb_512 : (zmmword, zmmword, range(0, 7)) -> qword
function avx_pcmpb_512(a, b, pred) =
  avx_pcmpb_256(a[511..256], b[511..256], pred) @
  avx_pcmpb_256(a[255..0], b[255..0], pred)

// VPCMPUW: unsigned word compare

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

val avx_pcmpuw_128 : (xmmword, xmmword, range(0, 7)) -> byte
function avx_pcmpuw_128(a, b, pred) =
  bool_to_bit(cmp_uw_pred(a[127..112], b[127..112], pred)) @
  bool_to_bit(cmp_uw_pred(a[111..96], b[111..96], pred)) @
  bool_to_bit(cmp_uw_pred(a[95..80], b[95..80], pred)) @
  bool_to_bit(cmp_uw_pred(a[79..64], b[79..64], pred)) @
  bool_to_bit(cmp_uw_pred(a[63..48], b[63..48], pred)) @
  bool_to_bit(cmp_uw_pred(a[47..32], b[47..32], pred)) @
  bool_to_bit(cmp_uw_pred(a[31..16], b[31..16], pred)) @
  bool_to_bit(cmp_uw_pred(a[15..0], b[15..0], pred))

val avx_pcmpuw_256 : (ymmword, ymmword, range(0, 7)) -> word
function avx_pcmpuw_256(a, b, pred) =
  avx_pcmpuw_128(a[255..128], b[255..128], pred) @
  avx_pcmpuw_128(a[127..0], b[127..0], pred)

val avx_pcmpuw_512 : (zmmword, zmmword, range(0, 7)) -> dword
function avx_pcmpuw_512(a, b, pred) =
  avx_pcmpuw_256(a[511..256], b[511..256], pred) @
  avx_pcmpuw_256(a[255..0], b[255..0], pred)

// VPCMPW: signed word compare

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

val avx_pcmpw_128 : (xmmword, xmmword, range(0, 7)) -> byte
function avx_pcmpw_128(a, b, pred) =
  bool_to_bit(cmp_sw_pred(a[127..112], b[127..112], pred)) @
  bool_to_bit(cmp_sw_pred(a[111..96], b[111..96], pred)) @
  bool_to_bit(cmp_sw_pred(a[95..80], b[95..80], pred)) @
  bool_to_bit(cmp_sw_pred(a[79..64], b[79..64], pred)) @
  bool_to_bit(cmp_sw_pred(a[63..48], b[63..48], pred)) @
  bool_to_bit(cmp_sw_pred(a[47..32], b[47..32], pred)) @
  bool_to_bit(cmp_sw_pred(a[31..16], b[31..16], pred)) @
  bool_to_bit(cmp_sw_pred(a[15..0], b[15..0], pred))

val avx_pcmpw_256 : (ymmword, ymmword, range(0, 7)) -> word
function avx_pcmpw_256(a, b, pred) =
  avx_pcmpw_128(a[255..128], b[255..128], pred) @
  avx_pcmpw_128(a[127..0], b[127..0], pred)

val avx_pcmpw_512 : (zmmword, zmmword, range(0, 7)) -> dword
function avx_pcmpw_512(a, b, pred) =
  avx_pcmpw_256(a[511..256], b[511..256], pred) @
  avx_pcmpw_256(a[255..0], b[255..0], pred)

// VPCMPUD: unsigned dword compare producing kmask

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

val avx_pcmpud_128 : (xmmword, xmmword, range(0, 7)) -> byte
function avx_pcmpud_128(a, b, pred) = {
  let r : bits(4) =
    bool_to_bit(cmp_ud_pred(a[127..96], b[127..96], pred)) @
    bool_to_bit(cmp_ud_pred(a[95..64], b[95..64], pred)) @
    bool_to_bit(cmp_ud_pred(a[63..32], b[63..32], pred)) @
    bool_to_bit(cmp_ud_pred(a[31..0], b[31..0], pred));
  zero_extend(r)
}

val avx_pcmpud_256 : (ymmword, ymmword, range(0, 7)) -> byte
function avx_pcmpud_256(a, b, pred) =
  bool_to_bit(cmp_ud_pred(a[255..224], b[255..224], pred)) @
  bool_to_bit(cmp_ud_pred(a[223..192], b[223..192], pred)) @
  bool_to_bit(cmp_ud_pred(a[191..160], b[191..160], pred)) @
  bool_to_bit(cmp_ud_pred(a[159..128], b[159..128], pred)) @
  bool_to_bit(cmp_ud_pred(a[127..96], b[127..96], pred)) @
  bool_to_bit(cmp_ud_pred(a[95..64], b[95..64], pred)) @
  bool_to_bit(cmp_ud_pred(a[63..32], b[63..32], pred)) @
  bool_to_bit(cmp_ud_pred(a[31..0], b[31..0], pred))

val avx_pcmpud_512 : (zmmword, zmmword, range(0, 7)) -> word
function avx_pcmpud_512(a, b, pred) =
  avx_pcmpud_256(a[511..256], b[511..256], pred) @
  avx_pcmpud_256(a[255..0], b[255..0], pred)

// VPCMPD: signed dword compare

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

val avx_pcmpd_128 : (xmmword, xmmword, range(0, 7)) -> byte
function avx_pcmpd_128(a, b, pred) = {
  let r : bits(4) =
    bool_to_bit(cmp_sd_pred(a[127..96], b[127..96], pred)) @
    bool_to_bit(cmp_sd_pred(a[95..64], b[95..64], pred)) @
    bool_to_bit(cmp_sd_pred(a[63..32], b[63..32], pred)) @
    bool_to_bit(cmp_sd_pred(a[31..0], b[31..0], pred));
  zero_extend(r)
}

val avx_pcmpd_256 : (ymmword, ymmword, range(0, 7)) -> byte
function avx_pcmpd_256(a, b, pred) =
  bool_to_bit(cmp_sd_pred(a[255..224], b[255..224], pred)) @
  bool_to_bit(cmp_sd_pred(a[223..192], b[223..192], pred)) @
  bool_to_bit(cmp_sd_pred(a[191..160], b[191..160], pred)) @
  bool_to_bit(cmp_sd_pred(a[159..128], b[159..128], pred)) @
  bool_to_bit(cmp_sd_pred(a[127..96], b[127..96], pred)) @
  bool_to_bit(cmp_sd_pred(a[95..64], b[95..64], pred)) @
  bool_to_bit(cmp_sd_pred(a[63..32], b[63..32], pred)) @
  bool_to_bit(cmp_sd_pred(a[31..0], b[31..0], pred))

val avx_pcmpd_512 : (zmmword, zmmword, range(0, 7)) -> word
function avx_pcmpd_512(a, b, pred) =
  avx_pcmpd_256(a[511..256], b[511..256], pred) @
  avx_pcmpd_256(a[255..0], b[255..0], pred)

// VPCMPUQ: unsigned qword compare

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

val avx_pcmpuq_128 : (xmmword, xmmword, range(0, 7)) -> byte
function avx_pcmpuq_128(a, b, pred) = {
  let r : bits(2) =
    bool_to_bit(cmp_uq_pred(a[127..64], b[127..64], pred)) @
    bool_to_bit(cmp_uq_pred(a[63..0], b[63..0], pred));
  zero_extend(r)
}

val avx_pcmpuq_256 : (ymmword, ymmword, range(0, 7)) -> byte
function avx_pcmpuq_256(a, b, pred) = {
  let r : bits(4) =
    bool_to_bit(cmp_uq_pred(a[255..192], b[255..192], pred)) @
    bool_to_bit(cmp_uq_pred(a[191..128], b[191..128], pred)) @
    bool_to_bit(cmp_uq_pred(a[127..64], b[127..64], pred)) @
    bool_to_bit(cmp_uq_pred(a[63..0], b[63..0], pred));
  zero_extend(r)
}

val avx_pcmpuq_512 : (zmmword, zmmword, range(0, 7)) -> byte
function avx_pcmpuq_512(a, b, pred) =
  bool_to_bit(cmp_uq_pred(a[511..448], b[511..448], pred)) @
  bool_to_bit(cmp_uq_pred(a[447..384], b[447..384], pred)) @
  bool_to_bit(cmp_uq_pred(a[383..320], b[383..320], pred)) @
  bool_to_bit(cmp_uq_pred(a[319..256], b[319..256], pred)) @
  bool_to_bit(cmp_uq_pred(a[255..192], b[255..192], pred)) @
  bool_to_bit(cmp_uq_pred(a[191..128], b[191..128], pred)) @
  bool_to_bit(cmp_uq_pred(a[127..64], b[127..64], pred)) @
  bool_to_bit(cmp_uq_pred(a[63..0], b[63..0], pred))

// VPCMPQ: signed qword compare

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

val avx_pcmpq_128 : (xmmword, xmmword, range(0, 7)) -> byte
function avx_pcmpq_128(a, b, pred) = {
  let r : bits(2) =
    bool_to_bit(cmp_sq_pred(a[127..64], b[127..64], pred)) @
    bool_to_bit(cmp_sq_pred(a[63..0], b[63..0], pred));
  zero_extend(r)
}

val avx_pcmpq_256 : (ymmword, ymmword, range(0, 7)) -> byte
function avx_pcmpq_256(a, b, pred) = {
  let r : bits(4) =
    bool_to_bit(cmp_sq_pred(a[255..192], b[255..192], pred)) @
    bool_to_bit(cmp_sq_pred(a[191..128], b[191..128], pred)) @
    bool_to_bit(cmp_sq_pred(a[127..64], b[127..64], pred)) @
    bool_to_bit(cmp_sq_pred(a[63..0], b[63..0], pred));
  zero_extend(r)
}

val avx_pcmpq_512 : (zmmword, zmmword, range(0, 7)) -> byte
function avx_pcmpq_512(a, b, pred) =
  bool_to_bit(cmp_sq_pred(a[511..448], b[511..448], pred)) @
  bool_to_bit(cmp_sq_pred(a[447..384], b[447..384], pred)) @
  bool_to_bit(cmp_sq_pred(a[383..320], b[383..320], pred)) @
  bool_to_bit(cmp_sq_pred(a[319..256], b[319..256], pred)) @
  bool_to_bit(cmp_sq_pred(a[255..192], b[255..192], pred)) @
  bool_to_bit(cmp_sq_pred(a[191..128], b[191..128], pred)) @
  bool_to_bit(cmp_sq_pred(a[127..64], b[127..64], pred)) @
  bool_to_bit(cmp_sq_pred(a[63..0], b[63..0], pred))

// =========================================================================
// VPTERNLOGD: ternary logic on 3 dword operands using 8-bit truth table
// For each bit position: result = imm8[{a_bit, b_bit, c_bit}]
// =========================================================================

val vpternlog_128 : (xmmword, xmmword, xmmword, byte) -> xmmword
function vpternlog_128(a, b, c, imm) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 127) {
    let idx : range(0, 7) = unsigned(a[i] @ b[i] @ c[i]);
    r[i] = imm[idx]
  };
  r
}

val vpternlog_256 : (ymmword, ymmword, ymmword, byte) -> ymmword
function vpternlog_256(a, b, c, imm) = {
  var r : ymmword = zeros();
  foreach (i from 0 to 255) {
    let idx : range(0, 7) = unsigned(a[i] @ b[i] @ c[i]);
    r[i] = imm[idx]
  };
  r
}

val vpternlog_512 : (zmmword, zmmword, zmmword, byte) -> zmmword
function vpternlog_512(a, b, c, imm) = {
  var r : zmmword = zeros();
  foreach (i from 0 to 511) {
    let idx : range(0, 7) = unsigned(a[i] @ b[i] @ c[i]);
    r[i] = imm[idx]
  };
  r
}

// =========================================================================
// AVX-512 opmask (k-register) operations
// =========================================================================

// AVX-512 Mask Register (k*) Instructions
//
// These instructions operate on opmask registers k0-k7.
// Opmask registers are defined in core/regs.sail as KREG[8].

// =========================================================================
// KADD -- Add Mask Registers
// =========================================================================

val cmp_pred5_f16 : (word, word, range(0, 31)) -> bool
function cmp_pred5_f16(a, b, pred) = {
  let r = __compare_sh(a, b);
  let is_unord = r == FP_UNORDERED;
  match pred {
    0  => r == FP_EQ,
    1  => r == FP_LT,
    2  => r == FP_LT | r == FP_EQ,
    3  => is_unord,
    4  => r != FP_EQ & not_bool(is_unord),
    5  => not_bool(r == FP_LT) | is_unord,
    6  => not_bool(r == FP_LT | r == FP_EQ) | is_unord,
    7  => not_bool(is_unord),
    8  => r == FP_EQ | is_unord,
    9  => r == FP_LT | is_unord,
    10 => (r == FP_LT | r == FP_EQ) | is_unord,
    11 => false,
    12 => r != FP_EQ,
    13 => not_bool(r == FP_LT),
    14 => r == FP_GT | r == FP_EQ,
    15 => true,
    16 => r == FP_EQ,
    17 => r == FP_LT,
    18 => r == FP_LT | r == FP_EQ,
    19 => is_unord,
    20 => r != FP_EQ | is_unord,
    21 => not_bool(r == FP_LT) | is_unord,
    22 => not_bool(r == FP_LT | r == FP_EQ) | is_unord,
    23 => not_bool(is_unord),
    24 => r == FP_EQ | is_unord,
    25 => r == FP_LT | is_unord,
    26 => (r == FP_LT | r == FP_EQ) | is_unord,
    27 => false,
    28 => r != FP_EQ,
    29 => not_bool(r == FP_LT),
    30 => r == FP_GT | r == FP_EQ,
    31 => true,
  }
}

// VCMPPH → kmask: compare FP16 elements, return mask

val avx_vcmpph_kmask_128 : (xmmword, xmmword, range(0, 31)) -> byte
function avx_vcmpph_kmask_128(a, b, pred) = {
  var r : byte = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    if cmp_pred5_f16(a[(lo+15)..lo], b[(lo+15)..lo], pred) then r[i] = bitone;
  };
  r
}

val avx_vcmpph_kmask_256 : (ymmword, ymmword, range(0, 31)) -> word
function avx_vcmpph_kmask_256(a, b, pred) = {
  avx_vcmpph_kmask_128(a[255..128], b[255..128], pred) @
  avx_vcmpph_kmask_128(a[127..0], b[127..0], pred)
}

val avx_vcmpph_kmask_512 : (zmmword, zmmword, range(0, 31)) -> dword
function avx_vcmpph_kmask_512(a, b, pred) = {
  avx_vcmpph_kmask_256(a[511..256], b[511..256], pred) @
  avx_vcmpph_kmask_256(a[255..0], b[255..0], pred)
}

// =========================================================================
// Packed FP conversions
// =========================================================================

// VCVTPS2PD: convert N f32 → N f64 (widening)

val avx_vpermq_imm_256 : (ymmword, byte) -> ymmword
function avx_vpermq_imm_256(src, imm) = {
  var r : ymmword = zeros();
  foreach (i from 0 to 3) {
    let sel : range(0, 3) = unsigned(imm[(i * 2 + 1)..(i * 2)]);
    let dst_lo : range(0, 192) = i * 64;
    let src_lo : range(0, 192) = sel * 64;
    r[(dst_lo + 63)..dst_lo] = src[(src_lo + 63)..src_lo];
  };
  r
}

val avx_vpermq_imm_512 : (zmmword, byte) -> zmmword
function avx_vpermq_imm_512(src, imm) = {
  // Two independent 256-bit halves
  let lo_half : ymmword = avx_vpermq_imm_256(src[255..0], imm);
  let hi_half : ymmword = avx_vpermq_imm_256(src[511..256], imm);
  hi_half @ lo_half
}

/* ---- VALIGND: concatenate and shift right by imm8 dwords ---- */

val avx_valignd_128 : (xmmword, xmmword, byte) -> xmmword
function avx_valignd_128(src1, src2, imm) = {
  // TEMP = src1:src2 (src1 upper, src2 lower)
  let shift : range(0, 3) = unsigned(imm[1..0]);
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let src_idx : range(0, 7) = i + shift;
    let dst_lo : range(0, 96) = i * 32;
    if src_idx < 4
    then {
      let s : range(0, 96) = src_idx * 32; r[(dst_lo + 31)..dst_lo] = src2[(s + 31)..s]
    } else {
      let s : range(0, 96) = (src_idx - 4) * 32; r[(dst_lo + 31)..dst_lo] = src1[(s + 31)..s]
    };
  };
  r
}

val avx_valignd_256 : (ymmword, ymmword, byte) -> ymmword
function avx_valignd_256(src1, src2, imm) = {
  // TEMP = src1:src2 (src1 upper, src2 lower)
  let shift : range(0, 7) = unsigned(imm[2..0]);
  var r : ymmword = zeros();
  foreach (i from 0 to 7) {
    let src_idx : range(0, 15) = i + shift;
    let dst_lo : range(0, 224) = i * 32;
    if src_idx < 8
    then {
      let s : range(0, 224) = src_idx * 32; r[(dst_lo + 31)..dst_lo] = src2[(s + 31)..s]
    } else {
      let s : range(0, 224) = (src_idx - 8) * 32; r[(dst_lo + 31)..dst_lo] = src1[(s + 31)..s]
    };
  };
  r
}

val avx_valignd_512 : (zmmword, zmmword, byte) -> zmmword
function avx_valignd_512(src1, src2, imm) = {
  // TEMP = src1:src2 (src1 is upper, src2 is lower)
  // Result[i] = TEMP[i + shift]
  let shift : range(0, 15) = unsigned(imm[3..0]);
  var r : zmmword = zeros();
  foreach (i from 0 to 15) {
    let src_idx : range(0, 31) = i + shift;
    let dst_lo : range(0, 480) = i * 32;
    if src_idx < 16
    then {
      let s : range(0, 480) = src_idx * 32; r[(dst_lo + 31)..dst_lo] = src2[(s + 31)..s]
    } else {
      let s : range(0, 480) = (src_idx - 16) * 32; r[(dst_lo + 31)..dst_lo] = src1[(s + 31)..s]
    };
  };
  r
}

/* ---- VALIGNQ: concatenate and shift right by imm8 qwords ---- */

val avx_valignq_128 : (xmmword, xmmword, byte) -> xmmword
function avx_valignq_128(src1, src2, imm) = {
  // TEMP = src1:src2 (src1 upper, src2 lower)
  let shift : range(0, 1) = unsigned(imm[0..0]);
  var r : xmmword = zeros();
  foreach (i from 0 to 1) {
    let src_idx : range(0, 3) = i + shift;
    let dst_lo : range(0, 64) = i * 64;
    if src_idx < 2
    then {
      let s : range(0, 64) = src_idx * 64; r[(dst_lo + 63)..dst_lo] = src2[(s + 63)..s]
    } else {
      let s : range(0, 64) = (src_idx - 2) * 64; r[(dst_lo + 63)..dst_lo] = src1[(s + 63)..s]
    };
  };
  r
}

val avx_valignq_256 : (ymmword, ymmword, byte) -> ymmword
function avx_valignq_256(src1, src2, imm) = {
  // TEMP = src1:src2 (src1 upper, src2 lower)
  let shift : range(0, 3) = unsigned(imm[1..0]);
  var r : ymmword = zeros();
  foreach (i from 0 to 3) {
    let src_idx : range(0, 7) = i + shift;
    let dst_lo : range(0, 192) = i * 64;
    if src_idx < 4
    then {
      let s : range(0, 192) = src_idx * 64; r[(dst_lo + 63)..dst_lo] = src2[(s + 63)..s]
    } else {
      let s : range(0, 192) = (src_idx - 4) * 64; r[(dst_lo + 63)..dst_lo] = src1[(s + 63)..s]
    };
  };
  r
}

val avx_valignq_512 : (zmmword, zmmword, byte) -> zmmword
function avx_valignq_512(src1, src2, imm) = {
  // TEMP = src1:src2 (src1 upper, src2 lower)
  let shift : range(0, 7) = unsigned(imm[2..0]);
  var r : zmmword = zeros();
  foreach (i from 0 to 7) {
    let src_idx : range(0, 15) = i + shift;
    let dst_lo : range(0, 448) = i * 64;
    if src_idx < 8
    then {
      let s : range(0, 448) = src_idx * 64; r[(dst_lo + 63)..dst_lo] = src2[(s + 63)..s]
    } else {
      let s : range(0, 448) = (src_idx - 8) * 64; r[(dst_lo + 63)..dst_lo] = src1[(s + 63)..s]
    };
  };
  r
}

/* ---- VPERMILPS (imm8): in-lane dword permute ---- */

val avx_vpermilps_imm_128 : (xmmword, byte) -> xmmword
function avx_vpermilps_imm_128(src, imm) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let sel : range(0, 3) = unsigned(imm[(i * 2 + 1)..(i * 2)]);
    let dst_lo : range(0, 96) = i * 32;
    let src_lo : range(0, 96) = sel * 32;
    r[(dst_lo + 31)..dst_lo] = src[(src_lo + 31)..src_lo];
  };
  r
}

val avx_vpermilps_imm_256 : (ymmword, byte) -> ymmword
function avx_vpermilps_imm_256(src, imm) = {
  let lo : xmmword = avx_vpermilps_imm_128(src[127..0], imm);
  let hi : xmmword = avx_vpermilps_imm_128(src[255..128], imm);
  hi @ lo
}

val avx_vpermilps_imm_512 : (zmmword, byte) -> zmmword
function avx_vpermilps_imm_512(src, imm) = {
  let q0 : xmmword = avx_vpermilps_imm_128(src[127..0], imm);
  let q1 : xmmword = avx_vpermilps_imm_128(src[255..128], imm);
  let q2 : xmmword = avx_vpermilps_imm_128(src[383..256], imm);
  let q3 : xmmword = avx_vpermilps_imm_128(src[511..384], imm);
  q3 @ q2 @ q1 @ q0
}

/* ---- VPERMILPD (imm8): in-lane qword permute ---- */

val avx_vpermilpd_imm_128 : (xmmword, byte) -> xmmword
function avx_vpermilpd_imm_128(src, imm) = {
  let s0 : range(0, 1) = unsigned(imm[0..0]);
  let s1 : range(0, 1) = unsigned(imm[1..1]);
  let lo0 : range(0, 64) = s0 * 64;
  let lo1 : range(0, 64) = s1 * 64;
  src[(lo1 + 63)..lo1] @ src[(lo0 + 63)..lo0]
}

val avx_vpermilpd_imm_256 : (ymmword, byte) -> ymmword
function avx_vpermilpd_imm_256(src, imm) = {
  let lo : xmmword = avx_vpermilpd_imm_128(src[127..0], imm);
  let hi : xmmword = avx_vpermilpd_imm_128(src[255..128], imm[3..2] @ 0b000000);
  hi @ lo
}

val avx_vpermilpd_imm_512 : (zmmword, byte) -> zmmword
function avx_vpermilpd_imm_512(src, imm) = {
  let q0 : xmmword = avx_vpermilpd_imm_128(src[127..0], imm);
  let q1 : xmmword = avx_vpermilpd_imm_128(src[255..128], imm[3..2] @ 0b000000);
  let q2 : xmmword = avx_vpermilpd_imm_128(src[383..256], imm[5..4] @ 0b000000);
  let q3 : xmmword = avx_vpermilpd_imm_128(src[511..384], imm[7..6] @ 0b000000);
  q3 @ q2 @ q1 @ q0
}

/* ---- VPALIGNR: byte-align concatenation per 128-bit lane ---- */

val avx_palignr_256 : (ymmword, ymmword, byte) -> ymmword
function avx_palignr_256(src1, src2, imm) = {
  let lo : xmmword = avx_palignr_128(src1[127..0], src2[127..0], imm);
  let hi : xmmword = avx_palignr_128(src1[255..128], src2[255..128], imm);
  hi @ lo
}

val avx_palignr_512 : (zmmword, zmmword, byte) -> zmmword
function avx_palignr_512(src1, src2, imm) = {
  let q0 : xmmword = avx_palignr_128(src1[127..0], src2[127..0], imm);
  let q1 : xmmword = avx_palignr_128(src1[255..128], src2[255..128], imm);
  let q2 : xmmword = avx_palignr_128(src1[383..256], src2[383..256], imm);
  let q3 : xmmword = avx_palignr_128(src1[511..384], src2[511..384], imm);
  q3 @ q2 @ q1 @ q0
}

// =========================================================================
// Narrowing / Down-conversion helpers (VPMOV, VPMOVS, VPMOVUS)
// =========================================================================

// --- VPMOVWB: truncate word -> byte ---

val select_lane_128_from_512 : (zmmword, range(0, 3)) -> xmmword
function select_lane_128_from_512(src, sel) = {
  match sel {
    0 => src[127..0],
    1 => src[255..128],
    2 => src[383..256],
    _ => src[511..384],
  }
}

// VSHUFF32X4 / VSHUFI32X4 (256-bit): shuffle 128-bit lanes
// imm8[0] selects src2 lane for dst[127:0], imm8[1] selects src2 lane for dst[255:128]
// Wait, for 256-bit: imm8[0] selects which lane of src1 → dst low, imm8[1] selects which lane of src2 → dst high
// Actually SDM says: for 256-bit VSHUFF32X4:
//   dst[127:0] = src1[imm8[0]*128+127 : imm8[0]*128]
//   dst[255:128] = src2[imm8[1]*128+127 : imm8[1]*128]

val avx_shuf_f32x4_256 : (ymmword, ymmword, byte) -> ymmword
function avx_shuf_f32x4_256(src1, src2, imm) = {
  let s0 : range(0, 1) = unsigned(imm[0..0]);
  let s1 : range(0, 1) = unsigned(imm[1..1]);
  let lane0 : xmmword = if s0 == 0 then src1[127..0] else src1[255..128];
  let lane1 : xmmword = if s1 == 0 then src2[127..0] else src2[255..128];
  lane1 @ lane0
}

// VSHUFF32X4 / VSHUFI32X4 (512-bit):
//   dst[127:0] = src1[imm8[1:0]*128+127 : ...]
//   dst[255:128] = src1[imm8[3:2]*128+127 : ...]
//   dst[383:256] = src2[imm8[5:4]*128+127 : ...]
//   dst[511:384] = src2[imm8[7:6]*128+127 : ...]

val avx_shuf_f32x4_512 : (zmmword, zmmword, byte) -> zmmword
function avx_shuf_f32x4_512(src1, src2, imm) = {
  let s0 : range(0, 3) = unsigned(imm[1..0]);
  let s1 : range(0, 3) = unsigned(imm[3..2]);
  let s2 : range(0, 3) = unsigned(imm[5..4]);
  let s3 : range(0, 3) = unsigned(imm[7..6]);
  let lane0 = select_lane_128_from_512(src1, s0);
  let lane1 = select_lane_128_from_512(src1, s1);
  let lane2 = select_lane_128_from_512(src2, s2);
  let lane3 = select_lane_128_from_512(src2, s3);
  lane3 @ lane2 @ lane1 @ lane0
}

// For 64-bit element variant (VSHUFF64X2 / VSHUFI64X2): same operation, just different element interpretation
// Use the same functions above since it's identical at the bitvector level.

/* ---- VDBPSADBW: double-block packed sum of absolute differences ---- */

// Extract byte i (0-15) from a 128-bit vector
val xmm_byte : (xmmword, range(0, 15)) -> byte
function xmm_byte(v, i) = v[(i * 8 + 7)..(i * 8)]

val avx_vdbpsadbw_128 : (xmmword, xmmword, byte) -> xmmword
function avx_vdbpsadbw_128(src1, src2, imm) = {
  // Phase 1: Form TMP1 by selecting dwords from src2 per imm8 2-bit fields
  var tmp1 : xmmword = zeros();
  foreach (i from 0 to 3) {
    let sel : range(0, 3) = unsigned(imm[(2 * i + 1)..(2 * i)]);
    tmp1[((i + 1) * 32 - 1)..(i * 32)] = src2[((sel + 1) * 32 - 1)..(sel * 32)];
  };
  // Phase 2: SAD with sliding window per 64-bit super block
  // For each super block, 2 stationary src1 dwords slide against TMP1:
  //   word[0] = SAD(src1_dw0, tmp1_bytes[0:3])
  //   word[1] = SAD(src1_dw0, tmp1_bytes[1:4])
  //   word[2] = SAD(src1_dw1, tmp1_bytes[2:5])
  //   word[3] = SAD(src1_dw1, tmp1_bytes[3:6])
  var result : xmmword = zeros();
  foreach (blk from 0 to 1) {
    let bb : range(0, 8) = blk * 8;  // base byte index for this super block
    foreach (w from 0 to 3) {
      let s1_base : range(0, 12) = bb + (w / 2) * 4;  // stationary dword start byte
      let t1_base : range(0, 11) = bb + w;  // sliding window start byte
      var sad : int = 0;
      foreach (k from 0 to 3) {
        sad = sad + abs_diff8(xmm_byte(src1, s1_base + k), xmm_byte(tmp1, t1_base + k));
      };
      let wrd : word = get_slice_int(16, sad, 0);
      let dst_bit : range(0, 112) = (blk * 4 + w) * 16;
      result[(dst_bit + 15)..dst_bit] = wrd;
    };
  };
  result
}

val avx_vdbpsadbw_256 : (ymmword, ymmword, byte) -> ymmword
function avx_vdbpsadbw_256(src1, src2, imm) = {
  avx_vdbpsadbw_128(src1[255..128], src2[255..128], imm) @ avx_vdbpsadbw_128(src1[127..0], src2[127..0], imm)
}

val avx_vdbpsadbw_512 : (zmmword, zmmword, byte) -> zmmword
function avx_vdbpsadbw_512(src1, src2, imm) = {
  let q0 = avx_vdbpsadbw_128(src1[127..0], src2[127..0], imm);
  let q1 = avx_vdbpsadbw_128(src1[255..128], src2[255..128], imm);
  let q2 = avx_vdbpsadbw_128(src1[383..256], src2[383..256], imm);
  let q3 = avx_vdbpsadbw_128(src1[511..384], src2[511..384], imm);
  q3 @ q2 @ q1 @ q0
}

/* ---- VEXPANDPS/PD: expand from contiguous to masked positions ---- */
// These read contiguous elements from src and scatter into positions where mask=1.
// Elements where mask=0 get zeroed (or kept from dst if merging, but we implement zero-masking).
// The mask comes from a k-register, but at the helper level we just take the mask bits as an argument.

// VEXPANDPS/PD and VCOMPRESSPS/PD use mask-based element rearrangement.
// Since the mutable counter j confuses the type checker, we use a different approach:
// count set bits below each position to determine source/dest indices.

// Count set bits in positions [0, upto) of a byte mask

val avx_vrndscaleps_128 : (xmmword, byte) -> xmmword
function avx_vrndscaleps_128(src, imm) = {
  let r0 = __f32_rndscale(src[31..0], imm);
  let r1 = __f32_rndscale(src[63..32], imm);
  let r2 = __f32_rndscale(src[95..64], imm);
  let r3 = __f32_rndscale(src[127..96], imm);
  r3 @ r2 @ r1 @ r0
}

val avx_vrndscaleps_256 : (ymmword, byte) -> ymmword
function avx_vrndscaleps_256(src, imm) = {
  avx_vrndscaleps_128(src[255..128], imm) @ avx_vrndscaleps_128(src[127..0], imm)
}

val avx_vrndscaleps_512 : (zmmword, byte) -> zmmword
function avx_vrndscaleps_512(src, imm) = {
  avx_vrndscaleps_256(src[511..256], imm) @ avx_vrndscaleps_256(src[255..0], imm)
}

val avx_vrndscalepd_128 : (xmmword, byte) -> xmmword
function avx_vrndscalepd_128(src, imm) = {
  let r0 = __f64_rndscale(src[63..0], imm);
  let r1 = __f64_rndscale(src[127..64], imm);
  r1 @ r0
}

val avx_vrndscalepd_256 : (ymmword, byte) -> ymmword
function avx_vrndscalepd_256(src, imm) = {
  avx_vrndscalepd_128(src[255..128], imm) @ avx_vrndscalepd_128(src[127..0], imm)
}

val avx_vrndscalepd_512 : (zmmword, byte) -> zmmword
function avx_vrndscalepd_512(src, imm) = {
  avx_vrndscalepd_256(src[511..256], imm) @ avx_vrndscalepd_256(src[255..0], imm)
}

/* ---- VGETMANT: extract mantissa ---- */

val avx_vgetmantps_128 : (xmmword, byte) -> xmmword
function avx_vgetmantps_128(src, imm) = {
  let r0 = __f32_getmant(src[31..0], imm);
  let r1 = __f32_getmant(src[63..32], imm);
  let r2 = __f32_getmant(src[95..64], imm);
  let r3 = __f32_getmant(src[127..96], imm);
  r3 @ r2 @ r1 @ r0
}

val avx_vgetmantps_256 : (ymmword, byte) -> ymmword
function avx_vgetmantps_256(src, imm) = {
  avx_vgetmantps_128(src[255..128], imm) @ avx_vgetmantps_128(src[127..0], imm)
}

val avx_vgetmantps_512 : (zmmword, byte) -> zmmword
function avx_vgetmantps_512(src, imm) = {
  avx_vgetmantps_256(src[511..256], imm) @ avx_vgetmantps_256(src[255..0], imm)
}

val avx_vgetmantpd_128 : (xmmword, byte) -> xmmword
function avx_vgetmantpd_128(src, imm) = {
  __f64_getmant(src[127..64], imm) @ __f64_getmant(src[63..0], imm)
}

val avx_vgetmantpd_256 : (ymmword, byte) -> ymmword
function avx_vgetmantpd_256(src, imm) = {
  avx_vgetmantpd_128(src[255..128], imm) @ avx_vgetmantpd_128(src[127..0], imm)
}

val avx_vgetmantpd_512 : (zmmword, byte) -> zmmword
function avx_vgetmantpd_512(src, imm) = {
  avx_vgetmantpd_256(src[511..256], imm) @ avx_vgetmantpd_256(src[255..0], imm)
}

/* ---- VREDUCE: reduce FP value ---- */

val avx_vreduceps_128 : (xmmword, byte) -> xmmword
function avx_vreduceps_128(src, imm) = {
  let r0 = __f32_reduce(src[31..0], imm);
  let r1 = __f32_reduce(src[63..32], imm);
  let r2 = __f32_reduce(src[95..64], imm);
  let r3 = __f32_reduce(src[127..96], imm);
  r3 @ r2 @ r1 @ r0
}

val avx_vreduceps_256 : (ymmword, byte) -> ymmword
function avx_vreduceps_256(src, imm) = {
  avx_vreduceps_128(src[255..128], imm) @ avx_vreduceps_128(src[127..0], imm)
}

val avx_vreduceps_512 : (zmmword, byte) -> zmmword
function avx_vreduceps_512(src, imm) = {
  avx_vreduceps_256(src[511..256], imm) @ avx_vreduceps_256(src[255..0], imm)
}

val avx_vreducepd_128 : (xmmword, byte) -> xmmword
function avx_vreducepd_128(src, imm) = {
  __f64_reduce(src[127..64], imm) @ __f64_reduce(src[63..0], imm)
}

val avx_vreducepd_256 : (ymmword, byte) -> ymmword
function avx_vreducepd_256(src, imm) = {
  avx_vreducepd_128(src[255..128], imm) @ avx_vreducepd_128(src[127..0], imm)
}

val avx_vreducepd_512 : (zmmword, byte) -> zmmword
function avx_vreducepd_512(src, imm) = {
  avx_vreducepd_256(src[511..256], imm) @ avx_vreducepd_256(src[255..0], imm)
}

/* ---- VFIXUPIMM: fix up special values ---- */

val avx_vfixupimmps_128 : (xmmword, xmmword, xmmword, byte) -> xmmword
function avx_vfixupimmps_128(dst, src1, src2, imm) = {
  let r0 = __f32_fixupimm(dst[31..0], src1[31..0], src2[31..0], imm);
  let r1 = __f32_fixupimm(dst[63..32], src1[63..32], src2[63..32], imm);
  let r2 = __f32_fixupimm(dst[95..64], src1[95..64], src2[95..64], imm);
  let r3 = __f32_fixupimm(dst[127..96], src1[127..96], src2[127..96], imm);
  r3 @ r2 @ r1 @ r0
}

val avx_vfixupimmps_256 : (ymmword, ymmword, ymmword, byte) -> ymmword
function avx_vfixupimmps_256(dst, src1, src2, imm) = {
  avx_vfixupimmps_128(dst[255..128], src1[255..128], src2[255..128], imm) @ avx_vfixupimmps_128(dst[127..0], src1[127..0], src2[127..0], imm)
}

val avx_vfixupimmps_512 : (zmmword, zmmword, zmmword, byte) -> zmmword
function avx_vfixupimmps_512(dst, src1, src2, imm) = {
  avx_vfixupimmps_256(dst[511..256], src1[511..256], src2[511..256], imm) @ avx_vfixupimmps_256(dst[255..0], src1[255..0], src2[255..0], imm)
}

val avx_vfixupimmpd_128 : (xmmword, xmmword, xmmword, byte) -> xmmword
function avx_vfixupimmpd_128(dst, src1, src2, imm) = {
  __f64_fixupimm(dst[127..64], src1[127..64], src2[127..64], imm) @ __f64_fixupimm(dst[63..0], src1[63..0], src2[63..0], imm)
}

val avx_vfixupimmpd_256 : (ymmword, ymmword, ymmword, byte) -> ymmword
function avx_vfixupimmpd_256(dst, src1, src2, imm) = {
  avx_vfixupimmpd_128(dst[255..128], src1[255..128], src2[255..128], imm) @ avx_vfixupimmpd_128(dst[127..0], src1[127..0], src2[127..0], imm)
}

val avx_vfixupimmpd_512 : (zmmword, zmmword, zmmword, byte) -> zmmword
function avx_vfixupimmpd_512(dst, src1, src2, imm) = {
  avx_vfixupimmpd_256(dst[511..256], src1[511..256], src2[511..256], imm) @ avx_vfixupimmpd_256(dst[255..0], src1[255..0], src2[255..0], imm)
}

/* ---- VPLZCNTD/Q: count leading zeros per element ---- */

val avx_fpclass_f32 : (dword, byte) -> bool
function avx_fpclass_f32(src, imm) = {
  let sign = src[31];
  let exp : byte = src[30..23];
  let frac : bits(23) = src[22..0];
  let is_qnan = (exp == 0xFF) & (frac != zeros()) & (frac[22] == bitone);
  let is_snan = (exp == 0xFF) & (frac != zeros()) & (frac[22] == bitzero);
  let is_pos_zero = (sign == bitzero) & (exp == 0x00) & (frac == zeros());
  let is_neg_zero = (sign == bitone) & (exp == 0x00) & (frac == zeros());
  let is_pos_inf = (sign == bitzero) & (exp == 0xFF) & (frac == zeros());
  let is_neg_inf = (sign == bitone) & (exp == 0xFF) & (frac == zeros());
  let is_denorm = (exp == 0x00) & (frac != zeros());
  let is_neg_finite = (sign == bitone) & (exp != 0xFF) & not_bool((exp == 0x00) & (frac == zeros()));
  (imm[0] == bitone & is_qnan) |
  (imm[1] == bitone & is_pos_zero) |
  (imm[2] == bitone & is_neg_zero) |
  (imm[3] == bitone & is_pos_inf) |
  (imm[4] == bitone & is_neg_inf) |
  (imm[5] == bitone & is_denorm) |
  (imm[6] == bitone & is_neg_finite) |
  (imm[7] == bitone & is_snan)
}

val avx_fpclass_f64 : (qword, byte) -> bool
function avx_fpclass_f64(src, imm) = {
  let sign = src[63];
  let exp : bits(11) = src[62..52];
  let frac : bits(52) = src[51..0];
  let is_qnan = (exp == ones()) & (frac != zeros()) & (frac[51] == bitone);
  let is_snan = (exp == ones()) & (frac != zeros()) & (frac[51] == bitzero);
  let is_pos_zero = (sign == bitzero) & (exp == zeros()) & (frac == zeros());
  let is_neg_zero = (sign == bitone) & (exp == zeros()) & (frac == zeros());
  let is_pos_inf = (sign == bitzero) & (exp == ones()) & (frac == zeros());
  let is_neg_inf = (sign == bitone) & (exp == ones()) & (frac == zeros());
  let is_denorm = (exp == zeros()) & (frac != zeros());
  let is_neg_finite = (sign == bitone) & (exp != ones()) & not_bool((exp == zeros()) & (frac == zeros()));
  (imm[0] == bitone & is_qnan) |
  (imm[1] == bitone & is_pos_zero) |
  (imm[2] == bitone & is_neg_zero) |
  (imm[3] == bitone & is_pos_inf) |
  (imm[4] == bitone & is_neg_inf) |
  (imm[5] == bitone & is_denorm) |
  (imm[6] == bitone & is_neg_finite) |
  (imm[7] == bitone & is_snan)
}

// VFPCLASSPS/PD packed versions

val avx_vfpclassps_128 : (xmmword, byte) -> byte
function avx_vfpclassps_128(src, imm) = {
  let b0 : bits(1) = bool_to_bit(avx_fpclass_f32(src[31..0], imm));
  let b1 : bits(1) = bool_to_bit(avx_fpclass_f32(src[63..32], imm));
  let b2 : bits(1) = bool_to_bit(avx_fpclass_f32(src[95..64], imm));
  let b3 : bits(1) = bool_to_bit(avx_fpclass_f32(src[127..96], imm));
  0b0000 @ b3 @ b2 @ b1 @ b0
}

val avx_vfpclassps_256 : (ymmword, byte) -> byte
function avx_vfpclassps_256(src, imm) = {
  let lo = avx_vfpclassps_128(src[127..0], imm);
  let hi = avx_vfpclassps_128(src[255..128], imm);
  hi[3..0] @ lo[3..0]
}

val avx_vfpclassps_512 : (zmmword, byte) -> word
function avx_vfpclassps_512(src, imm) = {
  let lo = avx_vfpclassps_256(src[255..0], imm);
  let hi = avx_vfpclassps_256(src[511..256], imm);
  hi @ lo
}

val avx_vfpclasspd_128 : (xmmword, byte) -> byte
function avx_vfpclasspd_128(src, imm) = {
  let b0 : bits(1) = bool_to_bit(avx_fpclass_f64(src[63..0], imm));
  let b1 : bits(1) = bool_to_bit(avx_fpclass_f64(src[127..64], imm));
  0b000000 @ b1 @ b0
}

val avx_vfpclasspd_256 : (ymmword, byte) -> byte
function avx_vfpclasspd_256(src, imm) = {
  let lo = avx_vfpclasspd_128(src[127..0], imm);
  let hi = avx_vfpclasspd_128(src[255..128], imm);
  0b0000 @ hi[1..0] @ lo[1..0]
}

val avx_vfpclasspd_512 : (zmmword, byte) -> byte
function avx_vfpclasspd_512(src, imm) = {
  let lo = avx_vfpclasspd_256(src[255..0], imm);
  let hi = avx_vfpclasspd_256(src[511..256], imm);
  hi[3..0] @ lo[3..0]
}

/* ---- VRANGEPS/PD: range restriction ---- */
// VRANGE: for each element pair, select min/max/abs-min/abs-max then apply sign control
// imm8[1:0] = operation (CmpOpCtl):
//   0=min(src1,src2), 1=max(src1,src2), 2=abs_min, 3=abs_max
//   For abs_min/abs_max: compare |src1| vs |src2| but return the ORIGINAL value
// imm8[3:2] = sign control (SignSelCtl):
//   0=preserve src1 sign, 1=preserve compare result sign, 2=force +, 3=force -

// Per-element range for f32 (SDM: RangeSP)
val avx_range_f32 : (dword, dword, byte) -> dword
function avx_range_f32(src1, src2, imm) = {
  let op : range(0, 3) = unsigned(imm[1..0]);
  let sign_ctl : range(0, 3) = unsigned(imm[3..2]);
  // Phase 1: select comparison result (TMP)
  let tmp : dword = match op {
    0 => __f32_min(src1, src2),
    1 => __f32_max(src1, src2),
    // abs_min: compare |src1| vs |src2|, return original
    2 => {
      if unsigned(src1[30..0]) <= unsigned(src2[30..0]) then src1 else src2
    },
    // abs_max: compare |src1| vs |src2|, return original
    _ => {
      if unsigned(src1[30..0]) >= unsigned(src2[30..0]) then src1 else src2
    },
  };
  // Phase 2: apply sign control
  match sign_ctl {
    0 => src1[31..31] @ tmp[30..0],  // preserve src1 sign
    1 => tmp,                          // preserve compare result sign
    2 => 0b0 @ tmp[30..0],            // force positive
    _ => 0b1 @ tmp[30..0],            // force negative
  }
}

// Per-element range for f64 (SDM: RangeDP)
val avx_range_f64 : (qword, qword, byte) -> qword
function avx_range_f64(src1, src2, imm) = {
  let op : range(0, 3) = unsigned(imm[1..0]);
  let sign_ctl : range(0, 3) = unsigned(imm[3..2]);
  let tmp : qword = match op {
    0 => __f64_min(src1, src2),
    1 => __f64_max(src1, src2),
    2 => {
      if unsigned(src1[62..0]) <= unsigned(src2[62..0]) then src1 else src2
    },
    _ => {
      if unsigned(src1[62..0]) >= unsigned(src2[62..0]) then src1 else src2
    },
  };
  match sign_ctl {
    0 => src1[63..63] @ tmp[62..0],
    1 => tmp,
    2 => 0b0 @ tmp[62..0],
    _ => 0b1 @ tmp[62..0],
  }
}

val avx_vrangeps_128 : (xmmword, xmmword, byte) -> xmmword
function avx_vrangeps_128(src1, src2, imm) = {
  var result : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    result[(lo + 31)..lo] = avx_range_f32(src1[(lo + 31)..lo], src2[(lo + 31)..lo], imm);
  };
  result
}

val avx_vrangeps_256 : (ymmword, ymmword, byte) -> ymmword
function avx_vrangeps_256(src1, src2, imm) = {
  avx_vrangeps_128(src1[255..128], src2[255..128], imm) @ avx_vrangeps_128(src1[127..0], src2[127..0], imm)
}

val avx_vrangeps_512 : (zmmword, zmmword, byte) -> zmmword
function avx_vrangeps_512(src1, src2, imm) = {
  avx_vrangeps_256(src1[511..256], src2[511..256], imm) @ avx_vrangeps_256(src1[255..0], src2[255..0], imm)
}

val avx_vrangepd_128 : (xmmword, xmmword, byte) -> xmmword
function avx_vrangepd_128(src1, src2, imm) = {
  var result : xmmword = zeros();
  foreach (i from 0 to 1) {
    let lo : range(0, 64) = i * 64;
    result[(lo + 63)..lo] = avx_range_f64(src1[(lo + 63)..lo], src2[(lo + 63)..lo], imm);
  };
  result
}

val avx_vrangepd_256 : (ymmword, ymmword, byte) -> ymmword
function avx_vrangepd_256(src1, src2, imm) = {
  avx_vrangepd_128(src1[255..128], src2[255..128], imm) @ avx_vrangepd_128(src1[127..0], src2[127..0], imm)
}

val avx_vrangepd_512 : (zmmword, zmmword, byte) -> zmmword
function avx_vrangepd_512(src1, src2, imm) = {
  avx_vrangepd_256(src1[511..256], src2[511..256], imm) @ avx_vrangepd_256(src1[255..0], src2[255..0], imm)
}

/* ---- VPBROADCASTMB2Q / VPBROADCASTMW2D: broadcast mask to vector ---- */

val avx_vcvtps2ph_512 : zmmword -> ymmword
function avx_vcvtps2ph_512(src) = {
  avx_vcvtps2ph_256(src[511..256]) @ avx_vcvtps2ph_256(src[255..0])
}

/* ---- Gather: VPGATHERDD/DQ, VGATHERDPS/DPD (dword indices) ---- */
/* ---- Gather: VPGATHERQD/QQ, VGATHERQPS/QPD (qword indices) ---- */

// Compute effective address for one gather element.
// base + sign_extend(index) << scale

val avx_vpclmulqdq_lane : (xmmword, xmmword, byte) -> xmmword
function avx_vpclmulqdq_lane(src1, src2, imm8) = {
  let sel_a : qword = blend64(src1[63..0], src1[127..64], imm8[0..0]);
  let sel_b : qword = blend64(src2[63..0], src2[127..64], imm8[4..4]);
  __pclmulqdq(sel_a, sel_b)
}

val avx_vpclmulqdq_128 : (xmmword, xmmword, byte) -> xmmword
function avx_vpclmulqdq_128(src1, src2, imm8) = {
  avx_vpclmulqdq_lane(src1, src2, imm8)
}

val avx_vpclmulqdq_256 : (ymmword, ymmword, byte) -> ymmword
function avx_vpclmulqdq_256(src1, src2, imm8) = {
  avx_vpclmulqdq_lane(src1[255..128], src2[255..128], imm8) @
  avx_vpclmulqdq_lane(src1[127..0], src2[127..0], imm8)
}

val avx_vpclmulqdq_512 : (zmmword, zmmword, byte) -> zmmword
function avx_vpclmulqdq_512(src1, src2, imm8) = {
  avx_vpclmulqdq_lane(src1[511..384], src2[511..384], imm8) @
  avx_vpclmulqdq_lane(src1[383..256], src2[383..256], imm8) @
  avx_vpclmulqdq_lane(src1[255..128], src2[255..128], imm8) @
  avx_vpclmulqdq_lane(src1[127..0], src2[127..0], imm8)
}


/* ---- VPSHLD/VPSHRD: packed shift double (VBMI2) ---- */

val avx_vpshldw_imm_128 : (xmmword, xmmword, byte) -> xmmword
function avx_vpshldw_imm_128(src1, src2, imm8) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    r[(lo + 15)..lo] = avx_vpshldw_elem(src1[(lo + 15)..lo], src2[(lo + 15)..lo], unsigned(imm8));
  }; r
}

val avx_vpshldw_imm_256 : (ymmword, ymmword, byte) -> ymmword
function avx_vpshldw_imm_256(src1, src2, imm8) = {
  avx_vpshldw_imm_128(src1[255..128], src2[255..128], imm8) @
  avx_vpshldw_imm_128(src1[127..0], src2[127..0], imm8)
}

val avx_vpshldw_imm_512 : (zmmword, zmmword, byte) -> zmmword
function avx_vpshldw_imm_512(src1, src2, imm8) = {
  avx_vpshldw_imm_256(src1[511..256], src2[511..256], imm8) @
  avx_vpshldw_imm_256(src1[255..0], src2[255..0], imm8)
}

val avx_vpshldd_imm_128 : (xmmword, xmmword, byte) -> xmmword
function avx_vpshldd_imm_128(src1, src2, imm8) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    r[(lo + 31)..lo] = avx_vpshldd_elem(src1[(lo + 31)..lo], src2[(lo + 31)..lo], unsigned(imm8));
  }; r
}

val avx_vpshldd_imm_256 : (ymmword, ymmword, byte) -> ymmword
function avx_vpshldd_imm_256(src1, src2, imm8) = {
  avx_vpshldd_imm_128(src1[255..128], src2[255..128], imm8) @
  avx_vpshldd_imm_128(src1[127..0], src2[127..0], imm8)
}

val avx_vpshldd_imm_512 : (zmmword, zmmword, byte) -> zmmword
function avx_vpshldd_imm_512(src1, src2, imm8) = {
  avx_vpshldd_imm_256(src1[511..256], src2[511..256], imm8) @
  avx_vpshldd_imm_256(src1[255..0], src2[255..0], imm8)
}

val avx_vpshldq_imm_128 : (xmmword, xmmword, byte) -> xmmword
function avx_vpshldq_imm_128(src1, src2, imm8) = {
  avx_vpshldq_elem(src1[127..64], src2[127..64], unsigned(imm8)) @
  avx_vpshldq_elem(src1[63..0], src2[63..0], unsigned(imm8))
}

val avx_vpshldq_imm_256 : (ymmword, ymmword, byte) -> ymmword
function avx_vpshldq_imm_256(src1, src2, imm8) = {
  avx_vpshldq_imm_128(src1[255..128], src2[255..128], imm8) @
  avx_vpshldq_imm_128(src1[127..0], src2[127..0], imm8)
}

val avx_vpshldq_imm_512 : (zmmword, zmmword, byte) -> zmmword
function avx_vpshldq_imm_512(src1, src2, imm8) = {
  avx_vpshldq_imm_256(src1[511..256], src2[511..256], imm8) @
  avx_vpshldq_imm_256(src1[255..0], src2[255..0], imm8)
}

// Immediate versions (VPSHRDW/D/Q imm8)

val avx_vpshrdw_imm_128 : (xmmword, xmmword, byte) -> xmmword
function avx_vpshrdw_imm_128(src1, src2, imm8) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    r[(lo + 15)..lo] = avx_vpshrdw_elem(src1[(lo + 15)..lo], src2[(lo + 15)..lo], unsigned(imm8));
  }; r
}

val avx_vpshrdw_imm_256 : (ymmword, ymmword, byte) -> ymmword
function avx_vpshrdw_imm_256(src1, src2, imm8) = {
  avx_vpshrdw_imm_128(src1[255..128], src2[255..128], imm8) @
  avx_vpshrdw_imm_128(src1[127..0], src2[127..0], imm8)
}

val avx_vpshrdw_imm_512 : (zmmword, zmmword, byte) -> zmmword
function avx_vpshrdw_imm_512(src1, src2, imm8) = {
  avx_vpshrdw_imm_256(src1[511..256], src2[511..256], imm8) @
  avx_vpshrdw_imm_256(src1[255..0], src2[255..0], imm8)
}

val avx_vpshrdd_imm_128 : (xmmword, xmmword, byte) -> xmmword
function avx_vpshrdd_imm_128(src1, src2, imm8) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    r[(lo + 31)..lo] = avx_vpshrdd_elem(src1[(lo + 31)..lo], src2[(lo + 31)..lo], unsigned(imm8));
  }; r
}

val avx_vpshrdd_imm_256 : (ymmword, ymmword, byte) -> ymmword
function avx_vpshrdd_imm_256(src1, src2, imm8) = {
  avx_vpshrdd_imm_128(src1[255..128], src2[255..128], imm8) @
  avx_vpshrdd_imm_128(src1[127..0], src2[127..0], imm8)
}

val avx_vpshrdd_imm_512 : (zmmword, zmmword, byte) -> zmmword
function avx_vpshrdd_imm_512(src1, src2, imm8) = {
  avx_vpshrdd_imm_256(src1[511..256], src2[511..256], imm8) @
  avx_vpshrdd_imm_256(src1[255..0], src2[255..0], imm8)
}

val avx_vpshrdq_imm_128 : (xmmword, xmmword, byte) -> xmmword
function avx_vpshrdq_imm_128(src1, src2, imm8) = {
  avx_vpshrdq_elem(src1[127..64], src2[127..64], unsigned(imm8)) @
  avx_vpshrdq_elem(src1[63..0], src2[63..0], unsigned(imm8))
}

val avx_vpshrdq_imm_256 : (ymmword, ymmword, byte) -> ymmword
function avx_vpshrdq_imm_256(src1, src2, imm8) = {
  avx_vpshrdq_imm_128(src1[255..128], src2[255..128], imm8) @
  avx_vpshrdq_imm_128(src1[127..0], src2[127..0], imm8)
}

val avx_vpshrdq_imm_512 : (zmmword, zmmword, byte) -> zmmword
function avx_vpshrdq_imm_512(src1, src2, imm8) = {
  avx_vpshrdq_imm_256(src1[511..256], src2[511..256], imm8) @
  avx_vpshrdq_imm_256(src1[255..0], src2[255..0], imm8)
}

/* ---- VPMADD52LUQ / VPMADD52HUQ: multiply-add unsigned 52-bit (IFMA) ---- */

// Multiply two 52-bit unsigned values (low 52 bits of each qword)
// and produce a 104-bit product. Return low or high 52 bits.

val gf2p8_affine : (byte, qword, byte) -> byte
function gf2p8_affine(src, matrix, imm8) = {
  var r : byte = zeros();
  foreach (i from 0 to 7) {
    // Row i of matrix is at bits [(7-i)*8+7 .. (7-i)*8]
    let row_lo : range(0, 56) = (7 - i) * 8;
    let row : byte = matrix[(row_lo + 7)..row_lo];
    let product : byte = src & row;
    // XOR-reduce (popcount mod 2)
    var bit : bit = bitzero;
    foreach (j from 0 to 7) { if product[j] == bitone then bit = bool_to_bit(bit == bitzero) };
    // XOR with imm8 bit
    r[i] = bool_to_bit(bit != imm8[i]);
  };
  r
}

val avx_gf2p8affineqb_lane : (qword, qword, byte) -> qword
function avx_gf2p8affineqb_lane(src1, matrix, imm8) = {
  var r : qword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 56) = i * 8;
    r[(lo + 7)..lo] = gf2p8_affine(src1[(lo + 7)..lo], matrix, imm8);
  };
  r
}

val avx_gf2p8affineqb_128 : (xmmword, xmmword, byte) -> xmmword
function avx_gf2p8affineqb_128(src1, src2, imm8) = {
  avx_gf2p8affineqb_lane(src1[127..64], src2[127..64], imm8) @
  avx_gf2p8affineqb_lane(src1[63..0], src2[63..0], imm8)
}

val avx_gf2p8affineqb_256 : (ymmword, ymmword, byte) -> ymmword
function avx_gf2p8affineqb_256(src1, src2, imm8) = {
  avx_gf2p8affineqb_128(src1[255..128], src2[255..128], imm8) @
  avx_gf2p8affineqb_128(src1[127..0], src2[127..0], imm8)
}

val avx_gf2p8affineqb_512 : (zmmword, zmmword, byte) -> zmmword
function avx_gf2p8affineqb_512(src1, src2, imm8) = {
  avx_gf2p8affineqb_256(src1[511..256], src2[511..256], imm8) @
  avx_gf2p8affineqb_256(src1[255..0], src2[255..0], imm8)
}

// GF2P8AFFINEINVQB: Same as AFFINEQB but first applies GF(2^8) inverse on src1
// The inverse of 0 is 0 in GF(2^8).

val gf2p8_inv : byte -> byte
function gf2p8_inv(x) = {
  if x == 0x00 then 0x00
  else {
    // Compute x^254 = x^(-1) in GF(2^8) using repeated squaring
    // x^2
    let x2 = gf2p8_mul(x, x);
    // x^3
    let x3 = gf2p8_mul(x2, x);
    // x^6
    let x6 = gf2p8_mul(x3, x3);
    // x^12
    let x12 = gf2p8_mul(x6, x6);
    // x^15 = x^12 * x^3
    let x15 = gf2p8_mul(x12, x3);
    // x^30
    let x30 = gf2p8_mul(x15, x15);
    // x^60
    let x60 = gf2p8_mul(x30, x30);
    // x^63 = x^60 * x^3
    let x63 = gf2p8_mul(x60, x3);
    // x^126
    let x126 = gf2p8_mul(x63, x63);
    // x^252
    let x252 = gf2p8_mul(x126, x126);
    // x^254 = x^252 * x^2
    gf2p8_mul(x252, x2)
  }
}

val avx_gf2p8affineinvqb_lane : (qword, qword, byte) -> qword
function avx_gf2p8affineinvqb_lane(src1, matrix, imm8) = {
  var r : qword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 56) = i * 8;
    let inv_byte = gf2p8_inv(src1[(lo + 7)..lo]);
    r[(lo + 7)..lo] = gf2p8_affine(inv_byte, matrix, imm8);
  };
  r
}

val avx_gf2p8affineinvqb_128 : (xmmword, xmmword, byte) -> xmmword
function avx_gf2p8affineinvqb_128(src1, src2, imm8) = {
  avx_gf2p8affineinvqb_lane(src1[127..64], src2[127..64], imm8) @
  avx_gf2p8affineinvqb_lane(src1[63..0], src2[63..0], imm8)
}

val avx_gf2p8affineinvqb_256 : (ymmword, ymmword, byte) -> ymmword
function avx_gf2p8affineinvqb_256(src1, src2, imm8) = {
  avx_gf2p8affineinvqb_128(src1[255..128], src2[255..128], imm8) @
  avx_gf2p8affineinvqb_128(src1[127..0], src2[127..0], imm8)
}

val avx_gf2p8affineinvqb_512 : (zmmword, zmmword, byte) -> zmmword
function avx_gf2p8affineinvqb_512(src1, src2, imm8) = {
  avx_gf2p8affineinvqb_256(src1[511..256], src2[511..256], imm8) @
  avx_gf2p8affineinvqb_256(src1[255..0], src2[255..0], imm8)
}

// =========================================================================
// VEXP2PS/PD — Approximate 2^x (512-bit only, AVX-512ER / KNL)
// =========================================================================


val dispatch_evex_imm : (range(0, 255), Prefixes) -> unit
function dispatch_evex_imm(op, pfx) = {
  let mp = get_mandatory_prefix(pfx);

  match op {
  // 0F3A 00: VPERMQ (66, W=1) — imm8-controlled qword permute (256/512)
  0 => {
    if mp != MP_66 | not_bool(pfx.vex_w) then raise_UD();
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
    let imm = fetch_byte();
    match pfx.evex_ll {
      2 => write_zmm(dst, avx_vpermq_imm_512(evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem), imm)),
      1 => write_ymm(dst, avx_vpermq_imm_256(evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem), imm)),
      _ => raise_UD(),
    }
  },

  // 0F3A 01: VPERMPD (66, W=1) — imm8-controlled qword permute for FP doubles (256/512)
  // 0F3A 01: VPERMPD (66, W=1) — imm8-controlled qword permute for FP doubles (256/512)
  1 => {
    if mp != MP_66 | not_bool(pfx.vex_w) then raise_UD();
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
    let imm = fetch_byte();
    match pfx.evex_ll {
      2 => write_zmm(dst, avx_vpermq_imm_512(evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem), imm)),
      1 => write_ymm(dst, avx_vpermq_imm_256(evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem), imm)),
      _ => raise_UD(),
    }
  },

  // 0F3A 03: VALIGND (66, W=0) / VALIGNQ (66, W=1)
  // 0F3A 03: VALIGND (66, W=0) / VALIGNQ (66, W=1)
  3 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
    let imm = fetch_byte();
    if pfx.vex_w then {
      // VALIGNQ xmm1/ymm1/zmm1, xmm2/ymm2/zmm2, xmm3/ymm3/zmm3/m128/m256/m512, imm8
      match pfx.evex_ll {
        2 => write_zmm(dst, avx_valignq_512(read_zmm(pfx.evex_vvvvv), evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem), imm)),
        1 => write_ymm(dst, avx_valignq_256(read_ymm(pfx.evex_vvvvv), evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem), imm)),
        _ => write_xmm(dst, avx_valignq_128(read_xmm(pfx.evex_vvvvv), evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem), imm)),
      }
    } else {
      // VALIGND xmm1/ymm1/zmm1, xmm2/ymm2/zmm2, xmm3/ymm3/zmm3/m128/m256/m512, imm8
      match pfx.evex_ll {
        2 => write_zmm(dst, avx_valignd_512(read_zmm(pfx.evex_vvvvv), evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem), imm)),
        1 => write_ymm(dst, avx_valignd_256(read_ymm(pfx.evex_vvvvv), evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem), imm)),
        _ => write_xmm(dst, avx_valignd_128(read_xmm(pfx.evex_vvvvv), evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem), imm)),
      }
    }
  },

  // 0F3A 04: VPERMILPS (66, W=0) — imm8-controlled in-lane dword permute
  // 0F3A 04: VPERMILPS (66, W=0) — imm8-controlled in-lane dword permute
  4 => {
    if mp != MP_66 | pfx.vex_w then raise_UD();
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
    let imm = fetch_byte();
    match pfx.evex_ll {
      2 => write_zmm(dst, avx_vpermilps_imm_512(evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem), imm)),
      1 => write_ymm(dst, avx_vpermilps_imm_256(evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem), imm)),
      _ => write_xmm(dst, avx_vpermilps_imm_128(evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem), imm)),
    }
  },

  // 0F3A 05: VPERMILPD (66, W=1) — imm8-controlled in-lane qword permute
  // 0F3A 05: VPERMILPD (66, W=1) — imm8-controlled in-lane qword permute
  5 => {
    if mp != MP_66 | not_bool(pfx.vex_w) then raise_UD();
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
    let imm = fetch_byte();
    match pfx.evex_ll {
      2 => write_zmm(dst, avx_vpermilpd_imm_512(evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem), imm)),
      1 => write_ymm(dst, avx_vpermilpd_imm_256(evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem), imm)),
      _ => write_xmm(dst, avx_vpermilpd_imm_128(evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem), imm)),
    }
  },

  // 0F3A 0F: VPALIGNR (66) — byte-align concatenation per 128-bit lane
  // 0F3A 0F: VPALIGNR (66) — byte-align concatenation per 128-bit lane
  15 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let imm = fetch_byte();
    match pfx.evex_ll {
      2 => write_zmm(dst, avx_palignr_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx), imm)),
      1 => write_ymm(dst, avx_palignr_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx), imm)),
      _ => write_xmm(dst, avx_palignr_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx), imm)),
    }
  },

  // 0F3A 14: VPEXTRB (66) — extract byte from XMM to GPR/mem
  // 0F3A 14: VPEXTRB (66) — extract byte from XMM to GPR/mem
  20 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let src = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, 1);
    let imm = fetch_byte();
    let sel : range(0, 15) = unsigned(imm[3..0]);
    let src_xmm = read_xmm(src);
    let lo : range(0, 120) = sel * 8;
    let extracted_byte : byte = src_xmm[(lo + 7)..lo];
    match rm {
      RM_reg(_) => {
        write_gpr32(modrm_rm_reg(modrm, pfx), zero_extend(extracted_byte))
      },
      RM_mem(addr) => {
        mem_write8(fixup_addr(addr), extracted_byte)
      },
    }
  },

  // 0F3A 15: VPEXTRW (66) — extract word from XMM to GPR/mem
  // 0F3A 15: VPEXTRW (66) — extract word from XMM to GPR/mem
  21 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let src = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, 2);
    let imm = fetch_byte();
    let sel : range(0, 7) = unsigned(imm[2..0]);
    let src_xmm = read_xmm(src);
    let lo : range(0, 112) = sel * 16;
    let extracted_word : word = src_xmm[(lo + 15)..lo];
    match rm {
      RM_reg(_) => {
        write_gpr32(modrm_rm_reg(modrm, pfx), zero_extend(extracted_word))
      },
      RM_mem(addr) => {
        mem_write16(fixup_addr(addr), extracted_word)
      },
    }
  },

  // 0F3A 16: VPEXTRD (66, W=0) / VPEXTRQ (66, W=1) — extract dword/qword from XMM
  // 0F3A 16: VPEXTRD (66, W=0) / VPEXTRQ (66, W=1) — extract dword/qword from XMM
  22 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let src = evex_reg_idx(modrm, pfx);
    let src_xmm = read_xmm(src);
    if pfx.vex_w then {
      // VPEXTRQ: imm8[0] selects qword
      let rm = decode_rm_evex(modrm, pfx, 8);
      let imm = fetch_byte();
      let sel : range(0, 1) = unsigned(imm[0..0]);
      let lo : range(0, 64) = sel * 64;
      let extracted : qword = src_xmm[(lo + 63)..lo];
      match rm {
        RM_reg(_) => {
          write_gpr64(modrm_rm_reg(modrm, pfx), extracted)
        },
        RM_mem(addr) => {
          mem_write64(fixup_addr(addr), extracted)
        },
      }
    } else {
      // VPEXTRD: imm8[1:0] selects dword
      let rm = decode_rm_evex(modrm, pfx, 4);
      let imm = fetch_byte();
      let sel : range(0, 3) = unsigned(imm[1..0]);
      let lo : range(0, 96) = sel * 32;
      let extracted : dword = src_xmm[(lo + 31)..lo];
      match rm {
        RM_reg(_) => {
          write_gpr32(modrm_rm_reg(modrm, pfx), extracted)
        },
        RM_mem(addr) => {
          mem_write32(fixup_addr(addr), extracted)
        },
      }
    }
  },

  // 0F3A 17: VEXTRACTPS (66) — extract single-precision FP from XMM to GPR/mem32
  // 0F3A 17: VEXTRACTPS (66) — extract single-precision FP from XMM to GPR/mem32
  23 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let src = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, 4);
    let imm = fetch_byte();
    let sel : range(0, 3) = unsigned(imm[1..0]);
    let src_xmm = read_xmm(src);
    let lo : range(0, 96) = sel * 32;
    let extracted : dword = src_xmm[(lo + 31)..lo];
    match rm {
      RM_reg(_) => {
        write_gpr32(modrm_rm_reg(modrm, pfx), extracted)
      },
      RM_mem(addr) => {
        mem_write32(fixup_addr(addr), extracted)
      },
    }
  },

  // 0F3A 18: VINSERTF32X4 (66, W=0) / VINSERTF64X2 (66, W=1) — insert 128-bit into 256/512
  // 0F3A 18: VINSERTF32X4 (66, W=0) / VINSERTF64X2 (66, W=1) — insert 128-bit into 256/512
  24 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, 16);
    let src2 : xmmword = evex_src_xmm(modrm, rm, pfx);
    let imm = fetch_byte();
    match pfx.evex_ll {
      2 => {
        // 512-bit: imm8[1:0] selects which 128-bit lane
        var result = read_zmm(pfx.evex_vvvvv);
        let sel : range(0, 3) = unsigned(imm[1..0]);
        match sel {
          0 => result[127..0] = src2,
          1 => result[255..128] = src2,
          2 => result[383..256] = src2,
          _ => result[511..384] = src2,
        };
        write_zmm(dst, result)
      },
      1 => {
        // 256-bit: imm8[0] selects which 128-bit lane
        var result = read_ymm(pfx.evex_vvvvv);
        if imm[0] == bitzero then result[127..0] = src2
        else result[255..128] = src2;
        write_ymm(dst, result)
      },
      _ => raise_UD(),
    }
  },

  // 0F3A 19: VEXTRACTF32X4 (66, W=0) / VEXTRACTF64X2 (66, W=1) — extract 128-bit from 256/512
  // 0F3A 19: VEXTRACTF32X4 (66, W=0) / VEXTRACTF64X2 (66, W=1) — extract 128-bit from 256/512
  25 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let src = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, 16);
    let imm = fetch_byte();
    match pfx.evex_ll {
      2 => {
        let src_zmm = read_zmm(src);
        let sel : range(0, 3) = unsigned(imm[1..0]);
        let extracted : xmmword = match sel {
          0 => src_zmm[127..0],
          1 => src_zmm[255..128],
          2 => src_zmm[383..256],
          _ => src_zmm[511..384],
        };
        match rm {
          RM_reg(_) => write_xmm(evex_rm_reg_idx(modrm, pfx), extracted),
          RM_mem(addr) => mem_write128(fixup_addr(addr), extracted),
        }
      },
      1 => {
        let src_ymm = read_ymm(src);
        let extracted : xmmword = if imm[0] == bitzero then src_ymm[127..0] else src_ymm[255..128];
        match rm {
          RM_reg(_) => write_xmm(evex_rm_reg_idx(modrm, pfx), extracted),
          RM_mem(addr) => mem_write128(fixup_addr(addr), extracted),
        }
      },
      _ => raise_UD(),
    }
  },

  // 0F3A 1A: VINSERTF32X8 (66, W=0) / VINSERTF64X4 (66, W=1) — insert 256-bit into 512
  // 0F3A 1A: VINSERTF32X8 (66, W=0) / VINSERTF64X4 (66, W=1) — insert 256-bit into 512
  26 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, 32);
    let src2 : ymmword = evex_src_ymm(modrm, rm, pfx);
    let imm = fetch_byte();
    match pfx.evex_ll {
      2 => {
        // 512-bit only: imm8[0] selects which 256-bit half
        var result = read_zmm(pfx.evex_vvvvv);
        if imm[0] == bitzero then result[255..0] = src2
        else result[511..256] = src2;
        write_zmm(dst, result)
      },
      _ => raise_UD(),
    }
  },

  // 0F3A 1B: VEXTRACTF32X8 (66, W=0) / VEXTRACTF64X4 (66, W=1) — extract 256-bit from 512
  // 0F3A 1B: VEXTRACTF32X8 (66, W=0) / VEXTRACTF64X4 (66, W=1) — extract 256-bit from 512
  27 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let src = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, 32);
    let imm = fetch_byte();
    match pfx.evex_ll {
      2 => {
        let src_zmm = read_zmm(src);
        let extracted : ymmword = if imm[0] == bitzero then src_zmm[255..0] else src_zmm[511..256];
        match rm {
          RM_reg(_) => write_ymm(evex_rm_reg_idx(modrm, pfx), extracted),
          RM_mem(addr) => mem_write256(fixup_addr(addr), extracted),
        }
      },
      _ => raise_UD(),
    }
  },

  // 0F3A 1D: VCVTPS2PH (66, W=0) — convert FP32 to FP16 with imm8 rounding
  29 => {
    if mp != MP_66 | pfx.rex_w then raise_UD();
    let modrm = fetch_byte();
    let src = evex_reg_idx(modrm, pfx);
    match pfx.evex_ll {
      2 => { let rm = decode_rm_evex(modrm, pfx, 32);
             let _imm = fetch_byte();
             let res = avx_vcvtps2ph_512(read_zmm(src));
             match rm { RM_reg(_) => write_ymm(evex_rm_reg_idx(modrm, pfx), res),
                         RM_mem(addr) => { mem_write256(fixup_addr(addr), res) } } },
      1 => { let rm = decode_rm_evex(modrm, pfx, 16);
             let _imm = fetch_byte();
             let res = avx_vcvtps2ph_256(read_ymm(src));
             match rm { RM_reg(_) => write_xmm(evex_rm_reg_idx(modrm, pfx), res),
                         RM_mem(addr) => { mem_write128(fixup_addr(addr), res) } } },
      _ => { let rm = decode_rm_evex(modrm, pfx, 8);
             let _imm = fetch_byte();
             let res = avx_vcvtps2ph_128(read_xmm(src));
             match rm { RM_reg(_) => write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)),
                         RM_mem(addr) => { mem_write64(fixup_addr(addr), res) } } },
    }
  },

  // 0F3A 1E: VPCMPUD (66, W=0) / VPCMPUQ (66, W=1) — unsigned dword/qword compare → kmask
  // 0F3A 1E: VPCMPUD (66, W=0) / VPCMPUQ (66, W=1) — unsigned dword/qword compare → kmask
  30 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst_k : range(0, 7) = unsigned(modrm[5..3]);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
    let imm = fetch_byte();
    let pred : range(0, 7) = unsigned(imm[2..0]);
    if pfx.rex_w then {
      // VPCMPUQ (m64bcst)
      match pfx.evex_ll {
        2 => {
          let mask : byte = avx_pcmpuq_512(read_zmm(pfx.evex_vvvvv), evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem), pred);
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask)
        },
        1 => {
          let mask : byte = avx_pcmpuq_256(read_ymm(pfx.evex_vvvvv), evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem), pred);
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask)
        },
        _ => {
          let mask : byte = avx_pcmpuq_128(read_xmm(pfx.evex_vvvvv), evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem), pred);
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask)
        },
      }
    } else {
      // VPCMPUD (m32bcst)
      match pfx.evex_ll {
        2 => {
          let mask : word = avx_pcmpud_512(read_zmm(pfx.evex_vvvvv), evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem), pred);
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask)
        },
        1 => {
          let mask : byte = avx_pcmpud_256(read_ymm(pfx.evex_vvvvv), evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem), pred);
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask)
        },
        _ => {
          let mask : byte = avx_pcmpud_128(read_xmm(pfx.evex_vvvvv), evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem), pred);
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask)
        },
      }
    }
  },

  // 0F3A 1F: VPCMPD (66, W=0) / VPCMPQ (66, W=1) — signed dword/qword compare → kmask
  // 0F3A 1F: VPCMPD (66, W=0) / VPCMPQ (66, W=1) — signed dword/qword compare → kmask
  31 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst_k : range(0, 7) = unsigned(modrm[5..3]);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
    let imm = fetch_byte();
    let pred : range(0, 7) = unsigned(imm[2..0]);
    if pfx.rex_w then {
      // VPCMPQ (m64bcst)
      match pfx.evex_ll {
        2 => {
          let mask : byte = avx_pcmpq_512(read_zmm(pfx.evex_vvvvv), evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem), pred);
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask)
        },
        1 => {
          let mask : byte = avx_pcmpq_256(read_ymm(pfx.evex_vvvvv), evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem), pred);
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask)
        },
        _ => {
          let mask : byte = avx_pcmpq_128(read_xmm(pfx.evex_vvvvv), evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem), pred);
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask)
        },
      }
    } else {
      // VPCMPD (m32bcst)
      match pfx.evex_ll {
        2 => {
          let mask : word = avx_pcmpd_512(read_zmm(pfx.evex_vvvvv), evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem), pred);
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask)
        },
        1 => {
          let mask : byte = avx_pcmpd_256(read_ymm(pfx.evex_vvvvv), evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem), pred);
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask)
        },
        _ => {
          let mask : byte = avx_pcmpd_128(read_xmm(pfx.evex_vvvvv), evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem), pred);
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask)
        },
      }
    }
  },

  // 0F3A 25: VPTERNLOGD (66, W=0) / VPTERNLOGQ (66, W=1)
  // 0F3A 25: VPTERNLOGD (66, W=0) / VPTERNLOGQ (66, W=1)
  37 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
    let imm = fetch_byte();
    if pfx.rex_w then {
      // VPTERNLOGQ (m64bcst)
      match pfx.evex_ll {
        2 => {
          let a = read_zmm(dst);
          let b = read_zmm(pfx.evex_vvvvv);
          let c = evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem);
          write_zmm(dst, vpternlog_512(a, b, c, imm))
        },
        1 => {
          let a = read_ymm(dst);
          let b = read_ymm(pfx.evex_vvvvv);
          let c = evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem);
          write_ymm(dst, vpternlog_256(a, b, c, imm))
        },
        _ => {
          let a = read_xmm(dst);
          let b = read_xmm(pfx.evex_vvvvv);
          let c = evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem);
          write_xmm(dst, vpternlog_128(a, b, c, imm))
        },
      }
    } else {
      // VPTERNLOGD (m32bcst)
      match pfx.evex_ll {
        2 => {
          let a = read_zmm(dst);
          let b = read_zmm(pfx.evex_vvvvv);
          let c = evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem);
          write_zmm(dst, vpternlog_512(a, b, c, imm))
        },
        1 => {
          let a = read_ymm(dst);
          let b = read_ymm(pfx.evex_vvvvv);
          let c = evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem);
          write_ymm(dst, vpternlog_256(a, b, c, imm))
        },
        _ => {
          let a = read_xmm(dst);
          let b = read_xmm(pfx.evex_vvvvv);
          let c = evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem);
          write_xmm(dst, vpternlog_128(a, b, c, imm))
        },
      }
    }
  },

  // 0F3A 20: VPINSRB (66) — insert byte from GPR/mem into XMM
  // 0F3A 20: VPINSRB (66) — insert byte from GPR/mem into XMM
  32 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, 1);
    let byte_val : byte = match rm {
      RM_reg(_) => read_gpr32(modrm_rm_reg(modrm, pfx))[7..0],
      RM_mem(addr) => mem_read8(fixup_addr(addr)),
    };
    let imm = fetch_byte();
    let sel : range(0, 15) = unsigned(imm[3..0]);
    var result = read_xmm(pfx.evex_vvvvv);
    let lo : range(0, 120) = sel * 8;
    result[(lo + 7)..lo] = byte_val;
    write_xmm(dst, result)
  },

  // 0F3A 21: VINSERTPS (66, W=0) — insert single-precision from XMM/mem into XMM
  // 0F3A 21: VINSERTPS (66, W=0) — insert single-precision from XMM/mem into XMM
  33 => {
    if mp != MP_66 | pfx.vex_w then raise_UD();
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, 4);
    let imm = fetch_byte();
    // For register source: imm8[7:6] selects which float from src
    // For memory source: always reads a single 32-bit float
    let src_float : dword = match rm {
      RM_reg(_) => {
        let src_xmm = read_xmm(evex_rm_reg_idx(modrm, pfx));
        let count_s : range(0, 3) = unsigned(imm[7..6]);
        let slo : range(0, 96) = count_s * 32;
        src_xmm[(slo + 31)..slo]
      },
      RM_mem(addr) => mem_read32(fixup_addr(addr)),
    };
    // imm8[5:4] selects destination float position
    let count_d : range(0, 3) = unsigned(imm[5..4]);
    let dlo : range(0, 96) = count_d * 32;
    var result = read_xmm(pfx.evex_vvvvv);
    result[(dlo + 31)..dlo] = src_float;
    // imm8[3:0] = zero mask for each float (branchless)
    result[31..0]   = result[31..0]   & sign_extend(~(imm[0..0]));
    result[63..32]  = result[63..32]  & sign_extend(~(imm[1..1]));
    result[95..64]  = result[95..64]  & sign_extend(~(imm[2..2]));
    result[127..96] = result[127..96] & sign_extend(~(imm[3..3]));
    write_xmm(dst, result)
  },

  // 0F3A 22: VPINSRD (66, W=0) / VPINSRQ (66, W=1) — insert dword/qword from GPR/mem into XMM
  // 0F3A 22: VPINSRD (66, W=0) / VPINSRQ (66, W=1) — insert dword/qword from GPR/mem into XMM
  34 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    if pfx.vex_w then {
      // VPINSRQ: imm8[0] selects qword position
      let rm = decode_rm_evex(modrm, pfx, 8);
      let qword_val : qword = match rm {
        RM_reg(_) => read_gpr64(modrm_rm_reg(modrm, pfx)),
        RM_mem(addr) => mem_read64(fixup_addr(addr)),
      };
      let imm = fetch_byte();
      let sel : range(0, 1) = unsigned(imm[0..0]);
      var result = read_xmm(pfx.evex_vvvvv);
      let lo : range(0, 64) = sel * 64;
      result[(lo + 63)..lo] = qword_val;
      write_xmm(dst, result)
    } else {
      // VPINSRD: imm8[1:0] selects dword position
      let rm = decode_rm_evex(modrm, pfx, 4);
      let dword_val : dword = match rm {
        RM_reg(_) => read_gpr32(modrm_rm_reg(modrm, pfx)),
        RM_mem(addr) => mem_read32(fixup_addr(addr)),
      };
      let imm = fetch_byte();
      let sel : range(0, 3) = unsigned(imm[1..0]);
      var result = read_xmm(pfx.evex_vvvvv);
      let lo : range(0, 96) = sel * 32;
      result[(lo + 31)..lo] = dword_val;
      write_xmm(dst, result)
    }
  },

  // 0F3A 38: VINSERTI32X4 (66, W=0) / VINSERTI64X2 (66, W=1) — insert 128-bit (integer) into 256/512
  // 0F3A 38: VINSERTI32X4 (66, W=0) / VINSERTI64X2 (66, W=1) — insert 128-bit (integer) into 256/512
  56 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, 16);
    let src2 : xmmword = evex_src_xmm(modrm, rm, pfx);
    let imm = fetch_byte();
    match pfx.evex_ll {
      2 => {
        var result = read_zmm(pfx.evex_vvvvv);
        let sel : range(0, 3) = unsigned(imm[1..0]);
        match sel {
          0 => result[127..0] = src2,
          1 => result[255..128] = src2,
          2 => result[383..256] = src2,
          _ => result[511..384] = src2,
        };
        write_zmm(dst, result)
      },
      1 => {
        var result = read_ymm(pfx.evex_vvvvv);
        if imm[0] == bitzero then result[127..0] = src2
        else result[255..128] = src2;
        write_ymm(dst, result)
      },
      _ => raise_UD(),
    }
  },

  // 0F3A 39: VEXTRACTI32X4 (66, W=0) / VEXTRACTI64X2 (66, W=1) — extract 128-bit from 256/512
  // 0F3A 39: VEXTRACTI32X4 (66, W=0) / VEXTRACTI64X2 (66, W=1) — extract 128-bit from 256/512
  57 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let src = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, 16);
    let imm = fetch_byte();
    match pfx.evex_ll {
      2 => {
        let src_zmm = read_zmm(src);
        let sel : range(0, 3) = unsigned(imm[1..0]);
        let extracted : xmmword = match sel {
          0 => src_zmm[127..0],
          1 => src_zmm[255..128],
          2 => src_zmm[383..256],
          _ => src_zmm[511..384],
        };
        match rm {
          RM_reg(_) => write_xmm(evex_rm_reg_idx(modrm, pfx), extracted),
          RM_mem(addr) => mem_write128(fixup_addr(addr), extracted),
        }
      },
      1 => {
        let src_ymm = read_ymm(src);
        let extracted : xmmword = if imm[0] == bitzero then src_ymm[127..0] else src_ymm[255..128];
        match rm {
          RM_reg(_) => write_xmm(evex_rm_reg_idx(modrm, pfx), extracted),
          RM_mem(addr) => mem_write128(fixup_addr(addr), extracted),
        }
      },
      _ => raise_UD(),
    }
  },

  // 0F3A 3A: VINSERTI32X8 (66, W=0) / VINSERTI64X4 (66, W=1) — insert 256-bit into 512
  // 0F3A 3A: VINSERTI32X8 (66, W=0) / VINSERTI64X4 (66, W=1) — insert 256-bit into 512
  58 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, 32);
    let src2 : ymmword = evex_src_ymm(modrm, rm, pfx);
    let imm = fetch_byte();
    match pfx.evex_ll {
      2 => {
        var result = read_zmm(pfx.evex_vvvvv);
        if imm[0] == bitzero then result[255..0] = src2
        else result[511..256] = src2;
        write_zmm(dst, result)
      },
      _ => raise_UD(),
    }
  },

  // 0F3A 3B: VEXTRACTI32X8 (66, W=0) / VEXTRACTI64X4 (66, W=1) — extract 256-bit from 512
  // 0F3A 3B: VEXTRACTI32X8 (66, W=0) / VEXTRACTI64X4 (66, W=1) — extract 256-bit from 512
  59 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let src = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, 32);
    let imm = fetch_byte();
    match pfx.evex_ll {
      2 => {
        let src_zmm = read_zmm(src);
        let extracted : ymmword = if imm[0] == bitzero then src_zmm[255..0] else src_zmm[511..256];
        match rm {
          RM_reg(_) => write_ymm(evex_rm_reg_idx(modrm, pfx), extracted),
          RM_mem(addr) => mem_write256(fixup_addr(addr), extracted),
        }
      },
      _ => raise_UD(),
    }
  },

  // 0F3A 3E: VPCMPUB (66, W=0) / VPCMPUW (66, W=1) — unsigned byte/word compare → kmask
  // 0F3A 3E: VPCMPUB (66, W=0) / VPCMPUW (66, W=1) — unsigned byte/word compare → kmask
  62 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst_k : range(0, 7) = unsigned(modrm[5..3]);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let imm = fetch_byte();
    let pred : range(0, 7) = unsigned(imm[2..0]);
    if pfx.rex_w then {
      // VPCMPUW (word)
      match pfx.evex_ll {
        2 => {
          let mask : dword = avx_pcmpuw_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx), pred);
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask)
        },
        1 => {
          let mask : word = avx_pcmpuw_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx), pred);
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask)
        },
        _ => {
          let mask : byte = avx_pcmpuw_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx), pred);
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask)
        },
      }
    } else {
      // VPCMPUB (byte)
      match pfx.evex_ll {
        2 => {
          let mask = avx_pcmpub_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx), pred);
          let k_mask : qword = if pfx.evex_aaa == 0 then mask else mask & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask)
        },
        1 => {
          let mask : dword = avx_pcmpub_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx), pred);
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask)
        },
        _ => {
          let mask : word = avx_pcmpub_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx), pred);
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask)
        },
      }
    }
  },

  // 0F3A 3F: VPCMPB (66, W=0) / VPCMPW (66, W=1) — signed byte/word compare → kmask
  // 0F3A 3F: VPCMPB (66, W=0) / VPCMPW (66, W=1) — signed byte/word compare → kmask
  63 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst_k : range(0, 7) = unsigned(modrm[5..3]);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let imm = fetch_byte();
    let pred : range(0, 7) = unsigned(imm[2..0]);
    if pfx.rex_w then {
      // VPCMPW (word)
      match pfx.evex_ll {
        2 => {
          let mask : dword = avx_pcmpw_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx), pred);
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask)
        },
        1 => {
          let mask : word = avx_pcmpw_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx), pred);
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask)
        },
        _ => {
          let mask : byte = avx_pcmpw_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx), pred);
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask)
        },
      }
    } else {
      // VPCMPB (byte)
      match pfx.evex_ll {
        2 => {
          let mask = avx_pcmpb_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx), pred);
          let k_mask : qword = if pfx.evex_aaa == 0 then mask else mask & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask)
        },
        1 => {
          let mask : dword = avx_pcmpb_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx), pred);
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask)
        },
        _ => {
          let mask : word = avx_pcmpb_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx), pred);
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask)
        },
      }
    }
  },

  // 0F3A 08: VRNDSCALEPS (66, W=0) / VRNDSCALEPH (NP, W=0)
  8 => {
    if pfx.vex_w then raise_UD();
    match mp {
      MP_66 => {
        let modrm = fetch_byte();
        let dst = evex_reg_idx(modrm, pfx);
        let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
        let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
        let imm = fetch_byte();
        match pfx.evex_ll {
          2 => write_zmm(dst, avx_vrndscaleps_512(evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem), imm)),
          1 => write_ymm(dst, avx_vrndscaleps_256(evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem), imm)),
          _ => write_xmm(dst, avx_vrndscaleps_128(evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem), imm)),
        }
      },
      MP_NONE => {
        // VRNDSCALEPH: packed FP16 round
        let modrm = fetch_byte();
        let dst = evex_reg_idx(modrm, pfx);
        let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
        let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
        let imm = fetch_byte();
        match pfx.evex_ll {
          2 => {
            let src = evex_bcast_src_f16_zmm(modrm, rm, pfx, is_mem);
            let r = vrndscaleph_zmm(src, imm);
            write_zmm(dst, apply_writemask_ph_zmm(r, read_zmm(dst), evex_get_mask32(pfx), pfx.evex_z))
          },
          1 => {
            let src = evex_bcast_src_f16_ymm(modrm, rm, pfx, is_mem);
            let r = vrndscaleph_ymm(src, imm);
            write_ymm(dst, apply_writemask_ph_ymm(r, read_ymm(dst), evex_get_mask16(pfx), pfx.evex_z))
          },
          _ => {
            let src = evex_bcast_src_f16_xmm(modrm, rm, pfx, is_mem);
            let r = vrndscaleph_xmm(src, imm);
            write_xmm(dst, apply_writemask_ph_xmm(r, read_xmm(dst), evex_get_mask8(pfx), pfx.evex_z))
          },
        }
      },
      _ => raise_UD(),
    }
  },

  // 0F3A 09: VRNDSCALEPD (66, W=1) — round packed double-precision
  // 0F3A 09: VRNDSCALEPD (66, W=1) — round packed double-precision
  9 => {
    if mp != MP_66 | not_bool(pfx.vex_w) then raise_UD();
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
    let imm = fetch_byte();
    match pfx.evex_ll {
      2 => write_zmm(dst, avx_vrndscalepd_512(evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem), imm)),
      1 => write_ymm(dst, avx_vrndscalepd_256(evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem), imm)),
      _ => write_xmm(dst, avx_vrndscalepd_128(evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem), imm)),
    }
  },

  // 0F3A 0A: VRNDSCALESS (66, W=0) / VRNDSCALESH (NP, W=0)
  10 => {
    if pfx.vex_w then raise_UD();
    match mp {
      MP_66 => {
        let modrm = fetch_byte();
        let dst = evex_reg_idx(modrm, pfx);
        let rm = decode_rm_evex(modrm, pfx, 4);
        let imm = fetch_byte();
        let src1 = read_xmm(pfx.evex_vvvvv);
        let src2 = evex_src_xmm(modrm, rm, pfx);
        let r = __f32_rndscale(src2[31..0], imm);
        write_xmm(dst, src1[127..32] @ r)
      },
      MP_NONE => {
        // VRNDSCALESH: scalar FP16 round
        let modrm = fetch_byte();
        let dst = evex_reg_idx(modrm, pfx);
        let rm = decode_rm_evex(modrm, pfx, 2);
        let imm = fetch_byte();
        let src1 = read_xmm(pfx.evex_vvvvv);
        let src2 = evex_src_xmm(modrm, rm, pfx);
        let r : word = __f16_rndscale(src2[15..0], imm);
        write_xmm(dst, src1[127..16] @ r)
      },
      _ => raise_UD(),
    }
  },

  // 0F3A 0B: VRNDSCALESD (66, W=1) — round scalar double-precision
  // 0F3A 0B: VRNDSCALESD (66, W=1) — round scalar double-precision
  11 => {
    if mp != MP_66 | not_bool(pfx.vex_w) then raise_UD();
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, 8);
    let imm = fetch_byte();
    let src1 = read_xmm(pfx.evex_vvvvv);
    let src2 = evex_src_xmm(modrm, rm, pfx);
    let r = __f64_rndscale(src2[63..0], imm);
    write_xmm(dst, src1[127..64] @ r)
  },

  // 0F3A 23: VSHUFF32X4 (66, W=0) / VSHUFF64X2 (66, W=1) — shuffle 128-bit lanes (FP)
  // 0F3A 23: VSHUFF32X4 (66, W=0) / VSHUFF64X2 (66, W=1) — shuffle 128-bit lanes (FP)
  35 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
    let imm = fetch_byte();
    if pfx.vex_w then {
      match pfx.evex_ll {
        2 => write_zmm(dst, avx_shuf_f32x4_512(read_zmm(pfx.evex_vvvvv), evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem), imm)),
        1 => write_ymm(dst, avx_shuf_f32x4_256(read_ymm(pfx.evex_vvvvv), evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem), imm)),
        _ => raise_UD(),
      }
    } else {
      match pfx.evex_ll {
        2 => write_zmm(dst, avx_shuf_f32x4_512(read_zmm(pfx.evex_vvvvv), evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem), imm)),
        1 => write_ymm(dst, avx_shuf_f32x4_256(read_ymm(pfx.evex_vvvvv), evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem), imm)),
        _ => raise_UD(),
      }
    }
  },

  // 0F3A 26: VGETMANTPS (66, W=0) / VGETMANTPD (66, W=1) / VGETMANTPH (NP, W=0)
  38 => {
    match mp {
      MP_66 => {
        let modrm = fetch_byte();
        let dst = evex_reg_idx(modrm, pfx);
        let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
        let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
        let imm = fetch_byte();
        if pfx.vex_w then {
          // VGETMANTPD xmm1/ymm1/zmm1, xmm2/ymm2/zmm2/m128/m256/m512, imm8
          match pfx.evex_ll {
            2 => write_zmm(dst, avx_vgetmantpd_512(evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem), imm)),
            1 => write_ymm(dst, avx_vgetmantpd_256(evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem), imm)),
            _ => write_xmm(dst, avx_vgetmantpd_128(evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem), imm)),
          }
        } else {
          // VGETMANTPS xmm1/ymm1/zmm1, xmm2/ymm2/zmm2/m128/m256/m512, imm8
          match pfx.evex_ll {
            2 => write_zmm(dst, avx_vgetmantps_512(evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem), imm)),
            1 => write_ymm(dst, avx_vgetmantps_256(evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem), imm)),
            _ => write_xmm(dst, avx_vgetmantps_128(evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem), imm)),
          }
        }
      },
      MP_NONE => {
        // VGETMANTPH: packed FP16 extract mantissa
        if pfx.vex_w then raise_UD();
        let modrm = fetch_byte();
        let dst = evex_reg_idx(modrm, pfx);
        let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
        let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
        let imm = fetch_byte();
        match pfx.evex_ll {
          2 => {
            let src = evex_bcast_src_f16_zmm(modrm, rm, pfx, is_mem);
            let r = vgetmantph_zmm(src, imm);
            write_zmm(dst, apply_writemask_ph_zmm(r, read_zmm(dst), evex_get_mask32(pfx), pfx.evex_z))
          },
          1 => {
            let src = evex_bcast_src_f16_ymm(modrm, rm, pfx, is_mem);
            let r = vgetmantph_ymm(src, imm);
            write_ymm(dst, apply_writemask_ph_ymm(r, read_ymm(dst), evex_get_mask16(pfx), pfx.evex_z))
          },
          _ => {
            let src = evex_bcast_src_f16_xmm(modrm, rm, pfx, is_mem);
            let r = vgetmantph_xmm(src, imm);
            write_xmm(dst, apply_writemask_ph_xmm(r, read_xmm(dst), evex_get_mask8(pfx), pfx.evex_z))
          },
        }
      },
      _ => raise_UD(),
    }
  },

  // 0F3A 27: VGETMANTSS (66, W=0) / VGETMANTSD (66, W=1) / VGETMANTSH (NP, W=0)
  39 => {
    match mp {
      MP_66 => {
        let modrm = fetch_byte();
        let dst = evex_reg_idx(modrm, pfx);
        let rm = decode_rm_evex(modrm, pfx, if pfx.vex_w then 8 else 4);
        let imm = fetch_byte();
        let src1 = read_xmm(pfx.evex_vvvvv);
        let src2 = evex_src_xmm(modrm, rm, pfx);
        if pfx.vex_w then {
          let r = __f64_getmant(src2[63..0], imm);
          write_xmm(dst, src1[127..64] @ r)
        } else {
          let r = __f32_getmant(src2[31..0], imm);
          write_xmm(dst, src1[127..32] @ r)
        }
      },
      MP_NONE => {
        // VGETMANTSH: scalar FP16 extract mantissa
        if pfx.vex_w then raise_UD();
        let modrm = fetch_byte();
        let dst = evex_reg_idx(modrm, pfx);
        let rm = decode_rm_evex(modrm, pfx, 2);
        let imm = fetch_byte();
        let src1 = read_xmm(pfx.evex_vvvvv);
        let src2 = evex_src_xmm(modrm, rm, pfx);
        let r : word = __f16_getmant(src2[15..0], imm);
        write_xmm(dst, src1[127..16] @ r)
      },
      _ => raise_UD(),
    }
  },

  // 0F3A 42: VDBPSADBW (66, W=0) — double block packed sum of absolute differences
  // 0F3A 42: VDBPSADBW (66, W=0) — double block packed sum of absolute differences
  66 => {
    if mp != MP_66 | pfx.vex_w then raise_UD();
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let imm = fetch_byte();
    match pfx.evex_ll {
      2 => write_zmm(dst, avx_vdbpsadbw_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx), imm)),
      1 => write_ymm(dst, avx_vdbpsadbw_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx), imm)),
      _ => write_xmm(dst, avx_vdbpsadbw_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx), imm)),
    }
  },

  // 0F3A 43: VSHUFI32X4 (66, W=0) / VSHUFI64X2 (66, W=1) — shuffle 128-bit lanes (integer)
  // 0F3A 43: VSHUFI32X4 (66, W=0) / VSHUFI64X2 (66, W=1) — shuffle 128-bit lanes (integer)
  67 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
    let imm = fetch_byte();
    if pfx.vex_w then {
      match pfx.evex_ll {
        2 => write_zmm(dst, avx_shuf_f32x4_512(read_zmm(pfx.evex_vvvvv), evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem), imm)),
        1 => write_ymm(dst, avx_shuf_f32x4_256(read_ymm(pfx.evex_vvvvv), evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem), imm)),
        _ => raise_UD(),
      }
    } else {
      match pfx.evex_ll {
        2 => write_zmm(dst, avx_shuf_f32x4_512(read_zmm(pfx.evex_vvvvv), evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem), imm)),
        1 => write_ymm(dst, avx_shuf_f32x4_256(read_ymm(pfx.evex_vvvvv), evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem), imm)),
        _ => raise_UD(),
      }
    }
  },

  // 0F3A 44: VPCLMULQDQ (66) — carry-less multiply per 128-bit lane [VPCLMULQDQ]
  // 0F3A 44: VPCLMULQDQ (66) — carry-less multiply per 128-bit lane [VPCLMULQDQ]
  68 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let imm = fetch_byte();
    let src1_idx = pfx.evex_vvvvv;
    match pfx.evex_ll {
      2 => write_zmm(dst, avx_vpclmulqdq_512(read_zmm(src1_idx), evex_src_zmm(modrm, rm, pfx), imm)),
      1 => write_ymm(dst, avx_vpclmulqdq_256(read_ymm(src1_idx), evex_src_ymm(modrm, rm, pfx), imm)),
      _ => write_xmm(dst, avx_vpclmulqdq_128(read_xmm(src1_idx), evex_src_xmm(modrm, rm, pfx), imm)),
    }
  },

  // 0F3A 50: VRANGEPS (66, W=0) / VRANGEPD (66, W=1) — range restriction packed [DQ]
  // 0F3A 50: VRANGEPS (66, W=0) / VRANGEPD (66, W=1) — range restriction packed [DQ]
  80 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
    let imm = fetch_byte();
    if pfx.vex_w then {
      match pfx.evex_ll {
        2 => write_zmm(dst, avx_vrangepd_512(read_zmm(pfx.evex_vvvvv), evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem), imm)),
        1 => write_ymm(dst, avx_vrangepd_256(read_ymm(pfx.evex_vvvvv), evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem), imm)),
        _ => write_xmm(dst, avx_vrangepd_128(read_xmm(pfx.evex_vvvvv), evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem), imm)),
      }
    } else {
      match pfx.evex_ll {
        2 => write_zmm(dst, avx_vrangeps_512(read_zmm(pfx.evex_vvvvv), evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem), imm)),
        1 => write_ymm(dst, avx_vrangeps_256(read_ymm(pfx.evex_vvvvv), evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem), imm)),
        _ => write_xmm(dst, avx_vrangeps_128(read_xmm(pfx.evex_vvvvv), evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem), imm)),
      }
    }
  },

  // 0F3A 51: VRANGESS (66, W=0) / VRANGESD (66, W=1) — range restriction scalar [DQ]
  81 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, if pfx.vex_w then 8 else 4);
    let imm = fetch_byte();
    let src1 = read_xmm(pfx.evex_vvvvv);
    if pfx.vex_w then {
      let src2 : qword = match rm {
        RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
        RM_mem(addr) => mem_read64(fixup_addr(addr)),
      };
      let r = avx_range_f64(src1[63..0], src2, imm);
      write_xmm(dst, src1[127..64] @ r)
    } else {
      let src2 : dword = match rm {
        RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
        RM_mem(addr) => mem_read32(fixup_addr(addr)),
      };
      let r = avx_range_f32(src1[31..0], src2, imm);
      write_xmm(dst, src1[127..32] @ r)
    }
  },

  // 0F3A 54: VFIXUPIMMPS (66, W=0) / VFIXUPIMMPD (66, W=1) — fixup packed
  // 0F3A 54: VFIXUPIMMPS (66, W=0) / VFIXUPIMMPD (66, W=1) — fixup packed
  84 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
    let imm = fetch_byte();
    if pfx.vex_w then {
      // VFIXUPIMMPD xmm1/ymm1/zmm1, xmm2/ymm2/zmm2, xmm3/ymm3/zmm3/m128/m256/m512, imm8
      match pfx.evex_ll {
        2 => write_zmm(dst, avx_vfixupimmpd_512(read_zmm(dst), read_zmm(pfx.evex_vvvvv), evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem), imm)),
        1 => write_ymm(dst, avx_vfixupimmpd_256(read_ymm(dst), read_ymm(pfx.evex_vvvvv), evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem), imm)),
        _ => write_xmm(dst, avx_vfixupimmpd_128(read_xmm(dst), read_xmm(pfx.evex_vvvvv), evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem), imm)),
      }
    } else {
      // VFIXUPIMMPS xmm1/ymm1/zmm1, xmm2/ymm2/zmm2, xmm3/ymm3/zmm3/m128/m256/m512, imm8
      match pfx.evex_ll {
        2 => write_zmm(dst, avx_vfixupimmps_512(read_zmm(dst), read_zmm(pfx.evex_vvvvv), evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem), imm)),
        1 => write_ymm(dst, avx_vfixupimmps_256(read_ymm(dst), read_ymm(pfx.evex_vvvvv), evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem), imm)),
        _ => write_xmm(dst, avx_vfixupimmps_128(read_xmm(dst), read_xmm(pfx.evex_vvvvv), evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem), imm)),
      }
    }
  },

  // 0F3A 55: VFIXUPIMMSS (66, W=0) / VFIXUPIMMSD (66, W=1) — fixup scalar
  // 0F3A 55: VFIXUPIMMSS (66, W=0) / VFIXUPIMMSD (66, W=1) — fixup scalar
  85 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, if pfx.vex_w then 8 else 4);
    let imm = fetch_byte();
    let src1 = read_xmm(pfx.evex_vvvvv);
    let src2 = evex_src_xmm(modrm, rm, pfx);
    let dst_xmm = read_xmm(dst);
    if pfx.vex_w then {
      // VFIXUPIMMSD xmm1, xmm2, xmm3/m64, imm8
      let r = __f64_fixupimm(dst_xmm[63..0], src1[63..0], src2[63..0], imm);
      write_xmm(dst, src1[127..64] @ r)
    } else {
      // VFIXUPIMMSS xmm1, xmm2, xmm3/m32, imm8
      let r = __f32_fixupimm(dst_xmm[31..0], src1[31..0], src2[31..0], imm);
      write_xmm(dst, src1[127..32] @ r)
    }
  },

  // 0F3A 56: VREDUCEPS (66, W=0) / VREDUCEPD (66, W=1) / VREDUCEPH (NP, W=0)
  86 => {
    match mp {
      MP_66 => {
        let modrm = fetch_byte();
        let dst = evex_reg_idx(modrm, pfx);
        let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
        let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
        let imm = fetch_byte();
        if pfx.vex_w then {
          // VREDUCEPD xmm1/ymm1/zmm1, xmm2/ymm2/zmm2/m128/m256/m512, imm8
          match pfx.evex_ll {
            2 => write_zmm(dst, avx_vreducepd_512(evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem), imm)),
            1 => write_ymm(dst, avx_vreducepd_256(evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem), imm)),
            _ => write_xmm(dst, avx_vreducepd_128(evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem), imm)),
          }
        } else {
          // VREDUCEPS xmm1/ymm1/zmm1, xmm2/ymm2/zmm2/m128/m256/m512, imm8
          match pfx.evex_ll {
            2 => write_zmm(dst, avx_vreduceps_512(evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem), imm)),
            1 => write_ymm(dst, avx_vreduceps_256(evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem), imm)),
            _ => write_xmm(dst, avx_vreduceps_128(evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem), imm)),
          }
        }
      },
      MP_NONE => {
        // VREDUCEPH: packed FP16 reduce
        if pfx.vex_w then raise_UD();
        let modrm = fetch_byte();
        let dst = evex_reg_idx(modrm, pfx);
        let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
        let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
        let imm = fetch_byte();
        match pfx.evex_ll {
          2 => {
            let src = evex_bcast_src_f16_zmm(modrm, rm, pfx, is_mem);
            let r = vreduceph_zmm(src, imm);
            write_zmm(dst, apply_writemask_ph_zmm(r, read_zmm(dst), evex_get_mask32(pfx), pfx.evex_z))
          },
          1 => {
            let src = evex_bcast_src_f16_ymm(modrm, rm, pfx, is_mem);
            let r = vreduceph_ymm(src, imm);
            write_ymm(dst, apply_writemask_ph_ymm(r, read_ymm(dst), evex_get_mask16(pfx), pfx.evex_z))
          },
          _ => {
            let src = evex_bcast_src_f16_xmm(modrm, rm, pfx, is_mem);
            let r = vreduceph_xmm(src, imm);
            write_xmm(dst, apply_writemask_ph_xmm(r, read_xmm(dst), evex_get_mask8(pfx), pfx.evex_z))
          },
        }
      },
      _ => raise_UD(),
    }
  },

  // 0F3A 57: VREDUCESS (66, W=0) / VREDUCESD (66, W=1) / VREDUCESH (NP, W=0)
  87 => {
    match mp {
      MP_66 => {
        let modrm = fetch_byte();
        let dst = evex_reg_idx(modrm, pfx);
        let rm = decode_rm_evex(modrm, pfx, if pfx.vex_w then 8 else 4);
        let imm = fetch_byte();
        let src1 = read_xmm(pfx.evex_vvvvv);
        let src2 = evex_src_xmm(modrm, rm, pfx);
        if pfx.vex_w then {
          let r = __f64_reduce(src2[63..0], imm);
          write_xmm(dst, src1[127..64] @ r)
        } else {
          let r = __f32_reduce(src2[31..0], imm);
          write_xmm(dst, src1[127..32] @ r)
        }
      },
      MP_NONE => {
        // VREDUCESH: scalar FP16 reduce
        if pfx.vex_w then raise_UD();
        let modrm = fetch_byte();
        let dst = evex_reg_idx(modrm, pfx);
        let rm = decode_rm_evex(modrm, pfx, 2);
        let imm = fetch_byte();
        let src1 = read_xmm(pfx.evex_vvvvv);
        let src2 = evex_src_xmm(modrm, rm, pfx);
        let r : word = __f16_reduce(src2[15..0], imm);
        write_xmm(dst, src1[127..16] @ r)
      },
      _ => raise_UD(),
    }
  },

  // 0F3A 66: VFPCLASSPS (66, W=0) / VFPCLASSPD (66, W=1) / VFPCLASSPH (NP, W=0)
  102 => {
    match mp {
      MP_66 => {
        let modrm = fetch_byte();
        let dst_k : range(0, 7) = unsigned(modrm[5..3]);
        let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
        let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
        let imm = fetch_byte();
        if pfx.vex_w then {
          // VFPCLASSPD k1, xmm2/ymm2/zmm2/m128/m256/m512, imm8
          match pfx.evex_ll {
            2 => {
              let mask : byte = avx_vfpclasspd_512(evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem), imm);
              let k_val : qword = zero_extend(mask);
              let k_mask : qword = if pfx.evex_aaa == 0 then k_val else k_val & read_kreg(pfx.evex_aaa);
              write_kreg(dst_k, k_mask)
            },
            1 => {
              let mask : byte = avx_vfpclasspd_256(evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem), imm);
              let k_val : qword = zero_extend(mask);
              let k_mask : qword = if pfx.evex_aaa == 0 then k_val else k_val & read_kreg(pfx.evex_aaa);
              write_kreg(dst_k, k_mask)
            },
            _ => {
              let mask : byte = avx_vfpclasspd_128(evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem), imm);
              let k_val : qword = zero_extend(mask);
              let k_mask : qword = if pfx.evex_aaa == 0 then k_val else k_val & read_kreg(pfx.evex_aaa);
              write_kreg(dst_k, k_mask)
            },
          }
        } else {
          // VFPCLASSPS k1, xmm2/ymm2/zmm2/m128/m256/m512, imm8
          match pfx.evex_ll {
            2 => {
              let mask : word = avx_vfpclassps_512(evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem), imm);
              let k_val : qword = zero_extend(mask);
              let k_mask : qword = if pfx.evex_aaa == 0 then k_val else k_val & read_kreg(pfx.evex_aaa);
              write_kreg(dst_k, k_mask)
            },
            1 => {
              let mask : byte = avx_vfpclassps_256(evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem), imm);
              let k_val : qword = zero_extend(mask);
              let k_mask : qword = if pfx.evex_aaa == 0 then k_val else k_val & read_kreg(pfx.evex_aaa);
              write_kreg(dst_k, k_mask)
            },
            _ => {
              let mask : byte = avx_vfpclassps_128(evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem), imm);
              let k_val : qword = zero_extend(mask);
              let k_mask : qword = if pfx.evex_aaa == 0 then k_val else k_val & read_kreg(pfx.evex_aaa);
              write_kreg(dst_k, k_mask)
            },
          }
        }
      },
      MP_NONE => {
        // VFPCLASSPH: classify packed FP16 → kmask
        if pfx.vex_w then raise_UD();
        let modrm = fetch_byte();
        let dst_k : range(0, 7) = unsigned(modrm[5..3]);
        let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
        let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
        let imm = fetch_byte();
        match pfx.evex_ll {
          2 => {
            let mask : dword = vfpclassph_zmm(evex_bcast_src_f16_zmm(modrm, rm, pfx, is_mem), imm);
            let k_val : qword = zero_extend(mask);
            let k_mask : qword = if pfx.evex_aaa == 0 then k_val else k_val & read_kreg(pfx.evex_aaa);
            write_kreg(dst_k, k_mask)
          },
          1 => {
            let mask : word = vfpclassph_ymm(evex_bcast_src_f16_ymm(modrm, rm, pfx, is_mem), imm);
            let k_val : qword = zero_extend(mask);
            let k_mask : qword = if pfx.evex_aaa == 0 then k_val else k_val & read_kreg(pfx.evex_aaa);
            write_kreg(dst_k, k_mask)
          },
          _ => {
            let mask : byte = vfpclassph_xmm(evex_bcast_src_f16_xmm(modrm, rm, pfx, is_mem), imm);
            let k_val : qword = zero_extend(mask);
            let k_mask : qword = if pfx.evex_aaa == 0 then k_val else k_val & read_kreg(pfx.evex_aaa);
            write_kreg(dst_k, k_mask)
          },
        }
      },
      _ => raise_UD(),
    }
  },

  // 0F3A 67: VFPCLASSSS (66, W=0) / VFPCLASSSD (66, W=1) / VFPCLASSSH (NP, W=0)
  103 => {
    match mp {
      MP_66 => {
        let modrm = fetch_byte();
        let dst_k : range(0, 7) = unsigned(modrm[5..3]);
        let rm = decode_rm_evex(modrm, pfx, if pfx.vex_w then 8 else 4);
        let imm = fetch_byte();
        let src = evex_src_xmm(modrm, rm, pfx);
        if pfx.vex_w then {
          let result : bool = avx_fpclass_f64(src[63..0], imm);
          let k_val : qword = if result then zero_extend(0b1 : bits(1)) else zeros();
          let k_mask : qword = if pfx.evex_aaa == 0 then k_val else k_val & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask)
        } else {
          let result : bool = avx_fpclass_f32(src[31..0], imm);
          let k_val : qword = if result then zero_extend(0b1 : bits(1)) else zeros();
          let k_mask : qword = if pfx.evex_aaa == 0 then k_val else k_val & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask)
        }
      },
      MP_NONE => {
        // VFPCLASSSH: classify scalar FP16 → kmask
        if pfx.vex_w then raise_UD();
        let modrm = fetch_byte();
        let dst_k : range(0, 7) = unsigned(modrm[5..3]);
        let rm = decode_rm_evex(modrm, pfx, 2);
        let imm = fetch_byte();
        let src = evex_src_xmm(modrm, rm, pfx);
        let result : bool = fpclass_f16(src[15..0], imm);
        let k_val : qword = if result then zero_extend(0b1 : bits(1)) else zeros();
        let k_mask : qword = if pfx.evex_aaa == 0 then k_val else k_val & read_kreg(pfx.evex_aaa);
        write_kreg(dst_k, k_mask)
      },
      _ => raise_UD(),
    }
  },

  // 0F3A CE: VGF2P8AFFINEQB (66,W1) [GFNI]
  // 0F3A CE: VGF2P8AFFINEQB (66,W1) [GFNI]
  206 => {
    if mp != MP_66 | not_bool(pfx.rex_w) then raise_UD();
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
    let imm = fetch_byte();
    match pfx.evex_ll {
      2 => write_zmm(dst, avx_gf2p8affineqb_512(read_zmm(pfx.evex_vvvvv), evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem), imm)),
      1 => write_ymm(dst, avx_gf2p8affineqb_256(read_ymm(pfx.evex_vvvvv), evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem), imm)),
      _ => write_xmm(dst, avx_gf2p8affineqb_128(read_xmm(pfx.evex_vvvvv), evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem), imm)),
    }
  },

  // 0F3A CF: VGF2P8AFFINEINVQB (66,W1) [GFNI]
  // 0F3A CF: VGF2P8AFFINEINVQB (66,W1) [GFNI]
  207 => {
    if mp != MP_66 | not_bool(pfx.rex_w) then raise_UD();
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
    let imm = fetch_byte();
    match pfx.evex_ll {
      2 => write_zmm(dst, avx_gf2p8affineinvqb_512(read_zmm(pfx.evex_vvvvv), evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem), imm)),
      1 => write_ymm(dst, avx_gf2p8affineinvqb_256(read_ymm(pfx.evex_vvvvv), evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem), imm)),
      _ => write_xmm(dst, avx_gf2p8affineinvqb_128(read_xmm(pfx.evex_vvvvv), evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem), imm)),
    }
  },

  // 0F3A 70: VPSHLDW (66, W=1) [VBMI2]
  // 0F3A 70: VPSHLDW (66, W=1) [VBMI2]
  112 => {
    if mp != MP_66 | not_bool(pfx.rex_w) then raise_UD();
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let imm = fetch_byte();
    match pfx.evex_ll {
      2 => write_zmm(dst, avx_vpshldw_imm_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx), imm)),
      1 => write_ymm(dst, avx_vpshldw_imm_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx), imm)),
      _ => write_xmm(dst, avx_vpshldw_imm_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx), imm)),
    }
  },

  // 0F3A 71: VPSHLDD (66, W=0) / VPSHLDQ (66, W=1) [VBMI2]
  // 0F3A 71: VPSHLDD (66, W=0) / VPSHLDQ (66, W=1) [VBMI2]
  113 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
    let imm = fetch_byte();
    if pfx.rex_w then {
      match pfx.evex_ll {
        2 => write_zmm(dst, avx_vpshldq_imm_512(read_zmm(pfx.evex_vvvvv), evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem), imm)),
        1 => write_ymm(dst, avx_vpshldq_imm_256(read_ymm(pfx.evex_vvvvv), evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem), imm)),
        _ => write_xmm(dst, avx_vpshldq_imm_128(read_xmm(pfx.evex_vvvvv), evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem), imm)),
      }
    } else {
      match pfx.evex_ll {
        2 => write_zmm(dst, avx_vpshldd_imm_512(read_zmm(pfx.evex_vvvvv), evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem), imm)),
        1 => write_ymm(dst, avx_vpshldd_imm_256(read_ymm(pfx.evex_vvvvv), evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem), imm)),
        _ => write_xmm(dst, avx_vpshldd_imm_128(read_xmm(pfx.evex_vvvvv), evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem), imm)),
      }
    }
  },

  // 0F3A 72: VPSHRDW (66, W=1) [VBMI2]
  // 0F3A 72: VPSHRDW (66, W=1) [VBMI2]
  114 => {
    if mp != MP_66 | not_bool(pfx.rex_w) then raise_UD();
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let imm = fetch_byte();
    match pfx.evex_ll {
      2 => write_zmm(dst, avx_vpshrdw_imm_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx), imm)),
      1 => write_ymm(dst, avx_vpshrdw_imm_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx), imm)),
      _ => write_xmm(dst, avx_vpshrdw_imm_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx), imm)),
    }
  },

  // 0F3A 73: VPSHRDD (66, W=0) / VPSHRDQ (66, W=1) [VBMI2]
  // 0F3A 73: VPSHRDD (66, W=0) / VPSHRDQ (66, W=1) [VBMI2]
  115 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
    let imm = fetch_byte();
    if pfx.rex_w then {
      match pfx.evex_ll {
        2 => write_zmm(dst, avx_vpshrdq_imm_512(read_zmm(pfx.evex_vvvvv), evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem), imm)),
        1 => write_ymm(dst, avx_vpshrdq_imm_256(read_ymm(pfx.evex_vvvvv), evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem), imm)),
        _ => write_xmm(dst, avx_vpshrdq_imm_128(read_xmm(pfx.evex_vvvvv), evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem), imm)),
      }
    } else {
      match pfx.evex_ll {
        2 => write_zmm(dst, avx_vpshrdd_imm_512(read_zmm(pfx.evex_vvvvv), evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem), imm)),
        1 => write_ymm(dst, avx_vpshrdd_imm_256(read_ymm(pfx.evex_vvvvv), evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem), imm)),
        _ => write_xmm(dst, avx_vpshrdd_imm_128(read_xmm(pfx.evex_vvvvv), evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem), imm)),
      }
    }
  },

  // 0F3A C2: VCMPPH (NP,W0) / VCMPSH (F3,W0) [FP16]
  // 0F3A C2: VCMPPH (NP,W0) / VCMPSH (F3,W0) [FP16]
  194 => {
    if pfx.rex_w then raise_UD();
    match mp {
      MP_NONE => {
        // VCMPPH: packed FP16 compare → kmask
        let modrm = fetch_byte();
        let k_idx : range(0, 7) = evex_reg_idx(modrm, pfx) % 8;
        let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
        match pfx.evex_ll {
          2 => {
            let src1 = read_zmm(pfx.evex_vvvvv);
            let src2 = evex_src_zmm(modrm, rm, pfx);
            let pred_byte = fetch_byte();
            let pred : range(0, 31) = unsigned(pred_byte[4..0]);
            let result = avx_vcmpph_kmask_512(src1, src2, pred);
            write_kreg(k_idx, zero_extend(result))
          },
          1 => {
            let src1 = read_ymm(pfx.evex_vvvvv);
            let src2 = evex_src_ymm(modrm, rm, pfx);
            let pred_byte = fetch_byte();
            let pred : range(0, 31) = unsigned(pred_byte[4..0]);
            let r = avx_vcmpph_kmask_256(src1, src2, pred);
            write_kreg(k_idx, zero_extend(r))
          },
          _ => {
            let src1 = read_xmm(pfx.evex_vvvvv);
            let src2 = evex_src_xmm(modrm, rm, pfx);
            let pred_byte = fetch_byte();
            let pred : range(0, 31) = unsigned(pred_byte[4..0]);
            let r = avx_vcmpph_kmask_128(src1, src2, pred);
            write_kreg(k_idx, zero_extend(r))
          },
        }
      },
      MP_F3 => {
        // VCMPSH: scalar FP16 compare → kmask bit 0
        let modrm = fetch_byte();
        let k_idx : range(0, 7) = evex_reg_idx(modrm, pfx) % 8;
        let rm = decode_rm_evex(modrm, pfx, 2);
        let src1 = read_xmm(pfx.evex_vvvvv);
        let src2 = evex_src_xmm(modrm, rm, pfx);
        let pred_byte = fetch_byte();
        let pred : range(0, 31) = unsigned(pred_byte[4..0]);
        let bit : bool = cmp_pred5_f16(src1[15..0], src2[15..0], pred);
        write_kreg(k_idx, if bit then 0x0000000000000001 else 0x0000000000000000)
      },
      _ => raise_UD(),
    }
  },

  _ => raise_UD(),
  }
}

// x86-64 — EVEX Immediate Operations (0F3A map)
//
// Insert/extract, permute-imm, ternlog, round, compare-imm,
// classify, shift-imm, GFNI, and FP16 compare.
// Called from dispatch_evex in insn_evex.sail.

val cmp_u_pred : forall 'n, 0 < 'n & 'n <= 64. (bits('n), bits('n), range(0, 7)) -> bit
function cmp_u_pred(a, b, pred) = {
  let eq : bit = is_eq(a, b);
  let lt : bit = is_gt_u(b, a);
  match pred {
    0 => eq,
    1 => lt,
    2 => eq | lt,
    3 => 0b0,
    4 => ~(eq),
    5 => ~(lt),
    6 => ~(eq) & ~(lt),
    7 => 0b1,
  }
}

val cmp_s_pred : forall 'n, 0 < 'n & 'n <= 64. (bits('n), bits('n), range(0, 7)) -> bit
function cmp_s_pred(a, b, pred) = {
  let eq : bit = is_eq(a, b);
  let lt : bit = is_gt(b, a);
  match pred {
    0 => eq,
    1 => lt,
    2 => eq | lt,
    3 => 0b0,
    4 => ~(eq),
    5 => ~(lt),
    6 => ~(eq) & ~(lt),
    7 => 0b1,
  }
}

val avx_pcmpub : forall 'vl, 'vl in {128, 256, 512}.
  (bits('vl), bits('vl), range(0, 7)) -> qword
function avx_pcmpub(a, b, pred) = {
  var r : qword = zeros();
  foreach (i from 0 to ('vl / 8 - 1)) {
    let lo = i * 8;
    r[i] = cmp_u_pred(a[(lo + 7)..lo], b[(lo + 7)..lo], pred);
  };
  r
}

// VPCMPB: signed byte compare
val avx_pcmpb : forall 'vl, 'vl in {128, 256, 512}.
  (bits('vl), bits('vl), range(0, 7)) -> qword
function avx_pcmpb(a, b, pred) = {
  var r : qword = zeros();
  foreach (i from 0 to ('vl / 8 - 1)) {
    let lo = i * 8;
    r[i] = cmp_s_pred(a[(lo + 7)..lo], b[(lo + 7)..lo], pred);
  };
  r
}

// VPCMPUW: unsigned word compare
val avx_pcmpuw : forall 'vl, 'vl in {128, 256, 512}.
  (bits('vl), bits('vl), range(0, 7)) -> qword
function avx_pcmpuw(a, b, pred) = {
  var r : qword = zeros();
  foreach (i from 0 to ('vl / 16 - 1)) {
    let lo = i * 16;
    r[i] = cmp_u_pred(a[(lo + 15)..lo], b[(lo + 15)..lo], pred);
  };
  r
}

// VPCMPW: signed word compare
val avx_pcmpw : forall 'vl, 'vl in {128, 256, 512}.
  (bits('vl), bits('vl), range(0, 7)) -> qword
function avx_pcmpw(a, b, pred) = {
  var r : qword = zeros();
  foreach (i from 0 to ('vl / 16 - 1)) {
    let lo = i * 16;
    r[i] = cmp_s_pred(a[(lo + 15)..lo], b[(lo + 15)..lo], pred);
  };
  r
}

// VPCMPUD: unsigned dword compare producing kmask
val avx_pcmpud : forall 'vl, 'vl in {128, 256, 512}.
  (bits('vl), bits('vl), range(0, 7)) -> qword
function avx_pcmpud(a, b, pred) = {
  var r : qword = zeros();
  foreach (i from 0 to ('vl / 32 - 1)) {
    let lo = i * 32;
    r[i] = cmp_u_pred(a[(lo + 31)..lo], b[(lo + 31)..lo], pred);
  };
  r
}

// VPCMPD: signed dword compare
val avx_pcmpd : forall 'vl, 'vl in {128, 256, 512}.
  (bits('vl), bits('vl), range(0, 7)) -> qword
function avx_pcmpd(a, b, pred) = {
  var r : qword = zeros();
  foreach (i from 0 to ('vl / 32 - 1)) {
    let lo = i * 32;
    r[i] = cmp_s_pred(a[(lo + 31)..lo], b[(lo + 31)..lo], pred);
  };
  r
}

// VPCMPUQ: unsigned qword compare
val avx_pcmpuq : forall 'vl, 'vl in {128, 256, 512}.
  (bits('vl), bits('vl), range(0, 7)) -> qword
function avx_pcmpuq(a, b, pred) = {
  var r : qword = zeros();
  foreach (i from 0 to ('vl / 64 - 1)) {
    let lo = i * 64;
    r[i] = cmp_u_pred(a[(lo + 63)..lo], b[(lo + 63)..lo], pred);
  };
  r
}

// VPCMPQ: signed qword compare
val avx_pcmpq : forall 'vl, 'vl in {128, 256, 512}.
  (bits('vl), bits('vl), range(0, 7)) -> qword
function avx_pcmpq(a, b, pred) = {
  var r : qword = zeros();
  foreach (i from 0 to ('vl / 64 - 1)) {
    let lo = i * 64;
    r[i] = cmp_s_pred(a[(lo + 63)..lo], b[(lo + 63)..lo], pred);
  };
  r
}

// =========================================================================
// VPTERNLOGD: ternary logic on 3 dword operands using 8-bit truth table
// For each bit position: result = imm8[{a_bit, b_bit, c_bit}]
// =========================================================================

val vpternlog : forall 'vl, 'vl in {128, 256, 512}.
  (bits('vl), bits('vl), bits('vl), byte) -> bits('vl)
function vpternlog(a, b, c, imm) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl - 1)) {
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

val cmp_pred5_f16 : (word, word, range(0, 31)) -> bit
function cmp_pred5_f16(a, b, pred) = {
  let r = fp_compare(a, b);
  let unord : bit = match r { FP_UNORDERED => 0b1, _ => 0b0 };
  let eq : bit = match r { FP_EQ => 0b1, _ => 0b0 };
  let lt : bit = match r { FP_LT => 0b1, _ => 0b0 };
  let gt : bit = match r { FP_GT => 0b1, _ => 0b0 };
  let le : bit = lt | eq;
  match pred {
    0  => eq,                    // EQ_OQ
    1  => lt,                    // LT_OS
    2  => le,                    // LE_OS
    3  => unord,                 // UNORD_Q
    4  => ~(eq) & ~(unord),      // NEQ_UQ
    5  => ~(lt) | unord,         // NLT_US
    6  => ~(le) | unord,         // NLE_US
    7  => ~(unord),              // ORD_Q
    8  => eq | unord,            // EQ_UQ
    9  => lt | unord,            // NGE_US
    10 => le | unord,            // NGT_US
    11 => 0b0,                   // FALSE_OQ
    12 => ~(eq),                 // NEQ_OQ
    13 => ~(lt),                 // GE_OS
    14 => gt | eq,               // GT_OS
    15 => 0b1,                   // TRUE_UQ
    16 => eq,                    // EQ_OS
    17 => lt,                    // LT_OQ
    18 => le,                    // LE_OQ
    19 => unord,                 // UNORD_S
    20 => ~(eq) | unord,         // NEQ_US
    21 => ~(lt) | unord,         // NLT_UQ
    22 => ~(le) | unord,         // NLE_UQ
    23 => ~(unord),              // ORD_S
    24 => eq | unord,            // EQ_US
    25 => lt | unord,            // NGE_UQ
    26 => le | unord,            // NGT_UQ
    27 => 0b0,                   // FALSE_OS
    28 => ~(eq),                 // NEQ_OS
    29 => ~(lt),                 // GE_OQ
    30 => gt | eq,               // GT_OQ
    31 => 0b1,                   // TRUE_US
  }
}

// VCMPPH → kmask: compare FP16 elements, return mask
val avx_vcmpph_kmask : forall 'vl, 'vl in {128, 256, 512}.
  (bits('vl), bits('vl), range(0, 31)) -> qword
function avx_vcmpph_kmask(a, b, pred) = {
  var r : qword = zeros();
  foreach (i from 0 to ('vl / 16 - 1)) {
    let lo = i * 16;
    r[i] = cmp_pred5_f16(a[(lo + 15)..lo], b[(lo + 15)..lo], pred);
  };
  r
}

// =========================================================================
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

// VALIGND: concatenate src1(high):src2(low), shift right by imm dwords, take low bits.
// Branchless: same pattern as VPALIGNR but at dword granularity.
val avx_valignd_128 : (xmmword, xmmword, byte) -> xmmword
function avx_valignd_128(src1, src2, imm) =
  ((src1 @ src2) >> (unsigned(imm[1..0]) * 32))[127..0]

val avx_valignd_256 : (ymmword, ymmword, byte) -> ymmword
function avx_valignd_256(src1, src2, imm) =
  ((src1 @ src2) >> (unsigned(imm[2..0]) * 32))[255..0]

val avx_valignd_512 : (zmmword, zmmword, byte) -> zmmword
function avx_valignd_512(src1, src2, imm) =
  ((src1 @ src2) >> (unsigned(imm[3..0]) * 32))[511..0]

// VALIGNQ: concatenate src1(high):src2(low), shift right by imm qwords, take low bits.
val avx_valignq_128 : (xmmword, xmmword, byte) -> xmmword
function avx_valignq_128(src1, src2, imm) =
  ((src1 @ src2) >> (unsigned(imm[0..0]) * 64))[127..0]

val avx_valignq_256 : (ymmword, ymmword, byte) -> ymmword
function avx_valignq_256(src1, src2, imm) =
  ((src1 @ src2) >> (unsigned(imm[1..0]) * 64))[255..0]

val avx_valignq_512 : (zmmword, zmmword, byte) -> zmmword
function avx_valignq_512(src1, src2, imm) =
  ((src1 @ src2) >> (unsigned(imm[2..0]) * 64))[511..0]

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

val avx_vpermilps_imm : forall 'vl, 'vl in {128, 256, 512}.
  (bits('vl), byte) -> bits('vl)
function avx_vpermilps_imm(src, imm) = {
  var r : bits('vl) = zeros();
  foreach (lane from 0 to ('vl / 128 - 1)) {
    let lo = lane * 128;
    r[(lo + 127)..lo] = avx_vpermilps_imm_128(src[(lo + 127)..lo], imm);
  };
  r
}

/* ---- VPERMILPD (imm8): in-lane qword permute ---- */

val avx_vpermilpd_imm_128 : (xmmword, byte) -> xmmword
function avx_vpermilpd_imm_128(src, imm) = {
  let s0 : range(0, 1) = unsigned(imm[0]);
  let s1 : range(0, 1) = unsigned(imm[1]);
  let lo0 : range(0, 64) = s0 * 64;
  let lo1 : range(0, 64) = s1 * 64;
  src[(lo1 + 63)..lo1] @ src[(lo0 + 63)..lo0]
}

val avx_vpermilpd_imm : forall 'vl, 'vl in {128, 256, 512}.
  (bits('vl), byte) -> bits('vl)
function avx_vpermilpd_imm(src, imm) = {
  var r : bits('vl) = zeros();
  foreach (lane from 0 to ('vl / 128 - 1)) {
    let lo = lane * 128;
    let lane_imm : byte = imm >> (lane * 2);
    r[(lo + 127)..lo] = avx_vpermilpd_imm_128(src[(lo + 127)..lo], lane_imm);
  };
  r
}

/* ---- VPALIGNR: byte-align concatenation per 128-bit lane ---- */

val avx_palignr : forall 'vl, 'vl in {128, 256, 512}.
  (bits('vl), bits('vl), byte) -> bits('vl)
function avx_palignr(src1, src2, imm) = {
  var r : bits('vl) = zeros();
  foreach (lane from 0 to ('vl / 128 - 1)) {
    let lo = lane * 128;
    r[(lo + 127)..lo] = avx_palignr_128(src1[(lo + 127)..lo], src2[(lo + 127)..lo], imm);
  };
  r
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
    3 => src[511..384],
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
  let s0 : range(0, 1) = unsigned(imm[0]);
  let s1 : range(0, 1) = unsigned(imm[1]);
  let lane0 : xmmword = (src1 >> (s0 * 128))[127..0];
  let lane1 : xmmword = (src2 >> (s1 * 128))[127..0];
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
        sad = sad + abs_diff(xmm_byte(src1, s1_base + k), xmm_byte(tmp1, t1_base + k));
      };
      let wrd : word = get_slice_int(16, sad, 0);
      let dst_bit : range(0, 112) = (blk * 4 + w) * 16;
      result[(dst_bit + 15)..dst_bit] = wrd;
    };
  };
  result
}

val avx_vdbpsadbw : forall 'vl, 'vl in {128, 256, 512}.
  (bits('vl), bits('vl), byte) -> bits('vl)
function avx_vdbpsadbw(src1, src2, imm) = {
  var r : bits('vl) = zeros();
  foreach (lane from 0 to ('vl / 128 - 1)) {
    let lo = lane * 128;
    r[(lo + 127)..lo] = avx_vdbpsadbw_128(src1[(lo + 127)..lo], src2[(lo + 127)..lo], imm);
  };
  r
}

val avx_vrndscale : forall 'vl 'eb, 'vl in {128, 256, 512} & 'eb in {32, 64}.
  (int('eb), bits('vl), byte) -> bits('vl)
function avx_vrndscale(eb, src, imm) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 'eb - 1)) {
    let lo = i * 'eb;
    r[(lo + 'eb - 1)..lo] = match eb {
      32 => fp_rndscale(src[(lo + 'eb - 1)..lo], imm),
      64 => fp_rndscale(src[(lo + 'eb - 1)..lo], imm),
    }
  };
  r
}

/* ---- VGETMANT: extract mantissa ---- */

val avx_vgetmant : forall 'vl 'eb, 'vl in {128, 256, 512} & 'eb in {32, 64}.
  (int('eb), bits('vl), byte) -> bits('vl)
function avx_vgetmant(eb, src, imm) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 'eb - 1)) {
    let lo = i * 'eb;
    r[(lo + 'eb - 1)..lo] = match eb {
      32 => fp_getmant(src[(lo + 'eb - 1)..lo], imm),
      64 => fp_getmant(src[(lo + 'eb - 1)..lo], imm),
    }
  };
  r
}

/* ---- VREDUCE: reduce FP value ---- */

val avx_vreduce : forall 'vl 'eb, 'vl in {128, 256, 512} & 'eb in {32, 64}.
  (int('eb), bits('vl), byte) -> bits('vl)
function avx_vreduce(eb, src, imm) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 'eb - 1)) {
    let lo = i * 'eb;
    r[(lo + 'eb - 1)..lo] = match eb {
      32 => fp_reduce(src[(lo + 'eb - 1)..lo], imm),
      64 => fp_reduce(src[(lo + 'eb - 1)..lo], imm),
    }
  };
  r
}

/* ---- VFIXUPIMM: fix up special values ---- */

val avx_vfixupimm : forall 'vl 'eb, 'vl in {128, 256, 512} & 'eb in {32, 64}.
  (int('eb), bits('vl), bits('vl), bits('vl), byte) -> bits('vl)
function avx_vfixupimm(eb, dst, src1, src2, imm) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 'eb - 1)) {
    let lo = i * 'eb;
    r[(lo + 'eb - 1)..lo] = match eb {
      32 => fp_fixupimm(dst[(lo + 'eb - 1)..lo], src1[(lo + 'eb - 1)..lo], src2[(lo + 'eb - 1)..lo], imm),
      64 => fp_fixupimm(dst[(lo + 'eb - 1)..lo], src1[(lo + 'eb - 1)..lo], src2[(lo + 'eb - 1)..lo], imm),
    }
  };
  r
}

/* ---- VPLZCNTD/Q: count leading zeros per element ---- */

val avx_fpclass_f32 : (dword, byte) -> bit
function avx_fpclass_f32(src, imm) = fpclass(src[31], src[30..23], src[22..0], imm)

val avx_fpclass_f64 : (qword, byte) -> bit
function avx_fpclass_f64(src, imm) = fpclass(src[63], src[62..52], src[51..0], imm)

// VFPCLASSPS/PD packed versions (polymorphic, returning qword mask)
val avx_vfpclassps : forall 'vl, 'vl in {128, 256, 512}.
  (bits('vl), byte) -> qword
function avx_vfpclassps(src, imm) = {
  var r : qword = zeros();
  foreach (i from 0 to ('vl / 32 - 1)) {
    let lo = i * 32;
    r[i] = avx_fpclass_f32(src[(lo + 31)..lo], imm);
  };
  r
}

val avx_vfpclasspd : forall 'vl, 'vl in {128, 256, 512}.
  (bits('vl), byte) -> qword
function avx_vfpclasspd(src, imm) = {
  var r : qword = zeros();
  foreach (i from 0 to ('vl / 64 - 1)) {
    let lo = i * 64;
    r[i] = avx_fpclass_f64(src[(lo + 63)..lo], imm);
  };
  r
}

/* ---- VRANGEPS/PD: range restriction ---- */
// VRANGE: for each element pair, select min/max/abs-min/abs-max then apply sign control
// imm8[1:0] = operation (CmpOpCtl):
//   0=min(src1,src2), 1=max(src1,src2), 2=abs_min, 3=abs_max
//   For abs_min/abs_max: compare |src1| vs |src2| but return the ORIGINAL value
// imm8[3:2] = sign control (SignSelCtl):
//   0=preserve src1 sign, 1=preserve compare result sign, 2=force +, 3=force -

// Per-element range for f32 (SDM: RangeSP)
// Faithful translation of SDM pseudocode including NaN handling.
val avx_range_f32 : (dword, dword, byte) -> dword
function avx_range_f32(src1, src2, imm) = {
  let op : range(0, 3) = unsigned(imm[1..0]);
  let sign_ctl : range(0, 3) = unsigned(imm[3..2]);
  // SDM: SNaN check — return quieted SNaN (we don't model IE flag)
  let src1_is_nan : bool = fp_compare(src1, src1) == FP_UNORDERED;
  let src2_is_nan : bool = fp_compare(src2, src2) == FP_UNORDERED;
  // SDM: QNaN priority — non-NaN operand wins
  //   IF (SRC2 = QNAN) THEN TMP := SRC1
  //   ELSE IF (SRC1 = QNAN) THEN TMP := SRC2
  //   ELSE ... comparison ...
  let tmp : dword =
    if src2_is_nan then src1
    else if src1_is_nan then src2
    else match op {
      0 => if fp_compare(src1, src2) != FP_GT then src1 else src2,  // min: src1<=src2 ? src1 : src2
      1 => if fp_compare(src1, src2) != FP_GT then src2 else src1,  // max: src1<=src2 ? src2 : src1
      // abs_min: |src1|<=|src2| ? src1 : src2
      2 => {
        let a1 : dword = 0b0 @ src1[30..0];
        let a2 : dword = 0b0 @ src2[30..0];
        if fp_compare(a1, a2) != FP_GT then src1 else src2
      },
      // abs_max: |src1|<=|src2| ? src2 : src1
      3 => {
        let a1 : dword = 0b0 @ src1[30..0];
        let a2 : dword = 0b0 @ src2[30..0];
        if fp_compare(a1, a2) != FP_GT then src2 else src1
      },
    };
  // Phase 2: apply sign control (SDM: SignSelCtl)
  match sign_ctl {
    0 => src1[31] @ tmp[30..0],  // preserve src1 sign
    1 => tmp,                          // preserve compare result sign
    2 => 0b0 @ tmp[30..0],            // force positive
    3 => 0b1 @ tmp[30..0],            // force negative
  }
}

// Per-element range for f64 (SDM: RangeDP)
val avx_range_f64 : (qword, qword, byte) -> qword
function avx_range_f64(src1, src2, imm) = {
  let op : range(0, 3) = unsigned(imm[1..0]);
  let sign_ctl : range(0, 3) = unsigned(imm[3..2]);
  let src1_is_nan : bool = fp_compare(src1, src1) == FP_UNORDERED;
  let src2_is_nan : bool = fp_compare(src2, src2) == FP_UNORDERED;
  let tmp : qword =
    if src2_is_nan then src1
    else if src1_is_nan then src2
    else match op {
      0 => if fp_compare(src1, src2) != FP_GT then src1 else src2,
      1 => if fp_compare(src1, src2) != FP_GT then src2 else src1,
      2 => {
        let a1 : qword = 0b0 @ src1[62..0];
        let a2 : qword = 0b0 @ src2[62..0];
        if fp_compare(a1, a2) != FP_GT then src1 else src2
      },
      3 => {
        let a1 : qword = 0b0 @ src1[62..0];
        let a2 : qword = 0b0 @ src2[62..0];
        if fp_compare(a1, a2) != FP_GT then src2 else src1
      },
    };
  match sign_ctl {
    0 => src1[63] @ tmp[62..0],
    1 => tmp,
    2 => 0b0 @ tmp[62..0],
    3 => 0b1 @ tmp[62..0],
  }
}

val avx_vrange : forall 'vl 'eb, 'vl in {128, 256, 512} & 'eb in {32, 64}.
  (int('eb), bits('vl), bits('vl), byte) -> bits('vl)
function avx_vrange(eb, src1, src2, imm) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 'eb - 1)) {
    let lo = i * 'eb;
    r[(lo + 'eb - 1)..lo] = match eb {
      32 => avx_range_f32(src1[(lo + 'eb - 1)..lo], src2[(lo + 'eb - 1)..lo], imm),
      64 => avx_range_f64(src1[(lo + 'eb - 1)..lo], src2[(lo + 'eb - 1)..lo], imm),
    }
  };
  r
}

/* ---- VPBROADCASTMB2Q / VPBROADCASTMW2D: broadcast mask to vector ---- */

val avx_vpclmulqdq_lane : (xmmword, xmmword, byte) -> xmmword
function avx_vpclmulqdq_lane(src1, src2, imm8) = {
  let sel_a : qword = blend(src1[63..0], src1[127..64], imm8[0]);
  let sel_b : qword = blend(src2[63..0], src2[127..64], imm8[4]);
  pclmulqdq(sel_a, sel_b)
}

val avx_vpclmulqdq : forall 'vl, 'vl in {128, 256, 512}.
  (bits('vl), bits('vl), byte) -> bits('vl)
function avx_vpclmulqdq(src1, src2, imm8) = {
  var r : bits('vl) = zeros();
  foreach (lane from 0 to ('vl / 128 - 1)) {
    let lo = lane * 128;
    r[(lo + 127)..lo] = avx_vpclmulqdq_lane(src1[(lo + 127)..lo], src2[(lo + 127)..lo], imm8);
  };
  r
}

/* ---- VPSHLD/VPSHRD: packed shift double (VBMI2) ---- */

val avx_vpshldw_imm : forall 'vl, 'vl in {128, 256, 512}. (bits('vl), bits('vl), byte) -> bits('vl)
function avx_vpshldw_imm(src1, src2, imm8) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 16 - 1)) {
    let lo = i * 16;
    r[(lo + 15)..lo] = avx_vpshldw_elem(src1[(lo + 15)..lo], src2[(lo + 15)..lo], unsigned(imm8));
  }; r
}

val avx_vpshldd_imm : forall 'vl, 'vl in {128, 256, 512}. (bits('vl), bits('vl), byte) -> bits('vl)
function avx_vpshldd_imm(src1, src2, imm8) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 32 - 1)) {
    let lo = i * 32;
    r[(lo + 31)..lo] = avx_vpshldd_elem(src1[(lo + 31)..lo], src2[(lo + 31)..lo], unsigned(imm8));
  }; r
}

val avx_vpshldq_imm : forall 'vl, 'vl in {128, 256, 512}. (bits('vl), bits('vl), byte) -> bits('vl)
function avx_vpshldq_imm(src1, src2, imm8) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 64 - 1)) {
    let lo = i * 64;
    r[(lo + 63)..lo] = avx_vpshldq_elem(src1[(lo + 63)..lo], src2[(lo + 63)..lo], unsigned(imm8));
  }; r
}

val avx_vpshrdw_imm : forall 'vl, 'vl in {128, 256, 512}. (bits('vl), bits('vl), byte) -> bits('vl)
function avx_vpshrdw_imm(src1, src2, imm8) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 16 - 1)) {
    let lo = i * 16;
    r[(lo + 15)..lo] = avx_vpshrdw_elem(src1[(lo + 15)..lo], src2[(lo + 15)..lo], unsigned(imm8));
  }; r
}

val avx_vpshrdd_imm : forall 'vl, 'vl in {128, 256, 512}. (bits('vl), bits('vl), byte) -> bits('vl)
function avx_vpshrdd_imm(src1, src2, imm8) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 32 - 1)) {
    let lo = i * 32;
    r[(lo + 31)..lo] = avx_vpshrdd_elem(src1[(lo + 31)..lo], src2[(lo + 31)..lo], unsigned(imm8));
  }; r
}

val avx_vpshrdq_imm : forall 'vl, 'vl in {128, 256, 512}. (bits('vl), bits('vl), byte) -> bits('vl)
function avx_vpshrdq_imm(src1, src2, imm8) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 64 - 1)) {
    let lo = i * 64;
    r[(lo + 63)..lo] = avx_vpshrdq_elem(src1[(lo + 63)..lo], src2[(lo + 63)..lo], unsigned(imm8));
  }; r
}


val dispatch_evex_imm : (range(0, 255), Prefixes) -> unit
function dispatch_evex_imm(op, pfx) = {
  let mp = get_mandatory_prefix(pfx);

  match op {
  // 0F3A 00: VPERMQ (66, W=1) — imm8-controlled qword permute (256/512)
  0 => {
    if mp != MP_66 | ~(pfx.vex_w) then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let imm = fetch(1);
    match pfx.evex_ll {
      1 => evex_write(dst, evex_wmask(pfx, 4), avx_vpermq_imm_256(evex_bcast_src(256,modrm, src, pfx, 64), imm)),
      2 => evex_write(dst, evex_wmask(pfx, 8), avx_vpermq_imm_512(evex_bcast_src(512,modrm, src, pfx, 64), imm)),
      _ => raise_UD(),
    }
  },

  // 0F3A 01: VPERMPD (66, W=1) — imm8-controlled qword permute for FP doubles (256/512)
  // 0F3A 01: VPERMPD (66, W=1) — imm8-controlled qword permute for FP doubles (256/512)
  1 => {
    if mp != MP_66 | ~(pfx.vex_w) then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let imm = fetch(1);
    match pfx.evex_ll {
      1 => evex_write(dst, evex_wmask(pfx, 4), avx_vpermq_imm_256(evex_bcast_src(256,modrm, src, pfx, 64), imm)),
      2 => evex_write(dst, evex_wmask(pfx, 8), avx_vpermq_imm_512(evex_bcast_src(512,modrm, src, pfx, 64), imm)),
      _ => raise_UD(),
    }
  },

  // 0F3A 03: VALIGND (66, W=0) / VALIGNQ (66, W=1)
  // 0F3A 03: VALIGND (66, W=0) / VALIGNQ (66, W=1)
  3 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let imm = fetch(1);
    match (pfx.vex_w, pfx.evex_ll) {
      // VALIGNQ xmm1/ymm1/zmm1, xmm2/ymm2/zmm2, xmm3/ymm3/zmm3/m128/m256/m512, imm8
      (true, 0) => evex_write(dst, evex_wmask(pfx, 2), avx_valignq_128(read_simd(pfx.evex_vvvvv), evex_bcast_src(128,modrm, src, pfx, 64), imm)),
      (true, 1)  => evex_write(dst, evex_wmask(pfx, 4), avx_valignq_256(read_simd(256, pfx.evex_vvvvv), evex_bcast_src(256,modrm, src, pfx, 64), imm)),
      (true, 2)  => evex_write(dst, evex_wmask(pfx, 8), avx_valignq_512(ZMM[pfx.evex_vvvvv], evex_bcast_src(512,modrm, src, pfx, 64), imm)),
      // VALIGND xmm1/ymm1/zmm1, xmm2/ymm2/zmm2, xmm3/ymm3/zmm3/m128/m256/m512, imm8
      (false, 0) => evex_write(dst, evex_wmask(pfx, 4), avx_valignd_128(read_simd(pfx.evex_vvvvv), evex_bcast_src(128,modrm, src, pfx, 32), imm)),
      (false, 1) => evex_write(dst, evex_wmask(pfx, 8), avx_valignd_256(read_simd(256, pfx.evex_vvvvv), evex_bcast_src(256,modrm, src, pfx, 32), imm)),
      (false, 2) => evex_write(dst, evex_wmask(pfx, 16), avx_valignd_512(ZMM[pfx.evex_vvvvv], evex_bcast_src(512,modrm, src, pfx, 32), imm)),
      _ => raise_UD(),
    }
  },

  // 0F3A 04: VPERMILPS (66, W=0) — imm8-controlled in-lane dword permute
  // 0F3A 04: VPERMILPS (66, W=0) — imm8-controlled in-lane dword permute
  4 => {
    if mp != MP_66 | pfx.vex_w then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let imm = fetch(1);
    match pfx.evex_ll {
      0 => evex_write(dst, evex_wmask(pfx, 4), avx_vpermilps_imm_128(evex_bcast_src(128,modrm, src, pfx, 32), imm)),
      1 => evex_write(dst, evex_wmask(pfx, 8), avx_vpermilps_imm(evex_bcast_src(256,modrm, src, pfx, 32), imm)),
      2 => evex_write(dst, evex_wmask(pfx, 16), avx_vpermilps_imm(evex_bcast_src(512,modrm, src, pfx, 32), imm)),
      3 => raise_UD(),
    }
  },

  // 0F3A 05: VPERMILPD (66, W=1) — imm8-controlled in-lane qword permute
  // 0F3A 05: VPERMILPD (66, W=1) — imm8-controlled in-lane qword permute
  5 => {
    if mp != MP_66 | ~(pfx.vex_w) then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let imm = fetch(1);
    match pfx.evex_ll {
      0 => evex_write(dst, evex_wmask(pfx, 2), avx_vpermilpd_imm_128(evex_bcast_src(128,modrm, src, pfx, 64), imm)),
      1 => evex_write(dst, evex_wmask(pfx, 4), avx_vpermilpd_imm(evex_bcast_src(256,modrm, src, pfx, 64), imm)),
      2 => evex_write(dst, evex_wmask(pfx, 8), avx_vpermilpd_imm(evex_bcast_src(512,modrm, src, pfx, 64), imm)),
      3 => raise_UD(),
    }
  },

  // 0F3A 0F: VPALIGNR (66) — byte-align concatenation per 128-bit lane
  // 0F3A 0F: VPALIGNR (66) — byte-align concatenation per 128-bit lane
  15 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let imm = fetch(1);
    match pfx.evex_ll {
      0 => evex_write(dst, evex_wmask(pfx, 16), avx_palignr_128(read_simd(pfx.evex_vvvvv), evex_src(128,modrm, src, pfx), imm)),
      1 => evex_write(dst, evex_wmask(pfx, 32), avx_palignr(read_simd(256, pfx.evex_vvvvv), evex_src(256,modrm, src, pfx), imm)),
      2 => evex_write(dst, evex_wmask(pfx, 64), avx_palignr(ZMM[pfx.evex_vvvvv], evex_src(512,modrm, src, pfx), imm)),
      3 => raise_UD(),
    }
  },

  // 0F3A 14: VPEXTRB (66) — extract byte from XMM to GPR/mem
  // 0F3A 14: VPEXTRB (66) — extract byte from XMM to GPR/mem
  20 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let src = evex_reg_idx(modrm, pfx);
    let dest = modrm_rm_evex(modrm, pfx, 1);
    let imm = fetch(1);
    let sel : range(0, 15) = unsigned(imm[3..0]);
    let src_xmm : xmmword = read_simd(src);
    let lo : range(0, 120) = sel * 8;
    let extracted_byte : byte = src_xmm[(lo + 7)..lo];
    match dest {
      RM_reg(_) => v(modrm_rm_reg(modrm, pfx)) = zero_extend(32, extracted_byte),
      RM_mem(m) => v(m) = extracted_byte,
    }
  },

  // 0F3A 15: VPEXTRW (66) — extract word from XMM to GPR/mem
  // 0F3A 15: VPEXTRW (66) — extract word from XMM to GPR/mem
  21 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let src = evex_reg_idx(modrm, pfx);
    let dest = modrm_rm_evex(modrm, pfx, 2);
    let imm = fetch(1);
    let sel : range(0, 7) = unsigned(imm[2..0]);
    let src_xmm : xmmword = read_simd(src);
    let lo : range(0, 112) = sel * 16;
    let extracted_word : word = src_xmm[(lo + 15)..lo];
    match dest {
      RM_reg(_) => v(modrm_rm_reg(modrm, pfx)) = zero_extend(32, extracted_word),
      RM_mem(m) => v(m) = extracted_word,
    }
  },

  // 0F3A 16: VPEXTRD (66, W=0) / VPEXTRQ (66, W=1) — extract dword/qword from XMM
  // 0F3A 16: VPEXTRD (66, W=0) / VPEXTRQ (66, W=1) — extract dword/qword from XMM
  22 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let src = evex_reg_idx(modrm, pfx);
    let src_xmm : xmmword = read_simd(src);
    if pfx.vex_w then {
      // VPEXTRQ: imm8[0] selects qword
      let dest = modrm_rm_evex(modrm, pfx, 8);
      let imm = fetch(1);
      let sel : range(0, 1) = unsigned(imm[0]);
      let lo : range(0, 64) = sel * 64;
      let extracted : qword = src_xmm[(lo + 63)..lo];
      match dest {
        RM_reg(_) => v(modrm_rm_reg(modrm, pfx)) = extracted,
        RM_mem(m) => v(m) = extracted,
      }
    } else {
      // VPEXTRD: imm8[1:0] selects dword
      let dest = modrm_rm_evex(modrm, pfx, 4);
      let imm = fetch(1);
      let sel : range(0, 3) = unsigned(imm[1..0]);
      let lo : range(0, 96) = sel * 32;
      let extracted : dword = src_xmm[(lo + 31)..lo];
      match dest {
        RM_reg(_) => v(modrm_rm_reg(modrm, pfx)) = extracted,
        RM_mem(m) => v(m) = extracted,
      }
    }
  },

  // 0F3A 17: VEXTRACTPS (66) — extract single-precision FP from XMM to GPR/mem32
  // 0F3A 17: VEXTRACTPS (66) — extract single-precision FP from XMM to GPR/mem32
  23 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let src = evex_reg_idx(modrm, pfx);
    let dest = modrm_rm_evex(modrm, pfx, 4);
    let imm = fetch(1);
    let sel : range(0, 3) = unsigned(imm[1..0]);
    let src_xmm : xmmword = read_simd(src);
    let lo : range(0, 96) = sel * 32;
    let extracted : dword = src_xmm[(lo + 31)..lo];
    match dest {
      RM_reg(_) => v(modrm_rm_reg(modrm, pfx)) = extracted,
      RM_mem(m) => v(m) = extracted,
    }
  },

  // 0F3A 18: VINSERTF32X4 (66, W=0) / VINSERTF64X2 (66, W=1) — insert 128-bit into 256/512
  // 0F3A 18: VINSERTF32X4 (66, W=0) / VINSERTF64X2 (66, W=1) — insert 128-bit into 256/512
  24 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, 16);
    let src2 : xmmword = evex_src(128,modrm, src, pfx);
    let imm = fetch(1);
    match pfx.evex_ll {
      1 => {
        // 256-bit: imm8[0] selects which 128-bit lane
        var result = read_simd(256, pfx.evex_vvvvv);
        if imm[0] == 0b0 then result[127..0] = src2
        else result[255..128] = src2;
        if pfx.vex_w then evex_write(dst, evex_wmask(pfx, 4), result)
        else evex_write(dst, evex_wmask(pfx, 8), result)
      },
      2 => {
        // 512-bit: imm8[1:0] selects which 128-bit lane
        var result = ZMM[pfx.evex_vvvvv];
        let sel : range(0, 3) = unsigned(imm[1..0]);
        match sel {
          0 => result[127..0] = src2,
          1 => result[255..128] = src2,
          2 => result[383..256] = src2,
          3 => result[511..384] = src2,
        };
        if pfx.vex_w then evex_write(dst, evex_wmask(pfx, 8), result)
        else evex_write(dst, evex_wmask(pfx, 16), result)
      },
      _ => raise_UD(),
    }
  },

  // 0F3A 19: VEXTRACTF32X4 (66, W=0) / VEXTRACTF64X2 (66, W=1) — extract 128-bit from 256/512
  // 0F3A 19: VEXTRACTF32X4 (66, W=0) / VEXTRACTF64X2 (66, W=1) — extract 128-bit from 256/512
  25 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let src = evex_reg_idx(modrm, pfx);
    let dest = modrm_rm_evex(modrm, pfx, 16);
    let imm = fetch(1);
    match pfx.evex_ll {
      1 => {
        let src_ymm = read_simd(256, src);
        let extracted : xmmword = (src_ymm >> (unsigned(zero_extend(imm[0]) : bits(1)) * 128))[127..0];
        match dest {
          RM_reg(_) => {
            if pfx.vex_w then evex_write(evex_rm_reg_idx(modrm, pfx), evex_wmask(pfx, 2), extracted)
            else evex_write(evex_rm_reg_idx(modrm, pfx), evex_wmask(pfx, 4), extracted)
          },
          RM_mem(m) => {
            let elem : {4, 8} = if pfx.vex_w then 8 else 4;
            evex_masked_mem_store(m, zero_extend(extracted), evex_kmask64(pfx), 16, elem)
          },
        }
      },
      2 => {
        let src_zmm = ZMM[src];
        let sel : range(0, 3) = unsigned(imm[1..0]);
        let extracted : xmmword = match sel {
          0 => src_zmm[127..0],
          1 => src_zmm[255..128],
          2 => src_zmm[383..256],
          3 => src_zmm[511..384],
        };
        match dest {
          RM_reg(_) => {
            if pfx.vex_w then evex_write(evex_rm_reg_idx(modrm, pfx), evex_wmask(pfx, 2), extracted)
            else evex_write(evex_rm_reg_idx(modrm, pfx), evex_wmask(pfx, 4), extracted)
          },
          RM_mem(m) => {
            let elem : {4, 8} = if pfx.vex_w then 8 else 4;
            evex_masked_mem_store(m, zero_extend(extracted), evex_kmask64(pfx), 16, elem)
          },
        }
      },
      _ => raise_UD(),
    }
  },

  // 0F3A 1A: VINSERTF32X8 (66, W=0) / VINSERTF64X4 (66, W=1) — insert 256-bit into 512
  // 0F3A 1A: VINSERTF32X8 (66, W=0) / VINSERTF64X4 (66, W=1) — insert 256-bit into 512
  26 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, 32);
    let src2 : ymmword = evex_src(256,modrm, src, pfx);
    let imm = fetch(1);
    match pfx.evex_ll {
      2 => {
        // 512-bit only: imm8[0] selects which 256-bit half
        var result = ZMM[pfx.evex_vvvvv];
        if imm[0] == 0b0 then result[255..0] = src2
        else result[511..256] = src2;
        if pfx.vex_w then evex_write(dst, evex_wmask(pfx, 8), result)
        else evex_write(dst, evex_wmask(pfx, 16), result)
      },
      _ => raise_UD(),
    }
  },

  // 0F3A 1B: VEXTRACTF32X8 (66, W=0) / VEXTRACTF64X4 (66, W=1) — extract 256-bit from 512
  // 0F3A 1B: VEXTRACTF32X8 (66, W=0) / VEXTRACTF64X4 (66, W=1) — extract 256-bit from 512
  27 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let src = evex_reg_idx(modrm, pfx);
    let dest = modrm_rm_evex(modrm, pfx, 32);
    let imm = fetch(1);
    match pfx.evex_ll {
      2 => {
        let src_zmm = ZMM[src];
        let extracted : ymmword = (src_zmm >> (unsigned(zero_extend(imm[0]) : bits(1)) * 256))[255..0];
        match dest {
          RM_reg(_) => {
            if pfx.vex_w then evex_write(evex_rm_reg_idx(modrm, pfx), evex_wmask(pfx, 4), extracted)
            else evex_write(evex_rm_reg_idx(modrm, pfx), evex_wmask(pfx, 8), extracted)
          },
          RM_mem(m) => {
            let elem : {4, 8} = if pfx.vex_w then 8 else 4;
            evex_masked_mem_store(m, zero_extend(extracted), evex_kmask64(pfx), 32, elem)
          },
        }
      },
      _ => raise_UD(),
    }
  },

  // 0F3A 1D: VCVTPS2PH (66, W=0) — convert FP32 to FP16 with imm8 rounding
  29 => {
    if mp != MP_66 | pfx.rex_w then raise_UD();
    let modrm = fetch(1);
    let src = evex_reg_idx(modrm, pfx);
    match pfx.evex_ll {
      0 => {
        let dest = modrm_rm_evex(modrm, pfx, 8);
        let imm = fetch(1);
        let rc : bits(2) = if imm[2] == 0b0 then imm[1..0] else __stmxcsr()[14..13];
        let res = avx_vcvtps2ph(read_simd(128, src), rc);
        match dest {
          RM_reg(_) => write_simd(128, evex_rm_reg_idx(modrm, pfx), zero_extend(res)),
          RM_mem(m) => evex_masked_mem_store(m, zero_extend(res), evex_kmask64(pfx), 8, 2)
        }
      },
      1 => {
        let dest = modrm_rm_evex(modrm, pfx, 16);
        let imm = fetch(1);
        let rc : bits(2) = if imm[2] == 0b0 then imm[1..0] else __stmxcsr()[14..13];
        let res = avx_vcvtps2ph(read_simd(256, src), rc);
        match dest {
          RM_reg(_) => write_simd(128, evex_rm_reg_idx(modrm, pfx), res),
          RM_mem(m) => evex_masked_mem_store(m, zero_extend(res), evex_kmask64(pfx), 16, 2)
        }
      },
      2 => {
        let dest = modrm_rm_evex(modrm, pfx, 32);
        let imm = fetch(1);
        let rc : bits(2) = if imm[2] == 0b0 then imm[1..0] else __stmxcsr()[14..13];
        let res = avx_vcvtps2ph(ZMM[src], rc);
        match dest {
          RM_reg(_) => write_simd(256, evex_rm_reg_idx(modrm, pfx), res),
          RM_mem(m) => evex_masked_mem_store(m, zero_extend(res), evex_kmask64(pfx), 32, 2)
        }
      },
      3 => raise_UD(),
    }
  },

  // 0F3A 1E: VPCMPUD (66, W=0) / VPCMPUQ (66, W=1) — unsigned dword/qword compare → kmask
  // 0F3A 1E: VPCMPUD (66, W=0) / VPCMPUQ (66, W=1) — unsigned dword/qword compare → kmask
  30 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst_k : range(0, 7) = unsigned(modrm[5..3]);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let imm = fetch(1);
    let pred : range(0, 7) = unsigned(imm[2..0]);
    match (pfx.rex_w, pfx.evex_ll) {
      // VPCMPUQ (m64bcst, W=1)
      (true, 0) => write_kreg(dst_k, avx_pcmpuq(read_simd(pfx.evex_vvvvv), evex_bcast_src(128,modrm, src, pfx, 64), pred) & evex_kmask64(pfx)),
      (true, 1) => write_kreg(dst_k, avx_pcmpuq(read_simd(256, pfx.evex_vvvvv), evex_bcast_src(256,modrm, src, pfx, 64), pred) & evex_kmask64(pfx)),
      (true, 2) => write_kreg(dst_k, avx_pcmpuq(ZMM[pfx.evex_vvvvv], evex_bcast_src(512,modrm, src, pfx, 64), pred) & evex_kmask64(pfx)),
      // VPCMPUD (m32bcst, W=0)
      (false, 0) => write_kreg(dst_k, avx_pcmpud(read_simd(pfx.evex_vvvvv), evex_bcast_src(128,modrm, src, pfx, 32), pred) & evex_kmask64(pfx)),
      (false, 1) => write_kreg(dst_k, avx_pcmpud(read_simd(256, pfx.evex_vvvvv), evex_bcast_src(256,modrm, src, pfx, 32), pred) & evex_kmask64(pfx)),
      (false, 2) => write_kreg(dst_k, avx_pcmpud(ZMM[pfx.evex_vvvvv], evex_bcast_src(512,modrm, src, pfx, 32), pred) & evex_kmask64(pfx)),
      _ => raise_UD(),
    }
  },

  // 0F3A 1F: VPCMPD (66, W=0) / VPCMPQ (66, W=1) — signed dword/qword compare → kmask
  // 0F3A 1F: VPCMPD (66, W=0) / VPCMPQ (66, W=1) — signed dword/qword compare → kmask
  31 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst_k : range(0, 7) = unsigned(modrm[5..3]);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let imm = fetch(1);
    let pred : range(0, 7) = unsigned(imm[2..0]);
    match (pfx.rex_w, pfx.evex_ll) {
      // VPCMPQ (m64bcst, W=1)
      (true, 0) => write_kreg(dst_k, avx_pcmpq(read_simd(pfx.evex_vvvvv), evex_bcast_src(128,modrm, src, pfx, 64), pred) & evex_kmask64(pfx)),
      (true, 1) => write_kreg(dst_k, avx_pcmpq(read_simd(256, pfx.evex_vvvvv), evex_bcast_src(256,modrm, src, pfx, 64), pred) & evex_kmask64(pfx)),
      (true, 2) => write_kreg(dst_k, avx_pcmpq(ZMM[pfx.evex_vvvvv], evex_bcast_src(512,modrm, src, pfx, 64), pred) & evex_kmask64(pfx)),
      // VPCMPD (m32bcst, W=0)
      (false, 0) => write_kreg(dst_k, avx_pcmpd(read_simd(pfx.evex_vvvvv), evex_bcast_src(128,modrm, src, pfx, 32), pred) & evex_kmask64(pfx)),
      (false, 1) => write_kreg(dst_k, avx_pcmpd(read_simd(256, pfx.evex_vvvvv), evex_bcast_src(256,modrm, src, pfx, 32), pred) & evex_kmask64(pfx)),
      (false, 2) => write_kreg(dst_k, avx_pcmpd(ZMM[pfx.evex_vvvvv], evex_bcast_src(512,modrm, src, pfx, 32), pred) & evex_kmask64(pfx)),
      _ => raise_UD(),
    }
  },

  // 0F3A 25: VPTERNLOGD (66, W=0) / VPTERNLOGQ (66, W=1)
  // 0F3A 25: VPTERNLOGD (66, W=0) / VPTERNLOGQ (66, W=1)
  37 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let imm = fetch(1);
    match (pfx.rex_w, pfx.evex_ll) {
      // VPTERNLOGQ (m64bcst, W=1)
      (true, 0) => {
        let a : xmmword = read_simd(dst);
        let b : xmmword = read_simd(pfx.evex_vvvvv);
        let c = evex_bcast_src(128,modrm, src, pfx, 64);
        evex_write(dst, evex_wmask(pfx, 2), vpternlog(a, b, c, imm))
      },
      (true, 1) => {
        let a = read_simd(256, dst);
        let b = read_simd(256, pfx.evex_vvvvv);
        let c = evex_bcast_src(256,modrm, src, pfx, 64);
        evex_write(dst, evex_wmask(pfx, 4), vpternlog(a, b, c, imm))
      },
      (true, 2) => {
        let a = ZMM[dst];
        let b = ZMM[pfx.evex_vvvvv];
        let c = evex_bcast_src(512,modrm, src, pfx, 64);
        evex_write(dst, evex_wmask(pfx, 8), vpternlog(a, b, c, imm))
      },
      // VPTERNLOGD (m32bcst, W=0)
      (false, 0) => {
        let a : xmmword = read_simd(dst);
        let b : xmmword = read_simd(pfx.evex_vvvvv);
        let c = evex_bcast_src(128,modrm, src, pfx, 32);
        evex_write(dst, evex_wmask(pfx, 4), vpternlog(a, b, c, imm))
      },
      (false, 1) => {
        let a = read_simd(256, dst);
        let b = read_simd(256, pfx.evex_vvvvv);
        let c = evex_bcast_src(256,modrm, src, pfx, 32);
        evex_write(dst, evex_wmask(pfx, 8), vpternlog(a, b, c, imm))
      },
      (false, 2) => {
        let a = ZMM[dst];
        let b = ZMM[pfx.evex_vvvvv];
        let c = evex_bcast_src(512,modrm, src, pfx, 32);
        evex_write(dst, evex_wmask(pfx, 16), vpternlog(a, b, c, imm))
      },
      _ => raise_UD(),
    }
  },

  // 0F3A 20: VPINSRB (66) — insert byte from GPR/mem into XMM
  // 0F3A 20: VPINSRB (66) — insert byte from GPR/mem into XMM
  32 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, 1);
    let byte_val : byte = match src {
      RM_reg(_) => v(32, modrm_rm_reg(modrm, pfx))[7..0],
      RM_mem(m) => v(m),
    };
    let imm = fetch(1);
    let sel : range(0, 15) = unsigned(imm[3..0]);
    var result : xmmword = read_simd(pfx.evex_vvvvv);
    let lo : range(0, 120) = sel * 8;
    result[(lo + 7)..lo] = byte_val;
    write_simd(128, dst, result)
  },

  // 0F3A 21: VINSERTPS (66, W=0) — insert single-precision from XMM/mem into XMM
  // 0F3A 21: VINSERTPS (66, W=0) — insert single-precision from XMM/mem into XMM
  33 => {
    if mp != MP_66 | pfx.vex_w then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, 4);
    let imm = fetch(1);
    // For register source: imm8[7:6] selects which float from src
    // For memory source: always reads a single 32-bit float
    let src_float : dword = match src {
      RM_reg(_) => {
        let src_xmm : xmmword = read_simd(evex_rm_reg_idx(modrm, pfx));
        let count_s : range(0, 3) = unsigned(imm[7..6]);
        let slo : range(0, 96) = count_s * 32;
        src_xmm[(slo + 31)..slo]
      },
      RM_mem(m) => v(m),
    };
    // imm8[5:4] selects destination float position
    let count_d : range(0, 3) = unsigned(imm[5..4]);
    let dlo : range(0, 96) = count_d * 32;
    var result : xmmword = read_simd(pfx.evex_vvvvv);
    result[(dlo + 31)..dlo] = src_float;
    // imm8[3:0] = zero mask for each float (branchless)
    result[31..0]   = result[31..0]   & sign_extend(~(imm[0]));
    result[63..32]  = result[63..32]  & sign_extend(~(imm[1]));
    result[95..64]  = result[95..64]  & sign_extend(~(imm[2]));
    result[127..96] = result[127..96] & sign_extend(~(imm[3]));
    write_simd(128, dst, result)
  },

  // 0F3A 22: VPINSRD (66, W=0) / VPINSRQ (66, W=1) — insert dword/qword from GPR/mem into XMM
  // 0F3A 22: VPINSRD (66, W=0) / VPINSRQ (66, W=1) — insert dword/qword from GPR/mem into XMM
  34 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    if pfx.vex_w then {
      // VPINSRQ: imm8[0] selects qword position
      let src = modrm_rm_evex(modrm, pfx, 8);
      let qword_val : qword = v(src);
      let imm = fetch(1);
      let sel : range(0, 1) = unsigned(imm[0]);
      var result : xmmword = read_simd(pfx.evex_vvvvv);
      let lo : range(0, 64) = sel * 64;
      result[(lo + 63)..lo] = qword_val;
      write_simd(128, dst, result)
    } else {
      // VPINSRD: imm8[1:0] selects dword position
      let src = modrm_rm_evex(modrm, pfx, 4);
      let dword_val : dword = v(src);
      let imm = fetch(1);
      let sel : range(0, 3) = unsigned(imm[1..0]);
      var result : xmmword = read_simd(pfx.evex_vvvvv);
      let lo : range(0, 96) = sel * 32;
      result[(lo + 31)..lo] = dword_val;
      write_simd(128, dst, result)
    }
  },

  // 0F3A 38: VINSERTI32X4 (66, W=0) / VINSERTI64X2 (66, W=1) — insert 128-bit (integer) into 256/512
  // 0F3A 38: VINSERTI32X4 (66, W=0) / VINSERTI64X2 (66, W=1) — insert 128-bit (integer) into 256/512
  56 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, 16);
    let src2 : xmmword = evex_src(128,modrm, src, pfx);
    let imm = fetch(1);
    match pfx.evex_ll {
      1 => {
        var result = read_simd(256, pfx.evex_vvvvv);
        if imm[0] == 0b0 then result[127..0] = src2
        else result[255..128] = src2;
        if pfx.vex_w then evex_write(dst, evex_wmask(pfx, 4), result)
        else evex_write(dst, evex_wmask(pfx, 8), result)
      },
      2 => {
        var result = ZMM[pfx.evex_vvvvv];
        let sel : range(0, 3) = unsigned(imm[1..0]);
        match sel {
          0 => result[127..0] = src2,
          1 => result[255..128] = src2,
          2 => result[383..256] = src2,
          3 => result[511..384] = src2,
        };
        if pfx.vex_w then evex_write(dst, evex_wmask(pfx, 8), result)
        else evex_write(dst, evex_wmask(pfx, 16), result)
      },
      _ => raise_UD(),
    }
  },

  // 0F3A 39: VEXTRACTI32X4 (66, W=0) / VEXTRACTI64X2 (66, W=1) — extract 128-bit from 256/512
  // 0F3A 39: VEXTRACTI32X4 (66, W=0) / VEXTRACTI64X2 (66, W=1) — extract 128-bit from 256/512
  57 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let src = evex_reg_idx(modrm, pfx);
    let dest = modrm_rm_evex(modrm, pfx, 16);
    let imm = fetch(1);
    match pfx.evex_ll {
      1 => {
        let src_ymm = read_simd(256, src);
        let extracted : xmmword = (src_ymm >> (unsigned(zero_extend(imm[0]) : bits(1)) * 128))[127..0];
        match dest {
          RM_reg(_) => {
            if pfx.vex_w then evex_write(evex_rm_reg_idx(modrm, pfx), evex_wmask(pfx, 2), extracted)
            else evex_write(evex_rm_reg_idx(modrm, pfx), evex_wmask(pfx, 4), extracted)
          },
          RM_mem(m) => {
            let elem : {4, 8} = if pfx.vex_w then 8 else 4;
            evex_masked_mem_store(m, zero_extend(extracted), evex_kmask64(pfx), 16, elem)
          },
        }
      },
      2 => {
        let src_zmm = ZMM[src];
        let sel : range(0, 3) = unsigned(imm[1..0]);
        let extracted : xmmword = match sel {
          0 => src_zmm[127..0],
          1 => src_zmm[255..128],
          2 => src_zmm[383..256],
          3 => src_zmm[511..384],
        };
        match dest {
          RM_reg(_) => {
            if pfx.vex_w then evex_write(evex_rm_reg_idx(modrm, pfx), evex_wmask(pfx, 2), extracted)
            else evex_write(evex_rm_reg_idx(modrm, pfx), evex_wmask(pfx, 4), extracted)
          },
          RM_mem(m) => {
            let elem : {4, 8} = if pfx.vex_w then 8 else 4;
            evex_masked_mem_store(m, zero_extend(extracted), evex_kmask64(pfx), 16, elem)
          },
        }
      },
      _ => raise_UD(),
    }
  },

  // 0F3A 3A: VINSERTI32X8 (66, W=0) / VINSERTI64X4 (66, W=1) — insert 256-bit into 512
  // 0F3A 3A: VINSERTI32X8 (66, W=0) / VINSERTI64X4 (66, W=1) — insert 256-bit into 512
  58 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, 32);
    let src2 : ymmword = evex_src(256,modrm, src, pfx);
    let imm = fetch(1);
    match pfx.evex_ll {
      2 => {
        var result = ZMM[pfx.evex_vvvvv];
        if imm[0] == 0b0 then result[255..0] = src2
        else result[511..256] = src2;
        if pfx.vex_w then evex_write(dst, evex_wmask(pfx, 8), result)
        else evex_write(dst, evex_wmask(pfx, 16), result)
      },
      _ => raise_UD(),
    }
  },

  // 0F3A 3B: VEXTRACTI32X8 (66, W=0) / VEXTRACTI64X4 (66, W=1) — extract 256-bit from 512
  // 0F3A 3B: VEXTRACTI32X8 (66, W=0) / VEXTRACTI64X4 (66, W=1) — extract 256-bit from 512
  59 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let src = evex_reg_idx(modrm, pfx);
    let dest = modrm_rm_evex(modrm, pfx, 32);
    let imm = fetch(1);
    match pfx.evex_ll {
      2 => {
        let src_zmm = ZMM[src];
        let extracted : ymmword = (src_zmm >> (unsigned(zero_extend(imm[0]) : bits(1)) * 256))[255..0];
        match dest {
          RM_reg(_) => {
            if pfx.vex_w then evex_write(evex_rm_reg_idx(modrm, pfx), evex_wmask(pfx, 4), extracted)
            else evex_write(evex_rm_reg_idx(modrm, pfx), evex_wmask(pfx, 8), extracted)
          },
          RM_mem(m) => {
            let elem : {4, 8} = if pfx.vex_w then 8 else 4;
            evex_masked_mem_store(m, zero_extend(extracted), evex_kmask64(pfx), 32, elem)
          },
        }
      },
      _ => raise_UD(),
    }
  },

  // 0F3A 3E: VPCMPUB (66, W=0) / VPCMPUW (66, W=1) — unsigned byte/word compare → kmask
  // 0F3A 3E: VPCMPUB (66, W=0) / VPCMPUW (66, W=1) — unsigned byte/word compare → kmask
  62 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst_k : range(0, 7) = unsigned(modrm[5..3]);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let imm = fetch(1);
    let pred : range(0, 7) = unsigned(imm[2..0]);
    match (pfx.rex_w, pfx.evex_ll) {
      // VPCMPUW (word, W=1)
      (true, 0) => write_kreg(dst_k, avx_pcmpuw(read_simd(pfx.evex_vvvvv), evex_src(128,modrm, src, pfx), pred) & evex_kmask64(pfx)),
      (true, 1) => write_kreg(dst_k, avx_pcmpuw(read_simd(256, pfx.evex_vvvvv), evex_src(256,modrm, src, pfx), pred) & evex_kmask64(pfx)),
      (true, 2) => write_kreg(dst_k, avx_pcmpuw(ZMM[pfx.evex_vvvvv], evex_src(512,modrm, src, pfx), pred) & evex_kmask64(pfx)),
      // VPCMPUB (byte, W=0)
      (false, 0) => write_kreg(dst_k, avx_pcmpub(read_simd(pfx.evex_vvvvv), evex_src(128,modrm, src, pfx), pred) & evex_kmask64(pfx)),
      (false, 1) => write_kreg(dst_k, avx_pcmpub(read_simd(256, pfx.evex_vvvvv), evex_src(256,modrm, src, pfx), pred) & evex_kmask64(pfx)),
      (false, 2) => write_kreg(dst_k, avx_pcmpub(ZMM[pfx.evex_vvvvv], evex_src(512,modrm, src, pfx), pred) & evex_kmask64(pfx)),
      _ => raise_UD(),
    }
  },

  // 0F3A 3F: VPCMPB (66, W=0) / VPCMPW (66, W=1) — signed byte/word compare → kmask
  // 0F3A 3F: VPCMPB (66, W=0) / VPCMPW (66, W=1) — signed byte/word compare → kmask
  63 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst_k : range(0, 7) = unsigned(modrm[5..3]);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let imm = fetch(1);
    let pred : range(0, 7) = unsigned(imm[2..0]);
    match (pfx.rex_w, pfx.evex_ll) {
      // VPCMPW (word, W=1)
      (true, 0) => write_kreg(dst_k, avx_pcmpw(read_simd(pfx.evex_vvvvv), evex_src(128,modrm, src, pfx), pred) & evex_kmask64(pfx)),
      (true, 1) => write_kreg(dst_k, avx_pcmpw(read_simd(256, pfx.evex_vvvvv), evex_src(256,modrm, src, pfx), pred) & evex_kmask64(pfx)),
      (true, 2) => write_kreg(dst_k, avx_pcmpw(ZMM[pfx.evex_vvvvv], evex_src(512,modrm, src, pfx), pred) & evex_kmask64(pfx)),
      // VPCMPB (byte, W=0)
      (false, 0) => write_kreg(dst_k, avx_pcmpb(read_simd(pfx.evex_vvvvv), evex_src(128,modrm, src, pfx), pred) & evex_kmask64(pfx)),
      (false, 1) => write_kreg(dst_k, avx_pcmpb(read_simd(256, pfx.evex_vvvvv), evex_src(256,modrm, src, pfx), pred) & evex_kmask64(pfx)),
      (false, 2) => write_kreg(dst_k, avx_pcmpb(ZMM[pfx.evex_vvvvv], evex_src(512,modrm, src, pfx), pred) & evex_kmask64(pfx)),
      _ => raise_UD(),
    }
  },

  // 0F3A 08: VRNDSCALEPS (66, W=0) / VRNDSCALEPH (NP, W=0)
  8 => {
    if pfx.vex_w then raise_UD();
    match mp {
      MP_66 => {
        let modrm = fetch(1);
        let dst = evex_reg_idx(modrm, pfx);
        let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
        let is_mem : bool = match src { RM_mem(_) => true, _ => false };
        let imm = fetch(1);
        match pfx.evex_ll {
          0 => evex_write(dst, evex_wmask(pfx, 4), avx_vrndscale(32,evex_bcast_src(128,modrm, src, pfx, 32), imm)),
          1 => evex_write(dst, evex_wmask(pfx, 8), avx_vrndscale(32,evex_bcast_src(256,modrm, src, pfx, 32), imm)),
          2 => evex_write(dst, evex_wmask(pfx, 16), avx_vrndscale(32,evex_bcast_src(512,modrm, src, pfx, 32), imm)),
          3 => raise_UD(),
        }
      },
      MP_NONE => {
        // VRNDSCALEPH: packed FP16 round
        let modrm = fetch(1);
        let dst = evex_reg_idx(modrm, pfx);
        let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
        let is_mem : bool = match src { RM_mem(_) => true, _ => false };
        let imm = fetch(1);
        match pfx.evex_ll {
          0 => {
            let src = evex_bcast_src(128,modrm, src, pfx, 16);
            let r = vrndscaleph(src, imm);
            evex_write(dst, evex_wmask(pfx, 8), r)
          },
          1 => {
            let src = evex_bcast_src(256,modrm, src, pfx, 16);
            let r = vrndscaleph(src, imm);
            evex_write(dst, evex_wmask(pfx, 16), r)
          },
          2 => {
            let src = evex_bcast_src(512,modrm, src, pfx, 16);
            let r = vrndscaleph(src, imm);
            evex_write(dst, evex_wmask(pfx, 32), r)
          },
          3 => raise_UD(),
        }
      },
      _ => raise_UD(),
    }
  },

  // 0F3A 09: VRNDSCALEPD (66, W=1) — round packed double-precision
  // 0F3A 09: VRNDSCALEPD (66, W=1) — round packed double-precision
  9 => {
    if mp != MP_66 | ~(pfx.vex_w) then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let imm = fetch(1);
    match pfx.evex_ll {
      0 => evex_write(dst, evex_wmask(pfx, 2), avx_vrndscale(64,evex_bcast_src(128,modrm, src, pfx, 64), imm)),
      1 => evex_write(dst, evex_wmask(pfx, 4), avx_vrndscale(64,evex_bcast_src(256,modrm, src, pfx, 64), imm)),
      2 => evex_write(dst, evex_wmask(pfx, 8), avx_vrndscale(64,evex_bcast_src(512,modrm, src, pfx, 64), imm)),
      3 => raise_UD(),
    }
  },

  // 0F3A 0A: VRNDSCALESS (66, W=0) / VRNDSCALESH (NP, W=0)
  10 => {
    if pfx.vex_w then raise_UD();
    match mp {
      MP_66 => {
        let modrm = fetch(1);
        let dst = evex_reg_idx(modrm, pfx);
        let src = modrm_rm_evex(modrm, pfx, 4);
        let imm = fetch(1);
        let src1 : xmmword = read_simd(pfx.evex_vvvvv);
        let src2 = evex_src(128,modrm, src, pfx);
        let r = fp_rndscale(src2[31..0], imm);
        evex_write_scalar(dst, src1[127..32] @ r, pfx, 32)
      },
      MP_NONE => {
        // VRNDSCALESH: scalar FP16 round
        let modrm = fetch(1);
        let dst = evex_reg_idx(modrm, pfx);
        let src = modrm_rm_evex(modrm, pfx, 2);
        let imm = fetch(1);
        let src1 : xmmword = read_simd(pfx.evex_vvvvv);
        let src2 = evex_src(128,modrm, src, pfx);
        let r : word = fp_rndscale(src2[15..0], imm);
        evex_write_scalar(dst, src1[127..16] @ r, pfx, 16)
      },
      _ => raise_UD(),
    }
  },

  // 0F3A 0B: VRNDSCALESD (66, W=1) — round scalar double-precision
  // 0F3A 0B: VRNDSCALESD (66, W=1) — round scalar double-precision
  11 => {
    if mp != MP_66 | ~(pfx.vex_w) then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, 8);
    let imm = fetch(1);
    let src1 : xmmword = read_simd(pfx.evex_vvvvv);
    let src2 = evex_src(128,modrm, src, pfx);
    let r = fp_rndscale(src2[63..0], imm);
    evex_write_scalar(dst, src1[127..64] @ r, pfx, 64)
  },

  // 0F3A 23: VSHUFF32X4 (66, W=0) / VSHUFF64X2 (66, W=1) — shuffle 128-bit lanes (FP)
  // 0F3A 23: VSHUFF32X4 (66, W=0) / VSHUFF64X2 (66, W=1) — shuffle 128-bit lanes (FP)
  35 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let imm = fetch(1);
    match (pfx.vex_w, pfx.evex_ll) {
      (true, 1)  => evex_write(dst, evex_wmask(pfx, 4), avx_shuf_f32x4_256(read_simd(256, pfx.evex_vvvvv), evex_bcast_src(256,modrm, src, pfx, 64), imm)),
      (true, 2)  => evex_write(dst, evex_wmask(pfx, 8), avx_shuf_f32x4_512(ZMM[pfx.evex_vvvvv], evex_bcast_src(512,modrm, src, pfx, 64), imm)),
      (false, 1) => evex_write(dst, evex_wmask(pfx, 8), avx_shuf_f32x4_256(read_simd(256, pfx.evex_vvvvv), evex_bcast_src(256,modrm, src, pfx, 32), imm)),
      (false, 2) => evex_write(dst, evex_wmask(pfx, 16), avx_shuf_f32x4_512(ZMM[pfx.evex_vvvvv], evex_bcast_src(512,modrm, src, pfx, 32), imm)),
      (_, _)     => raise_UD(),
    }
  },

  // 0F3A 26: VGETMANTPS (66, W=0) / VGETMANTPD (66, W=1) / VGETMANTPH (NP, W=0)
  38 => {
    match mp {
      MP_66 => {
        let modrm = fetch(1);
        let dst = evex_reg_idx(modrm, pfx);
        let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
        let is_mem : bool = match src { RM_mem(_) => true, _ => false };
        let imm = fetch(1);
        match (pfx.vex_w, pfx.evex_ll) {
          // VGETMANTPD xmm1/ymm1/zmm1, xmm2/ymm2/zmm2/m128/m256/m512, imm8
          (true, 0) => evex_write(dst, evex_wmask(pfx, 2), avx_vgetmant(64,evex_bcast_src(128,modrm, src, pfx, 64), imm)),
          (true, 1)  => evex_write(dst, evex_wmask(pfx, 4), avx_vgetmant(64,evex_bcast_src(256,modrm, src, pfx, 64), imm)),
          (true, 2)  => evex_write(dst, evex_wmask(pfx, 8), avx_vgetmant(64,evex_bcast_src(512,modrm, src, pfx, 64), imm)),
          // VGETMANTPS xmm1/ymm1/zmm1, xmm2/ymm2/zmm2/m128/m256/m512, imm8
          (false, 0) => evex_write(dst, evex_wmask(pfx, 4), avx_vgetmant(32,evex_bcast_src(128,modrm, src, pfx, 32), imm)),
          (false, 1) => evex_write(dst, evex_wmask(pfx, 8), avx_vgetmant(32,evex_bcast_src(256,modrm, src, pfx, 32), imm)),
          (false, 2) => evex_write(dst, evex_wmask(pfx, 16), avx_vgetmant(32,evex_bcast_src(512,modrm, src, pfx, 32), imm)),
          _ => raise_UD(),
        }
      },
      MP_NONE => {
        // VGETMANTPH: packed FP16 extract mantissa
        if pfx.vex_w then raise_UD();
        let modrm = fetch(1);
        let dst = evex_reg_idx(modrm, pfx);
        let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
        let is_mem : bool = match src { RM_mem(_) => true, _ => false };
        let imm = fetch(1);
        match pfx.evex_ll {
          0 => {
            let src = evex_bcast_src(128,modrm, src, pfx, 16);
            let r = vgetmantph(src, imm);
            evex_write(dst, evex_wmask(pfx, 8), r)
          },
          1 => {
            let src = evex_bcast_src(256,modrm, src, pfx, 16);
            let r = vgetmantph(src, imm);
            evex_write(dst, evex_wmask(pfx, 16), r)
          },
          2 => {
            let src = evex_bcast_src(512,modrm, src, pfx, 16);
            let r = vgetmantph(src, imm);
            evex_write(dst, evex_wmask(pfx, 32), r)
          },
          3 => raise_UD(),
        }
      },
      _ => raise_UD(),
    }
  },

  // 0F3A 27: VGETMANTSS (66, W=0) / VGETMANTSD (66, W=1) / VGETMANTSH (NP, W=0)
  39 => {
    match mp {
      MP_66 => {
        let modrm = fetch(1);
        let dst = evex_reg_idx(modrm, pfx);
        let src = modrm_rm_evex(modrm, pfx, if pfx.vex_w then 8 else 4);
        let imm = fetch(1);
        let src1 : xmmword = read_simd(pfx.evex_vvvvv);
        let src2 = evex_src(128,modrm, src, pfx);
        if pfx.vex_w
        then evex_write_scalar(dst, src1[127..64] @ fp_getmant(src2[63..0], imm), pfx, 64)
        else evex_write_scalar(dst, src1[127..32] @ fp_getmant(src2[31..0], imm), pfx, 32)
      },
      MP_NONE => {
        // VGETMANTSH: scalar FP16 extract mantissa
        if pfx.vex_w then raise_UD();
        let modrm = fetch(1);
        let dst = evex_reg_idx(modrm, pfx);
        let src = modrm_rm_evex(modrm, pfx, 2);
        let imm = fetch(1);
        let src1 : xmmword = read_simd(pfx.evex_vvvvv);
        let src2 = evex_src(128,modrm, src, pfx);
        let r : word = fp_getmant(src2[15..0], imm);
        evex_write_scalar(dst, src1[127..16] @ r, pfx, 16)
      },
      _ => raise_UD(),
    }
  },

  // 0F3A 42: VDBPSADBW (66, W=0) — double block packed sum of absolute differences
  // 0F3A 42: VDBPSADBW (66, W=0) — double block packed sum of absolute differences
  66 => {
    if mp != MP_66 | pfx.vex_w then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let imm = fetch(1);
    match pfx.evex_ll {
      0 => evex_write(dst, evex_wmask(pfx, 8), avx_vdbpsadbw_128(read_simd(pfx.evex_vvvvv), evex_src(128,modrm, src, pfx), imm)),
      1 => evex_write(dst, evex_wmask(pfx, 16), avx_vdbpsadbw(read_simd(256, pfx.evex_vvvvv), evex_src(256,modrm, src, pfx), imm)),
      2 => evex_write(dst, evex_wmask(pfx, 32), avx_vdbpsadbw(ZMM[pfx.evex_vvvvv], evex_src(512,modrm, src, pfx), imm)),
      3 => raise_UD(),
    }
  },

  // 0F3A 43: VSHUFI32X4 (66, W=0) / VSHUFI64X2 (66, W=1) — shuffle 128-bit lanes (integer)
  // 0F3A 43: VSHUFI32X4 (66, W=0) / VSHUFI64X2 (66, W=1) — shuffle 128-bit lanes (integer)
  67 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let imm = fetch(1);
    match (pfx.vex_w, pfx.evex_ll) {
      (true, 1)  => evex_write(dst, evex_wmask(pfx, 4), avx_shuf_f32x4_256(read_simd(256, pfx.evex_vvvvv), evex_bcast_src(256,modrm, src, pfx, 64), imm)),
      (true, 2)  => evex_write(dst, evex_wmask(pfx, 8), avx_shuf_f32x4_512(ZMM[pfx.evex_vvvvv], evex_bcast_src(512,modrm, src, pfx, 64), imm)),
      (false, 1) => evex_write(dst, evex_wmask(pfx, 8), avx_shuf_f32x4_256(read_simd(256, pfx.evex_vvvvv), evex_bcast_src(256,modrm, src, pfx, 32), imm)),
      (false, 2) => evex_write(dst, evex_wmask(pfx, 16), avx_shuf_f32x4_512(ZMM[pfx.evex_vvvvv], evex_bcast_src(512,modrm, src, pfx, 32), imm)),
      (_, _)     => raise_UD(),
    }
  },

  // 0F3A 44: VPCLMULQDQ (66) — carry-less multiply per 128-bit lane [VPCLMULQDQ]
  // 0F3A 44: VPCLMULQDQ (66) — carry-less multiply per 128-bit lane [VPCLMULQDQ]
  68 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let imm = fetch(1);
    let src1_idx = pfx.evex_vvvvv;
    match pfx.evex_ll {
      0 => evex_write(dst, evex_wmask(pfx, 2), avx_vpclmulqdq(read_simd(src1_idx), evex_src(128,modrm, src, pfx), imm)),
      1 => evex_write(dst, evex_wmask(pfx, 4), avx_vpclmulqdq(read_simd(256, src1_idx), evex_src(256,modrm, src, pfx), imm)),
      2 => evex_write(dst, evex_wmask(pfx, 8), avx_vpclmulqdq(ZMM[src1_idx], evex_src(512,modrm, src, pfx), imm)),
      3 => raise_UD(),
    }
  },

  // 0F3A 50: VRANGEPS (66, W=0) / VRANGEPD (66, W=1) — range restriction packed [DQ]
  // 0F3A 50: VRANGEPS (66, W=0) / VRANGEPD (66, W=1) — range restriction packed [DQ]
  80 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let imm = fetch(1);
    match (pfx.vex_w, pfx.evex_ll) {
      (true, 0) => evex_write(dst, evex_wmask(pfx, 2), avx_vrange(64,read_simd(pfx.evex_vvvvv), evex_bcast_src(128,modrm, src, pfx, 64), imm)),
      (true, 1)  => evex_write(dst, evex_wmask(pfx, 4), avx_vrange(64,read_simd(256, pfx.evex_vvvvv), evex_bcast_src(256,modrm, src, pfx, 64), imm)),
      (true, 2)  => evex_write(dst, evex_wmask(pfx, 8), avx_vrange(64,ZMM[pfx.evex_vvvvv], evex_bcast_src(512,modrm, src, pfx, 64), imm)),
      (false, 0) => evex_write(dst, evex_wmask(pfx, 4), avx_vrange(32,read_simd(pfx.evex_vvvvv), evex_bcast_src(128,modrm, src, pfx, 32), imm)),
      (false, 1) => evex_write(dst, evex_wmask(pfx, 8), avx_vrange(32,read_simd(256, pfx.evex_vvvvv), evex_bcast_src(256,modrm, src, pfx, 32), imm)),
      (false, 2) => evex_write(dst, evex_wmask(pfx, 16), avx_vrange(32,ZMM[pfx.evex_vvvvv], evex_bcast_src(512,modrm, src, pfx, 32), imm)),
      _ => raise_UD(),
    }
  },

  // 0F3A 51: VRANGESS (66, W=0) / VRANGESD (66, W=1) — range restriction scalar [DQ]
  81 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, if pfx.vex_w then 8 else 4);
    let imm = fetch(1);
    let src1 : xmmword = read_simd(pfx.evex_vvvvv);
    if pfx.vex_w then {
      let src2 : qword = match src {
        RM_reg(_) => read_simd(128, evex_rm_reg_idx(modrm, pfx))[63..0],
        RM_mem(m) => v(m),
      };
      let r = avx_range_f64(src1[63..0], src2, imm);
      evex_write_scalar(dst, src1[127..64] @ r, pfx, 64)
    } else {
      let src2 : dword = match src {
        RM_reg(_) => read_simd(128, evex_rm_reg_idx(modrm, pfx))[31..0],
        RM_mem(m) => v(m),
      };
      let r = avx_range_f32(src1[31..0], src2, imm);
      evex_write_scalar(dst, src1[127..32] @ r, pfx, 32)
    }
  },

  // 0F3A 54: VFIXUPIMMPS (66, W=0) / VFIXUPIMMPD (66, W=1) — fixup packed
  // 0F3A 54: VFIXUPIMMPS (66, W=0) / VFIXUPIMMPD (66, W=1) — fixup packed
  84 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let imm = fetch(1);
    match (pfx.vex_w, pfx.evex_ll) {
      // VFIXUPIMMPD xmm1/ymm1/zmm1, xmm2/ymm2/zmm2, xmm3/ymm3/zmm3/m128/m256/m512, imm8
      (true, 0) => evex_write(dst, evex_wmask(pfx, 2), avx_vfixupimm(64,read_simd(dst), read_simd(pfx.evex_vvvvv), evex_bcast_src(128,modrm, src, pfx, 64), imm)),
      (true, 1)  => evex_write(dst, evex_wmask(pfx, 4), avx_vfixupimm(64,read_simd(256, dst), read_simd(256, pfx.evex_vvvvv), evex_bcast_src(256,modrm, src, pfx, 64), imm)),
      (true, 2)  => evex_write(dst, evex_wmask(pfx, 8), avx_vfixupimm(64,ZMM[dst], ZMM[pfx.evex_vvvvv], evex_bcast_src(512,modrm, src, pfx, 64), imm)),
      // VFIXUPIMMPS xmm1/ymm1/zmm1, xmm2/ymm2/zmm2, xmm3/ymm3/zmm3/m128/m256/m512, imm8
      (false, 0) => evex_write(dst, evex_wmask(pfx, 4), avx_vfixupimm(32,read_simd(dst), read_simd(pfx.evex_vvvvv), evex_bcast_src(128,modrm, src, pfx, 32), imm)),
      (false, 1) => evex_write(dst, evex_wmask(pfx, 8), avx_vfixupimm(32,read_simd(256, dst), read_simd(256, pfx.evex_vvvvv), evex_bcast_src(256,modrm, src, pfx, 32), imm)),
      (false, 2) => evex_write(dst, evex_wmask(pfx, 16), avx_vfixupimm(32,ZMM[dst], ZMM[pfx.evex_vvvvv], evex_bcast_src(512,modrm, src, pfx, 32), imm)),
      _ => raise_UD(),
    }
  },

  // 0F3A 55: VFIXUPIMMSS (66, W=0) / VFIXUPIMMSD (66, W=1) — fixup scalar
  // 0F3A 55: VFIXUPIMMSS (66, W=0) / VFIXUPIMMSD (66, W=1) — fixup scalar
  85 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, if pfx.vex_w then 8 else 4);
    let imm = fetch(1);
    let src1 : xmmword = read_simd(pfx.evex_vvvvv);
    let src2 = evex_src(128,modrm, src, pfx);
    let dst_xmm : xmmword = read_simd(dst);
    // VFIXUPIMMSD xmm1, xmm2, xmm3/m64, imm8
    // VFIXUPIMMSS xmm1, xmm2, xmm3/m32, imm8
    if pfx.vex_w
    then evex_write_scalar(dst, src1[127..64] @ fp_fixupimm(dst_xmm[63..0], src1[63..0], src2[63..0], imm), pfx, 64)
    else evex_write_scalar(dst, src1[127..32] @ fp_fixupimm(dst_xmm[31..0], src1[31..0], src2[31..0], imm), pfx, 32)
  },

  // 0F3A 56: VREDUCEPS (66, W=0) / VREDUCEPD (66, W=1) / VREDUCEPH (NP, W=0)
  86 => {
    match mp {
      MP_66 => {
        let modrm = fetch(1);
        let dst = evex_reg_idx(modrm, pfx);
        let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
        let is_mem : bool = match src { RM_mem(_) => true, _ => false };
        let imm = fetch(1);
        match (pfx.vex_w, pfx.evex_ll) {
          // VREDUCEPD xmm1/ymm1/zmm1, xmm2/ymm2/zmm2/m128/m256/m512, imm8
          (true, 0) => evex_write(dst, evex_wmask(pfx, 2), avx_vreduce(64,evex_bcast_src(128,modrm, src, pfx, 64), imm)),
          (true, 1)  => evex_write(dst, evex_wmask(pfx, 4), avx_vreduce(64,evex_bcast_src(256,modrm, src, pfx, 64), imm)),
          (true, 2)  => evex_write(dst, evex_wmask(pfx, 8), avx_vreduce(64,evex_bcast_src(512,modrm, src, pfx, 64), imm)),
          // VREDUCEPS xmm1/ymm1/zmm1, xmm2/ymm2/zmm2/m128/m256/m512, imm8
          (false, 0) => evex_write(dst, evex_wmask(pfx, 4), avx_vreduce(32,evex_bcast_src(128,modrm, src, pfx, 32), imm)),
          (false, 1) => evex_write(dst, evex_wmask(pfx, 8), avx_vreduce(32,evex_bcast_src(256,modrm, src, pfx, 32), imm)),
          (false, 2) => evex_write(dst, evex_wmask(pfx, 16), avx_vreduce(32,evex_bcast_src(512,modrm, src, pfx, 32), imm)),
          _ => raise_UD(),
        }
      },
      MP_NONE => {
        // VREDUCEPH: packed FP16 reduce
        if pfx.vex_w then raise_UD();
        let modrm = fetch(1);
        let dst = evex_reg_idx(modrm, pfx);
        let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
        let is_mem : bool = match src { RM_mem(_) => true, _ => false };
        let imm = fetch(1);
        match pfx.evex_ll {
          0 => {
            let src = evex_bcast_src(128,modrm, src, pfx, 16);
            let r = vreduceph(src, imm);
            evex_write(dst, evex_wmask(pfx, 8), r)
          },
          1 => {
            let src = evex_bcast_src(256,modrm, src, pfx, 16);
            let r = vreduceph(src, imm);
            evex_write(dst, evex_wmask(pfx, 16), r)
          },
          2 => {
            let src = evex_bcast_src(512,modrm, src, pfx, 16);
            let r = vreduceph(src, imm);
            evex_write(dst, evex_wmask(pfx, 32), r)
          },
          3 => raise_UD(),
        }
      },
      _ => raise_UD(),
    }
  },

  // 0F3A 57: VREDUCESS (66, W=0) / VREDUCESD (66, W=1) / VREDUCESH (NP, W=0)
  87 => {
    match mp {
      MP_66 => {
        let modrm = fetch(1);
        let dst = evex_reg_idx(modrm, pfx);
        let src = modrm_rm_evex(modrm, pfx, if pfx.vex_w then 8 else 4);
        let imm = fetch(1);
        let src1 : xmmword = read_simd(pfx.evex_vvvvv);
        let src2 = evex_src(128,modrm, src, pfx);
        if pfx.vex_w
        then evex_write_scalar(dst, src1[127..64] @ fp_reduce(src2[63..0], imm), pfx, 64)
        else evex_write_scalar(dst, src1[127..32] @ fp_reduce(src2[31..0], imm), pfx, 32)
      },
      MP_NONE => {
        // VREDUCESH: scalar FP16 reduce
        if pfx.vex_w then raise_UD();
        let modrm = fetch(1);
        let dst = evex_reg_idx(modrm, pfx);
        let src = modrm_rm_evex(modrm, pfx, 2);
        let imm = fetch(1);
        let src1 : xmmword = read_simd(pfx.evex_vvvvv);
        let src2 = evex_src(128,modrm, src, pfx);
        let r : word = fp_reduce(src2[15..0], imm);
        evex_write_scalar(dst, src1[127..16] @ r, pfx, 16)
      },
      _ => raise_UD(),
    }
  },

  // 0F3A 66: VFPCLASSPS (66, W=0) / VFPCLASSPD (66, W=1) / VFPCLASSPH (NP, W=0)
  102 => {
    match mp {
      MP_66 => {
        let modrm = fetch(1);
        let dst_k : range(0, 7) = unsigned(modrm[5..3]);
        let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
        let is_mem : bool = match src { RM_mem(_) => true, _ => false };
        let imm = fetch(1);
        match (pfx.vex_w, pfx.evex_ll) {
          // VFPCLASSPD k1, xmm2/ymm2/zmm2/m128/m256/m512, imm8
          (true, 0) => write_kreg(dst_k, avx_vfpclasspd(evex_bcast_src(128,modrm, src, pfx, 64), imm) & evex_kmask64(pfx)),
          (true, 1) => write_kreg(dst_k, avx_vfpclasspd(evex_bcast_src(256,modrm, src, pfx, 64), imm) & evex_kmask64(pfx)),
          (true, 2) => write_kreg(dst_k, avx_vfpclasspd(evex_bcast_src(512,modrm, src, pfx, 64), imm) & evex_kmask64(pfx)),
          // VFPCLASSPS k1, xmm2/ymm2/zmm2/m128/m256/m512, imm8
          (false, 0) => write_kreg(dst_k, avx_vfpclassps(evex_bcast_src(128,modrm, src, pfx, 32), imm) & evex_kmask64(pfx)),
          (false, 1) => write_kreg(dst_k, avx_vfpclassps(evex_bcast_src(256,modrm, src, pfx, 32), imm) & evex_kmask64(pfx)),
          (false, 2) => write_kreg(dst_k, avx_vfpclassps(evex_bcast_src(512,modrm, src, pfx, 32), imm) & evex_kmask64(pfx)),
          _ => raise_UD(),
        }
      },
      MP_NONE => {
        // VFPCLASSPH: classify packed FP16 → kmask
        if pfx.vex_w then raise_UD();
        let modrm = fetch(1);
        let dst_k : range(0, 7) = unsigned(modrm[5..3]);
        let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
        let is_mem : bool = match src { RM_mem(_) => true, _ => false };
        let imm = fetch(1);
        match pfx.evex_ll {
          0 => {
            let mask : qword = vfpclassph(evex_bcast_src(128,modrm, src, pfx, 16), imm);
            let k_mask : qword = mask & evex_kmask64(pfx);
            write_kreg(dst_k, k_mask)
          },
          1 => {
            let mask : qword = vfpclassph(evex_bcast_src(256,modrm, src, pfx, 16), imm);
            let k_mask : qword = mask & evex_kmask64(pfx);
            write_kreg(dst_k, k_mask)
          },
          2 => {
            let mask : qword = vfpclassph(evex_bcast_src(512,modrm, src, pfx, 16), imm);
            let k_mask : qword = mask & evex_kmask64(pfx);
            write_kreg(dst_k, k_mask)
          },
          3 => raise_UD(),
        }
      },
      _ => raise_UD(),
    }
  },

  // 0F3A 67: VFPCLASSSS (66, W=0) / VFPCLASSSD (66, W=1) / VFPCLASSSH (NP, W=0)
  103 => {
    match mp {
      MP_66 => {
        let modrm = fetch(1);
        let dst_k : range(0, 7) = unsigned(modrm[5..3]);
        let src = modrm_rm_evex(modrm, pfx, if pfx.vex_w then 8 else 4);
        let imm = fetch(1);
        let src = evex_src(128,modrm, src, pfx);
        let result : bit = if pfx.vex_w then avx_fpclass_f64(src[63..0], imm)
                            else avx_fpclass_f32(src[31..0], imm);
        let k_val : qword = zero_extend(result);
        let k_mask : qword = k_val & evex_kmask64(pfx);
        write_kreg(dst_k, k_mask)
      },
      MP_NONE => {
        // VFPCLASSSH: classify scalar FP16 → kmask
        if pfx.vex_w then raise_UD();
        let modrm = fetch(1);
        let dst_k : range(0, 7) = unsigned(modrm[5..3]);
        let src = modrm_rm_evex(modrm, pfx, 2);
        let imm = fetch(1);
        let src = evex_src(128,modrm, src, pfx);
        let result : bit = fpclass_f16(src[15..0], imm);
        let k_val : qword = zero_extend(result);
        let k_mask : qword = k_val & evex_kmask64(pfx);
        write_kreg(dst_k, k_mask)
      },
      _ => raise_UD(),
    }
  },

  // 0F3A CE: VGF2P8AFFINEQB (66,W1) [GFNI]
  // 0F3A CE: VGF2P8AFFINEQB (66,W1) [GFNI]
  206 => {
    if mp != MP_66 | ~(pfx.rex_w) then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let imm = fetch(1);
    match pfx.evex_ll {
      0 => evex_write(dst, evex_wmask(pfx, 16), avx_gf2p8affineqb(read_simd(pfx.evex_vvvvv), evex_bcast_src(128,modrm, src, pfx, 64), imm)),
      1 => evex_write(dst, evex_wmask(pfx, 32), avx_gf2p8affineqb(read_simd(256, pfx.evex_vvvvv), evex_bcast_src(256,modrm, src, pfx, 64), imm)),
      2 => evex_write(dst, evex_wmask(pfx, 64), avx_gf2p8affineqb(ZMM[pfx.evex_vvvvv], evex_bcast_src(512,modrm, src, pfx, 64), imm)),
      3 => raise_UD(),
    }
  },

  // 0F3A CF: VGF2P8AFFINEINVQB (66,W1) [GFNI]
  // 0F3A CF: VGF2P8AFFINEINVQB (66,W1) [GFNI]
  207 => {
    if mp != MP_66 | ~(pfx.rex_w) then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let imm = fetch(1);
    match pfx.evex_ll {
      0 => evex_write(dst, evex_wmask(pfx, 16), avx_gf2p8affineinvqb(read_simd(pfx.evex_vvvvv), evex_bcast_src(128,modrm, src, pfx, 64), imm)),
      1 => evex_write(dst, evex_wmask(pfx, 32), avx_gf2p8affineinvqb(read_simd(256, pfx.evex_vvvvv), evex_bcast_src(256,modrm, src, pfx, 64), imm)),
      2 => evex_write(dst, evex_wmask(pfx, 64), avx_gf2p8affineinvqb(ZMM[pfx.evex_vvvvv], evex_bcast_src(512,modrm, src, pfx, 64), imm)),
      3 => raise_UD(),
    }
  },

  // 0F3A 70: VPSHLDW (66, W=1) [VBMI2]
  // 0F3A 70: VPSHLDW (66, W=1) [VBMI2]
  112 => {
    if mp != MP_66 | ~(pfx.rex_w) then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let imm = fetch(1);
    match pfx.evex_ll {
      0 => evex_write(dst, evex_wmask(pfx, 8), avx_vpshldw_imm(read_simd(pfx.evex_vvvvv), evex_src(128,modrm, src, pfx), imm)),
      1 => evex_write(dst, evex_wmask(pfx, 16), avx_vpshldw_imm(read_simd(256, pfx.evex_vvvvv), evex_src(256,modrm, src, pfx), imm)),
      2 => evex_write(dst, evex_wmask(pfx, 32), avx_vpshldw_imm(ZMM[pfx.evex_vvvvv], evex_src(512,modrm, src, pfx), imm)),
      3 => raise_UD(),
    }
  },

  // 0F3A 71: VPSHLDD (66, W=0) / VPSHLDQ (66, W=1) [VBMI2]
  // 0F3A 71: VPSHLDD (66, W=0) / VPSHLDQ (66, W=1) [VBMI2]
  113 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let imm = fetch(1);
    match (pfx.rex_w, pfx.evex_ll) {
      // VPSHLDQ (W=1)
      (true, 0) => evex_write(dst, evex_wmask(pfx, 2), avx_vpshldq_imm(read_simd(pfx.evex_vvvvv), evex_bcast_src(128,modrm, src, pfx, 64), imm)),
      (true, 1) => evex_write(dst, evex_wmask(pfx, 4), avx_vpshldq_imm(read_simd(256, pfx.evex_vvvvv), evex_bcast_src(256,modrm, src, pfx, 64), imm)),
      (true, 2) => evex_write(dst, evex_wmask(pfx, 8), avx_vpshldq_imm(ZMM[pfx.evex_vvvvv], evex_bcast_src(512,modrm, src, pfx, 64), imm)),
      // VPSHLDD (W=0)
      (false, 0) => evex_write(dst, evex_wmask(pfx, 4), avx_vpshldd_imm(read_simd(pfx.evex_vvvvv), evex_bcast_src(128,modrm, src, pfx, 32), imm)),
      (false, 1) => evex_write(dst, evex_wmask(pfx, 8), avx_vpshldd_imm(read_simd(256, pfx.evex_vvvvv), evex_bcast_src(256,modrm, src, pfx, 32), imm)),
      (false, 2) => evex_write(dst, evex_wmask(pfx, 16), avx_vpshldd_imm(ZMM[pfx.evex_vvvvv], evex_bcast_src(512,modrm, src, pfx, 32), imm)),
      _ => raise_UD(),
    }
  },

  // 0F3A 72: VPSHRDW (66, W=1) [VBMI2]
  // 0F3A 72: VPSHRDW (66, W=1) [VBMI2]
  114 => {
    if mp != MP_66 | ~(pfx.rex_w) then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let imm = fetch(1);
    match pfx.evex_ll {
      0 => evex_write(dst, evex_wmask(pfx, 8), avx_vpshrdw_imm(read_simd(pfx.evex_vvvvv), evex_src(128,modrm, src, pfx), imm)),
      1 => evex_write(dst, evex_wmask(pfx, 16), avx_vpshrdw_imm(read_simd(256, pfx.evex_vvvvv), evex_src(256,modrm, src, pfx), imm)),
      2 => evex_write(dst, evex_wmask(pfx, 32), avx_vpshrdw_imm(ZMM[pfx.evex_vvvvv], evex_src(512,modrm, src, pfx), imm)),
      3 => raise_UD(),
    }
  },

  // 0F3A 73: VPSHRDD (66, W=0) / VPSHRDQ (66, W=1) [VBMI2]
  // 0F3A 73: VPSHRDD (66, W=0) / VPSHRDQ (66, W=1) [VBMI2]
  115 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let imm = fetch(1);
    match (pfx.rex_w, pfx.evex_ll) {
      // VPSHRDQ (W=1)
      (true, 0) => evex_write(dst, evex_wmask(pfx, 2), avx_vpshrdq_imm(read_simd(pfx.evex_vvvvv), evex_bcast_src(128,modrm, src, pfx, 64), imm)),
      (true, 1) => evex_write(dst, evex_wmask(pfx, 4), avx_vpshrdq_imm(read_simd(256, pfx.evex_vvvvv), evex_bcast_src(256,modrm, src, pfx, 64), imm)),
      (true, 2) => evex_write(dst, evex_wmask(pfx, 8), avx_vpshrdq_imm(ZMM[pfx.evex_vvvvv], evex_bcast_src(512,modrm, src, pfx, 64), imm)),
      // VPSHRDD (W=0)
      (false, 0) => evex_write(dst, evex_wmask(pfx, 4), avx_vpshrdd_imm(read_simd(pfx.evex_vvvvv), evex_bcast_src(128,modrm, src, pfx, 32), imm)),
      (false, 1) => evex_write(dst, evex_wmask(pfx, 8), avx_vpshrdd_imm(read_simd(256, pfx.evex_vvvvv), evex_bcast_src(256,modrm, src, pfx, 32), imm)),
      (false, 2) => evex_write(dst, evex_wmask(pfx, 16), avx_vpshrdd_imm(ZMM[pfx.evex_vvvvv], evex_bcast_src(512,modrm, src, pfx, 32), imm)),
      _ => raise_UD(),
    }
  },

  // 0F3A C2: VCMPPH (NP,W0) / VCMPSH (F3,W0) [FP16]
  // 0F3A C2: VCMPPH (NP,W0) / VCMPSH (F3,W0) [FP16]
  194 => {
    if pfx.rex_w then raise_UD();
    match mp {
      MP_NONE => {
        // VCMPPH: packed FP16 compare → kmask
        let modrm = fetch(1);
        let k_idx : range(0, 7) = evex_reg_idx(modrm, pfx) % 8;
        let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
        match pfx.evex_ll {
          0 => {
            let src1 : xmmword = read_simd(pfx.evex_vvvvv);
            let src2 = evex_src(128,modrm, src, pfx);
            let pred_byte = fetch(1);
            let pred : range(0, 31) = unsigned(pred_byte[4..0]);
            write_kreg(k_idx, avx_vcmpph_kmask(src1, src2, pred))
          },
          1 => {
            let src1 = read_simd(256, pfx.evex_vvvvv);
            let src2 = evex_src(256,modrm, src, pfx);
            let pred_byte = fetch(1);
            let pred : range(0, 31) = unsigned(pred_byte[4..0]);
            write_kreg(k_idx, avx_vcmpph_kmask(src1, src2, pred))
          },
          2 => {
            let src1 = ZMM[pfx.evex_vvvvv];
            let src2 = evex_src(512,modrm, src, pfx);
            let pred_byte = fetch(1);
            let pred : range(0, 31) = unsigned(pred_byte[4..0]);
            write_kreg(k_idx, avx_vcmpph_kmask(src1, src2, pred))
          },
          3 => raise_UD(),
        }
      },
      MP_F3 => {
        // VCMPSH: scalar FP16 compare → kmask bit 0
        let modrm = fetch(1);
        let k_idx : range(0, 7) = evex_reg_idx(modrm, pfx) % 8;
        let src = modrm_rm_evex(modrm, pfx, 2);
        let src1 : xmmword = read_simd(pfx.evex_vvvvv);
        let src2 = evex_src(128,modrm, src, pfx);
        let pred_byte = fetch(1);
        let pred : range(0, 31) = unsigned(pred_byte[4..0]);
        write_kreg(k_idx, zero_extend(cmp_pred5_f16(src1[15..0], src2[15..0], pred)))
      },
      _ => raise_UD(),
    }
  },

  _ => raise_UD(),
  }
}

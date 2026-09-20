// x86-64 — EVEX Immediate Operations (0F3A map)
//
// Insert/extract, permute-imm, ternlog, round, compare-imm,
// classify, shift-imm, GFNI, and FP16 compare.
// Called from dispatch_evex_0f3a in insn_evex_dispatch.sail.
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

// Polymorphic unsigned integer compare → kmask
val avx_pcmp_u : forall 'vl 'eb, 'vl in {128, 256, 512} & 'eb in {8, 16, 32, 64}.
  (int('eb), bits('vl), bits('vl), range(0, 7)) -> qword
function avx_pcmp_u(eb, a, b, pred) = {
  var r : qword = zeros();
  foreach (i from 0 to ('vl / 'eb - 1)) {
    r[i] = cmp_u_pred(velem('eb, a, i), velem('eb, b, i), pred)
  };
  r
}

// Polymorphic signed integer compare → kmask
val avx_pcmp_s : forall 'vl 'eb, 'vl in {128, 256, 512} & 'eb in {8, 16, 32, 64}.
  (int('eb), bits('vl), bits('vl), range(0, 7)) -> qword
function avx_pcmp_s(eb, a, b, pred) = {
  var r : qword = zeros();
  foreach (i from 0 to ('vl / 'eb - 1)) {
    r[i] = cmp_s_pred(velem('eb, a, i), velem('eb, b, i), pred)
  };
  r
}

// VPTERNLOGD: ternary logic on 3 dword operands using 8-bit truth table
// For each bit position: result = imm8[{a_bit, b_bit, c_bit}]
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

// AVX-512 opmask (k-register) operations

// AVX-512 Mask Register (k*) Instructions
//
// These instructions operate on opmask registers k0-k7.
// Opmask registers are defined in regs.sail as KREG[8].

// KADD -- Add Mask Registers
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
    r[i] = cmp_pred5_f16(velem(16, a, i), velem(16, b, i), pred);
  };
  r
}

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
// VALIGND/Q: concatenate src1(high):src2(low), shift right by imm elements, take low VL bits.
val avx_valign : forall 'vl 'eb, 'vl in {128, 256, 512} & 'eb in {32, 64}.
  (int('eb), bits('vl), bits('vl), byte) -> bits('vl)
function avx_valign(eb, src1, src2, imm) = {
  let n_elems = 'vl / 'eb;
  let shift = unsigned(imm) % n_elems;
  ((src1 @ src2) >> (shift * 'eb))[('vl - 1)..0]
}

/* ---- VPERMILPS (imm8): in-lane dword permute ---- */

val avx_vpermilps_imm_128 : (xmmword, byte) -> xmmword
function avx_vpermilps_imm_128(src, imm) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo = i * 32;
    r[(lo + 31)..lo] = velem(32, src, imm[(i * 2 + 1)..(i * 2)]);
  };
  r
}

val avx_vpermilps_imm : forall 'vl, 'vl in {128, 256, 512}.
  (bits('vl), byte) -> bits('vl)
function avx_vpermilps_imm(src, imm) = {
  var r : bits('vl) = zeros();
  foreach (lane from 0 to ('vl / 128 - 1)) {
    let lo = lane * 128;
    r[(lo + 127)..lo] = avx_vpermilps_imm_128(velem(128, src, lane), imm);
  };
  r
}

/* ---- VPERMILPD (imm8): in-lane qword permute ---- */

val avx_vpermilpd_imm_128 : (xmmword, byte) -> xmmword
function avx_vpermilpd_imm_128(src, imm) =
  velem(64, src, imm[1]) @ velem(64, src, imm[0])

val avx_vpermilpd_imm : forall 'vl, 'vl in {128, 256, 512}.
  (bits('vl), byte) -> bits('vl)
function avx_vpermilpd_imm(src, imm) = {
  var r : bits('vl) = zeros();
  foreach (lane from 0 to ('vl / 128 - 1)) {
    let lo = lane * 128;
    r[(lo + 127)..lo] = avx_vpermilpd_imm_128(velem(128, src, lane), imm >> (lane * 2));
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
    r[(lo + 127)..lo] = avx_palignr_128(velem(128, src1, lane), velem(128, src2, lane), imm);
  };
  r
}

// VSHUFF32X4 / VSHUFI32X4 (256-bit): shuffle 128-bit lanes
// SDM: for 256-bit VSHUFF32X4:
//   dst[127:0] = src1[imm8[0]*128+127 : imm8[0]*128]
//   dst[255:128] = src2[imm8[1]*128+127 : imm8[1]*128]
val avx_shuf_f32x4_256 : (ymmword, ymmword, byte) -> ymmword
function avx_shuf_f32x4_256(src1, src2, imm) = {
  let s0 : range(0, 1) = unsigned(imm[0]);
  let s1 : range(0, 1) = unsigned(imm[1]);
  let lane0 : xmmword = velem(128, src1, s0);
  let lane1 : xmmword = velem(128, src2, s1);
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
  let lane0 = velem(128,src1, s0);
  let lane1 = velem(128,src1, s1);
  let lane2 = velem(128,src2, s2);
  let lane3 = velem(128,src2, s3);
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
    r[(lo + 127)..lo] = avx_vdbpsadbw_128(velem(128, src1, lane), velem(128, src2, lane), imm);
  };
  r
}

val avx_vrndscale : forall 'vl 'eb, 'vl in {128, 256, 512} & 'eb in {16, 32, 64}.
  (int('eb), bits('vl), byte) -> bits('vl)
function avx_vrndscale(eb, src, imm) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 'eb - 1)) {
    let lo = i * 'eb;
    r[(lo + 'eb - 1)..lo] = fp_rndscale(velem('eb, src, i), imm)
  };
  r
}

/* ---- VGETMANT: extract mantissa ---- */

val avx_vgetmant : forall 'vl 'eb, 'vl in {128, 256, 512} & 'eb in {16, 32, 64}.
  (int('eb), bits('vl), byte) -> bits('vl)
function avx_vgetmant(eb, src, imm) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 'eb - 1)) {
    let lo = i * 'eb;
    r[(lo + 'eb - 1)..lo] = fp_getmant(velem('eb, src, i), imm)
  };
  r
}

/* ---- VREDUCE: reduce FP value ---- */

val avx_vreduce : forall 'vl 'eb, 'vl in {128, 256, 512} & 'eb in {16, 32, 64}.
  (int('eb), bits('vl), byte) -> bits('vl)
function avx_vreduce(eb, src, imm) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 'eb - 1)) {
    let lo = i * 'eb;
    r[(lo + 'eb - 1)..lo] = fp_reduce(velem('eb, src, i), imm)
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
      32 => fp_fixupimm(velem(32, dst, i), velem(32, src1, i), velem(32, src2, i), imm),
      64 => fp_fixupimm(velem(64, dst, i), velem(64, src1, i), velem(64, src2, i), imm),
    }
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

// Per-element VRANGE: polymorphic over f32/f64.
// SDM pseudocode: NaN priority, then min/max/abs_min/abs_max, then sign control.
val avx_range_elem : forall 'eb, 'eb in {32, 64}. (bits('eb), bits('eb), byte) -> bits('eb)
function avx_range_elem(src1, src2, imm) = {
  let op : range(0, 3) = unsigned(imm[1..0]);
  let sign_ctl : range(0, 3) = unsigned(imm[3..2]);
  let src1_is_nan : bool = fp_compare(src1, src1) == FP_UNORDERED;
  let src2_is_nan : bool = fp_compare(src2, src2) == FP_UNORDERED;
  // Phase 1: select operand (NaN priority, then comparison)
  let abs1 : bits('eb) = 0b0 @ src1[('eb - 2)..0];
  let abs2 : bits('eb) = 0b0 @ src2[('eb - 2)..0];
  let tmp : bits('eb) =
    if src2_is_nan then src1
    else if src1_is_nan then src2
    else match op {
      0 => if fp_compare(src1, src2) != FP_GT then src1 else src2,
      1 => if fp_compare(src1, src2) != FP_GT then src2 else src1,
      2 => if fp_compare(abs1, abs2) != FP_GT then src1 else src2,
      3 => if fp_compare(abs1, abs2) != FP_GT then src2 else src1,
    };
  // Phase 2: sign control
  match sign_ctl {
    0 => src1[('eb - 1)] @ tmp[('eb - 2)..0],
    1 => tmp,
    2 => 0b0 @ tmp[('eb - 2)..0],
    3 => 0b1 @ tmp[('eb - 2)..0],
  }
}

val avx_vrange : forall 'vl 'eb, 'vl in {128, 256, 512} & 'eb in {32, 64}.
  (int('eb), bits('vl), bits('vl), byte) -> bits('vl)
function avx_vrange(eb, src1, src2, imm) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 'eb - 1)) {
    let lo = i * 'eb;
    r[(lo + 'eb - 1)..lo] = avx_range_elem(velem('eb, src1, i), velem('eb, src2, i), imm)
  };
  r
}

/* ---- VPCLMULQDQ: carry-less multiply per 128-bit lane ---- */

val avx_vpclmulqdq : forall 'vl, 'vl in {128, 256, 512}.
  (bits('vl), bits('vl), byte) -> bits('vl)
function avx_vpclmulqdq(src1, src2, imm8) = {
  var r : bits('vl) = zeros();
  foreach (lane from 0 to ('vl / 128 - 1)) {
    let lo = lane * 128;
    r[(lo + 127)..lo] = pclmulqdq_lane(velem(128, src1, lane), velem(128, src2, lane), imm8);
  };
  r
}

/* ---- VPSHLD/VPSHRD: packed shift double (VBMI2) ---- */

// VPSHLD/VPSHRD imm use packed_funnel_shl_imm / packed_funnel_shr_imm.


val dispatch_evex_imm : (range(0, 255), Prefixes) -> unit
function dispatch_evex_imm(op, pfx) = {
  let mp = get_mandatory_prefix(pfx);

  match op {
  // 0F3A 00: VPERMQ / 0F3A 01: VPERMPD (66, W=1) — identical qword permute
  op if op == 0 | op == 1 => {
    if mp != MP_66 | ~(pfx.vex_w) then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));

    let imm = fetch(1);
    match pfx.evex_ll {
      1 => evex_write(dst, evex_wmask(pfx, 4), avx_vpermq_imm_256(evex_bcast_src(256, src, pfx, 64), imm)),
      2 => evex_write(dst, evex_wmask(pfx, 8), avx_vpermq_imm_512(evex_bcast_src(512, src, pfx, 64), imm)),
      _ => raise_UD(),
    }
  },

  // 0F3A 03: VALIGND (66, W=0) / VALIGNQ (66, W=1)
  3 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let imm = fetch(1);
    let eb = evex_elem(pfx);
    let vl = evex_vl(pfx);
    evex_write(dst, evex_wmask(pfx, vl / eb),
               avx_valign(eb, read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(vl, src, pfx, eb), imm))
  },

  // 0F3A 04: VPERMILPS (66, W=0) — imm8-controlled in-lane dword permute
  4 => {
    if mp != MP_66 | pfx.vex_w then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));

    let imm = fetch(1);
    let vl = evex_vl(pfx);
    evex_write(dst, evex_wmask(pfx, vl / 32), avx_vpermilps_imm(evex_bcast_src(vl, src, pfx, 32), imm))
  },

  // 0F3A 05: VPERMILPD (66, W=1) — imm8-controlled in-lane qword permute
  5 => {
    if mp != MP_66 | ~(pfx.vex_w) then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));

    let imm = fetch(1);
    let vl = evex_vl(pfx);
    evex_write(dst, evex_wmask(pfx, vl / 64), avx_vpermilpd_imm(evex_bcast_src(vl, src, pfx, 64), imm))
  },

  // 0F3A 0F: VPALIGNR (66) — byte-align concatenation per 128-bit lane
  15 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let imm = fetch(1);
    let vl = evex_vl(pfx);
    evex_write(dst, evex_wmask(pfx, vl / 8), avx_palignr(read_simd(vl, pfx.evex_vvvvv), evex_src(vl, src), imm))
  },

  // 0F3A 14: VPEXTRB (66) — extract byte from XMM to GPR/mem
  20 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let src = evex_reg_idx(modrm, pfx);
    let dest = modrm_rm_evex(modrm, pfx, 1);
    let imm = fetch(1);
    let sel : range(0, 15) = unsigned(imm[3..0]);
    let src_xmm : xmmword = read_simd(src);
    let extracted_byte : byte = velem(8, src_xmm, sel);
    match dest {
      RM_reg(r) => v(r) = zero_extend(32, extracted_byte),
      RM_mem(m) => v(m) = extracted_byte,
    }
  },

  // 0F3A 15: VPEXTRW (66) — extract word from XMM to GPR/mem
  21 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let src = evex_reg_idx(modrm, pfx);
    let dest = modrm_rm_evex(modrm, pfx, 2);
    let imm = fetch(1);
    let sel : range(0, 7) = unsigned(imm[2..0]);
    let src_xmm : xmmword = read_simd(src);
    let extracted_word : word = velem(16, src_xmm, sel);
    match dest {
      RM_reg(r) => v(r) = zero_extend(32, extracted_word),
      RM_mem(m) => v(m) = extracted_word,
    }
  },

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
      let extracted : qword = velem(64, src_xmm, sel);
      match dest {
        RM_reg(r) => v(r) = extracted,
        RM_mem(m) => v(m) = extracted,
      }
    } else {
      // VPEXTRD: imm8[1:0] selects dword
      let dest = modrm_rm_evex(modrm, pfx, 4);
      let imm = fetch(1);
      let sel : range(0, 3) = unsigned(imm[1..0]);
      let extracted : dword = velem(32, src_xmm, sel);
      match dest {
        RM_reg(r) => v(r) = extracted,
        RM_mem(m) => v(m) = extracted,
      }
    }
  },

  // 0F3A 17: VEXTRACTPS (66) — extract single-precision FP from XMM to GPR/mem32
  23 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let src = evex_reg_idx(modrm, pfx);
    let dest = modrm_rm_evex(modrm, pfx, 4);
    let imm = fetch(1);
    let sel : range(0, 3) = unsigned(imm[1..0]);
    let src_xmm : xmmword = read_simd(src);
    let extracted : dword = velem(32, src_xmm, sel);
    match dest {
      RM_reg(r) => v(r) = extracted,
      RM_mem(m) => v(m) = extracted,
    }
  },

  // 0F3A 18: VINSERTF32X4 (66, W=0) / VINSERTF64X2 (66, W=1) — insert 128-bit into 256/512
  24 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, 16);
    let src2 : xmmword = evex_src(128, src);
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
  25 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let src = evex_reg_idx(modrm, pfx);
    let dest = modrm_xrm_evex(modrm, pfx, 16);
    let imm = fetch(1);
    match pfx.evex_ll {
      1 => {
        let src_ymm = read_simd(256, src);
        let extracted : xmmword = (src_ymm >> (unsigned(zero_extend(imm[0]) : bits(1)) * 128))[127..0];
        match dest {
          XRM_reg(xi) => {
            if pfx.vex_w then evex_write(xi, evex_wmask(pfx, 2), extracted)
            else evex_write(xi, evex_wmask(pfx, 4), extracted)
          },
          XRM_mem(m) => {
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
          XRM_reg(xi) => {
            if pfx.vex_w then evex_write(xi, evex_wmask(pfx, 2), extracted)
            else evex_write(xi, evex_wmask(pfx, 4), extracted)
          },
          XRM_mem(m) => {
            let elem : {4, 8} = if pfx.vex_w then 8 else 4;
            evex_masked_mem_store(m, zero_extend(extracted), evex_kmask64(pfx), 16, elem)
          },
        }
      },
      _ => raise_UD(),
    }
  },

  // 0F3A 1A: VINSERTF32X8 (66, W=0) / VINSERTF64X4 (66, W=1) — insert 256-bit into 512
  26 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, 32);
    let src2 : ymmword = evex_src(256, src);
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
  27 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let src = evex_reg_idx(modrm, pfx);
    let dest = modrm_xrm_evex(modrm, pfx, 32);
    let imm = fetch(1);
    match pfx.evex_ll {
      2 => {
        let src_zmm = ZMM[src];
        let extracted : ymmword = (src_zmm >> (unsigned(zero_extend(imm[0]) : bits(1)) * 256))[255..0];
        match dest {
          XRM_reg(xi) => {
            if pfx.vex_w then evex_write(xi, evex_wmask(pfx, 4), extracted)
            else evex_write(xi, evex_wmask(pfx, 8), extracted)
          },
          XRM_mem(m) => {
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
        let dest = modrm_xrm_evex(modrm, pfx, 8);
        let imm = fetch(1);
        let rc : bits(2) = if imm[2] == 0b0 then imm[1..0] else __stmxcsr()[14..13];
        let res = avx_vcvtps2ph(read_simd(128, src), rc);
        match dest {
          XRM_reg(xi) => write_simd(128, xi, zero_extend(res)),
          XRM_mem(m) => evex_masked_mem_store(m, zero_extend(res), evex_kmask64(pfx), 8, 2)
        }
      },
      1 => {
        let dest = modrm_xrm_evex(modrm, pfx, 16);
        let imm = fetch(1);
        let rc : bits(2) = if imm[2] == 0b0 then imm[1..0] else __stmxcsr()[14..13];
        let res = avx_vcvtps2ph(read_simd(256, src), rc);
        match dest {
          XRM_reg(xi) => write_simd(128, xi, res),
          XRM_mem(m) => evex_masked_mem_store(m, zero_extend(res), evex_kmask64(pfx), 16, 2)
        }
      },
      2 => {
        let dest = modrm_xrm_evex(modrm, pfx, 32);
        let imm = fetch(1);
        let rc : bits(2) = if imm[2] == 0b0 then imm[1..0] else __stmxcsr()[14..13];
        let res = avx_vcvtps2ph(ZMM[src], rc);
        match dest {
          XRM_reg(xi) => write_simd(256, xi, res),
          XRM_mem(m) => evex_masked_mem_store(m, zero_extend(res), evex_kmask64(pfx), 32, 2)
        }
      },
      3 => raise_UD(),
    }
  },

  // 0F3A 1E: VPCMPUD (66, W=0) / VPCMPUQ (66, W=1) — unsigned dword/qword compare → kmask
  30 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst_k : range(0, 7) = unsigned(modrm[5..3]);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let imm = fetch(1);
    let pred : range(0, 7) = unsigned(imm[2..0]);
    let eb = evex_elem(pfx);
    let vl = evex_vl(pfx);
    write_kreg(dst_k, avx_pcmp_u(eb, read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(vl, src, pfx, eb), pred) & evex_kmask64(pfx))
  },

  // 0F3A 1F: VPCMPD (66, W=0) / VPCMPQ (66, W=1) — signed dword/qword compare → kmask
  31 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst_k : range(0, 7) = unsigned(modrm[5..3]);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let imm = fetch(1);
    let pred : range(0, 7) = unsigned(imm[2..0]);
    let eb = evex_elem(pfx);
    let vl = evex_vl(pfx);
    write_kreg(dst_k, avx_pcmp_s(eb, read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(vl, src, pfx, eb), pred) & evex_kmask64(pfx))
  },

  // 0F3A 25: VPTERNLOGD (66, W=0) / VPTERNLOGQ (66, W=1)
  37 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));

    let imm = fetch(1);
    match (pfx.rex_w, pfx.evex_ll) {
      // VPTERNLOGQ (m64bcst, W=1)
      (true, 0) => {
        let a : xmmword = read_simd(dst);
        let b : xmmword = read_simd(pfx.evex_vvvvv);
        let c = evex_bcast_src(128, src, pfx, 64);
        evex_write(dst, evex_wmask(pfx, 2), vpternlog(a, b, c, imm))
      },
      (true, 1) => {
        let a = read_simd(256, dst);
        let b = read_simd(256, pfx.evex_vvvvv);
        let c = evex_bcast_src(256, src, pfx, 64);
        evex_write(dst, evex_wmask(pfx, 4), vpternlog(a, b, c, imm))
      },
      (true, 2) => {
        let a = ZMM[dst];
        let b = ZMM[pfx.evex_vvvvv];
        let c = evex_bcast_src(512, src, pfx, 64);
        evex_write(dst, evex_wmask(pfx, 8), vpternlog(a, b, c, imm))
      },
      // VPTERNLOGD (m32bcst, W=0)
      (false, 0) => {
        let a : xmmword = read_simd(dst);
        let b : xmmword = read_simd(pfx.evex_vvvvv);
        let c = evex_bcast_src(128, src, pfx, 32);
        evex_write(dst, evex_wmask(pfx, 4), vpternlog(a, b, c, imm))
      },
      (false, 1) => {
        let a = read_simd(256, dst);
        let b = read_simd(256, pfx.evex_vvvvv);
        let c = evex_bcast_src(256, src, pfx, 32);
        evex_write(dst, evex_wmask(pfx, 8), vpternlog(a, b, c, imm))
      },
      (false, 2) => {
        let a = ZMM[dst];
        let b = ZMM[pfx.evex_vvvvv];
        let c = evex_bcast_src(512, src, pfx, 32);
        evex_write(dst, evex_wmask(pfx, 16), vpternlog(a, b, c, imm))
      },
      _ => raise_UD(),
    }
  },

  // 0F3A 20: VPINSRB (66) — insert byte from GPR/mem into XMM
  32 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, 1);
    let byte_val : byte = match src {
      RM_reg(r) => v(32, r)[7..0],
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
  33 => {
    if mp != MP_66 | pfx.vex_w then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, 4);
    let imm = fetch(1);
    // For register source: imm8[7:6] selects which float from src
    // For memory source: always reads a single 32-bit float
    let src_float : dword = match src {
      XRM_reg(xi) => {
        let src_xmm : xmmword = read_simd(xi);
        let count_s : range(0, 3) = unsigned(imm[7..6]);
        let slo : range(0, 96) = count_s * 32;
        src_xmm[(slo + 31)..slo]
      },
      XRM_mem(m) => v(m),
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
  56 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, 16);
    let src2 : xmmword = evex_src(128, src);
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
  57 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let src = evex_reg_idx(modrm, pfx);
    let dest = modrm_xrm_evex(modrm, pfx, 16);
    let imm = fetch(1);
    match pfx.evex_ll {
      1 => {
        let src_ymm = read_simd(256, src);
        let extracted : xmmword = (src_ymm >> (unsigned(zero_extend(imm[0]) : bits(1)) * 128))[127..0];
        match dest {
          XRM_reg(xi) => {
            if pfx.vex_w then evex_write(xi, evex_wmask(pfx, 2), extracted)
            else evex_write(xi, evex_wmask(pfx, 4), extracted)
          },
          XRM_mem(m) => {
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
          XRM_reg(xi) => {
            if pfx.vex_w then evex_write(xi, evex_wmask(pfx, 2), extracted)
            else evex_write(xi, evex_wmask(pfx, 4), extracted)
          },
          XRM_mem(m) => {
            let elem : {4, 8} = if pfx.vex_w then 8 else 4;
            evex_masked_mem_store(m, zero_extend(extracted), evex_kmask64(pfx), 16, elem)
          },
        }
      },
      _ => raise_UD(),
    }
  },

  // 0F3A 3A: VINSERTI32X8 (66, W=0) / VINSERTI64X4 (66, W=1) — insert 256-bit into 512
  58 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, 32);
    let src2 : ymmword = evex_src(256, src);
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
  59 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let src = evex_reg_idx(modrm, pfx);
    let dest = modrm_xrm_evex(modrm, pfx, 32);
    let imm = fetch(1);
    match pfx.evex_ll {
      2 => {
        let src_zmm = ZMM[src];
        let extracted : ymmword = (src_zmm >> (unsigned(zero_extend(imm[0]) : bits(1)) * 256))[255..0];
        match dest {
          XRM_reg(xi) => {
            if pfx.vex_w then evex_write(xi, evex_wmask(pfx, 4), extracted)
            else evex_write(xi, evex_wmask(pfx, 8), extracted)
          },
          XRM_mem(m) => {
            let elem : {4, 8} = if pfx.vex_w then 8 else 4;
            evex_masked_mem_store(m, zero_extend(extracted), evex_kmask64(pfx), 32, elem)
          },
        }
      },
      _ => raise_UD(),
    }
  },

  // 0F3A 3E: VPCMPUB (66, W=0) / VPCMPUW (66, W=1) — unsigned byte/word compare → kmask
  62 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst_k : range(0, 7) = unsigned(modrm[5..3]);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let imm = fetch(1);
    let pred : range(0, 7) = unsigned(imm[2..0]);
    let eb = evex_elem_bw(pfx);
    let vl = evex_vl(pfx);
    write_kreg(dst_k, avx_pcmp_u(eb, read_simd(vl, pfx.evex_vvvvv), evex_src(vl, src), pred) & evex_kmask64(pfx))
  },

  // 0F3A 3F: VPCMPB (66, W=0) / VPCMPW (66, W=1) — signed byte/word compare → kmask
  63 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst_k : range(0, 7) = unsigned(modrm[5..3]);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let imm = fetch(1);
    let pred : range(0, 7) = unsigned(imm[2..0]);
    let eb = evex_elem_bw(pfx);
    let vl = evex_vl(pfx);
    write_kreg(dst_k, avx_pcmp_s(eb, read_simd(vl, pfx.evex_vvvvv), evex_src(vl, src), pred) & evex_kmask64(pfx))
  },

  // 0F3A 08: VRNDSCALEPS (66, W=0) / VRNDSCALEPH (NP, W=0)
  8 => {
    if pfx.vex_w then raise_UD();
    match mp {
      MP_66 => {
        let modrm = fetch(1);
        let dst = evex_reg_idx(modrm, pfx);
        let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    
        let imm = fetch(1);
        let vl = evex_vl(pfx);
        evex_write(dst, evex_wmask(pfx, vl / 32), avx_vrndscale(32, evex_bcast_src(vl, src, pfx, 32), imm))
      },
      MP_NONE => {
        // VRNDSCALEPH: packed FP16 round
        let modrm = fetch(1);
        let dst = evex_reg_idx(modrm, pfx);
        let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
        let imm = fetch(1);
        let vl = evex_vl(pfx);
        evex_write(dst, evex_wmask(pfx, vl / 16),
                   avx_vrndscale(16, evex_bcast_src(vl, src, pfx, 16), imm))
      },
      _ => raise_UD(),
    }
  },

  // 0F3A 09: VRNDSCALEPD (66, W=1) — round packed double-precision
  9 => {
    if mp != MP_66 | ~(pfx.vex_w) then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));

    let imm = fetch(1);
    let vl = evex_vl(pfx);
    evex_write(dst, evex_wmask(pfx, vl / 64), avx_vrndscale(64, evex_bcast_src(vl, src, pfx, 64), imm))
  },

  // 0F3A 0A: VRNDSCALESS (66, W=0) / VRNDSCALESH (NP, W=0)
  10 => {
    if pfx.vex_w then raise_UD();
    match mp {
      MP_66 => {
        let modrm = fetch(1);
        let dst = evex_reg_idx(modrm, pfx);
        let src = modrm_xrm_evex(modrm, pfx, 4);
        let imm = fetch(1);
        let src1 : xmmword = read_simd(pfx.evex_vvvvv);
        let src2 = evex_src(128, src);
        let r = fp_rndscale(src2[31..0], imm);
        evex_write_scalar(dst, src1[127..32] @ r, pfx, 32)
      },
      MP_NONE => {
        // VRNDSCALESH: scalar FP16 round
        let modrm = fetch(1);
        let dst = evex_reg_idx(modrm, pfx);
        let src = modrm_xrm_evex(modrm, pfx, 2);
        let imm = fetch(1);
        let src1 : xmmword = read_simd(pfx.evex_vvvvv);
        let src2 = evex_src(128, src);
        let r : word = fp_rndscale(src2[15..0], imm);
        evex_write_scalar(dst, src1[127..16] @ r, pfx, 16)
      },
      _ => raise_UD(),
    }
  },

  // 0F3A 0B: VRNDSCALESD (66, W=1) — round scalar double-precision
  11 => {
    if mp != MP_66 | ~(pfx.vex_w) then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, 8);
    let imm = fetch(1);
    let src1 : xmmword = read_simd(pfx.evex_vvvvv);
    let src2 = evex_src(128, src);
    let r = fp_rndscale(src2[63..0], imm);
    evex_write_scalar(dst, src1[127..64] @ r, pfx, 64)
  },

  // 0F3A 23: VSHUFF32X4 (66, W=0) / VSHUFF64X2 (66, W=1) — shuffle 128-bit lanes (FP)
  35 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));

    let imm = fetch(1);
    match (pfx.vex_w, pfx.evex_ll) {
      (true, 1)  => evex_write(dst, evex_wmask(pfx, 4), avx_shuf_f32x4_256(read_simd(256, pfx.evex_vvvvv), evex_bcast_src(256, src, pfx, 64), imm)),
      (true, 2)  => evex_write(dst, evex_wmask(pfx, 8), avx_shuf_f32x4_512(ZMM[pfx.evex_vvvvv], evex_bcast_src(512, src, pfx, 64), imm)),
      (false, 1) => evex_write(dst, evex_wmask(pfx, 8), avx_shuf_f32x4_256(read_simd(256, pfx.evex_vvvvv), evex_bcast_src(256, src, pfx, 32), imm)),
      (false, 2) => evex_write(dst, evex_wmask(pfx, 16), avx_shuf_f32x4_512(ZMM[pfx.evex_vvvvv], evex_bcast_src(512, src, pfx, 32), imm)),
      (_, _)     => raise_UD(),
    }
  },

  // 0F3A 26: VGETMANTPS (66, W=0) / VGETMANTPD (66, W=1) / VGETMANTPH (NP, W=0)
  38 => {
    match mp {
      MP_66 => {
        let modrm = fetch(1);
        let dst = evex_reg_idx(modrm, pfx);
        let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    
        let imm = fetch(1);
        match (pfx.vex_w, pfx.evex_ll) {
          // VGETMANTPD xmm1/ymm1/zmm1, xmm2/ymm2/zmm2/m128/m256/m512, imm8
          (true, 0) => evex_write(dst, evex_wmask(pfx, 2), avx_vgetmant(64,evex_bcast_src(128, src, pfx, 64), imm)),
          (true, 1)  => evex_write(dst, evex_wmask(pfx, 4), avx_vgetmant(64,evex_bcast_src(256, src, pfx, 64), imm)),
          (true, 2)  => evex_write(dst, evex_wmask(pfx, 8), avx_vgetmant(64,evex_bcast_src(512, src, pfx, 64), imm)),
          // VGETMANTPS xmm1/ymm1/zmm1, xmm2/ymm2/zmm2/m128/m256/m512, imm8
          (false, 0) => evex_write(dst, evex_wmask(pfx, 4), avx_vgetmant(32,evex_bcast_src(128, src, pfx, 32), imm)),
          (false, 1) => evex_write(dst, evex_wmask(pfx, 8), avx_vgetmant(32,evex_bcast_src(256, src, pfx, 32), imm)),
          (false, 2) => evex_write(dst, evex_wmask(pfx, 16), avx_vgetmant(32,evex_bcast_src(512, src, pfx, 32), imm)),
          _ => raise_UD(),
        }
      },
      MP_NONE => {
        // VGETMANTPH: packed FP16 extract mantissa
        if pfx.vex_w then raise_UD();
        let modrm = fetch(1);
        let dst = evex_reg_idx(modrm, pfx);
        let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
        let imm = fetch(1);
        let vl = evex_vl(pfx);
        evex_write(dst, evex_wmask(pfx, vl / 16),
                   avx_vgetmant(16, evex_bcast_src(vl, src, pfx, 16), imm))
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
        let src = modrm_xrm_evex(modrm, pfx, if pfx.vex_w then 8 else 4);
        let imm = fetch(1);
        let src1 : xmmword = read_simd(pfx.evex_vvvvv);
        let src2 = evex_src(128, src);
        if pfx.vex_w
        then evex_write_scalar(dst, src1[127..64] @ fp_getmant(src2[63..0], imm), pfx, 64)
        else evex_write_scalar(dst, src1[127..32] @ fp_getmant(src2[31..0], imm), pfx, 32)
      },
      MP_NONE => {
        // VGETMANTSH: scalar FP16 extract mantissa
        if pfx.vex_w then raise_UD();
        let modrm = fetch(1);
        let dst = evex_reg_idx(modrm, pfx);
        let src = modrm_xrm_evex(modrm, pfx, 2);
        let imm = fetch(1);
        let src1 : xmmword = read_simd(pfx.evex_vvvvv);
        let src2 = evex_src(128, src);
        let r : word = fp_getmant(src2[15..0], imm);
        evex_write_scalar(dst, src1[127..16] @ r, pfx, 16)
      },
      _ => raise_UD(),
    }
  },

  // 0F3A 42: VDBPSADBW (66, W=0) — double block packed sum of absolute differences
  66 => {
    if mp != MP_66 | pfx.vex_w then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let imm = fetch(1);
    let vl = evex_vl(pfx);
    evex_write(dst, evex_wmask(pfx, vl / 16), avx_vdbpsadbw(read_simd(vl, pfx.evex_vvvvv), evex_src(vl, src), imm))
  },

  // 0F3A 43: VSHUFI32X4 (66, W=0) / VSHUFI64X2 (66, W=1) — shuffle 128-bit lanes (integer)
  67 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));

    let imm = fetch(1);
    match (pfx.vex_w, pfx.evex_ll) {
      (true, 1)  => evex_write(dst, evex_wmask(pfx, 4), avx_shuf_f32x4_256(read_simd(256, pfx.evex_vvvvv), evex_bcast_src(256, src, pfx, 64), imm)),
      (true, 2)  => evex_write(dst, evex_wmask(pfx, 8), avx_shuf_f32x4_512(ZMM[pfx.evex_vvvvv], evex_bcast_src(512, src, pfx, 64), imm)),
      (false, 1) => evex_write(dst, evex_wmask(pfx, 8), avx_shuf_f32x4_256(read_simd(256, pfx.evex_vvvvv), evex_bcast_src(256, src, pfx, 32), imm)),
      (false, 2) => evex_write(dst, evex_wmask(pfx, 16), avx_shuf_f32x4_512(ZMM[pfx.evex_vvvvv], evex_bcast_src(512, src, pfx, 32), imm)),
      (_, _)     => raise_UD(),
    }
  },

  // 0F3A 44: VPCLMULQDQ (66) — carry-less multiply per 128-bit lane [VPCLMULQDQ]
  // The instruction has no opmask operand, so EVEX.aaa must be 000b and
  // hence EVEX.z must be 0 (SDM Vol.2A Table 2-42); the result is written
  // unmasked with the upper bits of the register zeroed.
  68 => {
    if mp != MP_66 | ~(has_vpclmulqdq) then raise_UD();
    if pfx.evex_aaa != 0 | pfx.evex_z == bitone then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let imm = fetch(1);
    let vl = evex_vl(pfx);
    write_simd(vl, dst, avx_vpclmulqdq(read_simd(vl, pfx.evex_vvvvv), evex_src(vl, src), imm))
  },

  // 0F3A 50: VRANGEPS (66, W=0) / VRANGEPD (66, W=1) — range restriction packed [DQ]
  80 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));

    let imm = fetch(1);
    match (pfx.vex_w, pfx.evex_ll) {
      (true, 0) => evex_write(dst, evex_wmask(pfx, 2), avx_vrange(64,read_simd(pfx.evex_vvvvv), evex_bcast_src(128, src, pfx, 64), imm)),
      (true, 1)  => evex_write(dst, evex_wmask(pfx, 4), avx_vrange(64,read_simd(256, pfx.evex_vvvvv), evex_bcast_src(256, src, pfx, 64), imm)),
      (true, 2)  => evex_write(dst, evex_wmask(pfx, 8), avx_vrange(64,ZMM[pfx.evex_vvvvv], evex_bcast_src(512, src, pfx, 64), imm)),
      (false, 0) => evex_write(dst, evex_wmask(pfx, 4), avx_vrange(32,read_simd(pfx.evex_vvvvv), evex_bcast_src(128, src, pfx, 32), imm)),
      (false, 1) => evex_write(dst, evex_wmask(pfx, 8), avx_vrange(32,read_simd(256, pfx.evex_vvvvv), evex_bcast_src(256, src, pfx, 32), imm)),
      (false, 2) => evex_write(dst, evex_wmask(pfx, 16), avx_vrange(32,ZMM[pfx.evex_vvvvv], evex_bcast_src(512, src, pfx, 32), imm)),
      _ => raise_UD(),
    }
  },

  // 0F3A 51: VRANGESS (66, W=0) / VRANGESD (66, W=1) — range restriction scalar [DQ]
  81 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, if pfx.vex_w then 8 else 4);
    let imm = fetch(1);
    let src1 : xmmword = read_simd(pfx.evex_vvvvv);
    if pfx.vex_w then {
      let src2 : qword = decode_scalar_src(64, src);
      let r = avx_range_elem(src1[63..0], src2, imm);
      evex_write_scalar(dst, src1[127..64] @ r, pfx, 64)
    } else {
      let src2 : dword = decode_scalar_src(32, src);
      let r = avx_range_elem(src1[31..0], src2, imm);
      evex_write_scalar(dst, src1[127..32] @ r, pfx, 32)
    }
  },

  // 0F3A 54: VFIXUPIMMPS (66, W=0) / VFIXUPIMMPD (66, W=1) — fixup packed
  84 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));

    let imm = fetch(1);
    match (pfx.vex_w, pfx.evex_ll) {
      // VFIXUPIMMPD xmm1/ymm1/zmm1, xmm2/ymm2/zmm2, xmm3/ymm3/zmm3/m128/m256/m512, imm8
      (true, 0) => evex_write(dst, evex_wmask(pfx, 2), avx_vfixupimm(64,read_simd(dst), read_simd(pfx.evex_vvvvv), evex_bcast_src(128, src, pfx, 64), imm)),
      (true, 1)  => evex_write(dst, evex_wmask(pfx, 4), avx_vfixupimm(64,read_simd(256, dst), read_simd(256, pfx.evex_vvvvv), evex_bcast_src(256, src, pfx, 64), imm)),
      (true, 2)  => evex_write(dst, evex_wmask(pfx, 8), avx_vfixupimm(64,ZMM[dst], ZMM[pfx.evex_vvvvv], evex_bcast_src(512, src, pfx, 64), imm)),
      // VFIXUPIMMPS xmm1/ymm1/zmm1, xmm2/ymm2/zmm2, xmm3/ymm3/zmm3/m128/m256/m512, imm8
      (false, 0) => evex_write(dst, evex_wmask(pfx, 4), avx_vfixupimm(32,read_simd(dst), read_simd(pfx.evex_vvvvv), evex_bcast_src(128, src, pfx, 32), imm)),
      (false, 1) => evex_write(dst, evex_wmask(pfx, 8), avx_vfixupimm(32,read_simd(256, dst), read_simd(256, pfx.evex_vvvvv), evex_bcast_src(256, src, pfx, 32), imm)),
      (false, 2) => evex_write(dst, evex_wmask(pfx, 16), avx_vfixupimm(32,ZMM[dst], ZMM[pfx.evex_vvvvv], evex_bcast_src(512, src, pfx, 32), imm)),
      _ => raise_UD(),
    }
  },

  // 0F3A 55: VFIXUPIMMSS (66, W=0) / VFIXUPIMMSD (66, W=1) — fixup scalar
  85 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, if pfx.vex_w then 8 else 4);
    let imm = fetch(1);
    let src1 : xmmword = read_simd(pfx.evex_vvvvv);
    let src2 = evex_src(128, src);
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
        let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    
        let imm = fetch(1);
        match (pfx.vex_w, pfx.evex_ll) {
          // VREDUCEPD xmm1/ymm1/zmm1, xmm2/ymm2/zmm2/m128/m256/m512, imm8
          (true, 0) => evex_write(dst, evex_wmask(pfx, 2), avx_vreduce(64,evex_bcast_src(128, src, pfx, 64), imm)),
          (true, 1)  => evex_write(dst, evex_wmask(pfx, 4), avx_vreduce(64,evex_bcast_src(256, src, pfx, 64), imm)),
          (true, 2)  => evex_write(dst, evex_wmask(pfx, 8), avx_vreduce(64,evex_bcast_src(512, src, pfx, 64), imm)),
          // VREDUCEPS xmm1/ymm1/zmm1, xmm2/ymm2/zmm2/m128/m256/m512, imm8
          (false, 0) => evex_write(dst, evex_wmask(pfx, 4), avx_vreduce(32,evex_bcast_src(128, src, pfx, 32), imm)),
          (false, 1) => evex_write(dst, evex_wmask(pfx, 8), avx_vreduce(32,evex_bcast_src(256, src, pfx, 32), imm)),
          (false, 2) => evex_write(dst, evex_wmask(pfx, 16), avx_vreduce(32,evex_bcast_src(512, src, pfx, 32), imm)),
          _ => raise_UD(),
        }
      },
      MP_NONE => {
        // VREDUCEPH: packed FP16 reduce
        if pfx.vex_w then raise_UD();
        let modrm = fetch(1);
        let dst = evex_reg_idx(modrm, pfx);
        let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
        let imm = fetch(1);
        let vl = evex_vl(pfx);
        evex_write(dst, evex_wmask(pfx, vl / 16),
                   avx_vreduce(16, evex_bcast_src(vl, src, pfx, 16), imm))
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
        let src = modrm_xrm_evex(modrm, pfx, if pfx.vex_w then 8 else 4);
        let imm = fetch(1);
        let src1 : xmmword = read_simd(pfx.evex_vvvvv);
        let src2 = evex_src(128, src);
        if pfx.vex_w
        then evex_write_scalar(dst, src1[127..64] @ fp_reduce(src2[63..0], imm), pfx, 64)
        else evex_write_scalar(dst, src1[127..32] @ fp_reduce(src2[31..0], imm), pfx, 32)
      },
      MP_NONE => {
        // VREDUCESH: scalar FP16 reduce
        if pfx.vex_w then raise_UD();
        let modrm = fetch(1);
        let dst = evex_reg_idx(modrm, pfx);
        let src = modrm_xrm_evex(modrm, pfx, 2);
        let imm = fetch(1);
        let src1 : xmmword = read_simd(pfx.evex_vvvvv);
        let src2 = evex_src(128, src);
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
        let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
        let imm = fetch(1);
        let eb = evex_elem(pfx);
        let vl = evex_vl(pfx);
        write_kreg(dst_k, packed_fpclass(eb, evex_bcast_src(vl, src, pfx, eb), imm) & evex_kmask64(pfx))
      },
      MP_NONE => {
        // VFPCLASSPH: classify packed FP16 → kmask
        if pfx.vex_w then raise_UD();
        let modrm = fetch(1);
        let dst_k : range(0, 7) = unsigned(modrm[5..3]);
        let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
        let imm = fetch(1);
        let vl = evex_vl(pfx);
        write_kreg(dst_k, packed_fpclass(16, evex_bcast_src(vl, src, pfx, 16), imm) & evex_kmask64(pfx))
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
        let src = modrm_xrm_evex(modrm, pfx, if pfx.vex_w then 8 else 4);
        let imm = fetch(1);
        let src = evex_src(128, src);
        let result : bit = if pfx.vex_w then fpclass_elem(src[63..0], imm)
                            else fpclass_elem(src[31..0], imm);
        let k_val : qword = zero_extend(result);
        let k_mask : qword = k_val & evex_kmask64(pfx);
        write_kreg(dst_k, k_mask)
      },
      MP_NONE => {
        // VFPCLASSSH: classify scalar FP16 → kmask
        if pfx.vex_w then raise_UD();
        let modrm = fetch(1);
        let dst_k : range(0, 7) = unsigned(modrm[5..3]);
        let src = modrm_xrm_evex(modrm, pfx, 2);
        let imm = fetch(1);
        let src = evex_src(128, src);
        let result : bit = fpclass_elem(src[15..0], imm);
        let k_val : qword = zero_extend(result);
        let k_mask : qword = k_val & evex_kmask64(pfx);
        write_kreg(dst_k, k_mask)
      },
      _ => raise_UD(),
    }
  },

  // 0F3A CE: VGF2P8AFFINEQB (66,W1) [GFNI]
  206 => {
    if mp != MP_66 | ~(pfx.rex_w) then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));

    let imm = fetch(1);
    let vl = evex_vl(pfx);
    evex_write(dst, evex_wmask(pfx, vl / 8), avx_gf2p8affineqb(read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(vl, src, pfx, 64), imm))
  },

  // 0F3A CF: VGF2P8AFFINEINVQB (66,W1) [GFNI]
  207 => {
    if mp != MP_66 | ~(pfx.rex_w) then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));

    let imm = fetch(1);
    let vl = evex_vl(pfx);
    evex_write(dst, evex_wmask(pfx, vl / 8), avx_gf2p8affineinvqb(read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(vl, src, pfx, 64), imm))
  },

  // 0F3A 70: VPSHLDW (66, W=1) [VBMI2]
  112 => {
    if mp != MP_66 | ~(pfx.rex_w) then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let imm = fetch(1);
    let vl = evex_vl(pfx);
    evex_write(dst, evex_wmask(pfx, vl / 16), packed_funnel_shl_imm(16, read_simd(vl, pfx.evex_vvvvv), evex_src(vl, src), unsigned(imm)))
  },

  // 0F3A 71: VPSHLDD (66, W=0) / VPSHLDQ (66, W=1) [VBMI2]
  113 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));

    let imm = fetch(1);
    let vl = evex_vl(pfx);
    let eb : {32, 64} = evex_elem(pfx);
    if pfx.rex_w then
      evex_write(dst, evex_wmask(pfx, vl / 64), packed_funnel_shl_imm(64, read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(vl, src, pfx, 64), unsigned(imm)))
    else
      evex_write(dst, evex_wmask(pfx, vl / 32), packed_funnel_shl_imm(32, read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(vl, src, pfx, 32), unsigned(imm)))
  },

  // 0F3A 72: VPSHRDW (66, W=1) [VBMI2]
  114 => {
    if mp != MP_66 | ~(pfx.rex_w) then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let imm = fetch(1);
    let vl = evex_vl(pfx);
    evex_write(dst, evex_wmask(pfx, vl / 16), packed_funnel_shr_imm(16, read_simd(vl, pfx.evex_vvvvv), evex_src(vl, src), unsigned(imm)))
  },

  // 0F3A 73: VPSHRDD (66, W=0) / VPSHRDQ (66, W=1) [VBMI2]
  115 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));

    let imm = fetch(1);
    let vl = evex_vl(pfx);
    if pfx.rex_w then
      evex_write(dst, evex_wmask(pfx, vl / 64), packed_funnel_shr_imm(64, read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(vl, src, pfx, 64), unsigned(imm)))
    else
      evex_write(dst, evex_wmask(pfx, vl / 32), packed_funnel_shr_imm(32, read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(vl, src, pfx, 32), unsigned(imm)))
  },

  // 0F3A C2: VCMPPH (NP,W0) / VCMPSH (F3,W0) [FP16]
  194 => {
    if pfx.rex_w then raise_UD();
    match mp {
      MP_NONE => {
        // VCMPPH: packed FP16 compare → kmask
        let modrm = fetch(1);
        let k_idx : range(0, 7) = evex_reg_idx(modrm, pfx) % 8;
        let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
        match pfx.evex_ll {
          0 => {
            let src1 : xmmword = read_simd(pfx.evex_vvvvv);
            let src2 = evex_src(128, src);
            let pred_byte = fetch(1);
            let pred : range(0, 31) = unsigned(pred_byte[4..0]);
            write_kreg(k_idx, avx_vcmpph_kmask(src1, src2, pred))
          },
          1 => {
            let src1 = read_simd(256, pfx.evex_vvvvv);
            let src2 = evex_src(256, src);
            let pred_byte = fetch(1);
            let pred : range(0, 31) = unsigned(pred_byte[4..0]);
            write_kreg(k_idx, avx_vcmpph_kmask(src1, src2, pred))
          },
          2 => {
            let src1 = ZMM[pfx.evex_vvvvv];
            let src2 = evex_src(512, src);
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
        let src = modrm_xrm_evex(modrm, pfx, 2);
        let src1 : xmmword = read_simd(pfx.evex_vvvvv);
        let src2 = evex_src(128, src);
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

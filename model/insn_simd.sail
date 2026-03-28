// x86-64 — Shared SIMD Helpers
//
// Generic packed element-wise operations and vector-width helper functions
// shared across legacy SSE, VEX, and EVEX instruction files.

// =========================================================================
// Generic packed element-wise operations
// =========================================================================

// Generic packed unary operation (element-wise, one source).
enum PackedUnaryOp = {
  PU_Abs, PU_Popcnt, PU_Lzcnt, PU_FSqrt,
  PU_FPGetexp, PU_FPRcp14, PU_FPRsqrt14, PU_FPRcp28, PU_FPRsqrt28, PU_FPExp2
}

val packed_unary_elem : forall 'eb, 'eb in {8, 16, 32, 64}.
  (PackedUnaryOp, bits('eb)) -> bits('eb)
function packed_unary_elem(op, a) = match op {
  PU_Abs       => abs(a),
  PU_Popcnt    => to_bits(popcount(a)),
  PU_Lzcnt     => to_bits(clz(a)),
  PU_FSqrt     => fp_sqrt(a),
  PU_FPGetexp  => fp_getexp(a),
  PU_FPRcp14   => fp_rcp14(a),
  PU_FPRsqrt14 => fp_rsqrt14(a),
  PU_FPRcp28   => fp_rcp28(a),
  PU_FPRsqrt28 => fp_rsqrt28(a),
  PU_FPExp2    => fp_exp2(a),
}

val packed_unop : forall 'vl 'eb, 'vl in {128, 256, 512} & 'eb in {8, 16, 32, 64}.
  (PackedUnaryOp, int('eb), bits('vl)) -> bits('vl)
function packed_unop(op, eb, a) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 'eb - 1)) {
    let hi = (i + 1) * 'eb - 1;
    let lo = i * 'eb;
    r[hi..lo] = packed_unary_elem(op, a[hi..lo])
  };
  r
}

// Generic packed binary operation (element-wise, two sources).
enum PackedBinOp = {
  PB_Add, PB_Sub,
  PB_SatAddS, PB_SatSubS, PB_SatAddU, PB_SatSubU,
  PB_MinU, PB_MaxU, PB_MinS, PB_MaxS,
  PB_Avg,
  PB_Srl, PB_Sra, PB_Sll,
  PB_MulLow, PB_MulHighS, PB_MulHighU, PB_MulHRS,
  PB_Ror, PB_Rol,
  PB_CmpEq, PB_CmpGt,
  PB_PSign,
  PB_FAdd, PB_FSub, PB_FMul, PB_FDiv, PB_FMin, PB_FMax,
  PB_FPScalef,
  PB_Psadbw, PB_Pmaddubsw, PB_Pmaddwd, PB_Pmuludq, PB_Pshufb,
  PB_HorizAddW, PB_HorizAddD, PB_HorizSatAddW,
  PB_HorizSubW, PB_HorizSubD, PB_HorizSatSubW,
}

// Forward declaration — defined after packed_elem_op.
val packed_horiz : forall 'ew, 'ew in {16, 32}.
  (PackedBinOp, int('ew), bits(128), bits(128)) -> bits(128)

// Per-element dispatch: applies the operation to one pair of elements.
// Most ops work at eb in {8,16,32,64}; lane ops (PB_Pshufb etc.) work at eb=128.
val packed_elem_op : forall 'eb, 'eb in {8, 16, 32, 64, 128}.
  (PackedBinOp, bits('eb), bits('eb)) -> bits('eb)
function packed_elem_op(op, a, b) = match op {
  PB_Add      => a + b,
  PB_Sub      => a - b,
  PB_SatAddS  => { assert('eb <= 64); sat_add_s(a, b) },
  PB_SatSubS  => { assert('eb <= 64); sat_sub_s(a, b) },
  PB_SatAddU  => { assert('eb <= 64); sat_add_u(a, b) },
  PB_SatSubU  => { assert('eb <= 64); sat_sub_u(a, b) },
  PB_MinU     => { assert('eb <= 64); min_u(a, b) },
  PB_MaxU     => { assert('eb <= 64); max_u(a, b) },
  PB_MinS     => { assert('eb <= 64); min_s(a, b) },
  PB_MaxS     => { assert('eb <= 64); max_s(a, b) },
  PB_Avg      => { assert('eb <= 64); avg(a, b) },
  PB_Srl      => a >> b,
  PB_Sra      => a >>> unsigned(b),
  PB_Sll      => a << b,
  PB_MulLow   => to_bits_truncate(signed(a) * signed(b)),
  PB_MulHighS => get_slice_int('eb, signed(a) * signed(b), 'eb),
  PB_MulHighU => get_slice_int('eb, unsigned(a) * unsigned(b), 'eb),
  PB_MulHRS   => { assert('eb <= 64); mulhrs(a, b) },
  PB_Ror      => { assert('eb <= 64); rotr(a, unsigned(b) % 'eb) },
  PB_Rol      => { assert('eb <= 64); rotl(a, unsigned(b) % 'eb) },
  PB_CmpEq    => { assert('eb <= 64); cmp_eq(a, b) },
  PB_CmpGt    => { assert('eb <= 64); cmp_gt(a, b) },
  PB_PSign    => { assert('eb <= 64); psign(a, b) },
  PB_FAdd     => { assert('eb <= 64); fp_add(a, b) },
  PB_FSub     => { assert('eb <= 64); fp_sub(a, b) },
  PB_FMul     => { assert('eb <= 64); fp_mul(a, b) },
  PB_FDiv     => { assert('eb <= 64); fp_div(a, b) },
  PB_FMin     => { assert('eb <= 64); fp_min(a, b) },
  PB_FMax     => { assert('eb <= 64); fp_max(a, b) },
  PB_FPScalef => { assert('eb <= 64); fp_scalef(a, b) },

  // Ops with internal sub-element structure
  PB_Pmaddubsw    => { assert('eb == 16);  pmaddubsw_pair(a[7..0], b[7..0], a[15..8], b[15..8]) },
  PB_Pmaddwd      => { assert('eb == 32);  pmaddwd_pair(a[15..0], b[15..0], a[31..16], b[31..16]) },
  PB_Pmuludq      => { assert('eb == 64);  to_bits(64, unsigned(a[31..0]) * unsigned(b[31..0])) },
  PB_Psadbw       => { assert('eb == 64);  psadbw(a, b) },
  PB_Pshufb       => { assert('eb == 128); pshufb(a, b) },
  PB_HorizAddW    => { assert('eb == 128); packed_horiz(PB_Add, 16, a, b) },
  PB_HorizAddD    => { assert('eb == 128); packed_horiz(PB_Add, 32, a, b) },
  PB_HorizSatAddW => { assert('eb == 128); packed_horiz(PB_SatAddS, 16, a, b) },
  PB_HorizSubW    => { assert('eb == 128); packed_horiz(PB_Sub, 16, a, b) },
  PB_HorizSubD    => { assert('eb == 128); packed_horiz(PB_Sub, 32, a, b) },
  PB_HorizSatSubW => { assert('eb == 128); packed_horiz(PB_SatSubS, 16, a, b) },
}

// Horizontal binary op within a 128-bit lane.
function packed_horiz(op, ew, a, b) = {
  var r : bits(128) = zeros();
  foreach (i from 0 to (64 / ew - 1)) {
    let src = i * 2 * ew;
    let a_dst = i * ew;
    let b_dst = a_dst + 64;
    r[(a_dst + ew - 1)..a_dst] = packed_elem_op(op, a[(src + ew - 1)..src], a[(src + 2 * ew - 1)..(src + ew)]);
    r[(b_dst + ew - 1)..b_dst] = packed_elem_op(op, b[(src + ew - 1)..src], b[(src + 2 * ew - 1)..(src + ew)]);
  };
  r
}

// Apply a packed binary operation element-wise across a vector.
val packed_binop : forall 'vl 'eb, 'vl in {128, 256, 512} & 'eb in {8, 16, 32, 64, 128}.
  (PackedBinOp, int('eb), bits('vl), bits('vl)) -> bits('vl)
function packed_binop(op, eb, a, b) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 'eb - 1)) {
    let hi = (i + 1) * 'eb - 1;
    let lo = i * 'eb;
    r[hi..lo] = packed_elem_op(op, a[hi..lo], b[hi..lo])
  };
  r
}

// Per-lane unary-with-immediate operations (PSHUFD, PSHUFHW, PSHUFLW).
enum PackedLaneImmOp = { PLI_Pshufd, PLI_Pshufhw, PLI_Pshuflw }

val packed_lane_imm_elem : (PackedLaneImmOp, bits(128), byte) -> bits(128)
function packed_lane_imm_elem(op, src, imm) = match op {
  PLI_Pshufd => {
    var r : bits(128) = zeros();
    foreach (i from 0 to 3) {
      let sel : range(0, 3) = unsigned(imm[(i * 2 + 1)..(i * 2)]);
      let dst_lo = i * 32;
      let src_lo = sel * 32;
      r[(dst_lo + 31)..dst_lo] = src[(src_lo + 31)..src_lo]
    };
    r
  },
  PLI_Pshufhw => {
    var r : bits(128) = zeros();
    r[63..0] = src[63..0];
    foreach (i from 0 to 3) {
      let sel : range(0, 3) = unsigned(imm[(i * 2 + 1)..(i * 2)]);
      let dst_lo = i * 16 + 64;
      let src_lo = sel * 16 + 64;
      r[(dst_lo + 15)..dst_lo] = src[(src_lo + 15)..src_lo]
    };
    r
  },
  PLI_Pshuflw => {
    var r : bits(128) = zeros();
    r[127..64] = src[127..64];
    foreach (i from 0 to 3) {
      let sel : range(0, 3) = unsigned(imm[(i * 2 + 1)..(i * 2)]);
      let dst_lo = i * 16;
      let src_lo = sel * 16;
      r[(dst_lo + 15)..dst_lo] = src[(src_lo + 15)..src_lo]
    };
    r
  },
}

val packed_lane_imm_op : forall 'vl, 'vl in {128, 256, 512}.
  (PackedLaneImmOp, bits('vl), byte) -> bits('vl)
function packed_lane_imm_op(op, src, imm) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) {
    let hi = (i + 1) * 128 - 1;
    let lo = i * 128;
    r[hi..lo] = packed_lane_imm_elem(op, src[hi..lo], imm)
  };
  r
}

// Uniform packed shift: apply a scalar shift count to all elements.
enum PackedShiftOp = { PS_Srl, PS_Sra, PS_Sll }

val packed_uniform_shift : forall 'vl 'eb, 'vl in {128, 256, 512} & 'eb in {16, 32, 64}.
  (PackedShiftOp, int('eb), bits('vl), nat) -> bits('vl)
function packed_uniform_shift(op, eb, src, count) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 'eb - 1)) {
    let hi = (i + 1) * 'eb - 1;
    let lo = i * 'eb;
    r[hi..lo] = match op {
      PS_Srl => src[hi..lo] >> count,
      PS_Sra => src[hi..lo] >>> count,
      PS_Sll => src[hi..lo] << count,
    }
  };
  r
}

// Interleave elements from two sources (PUNPCKLBW/WD/DQ/QDQ, PUNPCKHBW/WD/DQ/QDQ).
// Within each 128-bit lane, takes elements from the low (half=0) or high (half=64)
// half of a and b, and interleaves them: r[2i]=a[half+i], r[2i+1]=b[half+i].
val packed_unpack : forall 'vl 'eb, 'vl in {128, 256, 512} & 'eb in {8, 16, 32, 64}.
  (int('eb), {0, 64}, bits('vl), bits('vl)) -> bits('vl)
function packed_unpack(eb, half, a, b) = {
  var r : bits('vl) = zeros();
  let elems_per_half = 64 / eb;
  foreach (j from 0 to ('vl / 128 - 1)) {
    let lbase = j * 128;
    foreach (i from 0 to (elems_per_half - 1)) {
      let src_lo = lbase + half + i * eb;
      let dst_lo = lbase + i * 2 * eb;
      r[(dst_lo + eb - 1)..dst_lo] = a[(src_lo + eb - 1)..src_lo];
      r[(dst_lo + 2 * eb - 1)..(dst_lo + eb)] = b[(src_lo + eb - 1)..src_lo];
    }
  };
  r
}

// Generic packed narrowing unary operation (each element shrinks).
enum PackedNarrowOp = { PN_Trunc, PN_SatU, PN_SatS, PN_SatSU }

val packed_narrow_elem : forall 'src 'dst, 'src in {16, 32, 64} & 'dst in {8, 16, 32} & 'src > 'dst.
  (PackedNarrowOp, int('dst), bits('src)) -> bits('dst)
function packed_narrow_elem(op, dst, a) = match op {
  PN_Trunc => a[('dst - 1)..0],
  PN_SatU  => sat_u(a),
  PN_SatS  => sat_s(a),
  PN_SatSU => sat_su(a),
}

val packed_narrow_unop : forall 'vl 'src 'dst,
  'vl in {128, 256, 512} & 'src in {16, 32, 64} & 'dst in {8, 16, 32} & 'src > 'dst.
  (PackedNarrowOp, int('src), int('dst), bits('vl)) -> bits(div('vl * 'dst, 'src))
function packed_narrow_unop(op, src_eb, dst_eb, a) = {
  var r : bits(div('vl * 'dst, 'src)) = zeros();
  foreach (i from 0 to ('vl / 'src - 1)) {
    let slo = i * 'src;
    let dlo = i * 'dst;
    r[(dlo + 'dst - 1)..dlo] = packed_narrow_elem(op, dst_eb, a[(slo + 'src - 1)..slo])
  };
  r
}

// Two-source narrowing pack: within each 128-bit lane, narrow elements from a
// into the lower half and from b into the upper half, applying saturation.
// Covers PACKSSWB (PN_SatS, 16→8), PACKSSDW (PN_SatS, 32→16),
// PACKUSWB (PN_SatSU, 16→8), PACKUSDW (PN_SatSU, 32→16).
val packed_pack : forall 'vl 'src 'dst,
  'vl in {128, 256, 512} & 'src in {16, 32} & 'dst in {8, 16} & 'src == 'dst * 2.
  (PackedNarrowOp, int('src), int('dst), bits('vl), bits('vl)) -> bits('vl)
function packed_pack(op, src, dst, a, b) = {
  var r : bits('vl) = zeros();
  let elems = 128 / src;
  foreach (j from 0 to ('vl / 128 - 1)) {
    let lbase = j * 128;
    foreach (i from 0 to (elems - 1)) {
      let slo = lbase + i * src;
      let a_lo = lbase + i * dst;
      let b_lo = lbase + 64 + i * dst;
      r[(a_lo + dst - 1)..a_lo] = packed_narrow_elem(op, dst, a[(slo + src - 1)..slo]);
      r[(b_lo + dst - 1)..b_lo] = packed_narrow_elem(op, dst, b[(slo + src - 1)..slo]);
    }
  };
  r
}

// Generic packed widening unary operation (each element expands).
enum PackedWidenOp = { PW_SignExtend, PW_ZeroExtend }

val packed_widen_unop : forall 'vl 'n 'src 'dst,
  'vl in {128, 256, 512} & 'src in {8, 16, 32} & 'dst in {16, 32, 64} & 'dst > 'src &
  'n > 0 & 'n * 'dst == 'vl * 'src.
  (implicit('vl), PackedWidenOp, int('src), int('dst), bits('n)) -> bits('vl)
function packed_widen_unop(vl, op, src_eb, dst_eb, a) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 'dst - 1)) {
    let slo = i * 'src;
    let dlo = i * 'dst;
    let elem = a[(slo + 'src - 1)..slo];
    r[(dlo + 'dst - 1)..dlo] = match op {
      PW_SignExtend => sign_extend(dst_eb, elem),
      PW_ZeroExtend => zero_extend(dst_eb, elem),
    }
  };
  r
}

// Generic packed ternary operation (element-wise, three sources).
enum PackedTernaryOp = {
  PT_FMAdd, PT_FMSub, PT_FNMAdd, PT_FNMSub,
  PT_FunnelShl, PT_FunnelShr,
}

val packed_ternary_elem : forall 'eb, 'eb in {8, 16, 32, 64}.
  (PackedTernaryOp, bits('eb), bits('eb), bits('eb)) -> bits('eb)
function packed_ternary_elem(op, a, b, c) = match op {
  PT_FMAdd      => fp_fmadd(a, b, c),
  PT_FMSub      => fp_fmsub(a, b, c),
  PT_FNMAdd     => fp_fnmadd(a, b, c),
  PT_FNMSub     => fp_fnmsub(a, b, c),
  PT_FunnelShl  => ((a @ b) << (unsigned(c) % 'eb))[('eb * 2 - 1) .. 'eb],
  PT_FunnelShr  => ((b @ a) >> (unsigned(c) % 'eb))[('eb - 1) .. 0],
}

val packed_ternop : forall 'vl 'eb, 'vl in {128, 256, 512} & 'eb in {8, 16, 32, 64}.
  (PackedTernaryOp, int('eb), bits('vl), bits('vl), bits('vl)) -> bits('vl)
function packed_ternop(op, eb, a, b, c) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 'eb - 1)) {
    let hi = (i + 1) * 'eb - 1;
    let lo = i * 'eb;
    r[hi..lo] = packed_ternary_elem(op, a[hi..lo], b[hi..lo], c[hi..lo])
  };
  r
}

// =========================================================================
// FP16 <-> FP32 packed conversion
// =========================================================================

val avx_vcvtph2ps : forall 'n, 'n in {64, 128, 256}. bits('n) -> bits('n * 2)
function avx_vcvtph2ps(src) = {
  var r : bits('n * 2) = zeros();
  foreach (i from 0 to ('n / 16 - 1)) {
    let src_lo = i * 16;
    let dst_lo = i * 32;
    r[(dst_lo + 31)..dst_lo] = fp16_to_fp32(src[(src_lo + 15)..src_lo]);
  };
  r
}

val avx_vcvtps2ph : forall 'n, 'n in {128, 256, 512}. (bits('n), bits(2)) -> bits(div('n, 2))
function avx_vcvtps2ph(src, rc) = {
  var r : bits(div('n, 2)) = zeros();
  foreach (i from 0 to ('n / 32 - 1)) {
    let src_lo = i * 32;
    let dst_lo = i * 16;
    r[(dst_lo + 15)..dst_lo] = fp32_to_fp16(src[(src_lo + 31)..src_lo], rc);
  };
  r
}

// =========================================================================
// GFNI vector operations
// =========================================================================

val avx_gf2p8mulb : forall 'vl, 'vl in {128, 256, 512}.
  (bits('vl), bits('vl)) -> bits('vl)
function avx_gf2p8mulb(src1, src2) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 8 - 1)) {
    let lo = i * 8;
    r[(lo + 7)..lo] = gf2p8_mul(src1[(lo + 7)..lo], src2[(lo + 7)..lo]);
  };
  r
}

// Per-byte affine transform; each byte uses the 8x8 matrix from its 64-bit lane.
val avx_gf2p8affineqb : forall 'vl, 'vl in {128, 256, 512}.
  (bits('vl), bits('vl), byte) -> bits('vl)
function avx_gf2p8affineqb(src1, src2, imm8) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 8 - 1)) {
    let lo = i * 8;
    let lane = (i / 8) * 64;
    r[(lo + 7)..lo] = gf2p8_affine(src1[(lo + 7)..lo], src2[(lane + 63)..lane], imm8);
  };
  r
}

// Same but first applies GF(2^8) inverse on each src1 byte.
val avx_gf2p8affineinvqb : forall 'vl, 'vl in {128, 256, 512}.
  (bits('vl), bits('vl), byte) -> bits('vl)
function avx_gf2p8affineinvqb(src1, src2, imm8) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 8 - 1)) {
    let lo = i * 8;
    let lane = (i / 8) * 64;
    r[(lo + 7)..lo] = gf2p8_affine(gf2p8_inv(src1[(lo + 7)..lo]), src2[(lane + 63)..lane], imm8);
  };
  r
}

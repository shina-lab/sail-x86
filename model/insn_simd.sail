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
}

// Per-element dispatch: applies the operation to one pair of elements.
val packed_elem_op : forall 'eb, 'eb in {8, 16, 32, 64}.
  (PackedBinOp, bits('eb), bits('eb)) -> bits('eb)
function packed_elem_op(op, a, b) = match op {
  PB_Add      => a + b,
  PB_Sub      => a - b,
  PB_SatAddS  => sat_add_s(a, b),
  PB_SatSubS  => sat_sub_s(a, b),
  PB_SatAddU  => sat_add_u(a, b),
  PB_SatSubU  => sat_sub_u(a, b),
  PB_MinU     => min_u(a, b),
  PB_MaxU     => max_u(a, b),
  PB_MinS     => min_s(a, b),
  PB_MaxS     => max_s(a, b),
  PB_Avg      => avg(a, b),
  PB_Srl      => a >> b,
  PB_Sra      => a >>> unsigned(b),
  PB_Sll      => a << b,
  PB_MulLow   => to_bits_truncate(signed(a) * signed(b)),
  PB_MulHighS => get_slice_int('eb, signed(a) * signed(b), 'eb),
  PB_MulHighU => get_slice_int('eb, unsigned(a) * unsigned(b), 'eb),
  PB_MulHRS   => mulhrs(a, b),
  PB_Ror      => rotr(a, unsigned(b) % 'eb),
  PB_Rol      => rotl(a, unsigned(b) % 'eb),
  PB_CmpEq    => cmp_eq(a, b),
  PB_CmpGt    => cmp_gt(a, b),
  PB_PSign    => psign(a, b),
  PB_FAdd     => fp_add(a, b),
  PB_FSub     => fp_sub(a, b),
  PB_FMul     => fp_mul(a, b),
  PB_FDiv     => fp_div(a, b),
  PB_FMin     => fp_min(a, b),
  PB_FMax     => fp_max(a, b),
  PB_FPScalef => fp_scalef(a, b),
}

// Apply a packed binary operation element-wise across a vector.
val packed_binop : forall 'vl 'eb, 'vl in {128, 256, 512} & 'eb in {8, 16, 32, 64}.
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

// Horizontal packed binary operation: within each lane, pair adjacent elements
// from a (lower half of lane result) and b (upper half), apply op.
// Lane size is 64 for MMX, 128 for SSE/VEX/EVEX.
val packed_horiz_binop : forall 'vl 'lane 'eb,
  'vl in {64, 128, 256} & 'lane in {64, 128} & 'eb in {16, 32}.
  (PackedBinOp, int('eb), int('lane), bits('vl), bits('vl)) -> bits('vl)
function packed_horiz_binop(op, eb, lane, a, b) = {
  var r : bits('vl) = zeros();
  let n_pairs = lane / (2 * eb);
  foreach (j from 0 to ('vl / 'lane - 1)) {
    let lbase = j * lane;
    foreach (i from 0 to (n_pairs - 1)) {
      let src_lo = lbase + i * 2 * eb;
      let a_lo = lbase + i * eb;
      let b_lo = lbase + (n_pairs + i) * eb;
      r[(a_lo + eb - 1)..a_lo] = packed_elem_op(op, a[(src_lo + eb - 1)..src_lo], a[(src_lo + 2 * eb - 1)..(src_lo + eb)]);
      r[(b_lo + eb - 1)..b_lo] = packed_elem_op(op, b[(src_lo + eb - 1)..src_lo], b[(src_lo + 2 * eb - 1)..(src_lo + eb)]);
    }
  };
  r
}

// Generic packed narrowing unary operation (each element shrinks).
enum PackedNarrowOp = { PN_Trunc, PN_SatU, PN_SatS }

val packed_narrow_elem : forall 'src 'dst, 'src in {16, 32, 64} & 'dst in {8, 16, 32} & 'src > 'dst.
  (PackedNarrowOp, int('dst), bits('src)) -> bits('dst)
function packed_narrow_elem(op, dst, a) = match op {
  PN_Trunc => a[('dst - 1)..0],
  PN_SatU  => sat_u(a),
  PN_SatS  => sat_s(a),
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

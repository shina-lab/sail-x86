// x86-64 EVEX — FP Operations (0F map)
//
// FP mov, arithmetic, compare, and convert instructions.
// Called from dispatch_evex_0f in insn_evex.sail.

val vaddps_ymm : (ymmword, ymmword) -> ymmword
function vaddps_ymm(a, b) =
  vaddps_xmm(a[255..128], b[255..128]) @ vaddps_xmm(a[127..0], b[127..0])

val vsubps_ymm : (ymmword, ymmword) -> ymmword
function vsubps_ymm(a, b) =
  vsubps_xmm(a[255..128], b[255..128]) @ vsubps_xmm(a[127..0], b[127..0])

val vmulps_ymm : (ymmword, ymmword) -> ymmword
function vmulps_ymm(a, b) =
  vmulps_xmm(a[255..128], b[255..128]) @ vmulps_xmm(a[127..0], b[127..0])

val vdivps_ymm : (ymmword, ymmword) -> ymmword
function vdivps_ymm(a, b) =
  vdivps_xmm(a[255..128], b[255..128]) @ vdivps_xmm(a[127..0], b[127..0])

val vminps_ymm : (ymmword, ymmword) -> ymmword
function vminps_ymm(a, b) =
  vminps_xmm(a[255..128], b[255..128]) @ vminps_xmm(a[127..0], b[127..0])

val vmaxps_ymm : (ymmword, ymmword) -> ymmword
function vmaxps_ymm(a, b) =
  vmaxps_xmm(a[255..128], b[255..128]) @ vmaxps_xmm(a[127..0], b[127..0])

val vsqrtps_ymm : ymmword -> ymmword
function vsqrtps_ymm(a) =
  vsqrtps_xmm(a[255..128]) @ vsqrtps_xmm(a[127..0])

val vaddpd_ymm : (ymmword, ymmword) -> ymmword
function vaddpd_ymm(a, b) =
  vaddpd_xmm(a[255..128], b[255..128]) @ vaddpd_xmm(a[127..0], b[127..0])

val vsubpd_ymm : (ymmword, ymmword) -> ymmword
function vsubpd_ymm(a, b) =
  vsubpd_xmm(a[255..128], b[255..128]) @ vsubpd_xmm(a[127..0], b[127..0])

val vmulpd_ymm : (ymmword, ymmword) -> ymmword
function vmulpd_ymm(a, b) =
  vmulpd_xmm(a[255..128], b[255..128]) @ vmulpd_xmm(a[127..0], b[127..0])

val vdivpd_ymm : (ymmword, ymmword) -> ymmword
function vdivpd_ymm(a, b) =
  vdivpd_xmm(a[255..128], b[255..128]) @ vdivpd_xmm(a[127..0], b[127..0])

val vminpd_ymm : (ymmword, ymmword) -> ymmword
function vminpd_ymm(a, b) =
  vminpd_xmm(a[255..128], b[255..128]) @ vminpd_xmm(a[127..0], b[127..0])

val vmaxpd_ymm : (ymmword, ymmword) -> ymmword
function vmaxpd_ymm(a, b) =
  vmaxpd_xmm(a[255..128], b[255..128]) @ vmaxpd_xmm(a[127..0], b[127..0])

val vsqrtpd_ymm : ymmword -> ymmword
function vsqrtpd_ymm(a) =
  vsqrtpd_xmm(a[255..128]) @ vsqrtpd_xmm(a[127..0])

// =========================================================================
// Packed integer add/sub helpers (byte/word/dword/qword)
// 128-bit: manually unrolled. 256-bit: split into two 128-bit halves.
// =========================================================================

val vaddps_zmm : (zmmword, zmmword) -> zmmword
function vaddps_zmm(a, b) =
  vaddps_ymm(a[511..256], b[511..256]) @ vaddps_ymm(a[255..0], b[255..0])

val vsubps_zmm : (zmmword, zmmword) -> zmmword
function vsubps_zmm(a, b) =
  vsubps_ymm(a[511..256], b[511..256]) @ vsubps_ymm(a[255..0], b[255..0])

val vmulps_zmm : (zmmword, zmmword) -> zmmword
function vmulps_zmm(a, b) =
  vmulps_ymm(a[511..256], b[511..256]) @ vmulps_ymm(a[255..0], b[255..0])

val vdivps_zmm : (zmmword, zmmword) -> zmmword
function vdivps_zmm(a, b) =
  vdivps_ymm(a[511..256], b[511..256]) @ vdivps_ymm(a[255..0], b[255..0])

val vminps_zmm : (zmmword, zmmword) -> zmmword
function vminps_zmm(a, b) =
  vminps_ymm(a[511..256], b[511..256]) @ vminps_ymm(a[255..0], b[255..0])

val vmaxps_zmm : (zmmword, zmmword) -> zmmword
function vmaxps_zmm(a, b) =
  vmaxps_ymm(a[511..256], b[511..256]) @ vmaxps_ymm(a[255..0], b[255..0])

val vsqrtps_zmm : zmmword -> zmmword
function vsqrtps_zmm(a) =
  vsqrtps_ymm(a[511..256]) @ vsqrtps_ymm(a[255..0])

val vaddpd_zmm : (zmmword, zmmword) -> zmmword
function vaddpd_zmm(a, b) =
  vaddpd_ymm(a[511..256], b[511..256]) @ vaddpd_ymm(a[255..0], b[255..0])

val vsubpd_zmm : (zmmword, zmmword) -> zmmword
function vsubpd_zmm(a, b) =
  vsubpd_ymm(a[511..256], b[511..256]) @ vsubpd_ymm(a[255..0], b[255..0])

val vmulpd_zmm : (zmmword, zmmword) -> zmmword
function vmulpd_zmm(a, b) =
  vmulpd_ymm(a[511..256], b[511..256]) @ vmulpd_ymm(a[255..0], b[255..0])

val vdivpd_zmm : (zmmword, zmmword) -> zmmword
function vdivpd_zmm(a, b) =
  vdivpd_ymm(a[511..256], b[511..256]) @ vdivpd_ymm(a[255..0], b[255..0])

val vminpd_zmm : (zmmword, zmmword) -> zmmword
function vminpd_zmm(a, b) =
  vminpd_ymm(a[511..256], b[511..256]) @ vminpd_ymm(a[255..0], b[255..0])

val vmaxpd_zmm : (zmmword, zmmword) -> zmmword
function vmaxpd_zmm(a, b) =
  vmaxpd_ymm(a[511..256], b[511..256]) @ vmaxpd_ymm(a[255..0], b[255..0])

val vsqrtpd_zmm : zmmword -> zmmword
function vsqrtpd_zmm(a) =
  vsqrtpd_ymm(a[511..256]) @ vsqrtpd_ymm(a[255..0])

// =========================================================================
// 512-bit packed integer add/sub
// =========================================================================

val avx_movsldup_128 : xmmword -> xmmword
function avx_movsldup_128(src) = {
  // [127:96]=src[95:64], [95:64]=src[95:64], [63:32]=src[31:0], [31:0]=src[31:0]
  src[95..64] @ src[95..64] @ src[31..0] @ src[31..0]
}

val avx_movsldup_256 : ymmword -> ymmword
function avx_movsldup_256(src) =
  avx_movsldup_128(src[255..128]) @ avx_movsldup_128(src[127..0])

val avx_movsldup_512 : zmmword -> zmmword
function avx_movsldup_512(src) =
  avx_movsldup_256(src[511..256]) @ avx_movsldup_256(src[255..0])

// =========================================================================
// VMOVSHDUP — Duplicate Odd-Indexed Single-FP Values
// Each pair of 32-bit floats: [A, B] → [B, B] (odd index duplicated)
// =========================================================================

val avx_movshdup_128 : xmmword -> xmmword
function avx_movshdup_128(src) = {
  src[127..96] @ src[127..96] @ src[63..32] @ src[63..32]
}

val avx_movshdup_256 : ymmword -> ymmword
function avx_movshdup_256(src) =
  avx_movshdup_128(src[255..128]) @ avx_movshdup_128(src[127..0])

val avx_movshdup_512 : zmmword -> zmmword
function avx_movshdup_512(src) =
  avx_movshdup_256(src[511..256]) @ avx_movshdup_256(src[255..0])

// =========================================================================
// VMOVDDUP — Duplicate Low Double-FP Value in each 128-bit lane
// Each 128-bit lane: [A, B] → [A, A] (low qword duplicated)
// =========================================================================

val avx_movddup_128 : xmmword -> xmmword
function avx_movddup_128(src) = src[63..0] @ src[63..0]

val avx_movddup_256 : ymmword -> ymmword
function avx_movddup_256(src) =
  avx_movddup_128(src[255..128]) @ avx_movddup_128(src[127..0])

val avx_movddup_512 : zmmword -> zmmword
function avx_movddup_512(src) =
  avx_movddup_256(src[511..256]) @ avx_movddup_256(src[255..0])

// =========================================================================
// VUNPCKLPS — Unpack and Interleave Low Single-FP Values (per 128-bit lane)
// =========================================================================

val avx_unpcklps_128 : (xmmword, xmmword) -> xmmword
function avx_unpcklps_128(a, b) =
  b[63..32] @ a[63..32] @ b[31..0] @ a[31..0]

val avx_unpcklps_256 : (ymmword, ymmword) -> ymmword
function avx_unpcklps_256(a, b) =
  avx_unpcklps_128(a[255..128], b[255..128]) @ avx_unpcklps_128(a[127..0], b[127..0])

val avx_unpcklps_512 : (zmmword, zmmword) -> zmmword
function avx_unpcklps_512(a, b) =
  avx_unpcklps_256(a[511..256], b[511..256]) @ avx_unpcklps_256(a[255..0], b[255..0])

// =========================================================================
// VUNPCKHPS — Unpack and Interleave High Single-FP Values (per 128-bit lane)
// =========================================================================

val avx_unpckhps_128 : (xmmword, xmmword) -> xmmword
function avx_unpckhps_128(a, b) =
  b[127..96] @ a[127..96] @ b[95..64] @ a[95..64]

val avx_unpckhps_256 : (ymmword, ymmword) -> ymmword
function avx_unpckhps_256(a, b) =
  avx_unpckhps_128(a[255..128], b[255..128]) @ avx_unpckhps_128(a[127..0], b[127..0])

val avx_unpckhps_512 : (zmmword, zmmword) -> zmmword
function avx_unpckhps_512(a, b) =
  avx_unpckhps_256(a[511..256], b[511..256]) @ avx_unpckhps_256(a[255..0], b[255..0])

// =========================================================================
// VUNPCKLPD — Unpack and Interleave Low Double-FP Values (per 128-bit lane)
// =========================================================================

val avx_unpcklpd_128 : (xmmword, xmmword) -> xmmword
function avx_unpcklpd_128(a, b) = b[63..0] @ a[63..0]

val avx_unpcklpd_256 : (ymmword, ymmword) -> ymmword
function avx_unpcklpd_256(a, b) =
  avx_unpcklpd_128(a[255..128], b[255..128]) @ avx_unpcklpd_128(a[127..0], b[127..0])

val avx_unpcklpd_512 : (zmmword, zmmword) -> zmmword
function avx_unpcklpd_512(a, b) =
  avx_unpcklpd_256(a[511..256], b[511..256]) @ avx_unpcklpd_256(a[255..0], b[255..0])

// =========================================================================
// VUNPCKHPD — Unpack and Interleave High Double-FP Values (per 128-bit lane)
// =========================================================================

val avx_unpckhpd_128 : (xmmword, xmmword) -> xmmword
function avx_unpckhpd_128(a, b) = b[127..64] @ a[127..64]

val avx_unpckhpd_256 : (ymmword, ymmword) -> ymmword
function avx_unpckhpd_256(a, b) =
  avx_unpckhpd_128(a[255..128], b[255..128]) @ avx_unpckhpd_128(a[127..0], b[127..0])

val avx_unpckhpd_512 : (zmmword, zmmword) -> zmmword
function avx_unpckhpd_512(a, b) =
  avx_unpckhpd_256(a[511..256], b[511..256]) @ avx_unpckhpd_256(a[255..0], b[255..0])

// =========================================================================
// FP compare predicate (5-bit imm8 for AVX/AVX-512 VCMPPS/VCMPPD)
// =========================================================================

// Full 5-bit predicate (imm8[4:0]) for VCMPPS/VCMPPD/VCMPSS/VCMPSD.
// Returns 1 bit (true/false) for a single element comparison.

val cmp_pred5_f32 : (dword, dword, range(0, 31)) -> bool
function cmp_pred5_f32(a, b, pred) = {
  let r = __compare_ss(a, b);
  let is_unord = r == FP_UNORDERED;
  match pred {
    0  => r == FP_EQ,                        // EQ_OQ
    1  => r == FP_LT,                        // LT_OS
    2  => r == FP_LT | r == FP_EQ,           // LE_OS
    3  => is_unord,                           // UNORD_Q
    4  => r != FP_EQ & not_bool(is_unord),    // NEQ_UQ (true if unord too, but NEQ)
    5  => not_bool(r == FP_LT) | is_unord,   // NLT_US
    6  => not_bool(r == FP_LT | r == FP_EQ) | is_unord, // NLE_US
    7  => not_bool(is_unord),                 // ORD_Q
    8  => r == FP_EQ | is_unord,             // EQ_UQ
    9  => r == FP_LT | is_unord,             // NGE_US (= LT or unord)
    10 => (r == FP_LT | r == FP_EQ) | is_unord, // NGT_US (= LE or unord)
    11 => false,                             // FALSE_OQ
    12 => r != FP_EQ,                        // NEQ_OQ
    13 => not_bool(r == FP_LT),              // GE_OS (= NLT)
    14 => r == FP_GT | r == FP_EQ,           // GT_OS
    15 => true,                              // TRUE_UQ
    16 => r == FP_EQ,                        // EQ_OS
    17 => r == FP_LT,                        // LT_OQ
    18 => r == FP_LT | r == FP_EQ,           // LE_OQ
    19 => is_unord,                          // UNORD_S
    20 => r != FP_EQ | is_unord,             // NEQ_US
    21 => not_bool(r == FP_LT) | is_unord,   // NLT_UQ
    22 => not_bool(r == FP_LT | r == FP_EQ) | is_unord, // NLE_UQ
    23 => not_bool(is_unord),                // ORD_S
    24 => r == FP_EQ | is_unord,             // EQ_US
    25 => r == FP_LT | is_unord,             // NGE_UQ
    26 => (r == FP_LT | r == FP_EQ) | is_unord, // NGT_UQ
    27 => false,                             // FALSE_OS
    28 => r != FP_EQ,                        // NEQ_OS
    29 => not_bool(r == FP_LT),              // GE_OQ
    30 => r == FP_GT | r == FP_EQ,           // GT_OQ
    31 => true,                              // TRUE_US
  }
}

val cmp_pred5_f64 : (qword, qword, range(0, 31)) -> bool
function cmp_pred5_f64(a, b, pred) = {
  let r = __compare_sd(a, b);
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

// VCMPPS → kmask: compare 16 f32 elements, return 16-bit mask

val avx_vcmpps_kmask_128 : (xmmword, xmmword, range(0, 31)) -> bits(4)
function avx_vcmpps_kmask_128(a, b, pred) = {
  var r : bits(4) = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    if cmp_pred5_f32(a[(lo+31)..lo], b[(lo+31)..lo], pred) then r[i] = bitone;
  };
  r
}

val avx_vcmpps_kmask_512 : (zmmword, zmmword, range(0, 31)) -> word
function avx_vcmpps_kmask_512(a, b, pred) = {
  var r : word = zeros();
  foreach (i from 0 to 15) {
    let lo : range(0, 480) = i * 32;
    if cmp_pred5_f32(a[(lo+31)..lo], b[(lo+31)..lo], pred) then r[i] = bitone;
  };
  r
}

val avx_vcmppd_kmask_128 : (xmmword, xmmword, range(0, 31)) -> bits(2)
function avx_vcmppd_kmask_128(a, b, pred) = {
  var r : bits(2) = zeros();
  foreach (i from 0 to 1) {
    let lo : range(0, 64) = i * 64;
    if cmp_pred5_f64(a[(lo+63)..lo], b[(lo+63)..lo], pred) then r[i] = bitone;
  };
  r
}

val avx_vcmppd_kmask_512 : (zmmword, zmmword, range(0, 31)) -> byte
function avx_vcmppd_kmask_512(a, b, pred) = {
  var r : byte = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 448) = i * 64;
    if cmp_pred5_f64(a[(lo+63)..lo], b[(lo+63)..lo], pred) then r[i] = bitone;
  };
  r
}

// FP16 compare predicate (5-bit imm8)

val avx_cvtps2pd_2 : qword -> xmmword
function avx_cvtps2pd_2(src) =
  __f32_to_f64(src[63..32]) @ __f32_to_f64(src[31..0])

val avx_cvtps2pd_4 : xmmword -> ymmword
function avx_cvtps2pd_4(src) =
  avx_cvtps2pd_2(src[127..64]) @ avx_cvtps2pd_2(src[63..0])

val avx_cvtps2pd_8 : ymmword -> zmmword
function avx_cvtps2pd_8(src) =
  avx_cvtps2pd_4(src[255..128]) @ avx_cvtps2pd_4(src[127..0])

// VCVTPD2PS: convert N f64 → N f32 (narrowing) — result is half-width

val avx_cvtpd2ps_2 : xmmword -> qword
function avx_cvtpd2ps_2(src) =
  __f64_to_f32(src[127..64]) @ __f64_to_f32(src[63..0])

val avx_cvtpd2ps_4 : ymmword -> xmmword
function avx_cvtpd2ps_4(src) =
  avx_cvtpd2ps_2(src[255..128]) @ avx_cvtpd2ps_2(src[127..0])

val avx_cvtpd2ps_8 : zmmword -> ymmword
function avx_cvtpd2ps_8(src) =
  avx_cvtpd2ps_4(src[511..256]) @ avx_cvtpd2ps_4(src[255..0])

// VCVTDQ2PS: convert N i32 → N f32

val avx_cvtdq2ps_128 : xmmword -> xmmword
function avx_cvtdq2ps_128(src) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    r[(lo + 31)..lo] = __int32_to_f32(src[(lo + 31)..lo]);
  };
  r
}

val avx_cvtdq2ps_256 : ymmword -> ymmword
function avx_cvtdq2ps_256(src) =
  avx_cvtdq2ps_128(src[255..128]) @ avx_cvtdq2ps_128(src[127..0])

val avx_cvtdq2ps_512 : zmmword -> zmmword
function avx_cvtdq2ps_512(src) =
  avx_cvtdq2ps_256(src[511..256]) @ avx_cvtdq2ps_256(src[255..0])

// VCVTPS2DQ: convert N f32 → N i32 (round per MXCSR)

val avx_cvtps2dq_128 : xmmword -> xmmword
function avx_cvtps2dq_128(src) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    r[(lo + 31)..lo] = __f32_to_int32(src[(lo + 31)..lo]);
  };
  r
}

val avx_cvtps2dq_256 : ymmword -> ymmword
function avx_cvtps2dq_256(src) =
  avx_cvtps2dq_128(src[255..128]) @ avx_cvtps2dq_128(src[127..0])

val avx_cvtps2dq_512 : zmmword -> zmmword
function avx_cvtps2dq_512(src) =
  avx_cvtps2dq_256(src[511..256]) @ avx_cvtps2dq_256(src[255..0])

// VCVTTPS2DQ: convert N f32 → N i32 (truncate)

val avx_cvttps2dq_128 : xmmword -> xmmword
function avx_cvttps2dq_128(src) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    r[(lo + 31)..lo] = __f32_to_int32_trunc(src[(lo + 31)..lo]);
  };
  r
}

val avx_cvttps2dq_256 : ymmword -> ymmword
function avx_cvttps2dq_256(src) =
  avx_cvttps2dq_128(src[255..128]) @ avx_cvttps2dq_128(src[127..0])

val avx_cvttps2dq_512 : zmmword -> zmmword
function avx_cvttps2dq_512(src) =
  avx_cvttps2dq_256(src[511..256]) @ avx_cvttps2dq_256(src[255..0])

// VSHUFPS: shuffle f32 per 128-bit lane
// Low 2 elements from src1 lane (imm8[1:0], imm8[3:2])
// High 2 elements from src2 lane (imm8[5:4], imm8[7:6])

val shufps_lane : (bits(128), bits(128), bits(8)) -> bits(128)
function shufps_lane(src1, src2, imm) =
  select4_f32(src2, imm[7..6]) @
  select4_f32(src2, imm[5..4]) @
  select4_f32(src1, imm[3..2]) @
  select4_f32(src1, imm[1..0])

val avx_shufps_128 : (xmmword, xmmword, bits(8)) -> xmmword
function avx_shufps_128(src1, src2, imm) =
  shufps_lane(src1, src2, imm)

val avx_shufps_256 : (ymmword, ymmword, bits(8)) -> ymmword
function avx_shufps_256(src1, src2, imm) =
  shufps_lane(src1[255..128], src2[255..128], imm) @
  shufps_lane(src1[127..0], src2[127..0], imm)

val avx_shufps_512 : (zmmword, zmmword, bits(8)) -> zmmword
function avx_shufps_512(src1, src2, imm) =
  avx_shufps_256(src1[511..256], src2[511..256], imm) @
  avx_shufps_256(src1[255..0], src2[255..0], imm)

// VSHUFPD: shuffle f64 per 128-bit lane
// Each bit in imm8 selects low(0) or high(1) qword from src1/src2
// Bit 0 → dest[63:0] from src1, Bit 1 → dest[127:64] from src2
// Bit 2 → dest[191:128] from src1, Bit 3 → dest[255:192] from src2, etc.

val shufpd_lane : (bits(128), bits(128), bit, bit) -> bits(128)
function shufpd_lane(src1, src2, ctrl0, ctrl1) = {
  let lo : bits(64) = if ctrl0 == bitone then src1[127..64] else src1[63..0];
  let hi : bits(64) = if ctrl1 == bitone then src2[127..64] else src2[63..0];
  hi @ lo
}

val avx_shufpd_128 : (xmmword, xmmword, bits(8)) -> xmmword
function avx_shufpd_128(src1, src2, imm) =
  shufpd_lane(src1, src2, imm[0], imm[1])

val avx_shufpd_256 : (ymmword, ymmword, bits(8)) -> ymmword
function avx_shufpd_256(src1, src2, imm) =
  shufpd_lane(src1[255..128], src2[255..128], imm[2], imm[3]) @
  shufpd_lane(src1[127..0], src2[127..0], imm[0], imm[1])

val avx_shufpd_512 : (zmmword, zmmword, bits(8)) -> zmmword
function avx_shufpd_512(src1, src2, imm) =
  shufpd_lane(src1[511..384], src2[511..384], imm[6], imm[7]) @
  shufpd_lane(src1[383..256], src2[383..256], imm[4], imm[5]) @
  shufpd_lane(src1[255..128], src2[255..128], imm[2], imm[3]) @
  shufpd_lane(src1[127..0], src2[127..0], imm[0], imm[1])

// VCVTTPS2UDQ: convert N f32 → N u32 (truncate)

val avx_cvttps2udq_128 : xmmword -> xmmword
function avx_cvttps2udq_128(src) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    r[(lo + 31)..lo] = __f32_to_uint32_trunc(src[(lo + 31)..lo]);
  };
  r
}

val avx_cvttps2udq_256 : ymmword -> ymmword
function avx_cvttps2udq_256(src) =
  avx_cvttps2udq_128(src[255..128]) @ avx_cvttps2udq_128(src[127..0])

val avx_cvttps2udq_512 : zmmword -> zmmword
function avx_cvttps2udq_512(src) =
  avx_cvttps2udq_256(src[511..256]) @ avx_cvttps2udq_256(src[255..0])

// VCVTTPD2UDQ: convert N f64 → N u32 (truncate), result is half width

val avx_cvttpd2udq_2 : xmmword -> bits(64)
function avx_cvttpd2udq_2(src) =
  __f64_to_uint32_trunc(src[127..64]) @ __f64_to_uint32_trunc(src[63..0])

val avx_cvttpd2udq_4 : ymmword -> xmmword
function avx_cvttpd2udq_4(src) =
  avx_cvttpd2udq_2(src[255..128]) @ avx_cvttpd2udq_2(src[127..0])

val avx_cvttpd2udq_8 : zmmword -> ymmword
function avx_cvttpd2udq_8(src) =
  avx_cvttpd2udq_4(src[511..256]) @ avx_cvttpd2udq_4(src[255..0])

// VCVTPS2UDQ: convert N f32 → N u32 (round per MXCSR)

val avx_cvtps2udq_128 : xmmword -> xmmword
function avx_cvtps2udq_128(src) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    r[(lo + 31)..lo] = __f32_to_uint32(src[(lo + 31)..lo]);
  };
  r
}

val avx_cvtps2udq_256 : ymmword -> ymmword
function avx_cvtps2udq_256(src) =
  avx_cvtps2udq_128(src[255..128]) @ avx_cvtps2udq_128(src[127..0])

val avx_cvtps2udq_512 : zmmword -> zmmword
function avx_cvtps2udq_512(src) =
  avx_cvtps2udq_256(src[511..256]) @ avx_cvtps2udq_256(src[255..0])

// VCVTPD2UDQ: convert N f64 → N u32 (round per MXCSR), result is half width

val avx_cvtpd2udq_2 : xmmword -> bits(64)
function avx_cvtpd2udq_2(src) =
  __f64_to_uint32(src[127..64]) @ __f64_to_uint32(src[63..0])

val avx_cvtpd2udq_4 : ymmword -> xmmword
function avx_cvtpd2udq_4(src) =
  avx_cvtpd2udq_2(src[255..128]) @ avx_cvtpd2udq_2(src[127..0])

val avx_cvtpd2udq_8 : zmmword -> ymmword
function avx_cvtpd2udq_8(src) =
  avx_cvtpd2udq_4(src[511..256]) @ avx_cvtpd2udq_4(src[255..0])

// VCVTTPS2UQQ: convert N f32 → N u64 (truncate), result is double width

val avx_cvttps2uqq_2 : bits(64) -> xmmword
function avx_cvttps2uqq_2(src) =
  __f32_to_uint64_trunc(src[63..32]) @ __f32_to_uint64_trunc(src[31..0])

val avx_cvttps2uqq_4 : xmmword -> ymmword
function avx_cvttps2uqq_4(src) =
  avx_cvttps2uqq_2(src[127..64]) @ avx_cvttps2uqq_2(src[63..0])

val avx_cvttps2uqq_8 : ymmword -> zmmword
function avx_cvttps2uqq_8(src) =
  avx_cvttps2uqq_4(src[255..128]) @ avx_cvttps2uqq_4(src[127..0])

// VCVTTPD2UQQ: convert N f64 → N u64 (truncate)

val avx_cvttpd2uqq_128 : xmmword -> xmmword
function avx_cvttpd2uqq_128(src) =
  __f64_to_uint64_trunc(src[127..64]) @ __f64_to_uint64_trunc(src[63..0])

val avx_cvttpd2uqq_256 : ymmword -> ymmword
function avx_cvttpd2uqq_256(src) =
  avx_cvttpd2uqq_128(src[255..128]) @ avx_cvttpd2uqq_128(src[127..0])

val avx_cvttpd2uqq_512 : zmmword -> zmmword
function avx_cvttpd2uqq_512(src) =
  avx_cvttpd2uqq_256(src[511..256]) @ avx_cvttpd2uqq_256(src[255..0])

// VCVTPS2UQQ: convert N f32 → N u64 (round), result is double width

val avx_cvtps2uqq_2 : bits(64) -> xmmword
function avx_cvtps2uqq_2(src) =
  __f32_to_uint64(src[63..32]) @ __f32_to_uint64(src[31..0])

val avx_cvtps2uqq_4 : xmmword -> ymmword
function avx_cvtps2uqq_4(src) =
  avx_cvtps2uqq_2(src[127..64]) @ avx_cvtps2uqq_2(src[63..0])

val avx_cvtps2uqq_8 : ymmword -> zmmword
function avx_cvtps2uqq_8(src) =
  avx_cvtps2uqq_4(src[255..128]) @ avx_cvtps2uqq_4(src[127..0])

// VCVTPD2UQQ: convert N f64 → N u64 (round)

val avx_cvtpd2uqq_128 : xmmword -> xmmword
function avx_cvtpd2uqq_128(src) =
  __f64_to_uint64(src[127..64]) @ __f64_to_uint64(src[63..0])

val avx_cvtpd2uqq_256 : ymmword -> ymmword
function avx_cvtpd2uqq_256(src) =
  avx_cvtpd2uqq_128(src[255..128]) @ avx_cvtpd2uqq_128(src[127..0])

val avx_cvtpd2uqq_512 : zmmword -> zmmword
function avx_cvtpd2uqq_512(src) =
  avx_cvtpd2uqq_256(src[511..256]) @ avx_cvtpd2uqq_256(src[255..0])

// VCVTTPS2QQ: convert N f32 → N i64 (truncate, widening)

val avx_cvttps2qq_2 : bits(64) -> xmmword
function avx_cvttps2qq_2(src) =
  __f32_to_int64_trunc(src[63..32]) @ __f32_to_int64_trunc(src[31..0])

val avx_cvttps2qq_4 : xmmword -> ymmword
function avx_cvttps2qq_4(src) =
  avx_cvttps2qq_2(src[127..64]) @ avx_cvttps2qq_2(src[63..0])

val avx_cvttps2qq_8 : ymmword -> zmmword
function avx_cvttps2qq_8(src) =
  avx_cvttps2qq_4(src[255..128]) @ avx_cvttps2qq_4(src[127..0])

// VCVTTPD2QQ: convert N f64 → N i64 (truncate)

val avx_cvttpd2qq_128 : xmmword -> xmmword
function avx_cvttpd2qq_128(src) =
  __f64_to_int64_trunc(src[127..64]) @ __f64_to_int64_trunc(src[63..0])

val avx_cvttpd2qq_256 : ymmword -> ymmword
function avx_cvttpd2qq_256(src) =
  avx_cvttpd2qq_128(src[255..128]) @ avx_cvttpd2qq_128(src[127..0])

val avx_cvttpd2qq_512 : zmmword -> zmmword
function avx_cvttpd2qq_512(src) =
  avx_cvttpd2qq_256(src[511..256]) @ avx_cvttpd2qq_256(src[255..0])

// VCVTPS2QQ: convert N f32 → N i64 (round, widening)

val avx_cvtps2qq_2 : bits(64) -> xmmword
function avx_cvtps2qq_2(src) =
  __f32_to_int64(src[63..32]) @ __f32_to_int64(src[31..0])

val avx_cvtps2qq_4 : xmmword -> ymmword
function avx_cvtps2qq_4(src) =
  avx_cvtps2qq_2(src[127..64]) @ avx_cvtps2qq_2(src[63..0])

val avx_cvtps2qq_8 : ymmword -> zmmword
function avx_cvtps2qq_8(src) =
  avx_cvtps2qq_4(src[255..128]) @ avx_cvtps2qq_4(src[127..0])

// VCVTPD2QQ: convert N f64 → N i64 (round)

val avx_cvtpd2qq_128 : xmmword -> xmmword
function avx_cvtpd2qq_128(src) =
  __f64_to_int64(src[127..64]) @ __f64_to_int64(src[63..0])

val avx_cvtpd2qq_256 : ymmword -> ymmword
function avx_cvtpd2qq_256(src) =
  avx_cvtpd2qq_128(src[255..128]) @ avx_cvtpd2qq_128(src[127..0])

val avx_cvtpd2qq_512 : zmmword -> zmmword
function avx_cvtpd2qq_512(src) =
  avx_cvtpd2qq_256(src[511..256]) @ avx_cvtpd2qq_256(src[255..0])

// VCVTUDQ2PS: convert N u32 → N f32

val avx_cvtudq2ps_128 : xmmword -> xmmword
function avx_cvtudq2ps_128(src) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    r[(lo + 31)..lo] = __uint32_to_f32(src[(lo + 31)..lo]);
  };
  r
}

val avx_cvtudq2ps_256 : ymmword -> ymmword
function avx_cvtudq2ps_256(src) =
  avx_cvtudq2ps_128(src[255..128]) @ avx_cvtudq2ps_128(src[127..0])

val avx_cvtudq2ps_512 : zmmword -> zmmword
function avx_cvtudq2ps_512(src) =
  avx_cvtudq2ps_256(src[511..256]) @ avx_cvtudq2ps_256(src[255..0])

// VCVTUQQ2PS: convert N u64 → N f32 (narrowing)

val avx_cvtuqq2ps_2 : xmmword -> bits(64)
function avx_cvtuqq2ps_2(src) =
  __uint64_to_f32(src[127..64]) @ __uint64_to_f32(src[63..0])

val avx_cvtuqq2ps_4 : ymmword -> xmmword
function avx_cvtuqq2ps_4(src) =
  avx_cvtuqq2ps_2(src[255..128]) @ avx_cvtuqq2ps_2(src[127..0])

val avx_cvtuqq2ps_8 : zmmword -> ymmword
function avx_cvtuqq2ps_8(src) =
  avx_cvtuqq2ps_4(src[511..256]) @ avx_cvtuqq2ps_4(src[255..0])

// VCVTQQ2PS: convert N i64 → N f32 (narrowing)

val avx_cvtqq2ps_2 : xmmword -> bits(64)
function avx_cvtqq2ps_2(src) =
  __int64_to_f32(src[127..64]) @ __int64_to_f32(src[63..0])

val avx_cvtqq2ps_4 : ymmword -> xmmword
function avx_cvtqq2ps_4(src) =
  avx_cvtqq2ps_2(src[255..128]) @ avx_cvtqq2ps_2(src[127..0])

val avx_cvtqq2ps_8 : zmmword -> ymmword
function avx_cvtqq2ps_8(src) =
  avx_cvtqq2ps_4(src[511..256]) @ avx_cvtqq2ps_4(src[255..0])

// VCVTUDQ2PD: convert N u32 → N f64 (widening)

val avx_cvtudq2pd_2 : bits(64) -> xmmword
function avx_cvtudq2pd_2(src) =
  __uint32_to_f64(src[63..32]) @ __uint32_to_f64(src[31..0])

val avx_cvtudq2pd_4 : xmmword -> ymmword
function avx_cvtudq2pd_4(src) =
  avx_cvtudq2pd_2(src[127..64]) @ avx_cvtudq2pd_2(src[63..0])

val avx_cvtudq2pd_8 : ymmword -> zmmword
function avx_cvtudq2pd_8(src) =
  avx_cvtudq2pd_4(src[255..128]) @ avx_cvtudq2pd_4(src[127..0])

// VCVTUQQ2PD: convert N u64 → N f64

val avx_cvtuqq2pd_128 : xmmword -> xmmword
function avx_cvtuqq2pd_128(src) =
  __uint64_to_f64(src[127..64]) @ __uint64_to_f64(src[63..0])

val avx_cvtuqq2pd_256 : ymmword -> ymmword
function avx_cvtuqq2pd_256(src) =
  avx_cvtuqq2pd_128(src[255..128]) @ avx_cvtuqq2pd_128(src[127..0])

val avx_cvtuqq2pd_512 : zmmword -> zmmword
function avx_cvtuqq2pd_512(src) =
  avx_cvtuqq2pd_256(src[511..256]) @ avx_cvtuqq2pd_256(src[255..0])

// VCVTDQ2PD: convert N i32 → N f64 (widening)

val avx_cvtdq2pd_2 : bits(64) -> xmmword
function avx_cvtdq2pd_2(src) =
  __int32_to_f64(src[63..32]) @ __int32_to_f64(src[31..0])

val avx_cvtdq2pd_4 : xmmword -> ymmword
function avx_cvtdq2pd_4(src) =
  avx_cvtdq2pd_2(src[127..64]) @ avx_cvtdq2pd_2(src[63..0])

val avx_cvtdq2pd_8 : ymmword -> zmmword
function avx_cvtdq2pd_8(src) =
  avx_cvtdq2pd_4(src[255..128]) @ avx_cvtdq2pd_4(src[127..0])

// VCVTPD2DQ: convert N f64 → N i32 (round, narrowing)

val avx_cvtpd2dq_2 : xmmword -> bits(64)
function avx_cvtpd2dq_2(src) =
  __f64_to_int32(src[127..64]) @ __f64_to_int32(src[63..0])

val avx_cvtpd2dq_4 : ymmword -> xmmword
function avx_cvtpd2dq_4(src) =
  avx_cvtpd2dq_2(src[255..128]) @ avx_cvtpd2dq_2(src[127..0])

val avx_cvtpd2dq_8 : zmmword -> ymmword
function avx_cvtpd2dq_8(src) =
  avx_cvtpd2dq_4(src[511..256]) @ avx_cvtpd2dq_4(src[255..0])

// VCVTTPD2DQ: convert N f64 → N i32 (truncate, narrowing)

val avx_cvttpd2dq_2 : xmmword -> bits(64)
function avx_cvttpd2dq_2(src) =
  __f64_to_int32_trunc(src[127..64]) @ __f64_to_int32_trunc(src[63..0])

val avx_cvttpd2dq_4 : ymmword -> xmmword
function avx_cvttpd2dq_4(src) =
  avx_cvttpd2dq_2(src[255..128]) @ avx_cvttpd2dq_2(src[127..0])

val avx_cvttpd2dq_8 : zmmword -> ymmword
function avx_cvttpd2dq_8(src) =
  avx_cvttpd2dq_4(src[511..256]) @ avx_cvttpd2dq_4(src[255..0])

// VCVTQQ2PD: convert N i64 → N f64

val avx_cvtqq2pd_128 : xmmword -> xmmword
function avx_cvtqq2pd_128(src) =
  __int64_to_f64(src[127..64]) @ __int64_to_f64(src[63..0])

val avx_cvtqq2pd_256 : ymmword -> ymmword
function avx_cvtqq2pd_256(src) =
  avx_cvtqq2pd_128(src[255..128]) @ avx_cvtqq2pd_128(src[127..0])

val avx_cvtqq2pd_512 : zmmword -> zmmword
function avx_cvtqq2pd_512(src) =
  avx_cvtqq2pd_256(src[511..256]) @ avx_cvtqq2pd_256(src[255..0])

// VPSHUFB: byte shuffle per 128-bit lane
// For each byte in ctrl: if bit7 set → 0, else use low 4 bits as index in lane of src


val dispatch_evex_fp : (range(0, 255), Prefixes) -> ExecutionResult
function dispatch_evex_fp(op, pfx) = {
  let mp = get_mandatory_prefix(pfx);

  match op {
  // 0F 10: VMOVUPS/VMOVUPD (EVEX load)
  16 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
    match mp {
      MP_NONE => { // VMOVUPS
        match pfx.evex_ll {
          2 => {
            let src : zmmword = if pfx.evex_b & is_mem
              then broadcast_f32_zmm(evex_src_m32(modrm, rm, pfx))
              else evex_src_zmm(modrm, rm, pfx);
            let masked = apply_writemask_ps_zmm(src, read_zmm(dst), evex_get_mask16(pfx), pfx.evex_z);
            write_zmm(dst, masked); Ok()
          },
          1 => {
            let src = evex_src_ymm(modrm, rm, pfx);
            write_ymm(dst, src); Ok()
          },
          _ => {
            let src = evex_src_xmm(modrm, rm, pfx);
            write_xmm(dst, src); Ok()
          },
        }
      },
      MP_66 => { // VMOVUPD
        match pfx.evex_ll {
          2 => {
            let src : zmmword = if pfx.evex_b & is_mem
              then broadcast_f64_zmm(evex_src_m64(modrm, rm, pfx))
              else evex_src_zmm(modrm, rm, pfx);
            let masked = apply_writemask_pd_zmm(src, read_zmm(dst), evex_get_mask8(pfx), pfx.evex_z);
            write_zmm(dst, masked); Ok()
          },
          1 => {
            let src = evex_src_ymm(modrm, rm, pfx);
            write_ymm(dst, src); Ok()
          },
          _ => {
            let src = evex_src_xmm(modrm, rm, pfx);
            write_xmm(dst, src); Ok()
          },
        }
      },
      MP_F3 => { // VMOVSS (scalar f32 load/move, EVEX)
        // Memory: xmm1 = zero_extend(m32)
        // Register: xmm1 = xmm2[127:32] @ xmm3[31:0]
        match rm {
          RM_mem(addr) => {
            let v : dword = mem_read32(fixup_addr(addr));
            write_xmm(dst, zero_extend(v)); Ok()
          },
          RM_reg(_) => {
            let src1 = read_xmm(pfx.evex_vvvvv);
            let src2 : dword = read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0];
            write_xmm(dst, src1[127..32] @ src2); Ok()
          },
        }
      },
      MP_F2 => { // VMOVSD (scalar f64 load/move, EVEX)
        // Memory: xmm1 = zero_extend(m64)
        // Register: xmm1 = xmm2[127:64] @ xmm3[63:0]
        match rm {
          RM_mem(addr) => {
            let v : qword = mem_read64(fixup_addr(addr));
            write_xmm(dst, zero_extend(v)); Ok()
          },
          RM_reg(_) => {
            let src1 = read_xmm(pfx.evex_vvvvv);
            let src2 : qword = read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0];
            write_xmm(dst, src1[127..64] @ src2); Ok()
          },
        }
      },
    }
  },

  // 0F 11: VMOVUPS/VMOVUPD/VMOVSS/VMOVSD (EVEX store)
  17 => {
    let modrm = fetch_byte();
    let src = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    match mp {
      MP_NONE => // VMOVUPS store
        match rm {
          RM_reg(_) => {
            let dst = evex_rm_reg_idx(modrm, pfx);
            match pfx.evex_ll {
              2 => {
                let masked = apply_writemask_ps_zmm(read_zmm(src), read_zmm(dst), evex_get_mask16(pfx), pfx.evex_z);
                write_zmm(dst, masked); Ok()
              },
              1 => { write_ymm(dst, read_ymm(src)); Ok() },
              _ => { write_xmm(dst, read_xmm(src)); Ok() },
            }
          },
          RM_mem(addr) => {
            let a = fixup_addr(addr);
            match pfx.evex_ll {
              2 => { mem_write512(a, read_zmm(src)); Ok() },
              1 => { mem_write256(a, read_ymm(src)); Ok() },
              _ => { mem_write128(a, read_xmm(src)); Ok() },
            }
          },
        },
      MP_66 => // VMOVUPD store
        match rm {
          RM_reg(_) => {
            let dst = evex_rm_reg_idx(modrm, pfx);
            match pfx.evex_ll {
              2 => {
                let masked = apply_writemask_pd_zmm(read_zmm(src), read_zmm(dst), evex_get_mask8(pfx), pfx.evex_z);
                write_zmm(dst, masked); Ok()
              },
              1 => { write_ymm(dst, read_ymm(src)); Ok() },
              _ => { write_xmm(dst, read_xmm(src)); Ok() },
            }
          },
          RM_mem(addr) => {
            let a = fixup_addr(addr);
            match pfx.evex_ll {
              2 => { mem_write512(a, read_zmm(src)); Ok() },
              1 => { mem_write256(a, read_ymm(src)); Ok() },
              _ => { mem_write128(a, read_xmm(src)); Ok() },
            }
          },
        },
      MP_F3 => { // VMOVSS (scalar f32 store/move, EVEX)
        // Memory: m32 = xmm1[31:0]
        // Register: xmm1{k1}{z} = xmm2[127:32] @ xmm3[31:0]
        match rm {
          RM_mem(addr) => { mem_write32(fixup_addr(addr), read_xmm(src)[31..0]); Ok() },
          RM_reg(_) => {
            let dst = evex_rm_reg_idx(modrm, pfx);
            let src1 = read_xmm(pfx.evex_vvvvv);
            let src2 : dword = read_xmm(src)[31..0];
            write_xmm(dst, src1[127..32] @ src2); Ok()
          },
        }
      },
      MP_F2 => { // VMOVSD (scalar f64 store/move, EVEX)
        // Memory: m64 = xmm1[63:0]
        // Register: xmm1{k1}{z} = xmm2[127:64] @ xmm3[63:0]
        match rm {
          RM_mem(addr) => { mem_write64(fixup_addr(addr), read_xmm(src)[63..0]); Ok() },
          RM_reg(_) => {
            let dst = evex_rm_reg_idx(modrm, pfx);
            let src1 = read_xmm(pfx.evex_vvvvv);
            let src2 : qword = read_xmm(src)[63..0];
            write_xmm(dst, src1[127..64] @ src2); Ok()
          },
        }
      },
    }
  },

  // 0F 12: VMOVLPS (NP,mem) / VMOVHLPS (NP,reg) / VMOVLPD (66,mem) / VMOVSLDUP (F3) / VMOVDDUP (F2)
  // 0F 12: VMOVLPS (NP,mem) / VMOVHLPS (NP,reg) / VMOVLPD (66,mem) / VMOVSLDUP (F3) / VMOVDDUP (F2)
  18 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    match mp {
      MP_NONE => { // VMOVLPS (mem) or VMOVHLPS (reg) — XMM only
        if pfx.evex_ll != 0 then {
          raise_UD()
        } else {
          let rm = decode_rm_evex(modrm, pfx, 8);
          match rm {
            RM_reg(_) => { // VMOVHLPS xmm1, xmm2, xmm3
              let src1 = read_xmm(pfx.evex_vvvvv);
              let src2 = read_xmm(evex_rm_reg_idx(modrm, pfx));
              let result : xmmword = src1[127..64] @ src2[127..64];
              write_xmm(dst, result); Ok()
            },
            RM_mem(addr) => { // VMOVLPS xmm2, xmm1, m64
              let src1 = read_xmm(pfx.evex_vvvvv);
              let m64val = mem_read64(fixup_addr(addr));
              let result : xmmword = src1[127..64] @ m64val;
              write_xmm(dst, result); Ok()
            },
          }
        }
      },
      MP_66 => { // VMOVLPD xmm2, xmm1, m64 — XMM only
        if pfx.evex_ll != 0 then {
          raise_UD()
        } else {
          let rm = decode_rm_evex(modrm, pfx, 8);
          match rm {
            RM_reg(_) => raise_UD(),
            RM_mem(addr) => {
              let src1 = read_xmm(pfx.evex_vvvvv);
              let m64val = mem_read64(fixup_addr(addr));
              let result : xmmword = src1[127..64] @ m64val;
              write_xmm(dst, result); Ok()
            },
          }
        }
      },
      MP_F3 => { // VMOVSLDUP
        let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_movsldup_512(evex_src_zmm(modrm, rm, pfx))); Ok() },
          1 => { write_ymm(dst, avx_movsldup_256(evex_src_ymm(modrm, rm, pfx))); Ok() },
          _ => { write_xmm(dst, avx_movsldup_128(evex_src_xmm(modrm, rm, pfx))); Ok() },
        }
      },
      MP_F2 => { // VMOVDDUP
        let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_movddup_512(evex_src_zmm(modrm, rm, pfx))); Ok() },
          1 => { write_ymm(dst, avx_movddup_256(evex_src_ymm(modrm, rm, pfx))); Ok() },
          _ => {
            // 128-bit MOVDDUP: source is xmm or m64
            let src : xmmword = match rm {
              RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx)),
              RM_mem(addr) => {
                let v = mem_read64(fixup_addr(addr));
                v @ v
              },
            };
            write_xmm(dst, avx_movddup_128(src)); Ok()
          },
        }
      },
    }
  },

  // 0F 13: VMOVLPS (NP,store) / VMOVLPD (66,store) — XMM only, m64
  // 0F 13: VMOVLPS (NP,store) / VMOVLPD (66,store) — XMM only, m64
  19 => {
    let modrm = fetch_byte();
    if pfx.evex_ll != 0 then {
      raise_UD()
    } else {
      let rm = decode_rm_evex(modrm, pfx, 8);
      match rm {
        RM_reg(_) => raise_UD(),
        RM_mem(addr) => {
          let src = read_xmm(evex_reg_idx(modrm, pfx));
          mem_write64(fixup_addr(addr), src[63..0]); Ok()
        },
      }
    }
  },

  // 0F 14: VUNPCKLPS (NP,W0) / VUNPCKLPD (66,W1)
  // 0F 14: VUNPCKLPS (NP,W0) / VUNPCKLPD (66,W1)
  20 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
    let src1_idx = pfx.evex_vvvvv;
    match mp {
      MP_NONE => { // VUNPCKLPS (W0)
        match pfx.evex_ll {
          2 => {
            let src1 = read_zmm(src1_idx);
            let src2 : zmmword = if pfx.evex_b & is_mem
              then broadcast_f32_zmm(evex_src_m32(modrm, rm, pfx))
              else evex_src_zmm(modrm, rm, pfx);
            write_zmm(dst, avx_unpcklps_512(src1, src2)); Ok()
          },
          1 => {
            let src1 = read_ymm(src1_idx);
            let src2 = evex_src_ymm(modrm, rm, pfx);
            write_ymm(dst, avx_unpcklps_256(src1, src2)); Ok()
          },
          _ => {
            let src1 = read_xmm(src1_idx);
            let src2 = evex_src_xmm(modrm, rm, pfx);
            write_xmm(dst, avx_unpcklps_128(src1, src2)); Ok()
          },
        }
      },
      MP_66 => { // VUNPCKLPD (W1)
        match pfx.evex_ll {
          2 => {
            let src1 = read_zmm(src1_idx);
            let src2 : zmmword = if pfx.evex_b & is_mem
              then broadcast_f64_zmm(evex_src_m64(modrm, rm, pfx))
              else evex_src_zmm(modrm, rm, pfx);
            write_zmm(dst, avx_unpcklpd_512(src1, src2)); Ok()
          },
          1 => {
            let src1 = read_ymm(src1_idx);
            let src2 = evex_src_ymm(modrm, rm, pfx);
            write_ymm(dst, avx_unpcklpd_256(src1, src2)); Ok()
          },
          _ => {
            let src1 = read_xmm(src1_idx);
            let src2 = evex_src_xmm(modrm, rm, pfx);
            write_xmm(dst, avx_unpcklpd_128(src1, src2)); Ok()
          },
        }
      },
      _ => raise_UD(),
    }
  },

  // 0F 15: VUNPCKHPS (NP,W0) / VUNPCKHPD (66,W1)
  // 0F 15: VUNPCKHPS (NP,W0) / VUNPCKHPD (66,W1)
  21 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
    let src1_idx = pfx.evex_vvvvv;
    match mp {
      MP_NONE => { // VUNPCKHPS (W0)
        match pfx.evex_ll {
          2 => {
            let src1 = read_zmm(src1_idx);
            let src2 : zmmword = if pfx.evex_b & is_mem
              then broadcast_f32_zmm(evex_src_m32(modrm, rm, pfx))
              else evex_src_zmm(modrm, rm, pfx);
            write_zmm(dst, avx_unpckhps_512(src1, src2)); Ok()
          },
          1 => {
            let src1 = read_ymm(src1_idx);
            let src2 = evex_src_ymm(modrm, rm, pfx);
            write_ymm(dst, avx_unpckhps_256(src1, src2)); Ok()
          },
          _ => {
            let src1 = read_xmm(src1_idx);
            let src2 = evex_src_xmm(modrm, rm, pfx);
            write_xmm(dst, avx_unpckhps_128(src1, src2)); Ok()
          },
        }
      },
      MP_66 => { // VUNPCKHPD (W1)
        match pfx.evex_ll {
          2 => {
            let src1 = read_zmm(src1_idx);
            let src2 : zmmword = if pfx.evex_b & is_mem
              then broadcast_f64_zmm(evex_src_m64(modrm, rm, pfx))
              else evex_src_zmm(modrm, rm, pfx);
            write_zmm(dst, avx_unpckhpd_512(src1, src2)); Ok()
          },
          1 => {
            let src1 = read_ymm(src1_idx);
            let src2 = evex_src_ymm(modrm, rm, pfx);
            write_ymm(dst, avx_unpckhpd_256(src1, src2)); Ok()
          },
          _ => {
            let src1 = read_xmm(src1_idx);
            let src2 = evex_src_xmm(modrm, rm, pfx);
            write_xmm(dst, avx_unpckhpd_128(src1, src2)); Ok()
          },
        }
      },
      _ => raise_UD(),
    }
  },

  // 0F 16: VMOVHPS (NP,mem) / VMOVLHPS (NP,reg) / VMOVHPD (66,mem) / VMOVSHDUP (F3)
  // 0F 16: VMOVHPS (NP,mem) / VMOVLHPS (NP,reg) / VMOVHPD (66,mem) / VMOVSHDUP (F3)
  22 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    match mp {
      MP_NONE => { // VMOVHPS (mem) or VMOVLHPS (reg) — XMM only
        if pfx.evex_ll != 0 then {
          raise_UD()
        } else {
          let rm = decode_rm_evex(modrm, pfx, 8);
          match rm {
            RM_reg(_) => { // VMOVLHPS xmm1, xmm2, xmm3
              let src1 = read_xmm(pfx.evex_vvvvv);
              let src2 = read_xmm(evex_rm_reg_idx(modrm, pfx));
              let result : xmmword = src2[63..0] @ src1[63..0];
              write_xmm(dst, result); Ok()
            },
            RM_mem(addr) => { // VMOVHPS xmm2, xmm1, m64
              let src1 = read_xmm(pfx.evex_vvvvv);
              let m64val = mem_read64(fixup_addr(addr));
              let result : xmmword = m64val @ src1[63..0];
              write_xmm(dst, result); Ok()
            },
          }
        }
      },
      MP_66 => { // VMOVHPD xmm2, xmm1, m64 — XMM only
        if pfx.evex_ll != 0 then {
          raise_UD()
        } else {
          let rm = decode_rm_evex(modrm, pfx, 8);
          match rm {
            RM_reg(_) => raise_UD(),
            RM_mem(addr) => {
              let src1 = read_xmm(pfx.evex_vvvvv);
              let m64val = mem_read64(fixup_addr(addr));
              let result : xmmword = m64val @ src1[63..0];
              write_xmm(dst, result); Ok()
            },
          }
        }
      },
      MP_F3 => { // VMOVSHDUP
        let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_movshdup_512(evex_src_zmm(modrm, rm, pfx))); Ok() },
          1 => { write_ymm(dst, avx_movshdup_256(evex_src_ymm(modrm, rm, pfx))); Ok() },
          _ => { write_xmm(dst, avx_movshdup_128(evex_src_xmm(modrm, rm, pfx))); Ok() },
        }
      },
      _ => raise_UD(),
    }
  },

  // 0F 17: VMOVHPS (NP,store) / VMOVHPD (66,store) — XMM only, m64
  // 0F 17: VMOVHPS (NP,store) / VMOVHPD (66,store) — XMM only, m64
  23 => {
    let modrm = fetch_byte();
    if pfx.evex_ll != 0 then {
      raise_UD()
    } else {
      let rm = decode_rm_evex(modrm, pfx, 8);
      match rm {
        RM_reg(_) => raise_UD(),
        RM_mem(addr) => {
          let src = read_xmm(evex_reg_idx(modrm, pfx));
          mem_write64(fixup_addr(addr), src[127..64]); Ok()
        },
      }
    }
  },

  // 0F 28: VMOVAPS/VMOVAPD (EVEX load)
  // 0F 28: VMOVAPS/VMOVAPD (EVEX load)
  40 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    match pfx.evex_ll {
      2 => {
        let src = evex_src_zmm(modrm, rm, pfx);
        let mask_val = if mp == MP_66 then evex_get_mask8(pfx) @ evex_get_mask8(pfx) else evex_get_mask16(pfx);
        if mp == MP_66 then {
          let masked = apply_writemask_pd_zmm(src, read_zmm(dst), evex_get_mask8(pfx), pfx.evex_z);
          write_zmm(dst, masked); Ok()
        } else {
          let masked = apply_writemask_ps_zmm(src, read_zmm(dst), evex_get_mask16(pfx), pfx.evex_z);
          write_zmm(dst, masked); Ok()
        }
      },
      1 => { write_ymm(dst, evex_src_ymm(modrm, rm, pfx)); Ok() },
      _ => { write_xmm(dst, evex_src_xmm(modrm, rm, pfx)); Ok() },
    }
  },

  // 0F 29: VMOVAPS/VMOVAPD (EVEX store)
  // 0F 29: VMOVAPS/VMOVAPD (EVEX store)
  41 => {
    let modrm = fetch_byte();
    let src = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    match rm {
      RM_reg(_) => {
        let dst = evex_rm_reg_idx(modrm, pfx);
        match pfx.evex_ll {
          2 => { write_zmm(dst, read_zmm(src)); Ok() },
          1 => { write_ymm(dst, read_ymm(src)); Ok() },
          _ => { write_xmm(dst, read_xmm(src)); Ok() },
        }
      },
      RM_mem(addr) => {
        let a = fixup_addr(addr);
        match pfx.evex_ll {
          2 => { mem_write512(a, read_zmm(src)); Ok() },
          1 => { mem_write256(a, read_ymm(src)); Ok() },
          _ => { mem_write128(a, read_xmm(src)); Ok() },
        }
      },
    }
  },

  // 0F 2A: VCVTSI2SS (F3) / VCVTSI2SD (F2) — scalar, GPR/mem to XMM
  // 0F 2A: VCVTSI2SS (F3) / VCVTSI2SD (F2) — scalar, GPR/mem to XMM
  42 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
    let os : OperandSize = if pfx.rex_w then OS64 else OS32;
    let src_val : qword = match rm {
      RM_reg(_) => read_gpr(modrm_rm_reg(modrm, pfx), os),
      RM_mem(addr) => match os {
        OS64 => mem_read64(fixup_addr(addr)),
        _    => zero_extend(mem_read32(fixup_addr(addr))),
      },
    };
    let src1 = read_xmm(pfx.evex_vvvvv);
    match mp {
      MP_F3 => { // VCVTSI2SS
        let result : dword = match os {
          OS64 => __int64_to_f32(src_val),
          _    => __int32_to_f32(src_val[31..0]),
        };
        var xmm : xmmword = src1;
        xmm[31..0] = result;
        write_xmm(dst, xmm); Ok()
      },
      MP_F2 => { // VCVTSI2SD
        let result : qword = match os {
          OS64 => __int64_to_f64(src_val),
          _    => __int32_to_f64(src_val[31..0]),
        };
        var xmm : xmmword = src1;
        xmm[63..0] = result;
        write_xmm(dst, xmm); Ok()
      },
      _ => raise_UD(),
    }
  },

  // 0F 2B: VMOVNTPS (NP) / VMOVNTPD (66) — non-temporal store
  // 0F 2B: VMOVNTPS (NP) / VMOVNTPD (66) — non-temporal store
  43 => {
    let modrm = fetch_byte();
    let src = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    match rm {
      RM_reg(_) => raise_UD(),
      RM_mem(addr) => {
        let a = fixup_addr(addr);
        match pfx.evex_ll {
          2 => { mem_write512(a, read_zmm(src)); Ok() },
          1 => { mem_write256(a, read_ymm(src)); Ok() },
          _ => { mem_write128(a, read_xmm(src)); Ok() },
        }
      },
    }
  },

  // 0F 2C: VCVTTSS2SI (F3) / VCVTTSD2SI (F2) — scalar, XMM/mem to GPR (truncate)
  // 0F 2C: VCVTTSS2SI (F3) / VCVTTSD2SI (F2) — scalar, XMM/mem to GPR (truncate)
  44 => {
    let modrm = fetch_byte();
    let dst_gpr = modrm_reg(modrm, pfx);
    let os : OperandSize = if pfx.rex_w then OS64 else OS32;
    match mp {
      MP_F3 => { // VCVTTSS2SI
        let rm = decode_rm_evex(modrm, pfx, 4);
        let src_f32 : dword = match rm {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
          RM_mem(addr) => mem_read32(fixup_addr(addr)),
        };
        match os {
          OS64 => write_gpr(dst_gpr, OS64, __f32_to_int64_trunc(src_f32)),
          _    => write_gpr(dst_gpr, OS32, zero_extend(__f32_to_int32_trunc(src_f32))),
        };
        Ok()
      },
      MP_F2 => { // VCVTTSD2SI
        let rm = decode_rm_evex(modrm, pfx, 8);
        let src_f64 : qword = match rm {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
          RM_mem(addr) => mem_read64(fixup_addr(addr)),
        };
        match os {
          OS64 => write_gpr(dst_gpr, OS64, __f64_to_int64_trunc(src_f64)),
          _    => write_gpr(dst_gpr, OS32, zero_extend(__f64_to_int32_trunc(src_f64))),
        };
        Ok()
      },
      _ => raise_UD(),
    }
  },

  // 0F 2D: VCVTSS2SI (F3) / VCVTSD2SI (F2) — scalar, XMM/mem to GPR (round)
  // 0F 2D: VCVTSS2SI (F3) / VCVTSD2SI (F2) — scalar, XMM/mem to GPR (round)
  45 => {
    let modrm = fetch_byte();
    let dst_gpr = modrm_reg(modrm, pfx);
    let os : OperandSize = if pfx.rex_w then OS64 else OS32;
    match mp {
      MP_F3 => { // VCVTSS2SI
        let rm = decode_rm_evex(modrm, pfx, 4);
        let src_f32 : dword = match rm {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
          RM_mem(addr) => mem_read32(fixup_addr(addr)),
        };
        match os {
          OS64 => write_gpr(dst_gpr, OS64, __f32_to_int64(src_f32)),
          _    => write_gpr(dst_gpr, OS32, zero_extend(__f32_to_int32(src_f32))),
        };
        Ok()
      },
      MP_F2 => { // VCVTSD2SI
        let rm = decode_rm_evex(modrm, pfx, 8);
        let src_f64 : qword = match rm {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
          RM_mem(addr) => mem_read64(fixup_addr(addr)),
        };
        match os {
          OS64 => write_gpr(dst_gpr, OS64, __f64_to_int64(src_f64)),
          _    => write_gpr(dst_gpr, OS32, zero_extend(__f64_to_int32(src_f64))),
        };
        Ok()
      },
      _ => raise_UD(),
    }
  },

  // 0F 2E: VUCOMISS (NP,W0) / VUCOMISD (66,W1) — compare scalars, set EFLAGS
  // 0F 2E: VUCOMISS (NP,W0) / VUCOMISD (66,W1) — compare scalars, set EFLAGS
  46 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    match mp {
      MP_NONE => { // VUCOMISS
        let rm = decode_rm_evex(modrm, pfx, 4);
        let src : xmmword = match rm {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx)),
          RM_mem(addr) => zero_extend(mem_read32(fixup_addr(addr))),
        };
        let a : dword = read_xmm(dst)[31..0];
        let b : dword = src[31..0];
        match __compare_ss(a, b) {
          FP_UNORDERED => { ZF = bitone;  PF = bitone;  CF = bitone;  },
          FP_GT        => { ZF = bitzero; PF = bitzero; CF = bitzero; },
          FP_LT        => { ZF = bitzero; PF = bitzero; CF = bitone;  },
          FP_EQ        => { ZF = bitone;  PF = bitzero; CF = bitzero; },
        };
        OF = bitzero; SF = bitzero; AF = bitzero;
        Ok()
      },
      MP_66 => { // VUCOMISD
        let rm = decode_rm_evex(modrm, pfx, 8);
        let src : xmmword = match rm {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx)),
          RM_mem(addr) => zero_extend(mem_read64(fixup_addr(addr))),
        };
        let a : qword = read_xmm(dst)[63..0];
        let b : qword = src[63..0];
        match __compare_sd(a, b) {
          FP_UNORDERED => { ZF = bitone;  PF = bitone;  CF = bitone;  },
          FP_GT        => { ZF = bitzero; PF = bitzero; CF = bitzero; },
          FP_LT        => { ZF = bitzero; PF = bitzero; CF = bitone;  },
          FP_EQ        => { ZF = bitone;  PF = bitzero; CF = bitzero; },
        };
        OF = bitzero; SF = bitzero; AF = bitzero;
        Ok()
      },
      _ => raise_UD(),
    }
  },

  // 0F 2F: VCOMISS (NP,W0) / VCOMISD (66,W1) — ordered compare scalars, set EFLAGS
  // 0F 2F: VCOMISS (NP,W0) / VCOMISD (66,W1) — ordered compare scalars, set EFLAGS
  47 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    match mp {
      MP_NONE => { // VCOMISS
        let rm = decode_rm_evex(modrm, pfx, 4);
        let src : xmmword = match rm {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx)),
          RM_mem(addr) => zero_extend(mem_read32(fixup_addr(addr))),
        };
        let a : dword = read_xmm(dst)[31..0];
        let b : dword = src[31..0];
        match __compare_ss(a, b) {
          FP_UNORDERED => { ZF = bitone;  PF = bitone;  CF = bitone;  },
          FP_GT        => { ZF = bitzero; PF = bitzero; CF = bitzero; },
          FP_LT        => { ZF = bitzero; PF = bitzero; CF = bitone;  },
          FP_EQ        => { ZF = bitone;  PF = bitzero; CF = bitzero; },
        };
        OF = bitzero; SF = bitzero; AF = bitzero;
        Ok()
      },
      MP_66 => { // VCOMISD
        let rm = decode_rm_evex(modrm, pfx, 8);
        let src : xmmword = match rm {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx)),
          RM_mem(addr) => zero_extend(mem_read64(fixup_addr(addr))),
        };
        let a : qword = read_xmm(dst)[63..0];
        let b : qword = src[63..0];
        match __compare_sd(a, b) {
          FP_UNORDERED => { ZF = bitone;  PF = bitone;  CF = bitone;  },
          FP_GT        => { ZF = bitzero; PF = bitzero; CF = bitzero; },
          FP_LT        => { ZF = bitzero; PF = bitzero; CF = bitone;  },
          FP_EQ        => { ZF = bitone;  PF = bitzero; CF = bitzero; },
        };
        OF = bitzero; SF = bitzero; AF = bitzero;
        Ok()
      },
      _ => raise_UD(),
    }
  },

  // 0F 58: VADDPS/VADDPD (EVEX) — supports {er} at 512-bit
  88 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
    let (eff_ll, saved_mxcsr) = evex_begin_rc(pfx, not_bool(is_mem));
    let result : ExecutionResult = match mp {
      MP_NONE => { // VADDPS
        match eff_ll {
          2 => {
            let src1 : zmmword = read_zmm(pfx.evex_vvvvv);
            let src2 : zmmword = if pfx.evex_b & is_mem
              then broadcast_f32_zmm(evex_src_m32(modrm, rm, pfx))
              else evex_src_zmm(modrm, rm, pfx);
            let result = vaddps_zmm(src1, src2);
            let masked = apply_writemask_ps_zmm(result, read_zmm(dst), evex_get_mask16(pfx), pfx.evex_z);
            write_zmm(dst, masked); Ok()
          },
          1 => {
            let src1 = read_ymm(pfx.evex_vvvvv);
            let src2 = evex_src_ymm(modrm, rm, pfx);
            let result = vaddps_ymm(src1, src2);
            write_ymm(dst, apply_writemask_ps_ymm(result, read_ymm(dst), evex_get_mask16(pfx), pfx.evex_z)); Ok()
          },
          _ => {
            let src1 = read_xmm(pfx.evex_vvvvv);
            let src2 = evex_src_xmm(modrm, rm, pfx);
            let result = vaddps_xmm(src1, src2);
            write_xmm(dst, apply_writemask_ps_xmm(result, read_xmm(dst), evex_get_mask16(pfx), pfx.evex_z)); Ok()
          },
        }
      },
      MP_66 => { // VADDPD
        match eff_ll {
          2 => {
            let src1 : zmmword = read_zmm(pfx.evex_vvvvv);
            let src2 : zmmword = if pfx.evex_b & is_mem
              then broadcast_f64_zmm(evex_src_m64(modrm, rm, pfx))
              else evex_src_zmm(modrm, rm, pfx);
            let result = vaddpd_zmm(src1, src2);
            let masked = apply_writemask_pd_zmm(result, read_zmm(dst), evex_get_mask8(pfx), pfx.evex_z);
            write_zmm(dst, masked); Ok()
          },
          1 => {
            let src1 = read_ymm(pfx.evex_vvvvv);
            let src2 = evex_src_ymm(modrm, rm, pfx);
            write_ymm(dst, vaddpd_ymm(src1, src2)); Ok()
          },
          _ => {
            let src1 = read_xmm(pfx.evex_vvvvv);
            let src2 = evex_src_xmm(modrm, rm, pfx);
            write_xmm(dst, vaddpd_xmm(src1, src2)); Ok()
          },
        }
      },
      MP_F3 => { // VADDSS (scalar f32, EVEX) — supports {er}
        let src1 = read_xmm(pfx.evex_vvvvv);
        let src2_f32 : dword = match rm {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
          RM_mem(addr) => mem_read32(fixup_addr(addr)),
        };
        write_xmm(dst, src1[127..32] @ __f32_add(src1[31..0], src2_f32)); Ok()
      },
      MP_F2 => { // VADDSD (scalar f64, EVEX) — supports {er}
        let src1 = read_xmm(pfx.evex_vvvvv);
        let src2_f64 : qword = match rm {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
          RM_mem(addr) => mem_read64(fixup_addr(addr)),
        };
        write_xmm(dst, src1[127..64] @ __f64_add(src1[63..0], src2_f64)); Ok()
      },
    };
    evex_end_rc(saved_mxcsr);
    result
  },

  // 0F 59: VMULPS/VMULPD (EVEX) — supports {er} at 512-bit
  89 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
    let (eff_ll, saved_mxcsr) = evex_begin_rc(pfx, not_bool(is_mem));
    let result : ExecutionResult = match mp {
      MP_NONE => match eff_ll {
        2 => {
          let src1 : zmmword = read_zmm(pfx.evex_vvvvv);
          let src2 : zmmword = if pfx.evex_b & is_mem
            then broadcast_f32_zmm(evex_src_m32(modrm, rm, pfx))
            else evex_src_zmm(modrm, rm, pfx);
          let result = vmulps_zmm(src1, src2);
          let masked = apply_writemask_ps_zmm(result, read_zmm(dst), evex_get_mask16(pfx), pfx.evex_z);
          write_zmm(dst, masked); Ok()
        },
        1 => { write_ymm(dst, vmulps_ymm(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok() },
        _ => { write_xmm(dst, vmulps_xmm(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok() },
      },
      MP_66 => match eff_ll {
        2 => {
          let src1 : zmmword = read_zmm(pfx.evex_vvvvv);
          let src2 : zmmword = if pfx.evex_b & is_mem
            then broadcast_f64_zmm(evex_src_m64(modrm, rm, pfx))
            else evex_src_zmm(modrm, rm, pfx);
          let result = vmulpd_zmm(src1, src2);
          let masked = apply_writemask_pd_zmm(result, read_zmm(dst), evex_get_mask8(pfx), pfx.evex_z);
          write_zmm(dst, masked); Ok()
        },
        1 => { write_ymm(dst, vmulpd_ymm(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok() },
        _ => { write_xmm(dst, vmulpd_xmm(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok() },
      },
      MP_F3 => { // VMULSS (scalar f32, EVEX) — supports {er}
        let src1 = read_xmm(pfx.evex_vvvvv);
        let src2_f32 : dword = match rm {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
          RM_mem(addr) => mem_read32(fixup_addr(addr)),
        };
        write_xmm(dst, src1[127..32] @ __f32_mul(src1[31..0], src2_f32)); Ok()
      },
      MP_F2 => { // VMULSD (scalar f64, EVEX) — supports {er}
        let src1 = read_xmm(pfx.evex_vvvvv);
        let src2_f64 : qword = match rm {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
          RM_mem(addr) => mem_read64(fixup_addr(addr)),
        };
        write_xmm(dst, src1[127..64] @ __f64_mul(src1[63..0], src2_f64)); Ok()
      },
    };
    evex_end_rc(saved_mxcsr);
    result
  },

  // 0F 5A: VCVTPS2PD (NP,W0) / VCVTPD2PS (66,W1) / VCVTSS2SD (F3) / VCVTSD2SS (F2)
  // 0F 5A: VCVTPS2PD (NP,W0) / VCVTPD2PS (66,W1) / VCVTSS2SD (F3) / VCVTSD2SS (F2)
  90 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    match mp {
      MP_NONE => { // VCVTPS2PD: f32→f64, source is half-width
        match pfx.evex_ll {
          2 => { // ZMM: 8 f32 (YMM) → 8 f64 (ZMM)
            let rm = decode_rm_evex(modrm, pfx, 32);
            let src = evex_src_ymm(modrm, rm, pfx);
            write_zmm(dst, avx_cvtps2pd_8(src)); Ok()
          },
          1 => { // YMM: 4 f32 (XMM) → 4 f64 (YMM)
            let rm = decode_rm_evex(modrm, pfx, 16);
            let src = evex_src_xmm(modrm, rm, pfx);
            write_ymm(dst, avx_cvtps2pd_4(src)); Ok()
          },
          _ => { // XMM: 2 f32 (m64/xmm low) → 2 f64 (XMM)
            let rm = decode_rm_evex(modrm, pfx, 8);
            let src : qword = match rm {
              RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
              RM_mem(addr) => mem_read64(fixup_addr(addr)),
            };
            write_xmm(dst, avx_cvtps2pd_2(src)); Ok()
          },
        }
      },
      MP_66 => { // VCVTPD2PS: f64→f32, result is half-width
        match pfx.evex_ll {
          2 => { // ZMM→YMM: 8 f64 → 8 f32
            let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
            let src = evex_src_zmm(modrm, rm, pfx);
            write_ymm(dst, avx_cvtpd2ps_8(src)); Ok()
          },
          1 => { // YMM→XMM: 4 f64 → 4 f32
            let rm = decode_rm_evex(modrm, pfx, 32);
            let src = evex_src_ymm(modrm, rm, pfx);
            write_xmm(dst, avx_cvtpd2ps_4(src)); Ok()
          },
          _ => { // XMM→XMM low: 2 f64 → 2 f32
            let rm = decode_rm_evex(modrm, pfx, 16);
            let src = evex_src_xmm(modrm, rm, pfx);
            let result : qword = avx_cvtpd2ps_2(src);
            write_xmm(dst, zeros(64) @ result); Ok()
          },
        }
      },
      MP_F3 => { // VCVTSS2SD: scalar f32→f64
        let rm = decode_rm_evex(modrm, pfx, 4);
        let src1 = read_xmm(pfx.evex_vvvvv);
        let src_f32 : dword = match rm {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
          RM_mem(addr) => mem_read32(fixup_addr(addr)),
        };
        var result : xmmword = src1;
        result[63..0] = __f32_to_f64(src_f32);
        write_xmm(dst, result); Ok()
      },
      MP_F2 => { // VCVTSD2SS: scalar f64→f32
        let rm = decode_rm_evex(modrm, pfx, 8);
        let src1 = read_xmm(pfx.evex_vvvvv);
        let src_f64 : qword = match rm {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
          RM_mem(addr) => mem_read64(fixup_addr(addr)),
        };
        var result : xmmword = src1;
        result[31..0] = __f64_to_f32(src_f64);
        write_xmm(dst, result); Ok()
      },
    }
  },

  // 0F 5B: VCVTDQ2PS (NP,W0) / VCVTQQ2PS (NP,W1) / VCVTPS2DQ (66,W0) / VCVTTPS2DQ (F3,W0)
  // VCVTDQ2PS, VCVTQQ2PS, VCVTPS2DQ support {er} at 512-bit
  91 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
    let (eff_ll, saved_mxcsr) = evex_begin_rc(pfx, not_bool(is_mem));
    let result : ExecutionResult = match mp {
      MP_NONE => {
        if pfx.rex_w then { // VCVTQQ2PS: i64→f32 (narrowing, result half-width)
          match eff_ll {
            2 => { write_ymm(dst, avx_cvtqq2ps_8(evex_src_zmm(modrm, rm, pfx))); Ok() },
            1 => { write_xmm(dst, avx_cvtqq2ps_4(evex_src_ymm(modrm, rm, pfx))); Ok() },
            _ => { write_xmm(dst, zero_extend(avx_cvtqq2ps_2(evex_src_xmm(modrm, rm, pfx)))); Ok() },
          }
        } else { // VCVTDQ2PS: i32→f32
          match eff_ll {
            2 => { write_zmm(dst, avx_cvtdq2ps_512(evex_src_zmm(modrm, rm, pfx))); Ok() },
            1 => { write_ymm(dst, avx_cvtdq2ps_256(evex_src_ymm(modrm, rm, pfx))); Ok() },
            _ => { write_xmm(dst, avx_cvtdq2ps_128(evex_src_xmm(modrm, rm, pfx))); Ok() },
          }
        }
      },
      MP_66 => { // VCVTPS2DQ
        match eff_ll {
          2 => { write_zmm(dst, avx_cvtps2dq_512(evex_src_zmm(modrm, rm, pfx))); Ok() },
          1 => { write_ymm(dst, avx_cvtps2dq_256(evex_src_ymm(modrm, rm, pfx))); Ok() },
          _ => { write_xmm(dst, avx_cvtps2dq_128(evex_src_xmm(modrm, rm, pfx))); Ok() },
        }
      },
      MP_F3 => { // VCVTTPS2DQ (truncation — no {er} but no harm from the wrapper)
        match eff_ll {
          2 => { write_zmm(dst, avx_cvttps2dq_512(evex_src_zmm(modrm, rm, pfx))); Ok() },
          1 => { write_ymm(dst, avx_cvttps2dq_256(evex_src_ymm(modrm, rm, pfx))); Ok() },
          _ => { write_xmm(dst, avx_cvttps2dq_128(evex_src_xmm(modrm, rm, pfx))); Ok() },
        }
      },
      _ => raise_UD(),
    };
    evex_end_rc(saved_mxcsr);
    result
  },

  // 0F 5C: VSUBPS/VSUBPD (EVEX) — supports {er} at 512-bit
  92 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
    let (eff_ll, saved_mxcsr) = evex_begin_rc(pfx, not_bool(is_mem));
    let result : ExecutionResult = match mp {
      MP_NONE => match eff_ll {
        2 => {
          let src1 : zmmword = read_zmm(pfx.evex_vvvvv);
          let src2 : zmmword = if pfx.evex_b & is_mem
            then broadcast_f32_zmm(evex_src_m32(modrm, rm, pfx))
            else evex_src_zmm(modrm, rm, pfx);
          let result = vsubps_zmm(src1, src2);
          let masked = apply_writemask_ps_zmm(result, read_zmm(dst), evex_get_mask16(pfx), pfx.evex_z);
          write_zmm(dst, masked); Ok()
        },
        1 => { write_ymm(dst, vsubps_ymm(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok() },
        _ => { write_xmm(dst, vsubps_xmm(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok() },
      },
      MP_66 => match eff_ll {
        2 => {
          let src1 : zmmword = read_zmm(pfx.evex_vvvvv);
          let src2 : zmmword = if pfx.evex_b & is_mem
            then broadcast_f64_zmm(evex_src_m64(modrm, rm, pfx))
            else evex_src_zmm(modrm, rm, pfx);
          let result = vsubpd_zmm(src1, src2);
          let masked = apply_writemask_pd_zmm(result, read_zmm(dst), evex_get_mask8(pfx), pfx.evex_z);
          write_zmm(dst, masked); Ok()
        },
        1 => { write_ymm(dst, vsubpd_ymm(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok() },
        _ => { write_xmm(dst, vsubpd_xmm(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok() },
      },
      MP_F3 => { // VSUBSS (scalar f32, EVEX) — supports {er}
        let src1 = read_xmm(pfx.evex_vvvvv);
        let src2_f32 : dword = match rm {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
          RM_mem(addr) => mem_read32(fixup_addr(addr)),
        };
        write_xmm(dst, src1[127..32] @ __f32_sub(src1[31..0], src2_f32)); Ok()
      },
      MP_F2 => { // VSUBSD (scalar f64, EVEX) — supports {er}
        let src1 = read_xmm(pfx.evex_vvvvv);
        let src2_f64 : qword = match rm {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
          RM_mem(addr) => mem_read64(fixup_addr(addr)),
        };
        write_xmm(dst, src1[127..64] @ __f64_sub(src1[63..0], src2_f64)); Ok()
      },
    };
    evex_end_rc(saved_mxcsr);
    result
  },

  // 0F 57: VXORPS / 0F 54: VANDPS / 0F 55: VANDNPS / 0F 56: VORPS (EVEX bitwise)
  op if 84 <= op & op <= 87 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    match pfx.evex_ll {
      2 => {
        let src1 : zmmword = read_zmm(pfx.evex_vvvvv);
        let src2 : zmmword = evex_src_zmm(modrm, rm, pfx);
        let result : zmmword = match op {
          84 => src1 & src2,
          85 => ~(src1) & src2,
          86 => src1 | src2,
          _  => xor_vec(src1, src2),
        };
        write_zmm(dst, result); Ok()
      },
      1 => {
        let src1 : ymmword = read_ymm(pfx.evex_vvvvv);
        let src2 : ymmword = evex_src_ymm(modrm, rm, pfx);
        let result : ymmword = match op {
          84 => src1 & src2,
          85 => ~(src1) & src2,
          86 => src1 | src2,
          _  => xor_vec(src1, src2),
        };
        write_ymm(dst, result); Ok()
      },
      _ => {
        let src1 : xmmword = read_xmm(pfx.evex_vvvvv);
        let src2 : xmmword = evex_src_xmm(modrm, rm, pfx);
        let result : xmmword = match op {
          84 => src1 & src2,
          85 => ~(src1) & src2,
          86 => src1 | src2,
          _  => xor_vec(src1, src2),
        };
        write_xmm(dst, result); Ok()
      },
    }
  },

  // 0F 78: VCVTTPS2UDQ (NP,W0) / VCVTTPD2UDQ (NP,W1) / VCVTTSS2USI (F3) / VCVTTSD2USI (F2)
  //        / VCVTTPS2UQQ (66,W0) / VCVTTPD2UQQ (66,W1)
  // 0F 78: VCVTTPS2UDQ (NP,W0) / VCVTTPD2UDQ (NP,W1) / VCVTTSS2USI (F3) / VCVTTSD2USI (F2)
  //        / VCVTTPS2UQQ (66,W0) / VCVTTPD2UQQ (66,W1)
  120 => {
    let modrm = fetch_byte();
    match mp {
      MP_NONE => { // NP,W0=VCVTTPS2UDQ, NP,W1=VCVTTPD2UDQ
        let dst = evex_reg_idx(modrm, pfx);
        let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
        if pfx.rex_w then { // VCVTTPD2UDQ: f64→u32 trunc (narrowing)
          match pfx.evex_ll {
            2 => {
              let src = evex_src_zmm(modrm, rm, pfx);
              write_ymm(dst, avx_cvttpd2udq_8(src)); Ok()
            },
            1 => {
              let src = evex_src_ymm(modrm, rm, pfx);
              write_xmm(dst, avx_cvttpd2udq_4(src)); Ok()
            },
            _ => {
              let src = evex_src_xmm(modrm, rm, pfx);
              write_xmm(dst, zero_extend(avx_cvttpd2udq_2(src))); Ok()
            },
          }
        } else { // VCVTTPS2UDQ: f32→u32 trunc
          match pfx.evex_ll {
            2 => { write_zmm(dst, avx_cvttps2udq_512(evex_src_zmm(modrm, rm, pfx))); Ok() },
            1 => { write_ymm(dst, avx_cvttps2udq_256(evex_src_ymm(modrm, rm, pfx))); Ok() },
            _ => { write_xmm(dst, avx_cvttps2udq_128(evex_src_xmm(modrm, rm, pfx))); Ok() },
          }
        }
      },
      MP_F3 => { // VCVTTSS2USI: scalar f32→unsigned GPR trunc
        let dst_gpr = modrm_rm_reg(modrm, pfx);
        let rm2 = decode_rm_evex(modrm, pfx, 4);
        let src_f32 : dword = match rm2 {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
          RM_mem(addr) => mem_read32(fixup_addr(addr)),
        };
        let os = if pfx.rex_w then OS64 else OS32;
        match os {
          OS64 => write_gpr(dst_gpr, OS64, __f32_to_uint64_trunc(src_f32)),
          _    => write_gpr(dst_gpr, OS32, zero_extend(__f32_to_uint32_trunc(src_f32))),
        };
        Ok()
      },
      MP_F2 => { // VCVTTSD2USI: scalar f64→unsigned GPR trunc
        let dst_gpr = modrm_rm_reg(modrm, pfx);
        let rm2 = decode_rm_evex(modrm, pfx, 8);
        let src_f64 : qword = match rm2 {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
          RM_mem(addr) => mem_read64(fixup_addr(addr)),
        };
        let os = if pfx.rex_w then OS64 else OS32;
        match os {
          OS64 => write_gpr(dst_gpr, OS64, __f64_to_uint64_trunc(src_f64)),
          _    => write_gpr(dst_gpr, OS32, zero_extend(__f64_to_uint32_trunc(src_f64))),
        };
        Ok()
      },
      MP_66 => { // VCVTTPS2UQQ (W0) / VCVTTPD2UQQ (W1)
        let dst = evex_reg_idx(modrm, pfx);
        let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
        if pfx.rex_w then { // VCVTTPD2UQQ: f64→u64 trunc
          match pfx.evex_ll {
            2 => { write_zmm(dst, avx_cvttpd2uqq_512(evex_src_zmm(modrm, rm, pfx))); Ok() },
            1 => { write_ymm(dst, avx_cvttpd2uqq_256(evex_src_ymm(modrm, rm, pfx))); Ok() },
            _ => { write_xmm(dst, avx_cvttpd2uqq_128(evex_src_xmm(modrm, rm, pfx))); Ok() },
          }
        } else { // VCVTTPS2UQQ: f32→u64 trunc (widening)
          match pfx.evex_ll {
            2 => { write_zmm(dst, avx_cvttps2uqq_8(evex_src_ymm(modrm, rm, pfx))); Ok() },
            1 => { write_ymm(dst, avx_cvttps2uqq_4(evex_src_xmm(modrm, rm, pfx))); Ok() },
            _ => { write_xmm(dst, avx_cvttps2uqq_2(evex_src_xmm(modrm, rm, pfx)[63..0])); Ok() },
          }
        }
      },
    }
  },

  // 0F 79: VCVTPS2UDQ (NP,W0) / VCVTPD2UDQ (NP,W1) / VCVTSS2USI (F3) / VCVTSD2USI (F2)
  //        / VCVTPS2UQQ (66,W0) / VCVTPD2UQQ (66,W1)
  // 0F 79: VCVTPS2UDQ (NP,W0) / VCVTPD2UDQ (NP,W1) / VCVTSS2USI (F3) / VCVTSD2USI (F2)
  //        / VCVTPS2UQQ (66,W0) / VCVTPD2UQQ (66,W1)
  121 => {
    let modrm = fetch_byte();
    match mp {
      MP_NONE => { // NP,W0=VCVTPS2UDQ, NP,W1=VCVTPD2UDQ
        let dst = evex_reg_idx(modrm, pfx);
        let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
        if pfx.rex_w then { // VCVTPD2UDQ: f64→u32 round (narrowing)
          match pfx.evex_ll {
            2 => { write_ymm(dst, avx_cvtpd2udq_8(evex_src_zmm(modrm, rm, pfx))); Ok() },
            1 => { write_xmm(dst, avx_cvtpd2udq_4(evex_src_ymm(modrm, rm, pfx))); Ok() },
            _ => { write_xmm(dst, zero_extend(avx_cvtpd2udq_2(evex_src_xmm(modrm, rm, pfx)))); Ok() },
          }
        } else { // VCVTPS2UDQ: f32→u32 round
          match pfx.evex_ll {
            2 => { write_zmm(dst, avx_cvtps2udq_512(evex_src_zmm(modrm, rm, pfx))); Ok() },
            1 => { write_ymm(dst, avx_cvtps2udq_256(evex_src_ymm(modrm, rm, pfx))); Ok() },
            _ => { write_xmm(dst, avx_cvtps2udq_128(evex_src_xmm(modrm, rm, pfx))); Ok() },
          }
        }
      },
      MP_F3 => { // VCVTSS2USI: scalar f32→unsigned GPR round
        let dst_gpr = modrm_rm_reg(modrm, pfx);
        let rm2 = decode_rm_evex(modrm, pfx, 4);
        let src_f32 : dword = match rm2 {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
          RM_mem(addr) => mem_read32(fixup_addr(addr)),
        };
        let os = if pfx.rex_w then OS64 else OS32;
        match os {
          OS64 => write_gpr(dst_gpr, OS64, __f32_to_uint64(src_f32)),
          _    => write_gpr(dst_gpr, OS32, zero_extend(__f32_to_uint32(src_f32))),
        };
        Ok()
      },
      MP_F2 => { // VCVTSD2USI: scalar f64→unsigned GPR round
        let dst_gpr = modrm_rm_reg(modrm, pfx);
        let rm2 = decode_rm_evex(modrm, pfx, 8);
        let src_f64 : qword = match rm2 {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
          RM_mem(addr) => mem_read64(fixup_addr(addr)),
        };
        let os = if pfx.rex_w then OS64 else OS32;
        match os {
          OS64 => write_gpr(dst_gpr, OS64, __f64_to_uint64(src_f64)),
          _    => write_gpr(dst_gpr, OS32, zero_extend(__f64_to_uint32(src_f64))),
        };
        Ok()
      },
      MP_66 => { // VCVTPS2UQQ (W0) / VCVTPD2UQQ (W1)
        let dst = evex_reg_idx(modrm, pfx);
        let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
        if pfx.rex_w then { // VCVTPD2UQQ: f64→u64 round
          match pfx.evex_ll {
            2 => { write_zmm(dst, avx_cvtpd2uqq_512(evex_src_zmm(modrm, rm, pfx))); Ok() },
            1 => { write_ymm(dst, avx_cvtpd2uqq_256(evex_src_ymm(modrm, rm, pfx))); Ok() },
            _ => { write_xmm(dst, avx_cvtpd2uqq_128(evex_src_xmm(modrm, rm, pfx))); Ok() },
          }
        } else { // VCVTPS2UQQ: f32→u64 round (widening)
          match pfx.evex_ll {
            2 => { write_zmm(dst, avx_cvtps2uqq_8(evex_src_ymm(modrm, rm, pfx))); Ok() },
            1 => { write_ymm(dst, avx_cvtps2uqq_4(evex_src_xmm(modrm, rm, pfx))); Ok() },
            _ => { write_xmm(dst, avx_cvtps2uqq_2(evex_src_xmm(modrm, rm, pfx)[63..0])); Ok() },
          }
        }
      },
    }
  },

  // 0F 7A: VCVTTPS2QQ (66,W0) / VCVTTPD2QQ (66,W1) / VCVTUDQ2PS (F2,W0) / VCVTUQQ2PS (F2,W1)
  //        / VCVTUDQ2PD (F3,W0) / VCVTUQQ2PD (F3,W1)
  // 0F 7A: VCVTTPS2QQ (66,W0) / VCVTTPD2QQ (66,W1) / VCVTUDQ2PS (F2,W0) / VCVTUQQ2PS (F2,W1)
  //        / VCVTUDQ2PD (F3,W0) / VCVTUQQ2PD (F3,W1)
  122 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    match mp {
      MP_66 => { // VCVTTPS2QQ (W0) / VCVTTPD2QQ (W1)
        if pfx.rex_w then { // VCVTTPD2QQ: f64→i64 trunc
          match pfx.evex_ll {
            2 => { write_zmm(dst, avx_cvttpd2qq_512(evex_src_zmm(modrm, rm, pfx))); Ok() },
            1 => { write_ymm(dst, avx_cvttpd2qq_256(evex_src_ymm(modrm, rm, pfx))); Ok() },
            _ => { write_xmm(dst, avx_cvttpd2qq_128(evex_src_xmm(modrm, rm, pfx))); Ok() },
          }
        } else { // VCVTTPS2QQ: f32→i64 trunc (widening)
          match pfx.evex_ll {
            2 => { write_zmm(dst, avx_cvttps2qq_8(evex_src_ymm(modrm, rm, pfx))); Ok() },
            1 => { write_ymm(dst, avx_cvttps2qq_4(evex_src_xmm(modrm, rm, pfx))); Ok() },
            _ => { write_xmm(dst, avx_cvttps2qq_2(evex_src_xmm(modrm, rm, pfx)[63..0])); Ok() },
          }
        }
      },
      MP_F2 => { // VCVTUDQ2PS (W0) / VCVTUQQ2PS (W1)
        if pfx.rex_w then { // VCVTUQQ2PS: u64→f32 (narrowing)
          match pfx.evex_ll {
            2 => { write_ymm(dst, avx_cvtuqq2ps_8(evex_src_zmm(modrm, rm, pfx))); Ok() },
            1 => { write_xmm(dst, avx_cvtuqq2ps_4(evex_src_ymm(modrm, rm, pfx))); Ok() },
            _ => { write_xmm(dst, zero_extend(avx_cvtuqq2ps_2(evex_src_xmm(modrm, rm, pfx)))); Ok() },
          }
        } else { // VCVTUDQ2PS: u32→f32
          match pfx.evex_ll {
            2 => { write_zmm(dst, avx_cvtudq2ps_512(evex_src_zmm(modrm, rm, pfx))); Ok() },
            1 => { write_ymm(dst, avx_cvtudq2ps_256(evex_src_ymm(modrm, rm, pfx))); Ok() },
            _ => { write_xmm(dst, avx_cvtudq2ps_128(evex_src_xmm(modrm, rm, pfx))); Ok() },
          }
        }
      },
      MP_F3 => { // VCVTUDQ2PD (W0) / VCVTUQQ2PD (W1)
        if pfx.rex_w then { // VCVTUQQ2PD: u64→f64
          match pfx.evex_ll {
            2 => { write_zmm(dst, avx_cvtuqq2pd_512(evex_src_zmm(modrm, rm, pfx))); Ok() },
            1 => { write_ymm(dst, avx_cvtuqq2pd_256(evex_src_ymm(modrm, rm, pfx))); Ok() },
            _ => { write_xmm(dst, avx_cvtuqq2pd_128(evex_src_xmm(modrm, rm, pfx))); Ok() },
          }
        } else { // VCVTUDQ2PD: u32→f64 (widening)
          match pfx.evex_ll {
            2 => { write_zmm(dst, avx_cvtudq2pd_8(evex_src_ymm(modrm, rm, pfx))); Ok() },
            1 => { write_ymm(dst, avx_cvtudq2pd_4(evex_src_xmm(modrm, rm, pfx))); Ok() },
            _ => { write_xmm(dst, avx_cvtudq2pd_2(evex_src_xmm(modrm, rm, pfx)[63..0])); Ok() },
          }
        }
      },
      _ => raise_UD(),
    }
  },

  // 0F 7B: VCVTPS2QQ (66,W0) / VCVTPD2QQ (66,W1) / VCVTUSI2SS (F3) / VCVTUSI2SD (F2)
  // 0F 7B: VCVTPS2QQ (66,W0) / VCVTPD2QQ (66,W1) / VCVTUSI2SS (F3) / VCVTUSI2SD (F2)
  123 => {
    let modrm = fetch_byte();
    match mp {
      MP_66 => { // VCVTPS2QQ (W0) / VCVTPD2QQ (W1)
        let dst = evex_reg_idx(modrm, pfx);
        let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
        if pfx.rex_w then { // VCVTPD2QQ: f64→i64 round
          match pfx.evex_ll {
            2 => { write_zmm(dst, avx_cvtpd2qq_512(evex_src_zmm(modrm, rm, pfx))); Ok() },
            1 => { write_ymm(dst, avx_cvtpd2qq_256(evex_src_ymm(modrm, rm, pfx))); Ok() },
            _ => { write_xmm(dst, avx_cvtpd2qq_128(evex_src_xmm(modrm, rm, pfx))); Ok() },
          }
        } else { // VCVTPS2QQ: f32→i64 round (widening)
          match pfx.evex_ll {
            2 => { write_zmm(dst, avx_cvtps2qq_8(evex_src_ymm(modrm, rm, pfx))); Ok() },
            1 => { write_ymm(dst, avx_cvtps2qq_4(evex_src_xmm(modrm, rm, pfx))); Ok() },
            _ => { write_xmm(dst, avx_cvtps2qq_2(evex_src_xmm(modrm, rm, pfx)[63..0])); Ok() },
          }
        }
      },
      MP_F3 => { // VCVTUSI2SS: scalar u32/u64→f32
        let dst_xmm = evex_reg_idx(modrm, pfx);
        let rm2 = decode_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
        let src1 = read_xmm(pfx.evex_vvvvv);
        let result_f32 : dword = if pfx.rex_w then {
          let v : qword = match rm2 {
            RM_reg(_) => read_gpr64(modrm_rm_reg(modrm, pfx)),
            RM_mem(addr) => mem_read64(fixup_addr(addr)),
          };
          __uint64_to_f32(v)
        } else {
          let v : dword = match rm2 {
            RM_reg(_) => read_gpr32(modrm_rm_reg(modrm, pfx)),
            RM_mem(addr) => mem_read32(fixup_addr(addr)),
          };
          __uint32_to_f32(v)
        };
        var dst_val = src1;
        dst_val[31..0] = result_f32;
        write_xmm(dst_xmm, dst_val);
        Ok()
      },
      MP_F2 => { // VCVTUSI2SD: scalar u32/u64→f64
        let dst_xmm = evex_reg_idx(modrm, pfx);
        let rm2 = decode_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
        let src1 = read_xmm(pfx.evex_vvvvv);
        let result_f64 : qword = if pfx.rex_w then {
          let v : qword = match rm2 {
            RM_reg(_) => read_gpr64(modrm_rm_reg(modrm, pfx)),
            RM_mem(addr) => mem_read64(fixup_addr(addr)),
          };
          __uint64_to_f64(v)
        } else {
          let v : dword = match rm2 {
            RM_reg(_) => read_gpr32(modrm_rm_reg(modrm, pfx)),
            RM_mem(addr) => mem_read32(fixup_addr(addr)),
          };
          __uint32_to_f64(v)
        };
        var dst_val = src1;
        dst_val[63..0] = result_f64;
        write_xmm(dst_xmm, dst_val);
        Ok()
      },
      _ => raise_UD(),
    }
  },

  // 0F 6F: VMOVDQA32/VMOVDQA64/VMOVDQU32/VMOVDQU64 (EVEX load)
  // 0F 51: VSQRTPS (NP) / VSQRTPD (66) — supports {er} at 512-bit
  81 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
    let (eff_ll, saved_mxcsr) = evex_begin_rc(pfx, not_bool(is_mem));
    let result : ExecutionResult = match mp {
      MP_NONE => match eff_ll {
        2 => { write_zmm(dst, vsqrtps_zmm(evex_src_zmm(modrm, rm, pfx))); Ok() },
        1 => { write_ymm(dst, vsqrtps_ymm(evex_src_ymm(modrm, rm, pfx))); Ok() },
        _ => { write_xmm(dst, vsqrtps_xmm(evex_src_xmm(modrm, rm, pfx))); Ok() },
      },
      MP_66 => match eff_ll {
        2 => { write_zmm(dst, vsqrtpd_zmm(evex_src_zmm(modrm, rm, pfx))); Ok() },
        1 => { write_ymm(dst, vsqrtpd_ymm(evex_src_ymm(modrm, rm, pfx))); Ok() },
        _ => { write_xmm(dst, vsqrtpd_xmm(evex_src_xmm(modrm, rm, pfx))); Ok() },
      },
      MP_F3 => { // VSQRTSS (scalar f32, EVEX) — supports {er}
        let src1 = read_xmm(pfx.evex_vvvvv);
        let src2_f32 : dword = match rm {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
          RM_mem(addr) => mem_read32(fixup_addr(addr)),
        };
        write_xmm(dst, src1[127..32] @ __f32_sqrt(src2_f32)); Ok()
      },
      MP_F2 => { // VSQRTSD (scalar f64, EVEX) — supports {er}
        let src1 = read_xmm(pfx.evex_vvvvv);
        let src2_f64 : qword = match rm {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
          RM_mem(addr) => mem_read64(fixup_addr(addr)),
        };
        write_xmm(dst, src1[127..64] @ __f64_sqrt(src2_f64)); Ok()
      },
    };
    evex_end_rc(saved_mxcsr);
    result
  },

  // 0F 5D: VMINPS/PD/SS/SD (EVEX)
  93 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    match mp {
      MP_NONE => match pfx.evex_ll {
        2 => { write_zmm(dst, vminps_zmm(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok() },
        1 => { write_ymm(dst, vminps_ymm(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok() },
        _ => { write_xmm(dst, vminps_xmm(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok() },
      },
      MP_66 => match pfx.evex_ll {
        2 => { write_zmm(dst, vminpd_zmm(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok() },
        1 => { write_ymm(dst, vminpd_ymm(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok() },
        _ => { write_xmm(dst, vminpd_xmm(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok() },
      },
      MP_F3 => { // VMINSS (scalar f32, EVEX)
        let src1 = read_xmm(pfx.evex_vvvvv);
        let src2_f32 : dword = match rm {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
          RM_mem(addr) => mem_read32(fixup_addr(addr)),
        };
        write_xmm(dst, src1[127..32] @ __f32_min(src1[31..0], src2_f32)); Ok()
      },
      MP_F2 => { // VMINSD (scalar f64, EVEX)
        let src1 = read_xmm(pfx.evex_vvvvv);
        let src2_f64 : qword = match rm {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
          RM_mem(addr) => mem_read64(fixup_addr(addr)),
        };
        write_xmm(dst, src1[127..64] @ __f64_min(src1[63..0], src2_f64)); Ok()
      },
    }
  },

  // 0F 5E: VDIVPS (NP) / VDIVPD (66) — supports {er} at 512-bit
  94 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
    let (eff_ll, saved_mxcsr) = evex_begin_rc(pfx, not_bool(is_mem));
    let result : ExecutionResult = match mp {
      MP_NONE => match eff_ll {
        2 => { write_zmm(dst, vdivps_zmm(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok() },
        1 => { write_ymm(dst, vdivps_ymm(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok() },
        _ => { write_xmm(dst, vdivps_xmm(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok() },
      },
      MP_66 => match eff_ll {
        2 => { write_zmm(dst, vdivpd_zmm(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok() },
        1 => { write_ymm(dst, vdivpd_ymm(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok() },
        _ => { write_xmm(dst, vdivpd_xmm(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok() },
      },
      MP_F3 => { // VDIVSS (scalar f32, EVEX) — supports {er}
        let src1 = read_xmm(pfx.evex_vvvvv);
        let src2_f32 : dword = match rm {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
          RM_mem(addr) => mem_read32(fixup_addr(addr)),
        };
        write_xmm(dst, src1[127..32] @ __f32_div(src1[31..0], src2_f32)); Ok()
      },
      MP_F2 => { // VDIVSD (scalar f64, EVEX) — supports {er}
        let src1 = read_xmm(pfx.evex_vvvvv);
        let src2_f64 : qword = match rm {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
          RM_mem(addr) => mem_read64(fixup_addr(addr)),
        };
        write_xmm(dst, src1[127..64] @ __f64_div(src1[63..0], src2_f64)); Ok()
      },
    };
    evex_end_rc(saved_mxcsr);
    result
  },

  // 0F 5F: VMAXPS/PD/SS/SD (EVEX)
  95 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    match mp {
      MP_NONE => match pfx.evex_ll {
        2 => { write_zmm(dst, vmaxps_zmm(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok() },
        1 => { write_ymm(dst, vmaxps_ymm(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok() },
        _ => { write_xmm(dst, vmaxps_xmm(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok() },
      },
      MP_66 => match pfx.evex_ll {
        2 => { write_zmm(dst, vmaxpd_zmm(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok() },
        1 => { write_ymm(dst, vmaxpd_ymm(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok() },
        _ => { write_xmm(dst, vmaxpd_xmm(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok() },
      },
      MP_F3 => { // VMAXSS (scalar f32, EVEX)
        let src1 = read_xmm(pfx.evex_vvvvv);
        let src2_f32 : dword = match rm {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
          RM_mem(addr) => mem_read32(fixup_addr(addr)),
        };
        write_xmm(dst, src1[127..32] @ __f32_max(src1[31..0], src2_f32)); Ok()
      },
      MP_F2 => { // VMAXSD (scalar f64, EVEX)
        let src1 = read_xmm(pfx.evex_vvvvv);
        let src2_f64 : qword = match rm {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
          RM_mem(addr) => mem_read64(fixup_addr(addr)),
        };
        write_xmm(dst, src1[127..64] @ __f64_max(src1[63..0], src2_f64)); Ok()
      },
    }
  },

  // 0F 60: VPUNPCKLBW (66, EVEX) [BW]
  // 0F C2: VCMPPS (NP,W0) / VCMPPD (66,W1) / VCMPSS (F3) / VCMPSD (F2) → kmask
  194 => {
    let modrm = fetch_byte();
    let dst_k : range(0, 7) = evex_reg_idx(modrm, pfx) % 8;
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
    let src1_idx = pfx.evex_vvvvv;
    match mp {
      MP_NONE => { // VCMPPS → k
        let imm = fetch_byte();
        let pred : range(0, 31) = unsigned(imm[4..0]);
        match pfx.evex_ll {
          2 => {
            let src1 = read_zmm(src1_idx);
            let src2 : zmmword = if pfx.evex_b & is_mem
              then broadcast_f32_zmm(evex_src_m32(modrm, rm, pfx))
              else evex_src_zmm(modrm, rm, pfx);
            let result = avx_vcmpps_kmask_512(src1, src2, pred);
            write_kreg(dst_k, zero_extend(result)); Ok()
          },
          1 => {
            let src1 = read_ymm(src1_idx);
            let src2 = evex_src_ymm(modrm, rm, pfx);
            let r = avx_vcmpps_kmask_128(src1[255..128], src2[255..128], pred) @
                    avx_vcmpps_kmask_128(src1[127..0], src2[127..0], pred);
            write_kreg(dst_k, zero_extend(r)); Ok()
          },
          _ => {
            let src1 = read_xmm(src1_idx);
            let src2 = evex_src_xmm(modrm, rm, pfx);
            let r = avx_vcmpps_kmask_128(src1, src2, pred);
            write_kreg(dst_k, zero_extend(r)); Ok()
          },
        }
      },
      MP_66 => { // VCMPPD → k
        let imm = fetch_byte();
        let pred : range(0, 31) = unsigned(imm[4..0]);
        match pfx.evex_ll {
          2 => {
            let src1 = read_zmm(src1_idx);
            let src2 : zmmword = if pfx.evex_b & is_mem
              then broadcast_f64_zmm(evex_src_m64(modrm, rm, pfx))
              else evex_src_zmm(modrm, rm, pfx);
            let result = avx_vcmppd_kmask_512(src1, src2, pred);
            write_kreg(dst_k, zero_extend(result)); Ok()
          },
          1 => {
            let src1 = read_ymm(src1_idx);
            let src2 = evex_src_ymm(modrm, rm, pfx);
            let r = avx_vcmppd_kmask_128(src1[255..128], src2[255..128], pred) @
                    avx_vcmppd_kmask_128(src1[127..0], src2[127..0], pred);
            write_kreg(dst_k, zero_extend(r)); Ok()
          },
          _ => {
            let src1 = read_xmm(src1_idx);
            let src2 = evex_src_xmm(modrm, rm, pfx);
            let r = avx_vcmppd_kmask_128(src1, src2, pred);
            write_kreg(dst_k, zero_extend(r)); Ok()
          },
        }
      },
      MP_F3 => { // VCMPSS → k (scalar, bit 0 only)
        let rm2 = decode_rm_evex(modrm, pfx, 4);
        let imm = fetch_byte();
        let pred : range(0, 31) = unsigned(imm[4..0]);
        let src1_f32 = read_xmm(src1_idx)[31..0];
        let src2_f32 : dword = match rm2 {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
          RM_mem(addr) => mem_read32(fixup_addr(addr)),
        };
        let bit : bits(1) = if cmp_pred5_f32(src1_f32, src2_f32, pred) then 0b1 else 0b0;
        write_kreg(dst_k, zero_extend(bit)); Ok()
      },
      MP_F2 => { // VCMPSD → k (scalar, bit 0 only)
        let rm2 = decode_rm_evex(modrm, pfx, 8);
        let imm = fetch_byte();
        let pred : range(0, 31) = unsigned(imm[4..0]);
        let src1_f64 = read_xmm(src1_idx)[63..0];
        let src2_f64 : qword = match rm2 {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
          RM_mem(addr) => mem_read64(fixup_addr(addr)),
        };
        let bit : bits(1) = if cmp_pred5_f64(src1_f64, src2_f64, pred) then 0b1 else 0b0;
        write_kreg(dst_k, zero_extend(bit)); Ok()
      },
    }
  },

  // 0F C6: VSHUFPS (NP,W0) / VSHUFPD (66,W1)
  // 0F C6: VSHUFPS (NP,W0) / VSHUFPD (66,W1)
  198 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
    let src1_idx = pfx.evex_vvvvv;
    let imm = fetch_byte();
    match mp {
      MP_NONE => { // VSHUFPS
        match pfx.evex_ll {
          2 => {
            let src1 = read_zmm(src1_idx);
            let src2 : zmmword = if pfx.evex_b & is_mem
              then broadcast_f32_zmm(evex_src_m32(modrm, rm, pfx))
              else evex_src_zmm(modrm, rm, pfx);
            write_zmm(dst, avx_shufps_512(src1, src2, imm)); Ok()
          },
          1 => {
            let src1 = read_ymm(src1_idx);
            let src2 = evex_src_ymm(modrm, rm, pfx);
            write_ymm(dst, avx_shufps_256(src1, src2, imm)); Ok()
          },
          _ => {
            let src1 = read_xmm(src1_idx);
            let src2 = evex_src_xmm(modrm, rm, pfx);
            write_xmm(dst, avx_shufps_128(src1, src2, imm)); Ok()
          },
        }
      },
      MP_66 => { // VSHUFPD
        match pfx.evex_ll {
          2 => {
            let src1 = read_zmm(src1_idx);
            let src2 : zmmword = if pfx.evex_b & is_mem
              then broadcast_f64_zmm(evex_src_m64(modrm, rm, pfx))
              else evex_src_zmm(modrm, rm, pfx);
            write_zmm(dst, avx_shufpd_512(src1, src2, imm)); Ok()
          },
          1 => {
            let src1 = read_ymm(src1_idx);
            let src2 = evex_src_ymm(modrm, rm, pfx);
            write_ymm(dst, avx_shufpd_256(src1, src2, imm)); Ok()
          },
          _ => {
            let src1 = read_xmm(src1_idx);
            let src2 = evex_src_xmm(modrm, rm, pfx);
            write_xmm(dst, avx_shufpd_128(src1, src2, imm)); Ok()
          },
        }
      },
      _ => raise_UD(),
    }
  },

  // 0F D6: VMOVQ store (66,W1) — store low qword of XMM to XMM/m64
  // 0F E6: VCVTDQ2PD (F3,W0) / VCVTPD2DQ (F2,W1) / VCVTTPD2DQ (66,W1) / VCVTQQ2PD (F3,W1)
  230 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    match mp {
      MP_F3 => {
        if pfx.rex_w then { // VCVTQQ2PD: i64→f64
          match pfx.evex_ll {
            2 => { write_zmm(dst, avx_cvtqq2pd_512(evex_src_zmm(modrm, rm, pfx))); Ok() },
            1 => { write_ymm(dst, avx_cvtqq2pd_256(evex_src_ymm(modrm, rm, pfx))); Ok() },
            _ => { write_xmm(dst, avx_cvtqq2pd_128(evex_src_xmm(modrm, rm, pfx))); Ok() },
          }
        } else { // VCVTDQ2PD: i32→f64 (widening)
          match pfx.evex_ll {
            2 => { write_zmm(dst, avx_cvtdq2pd_8(evex_src_ymm(modrm, rm, pfx))); Ok() },
            1 => { write_ymm(dst, avx_cvtdq2pd_4(evex_src_xmm(modrm, rm, pfx))); Ok() },
            _ => { write_xmm(dst, avx_cvtdq2pd_2(evex_src_xmm(modrm, rm, pfx)[63..0])); Ok() },
          }
        }
      },
      MP_F2 => { // VCVTPD2DQ: f64→i32 (round, narrowing) — W1
        match pfx.evex_ll {
          2 => { write_ymm(dst, avx_cvtpd2dq_8(evex_src_zmm(modrm, rm, pfx))); Ok() },
          1 => { write_xmm(dst, avx_cvtpd2dq_4(evex_src_ymm(modrm, rm, pfx))); Ok() },
          _ => { write_xmm(dst, zero_extend(avx_cvtpd2dq_2(evex_src_xmm(modrm, rm, pfx)))); Ok() },
        }
      },
      MP_66 => { // VCVTTPD2DQ: f64→i32 (truncate, narrowing) — W1
        match pfx.evex_ll {
          2 => { write_ymm(dst, avx_cvttpd2dq_8(evex_src_zmm(modrm, rm, pfx))); Ok() },
          1 => { write_xmm(dst, avx_cvttpd2dq_4(evex_src_ymm(modrm, rm, pfx))); Ok() },
          _ => { write_xmm(dst, zero_extend(avx_cvttpd2dq_2(evex_src_xmm(modrm, rm, pfx)))); Ok() },
        }
      },
      _ => raise_UD(),
    }
  },

  _ => raise_UD(),
  }
}

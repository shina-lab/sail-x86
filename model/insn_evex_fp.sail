// x86-64 — EVEX FP Operations (0F map)
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

val cmp_pred5_f32 : (dword, dword, range(0, 31)) -> bit
function cmp_pred5_f32(a, b, pred) = {
  let r = __compare_ss(a, b);
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

val cmp_pred5_f64 : (qword, qword, range(0, 31)) -> bit
function cmp_pred5_f64(a, b, pred) = {
  let r = __compare_sd(a, b);
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

// VCMPPS → kmask: compare 16 f32 elements, return 16-bit mask

val avx_vcmpps_kmask_128 : (xmmword, xmmword, range(0, 31)) -> bits(4)
function avx_vcmpps_kmask_128(a, b, pred) = {
  var r : bits(4) = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    r[i] = cmp_pred5_f32(a[(lo+31)..lo], b[(lo+31)..lo], pred);
  };
  r
}

val avx_vcmpps_kmask_512 : (zmmword, zmmword, range(0, 31)) -> word
function avx_vcmpps_kmask_512(a, b, pred) = {
  var r : word = zeros();
  foreach (i from 0 to 15) {
    let lo : range(0, 480) = i * 32;
    r[i] = cmp_pred5_f32(a[(lo+31)..lo], b[(lo+31)..lo], pred);
  };
  r
}

val avx_vcmppd_kmask_128 : (xmmword, xmmword, range(0, 31)) -> bits(2)
function avx_vcmppd_kmask_128(a, b, pred) = {
  var r : bits(2) = zeros();
  foreach (i from 0 to 1) {
    let lo : range(0, 64) = i * 64;
    r[i] = cmp_pred5_f64(a[(lo+63)..lo], b[(lo+63)..lo], pred);
  };
  r
}

val avx_vcmppd_kmask_512 : (zmmword, zmmword, range(0, 31)) -> byte
function avx_vcmppd_kmask_512(a, b, pred) = {
  var r : byte = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 448) = i * 64;
    r[i] = cmp_pred5_f64(a[(lo+63)..lo], b[(lo+63)..lo], pred);
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
  let lo : bits(64) = blend(src1[63..0], src1[127..64], ctrl0);
  let hi : bits(64) = blend(src2[63..0], src2[127..64], ctrl1);
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


val dispatch_evex_fp : (range(0, 255), Prefixes) -> unit
function dispatch_evex_fp(op, pfx) = {
  let mp = get_mandatory_prefix(pfx);

  match op {
  // 0F 10: VMOVUPS/VMOVUPD (EVEX load)
  16 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_, _) => true, _ => false };
    match mp {
      // VMOVUPS xmm1/ymm1/zmm1, xmm2/ymm2/zmm2/m128/m256/m512
      MP_NONE => {
        let mask = evex_get_mask16(pfx);
        match pfx.evex_ll {
          0 => {
            let src = evex_src_xmm(modrm, rm, pfx);
            write_xmm(dst, apply_writemask_ps_xmm(src, read_xmm(dst), mask, pfx.evex_z))
          },
          1 => {
            let src = evex_src_ymm(modrm, rm, pfx);
            write_ymm(dst, apply_writemask_ps_ymm(src, read_ymm(dst), mask, pfx.evex_z))
          },
          2 => {
            let src = evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem);
            write_zmm(dst, apply_writemask_ps_zmm(src, read_zmm(dst), mask, pfx.evex_z))
          },
          3 => raise_UD(),
        }
      },
      // VMOVUPD xmm1/ymm1/zmm1, xmm2/ymm2/zmm2/m128/m256/m512
      MP_66 => {
        let mask = evex_get_mask8(pfx);
        match pfx.evex_ll {
          0 => {
            let src = evex_src_xmm(modrm, rm, pfx);
            write_xmm(dst, apply_writemask_pd_xmm(src, read_xmm(dst), mask, pfx.evex_z))
          },
          1 => {
            let src = evex_src_ymm(modrm, rm, pfx);
            write_ymm(dst, apply_writemask_pd_ymm(src, read_ymm(dst), mask, pfx.evex_z))
          },
          2 => {
            let src = evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem);
            write_zmm(dst, apply_writemask_pd_zmm(src, read_zmm(dst), mask, pfx.evex_z))
          },
          3 => raise_UD(),
        }
      },
      // VMOVSS (scalar f32 load/move, EVEX)
      MP_F3 => {
        // Memory: xmm1 = zero_extend(m32)
        // Register: xmm1 = xmm2[127:32] @ xmm3[31:0]
        match rm {
          RM_mem(seg, offset) => {
            let v : dword = seg_read32(seg, offset);
            write_xmm(dst, zero_extend(v))
          },
          RM_reg(_) => {
            let src1 = read_xmm(pfx.evex_vvvvv);
            let src2 : dword = read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0];
            evex_write_ss(dst, src1[127..32] @ src2, pfx)
          },
        }
      },
      // VMOVSD (scalar f64 load/move, EVEX)
      MP_F2 => {
        // Memory: xmm1 = zero_extend(m64)
        // Register: xmm1 = xmm2[127:64] @ xmm3[63:0]
        match rm {
          RM_mem(seg, offset) => {
            let v : qword = seg_read64(seg, offset);
            write_xmm(dst, zero_extend(v))
          },
          RM_reg(_) => {
            let src1 = read_xmm(pfx.evex_vvvvv);
            let src2 : qword = read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0];
            evex_write_sd(dst, src1[127..64] @ src2, pfx)
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
      // VMOVUPS xmm2/ymm2/zmm2/m128/m256/m512, xmm1/ymm1/zmm1
      MP_NONE => {
        match rm {
          RM_reg(_) => {
            let mask = evex_get_mask16(pfx);
            let dst = evex_rm_reg_idx(modrm, pfx);
            match pfx.evex_ll {
              0 => write_xmm(dst, apply_writemask_ps_xmm(read_xmm(src), read_xmm(dst), mask, pfx.evex_z)),
              1 => write_ymm(dst, apply_writemask_ps_ymm(read_ymm(src), read_ymm(dst), mask, pfx.evex_z)),
              2 => write_zmm(dst, apply_writemask_ps_zmm(read_zmm(src), read_zmm(dst), mask, pfx.evex_z)),
              3 => raise_UD(),
            }
          },
          RM_mem(seg, offset) => {
            let a = seg_linear(seg, offset, 64);
            let nbytes : {16, 32, 64} = match pfx.evex_ll { 0 => 16, 1 => 32, 2 => 64 , 3 => { raise_UD(); 16 } };
            evex_masked_mem_store(a, read_zmm(src), evex_kmask64(pfx), nbytes, 4)
          },
        }
      },
      // VMOVUPD xmm2/ymm2/zmm2/m128/m256/m512, xmm1/ymm1/zmm1
      MP_66 => {
        match rm {
          RM_reg(_) => {
            let mask = evex_get_mask8(pfx);
            let dst = evex_rm_reg_idx(modrm, pfx);
            match pfx.evex_ll {
              0 => write_xmm(dst, apply_writemask_pd_xmm(read_xmm(src), read_xmm(dst), mask, pfx.evex_z)),
              1 => write_ymm(dst, apply_writemask_pd_ymm(read_ymm(src), read_ymm(dst), mask, pfx.evex_z)),
              2 => write_zmm(dst, apply_writemask_pd_zmm(read_zmm(src), read_zmm(dst), mask, pfx.evex_z)),
              3 => raise_UD(),
            }
          },
          RM_mem(seg, offset) => {
            let a = seg_linear(seg, offset, 64);
            let nbytes : {16, 32, 64} = match pfx.evex_ll { 0 => 16, 1 => 32, 2 => 64 , 3 => { raise_UD(); 16 } };
            evex_masked_mem_store(a, read_zmm(src), evex_kmask64(pfx), nbytes, 8)
          },
        }
      },
      // VMOVSS (scalar f32 store/move, EVEX)
      MP_F3 => {
        // Memory: m32 = xmm1[31:0]
        // Register: xmm1{k1}{z} = xmm2[127:32] @ xmm3[31:0]
        match rm {
          RM_mem(seg, offset) => seg_write32(seg, offset, read_xmm(src)[31..0]),
          RM_reg(_) => {
            let dst = evex_rm_reg_idx(modrm, pfx);
            let src1 = read_xmm(pfx.evex_vvvvv);
            let src2 : dword = read_xmm(src)[31..0];
            evex_write_ss(dst, src1[127..32] @ src2, pfx)
          },
        }
      },
      // VMOVSD (scalar f64 store/move, EVEX)
      MP_F2 => {
        // Memory: m64 = xmm1[63:0]
        // Register: xmm1{k1}{z} = xmm2[127:64] @ xmm3[63:0]
        match rm {
          RM_mem(seg, offset) => seg_write64(seg, offset, read_xmm(src)[63..0]),
          RM_reg(_) => {
            let dst = evex_rm_reg_idx(modrm, pfx);
            let src1 = read_xmm(pfx.evex_vvvvv);
            let src2 : qword = read_xmm(src)[63..0];
            evex_write_sd(dst, src1[127..64] @ src2, pfx)
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
      // VMOVLPS (mem) or VMOVHLPS (reg) — XMM only
      MP_NONE => {
        if pfx.evex_ll != 0 then raise_UD();
        let rm = decode_rm_evex(modrm, pfx, 8);
        match rm {
          // VMOVHLPS xmm1, xmm2, xmm3
          RM_reg(_) => {
            let src1 = read_xmm(pfx.evex_vvvvv);
            let src2 = read_xmm(evex_rm_reg_idx(modrm, pfx));
            let result : xmmword = src1[127..64] @ src2[127..64];
            write_xmm(dst, result)
          },
          // VMOVLPS xmm2, xmm1, m64
          RM_mem(seg, offset) => {
            let src1 = read_xmm(pfx.evex_vvvvv);
            let m64val = seg_read64(seg, offset);
            let result : xmmword = src1[127..64] @ m64val;
            write_xmm(dst, result)
          },
        }
      },
      // VMOVLPD xmm2, xmm1, m64 — XMM only
      MP_66 => {
        if pfx.evex_ll != 0 then raise_UD();
        let rm = decode_rm_evex(modrm, pfx, 8);
        match rm {
          RM_reg(_) => raise_UD(),
          RM_mem(seg, offset) => {
            let src1 = read_xmm(pfx.evex_vvvvv);
            let m64val = seg_read64(seg, offset);
            let result : xmmword = src1[127..64] @ m64val;
            write_xmm(dst, result)
          },
        }
      },
      // VMOVSLDUP xmm1/ymm1/zmm1, xmm2/ymm2/zmm2/m128/m256/m512
      MP_F3 => {
        let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
        match pfx.evex_ll {
          0 => evex_write_ps_xmm(dst, avx_movsldup_128(evex_src_xmm(modrm, rm, pfx)), pfx),
          1 => evex_write_ps_ymm(dst, avx_movsldup_256(evex_src_ymm(modrm, rm, pfx)), pfx),
          2 => evex_write_ps_zmm(dst, avx_movsldup_512(evex_src_zmm(modrm, rm, pfx)), pfx),
          3 => raise_UD(),
        }
      },
      // VMOVDDUP xmm1/ymm1/zmm1, xmm2/ymm2/zmm2/m128/m256/m512
      MP_F2 => {
        let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
        match pfx.evex_ll {
          0 => {
            // 128-bit MOVDDUP: source is xmm or m64
            let src : xmmword = match rm {
              RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx)),
              RM_mem(seg, offset) => {
                let v = seg_read64(seg, offset);
                v @ v
              },
            };
            evex_write_pd_xmm(dst, avx_movddup_128(src), pfx)
          },
          1 => evex_write_pd_ymm(dst, avx_movddup_256(evex_src_ymm(modrm, rm, pfx)), pfx),
          2 => evex_write_pd_zmm(dst, avx_movddup_512(evex_src_zmm(modrm, rm, pfx)), pfx),
          3 => raise_UD(),
        }
      },
    }
  },

  // 0F 13: VMOVLPS (NP,store) / VMOVLPD (66,store) — XMM only, m64
  // 0F 13: VMOVLPS (NP,store) / VMOVLPD (66,store) — XMM only, m64
  19 => {
    let modrm = fetch_byte();
    if pfx.evex_ll != 0 then raise_UD();
    let rm = decode_rm_evex(modrm, pfx, 8);
    match rm {
      RM_reg(_) => raise_UD(),
      RM_mem(seg, offset) => {
        let src = read_xmm(evex_reg_idx(modrm, pfx));
        seg_write64(seg, offset, src[63..0])
      },
    }
  },

  // 0F 14: VUNPCKLPS (NP,W0) / VUNPCKLPD (66,W1)
  // 0F 14: VUNPCKLPS (NP,W0) / VUNPCKLPD (66,W1)
  20 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_, _) => true, _ => false };
    let src1_idx = pfx.evex_vvvvv;
    match mp {
      // VUNPCKLPS (W0)
      MP_NONE => {
        match pfx.evex_ll {
          0 => {
            let src1 = read_xmm(src1_idx);
            let src2 = evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem);
            evex_write_ps_xmm(dst, avx_unpcklps_128(src1, src2), pfx)
          },
          1 => {
            let src1 = read_ymm(src1_idx);
            let src2 = evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem);
            evex_write_ps_ymm(dst, avx_unpcklps_256(src1, src2), pfx)
          },
          2 => {
            let src1 = read_zmm(src1_idx);
            let src2 = evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem);
            evex_write_ps_zmm(dst, avx_unpcklps_512(src1, src2), pfx)
          },
          3 => raise_UD(),
        }
      },
      // VUNPCKLPD (W1)
      MP_66 => {
        match pfx.evex_ll {
          0 => {
            let src1 = read_xmm(src1_idx);
            let src2 = evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem);
            evex_write_pd_xmm(dst, avx_unpcklpd_128(src1, src2), pfx)
          },
          1 => {
            let src1 = read_ymm(src1_idx);
            let src2 = evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem);
            evex_write_pd_ymm(dst, avx_unpcklpd_256(src1, src2), pfx)
          },
          2 => {
            let src1 = read_zmm(src1_idx);
            let src2 = evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem);
            evex_write_pd_zmm(dst, avx_unpcklpd_512(src1, src2), pfx)
          },
          3 => raise_UD(),
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
    let is_mem : bool = match rm { RM_mem(_, _) => true, _ => false };
    let src1_idx = pfx.evex_vvvvv;
    match mp {
      // VUNPCKHPS (W0)
      MP_NONE => {
        match pfx.evex_ll {
          0 => {
            let src1 = read_xmm(src1_idx);
            let src2 = evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem);
            evex_write_ps_xmm(dst, avx_unpckhps_128(src1, src2), pfx)
          },
          1 => {
            let src1 = read_ymm(src1_idx);
            let src2 = evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem);
            evex_write_ps_ymm(dst, avx_unpckhps_256(src1, src2), pfx)
          },
          2 => {
            let src1 = read_zmm(src1_idx);
            let src2 = evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem);
            evex_write_ps_zmm(dst, avx_unpckhps_512(src1, src2), pfx)
          },
          3 => raise_UD(),
        }
      },
      // VUNPCKHPD (W1)
      MP_66 => {
        match pfx.evex_ll {
          0 => {
            let src1 = read_xmm(src1_idx);
            let src2 = evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem);
            evex_write_pd_xmm(dst, avx_unpckhpd_128(src1, src2), pfx)
          },
          1 => {
            let src1 = read_ymm(src1_idx);
            let src2 = evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem);
            evex_write_pd_ymm(dst, avx_unpckhpd_256(src1, src2), pfx)
          },
          2 => {
            let src1 = read_zmm(src1_idx);
            let src2 = evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem);
            evex_write_pd_zmm(dst, avx_unpckhpd_512(src1, src2), pfx)
          },
          3 => raise_UD(),
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
      // VMOVHPS (mem) or VMOVLHPS (reg) — XMM only
      MP_NONE => {
        if pfx.evex_ll != 0 then raise_UD();
        let rm = decode_rm_evex(modrm, pfx, 8);
        match rm {
          // VMOVLHPS xmm1, xmm2, xmm3
          RM_reg(_) => {
            let src1 = read_xmm(pfx.evex_vvvvv);
            let src2 = read_xmm(evex_rm_reg_idx(modrm, pfx));
            let result : xmmword = src2[63..0] @ src1[63..0];
            write_xmm(dst, result)
          },
          // VMOVHPS xmm2, xmm1, m64
          RM_mem(seg, offset) => {
            let src1 = read_xmm(pfx.evex_vvvvv);
            let m64val = seg_read64(seg, offset);
            let result : xmmword = m64val @ src1[63..0];
            write_xmm(dst, result)
          },
        }
      },
      // VMOVHPD xmm2, xmm1, m64 — XMM only
      MP_66 => {
        if pfx.evex_ll != 0 then raise_UD();
        let rm = decode_rm_evex(modrm, pfx, 8);
        match rm {
          RM_reg(_) => raise_UD(),
          RM_mem(seg, offset) => {
            let src1 = read_xmm(pfx.evex_vvvvv);
            let m64val = seg_read64(seg, offset);
            let result : xmmword = m64val @ src1[63..0];
            write_xmm(dst, result)
          },
        }
      },
      // VMOVSHDUP xmm1/ymm1/zmm1, xmm2/ymm2/zmm2/m128/m256/m512
      MP_F3 => {
        let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
        match pfx.evex_ll {
          0 => evex_write_ps_xmm(dst, avx_movshdup_128(evex_src_xmm(modrm, rm, pfx)), pfx),
          1 => evex_write_ps_ymm(dst, avx_movshdup_256(evex_src_ymm(modrm, rm, pfx)), pfx),
          2 => evex_write_ps_zmm(dst, avx_movshdup_512(evex_src_zmm(modrm, rm, pfx)), pfx),
          3 => raise_UD(),
        }
      },
      _ => raise_UD(),
    }
  },

  // 0F 17: VMOVHPS (NP,store) / VMOVHPD (66,store) — XMM only, m64
  // 0F 17: VMOVHPS (NP,store) / VMOVHPD (66,store) — XMM only, m64
  23 => {
    let modrm = fetch_byte();
    if pfx.evex_ll != 0 then raise_UD();
    let rm = decode_rm_evex(modrm, pfx, 8);
    match rm {
      RM_reg(_) => raise_UD(),
      RM_mem(seg, offset) => {
        let src = read_xmm(evex_reg_idx(modrm, pfx));
        seg_write64(seg, offset, src[127..64])
      },
    }
  },

  // 0F 28: VMOVAPS/VMOVAPD (EVEX load)
  // 0F 28: VMOVAPS/VMOVAPD (EVEX load)
  40 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    match pfx.evex_ll {
      0 => if mp == MP_66 then evex_write_pd_xmm(dst, evex_src_xmm(modrm, rm, pfx), pfx)
             else evex_write_ps_xmm(dst, evex_src_xmm(modrm, rm, pfx), pfx),
      1 => if mp == MP_66 then evex_write_pd_ymm(dst, evex_src_ymm(modrm, rm, pfx), pfx)
             else evex_write_ps_ymm(dst, evex_src_ymm(modrm, rm, pfx), pfx),
      2 => {
        let src = evex_src_zmm(modrm, rm, pfx);
        let mask_val = if mp == MP_66 then evex_get_mask8(pfx) @ evex_get_mask8(pfx) else evex_get_mask16(pfx);
        if mp == MP_66 then {
          let masked = apply_writemask_pd_zmm(src, read_zmm(dst), evex_get_mask8(pfx), pfx.evex_z);
          write_zmm(dst, masked)
        } else {
          let masked = apply_writemask_ps_zmm(src, read_zmm(dst), evex_get_mask16(pfx), pfx.evex_z);
          write_zmm(dst, masked)
        }
      },
      3 => raise_UD(),
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
          0 => if mp == MP_66 then evex_write_pd_xmm(dst, read_xmm(src), pfx)
                 else evex_write_ps_xmm(dst, read_xmm(src), pfx),
          1 => if mp == MP_66 then evex_write_pd_ymm(dst, read_ymm(src), pfx)
                 else evex_write_ps_ymm(dst, read_ymm(src), pfx),
          2 => if mp == MP_66 then evex_write_pd_zmm(dst, read_zmm(src), pfx)
                 else evex_write_ps_zmm(dst, read_zmm(src), pfx),
          3 => raise_UD(),
        }
      },
      RM_mem(seg, offset) => {
        let a = seg_linear(seg, offset, 64);
        let elem : {4, 8} = if mp == MP_66 then 8 else 4;
        let nbytes : {16, 32, 64} = match pfx.evex_ll { 0 => 16, 1 => 32, 2 => 64 , 3 => { raise_UD(); 16 } };
        evex_masked_mem_store(a, read_zmm(src), evex_kmask64(pfx), nbytes, elem)
      },
    }
  },

  // 0F 2A: VCVTSI2SS (F3) / VCVTSI2SD (F2) — scalar, GPR/mem to XMM
  // F3: {er}, F2/W1: {er}
  42 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
    let is_mem : bool = match rm { RM_mem(_, _) => true, _ => false };
    let (_, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
    let os : {16, 32, 64} = if pfx.rex_w then 64 else 32;
    let src_val : qword = match rm {
      RM_reg(_) => read_gpr(os, modrm_rm_reg(modrm, pfx)),
      RM_mem(seg, offset) => match os {
        64 => seg_read64(seg, offset),
        _    => zero_extend(seg_read32(seg, offset)),
      },
    };
    let src1 = read_xmm(pfx.evex_vvvvv);
    match mp {
      // VCVTSI2SS xmm1, xmm2, r/m32
      MP_F3 => {
        let result : dword = match os {
          64 => __int64_to_f32(src_val),
          _    => __int32_to_f32(src_val[31..0]),
        };
        var xmm : xmmword = src1;
        xmm[31..0] = result;
        write_xmm(dst, xmm)
      },
      // VCVTSI2SD xmm1, xmm2, r/m32
      MP_F2 => {
        let result : qword = match os {
          64 => __int64_to_f64(src_val),
          _    => __int32_to_f64(src_val[31..0]),
        };
        var xmm : xmmword = src1;
        xmm[63..0] = result;
        write_xmm(dst, xmm)
      },
      _ => raise_UD(),
    };
    evex_end_rc(saved_mxcsr)
  },

  // 0F 2B: VMOVNTPS (NP) / VMOVNTPD (66) — non-temporal store
  // 0F 2B: VMOVNTPS (NP) / VMOVNTPD (66) — non-temporal store
  43 => {
    let modrm = fetch_byte();
    let src = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    match rm {
      RM_reg(_) => raise_UD(),
      RM_mem(seg, offset) => {
        let a = seg_linear(seg, offset, 64);
        match pfx.evex_ll {
          0 => mem_write128(a, read_xmm(src)),
          1 => mem_write256(a, read_ymm(src)),
          2 => mem_write512(a, read_zmm(src)),
          3 => raise_UD(),
        }
      },
    }
  },

  // 0F 2C: VCVTTSS2SI (F3) / VCVTTSD2SI (F2) — scalar, XMM/mem to GPR (truncate)
  // Both support {sae}.
  44 => {
    let modrm = fetch_byte();
    let dst_gpr = modrm_reg(modrm, pfx);
    let os : {16, 32, 64} = if pfx.rex_w then 64 else 32;
    match mp {
      // VCVTTSS2SI — supports {sae}
      MP_F3 => {
        let rm = decode_rm_evex(modrm, pfx, 4);
        let is_mem : bool = match rm { RM_mem(_, _) => true, _ => false };
        let (_, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
        let src_f32 : dword = match rm {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
          RM_mem(seg, offset) => seg_read32(seg, offset),
        };
        match os {
          64 => write_gpr(64, dst_gpr, __f32_to_int64_trunc(src_f32)),
          _  => write_gpr(32, dst_gpr, zero_extend(__f32_to_int32_trunc(src_f32))),
        };
        evex_end_rc(saved_mxcsr)
      },
      // VCVTTSD2SI — supports {sae}
      MP_F2 => {
        let rm = decode_rm_evex(modrm, pfx, 8);
        let is_mem : bool = match rm { RM_mem(_, _) => true, _ => false };
        let (_, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
        let src_f64 : qword = match rm {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
          RM_mem(seg, offset) => seg_read64(seg, offset),
        };
        match os {
          64 => write_gpr(64, dst_gpr, __f64_to_int64_trunc(src_f64)),
          _  => write_gpr(32, dst_gpr, zero_extend(__f64_to_int32_trunc(src_f64))),
        };
        evex_end_rc(saved_mxcsr)
      },
      _ => raise_UD(),
    }
  },

  // 0F 2D: VCVTSS2SI (F3) / VCVTSD2SI (F2) — scalar, XMM/mem to GPR (round)
  // Both support {er}.
  45 => {
    let modrm = fetch_byte();
    let dst_gpr = modrm_reg(modrm, pfx);
    let os : {16, 32, 64} = if pfx.rex_w then 64 else 32;
    match mp {
      // VCVTSS2SI — supports {er}
      MP_F3 => {
        let rm = decode_rm_evex(modrm, pfx, 4);
        let is_mem : bool = match rm { RM_mem(_, _) => true, _ => false };
        let (_, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
        let src_f32 : dword = match rm {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
          RM_mem(seg, offset) => seg_read32(seg, offset),
        };
        match os {
          64 => write_gpr(64, dst_gpr, __f32_to_int64(src_f32)),
          _  => write_gpr(32, dst_gpr, zero_extend(__f32_to_int32(src_f32))),
        };
        evex_end_rc(saved_mxcsr)
      },
      // VCVTSD2SI — supports {er}
      MP_F2 => {
        let rm = decode_rm_evex(modrm, pfx, 8);
        let is_mem : bool = match rm { RM_mem(_, _) => true, _ => false };
        let (_, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
        let src_f64 : qword = match rm {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
          RM_mem(seg, offset) => seg_read64(seg, offset),
        };
        match os {
          64 => write_gpr(64, dst_gpr, __f64_to_int64(src_f64)),
          _  => write_gpr(32, dst_gpr, zero_extend(__f64_to_int32(src_f64))),
        };
        evex_end_rc(saved_mxcsr)
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
      // VUCOMISS xmm1, xmm2/m32
      MP_NONE => {
        let rm = decode_rm_evex(modrm, pfx, 4);
        let src : xmmword = match rm {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx)),
          RM_mem(seg, offset) => zero_extend(seg_read32(seg, offset)),
        };
        let a : dword = read_xmm(dst)[31..0];
        let b : dword = src[31..0];
        match __compare_ss(a, b) {
          FP_UNORDERED => { ZF = 0b1; PF = 0b1; CF = 0b1;  },
          FP_GT        => { ZF = 0b0; PF = 0b0; CF = 0b0; },
          FP_LT        => { ZF = 0b0; PF = 0b0; CF = 0b1;  },
          FP_EQ        => { ZF = 0b1; PF = 0b0; CF = 0b0; },
        };
        OF = 0b0;
        SF = 0b0;
        AF = 0b0
      },
      // VUCOMISD xmm1, xmm2/m64
      MP_66 => {
        let rm = decode_rm_evex(modrm, pfx, 8);
        let src : xmmword = match rm {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx)),
          RM_mem(seg, offset) => zero_extend(seg_read64(seg, offset)),
        };
        let a : qword = read_xmm(dst)[63..0];
        let b : qword = src[63..0];
        match __compare_sd(a, b) {
          FP_UNORDERED => { ZF = 0b1; PF = 0b1; CF = 0b1;  },
          FP_GT        => { ZF = 0b0; PF = 0b0; CF = 0b0; },
          FP_LT        => { ZF = 0b0; PF = 0b0; CF = 0b1;  },
          FP_EQ        => { ZF = 0b1; PF = 0b0; CF = 0b0; },
        };
        OF = 0b0;
        SF = 0b0;
        AF = 0b0
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
      // VCOMISS xmm1, xmm2/m32
      MP_NONE => {
        let rm = decode_rm_evex(modrm, pfx, 4);
        let src : xmmword = match rm {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx)),
          RM_mem(seg, offset) => zero_extend(seg_read32(seg, offset)),
        };
        let a : dword = read_xmm(dst)[31..0];
        let b : dword = src[31..0];
        match __compare_ss(a, b) {
          FP_UNORDERED => { ZF = 0b1; PF = 0b1; CF = 0b1;  },
          FP_GT        => { ZF = 0b0; PF = 0b0; CF = 0b0; },
          FP_LT        => { ZF = 0b0; PF = 0b0; CF = 0b1;  },
          FP_EQ        => { ZF = 0b1; PF = 0b0; CF = 0b0; },
        };
        OF = 0b0;
        SF = 0b0;
        AF = 0b0
      },
      // VCOMISD xmm1, xmm2/m64
      MP_66 => {
        let rm = decode_rm_evex(modrm, pfx, 8);
        let src : xmmword = match rm {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx)),
          RM_mem(seg, offset) => zero_extend(seg_read64(seg, offset)),
        };
        let a : qword = read_xmm(dst)[63..0];
        let b : qword = src[63..0];
        match __compare_sd(a, b) {
          FP_UNORDERED => { ZF = 0b1; PF = 0b1; CF = 0b1;  },
          FP_GT        => { ZF = 0b0; PF = 0b0; CF = 0b0; },
          FP_LT        => { ZF = 0b0; PF = 0b0; CF = 0b1;  },
          FP_EQ        => { ZF = 0b1; PF = 0b0; CF = 0b0; },
        };
        OF = 0b0;
        SF = 0b0;
        AF = 0b0
      },
      _ => raise_UD(),
    }
  },

  // 0F 58: VADDPS/VADDPD (EVEX) — supports {er} at 512-bit
  88 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_, _) => true, _ => false };
    let (eff_ll, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
    match mp {
      // VADDPS xmm1/ymm1/zmm1, xmm2/ymm2/zmm2, xmm3/ymm3/zmm3/m128/m256/m512
      MP_NONE => {
        match eff_ll {
          0 => {
            let src1 = read_xmm(pfx.evex_vvvvv);
            let src2 = evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem);
            let result = vaddps_xmm(src1, src2);
            write_xmm(dst, apply_writemask_ps_xmm(result, read_xmm(dst), evex_get_mask16(pfx), pfx.evex_z))
          },
          1 => {
            let src1 = read_ymm(pfx.evex_vvvvv);
            let src2 = evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem);
            let result = vaddps_ymm(src1, src2);
            write_ymm(dst, apply_writemask_ps_ymm(result, read_ymm(dst), evex_get_mask16(pfx), pfx.evex_z))
          },
          2 => {
            let src1 : zmmword = read_zmm(pfx.evex_vvvvv);
            let src2 = evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem);
            let result = vaddps_zmm(src1, src2);
            let masked = apply_writemask_ps_zmm(result, read_zmm(dst), evex_get_mask16(pfx), pfx.evex_z);
            write_zmm(dst, masked)
          },
          3 => raise_UD(),
        }
      },
      // VADDPD xmm1/ymm1/zmm1, xmm2/ymm2/zmm2, xmm3/ymm3/zmm3/m128/m256/m512
      MP_66 => {
        let mask = evex_get_mask8(pfx);
        match eff_ll {
          0 => {
            let result = vaddpd_xmm(read_xmm(pfx.evex_vvvvv), evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem));
            write_xmm(dst, apply_writemask_pd_xmm(result, read_xmm(dst), mask, pfx.evex_z))
          },
          1 => {
            let result = vaddpd_ymm(read_ymm(pfx.evex_vvvvv), evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem));
            write_ymm(dst, apply_writemask_pd_ymm(result, read_ymm(dst), mask, pfx.evex_z))
          },
          2 => {
            let result = vaddpd_zmm(read_zmm(pfx.evex_vvvvv), evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem));
            write_zmm(dst, apply_writemask_pd_zmm(result, read_zmm(dst), mask, pfx.evex_z))
          },
          3 => raise_UD(),
        }
      },
      // VADDSS (scalar f32, EVEX) — supports {er}
      MP_F3 => {
        let src1 = read_xmm(pfx.evex_vvvvv);
        let src2_f32 : dword = match rm {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
          RM_mem(seg, offset) => seg_read32(seg, offset),
        };
        evex_write_ss(dst, src1[127..32] @ __f32_add(src1[31..0], src2_f32), pfx)
      },
      // VADDSD (scalar f64, EVEX) — supports {er}
      MP_F2 => {
        let src1 = read_xmm(pfx.evex_vvvvv);
        let src2_f64 : qword = match rm {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
          RM_mem(seg, offset) => seg_read64(seg, offset),
        };
        evex_write_sd(dst, src1[127..64] @ __f64_add(src1[63..0], src2_f64), pfx)
      },
    };
    evex_end_rc(saved_mxcsr)
  },

  // 0F 59: VMULPS/VMULPD (EVEX) — supports {er} at 512-bit
  89 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_, _) => true, _ => false };
    let (eff_ll, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
    match mp {
      // VMULPS xmm1/ymm1/zmm1, xmm2/ymm2/zmm2, xmm3/ymm3/zmm3/m128/m256/m512
      MP_NONE => {
        let mask = evex_get_mask16(pfx);
        match eff_ll {
          0 => { let r = vmulps_xmm(read_xmm(pfx.evex_vvvvv), evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem)); write_xmm(dst, apply_writemask_ps_xmm(r, read_xmm(dst), mask, pfx.evex_z)) },
          1 => { let r = vmulps_ymm(read_ymm(pfx.evex_vvvvv), evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem)); write_ymm(dst, apply_writemask_ps_ymm(r, read_ymm(dst), mask, pfx.evex_z)) },
          2 => { let r = vmulps_zmm(read_zmm(pfx.evex_vvvvv), evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem)); write_zmm(dst, apply_writemask_ps_zmm(r, read_zmm(dst), mask, pfx.evex_z)) },
          3 => raise_UD(),
        }
      },
      // VMULPD xmm1/ymm1/zmm1, xmm2/ymm2/zmm2, xmm3/ymm3/zmm3/m128/m256/m512
      MP_66 => {
        let mask = evex_get_mask8(pfx);
        match eff_ll {
          0 => { let r = vmulpd_xmm(read_xmm(pfx.evex_vvvvv), evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem)); write_xmm(dst, apply_writemask_pd_xmm(r, read_xmm(dst), mask, pfx.evex_z)) },
          1 => { let r = vmulpd_ymm(read_ymm(pfx.evex_vvvvv), evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem)); write_ymm(dst, apply_writemask_pd_ymm(r, read_ymm(dst), mask, pfx.evex_z)) },
          2 => { let r = vmulpd_zmm(read_zmm(pfx.evex_vvvvv), evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem)); write_zmm(dst, apply_writemask_pd_zmm(r, read_zmm(dst), mask, pfx.evex_z)) },
          3 => raise_UD(),
        }
      },
      // VMULSS (scalar f32, EVEX) — supports {er}
      MP_F3 => {
        let src1 = read_xmm(pfx.evex_vvvvv);
        let src2_f32 : dword = match rm {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
          RM_mem(seg, offset) => seg_read32(seg, offset),
        };
        evex_write_ss(dst, src1[127..32] @ __f32_mul(src1[31..0], src2_f32), pfx)
      },
      // VMULSD (scalar f64, EVEX) — supports {er}
      MP_F2 => {
        let src1 = read_xmm(pfx.evex_vvvvv);
        let src2_f64 : qword = match rm {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
          RM_mem(seg, offset) => seg_read64(seg, offset),
        };
        evex_write_sd(dst, src1[127..64] @ __f64_mul(src1[63..0], src2_f64), pfx)
      },
    };
    evex_end_rc(saved_mxcsr)
  },

  // 0F 5A: VCVTPS2PD (NP,W0) / VCVTPD2PS (66,W1) / VCVTSS2SD (F3) / VCVTSD2SS (F2)
  // NP: {sae}, 66: {er}, F3: {sae}, F2: {er}
  90 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    match mp {
      // VCVTPS2PD: f32→f64, source is half-width — supports {sae}
      MP_NONE => {
        // For VCVTPS2PD the source is half-width, so disp_n varies by LL.
        // We need to determine is_mem before decode_rm_evex for the rc wrapper,
        // but decode_rm_evex needs disp_n which depends on eff_ll. Since EVEX.b=1
        // only applies to reg-reg, for mem operands EVEX.b means broadcast and LL
        // is the real vector length. So we can peek at modrm to check reg vs mem.
        let is_mem : bool = modrm[7..6] != 0b11;
        let (eff_ll, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
        match eff_ll {
          // XMM: 2 f32 (m64/xmm low) → 2 f64 (XMM)
          0 => {
            let rm = decode_rm_evex(modrm, pfx, 8);
            let src : qword = evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem)[63..0];
            evex_write_pd_xmm(dst, avx_cvtps2pd_2(src), pfx)
          },
          // YMM: 4 f32 (XMM) → 4 f64 (YMM)
          1 => {
            let rm = decode_rm_evex(modrm, pfx, 16);
            let src = evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem);
            evex_write_pd_ymm(dst, avx_cvtps2pd_4(src), pfx)
          },
          // ZMM: 8 f32 (YMM) → 8 f64 (ZMM)
          2 => {
            let rm = decode_rm_evex(modrm, pfx, 32);
            let src = evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem);
            evex_write_pd_zmm(dst, avx_cvtps2pd_8(src), pfx)
          },
          3 => raise_UD(),
        };
        evex_end_rc(saved_mxcsr)
      },
      // VCVTPD2PS: f64→f32, result is half-width — supports {er}
      MP_66 => {
        let is_mem : bool = modrm[7..6] != 0b11;
        let (eff_ll, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
        match eff_ll {
          // XMM→XMM low: 2 f64 → 2 f32
          0 => {
            let rm = decode_rm_evex(modrm, pfx, 16);
            let src = evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem);
            let result : qword = avx_cvtpd2ps_2(src);
            evex_write_ps_xmm(dst, zeros(64) @ result, pfx)
          },
          // YMM→XMM: 4 f64 → 4 f32
          1 => {
            let rm = decode_rm_evex(modrm, pfx, 32);
            let src = evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem);
            evex_write_ps_xmm(dst, avx_cvtpd2ps_4(src), pfx)
          },
          // ZMM→YMM: 8 f64 → 8 f32
          2 => {
            let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
            let src = evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem);
            evex_write_ps_ymm(dst, avx_cvtpd2ps_8(src), pfx)
          },
          3 => raise_UD(),
        };
        evex_end_rc(saved_mxcsr)
      },
      // VCVTSS2SD: scalar f32→f64 — supports {sae}
      MP_F3 => {
        let rm = decode_rm_evex(modrm, pfx, 4);
        let is_mem : bool = match rm { RM_mem(_, _) => true, _ => false };
        let (_, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
        let src1 = read_xmm(pfx.evex_vvvvv);
        let src_f32 : dword = match rm {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
          RM_mem(seg, offset) => seg_read32(seg, offset),
        };
        var result : xmmword = src1;
        result[63..0] = __f32_to_f64(src_f32);
        write_xmm(dst, result);
        evex_end_rc(saved_mxcsr)
      },
      // VCVTSD2SS: scalar f64→f32 — supports {er}
      MP_F2 => {
        let rm = decode_rm_evex(modrm, pfx, 8);
        let is_mem : bool = match rm { RM_mem(_, _) => true, _ => false };
        let (_, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
        let src1 = read_xmm(pfx.evex_vvvvv);
        let src_f64 : qword = match rm {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
          RM_mem(seg, offset) => seg_read64(seg, offset),
        };
        var result : xmmword = src1;
        result[31..0] = __f64_to_f32(src_f64);
        write_xmm(dst, result);
        evex_end_rc(saved_mxcsr)
      },
    }
  },

  // 0F 5B: VCVTDQ2PS (NP,W0) / VCVTQQ2PS (NP,W1) / VCVTPS2DQ (66,W0) / VCVTTPS2DQ (F3,W0)
  // VCVTDQ2PS, VCVTQQ2PS, VCVTPS2DQ support {er} at 512-bit
  91 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_, _) => true, _ => false };
    let (eff_ll, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
    match mp {
      MP_NONE => {
        match (pfx.rex_w, eff_ll) {
          // VCVTQQ2PS: i64→f32 (narrowing, result half-width)
          (true, 0) => evex_write_ps_xmm(dst, zero_extend(avx_cvtqq2ps_2(evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem))), pfx),
          (true, 1) => evex_write_ps_xmm(dst, avx_cvtqq2ps_4(evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem)), pfx),
          (true, 2) => evex_write_ps_ymm(dst, avx_cvtqq2ps_8(evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem)), pfx),
          // VCVTDQ2PS: i32→f32
          (false, 0) => evex_write_ps_xmm(dst, avx_cvtdq2ps_128(evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem)), pfx),
          (false, 1) => evex_write_ps_ymm(dst, avx_cvtdq2ps_256(evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem)), pfx),
          (false, 2) => evex_write_ps_zmm(dst, avx_cvtdq2ps_512(evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem)), pfx),
          _ => raise_UD(),
        }
      },
      // VCVTPS2DQ xmm1/ymm1/zmm1, xmm2/ymm2/zmm2/m128/m256/m512
      MP_66 => {
        match eff_ll {
          0 => evex_write_d_xmm(dst, avx_cvtps2dq_128(evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem)), pfx),
          1 => evex_write_d_ymm(dst, avx_cvtps2dq_256(evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem)), pfx),
          2 => evex_write_d_zmm(dst, avx_cvtps2dq_512(evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem)), pfx),
          3 => raise_UD(),
        }
      },
      // VCVTTPS2DQ (truncation — no {er} but no harm from the wrapper)
      MP_F3 => {
        match eff_ll {
          0 => evex_write_d_xmm(dst, avx_cvttps2dq_128(evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem)), pfx),
          1 => evex_write_d_ymm(dst, avx_cvttps2dq_256(evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem)), pfx),
          2 => evex_write_d_zmm(dst, avx_cvttps2dq_512(evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem)), pfx),
          3 => raise_UD(),
        }
      },
      _ => raise_UD(),
    };
    evex_end_rc(saved_mxcsr)
  },

  // 0F 5C: VSUBPS/VSUBPD (EVEX) — supports {er} at 512-bit
  92 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_, _) => true, _ => false };
    let (eff_ll, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
    match mp {
      // VSUBPS xmm1/ymm1/zmm1, xmm2/ymm2/zmm2, xmm3/ymm3/zmm3/m128/m256/m512
      MP_NONE => {
        let mask = evex_get_mask16(pfx);
        match eff_ll {
          0 => { let r = vsubps_xmm(read_xmm(pfx.evex_vvvvv), evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem)); write_xmm(dst, apply_writemask_ps_xmm(r, read_xmm(dst), mask, pfx.evex_z)) },
          1 => { let r = vsubps_ymm(read_ymm(pfx.evex_vvvvv), evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem)); write_ymm(dst, apply_writemask_ps_ymm(r, read_ymm(dst), mask, pfx.evex_z)) },
          2 => { let r = vsubps_zmm(read_zmm(pfx.evex_vvvvv), evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem)); write_zmm(dst, apply_writemask_ps_zmm(r, read_zmm(dst), mask, pfx.evex_z)) },
          3 => raise_UD(),
        }
      },
      // VSUBPD xmm1/ymm1/zmm1, xmm2/ymm2/zmm2, xmm3/ymm3/zmm3/m128/m256/m512
      MP_66 => {
        let mask = evex_get_mask8(pfx);
        match eff_ll {
          0 => { let r = vsubpd_xmm(read_xmm(pfx.evex_vvvvv), evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem)); write_xmm(dst, apply_writemask_pd_xmm(r, read_xmm(dst), mask, pfx.evex_z)) },
          1 => { let r = vsubpd_ymm(read_ymm(pfx.evex_vvvvv), evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem)); write_ymm(dst, apply_writemask_pd_ymm(r, read_ymm(dst), mask, pfx.evex_z)) },
          2 => { let r = vsubpd_zmm(read_zmm(pfx.evex_vvvvv), evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem)); write_zmm(dst, apply_writemask_pd_zmm(r, read_zmm(dst), mask, pfx.evex_z)) },
          3 => raise_UD(),
        }
      },
      // VSUBSS (scalar f32, EVEX) — supports {er}
      MP_F3 => {
        let src1 = read_xmm(pfx.evex_vvvvv);
        let src2_f32 : dword = match rm {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
          RM_mem(seg, offset) => seg_read32(seg, offset),
        };
        evex_write_ss(dst, src1[127..32] @ __f32_sub(src1[31..0], src2_f32), pfx)
      },
      // VSUBSD (scalar f64, EVEX) — supports {er}
      MP_F2 => {
        let src1 = read_xmm(pfx.evex_vvvvv);
        let src2_f64 : qword = match rm {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
          RM_mem(seg, offset) => seg_read64(seg, offset),
        };
        evex_write_sd(dst, src1[127..64] @ __f64_sub(src1[63..0], src2_f64), pfx)
      },
    };
    evex_end_rc(saved_mxcsr)
  },

  // 0F 54: VANDPS/PD / 0F 55: VANDNPS/PD / 0F 56: VORPS/PD / 0F 57: VXORPS/PD (EVEX bitwise)
  op if 84 <= op & op <= 87 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_, _) => true, _ => false };
    match (pfx.rex_w, pfx.evex_ll) {
      // PD variant (qword broadcast)
      (true, 0) => {
        let src1 : xmmword = read_xmm(pfx.evex_vvvvv);
        let src2 : xmmword = evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem);
        let result : xmmword = match op {
          84 => src1 & src2, 85 => ~(src1) & src2, 86 => src1 | src2,
          _  => src1 ^ src2,
        };
        evex_write_pd_xmm(dst, result, pfx)
      },
      (true, 1) => {
        let src1 : ymmword = read_ymm(pfx.evex_vvvvv);
        let src2 : ymmword = evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem);
        let result : ymmword = match op {
          84 => src1 & src2, 85 => ~(src1) & src2, 86 => src1 | src2,
          _  => src1 ^ src2,
        };
        evex_write_pd_ymm(dst, result, pfx)
      },
      (true, 2) => {
        let src1 : zmmword = read_zmm(pfx.evex_vvvvv);
        let src2 : zmmword = evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem);
        let result : zmmword = match op {
          84 => src1 & src2, 85 => ~(src1) & src2, 86 => src1 | src2,
          _  => src1 ^ src2,
        };
        evex_write_pd_zmm(dst, result, pfx)
      },
      // PS variant (dword broadcast)
      (false, 0) => {
        let src1 : xmmword = read_xmm(pfx.evex_vvvvv);
        let src2 : xmmword = evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem);
        let result : xmmword = match op {
          84 => src1 & src2, 85 => ~(src1) & src2, 86 => src1 | src2,
          _  => src1 ^ src2,
        };
        evex_write_ps_xmm(dst, result, pfx)
      },
      (false, 1) => {
        let src1 : ymmword = read_ymm(pfx.evex_vvvvv);
        let src2 : ymmword = evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem);
        let result : ymmword = match op {
          84 => src1 & src2, 85 => ~(src1) & src2, 86 => src1 | src2,
          _  => src1 ^ src2,
        };
        evex_write_ps_ymm(dst, result, pfx)
      },
      (false, 2) => {
        let src1 : zmmword = read_zmm(pfx.evex_vvvvv);
        let src2 : zmmword = evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem);
        let result : zmmword = match op {
          84 => src1 & src2, 85 => ~(src1) & src2, 86 => src1 | src2,
          _  => src1 ^ src2,
        };
        evex_write_ps_zmm(dst, result, pfx)
      },
      _ => raise_UD(),
    }
  },

  // 0F 78: VCVTTPS2UDQ (NP,W0) / VCVTTPD2UDQ (NP,W1) / VCVTTSS2USI (F3) / VCVTTSD2USI (F2)
  //        / VCVTTPS2UQQ (66,W0) / VCVTTPD2UQQ (66,W1)
  // All packed forms support {sae}; scalar forms support {sae} too.
  // When EVEX.b=1 reg-reg, LL encodes RC but vector length is forced to 512-bit.
  120 => {
    let modrm = fetch_byte();
    match mp {
      // NP,W0=VCVTTPS2UDQ, NP,W1=VCVTTPD2UDQ
      MP_NONE => {
        let dst = evex_reg_idx(modrm, pfx);
        let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
        let is_mem : bool = match rm { RM_mem(_, _) => true, _ => false };
        let (eff_ll, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
        match (pfx.rex_w, eff_ll) {
          // VCVTTPD2UDQ: f64→u32 trunc (narrowing)
          (true, 0) => {
            let src = evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem);
            evex_write_d_xmm(dst, zero_extend(avx_cvttpd2udq_2(src)), pfx)
          },
          (true, 1) => {
            let src = evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem);
            evex_write_d_xmm(dst, avx_cvttpd2udq_4(src), pfx)
          },
          (true, 2) => {
            let src = evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem);
            evex_write_d_ymm(dst, avx_cvttpd2udq_8(src), pfx)
          },
          // VCVTTPS2UDQ: f32→u32 trunc
          (false, 0) => evex_write_d_xmm(dst, avx_cvttps2udq_128(evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem)), pfx),
          (false, 1) => evex_write_d_ymm(dst, avx_cvttps2udq_256(evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem)), pfx),
          (false, 2) => evex_write_d_zmm(dst, avx_cvttps2udq_512(evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem)), pfx),
          _ => raise_UD(),
        };
        evex_end_rc(saved_mxcsr)
      },
      // VCVTTSS2USI: scalar f32→unsigned GPR trunc — supports {sae}
      MP_F3 => {
        let rm2 = decode_rm_evex(modrm, pfx, 4);
        let is_mem : bool = match rm2 { RM_mem(_, _) => true, _ => false };
        let (_, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
        let dst_gpr = modrm_reg(modrm, pfx);
        let src_f32 : dword = match rm2 {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
          RM_mem(seg, offset) => seg_read32(seg, offset),
        };
        if pfx.rex_w then write_gpr(64, dst_gpr, __f32_to_uint64_trunc(src_f32))
        else write_gpr(32, dst_gpr, zero_extend(__f32_to_uint32_trunc(src_f32)));
        evex_end_rc(saved_mxcsr)
      },
      // VCVTTSD2USI: scalar f64→unsigned GPR trunc — supports {sae}
      MP_F2 => {
        let rm2 = decode_rm_evex(modrm, pfx, 8);
        let is_mem : bool = match rm2 { RM_mem(_, _) => true, _ => false };
        let (_, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
        let dst_gpr = modrm_reg(modrm, pfx);
        let src_f64 : qword = match rm2 {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
          RM_mem(seg, offset) => seg_read64(seg, offset),
        };
        if pfx.rex_w then write_gpr(64, dst_gpr, __f64_to_uint64_trunc(src_f64))
        else write_gpr(32, dst_gpr, zero_extend(__f64_to_uint32_trunc(src_f64)));
        evex_end_rc(saved_mxcsr)
      },
      // VCVTTPS2UQQ (W0) / VCVTTPD2UQQ (W1) — supports {sae}
      MP_66 => {
        let dst = evex_reg_idx(modrm, pfx);
        let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
        let is_mem : bool = match rm { RM_mem(_, _) => true, _ => false };
        let (eff_ll, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
        match (pfx.rex_w, eff_ll) {
          // VCVTTPD2UQQ: f64→u64 trunc
          (true, 0) => evex_write_q_xmm(dst, avx_cvttpd2uqq_128(evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem)), pfx),
          (true, 1) => evex_write_q_ymm(dst, avx_cvttpd2uqq_256(evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem)), pfx),
          (true, 2) => evex_write_q_zmm(dst, avx_cvttpd2uqq_512(evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem)), pfx),
          // VCVTTPS2UQQ: f32→u64 trunc (widening)
          (false, 0) => evex_write_q_xmm(dst, avx_cvttps2uqq_2(evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem)[63..0]), pfx),
          (false, 1) => evex_write_q_ymm(dst, avx_cvttps2uqq_4(evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem)), pfx),
          (false, 2) => evex_write_q_zmm(dst, avx_cvttps2uqq_8(evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem)), pfx),
          _ => raise_UD(),
        };
        evex_end_rc(saved_mxcsr)
      },
    }
  },

  // 0F 79: VCVTPS2UDQ (NP,W0) / VCVTPD2UDQ (NP,W1) / VCVTSS2USI (F3) / VCVTSD2USI (F2)
  //        / VCVTPS2UQQ (66,W0) / VCVTPD2UQQ (66,W1)
  // All packed forms support {er}; scalar forms support {er} too.
  121 => {
    let modrm = fetch_byte();
    match mp {
      // NP,W0=VCVTPS2UDQ, NP,W1=VCVTPD2UDQ — supports {er}
      MP_NONE => {
        let dst = evex_reg_idx(modrm, pfx);
        let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
        let is_mem : bool = match rm { RM_mem(_, _) => true, _ => false };
        let (eff_ll, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
        match (pfx.rex_w, eff_ll) {
          // VCVTPD2UDQ: f64→u32 round (narrowing)
          (true, 0) => evex_write_d_xmm(dst, zero_extend(avx_cvtpd2udq_2(evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem))), pfx),
          (true, 1) => evex_write_d_xmm(dst, avx_cvtpd2udq_4(evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem)), pfx),
          (true, 2) => evex_write_d_ymm(dst, avx_cvtpd2udq_8(evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem)), pfx),
          // VCVTPS2UDQ: f32→u32 round
          (false, 0) => evex_write_d_xmm(dst, avx_cvtps2udq_128(evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem)), pfx),
          (false, 1) => evex_write_d_ymm(dst, avx_cvtps2udq_256(evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem)), pfx),
          (false, 2) => evex_write_d_zmm(dst, avx_cvtps2udq_512(evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem)), pfx),
          _ => raise_UD(),
        };
        evex_end_rc(saved_mxcsr)
      },
      // VCVTSS2USI: scalar f32→unsigned GPR round — supports {er}
      MP_F3 => {
        let rm2 = decode_rm_evex(modrm, pfx, 4);
        let is_mem : bool = match rm2 { RM_mem(_, _) => true, _ => false };
        let (_, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
        let dst_gpr = modrm_reg(modrm, pfx);
        let src_f32 : dword = match rm2 {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
          RM_mem(seg, offset) => seg_read32(seg, offset),
        };
        if pfx.rex_w then write_gpr(64, dst_gpr, __f32_to_uint64(src_f32))
        else write_gpr(32, dst_gpr, zero_extend(__f32_to_uint32(src_f32)));
        evex_end_rc(saved_mxcsr)
      },
      // VCVTSD2USI: scalar f64→unsigned GPR round — supports {er}
      MP_F2 => {
        let rm2 = decode_rm_evex(modrm, pfx, 8);
        let is_mem : bool = match rm2 { RM_mem(_, _) => true, _ => false };
        let (_, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
        let dst_gpr = modrm_reg(modrm, pfx);
        let src_f64 : qword = match rm2 {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
          RM_mem(seg, offset) => seg_read64(seg, offset),
        };
        if pfx.rex_w then write_gpr(64, dst_gpr, __f64_to_uint64(src_f64))
        else write_gpr(32, dst_gpr, zero_extend(__f64_to_uint32(src_f64)));
        evex_end_rc(saved_mxcsr)
      },
      // VCVTPS2UQQ (W0) / VCVTPD2UQQ (W1) — supports {er}
      MP_66 => {
        let dst = evex_reg_idx(modrm, pfx);
        let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
        let is_mem : bool = match rm { RM_mem(_, _) => true, _ => false };
        let (eff_ll, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
        match (pfx.rex_w, eff_ll) {
          // VCVTPD2UQQ: f64→u64 round
          (true, 0) => evex_write_q_xmm(dst, avx_cvtpd2uqq_128(evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem)), pfx),
          (true, 1) => evex_write_q_ymm(dst, avx_cvtpd2uqq_256(evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem)), pfx),
          (true, 2) => evex_write_q_zmm(dst, avx_cvtpd2uqq_512(evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem)), pfx),
          // VCVTPS2UQQ: f32→u64 round (widening)
          (false, 0) => evex_write_q_xmm(dst, avx_cvtps2uqq_2(evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem)[63..0]), pfx),
          (false, 1) => evex_write_q_ymm(dst, avx_cvtps2uqq_4(evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem)), pfx),
          (false, 2) => evex_write_q_zmm(dst, avx_cvtps2uqq_8(evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem)), pfx),
          _ => raise_UD(),
        };
        evex_end_rc(saved_mxcsr)
      },
    }
  },

  // 0F 7A: VCVTTPS2QQ (66,W0) / VCVTTPD2QQ (66,W1) / VCVTUDQ2PS (F2,W0) / VCVTUQQ2PS (F2,W1)
  //        / VCVTUDQ2PD (F3,W0) / VCVTUQQ2PD (F3,W1)
  // 66: {sae}, F2: {er}, F3/W1 (VCVTUQQ2PD): {er}
  122 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_, _) => true, _ => false };
    let (eff_ll, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
    match mp {
      // VCVTTPS2QQ (W0) / VCVTTPD2QQ (W1) — supports {sae}
      MP_66 => {
        match (pfx.rex_w, eff_ll) {
          // VCVTTPD2QQ: f64→i64 trunc
          (true, 0) => evex_write_q_xmm(dst, avx_cvttpd2qq_128(evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem)), pfx),
          (true, 1) => evex_write_q_ymm(dst, avx_cvttpd2qq_256(evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem)), pfx),
          (true, 2) => evex_write_q_zmm(dst, avx_cvttpd2qq_512(evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem)), pfx),
          // VCVTTPS2QQ: f32→i64 trunc (widening)
          (false, 0) => evex_write_q_xmm(dst, avx_cvttps2qq_2(evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem)[63..0]), pfx),
          (false, 1) => evex_write_q_ymm(dst, avx_cvttps2qq_4(evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem)), pfx),
          (false, 2) => evex_write_q_zmm(dst, avx_cvttps2qq_8(evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem)), pfx),
          _ => raise_UD(),
        }
      },
      // VCVTUDQ2PS (W0) / VCVTUQQ2PS (W1) — supports {er}
      MP_F2 => {
        match (pfx.rex_w, eff_ll) {
          // VCVTUQQ2PS: u64→f32 (narrowing)
          (true, 0) => evex_write_ps_xmm(dst, zero_extend(avx_cvtuqq2ps_2(evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem))), pfx),
          (true, 1) => evex_write_ps_xmm(dst, avx_cvtuqq2ps_4(evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem)), pfx),
          (true, 2) => evex_write_ps_ymm(dst, avx_cvtuqq2ps_8(evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem)), pfx),
          // VCVTUDQ2PS: u32→f32
          (false, 0) => evex_write_ps_xmm(dst, avx_cvtudq2ps_128(evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem)), pfx),
          (false, 1) => evex_write_ps_ymm(dst, avx_cvtudq2ps_256(evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem)), pfx),
          (false, 2) => evex_write_ps_zmm(dst, avx_cvtudq2ps_512(evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem)), pfx),
          _ => raise_UD(),
        }
      },
      // VCVTUDQ2PD (W0) / VCVTUQQ2PD (W1) — W1 supports {er}
      MP_F3 => {
        match (pfx.rex_w, eff_ll) {
          // VCVTUQQ2PD: u64→f64
          (true, 0) => evex_write_pd_xmm(dst, avx_cvtuqq2pd_128(evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem)), pfx),
          (true, 1) => evex_write_pd_ymm(dst, avx_cvtuqq2pd_256(evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem)), pfx),
          (true, 2) => evex_write_pd_zmm(dst, avx_cvtuqq2pd_512(evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem)), pfx),
          // VCVTUDQ2PD: u32→f64 (widening, exact — no rounding needed)
          (false, 0) => evex_write_pd_xmm(dst, avx_cvtudq2pd_2(evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem)[63..0]), pfx),
          (false, 1) => evex_write_pd_ymm(dst, avx_cvtudq2pd_4(evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem)), pfx),
          (false, 2) => evex_write_pd_zmm(dst, avx_cvtudq2pd_8(evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem)), pfx),
          _ => raise_UD(),
        }
      },
      _ => raise_UD(),
    };
    evex_end_rc(saved_mxcsr)
  },

  // 0F 7B: VCVTPS2QQ (66,W0) / VCVTPD2QQ (66,W1) / VCVTUSI2SS (F3) / VCVTUSI2SD (F2)
  // 66: {er}, F3: {er}, F2/W1: {er}
  123 => {
    let modrm = fetch_byte();
    match mp {
      // VCVTPS2QQ (W0) / VCVTPD2QQ (W1) — supports {er}
      MP_66 => {
        let dst = evex_reg_idx(modrm, pfx);
        let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
        let is_mem : bool = match rm { RM_mem(_, _) => true, _ => false };
        let (eff_ll, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
        match (pfx.rex_w, eff_ll) {
          // VCVTPD2QQ: f64→i64 round
          (true, 0) => evex_write_q_xmm(dst, avx_cvtpd2qq_128(evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem)), pfx),
          (true, 1) => evex_write_q_ymm(dst, avx_cvtpd2qq_256(evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem)), pfx),
          (true, 2) => evex_write_q_zmm(dst, avx_cvtpd2qq_512(evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem)), pfx),
          // VCVTPS2QQ: f32→i64 round (widening)
          (false, 0) => evex_write_q_xmm(dst, avx_cvtps2qq_2(evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem)[63..0]), pfx),
          (false, 1) => evex_write_q_ymm(dst, avx_cvtps2qq_4(evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem)), pfx),
          (false, 2) => evex_write_q_zmm(dst, avx_cvtps2qq_8(evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem)), pfx),
          _ => raise_UD(),
        };
        evex_end_rc(saved_mxcsr)
      },
      // VCVTUSI2SS: scalar u32/u64→f32 — supports {er}
      MP_F3 => {
        let dst_xmm = evex_reg_idx(modrm, pfx);
        let rm2 = decode_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
        let is_mem : bool = match rm2 { RM_mem(_, _) => true, _ => false };
        let (_, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
        let src1 = read_xmm(pfx.evex_vvvvv);
        let result_f32 : dword = match (rm2, pfx.rex_w) {
          // W1: u64→f32
          (RM_reg(_), true) => __uint64_to_f32(read_gpr64(modrm_rm_reg(modrm, pfx))),
          (RM_mem(seg, offset), true) => __uint64_to_f32(seg_read64(seg, offset)),
          // W0: u32→f32
          (RM_reg(_), false) => __uint32_to_f32(read_gpr32(modrm_rm_reg(modrm, pfx))),
          (RM_mem(seg, offset), false) => __uint32_to_f32(seg_read32(seg, offset)),
        };
        var dst_val = src1;
        dst_val[31..0] = result_f32;
        write_xmm(dst_xmm, dst_val);
        evex_end_rc(saved_mxcsr)
      },
      // VCVTUSI2SD: scalar u32/u64→f64 — W1 supports {er}
      MP_F2 => {
        let dst_xmm = evex_reg_idx(modrm, pfx);
        let rm2 = decode_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
        let is_mem : bool = match rm2 { RM_mem(_, _) => true, _ => false };
        let (_, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
        let src1 = read_xmm(pfx.evex_vvvvv);
        let result_f64 : qword = match (rm2, pfx.rex_w) {
          // W1: u64→f64
          (RM_reg(_), true) => __uint64_to_f64(read_gpr64(modrm_rm_reg(modrm, pfx))),
          (RM_mem(seg, offset), true) => __uint64_to_f64(seg_read64(seg, offset)),
          // W0: u32→f64
          (RM_reg(_), false) => __uint32_to_f64(read_gpr32(modrm_rm_reg(modrm, pfx))),
          (RM_mem(seg, offset), false) => __uint32_to_f64(seg_read32(seg, offset)),
        };
        var dst_val = src1;
        dst_val[63..0] = result_f64;
        write_xmm(dst_xmm, dst_val);
        evex_end_rc(saved_mxcsr)
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
    let is_mem : bool = match rm { RM_mem(_, _) => true, _ => false };
    let (eff_ll, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
    match mp {
      // VSQRTPS xmm1/ymm1/zmm1, xmm2/ymm2/zmm2/m128/m256/m512
      MP_NONE => {
        let mask = evex_get_mask16(pfx);
        match eff_ll {
          0 => { let r = vsqrtps_xmm(evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem)); write_xmm(dst, apply_writemask_ps_xmm(r, read_xmm(dst), mask, pfx.evex_z)) },
          1 => { let r = vsqrtps_ymm(evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem)); write_ymm(dst, apply_writemask_ps_ymm(r, read_ymm(dst), mask, pfx.evex_z)) },
          2 => { let r = vsqrtps_zmm(evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem)); write_zmm(dst, apply_writemask_ps_zmm(r, read_zmm(dst), mask, pfx.evex_z)) },
          3 => raise_UD(),
        }
      },
      // VSQRTPD xmm1/ymm1/zmm1, xmm2/ymm2/zmm2/m128/m256/m512
      MP_66 => {
        let mask = evex_get_mask8(pfx);
        match eff_ll {
          0 => { let r = vsqrtpd_xmm(evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem)); write_xmm(dst, apply_writemask_pd_xmm(r, read_xmm(dst), mask, pfx.evex_z)) },
          1 => { let r = vsqrtpd_ymm(evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem)); write_ymm(dst, apply_writemask_pd_ymm(r, read_ymm(dst), mask, pfx.evex_z)) },
          2 => { let r = vsqrtpd_zmm(evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem)); write_zmm(dst, apply_writemask_pd_zmm(r, read_zmm(dst), mask, pfx.evex_z)) },
          3 => raise_UD(),
        }
      },
      // VSQRTSS (scalar f32, EVEX) — supports {er}
      MP_F3 => {
        let src1 = read_xmm(pfx.evex_vvvvv);
        let src2_f32 : dword = match rm {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
          RM_mem(seg, offset) => seg_read32(seg, offset),
        };
        evex_write_ss(dst, src1[127..32] @ __f32_sqrt(src2_f32), pfx)
      },
      // VSQRTSD (scalar f64, EVEX) — supports {er}
      MP_F2 => {
        let src1 = read_xmm(pfx.evex_vvvvv);
        let src2_f64 : qword = match rm {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
          RM_mem(seg, offset) => seg_read64(seg, offset),
        };
        evex_write_sd(dst, src1[127..64] @ __f64_sqrt(src2_f64), pfx)
      },
    };
    evex_end_rc(saved_mxcsr)
  },

  // 0F 5D: VMINPS/PD/SS/SD (EVEX)
  93 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_, _) => true, _ => false };
    match mp {
      // VMINPS xmm1/ymm1/zmm1, xmm2/ymm2/zmm2, xmm3/ymm3/zmm3/m128/m256/m512
      MP_NONE => {
        let mask = evex_get_mask16(pfx);
        match pfx.evex_ll {
          0 => { let r = vminps_xmm(read_xmm(pfx.evex_vvvvv), evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem)); write_xmm(dst, apply_writemask_ps_xmm(r, read_xmm(dst), mask, pfx.evex_z)) },
          1 => { let r = vminps_ymm(read_ymm(pfx.evex_vvvvv), evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem)); write_ymm(dst, apply_writemask_ps_ymm(r, read_ymm(dst), mask, pfx.evex_z)) },
          2 => { let r = vminps_zmm(read_zmm(pfx.evex_vvvvv), evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem)); write_zmm(dst, apply_writemask_ps_zmm(r, read_zmm(dst), mask, pfx.evex_z)) },
          3 => raise_UD(),
        }
      },
      // VMINPD xmm1/ymm1/zmm1, xmm2/ymm2/zmm2, xmm3/ymm3/zmm3/m128/m256/m512
      MP_66 => {
        let mask = evex_get_mask8(pfx);
        match pfx.evex_ll {
          0 => { let r = vminpd_xmm(read_xmm(pfx.evex_vvvvv), evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem)); write_xmm(dst, apply_writemask_pd_xmm(r, read_xmm(dst), mask, pfx.evex_z)) },
          1 => { let r = vminpd_ymm(read_ymm(pfx.evex_vvvvv), evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem)); write_ymm(dst, apply_writemask_pd_ymm(r, read_ymm(dst), mask, pfx.evex_z)) },
          2 => { let r = vminpd_zmm(read_zmm(pfx.evex_vvvvv), evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem)); write_zmm(dst, apply_writemask_pd_zmm(r, read_zmm(dst), mask, pfx.evex_z)) },
          3 => raise_UD(),
        }
      },
      // VMINSS (scalar f32, EVEX)
      MP_F3 => {
        let src1 = read_xmm(pfx.evex_vvvvv);
        let src2_f32 : dword = match rm {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
          RM_mem(seg, offset) => seg_read32(seg, offset),
        };
        evex_write_ss(dst, src1[127..32] @ __f32_min(src1[31..0], src2_f32), pfx)
      },
      // VMINSD (scalar f64, EVEX)
      MP_F2 => {
        let src1 = read_xmm(pfx.evex_vvvvv);
        let src2_f64 : qword = match rm {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
          RM_mem(seg, offset) => seg_read64(seg, offset),
        };
        evex_write_sd(dst, src1[127..64] @ __f64_min(src1[63..0], src2_f64), pfx)
      },
    }
  },

  // 0F 5E: VDIVPS (NP) / VDIVPD (66) — supports {er} at 512-bit
  94 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_, _) => true, _ => false };
    let (eff_ll, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
    match mp {
      // VDIVPS xmm1/ymm1/zmm1, xmm2/ymm2/zmm2, xmm3/ymm3/zmm3/m128/m256/m512
      MP_NONE => {
        let mask = evex_get_mask16(pfx);
        match eff_ll {
          0 => { let r = vdivps_xmm(read_xmm(pfx.evex_vvvvv), evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem)); write_xmm(dst, apply_writemask_ps_xmm(r, read_xmm(dst), mask, pfx.evex_z)) },
          1 => { let r = vdivps_ymm(read_ymm(pfx.evex_vvvvv), evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem)); write_ymm(dst, apply_writemask_ps_ymm(r, read_ymm(dst), mask, pfx.evex_z)) },
          2 => { let r = vdivps_zmm(read_zmm(pfx.evex_vvvvv), evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem)); write_zmm(dst, apply_writemask_ps_zmm(r, read_zmm(dst), mask, pfx.evex_z)) },
          3 => raise_UD(),
        }
      },
      // VDIVPD xmm1/ymm1/zmm1, xmm2/ymm2/zmm2, xmm3/ymm3/zmm3/m128/m256/m512
      MP_66 => {
        let mask = evex_get_mask8(pfx);
        match eff_ll {
          0 => { let r = vdivpd_xmm(read_xmm(pfx.evex_vvvvv), evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem)); write_xmm(dst, apply_writemask_pd_xmm(r, read_xmm(dst), mask, pfx.evex_z)) },
          1 => { let r = vdivpd_ymm(read_ymm(pfx.evex_vvvvv), evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem)); write_ymm(dst, apply_writemask_pd_ymm(r, read_ymm(dst), mask, pfx.evex_z)) },
          2 => { let r = vdivpd_zmm(read_zmm(pfx.evex_vvvvv), evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem)); write_zmm(dst, apply_writemask_pd_zmm(r, read_zmm(dst), mask, pfx.evex_z)) },
          3 => raise_UD(),
        }
      },
      // VDIVSS (scalar f32, EVEX) — supports {er}
      MP_F3 => {
        let src1 = read_xmm(pfx.evex_vvvvv);
        let src2_f32 : dword = match rm {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
          RM_mem(seg, offset) => seg_read32(seg, offset),
        };
        evex_write_ss(dst, src1[127..32] @ __f32_div(src1[31..0], src2_f32), pfx)
      },
      // VDIVSD (scalar f64, EVEX) — supports {er}
      MP_F2 => {
        let src1 = read_xmm(pfx.evex_vvvvv);
        let src2_f64 : qword = match rm {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
          RM_mem(seg, offset) => seg_read64(seg, offset),
        };
        evex_write_sd(dst, src1[127..64] @ __f64_div(src1[63..0], src2_f64), pfx)
      },
    };
    evex_end_rc(saved_mxcsr)
  },

  // 0F 5F: VMAXPS/PD/SS/SD (EVEX)
  95 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_, _) => true, _ => false };
    match mp {
      // VMAXPS xmm1/ymm1/zmm1, xmm2/ymm2/zmm2, xmm3/ymm3/zmm3/m128/m256/m512
      MP_NONE => {
        let mask = evex_get_mask16(pfx);
        match pfx.evex_ll {
          0 => { let r = vmaxps_xmm(read_xmm(pfx.evex_vvvvv), evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem)); write_xmm(dst, apply_writemask_ps_xmm(r, read_xmm(dst), mask, pfx.evex_z)) },
          1 => { let r = vmaxps_ymm(read_ymm(pfx.evex_vvvvv), evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem)); write_ymm(dst, apply_writemask_ps_ymm(r, read_ymm(dst), mask, pfx.evex_z)) },
          2 => { let r = vmaxps_zmm(read_zmm(pfx.evex_vvvvv), evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem)); write_zmm(dst, apply_writemask_ps_zmm(r, read_zmm(dst), mask, pfx.evex_z)) },
          3 => raise_UD(),
        }
      },
      // VMAXPD xmm1/ymm1/zmm1, xmm2/ymm2/zmm2, xmm3/ymm3/zmm3/m128/m256/m512
      MP_66 => {
        let mask = evex_get_mask8(pfx);
        match pfx.evex_ll {
          0 => { let r = vmaxpd_xmm(read_xmm(pfx.evex_vvvvv), evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem)); write_xmm(dst, apply_writemask_pd_xmm(r, read_xmm(dst), mask, pfx.evex_z)) },
          1 => { let r = vmaxpd_ymm(read_ymm(pfx.evex_vvvvv), evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem)); write_ymm(dst, apply_writemask_pd_ymm(r, read_ymm(dst), mask, pfx.evex_z)) },
          2 => { let r = vmaxpd_zmm(read_zmm(pfx.evex_vvvvv), evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem)); write_zmm(dst, apply_writemask_pd_zmm(r, read_zmm(dst), mask, pfx.evex_z)) },
          3 => raise_UD(),
        }
      },
      // VMAXSS (scalar f32, EVEX)
      MP_F3 => {
        let src1 = read_xmm(pfx.evex_vvvvv);
        let src2_f32 : dword = match rm {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
          RM_mem(seg, offset) => seg_read32(seg, offset),
        };
        evex_write_ss(dst, src1[127..32] @ __f32_max(src1[31..0], src2_f32), pfx)
      },
      // VMAXSD (scalar f64, EVEX)
      MP_F2 => {
        let src1 = read_xmm(pfx.evex_vvvvv);
        let src2_f64 : qword = match rm {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
          RM_mem(seg, offset) => seg_read64(seg, offset),
        };
        evex_write_sd(dst, src1[127..64] @ __f64_max(src1[63..0], src2_f64), pfx)
      },
    }
  },

  // 0F 60: VPUNPCKLBW (66, EVEX) [BW]
  // 0F C2: VCMPPS (NP,W0) / VCMPPD (66,W1) / VCMPSS (F3) / VCMPSD (F2) → kmask
  194 => {
    let modrm = fetch_byte();
    let dst_k : range(0, 7) = evex_reg_idx(modrm, pfx) % 8;
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_, _) => true, _ => false };
    let src1_idx = pfx.evex_vvvvv;
    match mp {
      // VCMPPS → k
      MP_NONE => {
        let imm = fetch_byte();
        let pred : range(0, 31) = unsigned(imm[4..0]);
        match pfx.evex_ll {
          0 => {
            let src1 = read_xmm(src1_idx);
            let src2 = evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem);
            let r = avx_vcmpps_kmask_128(src1, src2, pred);
            write_kreg(dst_k, zero_extend(r))
          },
          1 => {
            let src1 = read_ymm(src1_idx);
            let src2 = evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem);
            let r = avx_vcmpps_kmask_128(src1[255..128], src2[255..128], pred) @
                    avx_vcmpps_kmask_128(src1[127..0], src2[127..0], pred);
            write_kreg(dst_k, zero_extend(r))
          },
          2 => {
            let src1 = read_zmm(src1_idx);
            let src2 = evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem);
            let result = avx_vcmpps_kmask_512(src1, src2, pred);
            write_kreg(dst_k, zero_extend(result))
          },
          3 => raise_UD(),
        }
      },
      // VCMPPD → k
      MP_66 => {
        let imm = fetch_byte();
        let pred : range(0, 31) = unsigned(imm[4..0]);
        match pfx.evex_ll {
          0 => {
            let src1 = read_xmm(src1_idx);
            let src2 = evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem);
            let r = avx_vcmppd_kmask_128(src1, src2, pred);
            write_kreg(dst_k, zero_extend(r))
          },
          1 => {
            let src1 = read_ymm(src1_idx);
            let src2 = evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem);
            let r = avx_vcmppd_kmask_128(src1[255..128], src2[255..128], pred) @
                    avx_vcmppd_kmask_128(src1[127..0], src2[127..0], pred);
            write_kreg(dst_k, zero_extend(r))
          },
          2 => {
            let src1 = read_zmm(src1_idx);
            let src2 = evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem);
            let result = avx_vcmppd_kmask_512(src1, src2, pred);
            write_kreg(dst_k, zero_extend(result))
          },
          3 => raise_UD(),
        }
      },
      // VCMPSS → k (scalar, bit 0 only)
      MP_F3 => {
        let rm2 = decode_rm_evex(modrm, pfx, 4);
        let imm = fetch_byte();
        let pred : range(0, 31) = unsigned(imm[4..0]);
        let src1_f32 = read_xmm(src1_idx)[31..0];
        let src2_f32 : dword = match rm2 {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
          RM_mem(seg, offset) => seg_read32(seg, offset),
        };
        write_kreg(dst_k, zero_extend(cmp_pred5_f32(src1_f32, src2_f32, pred)))
      },
      // VCMPSD → k (scalar, bit 0 only)
      MP_F2 => {
        let rm2 = decode_rm_evex(modrm, pfx, 8);
        let imm = fetch_byte();
        let pred : range(0, 31) = unsigned(imm[4..0]);
        let src1_f64 = read_xmm(src1_idx)[63..0];
        let src2_f64 : qword = match rm2 {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
          RM_mem(seg, offset) => seg_read64(seg, offset),
        };
        write_kreg(dst_k, zero_extend(cmp_pred5_f64(src1_f64, src2_f64, pred)))
      },
    }
  },

  // 0F C6: VSHUFPS (NP,W0) / VSHUFPD (66,W1)
  // 0F C6: VSHUFPS (NP,W0) / VSHUFPD (66,W1)
  198 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_, _) => true, _ => false };
    let src1_idx = pfx.evex_vvvvv;
    let imm = fetch_byte();
    match mp {
      // VSHUFPS xmm1/ymm1/zmm1, xmm2/ymm2/zmm2, xmm3/ymm3/zmm3/m128/m256/m512, imm8
      MP_NONE => {
        match pfx.evex_ll {
          0 => {
            let src1 = read_xmm(src1_idx);
            let src2 = evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem);
            evex_write_ps_xmm(dst, avx_shufps_128(src1, src2, imm), pfx)
          },
          1 => {
            let src1 = read_ymm(src1_idx);
            let src2 = evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem);
            evex_write_ps_ymm(dst, avx_shufps_256(src1, src2, imm), pfx)
          },
          2 => {
            let src1 = read_zmm(src1_idx);
            let src2 = evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem);
            evex_write_ps_zmm(dst, avx_shufps_512(src1, src2, imm), pfx)
          },
          3 => raise_UD(),
        }
      },
      // VSHUFPD xmm1/ymm1/zmm1, xmm2/ymm2/zmm2, xmm3/ymm3/zmm3/m128/m256/m512, imm8
      MP_66 => {
        match pfx.evex_ll {
          0 => {
            let src1 = read_xmm(src1_idx);
            let src2 = evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem);
            evex_write_pd_xmm(dst, avx_shufpd_128(src1, src2, imm), pfx)
          },
          1 => {
            let src1 = read_ymm(src1_idx);
            let src2 = evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem);
            evex_write_pd_ymm(dst, avx_shufpd_256(src1, src2, imm), pfx)
          },
          2 => {
            let src1 = read_zmm(src1_idx);
            let src2 = evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem);
            evex_write_pd_zmm(dst, avx_shufpd_512(src1, src2, imm), pfx)
          },
          3 => raise_UD(),
        }
      },
      _ => raise_UD(),
    }
  },

  // 0F D6: VMOVQ store (66,W1) — store low qword of XMM to XMM/m64
  // 0F E6: VCVTDQ2PD (F3,W0) / VCVTPD2DQ (F2,W1) / VCVTTPD2DQ (66,W1) / VCVTQQ2PD (F3,W1)
  // F3/W1 (VCVTQQ2PD): {er}, F2 (VCVTPD2DQ): {er}, 66 (VCVTTPD2DQ): {sae}
  230 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_, _) => true, _ => false };
    let (eff_ll, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
    match mp {
      MP_F3 => {
        match (pfx.rex_w, eff_ll) {
          // VCVTQQ2PD: i64→f64 — supports {er}
          (true, 0) => evex_write_pd_xmm(dst, avx_cvtqq2pd_128(evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem)), pfx),
          (true, 1) => evex_write_pd_ymm(dst, avx_cvtqq2pd_256(evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem)), pfx),
          (true, 2) => evex_write_pd_zmm(dst, avx_cvtqq2pd_512(evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem)), pfx),
          // VCVTDQ2PD: i32→f64 (widening, exact — no rounding needed)
          (false, 0) => evex_write_pd_xmm(dst, avx_cvtdq2pd_2(evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem)[63..0]), pfx),
          (false, 1) => evex_write_pd_ymm(dst, avx_cvtdq2pd_4(evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem)), pfx),
          (false, 2) => evex_write_pd_zmm(dst, avx_cvtdq2pd_8(evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem)), pfx),
          _ => raise_UD(),
        }
      },
      // VCVTPD2DQ: f64→i32 (round, narrowing) — supports {er}
      MP_F2 => {
        match eff_ll {
          0 => evex_write_d_xmm(dst, zero_extend(avx_cvtpd2dq_2(evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem))), pfx),
          1 => evex_write_d_xmm(dst, avx_cvtpd2dq_4(evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem)), pfx),
          2 => evex_write_d_ymm(dst, avx_cvtpd2dq_8(evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem)), pfx),
          3 => raise_UD(),
        }
      },
      // VCVTTPD2DQ: f64→i32 (truncate, narrowing) — supports {sae}
      MP_66 => {
        match eff_ll {
          0 => evex_write_d_xmm(dst, zero_extend(avx_cvttpd2dq_2(evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem))), pfx),
          1 => evex_write_d_xmm(dst, avx_cvttpd2dq_4(evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem)), pfx),
          2 => evex_write_d_ymm(dst, avx_cvttpd2dq_8(evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem)), pfx),
          3 => raise_UD(),
        }
      },
      _ => raise_UD(),
    };
    evex_end_rc(saved_mxcsr)
  },

  _ => raise_UD(),
  }
}

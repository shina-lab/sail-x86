// AVX Instruction Helpers
//
// Lane-parallel FP operations on 128-bit and 256-bit vectors.
// These are pure Sail implementations — no host AVX intrinsics.

// =========================================================================
// 128-bit (XMM) packed FP — used by VEX decoder
// =========================================================================

val vaddps_xmm : (xmmword, xmmword) -> xmmword
function vaddps_xmm(a, b) =
  __f32_add(a[127..96], b[127..96]) @
  __f32_add(a[95..64],  b[95..64])  @
  __f32_add(a[63..32],  b[63..32])  @
  __f32_add(a[31..0],   b[31..0])

val vsubps_xmm : (xmmword, xmmword) -> xmmword
function vsubps_xmm(a, b) =
  __f32_sub(a[127..96], b[127..96]) @
  __f32_sub(a[95..64],  b[95..64])  @
  __f32_sub(a[63..32],  b[63..32])  @
  __f32_sub(a[31..0],   b[31..0])

val vmulps_xmm : (xmmword, xmmword) -> xmmword
function vmulps_xmm(a, b) =
  __f32_mul(a[127..96], b[127..96]) @
  __f32_mul(a[95..64],  b[95..64])  @
  __f32_mul(a[63..32],  b[63..32])  @
  __f32_mul(a[31..0],   b[31..0])

val vdivps_xmm : (xmmword, xmmword) -> xmmword
function vdivps_xmm(a, b) =
  __f32_div(a[127..96], b[127..96]) @
  __f32_div(a[95..64],  b[95..64])  @
  __f32_div(a[63..32],  b[63..32])  @
  __f32_div(a[31..0],   b[31..0])

val vminps_xmm : (xmmword, xmmword) -> xmmword
function vminps_xmm(a, b) =
  __f32_min(a[127..96], b[127..96]) @
  __f32_min(a[95..64],  b[95..64])  @
  __f32_min(a[63..32],  b[63..32])  @
  __f32_min(a[31..0],   b[31..0])

val vmaxps_xmm : (xmmword, xmmword) -> xmmword
function vmaxps_xmm(a, b) =
  __f32_max(a[127..96], b[127..96]) @
  __f32_max(a[95..64],  b[95..64])  @
  __f32_max(a[63..32],  b[63..32])  @
  __f32_max(a[31..0],   b[31..0])

val vsqrtps_xmm : xmmword -> xmmword
function vsqrtps_xmm(a) =
  __f32_sqrt(a[127..96]) @ __f32_sqrt(a[95..64]) @
  __f32_sqrt(a[63..32])  @ __f32_sqrt(a[31..0])

val vaddpd_xmm : (xmmword, xmmword) -> xmmword
function vaddpd_xmm(a, b) =
  __f64_add(a[127..64], b[127..64]) @ __f64_add(a[63..0], b[63..0])

val vsubpd_xmm : (xmmword, xmmword) -> xmmword
function vsubpd_xmm(a, b) =
  __f64_sub(a[127..64], b[127..64]) @ __f64_sub(a[63..0], b[63..0])

val vmulpd_xmm : (xmmword, xmmword) -> xmmword
function vmulpd_xmm(a, b) =
  __f64_mul(a[127..64], b[127..64]) @ __f64_mul(a[63..0], b[63..0])

val vdivpd_xmm : (xmmword, xmmword) -> xmmword
function vdivpd_xmm(a, b) =
  __f64_div(a[127..64], b[127..64]) @ __f64_div(a[63..0], b[63..0])

val vminpd_xmm : (xmmword, xmmword) -> xmmword
function vminpd_xmm(a, b) =
  __f64_min(a[127..64], b[127..64]) @ __f64_min(a[63..0], b[63..0])

val vmaxpd_xmm : (xmmword, xmmword) -> xmmword
function vmaxpd_xmm(a, b) =
  __f64_max(a[127..64], b[127..64]) @ __f64_max(a[63..0], b[63..0])

val vsqrtpd_xmm : xmmword -> xmmword
function vsqrtpd_xmm(a) =
  __f64_sqrt(a[127..64]) @ __f64_sqrt(a[63..0])

// =========================================================================
// 256-bit (YMM) packed FP helpers
// Implemented as: high_128 @ low_128 using XMM helpers.
// =========================================================================

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

val avx_paddb_128 : (xmmword, xmmword) -> xmmword
function avx_paddb_128(a, b) =
  (a[127..120] + b[127..120]) @ (a[119..112] + b[119..112]) @
  (a[111..104] + b[111..104]) @ (a[103..96]  + b[103..96])  @
  (a[95..88]   + b[95..88])   @ (a[87..80]   + b[87..80])   @
  (a[79..72]   + b[79..72])   @ (a[71..64]   + b[71..64])   @
  (a[63..56]   + b[63..56])   @ (a[55..48]   + b[55..48])   @
  (a[47..40]   + b[47..40])   @ (a[39..32]   + b[39..32])   @
  (a[31..24]   + b[31..24])   @ (a[23..16]   + b[23..16])   @
  (a[15..8]    + b[15..8])    @ (a[7..0]     + b[7..0])

val avx_paddb_256 : (ymmword, ymmword) -> ymmword
function avx_paddb_256(a, b) =
  avx_paddb_128(a[255..128], b[255..128]) @
  avx_paddb_128(a[127..0],   b[127..0])

val avx_paddw_128 : (xmmword, xmmword) -> xmmword
function avx_paddw_128(a, b) =
  (a[127..112] + b[127..112]) @ (a[111..96] + b[111..96]) @
  (a[95..80]   + b[95..80])   @ (a[79..64]  + b[79..64])  @
  (a[63..48]   + b[63..48])   @ (a[47..32]  + b[47..32])  @
  (a[31..16]   + b[31..16])   @ (a[15..0]   + b[15..0])

val avx_paddw_256 : (ymmword, ymmword) -> ymmword
function avx_paddw_256(a, b) =
  avx_paddw_128(a[255..128], b[255..128]) @
  avx_paddw_128(a[127..0],   b[127..0])

val avx_paddd_128 : (xmmword, xmmword) -> xmmword
function avx_paddd_128(a, b) =
  (a[127..96] + b[127..96]) @ (a[95..64] + b[95..64]) @
  (a[63..32]  + b[63..32])  @ (a[31..0]  + b[31..0])

val avx_paddd_256 : (ymmword, ymmword) -> ymmword
function avx_paddd_256(a, b) =
  avx_paddd_128(a[255..128], b[255..128]) @
  avx_paddd_128(a[127..0],   b[127..0])

val avx_paddq_128 : (xmmword, xmmword) -> xmmword
function avx_paddq_128(a, b) =
  (a[127..64] + b[127..64]) @ (a[63..0] + b[63..0])

val avx_paddq_256 : (ymmword, ymmword) -> ymmword
function avx_paddq_256(a, b) =
  avx_paddq_128(a[255..128], b[255..128]) @
  avx_paddq_128(a[127..0],   b[127..0])

val avx_psubb_128 : (xmmword, xmmword) -> xmmword
function avx_psubb_128(a, b) =
  (a[127..120] - b[127..120]) @ (a[119..112] - b[119..112]) @
  (a[111..104] - b[111..104]) @ (a[103..96]  - b[103..96])  @
  (a[95..88]   - b[95..88])   @ (a[87..80]   - b[87..80])   @
  (a[79..72]   - b[79..72])   @ (a[71..64]   - b[71..64])   @
  (a[63..56]   - b[63..56])   @ (a[55..48]   - b[55..48])   @
  (a[47..40]   - b[47..40])   @ (a[39..32]   - b[39..32])   @
  (a[31..24]   - b[31..24])   @ (a[23..16]   - b[23..16])   @
  (a[15..8]    - b[15..8])    @ (a[7..0]     - b[7..0])

val avx_psubb_256 : (ymmword, ymmword) -> ymmword
function avx_psubb_256(a, b) =
  avx_psubb_128(a[255..128], b[255..128]) @
  avx_psubb_128(a[127..0],   b[127..0])

val avx_psubw_128 : (xmmword, xmmword) -> xmmword
function avx_psubw_128(a, b) =
  (a[127..112] - b[127..112]) @ (a[111..96] - b[111..96]) @
  (a[95..80]   - b[95..80])   @ (a[79..64]  - b[79..64])  @
  (a[63..48]   - b[63..48])   @ (a[47..32]  - b[47..32])  @
  (a[31..16]   - b[31..16])   @ (a[15..0]   - b[15..0])

val avx_psubw_256 : (ymmword, ymmword) -> ymmword
function avx_psubw_256(a, b) =
  avx_psubw_128(a[255..128], b[255..128]) @
  avx_psubw_128(a[127..0],   b[127..0])

val avx_psubd_128 : (xmmword, xmmword) -> xmmword
function avx_psubd_128(a, b) =
  (a[127..96] - b[127..96]) @ (a[95..64] - b[95..64]) @
  (a[63..32]  - b[63..32])  @ (a[31..0]  - b[31..0])

val avx_psubd_256 : (ymmword, ymmword) -> ymmword
function avx_psubd_256(a, b) =
  avx_psubd_128(a[255..128], b[255..128]) @
  avx_psubd_128(a[127..0],   b[127..0])

val avx_psubq_128 : (xmmword, xmmword) -> xmmword
function avx_psubq_128(a, b) =
  (a[127..64] - b[127..64]) @ (a[63..0] - b[63..0])

val avx_psubq_256 : (ymmword, ymmword) -> ymmword
function avx_psubq_256(a, b) =
  avx_psubq_128(a[255..128], b[255..128]) @
  avx_psubq_128(a[127..0],   b[127..0])

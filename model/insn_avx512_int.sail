// AVX-512 Integer, FP, and Mask Instruction Helpers
//
// Combined helpers for AVX-512 operations including:
// - 256/512-bit FP arithmetic (YMM/ZMM)
// - Packed integer 256/512 add/sub/min/max/compare
// - AVX-512 opmask (k-register) operations
// - FP math (scalef, getexp, rcp14, rsqrt14, rcp28, rsqrt28, exp2)
// - FP16 conversion and comparison
// - GFNI, VPCLMULQDQ, VNNI, and other AVX-512 extensions

// =========================================================================
// YMM/ZMM packed FP helpers (from former avx.sail)
// =========================================================================

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

val avx_paddb_256 : (ymmword, ymmword) -> ymmword
function avx_paddb_256(a, b) =
  avx_paddb_128(a[255..128], b[255..128]) @
  avx_paddb_128(a[127..0],   b[127..0])

val avx_paddw_256 : (ymmword, ymmword) -> ymmword
function avx_paddw_256(a, b) =
  avx_paddw_128(a[255..128], b[255..128]) @
  avx_paddw_128(a[127..0],   b[127..0])

val avx_paddd_256 : (ymmword, ymmword) -> ymmword
function avx_paddd_256(a, b) =
  avx_paddd_128(a[255..128], b[255..128]) @
  avx_paddd_128(a[127..0],   b[127..0])

val avx_paddq_256 : (ymmword, ymmword) -> ymmword
function avx_paddq_256(a, b) =
  avx_paddq_128(a[255..128], b[255..128]) @
  avx_paddq_128(a[127..0],   b[127..0])

val avx_psubb_256 : (ymmword, ymmword) -> ymmword
function avx_psubb_256(a, b) =
  avx_psubb_128(a[255..128], b[255..128]) @
  avx_psubb_128(a[127..0],   b[127..0])

val avx_psubw_256 : (ymmword, ymmword) -> ymmword
function avx_psubw_256(a, b) =
  avx_psubw_128(a[255..128], b[255..128]) @
  avx_psubw_128(a[127..0],   b[127..0])

val avx_psubd_256 : (ymmword, ymmword) -> ymmword
function avx_psubd_256(a, b) =
  avx_psubd_128(a[255..128], b[255..128]) @
  avx_psubd_128(a[127..0],   b[127..0])

val avx_psubq_256 : (ymmword, ymmword) -> ymmword
function avx_psubq_256(a, b) =
  avx_psubq_128(a[255..128], b[255..128]) @
  avx_psubq_128(a[127..0],   b[127..0])

// =========================================================================
// 512-bit (ZMM) packed FP helpers
// Implemented as: high_256 @ low_256 using YMM helpers.
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

val avx_paddb_512 : (zmmword, zmmword) -> zmmword
function avx_paddb_512(a, b) =
  avx_paddb_256(a[511..256], b[511..256]) @
  avx_paddb_256(a[255..0],   b[255..0])

val avx_paddw_512 : (zmmword, zmmword) -> zmmword
function avx_paddw_512(a, b) =
  avx_paddw_256(a[511..256], b[511..256]) @
  avx_paddw_256(a[255..0],   b[255..0])

val avx_paddd_512 : (zmmword, zmmword) -> zmmword
function avx_paddd_512(a, b) =
  avx_paddd_256(a[511..256], b[511..256]) @
  avx_paddd_256(a[255..0],   b[255..0])

val avx_paddq_512 : (zmmword, zmmword) -> zmmword
function avx_paddq_512(a, b) =
  avx_paddq_256(a[511..256], b[511..256]) @
  avx_paddq_256(a[255..0],   b[255..0])

val avx_psubb_512 : (zmmword, zmmword) -> zmmword
function avx_psubb_512(a, b) =
  avx_psubb_256(a[511..256], b[511..256]) @
  avx_psubb_256(a[255..0],   b[255..0])

val avx_psubw_512 : (zmmword, zmmword) -> zmmword
function avx_psubw_512(a, b) =
  avx_psubw_256(a[511..256], b[511..256]) @
  avx_psubw_256(a[255..0],   b[255..0])

val avx_psubd_512 : (zmmword, zmmword) -> zmmword
function avx_psubd_512(a, b) =
  avx_psubd_256(a[511..256], b[511..256]) @
  avx_psubd_256(a[255..0],   b[255..0])

val avx_psubq_512 : (zmmword, zmmword) -> zmmword
function avx_psubq_512(a, b) =
  avx_psubq_256(a[511..256], b[511..256]) @
  avx_psubq_256(a[255..0],   b[255..0])

// =========================================================================
// AVX-512 writemask helpers
//
// Per SDM: if aaa=0 (k0), no masking (all elements written).
// Otherwise, each bit of the mask register controls one element.
// z=0: merging (unmasked elements keep old dest value)
// z=1: zeroing (unmasked elements become zero)
// =========================================================================

// Apply 16-bit writemask to a 512-bit ZMM result (32-bit elements, 16 lanes).
// mask_val is the low 16 bits of the mask register.
// old_dst is the previous destination value (for merging).
val apply_writemask_ps_zmm : (zmmword, zmmword, word, bool) -> zmmword
function apply_writemask_ps_zmm(result, old_dst, mask_val, zeroing) = {
  var r : zmmword = if zeroing then zeros() else old_dst;
  if mask_val[15] == bitone then r[511..480] = result[511..480];
  if mask_val[14] == bitone then r[479..448] = result[479..448];
  if mask_val[13] == bitone then r[447..416] = result[447..416];
  if mask_val[12] == bitone then r[415..384] = result[415..384];
  if mask_val[11] == bitone then r[383..352] = result[383..352];
  if mask_val[10] == bitone then r[351..320] = result[351..320];
  if mask_val[9]  == bitone then r[319..288] = result[319..288];
  if mask_val[8]  == bitone then r[287..256] = result[287..256];
  if mask_val[7]  == bitone then r[255..224] = result[255..224];
  if mask_val[6]  == bitone then r[223..192] = result[223..192];
  if mask_val[5]  == bitone then r[191..160] = result[191..160];
  if mask_val[4]  == bitone then r[159..128] = result[159..128];
  if mask_val[3]  == bitone then r[127..96]  = result[127..96];
  if mask_val[2]  == bitone then r[95..64]   = result[95..64];
  if mask_val[1]  == bitone then r[63..32]   = result[63..32];
  if mask_val[0]  == bitone then r[31..0]    = result[31..0];
  r
}

// Apply 8-bit writemask to a 512-bit ZMM result (64-bit elements, 8 lanes).
val apply_writemask_pd_zmm : (zmmword, zmmword, byte, bool) -> zmmword
function apply_writemask_pd_zmm(result, old_dst, mask_val, zeroing) = {
  var r : zmmword = if zeroing then zeros() else old_dst;
  if mask_val[7] == bitone then r[511..448] = result[511..448];
  if mask_val[6] == bitone then r[447..384] = result[447..384];
  if mask_val[5] == bitone then r[383..320] = result[383..320];
  if mask_val[4] == bitone then r[319..256] = result[319..256];
  if mask_val[3] == bitone then r[255..192] = result[255..192];
  if mask_val[2] == bitone then r[191..128] = result[191..128];
  if mask_val[1] == bitone then r[127..64]  = result[127..64];
  if mask_val[0] == bitone then r[63..0]    = result[63..0];
  r
}

// Broadcast a 32-bit value to all 16 dword lanes of a ZMM register.
val broadcast_f32_zmm : dword -> zmmword
function broadcast_f32_zmm(v) =
  v @ v @ v @ v @ v @ v @ v @ v @
  v @ v @ v @ v @ v @ v @ v @ v

// Broadcast a 64-bit value to all 8 qword lanes of a ZMM register.
val broadcast_f32_ymm : dword -> ymmword
function broadcast_f32_ymm(v) =
  v @ v @ v @ v @ v @ v @ v @ v

val broadcast_f32_xmm : dword -> xmmword
function broadcast_f32_xmm(v) =
  v @ v @ v @ v

val broadcast_f64_zmm : qword -> zmmword
function broadcast_f64_zmm(v) =
  v @ v @ v @ v @ v @ v @ v @ v

val broadcast_f64_ymm : qword -> ymmword
function broadcast_f64_ymm(v) =
  v @ v @ v @ v

// Broadcast a byte to all lanes
val broadcast_byte_zmm : byte -> zmmword
function broadcast_byte_zmm(v) = {
  let w : word = v @ v;
  let d : dword = w @ w;
  let q : qword = d @ d;
  let x : xmmword = q @ q;
  let y : ymmword = x @ x;
  y @ y
}

val broadcast_byte_ymm : byte -> ymmword
function broadcast_byte_ymm(v) = {
  let w : word = v @ v;
  let d : dword = w @ w;
  let q : qword = d @ d;
  let x : xmmword = q @ q;
  x @ x
}

val broadcast_byte_xmm : byte -> xmmword
function broadcast_byte_xmm(v) = {
  let w : word = v @ v;
  let d : dword = w @ w;
  let q : qword = d @ d;
  q @ q
}

// =========================================================================
// AVX-512 packed unsigned byte minimum
// =========================================================================

val avx_pminub_128 : (xmmword, xmmword) -> xmmword
function avx_pminub_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 15) {
    let lo = i * 8;
    let hi = lo + 7;
    let av : byte = a[(hi)..(lo)];
    let bv : byte = b[(hi)..(lo)];
    r[(hi)..(lo)] = if unsigned(av) < unsigned(bv) then av else bv
  };
  r
}

val avx_pminub_256 : (ymmword, ymmword) -> ymmword
function avx_pminub_256(a, b) =
  avx_pminub_128(a[255..128], b[255..128]) @
  avx_pminub_128(a[127..0], b[127..0])

val avx_pminub_512 : (zmmword, zmmword) -> zmmword
function avx_pminub_512(a, b) =
  avx_pminub_256(a[511..256], b[511..256]) @
  avx_pminub_256(a[255..0], b[255..0])

// =========================================================================
// AVX-512 packed unsigned dword minimum
// =========================================================================

val avx_pminud_128 : (xmmword, xmmword) -> xmmword
function avx_pminud_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo = i * 32;
    let hi = lo + 31;
    let av : dword = a[(hi)..(lo)];
    let bv : dword = b[(hi)..(lo)];
    r[(hi)..(lo)] = if unsigned(av) < unsigned(bv) then av else bv
  };
  r
}

val avx_pminud_256 : (ymmword, ymmword) -> ymmword
function avx_pminud_256(a, b) =
  avx_pminud_128(a[255..128], b[255..128]) @
  avx_pminud_128(a[127..0], b[127..0])

val avx_pminud_512 : (zmmword, zmmword) -> zmmword
function avx_pminud_512(a, b) =
  avx_pminud_256(a[511..256], b[511..256]) @
  avx_pminud_256(a[255..0], b[255..0])

// =========================================================================
// AVX-512 VPCMPEQB — compare bytes for equal, produce kmask
// Each byte lane: if a[i] == b[i] then mask bit = 1, else 0
// =========================================================================

val avx_pcmpeqb_mask_128 : (xmmword, xmmword) -> word
function avx_pcmpeqb_mask_128(a, b) = {
  var r : word = zeros();
  foreach (i from 0 to 15) {
    let lo = i * 8;
    let hi = lo + 7;
    if a[(hi)..(lo)] == b[(hi)..(lo)] then r[i] = bitone
  };
  r
}

val avx_pcmpeqb_mask_256 : (ymmword, ymmword) -> dword
function avx_pcmpeqb_mask_256(a, b) = {
  var r : dword = zeros();
  foreach (i from 0 to 31) {
    let lo = i * 8;
    let hi = lo + 7;
    if a[(hi)..(lo)] == b[(hi)..(lo)] then r[i] = bitone
  };
  r
}

val avx_pcmpeqb_mask_512 : (zmmword, zmmword) -> qword
function avx_pcmpeqb_mask_512(a, b) = {
  var r : qword = zeros();
  foreach (i from 0 to 63) {
    let lo = i * 8;
    let hi = lo + 7;
    if a[(hi)..(lo)] == b[(hi)..(lo)] then r[i] = bitone
  };
  r
}

// =========================================================================
// VPTESTMB: mask[i] = (a[i] AND b[i]) != 0
// VPTESTNMB: mask[i] = (a[i] AND b[i]) == 0
// =========================================================================

val avx_ptestmb_512 : (zmmword, zmmword) -> qword
function avx_ptestmb_512(a, b) = {
  var r : qword = zeros();
  foreach (i from 0 to 63) {
    let lo = i * 8;
    let hi = lo + 7;
    if (a[(hi)..(lo)] & b[(hi)..(lo)]) != zeros() then r[i] = bitone
  };
  r
}

val avx_ptestnmb_512 : (zmmword, zmmword) -> qword
function avx_ptestnmb_512(a, b) = {
  var r : qword = zeros();
  foreach (i from 0 to 63) {
    let lo = i * 8;
    let hi = lo + 7;
    if (a[(hi)..(lo)] & b[(hi)..(lo)]) == zeros() then r[i] = bitone
  };
  r
}

val avx_ptestmb_256 : (ymmword, ymmword) -> dword
function avx_ptestmb_256(a, b) = {
  var r : dword = zeros();
  foreach (i from 0 to 31) {
    let lo = i * 8;
    let hi = lo + 7;
    if (a[(hi)..(lo)] & b[(hi)..(lo)]) != zeros() then r[i] = bitone
  };
  r
}

val avx_ptestnmb_256 : (ymmword, ymmword) -> dword
function avx_ptestnmb_256(a, b) = {
  var r : dword = zeros();
  foreach (i from 0 to 31) {
    let lo = i * 8;
    let hi = lo + 7;
    if (a[(hi)..(lo)] & b[(hi)..(lo)]) == zeros() then r[i] = bitone
  };
  r
}

val avx_ptestmb_128 : (xmmword, xmmword) -> word
function avx_ptestmb_128(a, b) = {
  var r : word = zeros();
  foreach (i from 0 to 15) {
    let lo = i * 8;
    let hi = lo + 7;
    if (a[(hi)..(lo)] & b[(hi)..(lo)]) != zeros() then r[i] = bitone
  };
  r
}

val avx_ptestnmb_128 : (xmmword, xmmword) -> word
function avx_ptestnmb_128(a, b) = {
  var r : word = zeros();
  foreach (i from 0 to 15) {
    let lo = i * 8;
    let hi = lo + 7;
    if (a[(hi)..(lo)] & b[(hi)..(lo)]) == zeros() then r[i] = bitone
  };
  r
}

// =========================================================================
// VPTESTMD/VPTESTNMD: dword version
// =========================================================================

val avx_ptestmd_512 : (zmmword, zmmword) -> word
function avx_ptestmd_512(a, b) = {
  var r : word = zeros();
  foreach (i from 0 to 15) {
    let lo = i * 32;
    let hi = lo + 31;
    if (a[(hi)..(lo)] & b[(hi)..(lo)]) != zeros() then r[i] = bitone
  };
  r
}

val avx_ptestnmd_512 : (zmmword, zmmword) -> word
function avx_ptestnmd_512(a, b) = {
  var r : word = zeros();
  foreach (i from 0 to 15) {
    let lo = i * 32;
    let hi = lo + 31;
    if (a[(hi)..(lo)] & b[(hi)..(lo)]) == zeros() then r[i] = bitone
  };
  r
}

val avx_ptestmd_256 : (ymmword, ymmword) -> byte
function avx_ptestmd_256(a, b) = {
  var r : byte = zeros();
  foreach (i from 0 to 7) {
    let lo = i * 32;
    let hi = lo + 31;
    if (a[(hi)..(lo)] & b[(hi)..(lo)]) != zeros() then r[i] = bitone
  };
  r
}

val avx_ptestnmd_256 : (ymmword, ymmword) -> byte
function avx_ptestnmd_256(a, b) = {
  var r : byte = zeros();
  foreach (i from 0 to 7) {
    let lo = i * 32;
    let hi = lo + 31;
    if (a[(hi)..(lo)] & b[(hi)..(lo)]) == zeros() then r[i] = bitone
  };
  r
}

// =========================================================================
// VPCMPUB: compare unsigned bytes with imm8 predicate, produce kmask
// imm8: 0=eq, 1=lt, 2=le, 4=neq, 5=nlt(>=), 6=nle(>)
// =========================================================================

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

val avx_pcmpub_512 : (zmmword, zmmword, range(0, 7)) -> qword
function avx_pcmpub_512(a, b, pred) = {
  var r : qword = zeros();
  foreach (i from 0 to 63) {
    let lo = i * 8;
    let hi = lo + 7;
    if cmp_ub_pred(a[(hi)..(lo)], b[(hi)..(lo)], pred) then r[i] = bitone
  };
  r
}

val avx_pcmpub_256 : (ymmword, ymmword, range(0, 7)) -> dword
function avx_pcmpub_256(a, b, pred) = {
  var r : dword = zeros();
  foreach (i from 0 to 31) {
    let lo = i * 8;
    let hi = lo + 7;
    if cmp_ub_pred(a[(hi)..(lo)], b[(hi)..(lo)], pred) then r[i] = bitone
  };
  r
}

val avx_pcmpub_128 : (xmmword, xmmword, range(0, 7)) -> word
function avx_pcmpub_128(a, b, pred) = {
  var r : word = zeros();
  foreach (i from 0 to 15) {
    let lo = i * 8;
    let hi = lo + 7;
    if cmp_ub_pred(a[(hi)..(lo)], b[(hi)..(lo)], pred) then r[i] = bitone
  };
  r
}

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

val avx_pcmpb_512 : (zmmword, zmmword, range(0, 7)) -> qword
function avx_pcmpb_512(a, b, pred) = {
  var r : qword = zeros();
  foreach (i from 0 to 63) {
    let lo = i * 8;
    let hi = lo + 7;
    if cmp_sb_pred(a[(hi)..(lo)], b[(hi)..(lo)], pred) then r[i] = bitone
  };
  r
}

val avx_pcmpb_256 : (ymmword, ymmword, range(0, 7)) -> dword
function avx_pcmpb_256(a, b, pred) = {
  var r : dword = zeros();
  foreach (i from 0 to 31) {
    let lo = i * 8;
    let hi = lo + 7;
    if cmp_sb_pred(a[(hi)..(lo)], b[(hi)..(lo)], pred) then r[i] = bitone
  };
  r
}

val avx_pcmpb_128 : (xmmword, xmmword, range(0, 7)) -> word
function avx_pcmpb_128(a, b, pred) = {
  var r : word = zeros();
  foreach (i from 0 to 15) {
    let lo = i * 8;
    let hi = lo + 7;
    if cmp_sb_pred(a[(hi)..(lo)], b[(hi)..(lo)], pred) then r[i] = bitone
  };
  r
}

// VPCMPEQD producing kmask
val avx_pcmpeqd_mask_128 : (xmmword, xmmword) -> byte
function avx_pcmpeqd_mask_128(a, b) = {
  var r : byte = zeros();
  foreach (i from 0 to 3) {
    let lo = i * 32; let hi = lo + 31;
    if a[(hi)..(lo)] == b[(hi)..(lo)] then r[i] = bitone
  };
  r
}

val avx_pcmpeqd_mask_256 : (ymmword, ymmword) -> byte
function avx_pcmpeqd_mask_256(a, b) = {
  var r : byte = zeros();
  foreach (i from 0 to 7) {
    let lo = i * 32; let hi = lo + 31;
    if a[(hi)..(lo)] == b[(hi)..(lo)] then r[i] = bitone
  };
  r
}

val avx_pcmpeqd_mask_512 : (zmmword, zmmword) -> word
function avx_pcmpeqd_mask_512(a, b) = {
  var r : word = zeros();
  foreach (i from 0 to 15) {
    let lo = i * 32; let hi = lo + 31;
    if a[(hi)..(lo)] == b[(hi)..(lo)] then r[i] = bitone
  };
  r
}

// VPCMPNEQD producing kmask (neq = pred 4)
// Reusing VPCMPUB pattern but for dwords
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

val avx_pcmpud_512 : (zmmword, zmmword, range(0, 7)) -> word
function avx_pcmpud_512(a, b, pred) = {
  var r : word = zeros();
  foreach (i from 0 to 15) {
    let lo = i * 32; let hi = lo + 31;
    if cmp_ud_pred(a[(hi)..(lo)], b[(hi)..(lo)], pred) then r[i] = bitone
  };
  r
}

val avx_pcmpud_256 : (ymmword, ymmword, range(0, 7)) -> byte
function avx_pcmpud_256(a, b, pred) = {
  var r : byte = zeros();
  foreach (i from 0 to 7) {
    let lo = i * 32; let hi = lo + 31;
    if cmp_ud_pred(a[(hi)..(lo)], b[(hi)..(lo)], pred) then r[i] = bitone
  };
  r
}

val avx_pcmpud_128 : (xmmword, xmmword, range(0, 7)) -> byte
function avx_pcmpud_128(a, b, pred) = {
  var r : byte = zeros();
  foreach (i from 0 to 3) {
    let lo = i * 32; let hi = lo + 31;
    if cmp_ud_pred(a[(hi)..(lo)], b[(hi)..(lo)], pred) then r[i] = bitone
  };
  r
}

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

val exec_kaddb : (kreg_idx, kreg_idx, kreg_idx) -> ExecutionResult
function exec_kaddb(dst, src1, src2) = {
  let a : byte = read_kreg(src1)[7..0];
  let b : byte = read_kreg(src2)[7..0];
  write_kreg(dst, zero_extend(a + b));
  Ok(())
}

val exec_kaddw : (kreg_idx, kreg_idx, kreg_idx) -> ExecutionResult
function exec_kaddw(dst, src1, src2) = {
  let a : word = read_kreg(src1)[15..0];
  let b : word = read_kreg(src2)[15..0];
  write_kreg(dst, zero_extend(a + b));
  Ok(())
}

val exec_kaddd : (kreg_idx, kreg_idx, kreg_idx) -> ExecutionResult
function exec_kaddd(dst, src1, src2) = {
  let a : dword = read_kreg(src1)[31..0];
  let b : dword = read_kreg(src2)[31..0];
  write_kreg(dst, zero_extend(a + b));
  Ok(())
}

val exec_kaddq : (kreg_idx, kreg_idx, kreg_idx) -> ExecutionResult
function exec_kaddq(dst, src1, src2) = {
  let a : qword = read_kreg(src1);
  let b : qword = read_kreg(src2);
  write_kreg(dst, a + b);
  Ok(())
}

// =========================================================================
// KAND -- Bitwise Logical AND Mask Registers
// =========================================================================

val exec_kandb : (kreg_idx, kreg_idx, kreg_idx) -> ExecutionResult
function exec_kandb(dst, src1, src2) = {
  write_kreg(dst, zero_extend(read_kreg(src1)[7..0] & read_kreg(src2)[7..0]));
  Ok(())
}

val exec_kandw : (kreg_idx, kreg_idx, kreg_idx) -> ExecutionResult
function exec_kandw(dst, src1, src2) = {
  write_kreg(dst, zero_extend(read_kreg(src1)[15..0] & read_kreg(src2)[15..0]));
  Ok(())
}

val exec_kandd : (kreg_idx, kreg_idx, kreg_idx) -> ExecutionResult
function exec_kandd(dst, src1, src2) = {
  write_kreg(dst, zero_extend(read_kreg(src1)[31..0] & read_kreg(src2)[31..0]));
  Ok(())
}

val exec_kandq : (kreg_idx, kreg_idx, kreg_idx) -> ExecutionResult
function exec_kandq(dst, src1, src2) = {
  write_kreg(dst, read_kreg(src1) & read_kreg(src2));
  Ok(())
}

// =========================================================================
// KANDN -- Bitwise Logical AND NOT Mask Registers
// =========================================================================

val exec_kandnb : (kreg_idx, kreg_idx, kreg_idx) -> ExecutionResult
function exec_kandnb(dst, src1, src2) = {
  write_kreg(dst, zero_extend((~(read_kreg(src1)[7..0])) & read_kreg(src2)[7..0]));
  Ok(())
}

val exec_kandnw : (kreg_idx, kreg_idx, kreg_idx) -> ExecutionResult
function exec_kandnw(dst, src1, src2) = {
  write_kreg(dst, zero_extend((~(read_kreg(src1)[15..0])) & read_kreg(src2)[15..0]));
  Ok(())
}

val exec_kandnd : (kreg_idx, kreg_idx, kreg_idx) -> ExecutionResult
function exec_kandnd(dst, src1, src2) = {
  write_kreg(dst, zero_extend((~(read_kreg(src1)[31..0])) & read_kreg(src2)[31..0]));
  Ok(())
}

val exec_kandnq : (kreg_idx, kreg_idx, kreg_idx) -> ExecutionResult
function exec_kandnq(dst, src1, src2) = {
  write_kreg(dst, (~(read_kreg(src1))) & read_kreg(src2));
  Ok(())
}

// =========================================================================
// KMOV -- Move Mask Register
// =========================================================================

val exec_kmovb_kreg_kreg : (kreg_idx, kreg_idx) -> ExecutionResult
function exec_kmovb_kreg_kreg(dst, src) = {
  write_kreg(dst, zero_extend(read_kreg(src)[7..0]));
  Ok(())
}

val exec_kmovw_kreg_kreg : (kreg_idx, kreg_idx) -> ExecutionResult
function exec_kmovw_kreg_kreg(dst, src) = {
  write_kreg(dst, zero_extend(read_kreg(src)[15..0]));
  Ok(())
}

val exec_kmovd_kreg_kreg : (kreg_idx, kreg_idx) -> ExecutionResult
function exec_kmovd_kreg_kreg(dst, src) = {
  write_kreg(dst, zero_extend(read_kreg(src)[31..0]));
  Ok(())
}

val exec_kmovq_kreg_kreg : (kreg_idx, kreg_idx) -> ExecutionResult
function exec_kmovq_kreg_kreg(dst, src) = {
  write_kreg(dst, read_kreg(src));
  Ok(())
}

val exec_kmovb_kreg_gpr : (kreg_idx, dword) -> ExecutionResult
function exec_kmovb_kreg_gpr(dst, src) = {
  write_kreg(dst, zero_extend(src[7..0]));
  Ok(())
}

val exec_kmovw_kreg_gpr : (kreg_idx, dword) -> ExecutionResult
function exec_kmovw_kreg_gpr(dst, src) = {
  write_kreg(dst, zero_extend(src[15..0]));
  Ok(())
}

val exec_kmovd_kreg_gpr : (kreg_idx, dword) -> ExecutionResult
function exec_kmovd_kreg_gpr(dst, src) = {
  write_kreg(dst, zero_extend(src));
  Ok(())
}

val exec_kmovq_kreg_gpr : (kreg_idx, qword) -> ExecutionResult
function exec_kmovq_kreg_gpr(dst, src) = {
  write_kreg(dst, src);
  Ok(())
}

val exec_kmovb_gpr_kreg : (gpr_idx, kreg_idx) -> ExecutionResult
function exec_kmovb_gpr_kreg(dst, src) = {
  write_gpr(dst, OS32, zero_extend(read_kreg(src)[7..0]));
  Ok(())
}

val exec_kmovw_gpr_kreg : (gpr_idx, kreg_idx) -> ExecutionResult
function exec_kmovw_gpr_kreg(dst, src) = {
  write_gpr(dst, OS32, zero_extend(read_kreg(src)[15..0]));
  Ok(())
}

val exec_kmovd_gpr_kreg : (gpr_idx, kreg_idx) -> ExecutionResult
function exec_kmovd_gpr_kreg(dst, src) = {
  write_gpr(dst, OS32, zero_extend(read_kreg(src)[31..0]));
  Ok(())
}

val exec_kmovq_gpr_kreg : (gpr_idx, kreg_idx) -> ExecutionResult
function exec_kmovq_gpr_kreg(dst, src) = {
  write_gpr(dst, OS64, read_kreg(src));
  Ok(())
}

// =========================================================================
// KNOT -- NOT Mask Register
// =========================================================================

val exec_knotb : (kreg_idx, kreg_idx) -> ExecutionResult
function exec_knotb(dst, src) = {
  write_kreg(dst, zero_extend(~(read_kreg(src)[7..0])));
  Ok(())
}

val exec_knotw : (kreg_idx, kreg_idx) -> ExecutionResult
function exec_knotw(dst, src) = {
  write_kreg(dst, zero_extend(~(read_kreg(src)[15..0])));
  Ok(())
}

val exec_knotd : (kreg_idx, kreg_idx) -> ExecutionResult
function exec_knotd(dst, src) = {
  write_kreg(dst, zero_extend(~(read_kreg(src)[31..0])));
  Ok(())
}

val exec_knotq : (kreg_idx, kreg_idx) -> ExecutionResult
function exec_knotq(dst, src) = {
  write_kreg(dst, ~(read_kreg(src)));
  Ok(())
}

// =========================================================================
// KOR -- Bitwise Logical OR Mask Registers
// =========================================================================

val exec_korb : (kreg_idx, kreg_idx, kreg_idx) -> ExecutionResult
function exec_korb(dst, src1, src2) = {
  write_kreg(dst, zero_extend(read_kreg(src1)[7..0] | read_kreg(src2)[7..0]));
  Ok(())
}

val exec_korw : (kreg_idx, kreg_idx, kreg_idx) -> ExecutionResult
function exec_korw(dst, src1, src2) = {
  write_kreg(dst, zero_extend(read_kreg(src1)[15..0] | read_kreg(src2)[15..0]));
  Ok(())
}

val exec_kord : (kreg_idx, kreg_idx, kreg_idx) -> ExecutionResult
function exec_kord(dst, src1, src2) = {
  write_kreg(dst, zero_extend(read_kreg(src1)[31..0] | read_kreg(src2)[31..0]));
  Ok(())
}

val exec_korq : (kreg_idx, kreg_idx, kreg_idx) -> ExecutionResult
function exec_korq(dst, src1, src2) = {
  write_kreg(dst, read_kreg(src1) | read_kreg(src2));
  Ok(())
}

// =========================================================================
// KORTEST -- OR Mask and Set Flags
// =========================================================================

val exec_kortestb : (kreg_idx, kreg_idx) -> ExecutionResult
function exec_kortestb(src1, src2) = {
  let tmp : byte = read_kreg(src1)[7..0] | read_kreg(src2)[7..0];
  ZF = if tmp == 0x00 then bitone else bitzero;
  CF = if tmp == 0xFF then bitone else bitzero;
  SF = bitzero; OF = bitzero; AF = bitzero; PF = bitzero;
  Ok(())
}

val exec_kortestw : (kreg_idx, kreg_idx) -> ExecutionResult
function exec_kortestw(src1, src2) = {
  let tmp : word = read_kreg(src1)[15..0] | read_kreg(src2)[15..0];
  ZF = if tmp == 0x0000 then bitone else bitzero;
  CF = if tmp == 0xFFFF then bitone else bitzero;
  SF = bitzero; OF = bitzero; AF = bitzero; PF = bitzero;
  Ok(())
}

val exec_kortestd : (kreg_idx, kreg_idx) -> ExecutionResult
function exec_kortestd(src1, src2) = {
  let tmp : dword = read_kreg(src1)[31..0] | read_kreg(src2)[31..0];
  ZF = if tmp == 0x00000000 then bitone else bitzero;
  CF = if tmp == 0xFFFFFFFF then bitone else bitzero;
  SF = bitzero; OF = bitzero; AF = bitzero; PF = bitzero;
  Ok(())
}

val exec_kortestq : (kreg_idx, kreg_idx) -> ExecutionResult
function exec_kortestq(src1, src2) = {
  let tmp : qword = read_kreg(src1) | read_kreg(src2);
  ZF = if tmp == 0x0000000000000000 then bitone else bitzero;
  CF = if tmp == 0xFFFFFFFFFFFFFFFF then bitone else bitzero;
  SF = bitzero; OF = bitzero; AF = bitzero; PF = bitzero;
  Ok(())
}

// =========================================================================
// KSHIFTL -- Shift Left Mask Register
// =========================================================================

val exec_kshiftlb : (kreg_idx, kreg_idx, byte) -> ExecutionResult
function exec_kshiftlb(dst, src, imm8) = {
  let count : int = unsigned(imm8);
  let result : byte = if count <= 7 then shift_bits_left(read_kreg(src)[7..0], imm8[2..0]) else 0x00;
  write_kreg(dst, zero_extend(result));
  Ok(())
}

val exec_kshiftlw : (kreg_idx, kreg_idx, byte) -> ExecutionResult
function exec_kshiftlw(dst, src, imm8) = {
  let count : int = unsigned(imm8);
  let result : word = if count <= 15 then shift_bits_left(read_kreg(src)[15..0], imm8[3..0]) else 0x0000;
  write_kreg(dst, zero_extend(result));
  Ok(())
}

val exec_kshiftld : (kreg_idx, kreg_idx, byte) -> ExecutionResult
function exec_kshiftld(dst, src, imm8) = {
  let count : int = unsigned(imm8);
  let result : dword = if count <= 31 then shift_bits_left(read_kreg(src)[31..0], imm8[4..0]) else 0x00000000;
  write_kreg(dst, zero_extend(result));
  Ok(())
}

val exec_kshiftlq : (kreg_idx, kreg_idx, byte) -> ExecutionResult
function exec_kshiftlq(dst, src, imm8) = {
  let count : int = unsigned(imm8);
  let result : qword = if count <= 63 then shift_bits_left(read_kreg(src), imm8[5..0]) else 0x0000000000000000;
  write_kreg(dst, result);
  Ok(())
}

// =========================================================================
// KSHIFTR -- Shift Right Mask Register
// =========================================================================

val exec_kshiftrb : (kreg_idx, kreg_idx, byte) -> ExecutionResult
function exec_kshiftrb(dst, src, imm8) = {
  let count : int = unsigned(imm8);
  let result : byte = if count <= 7 then shift_bits_right(read_kreg(src)[7..0], imm8[2..0]) else 0x00;
  write_kreg(dst, zero_extend(result));
  Ok(())
}

val exec_kshiftrw : (kreg_idx, kreg_idx, byte) -> ExecutionResult
function exec_kshiftrw(dst, src, imm8) = {
  let count : int = unsigned(imm8);
  let result : word = if count <= 15 then shift_bits_right(read_kreg(src)[15..0], imm8[3..0]) else 0x0000;
  write_kreg(dst, zero_extend(result));
  Ok(())
}

val exec_kshiftrd : (kreg_idx, kreg_idx, byte) -> ExecutionResult
function exec_kshiftrd(dst, src, imm8) = {
  let count : int = unsigned(imm8);
  let result : dword = if count <= 31 then shift_bits_right(read_kreg(src)[31..0], imm8[4..0]) else 0x00000000;
  write_kreg(dst, zero_extend(result));
  Ok(())
}

val exec_kshiftrq : (kreg_idx, kreg_idx, byte) -> ExecutionResult
function exec_kshiftrq(dst, src, imm8) = {
  let count : int = unsigned(imm8);
  let result : qword = if count <= 63 then shift_bits_right(read_kreg(src), imm8[5..0]) else 0x0000000000000000;
  write_kreg(dst, result);
  Ok(())
}

// =========================================================================
// KTEST -- AND Mask and Set Flags
// =========================================================================

val exec_ktestb : (kreg_idx, kreg_idx) -> ExecutionResult
function exec_ktestb(src1, src2) = {
  let s1 : byte = read_kreg(src1)[7..0];
  let s2 : byte = read_kreg(src2)[7..0];
  ZF = if (s2 & s1) == 0x00 then bitone else bitzero;
  CF = if (s2 & ~(s1)) == 0x00 then bitone else bitzero;
  SF = bitzero; OF = bitzero; AF = bitzero; PF = bitzero;
  Ok(())
}

val exec_ktestw : (kreg_idx, kreg_idx) -> ExecutionResult
function exec_ktestw(src1, src2) = {
  let s1 : word = read_kreg(src1)[15..0];
  let s2 : word = read_kreg(src2)[15..0];
  ZF = if (s2 & s1) == 0x0000 then bitone else bitzero;
  CF = if (s2 & ~(s1)) == 0x0000 then bitone else bitzero;
  SF = bitzero; OF = bitzero; AF = bitzero; PF = bitzero;
  Ok(())
}

val exec_ktestd : (kreg_idx, kreg_idx) -> ExecutionResult
function exec_ktestd(src1, src2) = {
  let s1 : dword = read_kreg(src1)[31..0];
  let s2 : dword = read_kreg(src2)[31..0];
  ZF = if (s2 & s1) == 0x00000000 then bitone else bitzero;
  CF = if (s2 & ~(s1)) == 0x00000000 then bitone else bitzero;
  SF = bitzero; OF = bitzero; AF = bitzero; PF = bitzero;
  Ok(())
}

val exec_ktestq : (kreg_idx, kreg_idx) -> ExecutionResult
function exec_ktestq(src1, src2) = {
  let s1 : qword = read_kreg(src1);
  let s2 : qword = read_kreg(src2);
  ZF = if (s2 & s1) == 0x0000000000000000 then bitone else bitzero;
  CF = if (s2 & ~(s1)) == 0x0000000000000000 then bitone else bitzero;
  SF = bitzero; OF = bitzero; AF = bitzero; PF = bitzero;
  Ok(())
}

// =========================================================================
// KUNPCK -- Unpack Mask Registers
// =========================================================================

val exec_kunpckbw : (kreg_idx, kreg_idx, kreg_idx) -> ExecutionResult
function exec_kunpckbw(dst, src1, src2) = {
  write_kreg(dst, zero_extend(read_kreg(src1)[7..0] @ read_kreg(src2)[7..0]));
  Ok(())
}

val exec_kunpckwd : (kreg_idx, kreg_idx, kreg_idx) -> ExecutionResult
function exec_kunpckwd(dst, src1, src2) = {
  write_kreg(dst, zero_extend(read_kreg(src1)[15..0] @ read_kreg(src2)[15..0]));
  Ok(())
}

val exec_kunpckdq : (kreg_idx, kreg_idx, kreg_idx) -> ExecutionResult
function exec_kunpckdq(dst, src1, src2) = {
  write_kreg(dst, read_kreg(src1)[31..0] @ read_kreg(src2)[31..0]);
  Ok(())
}

// =========================================================================
// KXNOR -- Bitwise Logical XNOR Mask Registers
// =========================================================================

val exec_kxnorb : (kreg_idx, kreg_idx, kreg_idx) -> ExecutionResult
function exec_kxnorb(dst, src1, src2) = {
  write_kreg(dst, zero_extend(~(xor_vec(read_kreg(src1)[7..0], read_kreg(src2)[7..0]))));
  Ok(())
}

val exec_kxnorw : (kreg_idx, kreg_idx, kreg_idx) -> ExecutionResult
function exec_kxnorw(dst, src1, src2) = {
  write_kreg(dst, zero_extend(~(xor_vec(read_kreg(src1)[15..0], read_kreg(src2)[15..0]))));
  Ok(())
}

val exec_kxnord : (kreg_idx, kreg_idx, kreg_idx) -> ExecutionResult
function exec_kxnord(dst, src1, src2) = {
  write_kreg(dst, zero_extend(~(xor_vec(read_kreg(src1)[31..0], read_kreg(src2)[31..0]))));
  Ok(())
}

val exec_kxnorq : (kreg_idx, kreg_idx, kreg_idx) -> ExecutionResult
function exec_kxnorq(dst, src1, src2) = {
  write_kreg(dst, ~(xor_vec(read_kreg(src1), read_kreg(src2))));
  Ok(())
}

// =========================================================================
// KXOR -- Bitwise Logical XOR Mask Registers
// =========================================================================

val exec_kxorb : (kreg_idx, kreg_idx, kreg_idx) -> ExecutionResult
function exec_kxorb(dst, src1, src2) = {
  write_kreg(dst, zero_extend(xor_vec(read_kreg(src1)[7..0], read_kreg(src2)[7..0])));
  Ok(())
}

val exec_kxorw : (kreg_idx, kreg_idx, kreg_idx) -> ExecutionResult
function exec_kxorw(dst, src1, src2) = {
  write_kreg(dst, zero_extend(xor_vec(read_kreg(src1)[15..0], read_kreg(src2)[15..0])));
  Ok(())
}

val exec_kxord : (kreg_idx, kreg_idx, kreg_idx) -> ExecutionResult
function exec_kxord(dst, src1, src2) = {
  write_kreg(dst, zero_extend(xor_vec(read_kreg(src1)[31..0], read_kreg(src2)[31..0])));
  Ok(())
}

val exec_kxorq : (kreg_idx, kreg_idx, kreg_idx) -> ExecutionResult
function exec_kxorq(dst, src1, src2) = {
  write_kreg(dst, xor_vec(read_kreg(src1), read_kreg(src2)));
  Ok(())
}

// AVX-512 Integer Instruction Helpers
//
// Saturating arithmetic, multiply, pack/unpack, compare, shift, etc.
// All follow the pattern: 128-bit base → 256 = two 128 halves → 512 = two 256 halves.

// =========================================================================
// Saturating byte add/sub (signed and unsigned)
// =========================================================================

// SaturateToSignedByte: clamp (signed 16-bit sum) to [-128, 127]
val saturate_sb : (byte, byte) -> byte
function saturate_sb(a, b) = {
  let sum : int = signed(a) + signed(b);
  if sum > 127 then 0x7F
  else if sum < negate(128) then 0x80
  else get_slice_int(8, sum, 0)
}

val avx_paddsb_128 : (xmmword, xmmword) -> xmmword
function avx_paddsb_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 15) {
    let lo : range(0, 120) = i * 8;
    r[(lo + 7)..lo] = saturate_sb(a[(lo + 7)..lo], b[(lo + 7)..lo]);
  };
  r
}
val avx_paddsb_256 : (ymmword, ymmword) -> ymmword
function avx_paddsb_256(a, b) =
  avx_paddsb_128(a[255..128], b[255..128]) @ avx_paddsb_128(a[127..0], b[127..0])
val avx_paddsb_512 : (zmmword, zmmword) -> zmmword
function avx_paddsb_512(a, b) =
  avx_paddsb_256(a[511..256], b[511..256]) @ avx_paddsb_256(a[255..0], b[255..0])

// SaturateToSignedWord: clamp (signed 32-bit sum) to [-32768, 32767]
val saturate_sw : (word, word) -> word
function saturate_sw(a, b) = {
  let sum : int = signed(a) + signed(b);
  if sum > 32767 then 0x7FFF
  else if sum < negate(32768) then 0x8000
  else get_slice_int(16, sum, 0)
}

val avx_paddsw_128 : (xmmword, xmmword) -> xmmword
function avx_paddsw_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    r[(lo + 15)..lo] = saturate_sw(a[(lo + 15)..lo], b[(lo + 15)..lo]);
  };
  r
}
val avx_paddsw_256 : (ymmword, ymmword) -> ymmword
function avx_paddsw_256(a, b) =
  avx_paddsw_128(a[255..128], b[255..128]) @ avx_paddsw_128(a[127..0], b[127..0])
val avx_paddsw_512 : (zmmword, zmmword) -> zmmword
function avx_paddsw_512(a, b) =
  avx_paddsw_256(a[511..256], b[511..256]) @ avx_paddsw_256(a[255..0], b[255..0])

// SaturateToSignedByte for subtraction
val saturate_sb_sub : (byte, byte) -> byte
function saturate_sb_sub(a, b) = {
  let diff : int = signed(a) - signed(b);
  if diff > 127 then 0x7F
  else if diff < negate(128) then 0x80
  else get_slice_int(8, diff, 0)
}

val avx_psubsb_128 : (xmmword, xmmword) -> xmmword
function avx_psubsb_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 15) {
    let lo : range(0, 120) = i * 8;
    r[(lo + 7)..lo] = saturate_sb_sub(a[(lo + 7)..lo], b[(lo + 7)..lo]);
  };
  r
}
val avx_psubsb_256 : (ymmword, ymmword) -> ymmword
function avx_psubsb_256(a, b) =
  avx_psubsb_128(a[255..128], b[255..128]) @ avx_psubsb_128(a[127..0], b[127..0])
val avx_psubsb_512 : (zmmword, zmmword) -> zmmword
function avx_psubsb_512(a, b) =
  avx_psubsb_256(a[511..256], b[511..256]) @ avx_psubsb_256(a[255..0], b[255..0])

// SaturateToSignedWord for subtraction
val saturate_sw_sub : (word, word) -> word
function saturate_sw_sub(a, b) = {
  let diff : int = signed(a) - signed(b);
  if diff > 32767 then 0x7FFF
  else if diff < negate(32768) then 0x8000
  else get_slice_int(16, diff, 0)
}

val avx_psubsw_128 : (xmmword, xmmword) -> xmmword
function avx_psubsw_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    r[(lo + 15)..lo] = saturate_sw_sub(a[(lo + 15)..lo], b[(lo + 15)..lo]);
  };
  r
}
val avx_psubsw_256 : (ymmword, ymmword) -> ymmword
function avx_psubsw_256(a, b) =
  avx_psubsw_128(a[255..128], b[255..128]) @ avx_psubsw_128(a[127..0], b[127..0])
val avx_psubsw_512 : (zmmword, zmmword) -> zmmword
function avx_psubsw_512(a, b) =
  avx_psubsw_256(a[511..256], b[511..256]) @ avx_psubsw_256(a[255..0], b[255..0])

// SaturateToUnsignedByte for add
val saturate_ub_add : (byte, byte) -> byte
function saturate_ub_add(a, b) = {
  let sum : int = unsigned(a) + unsigned(b);
  if sum > 255 then 0xFF
  else get_slice_int(8, sum, 0)
}

val avx_paddusb_128 : (xmmword, xmmword) -> xmmword
function avx_paddusb_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 15) {
    let lo : range(0, 120) = i * 8;
    r[(lo + 7)..lo] = saturate_ub_add(a[(lo + 7)..lo], b[(lo + 7)..lo]);
  };
  r
}
val avx_paddusb_256 : (ymmword, ymmword) -> ymmword
function avx_paddusb_256(a, b) =
  avx_paddusb_128(a[255..128], b[255..128]) @ avx_paddusb_128(a[127..0], b[127..0])
val avx_paddusb_512 : (zmmword, zmmword) -> zmmword
function avx_paddusb_512(a, b) =
  avx_paddusb_256(a[511..256], b[511..256]) @ avx_paddusb_256(a[255..0], b[255..0])

// SaturateToUnsignedWord for add
val saturate_uw_add : (word, word) -> word
function saturate_uw_add(a, b) = {
  let sum : int = unsigned(a) + unsigned(b);
  if sum > 65535 then 0xFFFF
  else get_slice_int(16, sum, 0)
}

val avx_paddusw_128 : (xmmword, xmmword) -> xmmword
function avx_paddusw_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    r[(lo + 15)..lo] = saturate_uw_add(a[(lo + 15)..lo], b[(lo + 15)..lo]);
  };
  r
}
val avx_paddusw_256 : (ymmword, ymmword) -> ymmword
function avx_paddusw_256(a, b) =
  avx_paddusw_128(a[255..128], b[255..128]) @ avx_paddusw_128(a[127..0], b[127..0])
val avx_paddusw_512 : (zmmword, zmmword) -> zmmword
function avx_paddusw_512(a, b) =
  avx_paddusw_256(a[511..256], b[511..256]) @ avx_paddusw_256(a[255..0], b[255..0])

// SaturateToUnsignedByte for sub
val saturate_ub_sub : (byte, byte) -> byte
function saturate_ub_sub(a, b) = {
  let diff : int = unsigned(a) - unsigned(b);
  if diff < 0 then 0x00
  else get_slice_int(8, diff, 0)
}

val avx_psubusb_128 : (xmmword, xmmword) -> xmmword
function avx_psubusb_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 15) {
    let lo : range(0, 120) = i * 8;
    r[(lo + 7)..lo] = saturate_ub_sub(a[(lo + 7)..lo], b[(lo + 7)..lo]);
  };
  r
}
val avx_psubusb_256 : (ymmword, ymmword) -> ymmword
function avx_psubusb_256(a, b) =
  avx_psubusb_128(a[255..128], b[255..128]) @ avx_psubusb_128(a[127..0], b[127..0])
val avx_psubusb_512 : (zmmword, zmmword) -> zmmword
function avx_psubusb_512(a, b) =
  avx_psubusb_256(a[511..256], b[511..256]) @ avx_psubusb_256(a[255..0], b[255..0])

// SaturateToUnsignedWord for sub
val saturate_uw_sub : (word, word) -> word
function saturate_uw_sub(a, b) = {
  let diff : int = unsigned(a) - unsigned(b);
  if diff < 0 then 0x0000
  else get_slice_int(16, diff, 0)
}

val avx_psubusw_128 : (xmmword, xmmword) -> xmmword
function avx_psubusw_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    r[(lo + 15)..lo] = saturate_uw_sub(a[(lo + 15)..lo], b[(lo + 15)..lo]);
  };
  r
}
val avx_psubusw_256 : (ymmword, ymmword) -> ymmword
function avx_psubusw_256(a, b) =
  avx_psubusw_128(a[255..128], b[255..128]) @ avx_psubusw_128(a[127..0], b[127..0])
val avx_psubusw_512 : (zmmword, zmmword) -> zmmword
function avx_psubusw_512(a, b) =
  avx_psubusw_256(a[511..256], b[511..256]) @ avx_psubusw_256(a[255..0], b[255..0])

// =========================================================================
// VPMULLW: multiply low word (src1[15:0] * src2[15:0] → result[15:0])
// =========================================================================

val avx_pmullw_128 : (xmmword, xmmword) -> xmmword
function avx_pmullw_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    let prod : int = signed(a[(lo + 15)..lo]) * signed(b[(lo + 15)..lo]);
    r[(lo + 15)..lo] = get_slice_int(16, prod, 0);
  };
  r
}
val avx_pmullw_256 : (ymmword, ymmword) -> ymmword
function avx_pmullw_256(a, b) =
  avx_pmullw_128(a[255..128], b[255..128]) @ avx_pmullw_128(a[127..0], b[127..0])
val avx_pmullw_512 : (zmmword, zmmword) -> zmmword
function avx_pmullw_512(a, b) =
  avx_pmullw_256(a[511..256], b[511..256]) @ avx_pmullw_256(a[255..0], b[255..0])

// =========================================================================
// VPMULHW: multiply high signed word
// =========================================================================

val avx_pmulhw_128 : (xmmword, xmmword) -> xmmword
function avx_pmulhw_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    let prod : int = signed(a[(lo + 15)..lo]) * signed(b[(lo + 15)..lo]);
    r[(lo + 15)..lo] = get_slice_int(16, prod, 16);
  };
  r
}
val avx_pmulhw_256 : (ymmword, ymmword) -> ymmword
function avx_pmulhw_256(a, b) =
  avx_pmulhw_128(a[255..128], b[255..128]) @ avx_pmulhw_128(a[127..0], b[127..0])
val avx_pmulhw_512 : (zmmword, zmmword) -> zmmword
function avx_pmulhw_512(a, b) =
  avx_pmulhw_256(a[511..256], b[511..256]) @ avx_pmulhw_256(a[255..0], b[255..0])

// =========================================================================
// VPMULHUW: multiply high unsigned word
// =========================================================================

val avx_pmulhuw_128 : (xmmword, xmmword) -> xmmword
function avx_pmulhuw_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    let prod : int = unsigned(a[(lo + 15)..lo]) * unsigned(b[(lo + 15)..lo]);
    r[(lo + 15)..lo] = get_slice_int(16, prod, 16);
  };
  r
}
val avx_pmulhuw_256 : (ymmword, ymmword) -> ymmword
function avx_pmulhuw_256(a, b) =
  avx_pmulhuw_128(a[255..128], b[255..128]) @ avx_pmulhuw_128(a[127..0], b[127..0])
val avx_pmulhuw_512 : (zmmword, zmmword) -> zmmword
function avx_pmulhuw_512(a, b) =
  avx_pmulhuw_256(a[511..256], b[511..256]) @ avx_pmulhuw_256(a[255..0], b[255..0])

// =========================================================================
// VPMULUDQ: multiply unsigned dwords → unsigned qwords
// For each 64-bit lane: result = src1[31:0] * src2[31:0] (unsigned)
// =========================================================================

val avx_pmuludq_128 : (xmmword, xmmword) -> xmmword
function avx_pmuludq_128(a, b) = {
  let prod1 : qword = to_bits(64, unsigned(a[31..0]) * unsigned(b[31..0]));
  let prod0 : qword = to_bits(64, unsigned(a[95..64]) * unsigned(b[95..64]));
  prod0 @ prod1
}
val avx_pmuludq_256 : (ymmword, ymmword) -> ymmword
function avx_pmuludq_256(a, b) =
  avx_pmuludq_128(a[255..128], b[255..128]) @ avx_pmuludq_128(a[127..0], b[127..0])
val avx_pmuludq_512 : (zmmword, zmmword) -> zmmword
function avx_pmuludq_512(a, b) =
  avx_pmuludq_256(a[511..256], b[511..256]) @ avx_pmuludq_256(a[255..0], b[255..0])

// =========================================================================
// VPAVGB/VPAVGW: unsigned average = (a + b + 1) >> 1
// =========================================================================

val avx_pavgb_128 : (xmmword, xmmword) -> xmmword
function avx_pavgb_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 15) {
    let lo : range(0, 120) = i * 8;
    let avg : int = (unsigned(a[(lo + 7)..lo]) + unsigned(b[(lo + 7)..lo]) + 1) / 2;
    r[(lo + 7)..lo] = get_slice_int(8, avg, 0);
  };
  r
}
val avx_pavgb_256 : (ymmword, ymmword) -> ymmword
function avx_pavgb_256(a, b) =
  avx_pavgb_128(a[255..128], b[255..128]) @ avx_pavgb_128(a[127..0], b[127..0])
val avx_pavgb_512 : (zmmword, zmmword) -> zmmword
function avx_pavgb_512(a, b) =
  avx_pavgb_256(a[511..256], b[511..256]) @ avx_pavgb_256(a[255..0], b[255..0])

val avx_pavgw_128 : (xmmword, xmmword) -> xmmword
function avx_pavgw_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    let avg : int = (unsigned(a[(lo + 15)..lo]) + unsigned(b[(lo + 15)..lo]) + 1) / 2;
    r[(lo + 15)..lo] = get_slice_int(16, avg, 0);
  };
  r
}
val avx_pavgw_256 : (ymmword, ymmword) -> ymmword
function avx_pavgw_256(a, b) =
  avx_pavgw_128(a[255..128], b[255..128]) @ avx_pavgw_128(a[127..0], b[127..0])
val avx_pavgw_512 : (zmmword, zmmword) -> zmmword
function avx_pavgw_512(a, b) =
  avx_pavgw_256(a[511..256], b[511..256]) @ avx_pavgw_256(a[255..0], b[255..0])

// =========================================================================
// VPMAXUB: unsigned byte max
// =========================================================================

val avx_pmaxub_128 : (xmmword, xmmword) -> xmmword
function avx_pmaxub_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 15) {
    let lo : range(0, 120) = i * 8;
    let va = a[(lo + 7)..lo];
    let vb = b[(lo + 7)..lo];
    r[(lo + 7)..lo] = if unsigned(va) > unsigned(vb) then va else vb;
  };
  r
}
val avx_pmaxub_256 : (ymmword, ymmword) -> ymmword
function avx_pmaxub_256(a, b) =
  avx_pmaxub_128(a[255..128], b[255..128]) @ avx_pmaxub_128(a[127..0], b[127..0])
val avx_pmaxub_512 : (zmmword, zmmword) -> zmmword
function avx_pmaxub_512(a, b) =
  avx_pmaxub_256(a[511..256], b[511..256]) @ avx_pmaxub_256(a[255..0], b[255..0])

// =========================================================================
// VPMINSW: signed word min
// =========================================================================

val avx_pminsw_128 : (xmmword, xmmword) -> xmmword
function avx_pminsw_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    let va = a[(lo + 15)..lo];
    let vb = b[(lo + 15)..lo];
    r[(lo + 15)..lo] = if signed(va) < signed(vb) then va else vb;
  };
  r
}
val avx_pminsw_256 : (ymmword, ymmword) -> ymmword
function avx_pminsw_256(a, b) =
  avx_pminsw_128(a[255..128], b[255..128]) @ avx_pminsw_128(a[127..0], b[127..0])
val avx_pminsw_512 : (zmmword, zmmword) -> zmmword
function avx_pminsw_512(a, b) =
  avx_pminsw_256(a[511..256], b[511..256]) @ avx_pminsw_256(a[255..0], b[255..0])

// =========================================================================
// VPMAXSW: signed word max
// =========================================================================

val avx_pmaxsw_128 : (xmmword, xmmword) -> xmmword
function avx_pmaxsw_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    let va = a[(lo + 15)..lo];
    let vb = b[(lo + 15)..lo];
    r[(lo + 15)..lo] = if signed(va) > signed(vb) then va else vb;
  };
  r
}
val avx_pmaxsw_256 : (ymmword, ymmword) -> ymmword
function avx_pmaxsw_256(a, b) =
  avx_pmaxsw_128(a[255..128], b[255..128]) @ avx_pmaxsw_128(a[127..0], b[127..0])
val avx_pmaxsw_512 : (zmmword, zmmword) -> zmmword
function avx_pmaxsw_512(a, b) =
  avx_pmaxsw_256(a[511..256], b[511..256]) @ avx_pmaxsw_256(a[255..0], b[255..0])

// =========================================================================
// VPMADDWD: multiply and add packed integers
// Per 128-bit lane: for each pair of words, multiply signed and add adjacent products
// =========================================================================

val avx_pmaddwd_128 : (xmmword, xmmword) -> xmmword
function avx_pmaddwd_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let wlo : range(0, 96) = i * 32;
    let w0 = signed(a[(wlo + 15)..wlo]) * signed(b[(wlo + 15)..wlo]);
    let w1 = signed(a[(wlo + 31)..(wlo + 16)]) * signed(b[(wlo + 31)..(wlo + 16)]);
    r[(wlo + 31)..wlo] = get_slice_int(32, w0 + w1, 0);
  };
  r
}
val avx_pmaddwd_256 : (ymmword, ymmword) -> ymmword
function avx_pmaddwd_256(a, b) =
  avx_pmaddwd_128(a[255..128], b[255..128]) @ avx_pmaddwd_128(a[127..0], b[127..0])
val avx_pmaddwd_512 : (zmmword, zmmword) -> zmmword
function avx_pmaddwd_512(a, b) =
  avx_pmaddwd_256(a[511..256], b[511..256]) @ avx_pmaddwd_256(a[255..0], b[255..0])

// =========================================================================
// VPSADBW: sum of absolute differences of unsigned bytes
// Per 64-bit group: sum |a[i] - b[i]| for 8 byte pairs → 16-bit result in low word
// =========================================================================

val avx_psadbw_64 : (bits(64), bits(64)) -> bits(64)
function avx_psadbw_64(a, b) = {
  var sum : int = 0;
  foreach (i from 0 to 7) {
    let lo : range(0, 56) = i * 8;
    let diff : int = unsigned(a[(lo + 7)..lo]) - unsigned(b[(lo + 7)..lo]);
    sum = sum + (if diff < 0 then negate(diff) else diff);
  };
  zero_extend(get_slice_int(16, sum, 0))
}

val avx_psadbw_128 : (xmmword, xmmword) -> xmmword
function avx_psadbw_128(a, b) =
  avx_psadbw_64(a[127..64], b[127..64]) @ avx_psadbw_64(a[63..0], b[63..0])
val avx_psadbw_256 : (ymmword, ymmword) -> ymmword
function avx_psadbw_256(a, b) =
  avx_psadbw_128(a[255..128], b[255..128]) @ avx_psadbw_128(a[127..0], b[127..0])
val avx_psadbw_512 : (zmmword, zmmword) -> zmmword
function avx_psadbw_512(a, b) =
  avx_psadbw_256(a[511..256], b[511..256]) @ avx_psadbw_256(a[255..0], b[255..0])

// =========================================================================
// VPCMPGTB/W/D → kmask: signed greater-than comparison
// =========================================================================

val avx_pcmpgtb_mask_128 : (xmmword, xmmword) -> word
function avx_pcmpgtb_mask_128(a, b) = {
  var r : word = zeros();
  foreach (i from 0 to 15) {
    let lo : range(0, 120) = i * 8;
    if signed(a[(lo + 7)..lo]) > signed(b[(lo + 7)..lo])
    then r[i] = bitone;
  };
  r
}
val avx_pcmpgtb_mask_256 : (ymmword, ymmword) -> dword
function avx_pcmpgtb_mask_256(a, b) = {
  var r : dword = zeros();
  foreach (i from 0 to 31) {
    let lo : range(0, 248) = i * 8;
    if signed(a[(lo + 7)..lo]) > signed(b[(lo + 7)..lo])
    then r[i] = bitone;
  };
  r
}
val avx_pcmpgtb_mask_512 : (zmmword, zmmword) -> qword
function avx_pcmpgtb_mask_512(a, b) = {
  var r : qword = zeros();
  foreach (i from 0 to 63) {
    let lo : range(0, 504) = i * 8;
    if signed(a[(lo + 7)..lo]) > signed(b[(lo + 7)..lo])
    then r[i] = bitone;
  };
  r
}

val avx_pcmpgtw_mask_128 : (xmmword, xmmword) -> byte
function avx_pcmpgtw_mask_128(a, b) = {
  var r : byte = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    if signed(a[(lo + 15)..lo]) > signed(b[(lo + 15)..lo])
    then r[i] = bitone;
  };
  r
}
val avx_pcmpgtw_mask_256 : (ymmword, ymmword) -> word
function avx_pcmpgtw_mask_256(a, b) = {
  var r : word = zeros();
  foreach (i from 0 to 15) {
    let lo : range(0, 240) = i * 16;
    if signed(a[(lo + 15)..lo]) > signed(b[(lo + 15)..lo])
    then r[i] = bitone;
  };
  r
}
val avx_pcmpgtw_mask_512 : (zmmword, zmmword) -> dword
function avx_pcmpgtw_mask_512(a, b) = {
  var r : dword = zeros();
  foreach (i from 0 to 31) {
    let lo : range(0, 496) = i * 16;
    if signed(a[(lo + 15)..lo]) > signed(b[(lo + 15)..lo])
    then r[i] = bitone;
  };
  r
}

val avx_pcmpgtd_mask_128 : (xmmword, xmmword) -> byte
function avx_pcmpgtd_mask_128(a, b) = {
  var r : byte = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    if signed(a[(lo + 31)..lo]) > signed(b[(lo + 31)..lo])
    then r[i] = bitone;
  };
  r
}
val avx_pcmpgtd_mask_256 : (ymmword, ymmword) -> byte
function avx_pcmpgtd_mask_256(a, b) = {
  var r : byte = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 224) = i * 32;
    if signed(a[(lo + 31)..lo]) > signed(b[(lo + 31)..lo])
    then r[i] = bitone;
  };
  r
}
val avx_pcmpgtd_mask_512 : (zmmword, zmmword) -> word
function avx_pcmpgtd_mask_512(a, b) = {
  var r : word = zeros();
  foreach (i from 0 to 15) {
    let lo : range(0, 480) = i * 32;
    if signed(a[(lo + 31)..lo]) > signed(b[(lo + 31)..lo])
    then r[i] = bitone;
  };
  r
}

// VPCMPEQW → kmask
val avx_pcmpeqw_mask_128 : (xmmword, xmmword) -> byte
function avx_pcmpeqw_mask_128(a, b) = {
  var r : byte = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    if a[(lo + 15)..lo] == b[(lo + 15)..lo]
    then r[i] = bitone;
  };
  r
}
val avx_pcmpeqw_mask_256 : (ymmword, ymmword) -> word
function avx_pcmpeqw_mask_256(a, b) = {
  var r : word = zeros();
  foreach (i from 0 to 15) {
    let lo : range(0, 240) = i * 16;
    if a[(lo + 15)..lo] == b[(lo + 15)..lo]
    then r[i] = bitone;
  };
  r
}
val avx_pcmpeqw_mask_512 : (zmmword, zmmword) -> dword
function avx_pcmpeqw_mask_512(a, b) = {
  var r : dword = zeros();
  foreach (i from 0 to 31) {
    let lo : range(0, 496) = i * 16;
    if a[(lo + 15)..lo] == b[(lo + 15)..lo]
    then r[i] = bitone;
  };
  r
}

// =========================================================================
// VPUNPCKLBW: interleave low bytes from each 128-bit lane
// For each 128-bit lane: dst[0]=a[0], dst[1]=b[0], dst[2]=a[1], dst[3]=b[1], ...
// =========================================================================

val avx_punpcklbw_128 : (xmmword, xmmword) -> xmmword
function avx_punpcklbw_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let src_lo : range(0, 56) = i * 8;
    let dst_lo : range(0, 112) = i * 16;
    r[(dst_lo + 7)..dst_lo] = a[(src_lo + 7)..src_lo];
    r[(dst_lo + 15)..(dst_lo + 8)] = b[(src_lo + 7)..src_lo];
  };
  r
}
val avx_punpcklbw_256 : (ymmword, ymmword) -> ymmword
function avx_punpcklbw_256(a, b) =
  avx_punpcklbw_128(a[255..128], b[255..128]) @ avx_punpcklbw_128(a[127..0], b[127..0])
val avx_punpcklbw_512 : (zmmword, zmmword) -> zmmword
function avx_punpcklbw_512(a, b) =
  avx_punpcklbw_256(a[511..256], b[511..256]) @ avx_punpcklbw_256(a[255..0], b[255..0])

// VPUNPCKLWD: interleave low words from each 128-bit lane
val avx_punpcklwd_128 : (xmmword, xmmword) -> xmmword
function avx_punpcklwd_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let src_lo : range(0, 48) = i * 16;
    let dst_lo : range(0, 96) = i * 32;
    r[(dst_lo + 15)..dst_lo] = a[(src_lo + 15)..src_lo];
    r[(dst_lo + 31)..(dst_lo + 16)] = b[(src_lo + 15)..src_lo];
  };
  r
}
val avx_punpcklwd_256 : (ymmword, ymmword) -> ymmword
function avx_punpcklwd_256(a, b) =
  avx_punpcklwd_128(a[255..128], b[255..128]) @ avx_punpcklwd_128(a[127..0], b[127..0])
val avx_punpcklwd_512 : (zmmword, zmmword) -> zmmword
function avx_punpcklwd_512(a, b) =
  avx_punpcklwd_256(a[511..256], b[511..256]) @ avx_punpcklwd_256(a[255..0], b[255..0])

// VPUNPCKLDQ: interleave low dwords from each 128-bit lane
val avx_punpckldq_128 : (xmmword, xmmword) -> xmmword
function avx_punpckldq_128(a, b) =
  b[63..32] @ a[63..32] @ b[31..0] @ a[31..0]
val avx_punpckldq_256 : (ymmword, ymmword) -> ymmword
function avx_punpckldq_256(a, b) =
  avx_punpckldq_128(a[255..128], b[255..128]) @ avx_punpckldq_128(a[127..0], b[127..0])
val avx_punpckldq_512 : (zmmword, zmmword) -> zmmword
function avx_punpckldq_512(a, b) =
  avx_punpckldq_256(a[511..256], b[511..256]) @ avx_punpckldq_256(a[255..0], b[255..0])

// VPUNPCKLQDQ: interleave low qwords from each 128-bit lane
val avx_punpcklqdq_128 : (xmmword, xmmword) -> xmmword
function avx_punpcklqdq_128(a, b) =
  b[63..0] @ a[63..0]
val avx_punpcklqdq_256 : (ymmword, ymmword) -> ymmword
function avx_punpcklqdq_256(a, b) =
  avx_punpcklqdq_128(a[255..128], b[255..128]) @ avx_punpcklqdq_128(a[127..0], b[127..0])
val avx_punpcklqdq_512 : (zmmword, zmmword) -> zmmword
function avx_punpcklqdq_512(a, b) =
  avx_punpcklqdq_256(a[511..256], b[511..256]) @ avx_punpcklqdq_256(a[255..0], b[255..0])

// =========================================================================
// VPUNPCKHBW: interleave high bytes from each 128-bit lane
// =========================================================================

val avx_punpckhbw_128 : (xmmword, xmmword) -> xmmword
function avx_punpckhbw_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let src_lo : range(0, 120) = i * 8 + 64;
    let dst_lo : range(0, 112) = i * 16;
    r[(dst_lo + 7)..dst_lo] = a[(src_lo + 7)..src_lo];
    r[(dst_lo + 15)..(dst_lo + 8)] = b[(src_lo + 7)..src_lo];
  };
  r
}
val avx_punpckhbw_256 : (ymmword, ymmword) -> ymmword
function avx_punpckhbw_256(a, b) =
  avx_punpckhbw_128(a[255..128], b[255..128]) @ avx_punpckhbw_128(a[127..0], b[127..0])
val avx_punpckhbw_512 : (zmmword, zmmword) -> zmmword
function avx_punpckhbw_512(a, b) =
  avx_punpckhbw_256(a[511..256], b[511..256]) @ avx_punpckhbw_256(a[255..0], b[255..0])

// VPUNPCKHWD: interleave high words from each 128-bit lane
val avx_punpckhwd_128 : (xmmword, xmmword) -> xmmword
function avx_punpckhwd_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let src_lo : range(0, 112) = i * 16 + 64;
    let dst_lo : range(0, 96) = i * 32;
    r[(dst_lo + 15)..dst_lo] = a[(src_lo + 15)..src_lo];
    r[(dst_lo + 31)..(dst_lo + 16)] = b[(src_lo + 15)..src_lo];
  };
  r
}
val avx_punpckhwd_256 : (ymmword, ymmword) -> ymmword
function avx_punpckhwd_256(a, b) =
  avx_punpckhwd_128(a[255..128], b[255..128]) @ avx_punpckhwd_128(a[127..0], b[127..0])
val avx_punpckhwd_512 : (zmmword, zmmword) -> zmmword
function avx_punpckhwd_512(a, b) =
  avx_punpckhwd_256(a[511..256], b[511..256]) @ avx_punpckhwd_256(a[255..0], b[255..0])

// VPUNPCKHDQ: interleave high dwords from each 128-bit lane
val avx_punpckhdq_128 : (xmmword, xmmword) -> xmmword
function avx_punpckhdq_128(a, b) =
  b[127..96] @ a[127..96] @ b[95..64] @ a[95..64]
val avx_punpckhdq_256 : (ymmword, ymmword) -> ymmword
function avx_punpckhdq_256(a, b) =
  avx_punpckhdq_128(a[255..128], b[255..128]) @ avx_punpckhdq_128(a[127..0], b[127..0])
val avx_punpckhdq_512 : (zmmword, zmmword) -> zmmword
function avx_punpckhdq_512(a, b) =
  avx_punpckhdq_256(a[511..256], b[511..256]) @ avx_punpckhdq_256(a[255..0], b[255..0])

// VPUNPCKHQDQ: interleave high qwords from each 128-bit lane
val avx_punpckhqdq_128 : (xmmword, xmmword) -> xmmword
function avx_punpckhqdq_128(a, b) =
  b[127..64] @ a[127..64]
val avx_punpckhqdq_256 : (ymmword, ymmword) -> ymmword
function avx_punpckhqdq_256(a, b) =
  avx_punpckhqdq_128(a[255..128], b[255..128]) @ avx_punpckhqdq_128(a[127..0], b[127..0])
val avx_punpckhqdq_512 : (zmmword, zmmword) -> zmmword
function avx_punpckhqdq_512(a, b) =
  avx_punpckhqdq_256(a[511..256], b[511..256]) @ avx_punpckhqdq_256(a[255..0], b[255..0])

// =========================================================================
// VPACKSSWB: pack signed words to signed bytes with saturation
// Per 128-bit lane: 8 words from src1 → low 8 bytes, 8 words from src2 → high 8 bytes
// =========================================================================

val saturate_sw_to_sb : word -> byte
function saturate_sw_to_sb(w) = {
  let v : int = signed(w);
  if v > 127 then 0x7F
  else if v < negate(128) then 0x80
  else get_slice_int(8, v, 0)
}

val avx_packsswb_128 : (xmmword, xmmword) -> xmmword
function avx_packsswb_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let src_lo : range(0, 112) = i * 16;
    r[(i * 8 + 7)..(i * 8)] = saturate_sw_to_sb(a[(src_lo + 15)..src_lo]);
    r[(i * 8 + 71)..(i * 8 + 64)] = saturate_sw_to_sb(b[(src_lo + 15)..src_lo]);
  };
  r
}
val avx_packsswb_256 : (ymmword, ymmword) -> ymmword
function avx_packsswb_256(a, b) =
  avx_packsswb_128(a[255..128], b[255..128]) @ avx_packsswb_128(a[127..0], b[127..0])
val avx_packsswb_512 : (zmmword, zmmword) -> zmmword
function avx_packsswb_512(a, b) =
  avx_packsswb_256(a[511..256], b[511..256]) @ avx_packsswb_256(a[255..0], b[255..0])

// VPACKSSDW: pack signed dwords to signed words with saturation
val saturate_sd_to_sw : dword -> word
function saturate_sd_to_sw(d) = {
  let v : int = signed(d);
  if v > 32767 then 0x7FFF
  else if v < negate(32768) then 0x8000
  else get_slice_int(16, v, 0)
}

val avx_packssdw_128 : (xmmword, xmmword) -> xmmword
function avx_packssdw_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let src_lo : range(0, 96) = i * 32;
    r[(i * 16 + 15)..(i * 16)] = saturate_sd_to_sw(a[(src_lo + 31)..src_lo]);
    r[(i * 16 + 79)..(i * 16 + 64)] = saturate_sd_to_sw(b[(src_lo + 31)..src_lo]);
  };
  r
}
val avx_packssdw_256 : (ymmword, ymmword) -> ymmword
function avx_packssdw_256(a, b) =
  avx_packssdw_128(a[255..128], b[255..128]) @ avx_packssdw_128(a[127..0], b[127..0])
val avx_packssdw_512 : (zmmword, zmmword) -> zmmword
function avx_packssdw_512(a, b) =
  avx_packssdw_256(a[511..256], b[511..256]) @ avx_packssdw_256(a[255..0], b[255..0])

// VPACKUSWB: pack signed words to unsigned bytes with saturation
val saturate_sw_to_ub : word -> byte
function saturate_sw_to_ub(w) = {
  let v : int = signed(w);
  if v > 255 then 0xFF
  else if v < 0 then 0x00
  else get_slice_int(8, v, 0)
}

val avx_packuswb_128 : (xmmword, xmmword) -> xmmword
function avx_packuswb_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let src_lo : range(0, 112) = i * 16;
    r[(i * 8 + 7)..(i * 8)] = saturate_sw_to_ub(a[(src_lo + 15)..src_lo]);
    r[(i * 8 + 71)..(i * 8 + 64)] = saturate_sw_to_ub(b[(src_lo + 15)..src_lo]);
  };
  r
}
val avx_packuswb_256 : (ymmword, ymmword) -> ymmword
function avx_packuswb_256(a, b) =
  avx_packuswb_128(a[255..128], b[255..128]) @ avx_packuswb_128(a[127..0], b[127..0])
val avx_packuswb_512 : (zmmword, zmmword) -> zmmword
function avx_packuswb_512(a, b) =
  avx_packuswb_256(a[511..256], b[511..256]) @ avx_packuswb_256(a[255..0], b[255..0])

// =========================================================================
// VPSHUFD: shuffle dwords within each 128-bit lane by imm8
// =========================================================================

val avx_pshufd_128 : (xmmword, byte) -> xmmword
function avx_pshufd_128(src, imm) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let sel_bits : range(0, 6) = i * 2;
    let sel : range(0, 3) = unsigned(imm[(sel_bits + 1)..sel_bits]);
    let src_lo : range(0, 96) = sel * 32;
    let dst_lo : range(0, 96) = i * 32;
    r[(dst_lo + 31)..dst_lo] = src[(src_lo + 31)..src_lo];
  };
  r
}
val avx_pshufd_256 : (ymmword, byte) -> ymmword
function avx_pshufd_256(src, imm) =
  avx_pshufd_128(src[255..128], imm) @ avx_pshufd_128(src[127..0], imm)
val avx_pshufd_512 : (zmmword, byte) -> zmmword
function avx_pshufd_512(src, imm) =
  avx_pshufd_256(src[511..256], imm) @ avx_pshufd_256(src[255..0], imm)

// VPSHUFHW: shuffle high words within each 128-bit lane, low qword unchanged
val avx_pshufhw_128 : (xmmword, byte) -> xmmword
function avx_pshufhw_128(src, imm) = {
  var r : xmmword = zeros();
  r[63..0] = src[63..0];
  foreach (i from 0 to 3) {
    let sel_bits : range(0, 6) = i * 2;
    let sel : range(0, 3) = unsigned(imm[(sel_bits + 1)..sel_bits]);
    let src_lo : range(0, 112) = sel * 16 + 64;
    let dst_lo : range(0, 112) = i * 16 + 64;
    r[(dst_lo + 15)..dst_lo] = src[(src_lo + 15)..src_lo];
  };
  r
}
val avx_pshufhw_256 : (ymmword, byte) -> ymmword
function avx_pshufhw_256(src, imm) =
  avx_pshufhw_128(src[255..128], imm) @ avx_pshufhw_128(src[127..0], imm)
val avx_pshufhw_512 : (zmmword, byte) -> zmmword
function avx_pshufhw_512(src, imm) =
  avx_pshufhw_256(src[511..256], imm) @ avx_pshufhw_256(src[255..0], imm)

// VPSHUFLW: shuffle low words within each 128-bit lane, high qword unchanged
val avx_pshuflw_128 : (xmmword, byte) -> xmmword
function avx_pshuflw_128(src, imm) = {
  var r : xmmword = zeros();
  r[127..64] = src[127..64];
  foreach (i from 0 to 3) {
    let sel_bits : range(0, 6) = i * 2;
    let sel : range(0, 3) = unsigned(imm[(sel_bits + 1)..sel_bits]);
    let src_lo : range(0, 48) = sel * 16;
    let dst_lo : range(0, 48) = i * 16;
    r[(dst_lo + 15)..dst_lo] = src[(src_lo + 15)..src_lo];
  };
  r
}
val avx_pshuflw_256 : (ymmword, byte) -> ymmword
function avx_pshuflw_256(src, imm) =
  avx_pshuflw_128(src[255..128], imm) @ avx_pshuflw_128(src[127..0], imm)
val avx_pshuflw_512 : (zmmword, byte) -> zmmword
function avx_pshuflw_512(src, imm) =
  avx_pshuflw_256(src[511..256], imm) @ avx_pshuflw_256(src[255..0], imm)

// =========================================================================
// Shift by immediate: VPSRLW/D/Q, VPSLLW/D/Q, VPSRAW/D, VPSRAQ
// If count >= element_size, result is 0 (logical) or sign-extended (arithmetic)
// =========================================================================

// VPSRLW: logical right shift words by imm
val avx_psrlw_imm_128 : (xmmword, range(0, 255)) -> xmmword
function avx_psrlw_imm_128(a, count) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    r[(lo + 15)..lo] = if count >= 16 then zeros() else a[(lo + 15)..lo] >> count;
  };
  r
}
val avx_psrlw_imm_256 : (ymmword, range(0, 255)) -> ymmword
function avx_psrlw_imm_256(a, count) =
  avx_psrlw_imm_128(a[255..128], count) @ avx_psrlw_imm_128(a[127..0], count)
val avx_psrlw_imm_512 : (zmmword, range(0, 255)) -> zmmword
function avx_psrlw_imm_512(a, count) =
  avx_psrlw_imm_256(a[511..256], count) @ avx_psrlw_imm_256(a[255..0], count)

// VPSRLD: logical right shift dwords by imm
val avx_psrld_imm_128 : (xmmword, range(0, 255)) -> xmmword
function avx_psrld_imm_128(a, count) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    r[(lo + 31)..lo] = if count >= 32 then zeros() else a[(lo + 31)..lo] >> count;
  };
  r
}
val avx_psrld_imm_256 : (ymmword, range(0, 255)) -> ymmword
function avx_psrld_imm_256(a, count) =
  avx_psrld_imm_128(a[255..128], count) @ avx_psrld_imm_128(a[127..0], count)
val avx_psrld_imm_512 : (zmmword, range(0, 255)) -> zmmword
function avx_psrld_imm_512(a, count) =
  avx_psrld_imm_256(a[511..256], count) @ avx_psrld_imm_256(a[255..0], count)

// VPSRLQ: logical right shift qwords by imm
val avx_psrlq_imm_128 : (xmmword, range(0, 255)) -> xmmword
function avx_psrlq_imm_128(a, count) = {
  var r : xmmword = zeros();
  r[63..0] = if count >= 64 then zeros() else a[63..0] >> count;
  r[127..64] = if count >= 64 then zeros() else a[127..64] >> count;
  r
}
val avx_psrlq_imm_256 : (ymmword, range(0, 255)) -> ymmword
function avx_psrlq_imm_256(a, count) =
  avx_psrlq_imm_128(a[255..128], count) @ avx_psrlq_imm_128(a[127..0], count)
val avx_psrlq_imm_512 : (zmmword, range(0, 255)) -> zmmword
function avx_psrlq_imm_512(a, count) =
  avx_psrlq_imm_256(a[511..256], count) @ avx_psrlq_imm_256(a[255..0], count)

// VPSLLW: logical left shift words by imm
val avx_psllw_imm_128 : (xmmword, range(0, 255)) -> xmmword
function avx_psllw_imm_128(a, count) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    r[(lo + 15)..lo] = if count >= 16 then zeros() else a[(lo + 15)..lo] << count;
  };
  r
}
val avx_psllw_imm_256 : (ymmword, range(0, 255)) -> ymmword
function avx_psllw_imm_256(a, count) =
  avx_psllw_imm_128(a[255..128], count) @ avx_psllw_imm_128(a[127..0], count)
val avx_psllw_imm_512 : (zmmword, range(0, 255)) -> zmmword
function avx_psllw_imm_512(a, count) =
  avx_psllw_imm_256(a[511..256], count) @ avx_psllw_imm_256(a[255..0], count)

// VPSLLD: logical left shift dwords by imm
val avx_pslld_imm_128 : (xmmword, range(0, 255)) -> xmmword
function avx_pslld_imm_128(a, count) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    r[(lo + 31)..lo] = if count >= 32 then zeros() else a[(lo + 31)..lo] << count;
  };
  r
}
val avx_pslld_imm_256 : (ymmword, range(0, 255)) -> ymmword
function avx_pslld_imm_256(a, count) =
  avx_pslld_imm_128(a[255..128], count) @ avx_pslld_imm_128(a[127..0], count)
val avx_pslld_imm_512 : (zmmword, range(0, 255)) -> zmmword
function avx_pslld_imm_512(a, count) =
  avx_pslld_imm_256(a[511..256], count) @ avx_pslld_imm_256(a[255..0], count)

// VPSLLQ: logical left shift qwords by imm
val avx_psllq_imm_128 : (xmmword, range(0, 255)) -> xmmword
function avx_psllq_imm_128(a, count) = {
  var r : xmmword = zeros();
  r[63..0] = if count >= 64 then zeros() else a[63..0] << count;
  r[127..64] = if count >= 64 then zeros() else a[127..64] << count;
  r
}
val avx_psllq_imm_256 : (ymmword, range(0, 255)) -> ymmword
function avx_psllq_imm_256(a, count) =
  avx_psllq_imm_128(a[255..128], count) @ avx_psllq_imm_128(a[127..0], count)
val avx_psllq_imm_512 : (zmmword, range(0, 255)) -> zmmword
function avx_psllq_imm_512(a, count) =
  avx_psllq_imm_256(a[511..256], count) @ avx_psllq_imm_256(a[255..0], count)

// VPSRAW: arithmetic right shift words by imm
val arith_shr_word : (word, range(0, 255)) -> word
function arith_shr_word(v, count) = {
  if count == 0 then v
  else if count >= 16 then (if v[15] == bitone then ones() else zeros())
  else {
    // Logical shift right, then fill high bits with sign bit
    let shifted : word = v >> count;
    let sign_bit = v[15];
    var r : word = shifted;
    foreach (i from 0 to 14) {
      let bit_idx : range(0, 15) = 15 - i;
      if i < count then r[bit_idx] = sign_bit;
    };
    r
  }
}

val avx_psraw_imm_128 : (xmmword, range(0, 255)) -> xmmword
function avx_psraw_imm_128(a, count) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    r[(lo + 15)..lo] = arith_shr_word(a[(lo + 15)..lo], count);
  };
  r
}
val avx_psraw_imm_256 : (ymmword, range(0, 255)) -> ymmword
function avx_psraw_imm_256(a, count) =
  avx_psraw_imm_128(a[255..128], count) @ avx_psraw_imm_128(a[127..0], count)
val avx_psraw_imm_512 : (zmmword, range(0, 255)) -> zmmword
function avx_psraw_imm_512(a, count) =
  avx_psraw_imm_256(a[511..256], count) @ avx_psraw_imm_256(a[255..0], count)

// VPSRAD: arithmetic right shift dwords by imm
val arith_shr_dword : (dword, range(0, 255)) -> dword
function arith_shr_dword(v, count) = {
  if count == 0 then v
  else if count >= 32 then (if v[31] == bitone then ones() else zeros())
  else {
    let shifted : dword = v >> count;
    let sign_bit = v[31];
    var r : dword = shifted;
    foreach (i from 0 to 30) {
      let bit_idx : range(0, 31) = 31 - i;
      if i < count then r[bit_idx] = sign_bit;
    };
    r
  }
}

val avx_psrad_imm_128 : (xmmword, range(0, 255)) -> xmmword
function avx_psrad_imm_128(a, count) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    r[(lo + 31)..lo] = arith_shr_dword(a[(lo + 31)..lo], count);
  };
  r
}
val avx_psrad_imm_256 : (ymmword, range(0, 255)) -> ymmword
function avx_psrad_imm_256(a, count) =
  avx_psrad_imm_128(a[255..128], count) @ avx_psrad_imm_128(a[127..0], count)
val avx_psrad_imm_512 : (zmmword, range(0, 255)) -> zmmword
function avx_psrad_imm_512(a, count) =
  avx_psrad_imm_256(a[511..256], count) @ avx_psrad_imm_256(a[255..0], count)

// VPSRAQ: arithmetic right shift qwords by imm (AVX-512 new)
val arith_shr_qword : (qword, range(0, 255)) -> qword
function arith_shr_qword(v, count) = {
  if count == 0 then v
  else if count >= 64 then (if v[63] == bitone then ones() else zeros())
  else {
    let shifted : qword = v >> count;
    let sign_bit = v[63];
    var r : qword = shifted;
    foreach (i from 0 to 62) {
      let bit_idx : range(0, 63) = 63 - i;
      if i < count then r[bit_idx] = sign_bit;
    };
    r
  }
}

val avx_psraq_imm_128 : (xmmword, range(0, 255)) -> xmmword
function avx_psraq_imm_128(a, count) = {
  var r : xmmword = zeros();
  r[63..0] = arith_shr_qword(a[63..0], count);
  r[127..64] = arith_shr_qword(a[127..64], count);
  r
}
val avx_psraq_imm_256 : (ymmword, range(0, 255)) -> ymmword
function avx_psraq_imm_256(a, count) =
  avx_psraq_imm_128(a[255..128], count) @ avx_psraq_imm_128(a[127..0], count)
val avx_psraq_imm_512 : (zmmword, range(0, 255)) -> zmmword
function avx_psraq_imm_512(a, count) =
  avx_psraq_imm_256(a[511..256], count) @ avx_psraq_imm_256(a[255..0], count)

// VPSLLDQ: byte shift left per 128-bit lane
val avx_pslldq_128 : (xmmword, range(0, 255)) -> xmmword
function avx_pslldq_128(a, count) = {
  let cnt = if count > 15 then 16 else count;
  a << (cnt * 8)
}
val avx_pslldq_256 : (ymmword, range(0, 255)) -> ymmword
function avx_pslldq_256(a, count) =
  avx_pslldq_128(a[255..128], count) @ avx_pslldq_128(a[127..0], count)
val avx_pslldq_512 : (zmmword, range(0, 255)) -> zmmword
function avx_pslldq_512(a, count) =
  avx_pslldq_256(a[511..256], count) @ avx_pslldq_256(a[255..0], count)

// VPSRLDQ: byte shift right per 128-bit lane
val avx_psrldq_128 : (xmmword, range(0, 255)) -> xmmword
function avx_psrldq_128(a, count) = {
  let cnt = if count > 15 then 16 else count;
  a >> (cnt * 8)
}
val avx_psrldq_256 : (ymmword, range(0, 255)) -> ymmword
function avx_psrldq_256(a, count) =
  avx_psrldq_128(a[255..128], count) @ avx_psrldq_128(a[127..0], count)
val avx_psrldq_512 : (zmmword, range(0, 255)) -> zmmword
function avx_psrldq_512(a, count) =
  avx_psrldq_256(a[511..256], count) @ avx_psrldq_256(a[255..0], count)

// =========================================================================
// Shift by XMM count: count comes from low 64 bits of XMM register
// Same functions as imm but count extracted from xmm src2[63:0]
// =========================================================================

val clamp_shift_count : int -> range(0, 255)
function clamp_shift_count(c) = {
  let r : range(0, 255) = if c > 255 then 255 else if c < 0 then 0 else c;
  r
}

// VPSRLW by xmm count
val avx_psrlw_xmm_128 : (xmmword, xmmword) -> xmmword
function avx_psrlw_xmm_128(a, count_xmm) =
  avx_psrlw_imm_128(a, clamp_shift_count(unsigned(count_xmm[63..0])))
val avx_psrlw_xmm_256 : (ymmword, xmmword) -> ymmword
function avx_psrlw_xmm_256(a, count_xmm) =
  avx_psrlw_imm_256(a, clamp_shift_count(unsigned(count_xmm[63..0])))
val avx_psrlw_xmm_512 : (zmmword, xmmword) -> zmmword
function avx_psrlw_xmm_512(a, count_xmm) =
  avx_psrlw_imm_512(a, clamp_shift_count(unsigned(count_xmm[63..0])))

// VPSRLD by xmm count
val avx_psrld_xmm_128 : (xmmword, xmmword) -> xmmword
function avx_psrld_xmm_128(a, count_xmm) =
  avx_psrld_imm_128(a, clamp_shift_count(unsigned(count_xmm[63..0])))
val avx_psrld_xmm_256 : (ymmword, xmmword) -> ymmword
function avx_psrld_xmm_256(a, count_xmm) =
  avx_psrld_imm_256(a, clamp_shift_count(unsigned(count_xmm[63..0])))
val avx_psrld_xmm_512 : (zmmword, xmmword) -> zmmword
function avx_psrld_xmm_512(a, count_xmm) =
  avx_psrld_imm_512(a, clamp_shift_count(unsigned(count_xmm[63..0])))

// VPSRLQ by xmm count
val avx_psrlq_xmm_128 : (xmmword, xmmword) -> xmmword
function avx_psrlq_xmm_128(a, count_xmm) =
  avx_psrlq_imm_128(a, clamp_shift_count(unsigned(count_xmm[63..0])))
val avx_psrlq_xmm_256 : (ymmword, xmmword) -> ymmword
function avx_psrlq_xmm_256(a, count_xmm) =
  avx_psrlq_imm_256(a, clamp_shift_count(unsigned(count_xmm[63..0])))
val avx_psrlq_xmm_512 : (zmmword, xmmword) -> zmmword
function avx_psrlq_xmm_512(a, count_xmm) =
  avx_psrlq_imm_512(a, clamp_shift_count(unsigned(count_xmm[63..0])))

// VPSLLW by xmm count
val avx_psllw_xmm_128 : (xmmword, xmmword) -> xmmword
function avx_psllw_xmm_128(a, count_xmm) =
  avx_psllw_imm_128(a, clamp_shift_count(unsigned(count_xmm[63..0])))
val avx_psllw_xmm_256 : (ymmword, xmmword) -> ymmword
function avx_psllw_xmm_256(a, count_xmm) =
  avx_psllw_imm_256(a, clamp_shift_count(unsigned(count_xmm[63..0])))
val avx_psllw_xmm_512 : (zmmword, xmmword) -> zmmword
function avx_psllw_xmm_512(a, count_xmm) =
  avx_psllw_imm_512(a, clamp_shift_count(unsigned(count_xmm[63..0])))

// VPSLLD by xmm count
val avx_pslld_xmm_128 : (xmmword, xmmword) -> xmmword
function avx_pslld_xmm_128(a, count_xmm) =
  avx_pslld_imm_128(a, clamp_shift_count(unsigned(count_xmm[63..0])))
val avx_pslld_xmm_256 : (ymmword, xmmword) -> ymmword
function avx_pslld_xmm_256(a, count_xmm) =
  avx_pslld_imm_256(a, clamp_shift_count(unsigned(count_xmm[63..0])))
val avx_pslld_xmm_512 : (zmmword, xmmword) -> zmmword
function avx_pslld_xmm_512(a, count_xmm) =
  avx_pslld_imm_512(a, clamp_shift_count(unsigned(count_xmm[63..0])))

// VPSLLQ by xmm count
val avx_psllq_xmm_128 : (xmmword, xmmword) -> xmmword
function avx_psllq_xmm_128(a, count_xmm) =
  avx_psllq_imm_128(a, clamp_shift_count(unsigned(count_xmm[63..0])))
val avx_psllq_xmm_256 : (ymmword, xmmword) -> ymmword
function avx_psllq_xmm_256(a, count_xmm) =
  avx_psllq_imm_256(a, clamp_shift_count(unsigned(count_xmm[63..0])))
val avx_psllq_xmm_512 : (zmmword, xmmword) -> zmmword
function avx_psllq_xmm_512(a, count_xmm) =
  avx_psllq_imm_512(a, clamp_shift_count(unsigned(count_xmm[63..0])))

// VPSRAW by xmm count
val avx_psraw_xmm_128 : (xmmword, xmmword) -> xmmword
function avx_psraw_xmm_128(a, count_xmm) =
  avx_psraw_imm_128(a, clamp_shift_count(unsigned(count_xmm[63..0])))
val avx_psraw_xmm_256 : (ymmword, xmmword) -> ymmword
function avx_psraw_xmm_256(a, count_xmm) =
  avx_psraw_imm_256(a, clamp_shift_count(unsigned(count_xmm[63..0])))
val avx_psraw_xmm_512 : (zmmword, xmmword) -> zmmword
function avx_psraw_xmm_512(a, count_xmm) =
  avx_psraw_imm_512(a, clamp_shift_count(unsigned(count_xmm[63..0])))

// VPSRAD by xmm count
val avx_psrad_xmm_128 : (xmmword, xmmword) -> xmmword
function avx_psrad_xmm_128(a, count_xmm) =
  avx_psrad_imm_128(a, clamp_shift_count(unsigned(count_xmm[63..0])))
val avx_psrad_xmm_256 : (ymmword, xmmword) -> ymmword
function avx_psrad_xmm_256(a, count_xmm) =
  avx_psrad_imm_256(a, clamp_shift_count(unsigned(count_xmm[63..0])))
val avx_psrad_xmm_512 : (zmmword, xmmword) -> zmmword
function avx_psrad_xmm_512(a, count_xmm) =
  avx_psrad_imm_512(a, clamp_shift_count(unsigned(count_xmm[63..0])))

// VPSRAQ by xmm count
val avx_psraq_xmm_128 : (xmmword, xmmword) -> xmmword
function avx_psraq_xmm_128(a, count_xmm) =
  avx_psraq_imm_128(a, clamp_shift_count(unsigned(count_xmm[63..0])))
val avx_psraq_xmm_256 : (ymmword, xmmword) -> ymmword
function avx_psraq_xmm_256(a, count_xmm) =
  avx_psraq_imm_256(a, clamp_shift_count(unsigned(count_xmm[63..0])))
val avx_psraq_xmm_512 : (zmmword, xmmword) -> zmmword
function avx_psraq_xmm_512(a, count_xmm) =
  avx_psraq_imm_512(a, clamp_shift_count(unsigned(count_xmm[63..0])))

// =========================================================================
// VMOVSLDUP — Duplicate Even-Indexed Single-FP Values
// Each pair of 32-bit floats: [A, B] → [A, A] (even index duplicated)
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
val select4_f32 : (bits(128), bits(2)) -> bits(32)
function select4_f32(src, ctrl) = match ctrl {
  0b00 => src[31..0],
  0b01 => src[63..32],
  0b10 => src[95..64],
  0b11 => src[127..96],
}

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
val avx_pshufb_128 : (xmmword, xmmword) -> xmmword
function avx_pshufb_128(src, ctrl) = {
  var r : xmmword = zeros();
  foreach (j from 0 to 15) {
    let jj : range(0, 120) = j * 8;
    let c : byte = ctrl[(jj + 7)..jj];
    if c[7] == bitone then
      r[(jj + 7)..jj] = 0x00
    else {
      let idx : range(0, 120) = unsigned(c[3..0]) * 8;
      r[(jj + 7)..jj] = src[(idx + 7)..idx];
    }
  };
  r
}
val avx_pshufb_256 : (ymmword, ymmword) -> ymmword
function avx_pshufb_256(src, ctrl) =
  avx_pshufb_128(src[255..128], ctrl[255..128]) @ avx_pshufb_128(src[127..0], ctrl[127..0])
val avx_pshufb_512 : (zmmword, zmmword) -> zmmword
function avx_pshufb_512(src, ctrl) =
  avx_pshufb_256(src[511..256], ctrl[511..256]) @ avx_pshufb_256(src[255..0], ctrl[255..0])

// VPMADDUBSW: multiply unsigned bytes by signed bytes, add pairs → signed words
val avx_pmaddubsw_128 : (xmmword, xmmword) -> xmmword
function avx_pmaddubsw_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    let b0 : range(0, 112) = i * 16;
    let b1 : range(0, 120) = i * 16 + 8;
    let prod0 : int = unsigned(a[(b0 + 7)..b0]) * signed(b[(b0 + 7)..b0]);
    let prod1 : int = unsigned(a[(b1 + 7)..b1]) * signed(b[(b1 + 7)..b1]);
    let sum : int = prod0 + prod1;
    // Saturate to signed 16-bit
    let sat : int = if sum > 32767 then 32767 else if sum < -32768 then -32768 else sum;
    r[(lo + 15)..lo] = to_bits_truncate(sat);
  };
  r
}
val avx_pmaddubsw_256 : (ymmword, ymmword) -> ymmword
function avx_pmaddubsw_256(a, b) =
  avx_pmaddubsw_128(a[255..128], b[255..128]) @ avx_pmaddubsw_128(a[127..0], b[127..0])
val avx_pmaddubsw_512 : (zmmword, zmmword) -> zmmword
function avx_pmaddubsw_512(a, b) =
  avx_pmaddubsw_256(a[511..256], b[511..256]) @ avx_pmaddubsw_256(a[255..0], b[255..0])

// VPMULHRSW: packed multiply high with round and scale (signed words)
// Result = (((a[i] * b[i]) >> 14) + 1) >> 1, truncated to 16 bits
val avx_pmulhrsw_128 : (xmmword, xmmword) -> xmmword
function avx_pmulhrsw_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    // Compute in 32-bit signed bitvectors to avoid Sail integer division issues
    let av : bits(32) = sign_extend(a[(lo + 15)..lo]);
    let bv : bits(32) = sign_extend(b[(lo + 15)..lo]);
    let prod : bits(32) = to_bits_truncate(signed(av) * signed(bv));
    // Arithmetic right shift by 14, add 1, arithmetic right shift by 1
    let shifted14 : bits(32) = sail_arith_shiftright(prod, 14);
    let plus1 : bits(32) = to_bits_truncate(signed(shifted14) + 1);
    let result : bits(32) = sail_arith_shiftright(plus1, 1);
    r[(lo + 15)..lo] = result[15..0];
  };
  r
}
val avx_pmulhrsw_256 : (ymmword, ymmword) -> ymmword
function avx_pmulhrsw_256(a, b) =
  avx_pmulhrsw_128(a[255..128], b[255..128]) @ avx_pmulhrsw_128(a[127..0], b[127..0])
val avx_pmulhrsw_512 : (zmmword, zmmword) -> zmmword
function avx_pmulhrsw_512(a, b) =
  avx_pmulhrsw_256(a[511..256], b[511..256]) @ avx_pmulhrsw_256(a[255..0], b[255..0])

// VPMULDQ: multiply packed signed dwords → packed signed qwords (even dwords only)
val avx_pmuldq_128 : (xmmword, xmmword) -> xmmword
function avx_pmuldq_128(a, b) = {
  let lo_prod : bits(64) = to_bits_truncate(signed(a[31..0]) * signed(b[31..0]));
  let hi_prod : bits(64) = to_bits_truncate(signed(a[95..64]) * signed(b[95..64]));
  hi_prod @ lo_prod
}
val avx_pmuldq_256 : (ymmword, ymmword) -> ymmword
function avx_pmuldq_256(a, b) =
  avx_pmuldq_128(a[255..128], b[255..128]) @ avx_pmuldq_128(a[127..0], b[127..0])
val avx_pmuldq_512 : (zmmword, zmmword) -> zmmword
function avx_pmuldq_512(a, b) =
  avx_pmuldq_256(a[511..256], b[511..256]) @ avx_pmuldq_256(a[255..0], b[255..0])

// VPMULLD: multiply packed dwords, low 32-bit result
val avx_pmulld_128 : (xmmword, xmmword) -> xmmword
function avx_pmulld_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    let prod : int = signed(a[(lo + 31)..lo]) * signed(b[(lo + 31)..lo]);
    r[(lo + 31)..lo] = to_bits_truncate(prod);
  };
  r
}
val avx_pmulld_256 : (ymmword, ymmword) -> ymmword
function avx_pmulld_256(a, b) =
  avx_pmulld_128(a[255..128], b[255..128]) @ avx_pmulld_128(a[127..0], b[127..0])
val avx_pmulld_512 : (zmmword, zmmword) -> zmmword
function avx_pmulld_512(a, b) =
  avx_pmulld_256(a[511..256], b[511..256]) @ avx_pmulld_256(a[255..0], b[255..0])

// VPMULLQ: multiply packed qwords, low 64-bit result
val avx_pmullq_128 : (xmmword, xmmword) -> xmmword
function avx_pmullq_128(a, b) = {
  let lo_prod : bits(64) = to_bits_truncate(signed(a[63..0]) * signed(b[63..0]));
  let hi_prod : bits(64) = to_bits_truncate(signed(a[127..64]) * signed(b[127..64]));
  hi_prod @ lo_prod
}
val avx_pmullq_256 : (ymmword, ymmword) -> ymmword
function avx_pmullq_256(a, b) =
  avx_pmullq_128(a[255..128], b[255..128]) @ avx_pmullq_128(a[127..0], b[127..0])
val avx_pmullq_512 : (zmmword, zmmword) -> zmmword
function avx_pmullq_512(a, b) =
  avx_pmullq_256(a[511..256], b[511..256]) @ avx_pmullq_256(a[255..0], b[255..0])

// VPERMILPS (register control): per-element select within 128-bit lane
val avx_vpermilps_128 : (xmmword, xmmword) -> xmmword
function avx_vpermilps_128(src, ctrl) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    let sel : bits(2) = ctrl[(lo + 1)..lo];
    r[(lo + 31)..lo] = select4_f32(src, sel);
  };
  r
}
val avx_vpermilps_256 : (ymmword, ymmword) -> ymmword
function avx_vpermilps_256(src, ctrl) =
  avx_vpermilps_128(src[255..128], ctrl[255..128]) @ avx_vpermilps_128(src[127..0], ctrl[127..0])
val avx_vpermilps_512 : (zmmword, zmmword) -> zmmword
function avx_vpermilps_512(src, ctrl) =
  avx_vpermilps_256(src[511..256], ctrl[511..256]) @ avx_vpermilps_256(src[255..0], ctrl[255..0])

// VPERMILPD (register control): per-element select within 128-bit lane
// Each qword in ctrl: bit 1 selects low(0) or high(1) qword from lane
val avx_vpermilpd_128 : (xmmword, xmmword) -> xmmword
function avx_vpermilpd_128(src, ctrl) = {
  let lo : bits(64) = if ctrl[1] == bitone then src[127..64] else src[63..0];
  let hi : bits(64) = if ctrl[65] == bitone then src[127..64] else src[63..0];
  hi @ lo
}
val avx_vpermilpd_256 : (ymmword, ymmword) -> ymmword
function avx_vpermilpd_256(src, ctrl) =
  avx_vpermilpd_128(src[255..128], ctrl[255..128]) @ avx_vpermilpd_128(src[127..0], ctrl[127..0])
val avx_vpermilpd_512 : (zmmword, zmmword) -> zmmword
function avx_vpermilpd_512(src, ctrl) =
  avx_vpermilpd_256(src[511..256], ctrl[511..256]) @ avx_vpermilpd_256(src[255..0], ctrl[255..0])

// VPERMPS: full cross-lane permute of f32 using index register
val avx_vpermps_256 : (ymmword, ymmword) -> ymmword
function avx_vpermps_256(src, idx) = {
  var r : ymmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 224) = i * 32;
    let sel : range(0, 224) = unsigned(idx[(lo + 2)..lo]) * 32;
    r[(lo + 31)..lo] = src[(sel + 31)..sel];
  };
  r
}
val avx_vpermps_512 : (zmmword, zmmword) -> zmmword
function avx_vpermps_512(src, idx) = {
  var r : zmmword = zeros();
  foreach (i from 0 to 15) {
    let lo : range(0, 480) = i * 32;
    let sel : range(0, 480) = unsigned(idx[(lo + 3)..lo]) * 32;
    r[(lo + 31)..lo] = src[(sel + 31)..sel];
  };
  r
}

// VPERMPD: full cross-lane permute of f64 using index register
val avx_vpermpd_256 : (ymmword, ymmword) -> ymmword
function avx_vpermpd_256(src, idx) = {
  var r : ymmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 192) = i * 64;
    let sel : range(0, 192) = unsigned(idx[(lo + 1)..lo]) * 64;
    r[(lo + 63)..lo] = src[(sel + 63)..sel];
  };
  r
}
val avx_vpermpd_512 : (zmmword, zmmword) -> zmmword
function avx_vpermpd_512(src, idx) = {
  var r : zmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 448) = i * 64;
    let sel : range(0, 448) = unsigned(idx[(lo + 2)..lo]) * 64;
    r[(lo + 63)..lo] = src[(sel + 63)..sel];
  };
  r
}

// VPERMD: full cross-lane permute of dwords using index register
val avx_vpermd_256 : (ymmword, ymmword) -> ymmword
function avx_vpermd_256(src, idx) = {
  var r : ymmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 224) = i * 32;
    let sel : range(0, 224) = unsigned(idx[(lo + 2)..lo]) * 32;
    r[(lo + 31)..lo] = src[(sel + 31)..sel];
  };
  r
}
val avx_vpermd_512 : (zmmword, zmmword) -> zmmword
function avx_vpermd_512(src, idx) = {
  var r : zmmword = zeros();
  foreach (i from 0 to 15) {
    let lo : range(0, 480) = i * 32;
    let sel : range(0, 480) = unsigned(idx[(lo + 3)..lo]) * 32;
    r[(lo + 31)..lo] = src[(sel + 31)..sel];
  };
  r
}

// VPERMQ: full cross-lane permute of qwords using index register
val avx_vpermq_256 : (ymmword, ymmword) -> ymmword
function avx_vpermq_256(src, idx) = {
  var r : ymmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 192) = i * 64;
    let sel : range(0, 192) = unsigned(idx[(lo + 1)..lo]) * 64;
    r[(lo + 63)..lo] = src[(sel + 63)..sel];
  };
  r
}
val avx_vpermq_512 : (zmmword, zmmword) -> zmmword
function avx_vpermq_512(src, idx) = {
  var r : zmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 448) = i * 64;
    let sel : range(0, 448) = unsigned(idx[(lo + 2)..lo]) * 64;
    r[(lo + 63)..lo] = src[(sel + 63)..sel];
  };
  r
}

// =========================================================================
// VPMOVSXBW: Sign-extend packed bytes to words
// =========================================================================
val avx_pmovsxbw_128 : qword -> xmmword
function avx_pmovsxbw_128(src) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let slo : range(0, 56) = i * 8;
    let dlo : range(0, 112) = i * 16;
    let v : word = sign_extend(src[(slo + 7)..slo]);
    r[(dlo + 15)..dlo] = v;
  };
  r
}
val avx_pmovsxbw_256 : xmmword -> ymmword
function avx_pmovsxbw_256(src) = avx_pmovsxbw_128(src[127..64]) @ avx_pmovsxbw_128(src[63..0])
val avx_pmovsxbw_512 : ymmword -> zmmword
function avx_pmovsxbw_512(src) = avx_pmovsxbw_256(src[255..128]) @ avx_pmovsxbw_256(src[127..0])

// VPMOVSXBD: Sign-extend packed bytes to dwords
val avx_pmovsxbd_128 : dword -> xmmword
function avx_pmovsxbd_128(src) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let slo : range(0, 24) = i * 8;
    let dlo : range(0, 96) = i * 32;
    let v : dword = sign_extend(src[(slo + 7)..slo]);
    r[(dlo + 31)..dlo] = v;
  };
  r
}
val avx_pmovsxbd_256 : qword -> ymmword
function avx_pmovsxbd_256(src) = avx_pmovsxbd_128(src[63..32]) @ avx_pmovsxbd_128(src[31..0])
val avx_pmovsxbd_512 : xmmword -> zmmword
function avx_pmovsxbd_512(src) = avx_pmovsxbd_256(src[127..64]) @ avx_pmovsxbd_256(src[63..0])

// VPMOVSXBQ: Sign-extend packed bytes to qwords
val avx_pmovsxbq_128 : word -> xmmword
function avx_pmovsxbq_128(src) = {
  let lo : qword = sign_extend(src[7..0]);
  let hi : qword = sign_extend(src[15..8]);
  hi @ lo
}
val avx_pmovsxbq_256 : dword -> ymmword
function avx_pmovsxbq_256(src) = avx_pmovsxbq_128(src[31..16]) @ avx_pmovsxbq_128(src[15..0])
val avx_pmovsxbq_512 : qword -> zmmword
function avx_pmovsxbq_512(src) = avx_pmovsxbq_256(src[63..32]) @ avx_pmovsxbq_256(src[31..0])

// VPMOVSXWD: Sign-extend packed words to dwords
val avx_pmovsxwd_128 : qword -> xmmword
function avx_pmovsxwd_128(src) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let slo : range(0, 48) = i * 16;
    let dlo : range(0, 96) = i * 32;
    let v : dword = sign_extend(src[(slo + 15)..slo]);
    r[(dlo + 31)..dlo] = v;
  };
  r
}
val avx_pmovsxwd_256 : xmmword -> ymmword
function avx_pmovsxwd_256(src) = avx_pmovsxwd_128(src[127..64]) @ avx_pmovsxwd_128(src[63..0])
val avx_pmovsxwd_512 : ymmword -> zmmword
function avx_pmovsxwd_512(src) = avx_pmovsxwd_256(src[255..128]) @ avx_pmovsxwd_256(src[127..0])

// VPMOVSXWQ: Sign-extend packed words to qwords
val avx_pmovsxwq_128 : dword -> xmmword
function avx_pmovsxwq_128(src) = {
  let lo : qword = sign_extend(src[15..0]);
  let hi : qword = sign_extend(src[31..16]);
  hi @ lo
}
val avx_pmovsxwq_256 : qword -> ymmword
function avx_pmovsxwq_256(src) = avx_pmovsxwq_128(src[63..32]) @ avx_pmovsxwq_128(src[31..0])
val avx_pmovsxwq_512 : xmmword -> zmmword
function avx_pmovsxwq_512(src) = avx_pmovsxwq_256(src[127..64]) @ avx_pmovsxwq_256(src[63..0])

// VPMOVSXDQ: Sign-extend packed dwords to qwords
val avx_pmovsxdq_128 : qword -> xmmword
function avx_pmovsxdq_128(src) = {
  let lo : qword = sign_extend(src[31..0]);
  let hi : qword = sign_extend(src[63..32]);
  hi @ lo
}
val avx_pmovsxdq_256 : xmmword -> ymmword
function avx_pmovsxdq_256(src) = avx_pmovsxdq_128(src[127..64]) @ avx_pmovsxdq_128(src[63..0])
val avx_pmovsxdq_512 : ymmword -> zmmword
function avx_pmovsxdq_512(src) = avx_pmovsxdq_256(src[255..128]) @ avx_pmovsxdq_256(src[127..0])

// =========================================================================
// VPMOVZXBW: Zero-extend packed bytes to words
// =========================================================================
val avx_pmovzxbw_128 : qword -> xmmword
function avx_pmovzxbw_128(src) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let slo : range(0, 56) = i * 8;
    let dlo : range(0, 112) = i * 16;
    let v : word = zero_extend(src[(slo + 7)..slo]);
    r[(dlo + 15)..dlo] = v;
  };
  r
}
val avx_pmovzxbw_256 : xmmword -> ymmword
function avx_pmovzxbw_256(src) = avx_pmovzxbw_128(src[127..64]) @ avx_pmovzxbw_128(src[63..0])
val avx_pmovzxbw_512 : ymmword -> zmmword
function avx_pmovzxbw_512(src) = avx_pmovzxbw_256(src[255..128]) @ avx_pmovzxbw_256(src[127..0])

// VPMOVZXBD: Zero-extend packed bytes to dwords
val avx_pmovzxbd_128 : dword -> xmmword
function avx_pmovzxbd_128(src) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let slo : range(0, 24) = i * 8;
    let dlo : range(0, 96) = i * 32;
    let v : dword = zero_extend(src[(slo + 7)..slo]);
    r[(dlo + 31)..dlo] = v;
  };
  r
}
val avx_pmovzxbd_256 : qword -> ymmword
function avx_pmovzxbd_256(src) = avx_pmovzxbd_128(src[63..32]) @ avx_pmovzxbd_128(src[31..0])
val avx_pmovzxbd_512 : xmmword -> zmmword
function avx_pmovzxbd_512(src) = avx_pmovzxbd_256(src[127..64]) @ avx_pmovzxbd_256(src[63..0])

// VPMOVZXBQ: Zero-extend packed bytes to qwords
val avx_pmovzxbq_128 : word -> xmmword
function avx_pmovzxbq_128(src) = {
  let lo : qword = zero_extend(src[7..0]);
  let hi : qword = zero_extend(src[15..8]);
  hi @ lo
}
val avx_pmovzxbq_256 : dword -> ymmword
function avx_pmovzxbq_256(src) = avx_pmovzxbq_128(src[31..16]) @ avx_pmovzxbq_128(src[15..0])
val avx_pmovzxbq_512 : qword -> zmmword
function avx_pmovzxbq_512(src) = avx_pmovzxbq_256(src[63..32]) @ avx_pmovzxbq_256(src[31..0])

// VPMOVZXWD: Zero-extend packed words to dwords
val avx_pmovzxwd_128 : qword -> xmmword
function avx_pmovzxwd_128(src) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let slo : range(0, 48) = i * 16;
    let dlo : range(0, 96) = i * 32;
    let v : dword = zero_extend(src[(slo + 15)..slo]);
    r[(dlo + 31)..dlo] = v;
  };
  r
}
val avx_pmovzxwd_256 : xmmword -> ymmword
function avx_pmovzxwd_256(src) = avx_pmovzxwd_128(src[127..64]) @ avx_pmovzxwd_128(src[63..0])
val avx_pmovzxwd_512 : ymmword -> zmmword
function avx_pmovzxwd_512(src) = avx_pmovzxwd_256(src[255..128]) @ avx_pmovzxwd_256(src[127..0])

// VPMOVZXWQ: Zero-extend packed words to qwords
val avx_pmovzxwq_128 : dword -> xmmword
function avx_pmovzxwq_128(src) = {
  let lo : qword = zero_extend(src[15..0]);
  let hi : qword = zero_extend(src[31..16]);
  hi @ lo
}
val avx_pmovzxwq_256 : qword -> ymmword
function avx_pmovzxwq_256(src) = avx_pmovzxwq_128(src[63..32]) @ avx_pmovzxwq_128(src[31..0])
val avx_pmovzxwq_512 : xmmword -> zmmword
function avx_pmovzxwq_512(src) = avx_pmovzxwq_256(src[127..64]) @ avx_pmovzxwq_256(src[63..0])

// VPMOVZXDQ: Zero-extend packed dwords to qwords
val avx_pmovzxdq_128 : qword -> xmmword
function avx_pmovzxdq_128(src) = {
  let lo : qword = zero_extend(src[31..0]);
  let hi : qword = zero_extend(src[63..32]);
  hi @ lo
}
val avx_pmovzxdq_256 : xmmword -> ymmword
function avx_pmovzxdq_256(src) = avx_pmovzxdq_128(src[127..64]) @ avx_pmovzxdq_128(src[63..0])
val avx_pmovzxdq_512 : ymmword -> zmmword
function avx_pmovzxdq_512(src) = avx_pmovzxdq_256(src[255..128]) @ avx_pmovzxdq_256(src[127..0])

// =========================================================================
// Variable-count shifts: VPSRLVD/Q, VPSRAVD/Q, VPSLLVD/Q
// Each element is shifted by a different count from the count vector
// =========================================================================

// VPSRLVD: variable logical right shift dwords
val avx_psrlvd_128 : (xmmword, xmmword) -> xmmword
function avx_psrlvd_128(src, cnt) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    let c : bits(32) = cnt[(lo + 31)..lo];
    if unsigned(c) >= 32 then r[(lo + 31)..lo] = zeros()
    else r[(lo + 31)..lo] = shift_bits_right(src[(lo + 31)..lo], c);
  };
  r
}
val avx_psrlvd_256 : (ymmword, ymmword) -> ymmword
function avx_psrlvd_256(a, b) =
  avx_psrlvd_128(a[255..128], b[255..128]) @ avx_psrlvd_128(a[127..0], b[127..0])
val avx_psrlvd_512 : (zmmword, zmmword) -> zmmword
function avx_psrlvd_512(a, b) =
  avx_psrlvd_256(a[511..256], b[511..256]) @ avx_psrlvd_256(a[255..0], b[255..0])

// VPSRLVQ: variable logical right shift qwords
val avx_psrlvq_128 : (xmmword, xmmword) -> xmmword
function avx_psrlvq_128(src, cnt) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 1) {
    let lo : range(0, 64) = i * 64;
    let c : bits(64) = cnt[(lo + 63)..lo];
    if unsigned(c) >= 64 then r[(lo + 63)..lo] = zeros()
    else r[(lo + 63)..lo] = shift_bits_right(src[(lo + 63)..lo], c);
  };
  r
}
val avx_psrlvq_256 : (ymmword, ymmword) -> ymmword
function avx_psrlvq_256(a, b) =
  avx_psrlvq_128(a[255..128], b[255..128]) @ avx_psrlvq_128(a[127..0], b[127..0])
val avx_psrlvq_512 : (zmmword, zmmword) -> zmmword
function avx_psrlvq_512(a, b) =
  avx_psrlvq_256(a[511..256], b[511..256]) @ avx_psrlvq_256(a[255..0], b[255..0])

// VPSRAVD: variable arithmetic right shift dwords
val avx_psravd_128 : (xmmword, xmmword) -> xmmword
function avx_psravd_128(src, cnt) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    let c : range(0, 4294967295) = unsigned(cnt[(lo + 31)..lo]);
    let elem : bits(32) = src[(lo + 31)..lo];
    if c >= 32 then {
      if elem[31] == bitone then r[(lo + 31)..lo] = ones()
      else r[(lo + 31)..lo] = zeros()
    } else {
      let shift_amt : range(0, 31) = c;
      r[(lo + 31)..lo] = sail_arith_shiftright(elem, shift_amt);
    }
  };
  r
}
val avx_psravd_256 : (ymmword, ymmword) -> ymmword
function avx_psravd_256(a, b) =
  avx_psravd_128(a[255..128], b[255..128]) @ avx_psravd_128(a[127..0], b[127..0])
val avx_psravd_512 : (zmmword, zmmword) -> zmmword
function avx_psravd_512(a, b) =
  avx_psravd_256(a[511..256], b[511..256]) @ avx_psravd_256(a[255..0], b[255..0])

// VPSRAVQ: variable arithmetic right shift qwords
val avx_psravq_128 : (xmmword, xmmword) -> xmmword
function avx_psravq_128(src, cnt) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 1) {
    let lo : range(0, 64) = i * 64;
    let c = unsigned(cnt[(lo + 63)..lo]);
    let elem : bits(64) = src[(lo + 63)..lo];
    if c >= 64 then {
      if elem[63] == bitone then r[(lo + 63)..lo] = ones()
      else r[(lo + 63)..lo] = zeros()
    } else {
      let shift_amt : range(0, 63) = c;
      r[(lo + 63)..lo] = sail_arith_shiftright(elem, shift_amt);
    }
  };
  r
}
val avx_psravq_256 : (ymmword, ymmword) -> ymmword
function avx_psravq_256(a, b) =
  avx_psravq_128(a[255..128], b[255..128]) @ avx_psravq_128(a[127..0], b[127..0])
val avx_psravq_512 : (zmmword, zmmword) -> zmmword
function avx_psravq_512(a, b) =
  avx_psravq_256(a[511..256], b[511..256]) @ avx_psravq_256(a[255..0], b[255..0])

// VPSLLVD: variable logical left shift dwords
val avx_psllvd_128 : (xmmword, xmmword) -> xmmword
function avx_psllvd_128(src, cnt) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    let c : bits(32) = cnt[(lo + 31)..lo];
    if unsigned(c) >= 32 then r[(lo + 31)..lo] = zeros()
    else r[(lo + 31)..lo] = shift_bits_left(src[(lo + 31)..lo], c);
  };
  r
}
val avx_psllvd_256 : (ymmword, ymmword) -> ymmword
function avx_psllvd_256(a, b) =
  avx_psllvd_128(a[255..128], b[255..128]) @ avx_psllvd_128(a[127..0], b[127..0])
val avx_psllvd_512 : (zmmword, zmmword) -> zmmword
function avx_psllvd_512(a, b) =
  avx_psllvd_256(a[511..256], b[511..256]) @ avx_psllvd_256(a[255..0], b[255..0])

// VPSLLVQ: variable logical left shift qwords
val avx_psllvq_128 : (xmmword, xmmword) -> xmmword
function avx_psllvq_128(src, cnt) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 1) {
    let lo : range(0, 64) = i * 64;
    let c : bits(64) = cnt[(lo + 63)..lo];
    if unsigned(c) >= 64 then r[(lo + 63)..lo] = zeros()
    else r[(lo + 63)..lo] = shift_bits_left(src[(lo + 63)..lo], c);
  };
  r
}
val avx_psllvq_256 : (ymmword, ymmword) -> ymmword
function avx_psllvq_256(a, b) =
  avx_psllvq_128(a[255..128], b[255..128]) @ avx_psllvq_128(a[127..0], b[127..0])
val avx_psllvq_512 : (zmmword, zmmword) -> zmmword
function avx_psllvq_512(a, b) =
  avx_psllvq_256(a[511..256], b[511..256]) @ avx_psllvq_256(a[255..0], b[255..0])

// VPSRLVW: variable logical right shift words
val avx_psrlvw_128 : (xmmword, xmmword) -> xmmword
function avx_psrlvw_128(src, cnt) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    let c : bits(16) = cnt[(lo + 15)..lo];
    if unsigned(c) >= 16 then r[(lo + 15)..lo] = zeros()
    else r[(lo + 15)..lo] = shift_bits_right(src[(lo + 15)..lo], c);
  };
  r
}
val avx_psrlvw_256 : (ymmword, ymmword) -> ymmword
function avx_psrlvw_256(a, b) =
  avx_psrlvw_128(a[255..128], b[255..128]) @ avx_psrlvw_128(a[127..0], b[127..0])
val avx_psrlvw_512 : (zmmword, zmmword) -> zmmword
function avx_psrlvw_512(a, b) =
  avx_psrlvw_256(a[511..256], b[511..256]) @ avx_psrlvw_256(a[255..0], b[255..0])

// VPSRAVW: variable arithmetic right shift words
val avx_psravw_128 : (xmmword, xmmword) -> xmmword
function avx_psravw_128(src, cnt) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    let c : range(0, 65535) = unsigned(cnt[(lo + 15)..lo]);
    let elem : bits(16) = src[(lo + 15)..lo];
    if c >= 16 then {
      if elem[15] == bitone then r[(lo + 15)..lo] = ones()
      else r[(lo + 15)..lo] = zeros()
    } else {
      let shift_amt : range(0, 15) = c;
      r[(lo + 15)..lo] = sail_arith_shiftright(elem, shift_amt);
    }
  };
  r
}
val avx_psravw_256 : (ymmword, ymmword) -> ymmword
function avx_psravw_256(a, b) =
  avx_psravw_128(a[255..128], b[255..128]) @ avx_psravw_128(a[127..0], b[127..0])
val avx_psravw_512 : (zmmword, zmmword) -> zmmword
function avx_psravw_512(a, b) =
  avx_psravw_256(a[511..256], b[511..256]) @ avx_psravw_256(a[255..0], b[255..0])

// VPSLLVW: variable logical left shift words
val avx_psllvw_128 : (xmmword, xmmword) -> xmmword
function avx_psllvw_128(src, cnt) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    let c : bits(16) = cnt[(lo + 15)..lo];
    if unsigned(c) >= 16 then r[(lo + 15)..lo] = zeros()
    else r[(lo + 15)..lo] = shift_bits_left(src[(lo + 15)..lo], c);
  };
  r
}
val avx_psllvw_256 : (ymmword, ymmword) -> ymmword
function avx_psllvw_256(a, b) =
  avx_psllvw_128(a[255..128], b[255..128]) @ avx_psllvw_128(a[127..0], b[127..0])
val avx_psllvw_512 : (zmmword, zmmword) -> zmmword
function avx_psllvw_512(a, b) =
  avx_psllvw_256(a[511..256], b[511..256]) @ avx_psllvw_256(a[255..0], b[255..0])

// VPRORVD: variable rotate right dwords
val avx_prorvd_128 : (xmmword, xmmword) -> xmmword
function avx_prorvd_128(src, cnt) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    let c : range(0, 31) = unsigned(cnt[(lo + 4)..lo]);
    let elem : bits(32) = src[(lo + 31)..lo];
    if c == 0 then r[(lo + 31)..lo] = elem
    else {
      let rc : range(1, 31) = 32 - c;
      r[(lo + 31)..lo] = shift_bits_right(elem, cnt[(lo + 4)..lo]) | shift_bits_left(elem, to_bits(5, rc));
    }
  };
  r
}
val avx_prorvd_256 : (ymmword, ymmword) -> ymmword
function avx_prorvd_256(a, b) =
  avx_prorvd_128(a[255..128], b[255..128]) @ avx_prorvd_128(a[127..0], b[127..0])
val avx_prorvd_512 : (zmmword, zmmword) -> zmmword
function avx_prorvd_512(a, b) =
  avx_prorvd_256(a[511..256], b[511..256]) @ avx_prorvd_256(a[255..0], b[255..0])

// VPRORVQ: variable rotate right qwords
val avx_prorvq_128 : (xmmword, xmmword) -> xmmword
function avx_prorvq_128(src, cnt) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 1) {
    let lo : range(0, 64) = i * 64;
    let c : range(0, 63) = unsigned(cnt[(lo + 5)..lo]);
    let elem : bits(64) = src[(lo + 63)..lo];
    if c == 0 then r[(lo + 63)..lo] = elem
    else {
      let rc : range(1, 63) = 64 - c;
      r[(lo + 63)..lo] = shift_bits_right(elem, cnt[(lo + 5)..lo]) | shift_bits_left(elem, to_bits(6, rc));
    }
  };
  r
}
val avx_prorvq_256 : (ymmword, ymmword) -> ymmword
function avx_prorvq_256(a, b) =
  avx_prorvq_128(a[255..128], b[255..128]) @ avx_prorvq_128(a[127..0], b[127..0])
val avx_prorvq_512 : (zmmword, zmmword) -> zmmword
function avx_prorvq_512(a, b) =
  avx_prorvq_256(a[511..256], b[511..256]) @ avx_prorvq_256(a[255..0], b[255..0])

// VPROLVD: variable rotate left dwords
val avx_prolvd_128 : (xmmword, xmmword) -> xmmword
function avx_prolvd_128(src, cnt) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    let c : range(0, 31) = unsigned(cnt[(lo + 4)..lo]);
    let elem : bits(32) = src[(lo + 31)..lo];
    if c == 0 then r[(lo + 31)..lo] = elem
    else {
      let rc : range(1, 31) = 32 - c;
      r[(lo + 31)..lo] = shift_bits_left(elem, cnt[(lo + 4)..lo]) | shift_bits_right(elem, to_bits(5, rc));
    }
  };
  r
}
val avx_prolvd_256 : (ymmword, ymmword) -> ymmword
function avx_prolvd_256(a, b) =
  avx_prolvd_128(a[255..128], b[255..128]) @ avx_prolvd_128(a[127..0], b[127..0])
val avx_prolvd_512 : (zmmword, zmmword) -> zmmword
function avx_prolvd_512(a, b) =
  avx_prolvd_256(a[511..256], b[511..256]) @ avx_prolvd_256(a[255..0], b[255..0])

// VPROLVQ: variable rotate left qwords
val avx_prolvq_128 : (xmmword, xmmword) -> xmmword
function avx_prolvq_128(src, cnt) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 1) {
    let lo : range(0, 64) = i * 64;
    let c : range(0, 63) = unsigned(cnt[(lo + 5)..lo]);
    let elem : bits(64) = src[(lo + 63)..lo];
    if c == 0 then r[(lo + 63)..lo] = elem
    else {
      let rc : range(1, 63) = 64 - c;
      r[(lo + 63)..lo] = shift_bits_left(elem, cnt[(lo + 5)..lo]) | shift_bits_right(elem, to_bits(6, rc));
    }
  };
  r
}
val avx_prolvq_256 : (ymmword, ymmword) -> ymmword
function avx_prolvq_256(a, b) =
  avx_prolvq_128(a[255..128], b[255..128]) @ avx_prolvq_128(a[127..0], b[127..0])
val avx_prolvq_512 : (zmmword, zmmword) -> zmmword
function avx_prolvq_512(a, b) =
  avx_prolvq_256(a[511..256], b[511..256]) @ avx_prolvq_256(a[255..0], b[255..0])

// =========================================================================
// VPABSB: absolute value of packed signed bytes
// =========================================================================

val avx_pabsb_128 : (xmmword) -> xmmword
function avx_pabsb_128(a) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 15) {
    let lo : range(0, 120) = i * 8;
    let va = a[(lo + 7)..lo];
    let sv = signed(va);
    r[(lo + 7)..lo] = if sv < 0 then to_bits_truncate(negate(sv)) else va;
  };
  r
}
val avx_pabsb_256 : (ymmword) -> ymmword
function avx_pabsb_256(a) =
  avx_pabsb_128(a[255..128]) @ avx_pabsb_128(a[127..0])
val avx_pabsb_512 : (zmmword) -> zmmword
function avx_pabsb_512(a) =
  avx_pabsb_256(a[511..256]) @ avx_pabsb_256(a[255..0])

// =========================================================================
// VPABSW: absolute value of packed signed words
// =========================================================================

val avx_pabsw_128 : (xmmword) -> xmmword
function avx_pabsw_128(a) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    let va = a[(lo + 15)..lo];
    let sv = signed(va);
    r[(lo + 15)..lo] = if sv < 0 then to_bits_truncate(negate(sv)) else va;
  };
  r
}
val avx_pabsw_256 : (ymmword) -> ymmword
function avx_pabsw_256(a) =
  avx_pabsw_128(a[255..128]) @ avx_pabsw_128(a[127..0])
val avx_pabsw_512 : (zmmword) -> zmmword
function avx_pabsw_512(a) =
  avx_pabsw_256(a[511..256]) @ avx_pabsw_256(a[255..0])

// =========================================================================
// VPABSD: absolute value of packed signed dwords
// =========================================================================

val avx_pabsd_128 : (xmmword) -> xmmword
function avx_pabsd_128(a) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    let va = a[(lo + 31)..lo];
    let sv = signed(va);
    r[(lo + 31)..lo] = if sv < 0 then to_bits_truncate(negate(sv)) else va;
  };
  r
}
val avx_pabsd_256 : (ymmword) -> ymmword
function avx_pabsd_256(a) =
  avx_pabsd_128(a[255..128]) @ avx_pabsd_128(a[127..0])
val avx_pabsd_512 : (zmmword) -> zmmword
function avx_pabsd_512(a) =
  avx_pabsd_256(a[511..256]) @ avx_pabsd_256(a[255..0])

// =========================================================================
// VPABSQ: absolute value of packed signed qwords
// =========================================================================

val avx_pabsq_128 : (xmmword) -> xmmword
function avx_pabsq_128(a) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 1) {
    let lo : range(0, 64) = i * 64;
    let va = a[(lo + 63)..lo];
    let sv = signed(va);
    r[(lo + 63)..lo] = if sv < 0 then to_bits_truncate(negate(sv)) else va;
  };
  r
}
val avx_pabsq_256 : (ymmword) -> ymmword
function avx_pabsq_256(a) =
  avx_pabsq_128(a[255..128]) @ avx_pabsq_128(a[127..0])
val avx_pabsq_512 : (zmmword) -> zmmword
function avx_pabsq_512(a) =
  avx_pabsq_256(a[511..256]) @ avx_pabsq_256(a[255..0])

// =========================================================================
// VPMINSB: signed byte min
// =========================================================================

val avx_pminsb_128 : (xmmword, xmmword) -> xmmword
function avx_pminsb_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 15) {
    let lo : range(0, 120) = i * 8;
    let va = a[(lo + 7)..lo];
    let vb = b[(lo + 7)..lo];
    r[(lo + 7)..lo] = if signed(va) < signed(vb) then va else vb;
  };
  r
}
val avx_pminsb_256 : (ymmword, ymmword) -> ymmword
function avx_pminsb_256(a, b) =
  avx_pminsb_128(a[255..128], b[255..128]) @ avx_pminsb_128(a[127..0], b[127..0])
val avx_pminsb_512 : (zmmword, zmmword) -> zmmword
function avx_pminsb_512(a, b) =
  avx_pminsb_256(a[511..256], b[511..256]) @ avx_pminsb_256(a[255..0], b[255..0])

// =========================================================================
// VPMINSD: signed dword min
// =========================================================================

val avx_pminsd_128 : (xmmword, xmmword) -> xmmword
function avx_pminsd_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    let va = a[(lo + 31)..lo];
    let vb = b[(lo + 31)..lo];
    r[(lo + 31)..lo] = if signed(va) < signed(vb) then va else vb;
  };
  r
}
val avx_pminsd_256 : (ymmword, ymmword) -> ymmword
function avx_pminsd_256(a, b) =
  avx_pminsd_128(a[255..128], b[255..128]) @ avx_pminsd_128(a[127..0], b[127..0])
val avx_pminsd_512 : (zmmword, zmmword) -> zmmword
function avx_pminsd_512(a, b) =
  avx_pminsd_256(a[511..256], b[511..256]) @ avx_pminsd_256(a[255..0], b[255..0])

// =========================================================================
// VPMINSQ: signed qword min
// =========================================================================

val avx_pminsq_128 : (xmmword, xmmword) -> xmmword
function avx_pminsq_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 1) {
    let lo : range(0, 64) = i * 64;
    let va = a[(lo + 63)..lo];
    let vb = b[(lo + 63)..lo];
    r[(lo + 63)..lo] = if signed(va) < signed(vb) then va else vb;
  };
  r
}
val avx_pminsq_256 : (ymmword, ymmword) -> ymmword
function avx_pminsq_256(a, b) =
  avx_pminsq_128(a[255..128], b[255..128]) @ avx_pminsq_128(a[127..0], b[127..0])
val avx_pminsq_512 : (zmmword, zmmword) -> zmmword
function avx_pminsq_512(a, b) =
  avx_pminsq_256(a[511..256], b[511..256]) @ avx_pminsq_256(a[255..0], b[255..0])

// =========================================================================
// VPMAXSB: signed byte max
// =========================================================================

val avx_pmaxsb_128 : (xmmword, xmmword) -> xmmword
function avx_pmaxsb_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 15) {
    let lo : range(0, 120) = i * 8;
    let va = a[(lo + 7)..lo];
    let vb = b[(lo + 7)..lo];
    r[(lo + 7)..lo] = if signed(va) > signed(vb) then va else vb;
  };
  r
}
val avx_pmaxsb_256 : (ymmword, ymmword) -> ymmword
function avx_pmaxsb_256(a, b) =
  avx_pmaxsb_128(a[255..128], b[255..128]) @ avx_pmaxsb_128(a[127..0], b[127..0])
val avx_pmaxsb_512 : (zmmword, zmmword) -> zmmword
function avx_pmaxsb_512(a, b) =
  avx_pmaxsb_256(a[511..256], b[511..256]) @ avx_pmaxsb_256(a[255..0], b[255..0])

// =========================================================================
// VPMAXSD: signed dword max
// =========================================================================

val avx_pmaxsd_128 : (xmmword, xmmword) -> xmmword
function avx_pmaxsd_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    let va = a[(lo + 31)..lo];
    let vb = b[(lo + 31)..lo];
    r[(lo + 31)..lo] = if signed(va) > signed(vb) then va else vb;
  };
  r
}
val avx_pmaxsd_256 : (ymmword, ymmword) -> ymmword
function avx_pmaxsd_256(a, b) =
  avx_pmaxsd_128(a[255..128], b[255..128]) @ avx_pmaxsd_128(a[127..0], b[127..0])
val avx_pmaxsd_512 : (zmmword, zmmword) -> zmmword
function avx_pmaxsd_512(a, b) =
  avx_pmaxsd_256(a[511..256], b[511..256]) @ avx_pmaxsd_256(a[255..0], b[255..0])

// =========================================================================
// VPMAXSQ: signed qword max
// =========================================================================

val avx_pmaxsq_128 : (xmmword, xmmword) -> xmmword
function avx_pmaxsq_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 1) {
    let lo : range(0, 64) = i * 64;
    let va = a[(lo + 63)..lo];
    let vb = b[(lo + 63)..lo];
    r[(lo + 63)..lo] = if signed(va) > signed(vb) then va else vb;
  };
  r
}
val avx_pmaxsq_256 : (ymmword, ymmword) -> ymmword
function avx_pmaxsq_256(a, b) =
  avx_pmaxsq_128(a[255..128], b[255..128]) @ avx_pmaxsq_128(a[127..0], b[127..0])
val avx_pmaxsq_512 : (zmmword, zmmword) -> zmmword
function avx_pmaxsq_512(a, b) =
  avx_pmaxsq_256(a[511..256], b[511..256]) @ avx_pmaxsq_256(a[255..0], b[255..0])

// =========================================================================
// VPMAXUW: unsigned word max
// =========================================================================

val avx_pmaxuw_128 : (xmmword, xmmword) -> xmmword
function avx_pmaxuw_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    let va = a[(lo + 15)..lo];
    let vb = b[(lo + 15)..lo];
    r[(lo + 15)..lo] = if unsigned(va) > unsigned(vb) then va else vb;
  };
  r
}
val avx_pmaxuw_256 : (ymmword, ymmword) -> ymmword
function avx_pmaxuw_256(a, b) =
  avx_pmaxuw_128(a[255..128], b[255..128]) @ avx_pmaxuw_128(a[127..0], b[127..0])
val avx_pmaxuw_512 : (zmmword, zmmword) -> zmmword
function avx_pmaxuw_512(a, b) =
  avx_pmaxuw_256(a[511..256], b[511..256]) @ avx_pmaxuw_256(a[255..0], b[255..0])

// =========================================================================
// VPMAXUD: unsigned dword max
// =========================================================================

val avx_pmaxud_128 : (xmmword, xmmword) -> xmmword
function avx_pmaxud_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    let va = a[(lo + 31)..lo];
    let vb = b[(lo + 31)..lo];
    r[(lo + 31)..lo] = if unsigned(va) > unsigned(vb) then va else vb;
  };
  r
}
val avx_pmaxud_256 : (ymmword, ymmword) -> ymmword
function avx_pmaxud_256(a, b) =
  avx_pmaxud_128(a[255..128], b[255..128]) @ avx_pmaxud_128(a[127..0], b[127..0])
val avx_pmaxud_512 : (zmmword, zmmword) -> zmmword
function avx_pmaxud_512(a, b) =
  avx_pmaxud_256(a[511..256], b[511..256]) @ avx_pmaxud_256(a[255..0], b[255..0])

// =========================================================================
// VPMAXUQ: unsigned qword max
// =========================================================================

val avx_pmaxuq_128 : (xmmword, xmmword) -> xmmword
function avx_pmaxuq_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 1) {
    let lo : range(0, 64) = i * 64;
    let va = a[(lo + 63)..lo];
    let vb = b[(lo + 63)..lo];
    r[(lo + 63)..lo] = if unsigned(va) > unsigned(vb) then va else vb;
  };
  r
}
val avx_pmaxuq_256 : (ymmword, ymmword) -> ymmword
function avx_pmaxuq_256(a, b) =
  avx_pmaxuq_128(a[255..128], b[255..128]) @ avx_pmaxuq_128(a[127..0], b[127..0])
val avx_pmaxuq_512 : (zmmword, zmmword) -> zmmword
function avx_pmaxuq_512(a, b) =
  avx_pmaxuq_256(a[511..256], b[511..256]) @ avx_pmaxuq_256(a[255..0], b[255..0])

// =========================================================================
// VPACKUSDW: pack dwords to words with unsigned saturation
// Per 128-bit lane: 4 dwords from src1 -> 4 words, 4 dwords from src2 -> 4 words
// Each signed dword is clamped to [0, 65535] before truncation
// =========================================================================

val avx_packusdw_128 : (xmmword, xmmword) -> xmmword
function avx_packusdw_128(a, b) = {
  var r : xmmword = zeros();
  /* Process 4 dwords from a -> lower 4 words */
  foreach (i from 0 to 3) {
    let src_lo : range(0, 96) = i * 32;
    let dst_lo : range(0, 48) = i * 16;
    let sv = signed(a[(src_lo + 31)..src_lo]);
    let clamped = if sv < 0 then 0 else if sv > 65535 then 65535 else sv;
    r[(dst_lo + 15)..dst_lo] = to_bits(16, clamped);
  };
  /* Process 4 dwords from b -> upper 4 words */
  foreach (i from 0 to 3) {
    let src_lo : range(0, 96) = i * 32;
    let dst_lo : range(64, 112) = 64 + i * 16;
    let sv = signed(b[(src_lo + 31)..src_lo]);
    let clamped = if sv < 0 then 0 else if sv > 65535 then 65535 else sv;
    r[(dst_lo + 15)..dst_lo] = to_bits(16, clamped);
  };
  r
}
val avx_packusdw_256 : (ymmword, ymmword) -> ymmword
function avx_packusdw_256(a, b) =
  avx_packusdw_128(a[255..128], b[255..128]) @ avx_packusdw_128(a[127..0], b[127..0])
val avx_packusdw_512 : (zmmword, zmmword) -> zmmword
function avx_packusdw_512(a, b) =
  avx_packusdw_256(a[511..256], b[511..256]) @ avx_packusdw_256(a[255..0], b[255..0])

// =========================================================================
// VPERMI2/VPERMT2: 2-source permute using index vector
// vperm2_d: select dwords from combined (t1,t2) table using idx
// vperm2_q: select qwords from combined (t1,t2) table using idx
// =========================================================================

val avx_vperm2_d_128 : (xmmword, xmmword, xmmword) -> xmmword
function avx_vperm2_d_128(t1, t2, idx) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    let id : range(0, 7) = unsigned(idx[(lo + 2)..lo]);
    let sel : range(0, 96) = (id % 4) * 32;
    if id < 4 then r[(lo + 31)..lo] = t1[(sel + 31)..sel]
    else r[(lo + 31)..lo] = t2[(sel + 31)..sel];
  };
  r
}
val avx_vperm2_d_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_vperm2_d_256(t1, t2, idx) = {
  var r : ymmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 224) = i * 32;
    let id : range(0, 15) = unsigned(idx[(lo + 3)..lo]);
    let sel : range(0, 224) = (id % 8) * 32;
    if id < 8 then r[(lo + 31)..lo] = t1[(sel + 31)..sel]
    else r[(lo + 31)..lo] = t2[(sel + 31)..sel];
  };
  r
}
val avx_vperm2_d_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_vperm2_d_512(t1, t2, idx) = {
  var r : zmmword = zeros();
  foreach (i from 0 to 15) {
    let lo : range(0, 480) = i * 32;
    let id : range(0, 31) = unsigned(idx[(lo + 4)..lo]);
    let sel : range(0, 480) = (id % 16) * 32;
    if id < 16 then r[(lo + 31)..lo] = t1[(sel + 31)..sel]
    else r[(lo + 31)..lo] = t2[(sel + 31)..sel];
  };
  r
}

val avx_vperm2_q_128 : (xmmword, xmmword, xmmword) -> xmmword
function avx_vperm2_q_128(t1, t2, idx) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 1) {
    let lo : range(0, 64) = i * 64;
    let id : range(0, 3) = unsigned(idx[(lo + 1)..lo]);
    let sel : range(0, 64) = (id % 2) * 64;
    if id < 2 then r[(lo + 63)..lo] = t1[(sel + 63)..sel]
    else r[(lo + 63)..lo] = t2[(sel + 63)..sel];
  };
  r
}
val avx_vperm2_q_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_vperm2_q_256(t1, t2, idx) = {
  var r : ymmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 192) = i * 64;
    let id : range(0, 7) = unsigned(idx[(lo + 2)..lo]);
    let sel : range(0, 192) = (id % 4) * 64;
    if id < 4 then r[(lo + 63)..lo] = t1[(sel + 63)..sel]
    else r[(lo + 63)..lo] = t2[(sel + 63)..sel];
  };
  r
}
val avx_vperm2_q_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_vperm2_q_512(t1, t2, idx) = {
  var r : zmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 448) = i * 64;
    let id : range(0, 15) = unsigned(idx[(lo + 3)..lo]);
    let sel : range(0, 448) = (id % 8) * 64;
    if id < 8 then r[(lo + 63)..lo] = t1[(sel + 63)..sel]
    else r[(lo + 63)..lo] = t2[(sel + 63)..sel];
  };
  r
}

/* ---- Packed FMA helpers ---- */

val avx_fmadd_ps_128 : (xmmword, xmmword, xmmword) -> xmmword
function avx_fmadd_ps_128(a, b, c) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    r[(lo + 31)..lo] = __f32_fmadd(a[(lo + 31)..lo], b[(lo + 31)..lo], c[(lo + 31)..lo]);
  };
  r
}

val avx_fmadd_ps_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_fmadd_ps_256(a, b, c) = avx_fmadd_ps_128(a[255..128], b[255..128], c[255..128]) @ avx_fmadd_ps_128(a[127..0], b[127..0], c[127..0])

val avx_fmadd_ps_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_fmadd_ps_512(a, b, c) = avx_fmadd_ps_256(a[511..256], b[511..256], c[511..256]) @ avx_fmadd_ps_256(a[255..0], b[255..0], c[255..0])

val avx_fmadd_pd_128 : (xmmword, xmmword, xmmword) -> xmmword
function avx_fmadd_pd_128(a, b, c) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 1) {
    let lo : range(0, 64) = i * 64;
    r[(lo + 63)..lo] = __f64_fmadd(a[(lo + 63)..lo], b[(lo + 63)..lo], c[(lo + 63)..lo]);
  };
  r
}

val avx_fmadd_pd_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_fmadd_pd_256(a, b, c) = avx_fmadd_pd_128(a[255..128], b[255..128], c[255..128]) @ avx_fmadd_pd_128(a[127..0], b[127..0], c[127..0])

val avx_fmadd_pd_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_fmadd_pd_512(a, b, c) = avx_fmadd_pd_256(a[511..256], b[511..256], c[511..256]) @ avx_fmadd_pd_256(a[255..0], b[255..0], c[255..0])

val avx_fmsub_ps_128 : (xmmword, xmmword, xmmword) -> xmmword
function avx_fmsub_ps_128(a, b, c) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    r[(lo + 31)..lo] = __f32_fmsub(a[(lo + 31)..lo], b[(lo + 31)..lo], c[(lo + 31)..lo]);
  };
  r
}

val avx_fmsub_ps_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_fmsub_ps_256(a, b, c) = avx_fmsub_ps_128(a[255..128], b[255..128], c[255..128]) @ avx_fmsub_ps_128(a[127..0], b[127..0], c[127..0])

val avx_fmsub_ps_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_fmsub_ps_512(a, b, c) = avx_fmsub_ps_256(a[511..256], b[511..256], c[511..256]) @ avx_fmsub_ps_256(a[255..0], b[255..0], c[255..0])

val avx_fmsub_pd_128 : (xmmword, xmmword, xmmword) -> xmmword
function avx_fmsub_pd_128(a, b, c) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 1) {
    let lo : range(0, 64) = i * 64;
    r[(lo + 63)..lo] = __f64_fmsub(a[(lo + 63)..lo], b[(lo + 63)..lo], c[(lo + 63)..lo]);
  };
  r
}

val avx_fmsub_pd_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_fmsub_pd_256(a, b, c) = avx_fmsub_pd_128(a[255..128], b[255..128], c[255..128]) @ avx_fmsub_pd_128(a[127..0], b[127..0], c[127..0])

val avx_fmsub_pd_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_fmsub_pd_512(a, b, c) = avx_fmsub_pd_256(a[511..256], b[511..256], c[511..256]) @ avx_fmsub_pd_256(a[255..0], b[255..0], c[255..0])

val avx_fnmadd_ps_128 : (xmmword, xmmword, xmmword) -> xmmword
function avx_fnmadd_ps_128(a, b, c) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    r[(lo + 31)..lo] = __f32_fnmadd(a[(lo + 31)..lo], b[(lo + 31)..lo], c[(lo + 31)..lo]);
  };
  r
}

val avx_fnmadd_ps_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_fnmadd_ps_256(a, b, c) = avx_fnmadd_ps_128(a[255..128], b[255..128], c[255..128]) @ avx_fnmadd_ps_128(a[127..0], b[127..0], c[127..0])

val avx_fnmadd_ps_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_fnmadd_ps_512(a, b, c) = avx_fnmadd_ps_256(a[511..256], b[511..256], c[511..256]) @ avx_fnmadd_ps_256(a[255..0], b[255..0], c[255..0])

val avx_fnmadd_pd_128 : (xmmword, xmmword, xmmword) -> xmmword
function avx_fnmadd_pd_128(a, b, c) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 1) {
    let lo : range(0, 64) = i * 64;
    r[(lo + 63)..lo] = __f64_fnmadd(a[(lo + 63)..lo], b[(lo + 63)..lo], c[(lo + 63)..lo]);
  };
  r
}

val avx_fnmadd_pd_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_fnmadd_pd_256(a, b, c) = avx_fnmadd_pd_128(a[255..128], b[255..128], c[255..128]) @ avx_fnmadd_pd_128(a[127..0], b[127..0], c[127..0])

val avx_fnmadd_pd_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_fnmadd_pd_512(a, b, c) = avx_fnmadd_pd_256(a[511..256], b[511..256], c[511..256]) @ avx_fnmadd_pd_256(a[255..0], b[255..0], c[255..0])

val avx_fnmsub_ps_128 : (xmmword, xmmword, xmmword) -> xmmword
function avx_fnmsub_ps_128(a, b, c) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    r[(lo + 31)..lo] = __f32_fnmsub(a[(lo + 31)..lo], b[(lo + 31)..lo], c[(lo + 31)..lo]);
  };
  r
}

val avx_fnmsub_ps_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_fnmsub_ps_256(a, b, c) = avx_fnmsub_ps_128(a[255..128], b[255..128], c[255..128]) @ avx_fnmsub_ps_128(a[127..0], b[127..0], c[127..0])

val avx_fnmsub_ps_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_fnmsub_ps_512(a, b, c) = avx_fnmsub_ps_256(a[511..256], b[511..256], c[511..256]) @ avx_fnmsub_ps_256(a[255..0], b[255..0], c[255..0])

val avx_fnmsub_pd_128 : (xmmword, xmmword, xmmword) -> xmmword
function avx_fnmsub_pd_128(a, b, c) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 1) {
    let lo : range(0, 64) = i * 64;
    r[(lo + 63)..lo] = __f64_fnmsub(a[(lo + 63)..lo], b[(lo + 63)..lo], c[(lo + 63)..lo]);
  };
  r
}

val avx_fnmsub_pd_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_fnmsub_pd_256(a, b, c) = avx_fnmsub_pd_128(a[255..128], b[255..128], c[255..128]) @ avx_fnmsub_pd_128(a[127..0], b[127..0], c[127..0])

val avx_fnmsub_pd_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_fnmsub_pd_512(a, b, c) = avx_fnmsub_pd_256(a[511..256], b[511..256], c[511..256]) @ avx_fnmsub_pd_256(a[255..0], b[255..0], c[255..0])

val avx_fmaddsub_ps_128 : (xmmword, xmmword, xmmword) -> xmmword
function avx_fmaddsub_ps_128(a, b, c) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    if i % 2 == 0
    then r[(lo + 31)..lo] = __f32_fmsub(a[(lo + 31)..lo], b[(lo + 31)..lo], c[(lo + 31)..lo])
    else r[(lo + 31)..lo] = __f32_fmadd(a[(lo + 31)..lo], b[(lo + 31)..lo], c[(lo + 31)..lo]);
  };
  r
}

val avx_fmaddsub_ps_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_fmaddsub_ps_256(a, b, c) = avx_fmaddsub_ps_128(a[255..128], b[255..128], c[255..128]) @ avx_fmaddsub_ps_128(a[127..0], b[127..0], c[127..0])

val avx_fmaddsub_ps_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_fmaddsub_ps_512(a, b, c) = avx_fmaddsub_ps_256(a[511..256], b[511..256], c[511..256]) @ avx_fmaddsub_ps_256(a[255..0], b[255..0], c[255..0])

val avx_fmaddsub_pd_128 : (xmmword, xmmword, xmmword) -> xmmword
function avx_fmaddsub_pd_128(a, b, c) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 1) {
    let lo : range(0, 64) = i * 64;
    if i % 2 == 0
    then r[(lo + 63)..lo] = __f64_fmsub(a[(lo + 63)..lo], b[(lo + 63)..lo], c[(lo + 63)..lo])
    else r[(lo + 63)..lo] = __f64_fmadd(a[(lo + 63)..lo], b[(lo + 63)..lo], c[(lo + 63)..lo]);
  };
  r
}

val avx_fmaddsub_pd_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_fmaddsub_pd_256(a, b, c) = avx_fmaddsub_pd_128(a[255..128], b[255..128], c[255..128]) @ avx_fmaddsub_pd_128(a[127..0], b[127..0], c[127..0])

val avx_fmaddsub_pd_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_fmaddsub_pd_512(a, b, c) = avx_fmaddsub_pd_256(a[511..256], b[511..256], c[511..256]) @ avx_fmaddsub_pd_256(a[255..0], b[255..0], c[255..0])

val avx_fmsubadd_ps_128 : (xmmword, xmmword, xmmword) -> xmmword
function avx_fmsubadd_ps_128(a, b, c) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    if i % 2 == 0
    then r[(lo + 31)..lo] = __f32_fmadd(a[(lo + 31)..lo], b[(lo + 31)..lo], c[(lo + 31)..lo])
    else r[(lo + 31)..lo] = __f32_fmsub(a[(lo + 31)..lo], b[(lo + 31)..lo], c[(lo + 31)..lo]);
  };
  r
}

val avx_fmsubadd_ps_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_fmsubadd_ps_256(a, b, c) = avx_fmsubadd_ps_128(a[255..128], b[255..128], c[255..128]) @ avx_fmsubadd_ps_128(a[127..0], b[127..0], c[127..0])

val avx_fmsubadd_ps_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_fmsubadd_ps_512(a, b, c) = avx_fmsubadd_ps_256(a[511..256], b[511..256], c[511..256]) @ avx_fmsubadd_ps_256(a[255..0], b[255..0], c[255..0])

val avx_fmsubadd_pd_128 : (xmmword, xmmword, xmmword) -> xmmword
function avx_fmsubadd_pd_128(a, b, c) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 1) {
    let lo : range(0, 64) = i * 64;
    if i % 2 == 0
    then r[(lo + 63)..lo] = __f64_fmadd(a[(lo + 63)..lo], b[(lo + 63)..lo], c[(lo + 63)..lo])
    else r[(lo + 63)..lo] = __f64_fmsub(a[(lo + 63)..lo], b[(lo + 63)..lo], c[(lo + 63)..lo]);
  };
  r
}

val avx_fmsubadd_pd_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_fmsubadd_pd_256(a, b, c) = avx_fmsubadd_pd_128(a[255..128], b[255..128], c[255..128]) @ avx_fmsubadd_pd_128(a[127..0], b[127..0], c[127..0])

val avx_fmsubadd_pd_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_fmsubadd_pd_512(a, b, c) = avx_fmsubadd_pd_256(a[511..256], b[511..256], c[511..256]) @ avx_fmsubadd_pd_256(a[255..0], b[255..0], c[255..0])

/* ---- 2-source word permute (VPERMI2W/VPERMT2W) ---- */

val avx_vperm2_w_128 : (xmmword, xmmword, xmmword) -> xmmword
function avx_vperm2_w_128(t1, t2, idx) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    let id : range(0, 15) = unsigned(idx[(lo + 3)..lo]);
    let sel : range(0, 112) = (id % 8) * 16;
    if id < 8 then r[(lo + 15)..lo] = t1[(sel + 15)..sel]
    else r[(lo + 15)..lo] = t2[(sel + 15)..sel];
  };
  r
}
val avx_vperm2_w_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_vperm2_w_256(t1, t2, idx) = {
  var r : ymmword = zeros();
  foreach (i from 0 to 15) {
    let lo : range(0, 240) = i * 16;
    let id : range(0, 31) = unsigned(idx[(lo + 4)..lo]);
    let sel : range(0, 240) = (id % 16) * 16;
    if id < 16 then r[(lo + 15)..lo] = t1[(sel + 15)..sel]
    else r[(lo + 15)..lo] = t2[(sel + 15)..sel];
  };
  r
}
val avx_vperm2_w_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_vperm2_w_512(t1, t2, idx) = {
  var r : zmmword = zeros();
  foreach (i from 0 to 31) {
    let lo : range(0, 496) = i * 16;
    let id : range(0, 63) = unsigned(idx[(lo + 5)..lo]);
    let sel : range(0, 496) = (id % 32) * 16;
    if id < 32 then r[(lo + 15)..lo] = t1[(sel + 15)..sel]
    else r[(lo + 15)..lo] = t2[(sel + 15)..sel];
  };
  r
}

/* ---- VPERMW: single-source word permute ---- */

val avx_vpermw_128 : (xmmword, xmmword) -> xmmword
function avx_vpermw_128(src, idx) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    let id : range(0, 7) = unsigned(idx[(lo + 2)..lo]);
    let sel : range(0, 112) = id * 16;
    r[(lo + 15)..lo] = src[(sel + 15)..sel];
  };
  r
}
val avx_vpermw_256 : (ymmword, ymmword) -> ymmword
function avx_vpermw_256(src, idx) = {
  var r : ymmword = zeros();
  foreach (i from 0 to 15) {
    let lo : range(0, 240) = i * 16;
    let id : range(0, 15) = unsigned(idx[(lo + 3)..lo]);
    let sel : range(0, 240) = id * 16;
    r[(lo + 15)..lo] = src[(sel + 15)..sel];
  };
  r
}
val avx_vpermw_512 : (zmmword, zmmword) -> zmmword
function avx_vpermw_512(src, idx) = {
  var r : zmmword = zeros();
  foreach (i from 0 to 31) {
    let lo : range(0, 496) = i * 16;
    let id : range(0, 31) = unsigned(idx[(lo + 4)..lo]);
    let sel : range(0, 496) = id * 16;
    r[(lo + 15)..lo] = src[(sel + 15)..sel];
  };
  r
}

/* ---- 2-source byte permute (VPERMI2B/VPERMT2B) ---- */

val avx_vperm2_b_128 : (xmmword, xmmword, xmmword) -> xmmword
function avx_vperm2_b_128(t1, t2, idx) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 15) {
    let lo : range(0, 120) = i * 8;
    let id : range(0, 31) = unsigned(idx[(lo + 4)..lo]);
    let sel : range(0, 120) = (id % 16) * 8;
    if id < 16 then r[(lo + 7)..lo] = t1[(sel + 7)..sel]
    else r[(lo + 7)..lo] = t2[(sel + 7)..sel];
  };
  r
}
val avx_vperm2_b_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_vperm2_b_256(t1, t2, idx) = {
  var r : ymmword = zeros();
  foreach (i from 0 to 31) {
    let lo : range(0, 248) = i * 8;
    let id : range(0, 63) = unsigned(idx[(lo + 5)..lo]);
    let sel : range(0, 248) = (id % 32) * 8;
    if id < 32 then r[(lo + 7)..lo] = t1[(sel + 7)..sel]
    else r[(lo + 7)..lo] = t2[(sel + 7)..sel];
  };
  r
}
val avx_vperm2_b_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_vperm2_b_512(t1, t2, idx) = {
  var r : zmmword = zeros();
  foreach (i from 0 to 63) {
    let lo : range(0, 504) = i * 8;
    let id : range(0, 127) = unsigned(idx[(lo + 6)..lo]);
    let sel : range(0, 504) = (id % 64) * 8;
    if id < 64 then r[(lo + 7)..lo] = t1[(sel + 7)..sel]
    else r[(lo + 7)..lo] = t2[(sel + 7)..sel];
  };
  r
}

/* ---- VPERMB: single-source byte permute ---- */

val avx_vpermb_128 : (xmmword, xmmword) -> xmmword
function avx_vpermb_128(src, idx) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 15) {
    let lo : range(0, 120) = i * 8;
    let id : range(0, 15) = unsigned(idx[(lo + 3)..lo]);
    let sel : range(0, 120) = id * 8;
    r[(lo + 7)..lo] = src[(sel + 7)..sel];
  };
  r
}
val avx_vpermb_256 : (ymmword, ymmword) -> ymmword
function avx_vpermb_256(src, idx) = {
  var r : ymmword = zeros();
  foreach (i from 0 to 31) {
    let lo : range(0, 248) = i * 8;
    let id : range(0, 31) = unsigned(idx[(lo + 4)..lo]);
    let sel : range(0, 248) = id * 8;
    r[(lo + 7)..lo] = src[(sel + 7)..sel];
  };
  r
}
val avx_vpermb_512 : (zmmword, zmmword) -> zmmword
function avx_vpermb_512(src, idx) = {
  var r : zmmword = zeros();
  foreach (i from 0 to 63) {
    let lo : range(0, 504) = i * 8;
    let id : range(0, 63) = unsigned(idx[(lo + 5)..lo]);
    let sel : range(0, 504) = id * 8;
    r[(lo + 7)..lo] = src[(sel + 7)..sel];
  };
  r
}

/* ---- VPERMQ/VPERMPD (imm8): qword permute per 256-bit lane ---- */

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
    then { let s : range(0, 96) = src_idx * 32; r[(dst_lo + 31)..dst_lo] = src2[(s + 31)..s] }
    else { let s : range(0, 96) = (src_idx - 4) * 32; r[(dst_lo + 31)..dst_lo] = src1[(s + 31)..s] };
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
    then { let s : range(0, 224) = src_idx * 32; r[(dst_lo + 31)..dst_lo] = src2[(s + 31)..s] }
    else { let s : range(0, 224) = (src_idx - 8) * 32; r[(dst_lo + 31)..dst_lo] = src1[(s + 31)..s] };
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
    then { let s : range(0, 480) = src_idx * 32; r[(dst_lo + 31)..dst_lo] = src2[(s + 31)..s] }
    else { let s : range(0, 480) = (src_idx - 16) * 32; r[(dst_lo + 31)..dst_lo] = src1[(s + 31)..s] };
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
    then { let s : range(0, 64) = src_idx * 64; r[(dst_lo + 63)..dst_lo] = src2[(s + 63)..s] }
    else { let s : range(0, 64) = (src_idx - 2) * 64; r[(dst_lo + 63)..dst_lo] = src1[(s + 63)..s] };
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
    then { let s : range(0, 192) = src_idx * 64; r[(dst_lo + 63)..dst_lo] = src2[(s + 63)..s] }
    else { let s : range(0, 192) = (src_idx - 4) * 64; r[(dst_lo + 63)..dst_lo] = src1[(s + 63)..s] };
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
    then { let s : range(0, 448) = src_idx * 64; r[(dst_lo + 63)..dst_lo] = src2[(s + 63)..s] }
    else { let s : range(0, 448) = (src_idx - 8) * 64; r[(dst_lo + 63)..dst_lo] = src1[(s + 63)..s] };
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

val avx_palignr_128 : (xmmword, xmmword, byte) -> xmmword
function avx_palignr_128(src1, src2, imm) = {
  let shift : range(0, 255) = unsigned(imm);
  if shift >= 32 then zeros()
  else if shift >= 16 then {
    // Only src2 contributes, shifted right by (shift-16) bytes
    let s : range(0, 15) = shift - 16;
    let sbit : range(0, 120) = s * 8;
    var r : xmmword = zeros();
    foreach (i from 0 to 15) {
      let src_byte : range(0, 31) = i + s;
      let dst_lo : range(0, 120) = i * 8;
      if src_byte < 16
      then { let sl : range(0, 120) = src_byte * 8; r[(dst_lo + 7)..dst_lo] = src2[(sl + 7)..sl] }
      else r[(dst_lo + 7)..dst_lo] = 0x00;
    };
    r
  } else {
    // Concatenate src2:src1 = 256 bits, shift right by 'shift' bytes, take low 128
    let s : range(0, 15) = shift;
    var r : xmmword = zeros();
    foreach (i from 0 to 15) {
      let src_byte : range(0, 31) = i + s;
      let dst_lo : range(0, 120) = i * 8;
      if src_byte < 16
      then { let sl : range(0, 120) = src_byte * 8; r[(dst_lo + 7)..dst_lo] = src2[(sl + 7)..sl] }
      else { let sl : range(0, 120) = (src_byte - 16) * 8; r[(dst_lo + 7)..dst_lo] = src1[(sl + 7)..sl] };
    };
    r
  }
}

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

val avx_pmovwb_128 : xmmword -> qword
function avx_pmovwb_128(src) = {
  var r : qword = zeros();
  foreach (i from 0 to 7) {
    let slo : range(0, 112) = i * 16;
    let dlo : range(0, 56) = i * 8;
    r[(dlo + 7)..dlo] = src[(slo + 7)..slo];
  };
  r
}
val avx_pmovwb_256 : ymmword -> xmmword
function avx_pmovwb_256(src) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 15) {
    let slo : range(0, 240) = i * 16;
    let dlo : range(0, 120) = i * 8;
    r[(dlo + 7)..dlo] = src[(slo + 7)..slo];
  };
  r
}
val avx_pmovwb_512 : zmmword -> ymmword
function avx_pmovwb_512(src) = {
  var r : ymmword = zeros();
  foreach (i from 0 to 31) {
    let slo : range(0, 496) = i * 16;
    let dlo : range(0, 248) = i * 8;
    r[(dlo + 7)..dlo] = src[(slo + 7)..slo];
  };
  r
}

// --- VPMOVDB: truncate dword -> byte ---

val avx_pmovdb_128 : xmmword -> dword
function avx_pmovdb_128(src) = {
  var r : dword = zeros();
  foreach (i from 0 to 3) {
    let slo : range(0, 96) = i * 32;
    let dlo : range(0, 24) = i * 8;
    r[(dlo + 7)..dlo] = src[(slo + 7)..slo];
  };
  r
}
val avx_pmovdb_256 : ymmword -> qword
function avx_pmovdb_256(src) = {
  var r : qword = zeros();
  foreach (i from 0 to 7) {
    let slo : range(0, 224) = i * 32;
    let dlo : range(0, 56) = i * 8;
    r[(dlo + 7)..dlo] = src[(slo + 7)..slo];
  };
  r
}
val avx_pmovdb_512 : zmmword -> xmmword
function avx_pmovdb_512(src) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 15) {
    let slo : range(0, 480) = i * 32;
    let dlo : range(0, 120) = i * 8;
    r[(dlo + 7)..dlo] = src[(slo + 7)..slo];
  };
  r
}

// --- VPMOVQB: truncate qword -> byte ---

val avx_pmovqb_128 : xmmword -> word
function avx_pmovqb_128(src) = {
  var r : word = zeros();
  foreach (i from 0 to 1) {
    let slo : range(0, 64) = i * 64;
    let dlo : range(0, 8) = i * 8;
    r[(dlo + 7)..dlo] = src[(slo + 7)..slo];
  };
  r
}
val avx_pmovqb_256 : ymmword -> dword
function avx_pmovqb_256(src) = {
  var r : dword = zeros();
  foreach (i from 0 to 3) {
    let slo : range(0, 192) = i * 64;
    let dlo : range(0, 24) = i * 8;
    r[(dlo + 7)..dlo] = src[(slo + 7)..slo];
  };
  r
}
val avx_pmovqb_512 : zmmword -> qword
function avx_pmovqb_512(src) = {
  var r : qword = zeros();
  foreach (i from 0 to 7) {
    let slo : range(0, 448) = i * 64;
    let dlo : range(0, 56) = i * 8;
    r[(dlo + 7)..dlo] = src[(slo + 7)..slo];
  };
  r
}

// --- VPMOVDW: truncate dword -> word ---

val avx_pmovdw_128 : xmmword -> qword
function avx_pmovdw_128(src) = {
  var r : qword = zeros();
  foreach (i from 0 to 3) {
    let slo : range(0, 96) = i * 32;
    let dlo : range(0, 48) = i * 16;
    r[(dlo + 15)..dlo] = src[(slo + 15)..slo];
  };
  r
}
val avx_pmovdw_256 : ymmword -> xmmword
function avx_pmovdw_256(src) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let slo : range(0, 224) = i * 32;
    let dlo : range(0, 112) = i * 16;
    r[(dlo + 15)..dlo] = src[(slo + 15)..slo];
  };
  r
}
val avx_pmovdw_512 : zmmword -> ymmword
function avx_pmovdw_512(src) = {
  var r : ymmword = zeros();
  foreach (i from 0 to 15) {
    let slo : range(0, 480) = i * 32;
    let dlo : range(0, 240) = i * 16;
    r[(dlo + 15)..dlo] = src[(slo + 15)..slo];
  };
  r
}

// --- VPMOVQW: truncate qword -> word ---

val avx_pmovqw_128 : xmmword -> dword
function avx_pmovqw_128(src) = {
  var r : dword = zeros();
  foreach (i from 0 to 1) {
    let slo : range(0, 64) = i * 64;
    let dlo : range(0, 16) = i * 16;
    r[(dlo + 15)..dlo] = src[(slo + 15)..slo];
  };
  r
}
val avx_pmovqw_256 : ymmword -> qword
function avx_pmovqw_256(src) = {
  var r : qword = zeros();
  foreach (i from 0 to 3) {
    let slo : range(0, 192) = i * 64;
    let dlo : range(0, 48) = i * 16;
    r[(dlo + 15)..dlo] = src[(slo + 15)..slo];
  };
  r
}
val avx_pmovqw_512 : zmmword -> xmmword
function avx_pmovqw_512(src) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let slo : range(0, 448) = i * 64;
    let dlo : range(0, 112) = i * 16;
    r[(dlo + 15)..dlo] = src[(slo + 15)..slo];
  };
  r
}

// --- VPMOVQD: truncate qword -> dword ---

val avx_pmovqd_128 : xmmword -> qword
function avx_pmovqd_128(src) = {
  var r : qword = zeros();
  foreach (i from 0 to 1) {
    let slo : range(0, 64) = i * 64;
    let dlo : range(0, 32) = i * 32;
    r[(dlo + 31)..dlo] = src[(slo + 31)..slo];
  };
  r
}
val avx_pmovqd_256 : ymmword -> xmmword
function avx_pmovqd_256(src) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let slo : range(0, 192) = i * 64;
    let dlo : range(0, 96) = i * 32;
    r[(dlo + 31)..dlo] = src[(slo + 31)..slo];
  };
  r
}
val avx_pmovqd_512 : zmmword -> ymmword
function avx_pmovqd_512(src) = {
  var r : ymmword = zeros();
  foreach (i from 0 to 7) {
    let slo : range(0, 448) = i * 64;
    let dlo : range(0, 224) = i * 32;
    r[(dlo + 31)..dlo] = src[(slo + 31)..slo];
  };
  r
}

// --- VPMOVUSWB: unsigned-saturate word -> byte ---

val avx_pmovuswb_128 : xmmword -> qword
function avx_pmovuswb_128(src) = {
  var r : qword = zeros();
  foreach (i from 0 to 7) {
    let slo : range(0, 112) = i * 16;
    let dlo : range(0, 56) = i * 8;
    let v : int = unsigned(src[(slo + 15)..slo]);
    r[(dlo + 7)..dlo] = if v > 255 then 0xFF else src[(slo + 7)..slo];
  };
  r
}
val avx_pmovuswb_256 : ymmword -> xmmword
function avx_pmovuswb_256(src) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 15) {
    let slo : range(0, 240) = i * 16;
    let dlo : range(0, 120) = i * 8;
    let v : int = unsigned(src[(slo + 15)..slo]);
    r[(dlo + 7)..dlo] = if v > 255 then 0xFF else src[(slo + 7)..slo];
  };
  r
}
val avx_pmovuswb_512 : zmmword -> ymmword
function avx_pmovuswb_512(src) = {
  var r : ymmword = zeros();
  foreach (i from 0 to 31) {
    let slo : range(0, 496) = i * 16;
    let dlo : range(0, 248) = i * 8;
    let v : int = unsigned(src[(slo + 15)..slo]);
    r[(dlo + 7)..dlo] = if v > 255 then 0xFF else src[(slo + 7)..slo];
  };
  r
}

// --- VPMOVUSDB: unsigned-saturate dword -> byte ---

val avx_pmovusdb_128 : xmmword -> dword
function avx_pmovusdb_128(src) = {
  var r : dword = zeros();
  foreach (i from 0 to 3) {
    let slo : range(0, 96) = i * 32;
    let dlo : range(0, 24) = i * 8;
    let v : int = unsigned(src[(slo + 31)..slo]);
    r[(dlo + 7)..dlo] = if v > 255 then 0xFF else src[(slo + 7)..slo];
  };
  r
}
val avx_pmovusdb_256 : ymmword -> qword
function avx_pmovusdb_256(src) = {
  var r : qword = zeros();
  foreach (i from 0 to 7) {
    let slo : range(0, 224) = i * 32;
    let dlo : range(0, 56) = i * 8;
    let v : int = unsigned(src[(slo + 31)..slo]);
    r[(dlo + 7)..dlo] = if v > 255 then 0xFF else src[(slo + 7)..slo];
  };
  r
}
val avx_pmovusdb_512 : zmmword -> xmmword
function avx_pmovusdb_512(src) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 15) {
    let slo : range(0, 480) = i * 32;
    let dlo : range(0, 120) = i * 8;
    let v : int = unsigned(src[(slo + 31)..slo]);
    r[(dlo + 7)..dlo] = if v > 255 then 0xFF else src[(slo + 7)..slo];
  };
  r
}

// --- VPMOVUSQB: unsigned-saturate qword -> byte ---

val avx_pmovusqb_128 : xmmword -> word
function avx_pmovusqb_128(src) = {
  var r : word = zeros();
  foreach (i from 0 to 1) {
    let slo : range(0, 64) = i * 64;
    let dlo : range(0, 8) = i * 8;
    let v : int = unsigned(src[(slo + 63)..slo]);
    r[(dlo + 7)..dlo] = if v > 255 then 0xFF else src[(slo + 7)..slo];
  };
  r
}
val avx_pmovusqb_256 : ymmword -> dword
function avx_pmovusqb_256(src) = {
  var r : dword = zeros();
  foreach (i from 0 to 3) {
    let slo : range(0, 192) = i * 64;
    let dlo : range(0, 24) = i * 8;
    let v : int = unsigned(src[(slo + 63)..slo]);
    r[(dlo + 7)..dlo] = if v > 255 then 0xFF else src[(slo + 7)..slo];
  };
  r
}
val avx_pmovusqb_512 : zmmword -> qword
function avx_pmovusqb_512(src) = {
  var r : qword = zeros();
  foreach (i from 0 to 7) {
    let slo : range(0, 448) = i * 64;
    let dlo : range(0, 56) = i * 8;
    let v : int = unsigned(src[(slo + 63)..slo]);
    r[(dlo + 7)..dlo] = if v > 255 then 0xFF else src[(slo + 7)..slo];
  };
  r
}

// --- VPMOVUSDW: unsigned-saturate dword -> word ---

val avx_pmovusdw_128 : xmmword -> qword
function avx_pmovusdw_128(src) = {
  var r : qword = zeros();
  foreach (i from 0 to 3) {
    let slo : range(0, 96) = i * 32;
    let dlo : range(0, 48) = i * 16;
    let v : int = unsigned(src[(slo + 31)..slo]);
    r[(dlo + 15)..dlo] = if v > 65535 then 0xFFFF else src[(slo + 15)..slo];
  };
  r
}
val avx_pmovusdw_256 : ymmword -> xmmword
function avx_pmovusdw_256(src) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let slo : range(0, 224) = i * 32;
    let dlo : range(0, 112) = i * 16;
    let v : int = unsigned(src[(slo + 31)..slo]);
    r[(dlo + 15)..dlo] = if v > 65535 then 0xFFFF else src[(slo + 15)..slo];
  };
  r
}
val avx_pmovusdw_512 : zmmword -> ymmword
function avx_pmovusdw_512(src) = {
  var r : ymmword = zeros();
  foreach (i from 0 to 15) {
    let slo : range(0, 480) = i * 32;
    let dlo : range(0, 240) = i * 16;
    let v : int = unsigned(src[(slo + 31)..slo]);
    r[(dlo + 15)..dlo] = if v > 65535 then 0xFFFF else src[(slo + 15)..slo];
  };
  r
}

// --- VPMOVUSQW: unsigned-saturate qword -> word ---

val avx_pmovusqw_128 : xmmword -> dword
function avx_pmovusqw_128(src) = {
  var r : dword = zeros();
  foreach (i from 0 to 1) {
    let slo : range(0, 64) = i * 64;
    let dlo : range(0, 16) = i * 16;
    let v : int = unsigned(src[(slo + 63)..slo]);
    r[(dlo + 15)..dlo] = if v > 65535 then 0xFFFF else src[(slo + 15)..slo];
  };
  r
}
val avx_pmovusqw_256 : ymmword -> qword
function avx_pmovusqw_256(src) = {
  var r : qword = zeros();
  foreach (i from 0 to 3) {
    let slo : range(0, 192) = i * 64;
    let dlo : range(0, 48) = i * 16;
    let v : int = unsigned(src[(slo + 63)..slo]);
    r[(dlo + 15)..dlo] = if v > 65535 then 0xFFFF else src[(slo + 15)..slo];
  };
  r
}
val avx_pmovusqw_512 : zmmword -> xmmword
function avx_pmovusqw_512(src) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let slo : range(0, 448) = i * 64;
    let dlo : range(0, 112) = i * 16;
    let v : int = unsigned(src[(slo + 63)..slo]);
    r[(dlo + 15)..dlo] = if v > 65535 then 0xFFFF else src[(slo + 15)..slo];
  };
  r
}

// --- VPMOVUSQD: unsigned-saturate qword -> dword ---

val avx_pmovusqd_128 : xmmword -> qword
function avx_pmovusqd_128(src) = {
  var r : qword = zeros();
  foreach (i from 0 to 1) {
    let slo : range(0, 64) = i * 64;
    let dlo : range(0, 32) = i * 32;
    let v : int = unsigned(src[(slo + 63)..slo]);
    r[(dlo + 31)..dlo] = if v > 4294967295 then 0xFFFFFFFF else src[(slo + 31)..slo];
  };
  r
}
val avx_pmovusqd_256 : ymmword -> xmmword
function avx_pmovusqd_256(src) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let slo : range(0, 192) = i * 64;
    let dlo : range(0, 96) = i * 32;
    let v : int = unsigned(src[(slo + 63)..slo]);
    r[(dlo + 31)..dlo] = if v > 4294967295 then 0xFFFFFFFF else src[(slo + 31)..slo];
  };
  r
}
val avx_pmovusqd_512 : zmmword -> ymmword
function avx_pmovusqd_512(src) = {
  var r : ymmword = zeros();
  foreach (i from 0 to 7) {
    let slo : range(0, 448) = i * 64;
    let dlo : range(0, 224) = i * 32;
    let v : int = unsigned(src[(slo + 63)..slo]);
    r[(dlo + 31)..dlo] = if v > 4294967295 then 0xFFFFFFFF else src[(slo + 31)..slo];
  };
  r
}

// --- VPMOVSWB: signed-saturate word -> byte ---

val avx_pmovswb_128 : xmmword -> qword
function avx_pmovswb_128(src) = {
  var r : qword = zeros();
  foreach (i from 0 to 7) {
    let slo : range(0, 112) = i * 16;
    let dlo : range(0, 56) = i * 8;
    let v : int = signed(src[(slo + 15)..slo]);
    r[(dlo + 7)..dlo] = if v > 127 then 0x7F
                         else if v < negate(128) then 0x80
                         else get_slice_int(8, v, 0);
  };
  r
}
val avx_pmovswb_256 : ymmword -> xmmword
function avx_pmovswb_256(src) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 15) {
    let slo : range(0, 240) = i * 16;
    let dlo : range(0, 120) = i * 8;
    let v : int = signed(src[(slo + 15)..slo]);
    r[(dlo + 7)..dlo] = if v > 127 then 0x7F
                         else if v < negate(128) then 0x80
                         else get_slice_int(8, v, 0);
  };
  r
}
val avx_pmovswb_512 : zmmword -> ymmword
function avx_pmovswb_512(src) = {
  var r : ymmword = zeros();
  foreach (i from 0 to 31) {
    let slo : range(0, 496) = i * 16;
    let dlo : range(0, 248) = i * 8;
    let v : int = signed(src[(slo + 15)..slo]);
    r[(dlo + 7)..dlo] = if v > 127 then 0x7F
                         else if v < negate(128) then 0x80
                         else get_slice_int(8, v, 0);
  };
  r
}

// --- VPMOVSDB: signed-saturate dword -> byte ---

val avx_pmovsdb_128 : xmmword -> dword
function avx_pmovsdb_128(src) = {
  var r : dword = zeros();
  foreach (i from 0 to 3) {
    let slo : range(0, 96) = i * 32;
    let dlo : range(0, 24) = i * 8;
    let v : int = signed(src[(slo + 31)..slo]);
    r[(dlo + 7)..dlo] = if v > 127 then 0x7F
                         else if v < negate(128) then 0x80
                         else get_slice_int(8, v, 0);
  };
  r
}
val avx_pmovsdb_256 : ymmword -> qword
function avx_pmovsdb_256(src) = {
  var r : qword = zeros();
  foreach (i from 0 to 7) {
    let slo : range(0, 224) = i * 32;
    let dlo : range(0, 56) = i * 8;
    let v : int = signed(src[(slo + 31)..slo]);
    r[(dlo + 7)..dlo] = if v > 127 then 0x7F
                         else if v < negate(128) then 0x80
                         else get_slice_int(8, v, 0);
  };
  r
}
val avx_pmovsdb_512 : zmmword -> xmmword
function avx_pmovsdb_512(src) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 15) {
    let slo : range(0, 480) = i * 32;
    let dlo : range(0, 120) = i * 8;
    let v : int = signed(src[(slo + 31)..slo]);
    r[(dlo + 7)..dlo] = if v > 127 then 0x7F
                         else if v < negate(128) then 0x80
                         else get_slice_int(8, v, 0);
  };
  r
}

// --- VPMOVSQB: signed-saturate qword -> byte ---

val avx_pmovsqb_128 : xmmword -> word
function avx_pmovsqb_128(src) = {
  var r : word = zeros();
  foreach (i from 0 to 1) {
    let slo : range(0, 64) = i * 64;
    let dlo : range(0, 8) = i * 8;
    let v : int = signed(src[(slo + 63)..slo]);
    r[(dlo + 7)..dlo] = if v > 127 then 0x7F
                         else if v < negate(128) then 0x80
                         else get_slice_int(8, v, 0);
  };
  r
}
val avx_pmovsqb_256 : ymmword -> dword
function avx_pmovsqb_256(src) = {
  var r : dword = zeros();
  foreach (i from 0 to 3) {
    let slo : range(0, 192) = i * 64;
    let dlo : range(0, 24) = i * 8;
    let v : int = signed(src[(slo + 63)..slo]);
    r[(dlo + 7)..dlo] = if v > 127 then 0x7F
                         else if v < negate(128) then 0x80
                         else get_slice_int(8, v, 0);
  };
  r
}
val avx_pmovsqb_512 : zmmword -> qword
function avx_pmovsqb_512(src) = {
  var r : qword = zeros();
  foreach (i from 0 to 7) {
    let slo : range(0, 448) = i * 64;
    let dlo : range(0, 56) = i * 8;
    let v : int = signed(src[(slo + 63)..slo]);
    r[(dlo + 7)..dlo] = if v > 127 then 0x7F
                         else if v < negate(128) then 0x80
                         else get_slice_int(8, v, 0);
  };
  r
}

// --- VPMOVSDW: signed-saturate dword -> word ---

val avx_pmovsdw_128 : xmmword -> qword
function avx_pmovsdw_128(src) = {
  var r : qword = zeros();
  foreach (i from 0 to 3) {
    let slo : range(0, 96) = i * 32;
    let dlo : range(0, 48) = i * 16;
    let v : int = signed(src[(slo + 31)..slo]);
    r[(dlo + 15)..dlo] = if v > 32767 then 0x7FFF
                          else if v < negate(32768) then 0x8000
                          else get_slice_int(16, v, 0);
  };
  r
}
val avx_pmovsdw_256 : ymmword -> xmmword
function avx_pmovsdw_256(src) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let slo : range(0, 224) = i * 32;
    let dlo : range(0, 112) = i * 16;
    let v : int = signed(src[(slo + 31)..slo]);
    r[(dlo + 15)..dlo] = if v > 32767 then 0x7FFF
                          else if v < negate(32768) then 0x8000
                          else get_slice_int(16, v, 0);
  };
  r
}
val avx_pmovsdw_512 : zmmword -> ymmword
function avx_pmovsdw_512(src) = {
  var r : ymmword = zeros();
  foreach (i from 0 to 15) {
    let slo : range(0, 480) = i * 32;
    let dlo : range(0, 240) = i * 16;
    let v : int = signed(src[(slo + 31)..slo]);
    r[(dlo + 15)..dlo] = if v > 32767 then 0x7FFF
                          else if v < negate(32768) then 0x8000
                          else get_slice_int(16, v, 0);
  };
  r
}

// --- VPMOVSQW: signed-saturate qword -> word ---

val avx_pmovsqw_128 : xmmword -> dword
function avx_pmovsqw_128(src) = {
  var r : dword = zeros();
  foreach (i from 0 to 1) {
    let slo : range(0, 64) = i * 64;
    let dlo : range(0, 16) = i * 16;
    let v : int = signed(src[(slo + 63)..slo]);
    r[(dlo + 15)..dlo] = if v > 32767 then 0x7FFF
                          else if v < negate(32768) then 0x8000
                          else get_slice_int(16, v, 0);
  };
  r
}
val avx_pmovsqw_256 : ymmword -> qword
function avx_pmovsqw_256(src) = {
  var r : qword = zeros();
  foreach (i from 0 to 3) {
    let slo : range(0, 192) = i * 64;
    let dlo : range(0, 48) = i * 16;
    let v : int = signed(src[(slo + 63)..slo]);
    r[(dlo + 15)..dlo] = if v > 32767 then 0x7FFF
                          else if v < negate(32768) then 0x8000
                          else get_slice_int(16, v, 0);
  };
  r
}
val avx_pmovsqw_512 : zmmword -> xmmword
function avx_pmovsqw_512(src) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let slo : range(0, 448) = i * 64;
    let dlo : range(0, 112) = i * 16;
    let v : int = signed(src[(slo + 63)..slo]);
    r[(dlo + 15)..dlo] = if v > 32767 then 0x7FFF
                          else if v < negate(32768) then 0x8000
                          else get_slice_int(16, v, 0);
  };
  r
}

// --- VPMOVSQD: signed-saturate qword -> dword ---

val avx_pmovsqd_128 : xmmword -> qword
function avx_pmovsqd_128(src) = {
  var r : qword = zeros();
  foreach (i from 0 to 1) {
    let slo : range(0, 64) = i * 64;
    let dlo : range(0, 32) = i * 32;
    let v : int = signed(src[(slo + 63)..slo]);
    r[(dlo + 31)..dlo] = if v > 2147483647 then 0x7FFFFFFF
                          else if v < negate(2147483648) then 0x80000000
                          else get_slice_int(32, v, 0);
  };
  r
}
val avx_pmovsqd_256 : ymmword -> xmmword
function avx_pmovsqd_256(src) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let slo : range(0, 192) = i * 64;
    let dlo : range(0, 96) = i * 32;
    let v : int = signed(src[(slo + 63)..slo]);
    r[(dlo + 31)..dlo] = if v > 2147483647 then 0x7FFFFFFF
                          else if v < negate(2147483648) then 0x80000000
                          else get_slice_int(32, v, 0);
  };
  r
}
val avx_pmovsqd_512 : zmmword -> ymmword
function avx_pmovsqd_512(src) = {
  var r : ymmword = zeros();
  foreach (i from 0 to 7) {
    let slo : range(0, 448) = i * 64;
    let dlo : range(0, 224) = i * 32;
    let v : int = signed(src[(slo + 63)..slo]);
    r[(dlo + 31)..dlo] = if v > 2147483647 then 0x7FFFFFFF
                          else if v < negate(2147483648) then 0x80000000
                          else get_slice_int(32, v, 0);
  };
  r
}

// =====================================================================
// VPMOVM2B: mask register -> vector (each bit -> 0xFF or 0x00 byte)
// =====================================================================

val avx_vpmovm2b_128 : qword -> xmmword
function avx_vpmovm2b_128(k) = {
  var result : xmmword = zeros();
  foreach (i from 0 to 15) {
    let lo : range(0, 120) = i * 8;
    result[(lo + 7)..lo] = if k[i] == bitone then 0xFF else 0x00;
  };
  result
}

val avx_vpmovm2b_256 : qword -> ymmword
function avx_vpmovm2b_256(k) = {
  var result : ymmword = zeros();
  foreach (i from 0 to 31) {
    let lo : range(0, 248) = i * 8;
    result[(lo + 7)..lo] = if k[i] == bitone then 0xFF else 0x00;
  };
  result
}

val avx_vpmovm2b_512 : qword -> zmmword
function avx_vpmovm2b_512(k) = {
  var result : zmmword = zeros();
  foreach (i from 0 to 63) {
    let lo : range(0, 504) = i * 8;
    result[(lo + 7)..lo] = if k[i] == bitone then 0xFF else 0x00;
  };
  result
}

// =====================================================================
// VPMOVM2W: mask register -> vector (each bit -> 0xFFFF or 0x0000 word)
// =====================================================================

val avx_vpmovm2w_128 : qword -> xmmword
function avx_vpmovm2w_128(k) = {
  var result : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    result[(lo + 15)..lo] = if k[i] == bitone then 0xFFFF else 0x0000;
  };
  result
}

val avx_vpmovm2w_256 : qword -> ymmword
function avx_vpmovm2w_256(k) = {
  var result : ymmword = zeros();
  foreach (i from 0 to 15) {
    let lo : range(0, 240) = i * 16;
    result[(lo + 15)..lo] = if k[i] == bitone then 0xFFFF else 0x0000;
  };
  result
}

val avx_vpmovm2w_512 : qword -> zmmword
function avx_vpmovm2w_512(k) = {
  var result : zmmword = zeros();
  foreach (i from 0 to 31) {
    let lo : range(0, 496) = i * 16;
    result[(lo + 15)..lo] = if k[i] == bitone then 0xFFFF else 0x0000;
  };
  result
}

// =====================================================================
// VPMOVM2D: mask register -> vector (each bit -> all-ones or all-zeros dword)
// =====================================================================

val avx_vpmovm2d_128 : qword -> xmmword
function avx_vpmovm2d_128(k) = {
  var result : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    result[(lo + 31)..lo] = if k[i] == bitone then 0xFFFFFFFF else 0x00000000;
  };
  result
}

val avx_vpmovm2d_256 : qword -> ymmword
function avx_vpmovm2d_256(k) = {
  var result : ymmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 224) = i * 32;
    result[(lo + 31)..lo] = if k[i] == bitone then 0xFFFFFFFF else 0x00000000;
  };
  result
}

val avx_vpmovm2d_512 : qword -> zmmword
function avx_vpmovm2d_512(k) = {
  var result : zmmword = zeros();
  foreach (i from 0 to 15) {
    let lo : range(0, 480) = i * 32;
    result[(lo + 31)..lo] = if k[i] == bitone then 0xFFFFFFFF else 0x00000000;
  };
  result
}

// =====================================================================
// VPMOVM2Q: mask register -> vector (each bit -> all-ones or all-zeros qword)
// =====================================================================

val avx_vpmovm2q_128 : qword -> xmmword
function avx_vpmovm2q_128(k) = {
  var result : xmmword = zeros();
  foreach (i from 0 to 1) {
    let lo : range(0, 64) = i * 64;
    result[(lo + 63)..lo] = if k[i] == bitone then ones() else zeros();
  };
  result
}

val avx_vpmovm2q_256 : qword -> ymmword
function avx_vpmovm2q_256(k) = {
  var result : ymmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 192) = i * 64;
    result[(lo + 63)..lo] = if k[i] == bitone then ones() else zeros();
  };
  result
}

val avx_vpmovm2q_512 : qword -> zmmword
function avx_vpmovm2q_512(k) = {
  var result : zmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 448) = i * 64;
    result[(lo + 63)..lo] = if k[i] == bitone then ones() else zeros();
  };
  result
}

// =====================================================================
// VPMOVB2M: vector -> mask (MSB of each byte -> mask bit)
// =====================================================================

val avx_vpmovb2m_128 : xmmword -> qword
function avx_vpmovb2m_128(src) = {
  var result : qword = zeros();
  foreach (i from 0 to 15) {
    if src[i * 8 + 7] == bitone then result = result | (zero_extend(0b1 : bits(1)) << i);
  };
  result
}

val avx_vpmovb2m_256 : ymmword -> qword
function avx_vpmovb2m_256(src) = {
  var result : qword = zeros();
  foreach (i from 0 to 31) {
    if src[i * 8 + 7] == bitone then result = result | (zero_extend(0b1 : bits(1)) << i);
  };
  result
}

val avx_vpmovb2m_512 : zmmword -> qword
function avx_vpmovb2m_512(src) = {
  var result : qword = zeros();
  foreach (i from 0 to 63) {
    if src[i * 8 + 7] == bitone then result = result | (zero_extend(0b1 : bits(1)) << i);
  };
  result
}

// =====================================================================
// VPMOVW2M: vector -> mask (MSB of each word -> mask bit)
// =====================================================================

val avx_vpmovw2m_128 : xmmword -> qword
function avx_vpmovw2m_128(src) = {
  var result : qword = zeros();
  foreach (i from 0 to 7) {
    if src[i * 16 + 15] == bitone then result = result | (zero_extend(0b1 : bits(1)) << i);
  };
  result
}

val avx_vpmovw2m_256 : ymmword -> qword
function avx_vpmovw2m_256(src) = {
  var result : qword = zeros();
  foreach (i from 0 to 15) {
    if src[i * 16 + 15] == bitone then result = result | (zero_extend(0b1 : bits(1)) << i);
  };
  result
}

val avx_vpmovw2m_512 : zmmword -> qword
function avx_vpmovw2m_512(src) = {
  var result : qword = zeros();
  foreach (i from 0 to 31) {
    if src[i * 16 + 15] == bitone then result = result | (zero_extend(0b1 : bits(1)) << i);
  };
  result
}

// =====================================================================
// VPMOVD2M: vector -> mask (MSB of each dword -> mask bit)
// =====================================================================

val avx_vpmovd2m_128 : xmmword -> qword
function avx_vpmovd2m_128(src) = {
  var result : qword = zeros();
  foreach (i from 0 to 3) {
    if src[i * 32 + 31] == bitone then result = result | (zero_extend(0b1 : bits(1)) << i);
  };
  result
}

val avx_vpmovd2m_256 : ymmword -> qword
function avx_vpmovd2m_256(src) = {
  var result : qword = zeros();
  foreach (i from 0 to 7) {
    if src[i * 32 + 31] == bitone then result = result | (zero_extend(0b1 : bits(1)) << i);
  };
  result
}

val avx_vpmovd2m_512 : zmmword -> qword
function avx_vpmovd2m_512(src) = {
  var result : qword = zeros();
  foreach (i from 0 to 15) {
    if src[i * 32 + 31] == bitone then result = result | (zero_extend(0b1 : bits(1)) << i);
  };
  result
}

// =====================================================================
// VPMOVQ2M: vector -> mask (MSB of each qword -> mask bit)
// =====================================================================

val avx_vpmovq2m_128 : xmmword -> qword
function avx_vpmovq2m_128(src) = {
  var result : qword = zeros();
  foreach (i from 0 to 1) {
    if src[i * 64 + 63] == bitone then result = result | (zero_extend(0b1 : bits(1)) << i);
  };
  result
}

val avx_vpmovq2m_256 : ymmword -> qword
function avx_vpmovq2m_256(src) = {
  var result : qword = zeros();
  foreach (i from 0 to 3) {
    if src[i * 64 + 63] == bitone then result = result | (zero_extend(0b1 : bits(1)) << i);
  };
  result
}

val avx_vpmovq2m_512 : zmmword -> qword
function avx_vpmovq2m_512(src) = {
  var result : qword = zeros();
  foreach (i from 0 to 7) {
    if src[i * 64 + 63] == bitone then result = result | (zero_extend(0b1 : bits(1)) << i);
  };
  result
}

/* ---- VSHUFF32X4 / VSHUFI32X4: 128-bit lane shuffle ---- */

// Helper: select 128-bit lane from a 512-bit source
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

val avx_vdbpsadbw_128 : (xmmword, xmmword, byte) -> xmmword
function avx_vdbpsadbw_128(src1, src2, imm) = {
  // imm8[1:0] selects src2 starting byte offset within each 128-bit lane's low 4 bytes
  // imm8[3:2] selects src2 starting byte offset within each 128-bit lane's high 4 bytes
  // For each 2 adjacent words in the destination:
  //   dst[i] = sum of |src1_byte[j] - src2_byte[k]| for 4 byte pairs
  // This is complex. For now, implement the basic algorithm.
  let sh_lo : range(0, 3) = unsigned(imm[1..0]);
  let sh_hi : range(0, 3) = unsigned(imm[3..2]);
  var result : xmmword = zeros();
  // Lower 4 words: compare src1[3:0] bytes against selected src2 bytes
  foreach (j from 0 to 3) {
    var sad : int = 0;
    foreach (k from 0 to 3) {
      let s1_byte : byte = src1[((j + k) * 8 + 7)..((j + k) * 8)];
      let s2_byte : byte = src2[((sh_lo + k) * 8 + 7)..((sh_lo + k) * 8)];
      let diff : int = unsigned(s1_byte) - unsigned(s2_byte);
      sad = sad + (if diff < 0 then negate(diff) else diff);
    };
    let w : word = get_slice_int(16, sad, 0);
    result[(j * 16 + 15)..(j * 16)] = w;
  };
  // Upper 4 words: compare src1[11:8] bytes against selected src2 bytes in upper half
  foreach (j from 0 to 3) {
    var sad : int = 0;
    foreach (k from 0 to 3) {
      let s1_byte : byte = src1[((8 + j + k) * 8 + 7)..((8 + j + k) * 8)];
      let s2_byte : byte = src2[((8 + sh_hi + k) * 8 + 7)..((8 + sh_hi + k) * 8)];
      let diff : int = unsigned(s1_byte) - unsigned(s2_byte);
      sad = sad + (if diff < 0 then negate(diff) else diff);
    };
    let w : word = get_slice_int(16, sad, 0);
    result[((4 + j) * 16 + 15)..((4 + j) * 16)] = w;
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
val popcount_byte : (byte, int) -> int
function popcount_byte(mask, upto) = {
  var count : int = 0;
  foreach (i from 0 to 7) {
    if i < upto then {
      if mask[i] == bitone then count = count + 1;
    };
  };
  count
}

val popcount_word : (word, int) -> int
function popcount_word(mask, upto) = {
  var count : int = 0;
  foreach (i from 0 to 15) {
    if i < upto then {
      if mask[i] == bitone then count = count + 1;
    };
  };
  count
}

// For expand/compress, we use a simpler strategy: iterate and use get_slice/set_slice
// with computed bit offsets, working element-by-element.

val avx_vexpandps_128 : (xmmword, byte) -> xmmword
function avx_vexpandps_128(src, mask) = {
  var result : xmmword = zeros();
  foreach (i from 0 to 3) {
    if mask[i] == bitone then {
      let j = popcount_byte(mask, i);
      assert(j >= 0);
      let dst_lo : range(0, 96) = i * 32;
      let src_elem : dword = get_slice_int(32, unsigned(src), j * 32);
      result[(dst_lo + 31)..dst_lo] = src_elem;
    };
  };
  result
}

val avx_vexpandps_256 : (ymmword, byte) -> ymmword
function avx_vexpandps_256(src, mask) = {
  var result : ymmword = zeros();
  foreach (i from 0 to 7) {
    if mask[i] == bitone then {
      let j = popcount_byte(mask, i);
      assert(j >= 0);
      let dst_lo : range(0, 224) = i * 32;
      let src_elem : dword = get_slice_int(32, unsigned(src), j * 32);
      result[(dst_lo + 31)..dst_lo] = src_elem;
    };
  };
  result
}

val avx_vexpandps_512 : (zmmword, word) -> zmmword
function avx_vexpandps_512(src, mask) = {
  var result : zmmword = zeros();
  foreach (i from 0 to 15) {
    if mask[i] == bitone then {
      let j = popcount_word(mask, i);
      assert(j >= 0);
      let dst_lo : range(0, 480) = i * 32;
      let src_elem : dword = get_slice_int(32, unsigned(src), j * 32);
      result[(dst_lo + 31)..dst_lo] = src_elem;
    };
  };
  result
}

val avx_vexpandpd_128 : (xmmword, byte) -> xmmword
function avx_vexpandpd_128(src, mask) = {
  var result : xmmword = zeros();
  foreach (i from 0 to 1) {
    if mask[i] == bitone then {
      let j = popcount_byte(mask, i);
      assert(j >= 0);
      let dst_lo : range(0, 64) = i * 64;
      let src_elem : qword = get_slice_int(64, unsigned(src), j * 64);
      result[(dst_lo + 63)..dst_lo] = src_elem;
    };
  };
  result
}

val avx_vexpandpd_256 : (ymmword, byte) -> ymmword
function avx_vexpandpd_256(src, mask) = {
  var result : ymmword = zeros();
  foreach (i from 0 to 3) {
    if mask[i] == bitone then {
      let j = popcount_byte(mask, i);
      assert(j >= 0);
      let dst_lo : range(0, 192) = i * 64;
      let src_elem : qword = get_slice_int(64, unsigned(src), j * 64);
      result[(dst_lo + 63)..dst_lo] = src_elem;
    };
  };
  result
}

val avx_vexpandpd_512 : (zmmword, byte) -> zmmword
function avx_vexpandpd_512(src, mask) = {
  var result : zmmword = zeros();
  foreach (i from 0 to 7) {
    if mask[i] == bitone then {
      let j = popcount_byte(mask, i);
      assert(j >= 0);
      let dst_lo : range(0, 448) = i * 64;
      let src_elem : qword = get_slice_int(64, unsigned(src), j * 64);
      result[(dst_lo + 63)..dst_lo] = src_elem;
    };
  };
  result
}

/* ---- VCOMPRESSPS/PD: compress from masked positions to contiguous ---- */

val avx_vcompressps_128 : (xmmword, byte) -> xmmword
function avx_vcompressps_128(src, mask) = {
  var result : xmmword = zeros();
  foreach (i from 0 to 3) {
    if mask[i] == bitone then {
      let j = popcount_byte(mask, i);
      assert(j >= 0);
      let src_lo : range(0, 96) = i * 32;
      let src_elem : dword = src[(src_lo + 31)..src_lo];
      result = result | (zero_extend(src_elem) << (j * 32));
    };
  };
  result
}

val avx_vcompressps_256 : (ymmword, byte) -> ymmword
function avx_vcompressps_256(src, mask) = {
  var result : ymmword = zeros();
  foreach (i from 0 to 7) {
    if mask[i] == bitone then {
      let j = popcount_byte(mask, i);
      assert(j >= 0);
      let src_lo : range(0, 224) = i * 32;
      let src_elem : dword = src[(src_lo + 31)..src_lo];
      result = result | (zero_extend(src_elem) << (j * 32));
    };
  };
  result
}

val avx_vcompressps_512 : (zmmword, word) -> zmmword
function avx_vcompressps_512(src, mask) = {
  var result : zmmword = zeros();
  foreach (i from 0 to 15) {
    if mask[i] == bitone then {
      let j = popcount_word(mask, i);
      assert(j >= 0);
      let src_lo : range(0, 480) = i * 32;
      let src_elem : dword = src[(src_lo + 31)..src_lo];
      result = result | (zero_extend(src_elem) << (j * 32));
    };
  };
  result
}

val avx_vcompresspd_128 : (xmmword, byte) -> xmmword
function avx_vcompresspd_128(src, mask) = {
  var result : xmmword = zeros();
  foreach (i from 0 to 1) {
    if mask[i] == bitone then {
      let j = popcount_byte(mask, i);
      assert(j >= 0);
      let src_lo : range(0, 64) = i * 64;
      let src_elem : qword = src[(src_lo + 63)..src_lo];
      result = result | (zero_extend(src_elem) << (j * 64));
    };
  };
  result
}

val avx_vcompresspd_256 : (ymmword, byte) -> ymmword
function avx_vcompresspd_256(src, mask) = {
  var result : ymmword = zeros();
  foreach (i from 0 to 3) {
    if mask[i] == bitone then {
      let j = popcount_byte(mask, i);
      assert(j >= 0);
      let src_lo : range(0, 192) = i * 64;
      let src_elem : qword = src[(src_lo + 63)..src_lo];
      result = result | (zero_extend(src_elem) << (j * 64));
    };
  };
  result
}

val avx_vcompresspd_512 : (zmmword, byte) -> zmmword
function avx_vcompresspd_512(src, mask) = {
  var result : zmmword = zeros();
  foreach (i from 0 to 7) {
    if mask[i] == bitone then {
      let j = popcount_byte(mask, i);
      assert(j >= 0);
      let src_lo : range(0, 448) = i * 64;
      let src_elem : qword = src[(src_lo + 63)..src_lo];
      result = result | (zero_extend(src_elem) << (j * 64));
    };
  };
  result
}

// VPEXPANDD/Q and VPCOMPRESSD/Q use the same logic as the FP variants
// (dword elements = same as PS, qword elements = same as PD)

/* ---- VRNDSCALE: round to specified precision ---- */

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

val avx_lzcnt32 : dword -> dword
function avx_lzcnt32(v) = {
  if v == zeros() then 0x00000020
  else {
    let count : range(0, 32) = 0;
    foreach (i from 31 downto 0) {
      if v[i] == bitone then return to_bits(32, 31 - i)
    };
    0x00000020
  }
}

val avx_lzcnt64 : qword -> qword
function avx_lzcnt64(v) = {
  if v == zeros() then 0x0000000000000040
  else {
    foreach (i from 63 downto 0) {
      if v[i] == bitone then return to_bits(64, 63 - i)
    };
    0x0000000000000040
  }
}

val avx_vplzcntd_128 : xmmword -> xmmword
function avx_vplzcntd_128(src) = {
  avx_lzcnt32(src[127..96]) @ avx_lzcnt32(src[95..64]) @ avx_lzcnt32(src[63..32]) @ avx_lzcnt32(src[31..0])
}

val avx_vplzcntd_256 : ymmword -> ymmword
function avx_vplzcntd_256(src) = {
  avx_vplzcntd_128(src[255..128]) @ avx_vplzcntd_128(src[127..0])
}

val avx_vplzcntd_512 : zmmword -> zmmword
function avx_vplzcntd_512(src) = {
  avx_vplzcntd_256(src[511..256]) @ avx_vplzcntd_256(src[255..0])
}

val avx_vplzcntq_128 : xmmword -> xmmword
function avx_vplzcntq_128(src) = {
  avx_lzcnt64(src[127..64]) @ avx_lzcnt64(src[63..0])
}

val avx_vplzcntq_256 : ymmword -> ymmword
function avx_vplzcntq_256(src) = {
  avx_vplzcntq_128(src[255..128]) @ avx_vplzcntq_128(src[127..0])
}

val avx_vplzcntq_512 : zmmword -> zmmword
function avx_vplzcntq_512(src) = {
  avx_vplzcntq_256(src[511..256]) @ avx_vplzcntq_256(src[255..0])
}

/* ---- VPCONFLICTD/Q: conflict detection ---- */
// For each element i, produce a bitmask of preceding elements (j < i) that have the same value.

val avx_vpconflictd_128 : xmmword -> xmmword
function avx_vpconflictd_128(src) = {
  var result : xmmword = zeros();
  foreach (i from 0 to 3) {
    let ilo : range(0, 96) = i * 32;
    let elem_i : dword = src[(ilo + 31)..ilo];
    var mask : dword = zeros();
    foreach (j from 0 to 3) {
      if j < i then {
        let jlo : range(0, 96) = j * 32;
        let elem_j : dword = src[(jlo + 31)..jlo];
        if elem_i == elem_j then mask = mask | (sail_zero_extend(0x00000001, 32) << j);
      }
    };
    result[(ilo + 31)..ilo] = mask;
  };
  result
}

val avx_vpconflictd_256 : ymmword -> ymmword
function avx_vpconflictd_256(src) = {
  var result : ymmword = zeros();
  foreach (i from 0 to 7) {
    let ilo : range(0, 224) = i * 32;
    let elem_i : dword = src[(ilo + 31)..ilo];
    var mask : dword = zeros();
    foreach (j from 0 to 7) {
      if j < i then {
        let jlo : range(0, 224) = j * 32;
        let elem_j : dword = src[(jlo + 31)..jlo];
        if elem_i == elem_j then mask = mask | (sail_zero_extend(0x00000001, 32) << j);
      }
    };
    result[(ilo + 31)..ilo] = mask;
  };
  result
}

val avx_vpconflictd_512 : zmmword -> zmmword
function avx_vpconflictd_512(src) = {
  var result : zmmword = zeros();
  foreach (i from 0 to 15) {
    let ilo : range(0, 480) = i * 32;
    let elem_i : dword = src[(ilo + 31)..ilo];
    var mask : dword = zeros();
    foreach (j from 0 to 15) {
      if j < i then {
        let jlo : range(0, 480) = j * 32;
        let elem_j : dword = src[(jlo + 31)..jlo];
        if elem_i == elem_j then mask = mask | (sail_zero_extend(0x00000001, 32) << j);
      }
    };
    result[(ilo + 31)..ilo] = mask;
  };
  result
}

val avx_vpconflictq_128 : xmmword -> xmmword
function avx_vpconflictq_128(src) = {
  var result : xmmword = zeros();
  foreach (i from 0 to 1) {
    let ilo : range(0, 64) = i * 64;
    let elem_i : qword = src[(ilo + 63)..ilo];
    var mask : qword = zeros();
    foreach (j from 0 to 1) {
      if j < i then {
        let jlo : range(0, 64) = j * 64;
        let elem_j : qword = src[(jlo + 63)..jlo];
        if elem_i == elem_j then mask = mask | (sail_zero_extend(0x0000000000000001, 64) << j);
      }
    };
    result[(ilo + 63)..ilo] = mask;
  };
  result
}

val avx_vpconflictq_256 : ymmword -> ymmword
function avx_vpconflictq_256(src) = {
  var result : ymmword = zeros();
  foreach (i from 0 to 3) {
    let ilo : range(0, 192) = i * 64;
    let elem_i : qword = src[(ilo + 63)..ilo];
    var mask : qword = zeros();
    foreach (j from 0 to 3) {
      if j < i then {
        let jlo : range(0, 192) = j * 64;
        let elem_j : qword = src[(jlo + 63)..jlo];
        if elem_i == elem_j then mask = mask | (sail_zero_extend(0x0000000000000001, 64) << j);
      }
    };
    result[(ilo + 63)..ilo] = mask;
  };
  result
}

val avx_vpconflictq_512 : zmmword -> zmmword
function avx_vpconflictq_512(src) = {
  var result : zmmword = zeros();
  foreach (i from 0 to 7) {
    let ilo : range(0, 448) = i * 64;
    let elem_i : qword = src[(ilo + 63)..ilo];
    var mask : qword = zeros();
    foreach (j from 0 to 7) {
      if j < i then {
        let jlo : range(0, 448) = j * 64;
        let elem_j : qword = src[(jlo + 63)..jlo];
        if elem_i == elem_j then mask = mask | (sail_zero_extend(0x0000000000000001, 64) << j);
      }
    };
    result[(ilo + 63)..ilo] = mask;
  };
  result
}

/* ---- VFPCLASS: classify FP value ---- */
// Returns true if any of the imm8-selected classes match:
// bit 0: QNaN, bit 1: +0, bit 2: -0, bit 3: +Inf, bit 4: -Inf
// bit 5: denormal, bit 6: negative finite, bit 7: SNaN

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
  let b0 : bits(1) = if avx_fpclass_f32(src[31..0], imm) then 0b1 else 0b0;
  let b1 : bits(1) = if avx_fpclass_f32(src[63..32], imm) then 0b1 else 0b0;
  let b2 : bits(1) = if avx_fpclass_f32(src[95..64], imm) then 0b1 else 0b0;
  let b3 : bits(1) = if avx_fpclass_f32(src[127..96], imm) then 0b1 else 0b0;
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
  let b0 : bits(1) = if avx_fpclass_f64(src[63..0], imm) then 0b1 else 0b0;
  let b1 : bits(1) = if avx_fpclass_f64(src[127..64], imm) then 0b1 else 0b0;
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
// VRANGE: for each element pair, select min/max/abs-min/abs-max and optionally set sign
// imm8[1:0] = operation: 0=min, 1=max, 2=abs_min, 3=abs_max
// imm8[3:2] = sign control: 0=src1_sign, 1=0, 2=1, 3=sign(compare result)

val avx_vrangeps_128 : (xmmword, xmmword, byte) -> xmmword
function avx_vrangeps_128(src1, src2, imm) = {
  // Simplified: use __f32_min/__f32_max based on operation
  let op : range(0, 3) = unsigned(imm[1..0]);
  var result : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    let a : dword = src1[(lo + 31)..lo];
    let b : dword = src2[(lo + 31)..lo];
    let r : dword = match op {
      0 => __f32_min(a, b),
      1 => __f32_max(a, b),
      2 => { // abs min
        let abs_a : dword = 0b0 @ a[30..0];
        let abs_b : dword = 0b0 @ b[30..0];
        __f32_min(abs_a, abs_b)
      },
      _ => { // abs max
        let abs_a : dword = 0b0 @ a[30..0];
        let abs_b : dword = 0b0 @ b[30..0];
        __f32_max(abs_a, abs_b)
      },
    };
    result[(lo + 31)..lo] = r;
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
  let op : range(0, 3) = unsigned(imm[1..0]);
  var result : xmmword = zeros();
  foreach (i from 0 to 1) {
    let lo : range(0, 64) = i * 64;
    let a : qword = src1[(lo + 63)..lo];
    let b : qword = src2[(lo + 63)..lo];
    let r : qword = match op {
      0 => __f64_min(a, b),
      1 => __f64_max(a, b),
      2 => { let abs_a : qword = 0b0 @ a[62..0]; let abs_b : qword = 0b0 @ b[62..0]; __f64_min(abs_a, abs_b) },
      _ => { let abs_a : qword = 0b0 @ a[62..0]; let abs_b : qword = 0b0 @ b[62..0]; __f64_max(abs_a, abs_b) },
    };
    result[(lo + 63)..lo] = r;
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

val avx_vpbroadcastmb2q_128 : byte -> xmmword
function avx_vpbroadcastmb2q_128(k) = {
  let elem : qword = zero_extend(k);
  elem @ elem
}

val avx_vpbroadcastmb2q_256 : byte -> ymmword
function avx_vpbroadcastmb2q_256(k) = {
  let elem : qword = zero_extend(k);
  elem @ elem @ elem @ elem
}

val avx_vpbroadcastmb2q_512 : byte -> zmmword
function avx_vpbroadcastmb2q_512(k) = {
  let elem : qword = zero_extend(k);
  elem @ elem @ elem @ elem @ elem @ elem @ elem @ elem
}

val avx_vpbroadcastmw2d_128 : word -> xmmword
function avx_vpbroadcastmw2d_128(k) = {
  let elem : dword = zero_extend(k);
  elem @ elem @ elem @ elem
}

val avx_vpbroadcastmw2d_256 : word -> ymmword
function avx_vpbroadcastmw2d_256(k) = {
  let elem : dword = zero_extend(k);
  elem @ elem @ elem @ elem @ elem @ elem @ elem @ elem
}

val avx_vpbroadcastmw2d_512 : word -> zmmword
function avx_vpbroadcastmw2d_512(k) = {
  let elem : dword = zero_extend(k);
  elem @ elem @ elem @ elem @ elem @ elem @ elem @ elem @ elem @ elem @ elem @ elem @ elem @ elem @ elem @ elem
}

/* ---- VPDPBUSD: Multiply and Add Unsigned and Signed Bytes ---- */
// For each dword position:
//   temp = src1.u8[0]*src2.s8[0] + src1.u8[1]*src2.s8[1] + src1.u8[2]*src2.s8[2] + src1.u8[3]*src2.s8[3]
//   dst.dword += temp

val avx_vpdpbusd_elem : (dword, dword, dword) -> dword
function avx_vpdpbusd_elem(dst, s1, s2) = {
  let p0 : int = unsigned(s1[7..0]) * signed(s2[7..0]);
  let p1 : int = unsigned(s1[15..8]) * signed(s2[15..8]);
  let p2 : int = unsigned(s1[23..16]) * signed(s2[23..16]);
  let p3 : int = unsigned(s1[31..24]) * signed(s2[31..24]);
  let sum : int = signed(dst) + p0 + p1 + p2 + p3;
  get_slice_int(32, sum, 0)
}

val avx_vpdpbusd_128 : (xmmword, xmmword, xmmword) -> xmmword
function avx_vpdpbusd_128(dst, src1, src2) = {
  avx_vpdpbusd_elem(dst[127..96], src1[127..96], src2[127..96]) @
  avx_vpdpbusd_elem(dst[95..64], src1[95..64], src2[95..64]) @
  avx_vpdpbusd_elem(dst[63..32], src1[63..32], src2[63..32]) @
  avx_vpdpbusd_elem(dst[31..0], src1[31..0], src2[31..0])
}

val avx_vpdpbusd_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_vpdpbusd_256(dst, src1, src2) = {
  avx_vpdpbusd_128(dst[255..128], src1[255..128], src2[255..128]) @
  avx_vpdpbusd_128(dst[127..0], src1[127..0], src2[127..0])
}

val avx_vpdpbusd_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_vpdpbusd_512(dst, src1, src2) = {
  avx_vpdpbusd_256(dst[511..256], src1[511..256], src2[511..256]) @
  avx_vpdpbusd_256(dst[255..0], src1[255..0], src2[255..0])
}

/* ---- VPDPWSSD: Multiply and Add Signed Word Integers ---- */
// For each dword: dst += src1.s16[0]*src2.s16[0] + src1.s16[1]*src2.s16[1]

val avx_vpdpwssd_elem : (dword, dword, dword) -> dword
function avx_vpdpwssd_elem(dst, s1, s2) = {
  let p0 : int = signed(s1[15..0]) * signed(s2[15..0]);
  let p1 : int = signed(s1[31..16]) * signed(s2[31..16]);
  let sum : int = signed(dst) + p0 + p1;
  get_slice_int(32, sum, 0)
}

val avx_vpdpwssd_128 : (xmmword, xmmword, xmmword) -> xmmword
function avx_vpdpwssd_128(dst, src1, src2) = {
  avx_vpdpwssd_elem(dst[127..96], src1[127..96], src2[127..96]) @
  avx_vpdpwssd_elem(dst[95..64], src1[95..64], src2[95..64]) @
  avx_vpdpwssd_elem(dst[63..32], src1[63..32], src2[63..32]) @
  avx_vpdpwssd_elem(dst[31..0], src1[31..0], src2[31..0])
}

val avx_vpdpwssd_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_vpdpwssd_256(dst, src1, src2) = {
  avx_vpdpwssd_128(dst[255..128], src1[255..128], src2[255..128]) @
  avx_vpdpwssd_128(dst[127..0], src1[127..0], src2[127..0])
}

val avx_vpdpwssd_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_vpdpwssd_512(dst, src1, src2) = {
  avx_vpdpwssd_256(dst[511..256], src1[511..256], src2[511..256]) @
  avx_vpdpwssd_256(dst[255..0], src1[255..0], src2[255..0])
}

/* ---- VPDPWSSDS: Same as VPDPWSSD but with signed dword saturation ---- */

val sat_s32 : int -> dword
function sat_s32(v) = {
  if v > 2147483647 then 0x7FFFFFFF
  else if v < negate(2147483648) then 0x80000000
  else get_slice_int(32, v, 0)
}

val avx_vpdpwssds_elem : (dword, dword, dword) -> dword
function avx_vpdpwssds_elem(dst, s1, s2) = {
  let p0 : int = signed(s1[15..0]) * signed(s2[15..0]);
  let p1 : int = signed(s1[31..16]) * signed(s2[31..16]);
  let sum : int = signed(dst) + p0 + p1;
  sat_s32(sum)
}

val avx_vpdpwssds_128 : (xmmword, xmmword, xmmword) -> xmmword
function avx_vpdpwssds_128(dst, src1, src2) = {
  avx_vpdpwssds_elem(dst[127..96], src1[127..96], src2[127..96]) @
  avx_vpdpwssds_elem(dst[95..64], src1[95..64], src2[95..64]) @
  avx_vpdpwssds_elem(dst[63..32], src1[63..32], src2[63..32]) @
  avx_vpdpwssds_elem(dst[31..0], src1[31..0], src2[31..0])
}

val avx_vpdpwssds_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_vpdpwssds_256(dst, src1, src2) = {
  avx_vpdpwssds_128(dst[255..128], src1[255..128], src2[255..128]) @
  avx_vpdpwssds_128(dst[127..0], src1[127..0], src2[127..0])
}

val avx_vpdpwssds_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_vpdpwssds_512(dst, src1, src2) = {
  avx_vpdpwssds_256(dst[511..256], src1[511..256], src2[511..256]) @
  avx_vpdpwssds_256(dst[255..0], src1[255..0], src2[255..0])
}

/* ---- VPDPBUSDS: VPDPBUSD with signed dword saturation ---- */

val avx_vpdpbusds_elem : (dword, dword, dword) -> dword
function avx_vpdpbusds_elem(dst, s1, s2) = {
  let p0 : int = unsigned(s1[7..0]) * signed(s2[7..0]);
  let p1 : int = unsigned(s1[15..8]) * signed(s2[15..8]);
  let p2 : int = unsigned(s1[23..16]) * signed(s2[23..16]);
  let p3 : int = unsigned(s1[31..24]) * signed(s2[31..24]);
  let sum : int = signed(dst) + p0 + p1 + p2 + p3;
  sat_s32(sum)
}

val avx_vpdpbusds_128 : (xmmword, xmmword, xmmword) -> xmmword
function avx_vpdpbusds_128(dst, src1, src2) = {
  avx_vpdpbusds_elem(dst[127..96], src1[127..96], src2[127..96]) @
  avx_vpdpbusds_elem(dst[95..64], src1[95..64], src2[95..64]) @
  avx_vpdpbusds_elem(dst[63..32], src1[63..32], src2[63..32]) @
  avx_vpdpbusds_elem(dst[31..0], src1[31..0], src2[31..0])
}

val avx_vpdpbusds_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_vpdpbusds_256(dst, src1, src2) = {
  avx_vpdpbusds_128(dst[255..128], src1[255..128], src2[255..128]) @
  avx_vpdpbusds_128(dst[127..0], src1[127..0], src2[127..0])
}

val avx_vpdpbusds_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_vpdpbusds_512(dst, src1, src2) = {
  avx_vpdpbusds_256(dst[511..256], src1[511..256], src2[511..256]) @
  avx_vpdpbusds_256(dst[255..0], src1[255..0], src2[255..0])
}

/* ---- VPOPCNT: population count per element ---- */

val popcnt8 : byte -> byte
function popcnt8(v) = {
  var count : int = 0;
  foreach (i from 0 to 7) { if v[i] == bitone then count = count + 1 };
  get_slice_int(8, count, 0)
}

val popcnt16 : word -> word
function popcnt16(v) = {
  var count : int = 0;
  foreach (i from 0 to 15) { if v[i] == bitone then count = count + 1 };
  get_slice_int(16, count, 0)
}

val popcnt32 : dword -> dword
function popcnt32(v) = {
  var count : int = 0;
  foreach (i from 0 to 31) { if v[i] == bitone then count = count + 1 };
  get_slice_int(32, count, 0)
}

val popcnt64 : qword -> qword
function popcnt64(v) = {
  var count : int = 0;
  foreach (i from 0 to 63) { if v[i] == bitone then count = count + 1 };
  get_slice_int(64, count, 0)
}

// VPOPCNTB (byte elements)
val avx_vpopcntb_128 : xmmword -> xmmword
function avx_vpopcntb_128(src) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 15) {
    let lo : range(0, 120) = i * 8;
    r[(lo + 7)..lo] = popcnt8(src[(lo + 7)..lo]);
  };
  r
}

val avx_vpopcntb_256 : ymmword -> ymmword
function avx_vpopcntb_256(src) = {
  avx_vpopcntb_128(src[255..128]) @ avx_vpopcntb_128(src[127..0])
}

val avx_vpopcntb_512 : zmmword -> zmmword
function avx_vpopcntb_512(src) = {
  avx_vpopcntb_256(src[511..256]) @ avx_vpopcntb_256(src[255..0])
}

// VPOPCNTW (word elements)
val avx_vpopcntw_128 : xmmword -> xmmword
function avx_vpopcntw_128(src) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    r[(lo + 15)..lo] = popcnt16(src[(lo + 15)..lo]);
  };
  r
}

val avx_vpopcntw_256 : ymmword -> ymmword
function avx_vpopcntw_256(src) = {
  avx_vpopcntw_128(src[255..128]) @ avx_vpopcntw_128(src[127..0])
}

val avx_vpopcntw_512 : zmmword -> zmmword
function avx_vpopcntw_512(src) = {
  avx_vpopcntw_256(src[511..256]) @ avx_vpopcntw_256(src[255..0])
}

// VPOPCNTD (dword elements)
val avx_vpopcntd_128 : xmmword -> xmmword
function avx_vpopcntd_128(src) = {
  popcnt32(src[127..96]) @ popcnt32(src[95..64]) @ popcnt32(src[63..32]) @ popcnt32(src[31..0])
}

val avx_vpopcntd_256 : ymmword -> ymmword
function avx_vpopcntd_256(src) = {
  avx_vpopcntd_128(src[255..128]) @ avx_vpopcntd_128(src[127..0])
}

val avx_vpopcntd_512 : zmmword -> zmmword
function avx_vpopcntd_512(src) = {
  avx_vpopcntd_256(src[511..256]) @ avx_vpopcntd_256(src[255..0])
}

// VPOPCNTQ (qword elements)
val avx_vpopcntq_128 : xmmword -> xmmword
function avx_vpopcntq_128(src) = {
  popcnt64(src[127..64]) @ popcnt64(src[63..0])
}

val avx_vpopcntq_256 : ymmword -> ymmword
function avx_vpopcntq_256(src) = {
  avx_vpopcntq_128(src[255..128]) @ avx_vpopcntq_128(src[127..0])
}

val avx_vpopcntq_512 : zmmword -> zmmword
function avx_vpopcntq_512(src) = {
  avx_vpopcntq_256(src[511..256]) @ avx_vpopcntq_256(src[255..0])
}

/* ---- VCVTPH2PS/VCVTPS2PH: 512-bit variants (128/256 defined in insn_vex.sail) ---- */

val avx_vcvtph2ps_512 : ymmword -> zmmword
function avx_vcvtph2ps_512(src) = {
  avx_vcvtph2ps_256(src[255..128]) @ avx_vcvtph2ps_256(src[127..0])
}

val avx_vcvtps2ph_512 : zmmword -> ymmword
function avx_vcvtps2ph_512(src) = {
  avx_vcvtps2ph_256(src[511..256]) @ avx_vcvtps2ph_256(src[255..0])
}

/* ---- Gather: VPGATHERDD/DQ, VGATHERDPS/DPD (dword indices) ---- */
/* ---- Gather: VPGATHERQD/QQ, VGATHERQPS/QPD (qword indices) ---- */

// Compute effective address for one gather element.
// base + sign_extend(index) << scale
val gather_addr : (qword, dword, range(0, 3)) -> qword
function gather_addr(base, idx32, scale) = {
  let offset : qword = sign_extend(idx32);
  match scale {
    0 => base + offset,
    1 => base + (offset << 1),
    2 => base + (offset << 2),
    3 => base + (offset << 3),
  }
}

val gather_addr_q : (qword, qword, range(0, 3)) -> qword
function gather_addr_q(base, idx64, scale) = {
  match scale {
    0 => base + idx64,
    1 => base + (idx64 << 1),
    2 => base + (idx64 << 2),
    3 => base + (idx64 << 3),
  }
}

// VPGATHERDD / VGATHERDPS: 32-bit indices, 32-bit elements
// ZMM: 16 elements, mask is 16 bits
val exec_gather_d32_512 : (simd_idx, VSIB, kreg_idx) -> ExecutionResult
function exec_gather_d32_512(dst, vsib, k_idx) = {
  let mask : qword = read_kreg(k_idx);
  var result : zmmword = read_zmm(dst);
  let indices : zmmword = read_zmm(vsib.vsib_vidx);
  foreach (i from 0 to 15) {
    let lo : range(0, 480) = i * 32;
    if mask[i] == bitone then {
      let idx : dword = indices[(lo + 31)..lo];
      let addr = gather_addr(vsib.vsib_base, idx, vsib.vsib_scale);
      let v : dword = mem_read32(addr);
      result = [result with (lo + 31)..lo = v];
    }
  };
  write_zmm(dst, result);
  write_kreg(k_idx, zeros()); // all mask bits cleared
  Ok(())
}

val exec_gather_d32_256 : (simd_idx, VSIB, kreg_idx) -> ExecutionResult
function exec_gather_d32_256(dst, vsib, k_idx) = {
  let mask : qword = read_kreg(k_idx);
  var result : ymmword = read_ymm(dst);
  let indices : ymmword = read_ymm(vsib.vsib_vidx);
  foreach (i from 0 to 7) {
    let lo : range(0, 224) = i * 32;
    if mask[i] == bitone then {
      let idx : dword = indices[(lo + 31)..lo];
      let addr = gather_addr(vsib.vsib_base, idx, vsib.vsib_scale);
      let v : dword = mem_read32(addr);
      result = [result with (lo + 31)..lo = v];
    }
  };
  write_ymm(dst, result);
  write_kreg(k_idx, zeros());
  Ok(())
}

val exec_gather_d32_128 : (simd_idx, VSIB, kreg_idx) -> ExecutionResult
function exec_gather_d32_128(dst, vsib, k_idx) = {
  let mask : qword = read_kreg(k_idx);
  var result : xmmword = read_xmm(dst);
  let indices : xmmword = read_xmm(vsib.vsib_vidx);
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    if mask[i] == bitone then {
      let idx : dword = indices[(lo + 31)..lo];
      let addr = gather_addr(vsib.vsib_base, idx, vsib.vsib_scale);
      let v : dword = mem_read32(addr);
      result = [result with (lo + 31)..lo = v];
    }
  };
  write_xmm(dst, result);
  write_kreg(k_idx, zeros());
  Ok(())
}

// VPGATHERDQ / VGATHERDPD: 32-bit indices, 64-bit elements
// ZMM: 8 qword elements, indices from YMM (8 dwords)
val exec_gather_d64_512 : (simd_idx, VSIB, kreg_idx) -> ExecutionResult
function exec_gather_d64_512(dst, vsib, k_idx) = {
  let mask : qword = read_kreg(k_idx);
  var result : zmmword = read_zmm(dst);
  let indices : ymmword = read_ymm(vsib.vsib_vidx);
  foreach (i from 0 to 7) {
    let ilo : range(0, 224) = i * 32;
    let olo : range(0, 448) = i * 64;
    if mask[i] == bitone then {
      let idx : dword = indices[(ilo + 31)..ilo];
      let addr = gather_addr(vsib.vsib_base, idx, vsib.vsib_scale);
      let v : qword = mem_read64(addr);
      result = [result with (olo + 63)..olo = v];
    }
  };
  write_zmm(dst, result);
  write_kreg(k_idx, zeros());
  Ok(())
}

val exec_gather_d64_256 : (simd_idx, VSIB, kreg_idx) -> ExecutionResult
function exec_gather_d64_256(dst, vsib, k_idx) = {
  let mask : qword = read_kreg(k_idx);
  var result : ymmword = read_ymm(dst);
  let indices : xmmword = read_xmm(vsib.vsib_vidx);
  foreach (i from 0 to 3) {
    let ilo : range(0, 96) = i * 32;
    let olo : range(0, 192) = i * 64;
    if mask[i] == bitone then {
      let idx : dword = indices[(ilo + 31)..ilo];
      let addr = gather_addr(vsib.vsib_base, idx, vsib.vsib_scale);
      let v : qword = mem_read64(addr);
      result = [result with (olo + 63)..olo = v];
    }
  };
  write_ymm(dst, result);
  write_kreg(k_idx, zeros());
  Ok(())
}

val exec_gather_d64_128 : (simd_idx, VSIB, kreg_idx) -> ExecutionResult
function exec_gather_d64_128(dst, vsib, k_idx) = {
  let mask : qword = read_kreg(k_idx);
  var result : xmmword = read_xmm(dst);
  let indices : xmmword = read_xmm(vsib.vsib_vidx);
  foreach (i from 0 to 1) {
    let ilo : range(0, 32) = i * 32;
    let olo : range(0, 64) = i * 64;
    if mask[i] == bitone then {
      let idx : dword = indices[(ilo + 31)..ilo];
      let addr = gather_addr(vsib.vsib_base, idx, vsib.vsib_scale);
      let v : qword = mem_read64(addr);
      result = [result with (olo + 63)..olo = v];
    }
  };
  write_xmm(dst, result);
  write_kreg(k_idx, zeros());
  Ok(())
}

// VPGATHERQD / VGATHERQPS: 64-bit indices, 32-bit elements
// ZMM index: 8 qwords → 8 dword results in YMM
val exec_gather_q32_512 : (simd_idx, VSIB, kreg_idx) -> ExecutionResult
function exec_gather_q32_512(dst, vsib, k_idx) = {
  let mask : qword = read_kreg(k_idx);
  var result : ymmword = read_ymm(dst);
  let indices : zmmword = read_zmm(vsib.vsib_vidx);
  foreach (i from 0 to 7) {
    let ilo : range(0, 448) = i * 64;
    let olo : range(0, 224) = i * 32;
    if mask[i] == bitone then {
      let idx : qword = indices[(ilo + 63)..ilo];
      let addr = gather_addr_q(vsib.vsib_base, idx, vsib.vsib_scale);
      let v : dword = mem_read32(addr);
      result = [result with (olo + 31)..olo = v];
    }
  };
  write_ymm(dst, result);
  write_kreg(k_idx, zeros());
  Ok(())
}

val exec_gather_q32_256 : (simd_idx, VSIB, kreg_idx) -> ExecutionResult
function exec_gather_q32_256(dst, vsib, k_idx) = {
  let mask : qword = read_kreg(k_idx);
  var result : xmmword = read_xmm(dst);
  let indices : ymmword = read_ymm(vsib.vsib_vidx);
  foreach (i from 0 to 3) {
    let ilo : range(0, 192) = i * 64;
    let olo : range(0, 96) = i * 32;
    if mask[i] == bitone then {
      let idx : qword = indices[(ilo + 63)..ilo];
      let addr = gather_addr_q(vsib.vsib_base, idx, vsib.vsib_scale);
      let v : dword = mem_read32(addr);
      result = [result with (olo + 31)..olo = v];
    }
  };
  // Write as XMM (zero-extends upper)
  write_xmm(dst, result);
  write_kreg(k_idx, zeros());
  Ok(())
}

val exec_gather_q32_128 : (simd_idx, VSIB, kreg_idx) -> ExecutionResult
function exec_gather_q32_128(dst, vsib, k_idx) = {
  let mask : qword = read_kreg(k_idx);
  var result : xmmword = read_xmm(dst);
  let indices : xmmword = read_xmm(vsib.vsib_vidx);
  foreach (i from 0 to 1) {
    let ilo : range(0, 64) = i * 64;
    let olo : range(0, 32) = i * 32;
    if mask[i] == bitone then {
      let idx : qword = indices[(ilo + 63)..ilo];
      let addr = gather_addr_q(vsib.vsib_base, idx, vsib.vsib_scale);
      let v : dword = mem_read32(addr);
      result = [result with (olo + 31)..olo = v];
    }
  };
  write_xmm(dst, result);
  write_kreg(k_idx, zeros());
  Ok(())
}

// VPGATHERQQ / VGATHERQPD: 64-bit indices, 64-bit elements
val exec_gather_q64_512 : (simd_idx, VSIB, kreg_idx) -> ExecutionResult
function exec_gather_q64_512(dst, vsib, k_idx) = {
  let mask : qword = read_kreg(k_idx);
  var result : zmmword = read_zmm(dst);
  let indices : zmmword = read_zmm(vsib.vsib_vidx);
  foreach (i from 0 to 7) {
    let lo : range(0, 448) = i * 64;
    if mask[i] == bitone then {
      let idx : qword = indices[(lo + 63)..lo];
      let addr = gather_addr_q(vsib.vsib_base, idx, vsib.vsib_scale);
      let v : qword = mem_read64(addr);
      result = [result with (lo + 63)..lo = v];
    }
  };
  write_zmm(dst, result);
  write_kreg(k_idx, zeros());
  Ok(())
}

val exec_gather_q64_256 : (simd_idx, VSIB, kreg_idx) -> ExecutionResult
function exec_gather_q64_256(dst, vsib, k_idx) = {
  let mask : qword = read_kreg(k_idx);
  var result : ymmword = read_ymm(dst);
  let indices : ymmword = read_ymm(vsib.vsib_vidx);
  foreach (i from 0 to 3) {
    let lo : range(0, 192) = i * 64;
    if mask[i] == bitone then {
      let idx : qword = indices[(lo + 63)..lo];
      let addr = gather_addr_q(vsib.vsib_base, idx, vsib.vsib_scale);
      let v : qword = mem_read64(addr);
      result = [result with (lo + 63)..lo = v];
    }
  };
  write_ymm(dst, result);
  write_kreg(k_idx, zeros());
  Ok(())
}

val exec_gather_q64_128 : (simd_idx, VSIB, kreg_idx) -> ExecutionResult
function exec_gather_q64_128(dst, vsib, k_idx) = {
  let mask : qword = read_kreg(k_idx);
  var result : xmmword = read_xmm(dst);
  let indices : xmmword = read_xmm(vsib.vsib_vidx);
  foreach (i from 0 to 1) {
    let lo : range(0, 64) = i * 64;
    if mask[i] == bitone then {
      let idx : qword = indices[(lo + 63)..lo];
      let addr = gather_addr_q(vsib.vsib_base, idx, vsib.vsib_scale);
      let v : qword = mem_read64(addr);
      result = [result with (lo + 63)..lo = v];
    }
  };
  write_xmm(dst, result);
  write_kreg(k_idx, zeros());
  Ok(())
}

/* ---- Scatter: VPSCATTERDD/DQ, VSCATTERDPS/DPD (dword indices) ---- */
/* ---- Scatter: VPSCATTERQD/QQ, VSCATTERQPS/QPD (qword indices) ---- */

// VPSCATTERDD / VSCATTERDPS: 32-bit indices, 32-bit elements
val exec_scatter_d32_512 : (simd_idx, VSIB, kreg_idx) -> ExecutionResult
function exec_scatter_d32_512(src, vsib, k_idx) = {
  let mask : qword = read_kreg(k_idx);
  let data : zmmword = read_zmm(src);
  let indices : zmmword = read_zmm(vsib.vsib_vidx);
  foreach (i from 0 to 15) {
    let lo : range(0, 480) = i * 32;
    if mask[i] == bitone then {
      let idx : dword = indices[(lo + 31)..lo];
      let addr = gather_addr(vsib.vsib_base, idx, vsib.vsib_scale);
      mem_write32(addr, data[(lo + 31)..lo]);
    }
  };
  write_kreg(k_idx, zeros());
  Ok(())
}

val exec_scatter_d32_256 : (simd_idx, VSIB, kreg_idx) -> ExecutionResult
function exec_scatter_d32_256(src, vsib, k_idx) = {
  let mask : qword = read_kreg(k_idx);
  let data : ymmword = read_ymm(src);
  let indices : ymmword = read_ymm(vsib.vsib_vidx);
  foreach (i from 0 to 7) {
    let lo : range(0, 224) = i * 32;
    if mask[i] == bitone then {
      let idx : dword = indices[(lo + 31)..lo];
      let addr = gather_addr(vsib.vsib_base, idx, vsib.vsib_scale);
      mem_write32(addr, data[(lo + 31)..lo]);
    }
  };
  write_kreg(k_idx, zeros());
  Ok(())
}

val exec_scatter_d32_128 : (simd_idx, VSIB, kreg_idx) -> ExecutionResult
function exec_scatter_d32_128(src, vsib, k_idx) = {
  let mask : qword = read_kreg(k_idx);
  let data : xmmword = read_xmm(src);
  let indices : xmmword = read_xmm(vsib.vsib_vidx);
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    if mask[i] == bitone then {
      let idx : dword = indices[(lo + 31)..lo];
      let addr = gather_addr(vsib.vsib_base, idx, vsib.vsib_scale);
      mem_write32(addr, data[(lo + 31)..lo]);
    }
  };
  write_kreg(k_idx, zeros());
  Ok(())
}

// VPSCATTERDQ / VSCATTERDPD: 32-bit indices, 64-bit elements
val exec_scatter_d64_512 : (simd_idx, VSIB, kreg_idx) -> ExecutionResult
function exec_scatter_d64_512(src, vsib, k_idx) = {
  let mask : qword = read_kreg(k_idx);
  let data : zmmword = read_zmm(src);
  let indices : ymmword = read_ymm(vsib.vsib_vidx);
  foreach (i from 0 to 7) {
    let ilo : range(0, 224) = i * 32;
    let olo : range(0, 448) = i * 64;
    if mask[i] == bitone then {
      let idx : dword = indices[(ilo + 31)..ilo];
      let addr = gather_addr(vsib.vsib_base, idx, vsib.vsib_scale);
      mem_write64(addr, data[(olo + 63)..olo]);
    }
  };
  write_kreg(k_idx, zeros());
  Ok(())
}

val exec_scatter_d64_256 : (simd_idx, VSIB, kreg_idx) -> ExecutionResult
function exec_scatter_d64_256(src, vsib, k_idx) = {
  let mask : qword = read_kreg(k_idx);
  let data : ymmword = read_ymm(src);
  let indices : xmmword = read_xmm(vsib.vsib_vidx);
  foreach (i from 0 to 3) {
    let ilo : range(0, 96) = i * 32;
    let olo : range(0, 192) = i * 64;
    if mask[i] == bitone then {
      let idx : dword = indices[(ilo + 31)..ilo];
      let addr = gather_addr(vsib.vsib_base, idx, vsib.vsib_scale);
      mem_write64(addr, data[(olo + 63)..olo]);
    }
  };
  write_kreg(k_idx, zeros());
  Ok(())
}

val exec_scatter_d64_128 : (simd_idx, VSIB, kreg_idx) -> ExecutionResult
function exec_scatter_d64_128(src, vsib, k_idx) = {
  let mask : qword = read_kreg(k_idx);
  let data : xmmword = read_xmm(src);
  let indices : xmmword = read_xmm(vsib.vsib_vidx);
  foreach (i from 0 to 1) {
    let ilo : range(0, 32) = i * 32;
    let olo : range(0, 64) = i * 64;
    if mask[i] == bitone then {
      let idx : dword = indices[(ilo + 31)..ilo];
      let addr = gather_addr(vsib.vsib_base, idx, vsib.vsib_scale);
      mem_write64(addr, data[(olo + 63)..olo]);
    }
  };
  write_kreg(k_idx, zeros());
  Ok(())
}

// VPSCATTERQD / VSCATTERQPS: 64-bit indices, 32-bit elements
val exec_scatter_q32_512 : (simd_idx, VSIB, kreg_idx) -> ExecutionResult
function exec_scatter_q32_512(src, vsib, k_idx) = {
  let mask : qword = read_kreg(k_idx);
  let data : ymmword = read_ymm(src);
  let indices : zmmword = read_zmm(vsib.vsib_vidx);
  foreach (i from 0 to 7) {
    let ilo : range(0, 448) = i * 64;
    let olo : range(0, 224) = i * 32;
    if mask[i] == bitone then {
      let idx : qword = indices[(ilo + 63)..ilo];
      let addr = gather_addr_q(vsib.vsib_base, idx, vsib.vsib_scale);
      mem_write32(addr, data[(olo + 31)..olo]);
    }
  };
  write_kreg(k_idx, zeros());
  Ok(())
}

val exec_scatter_q32_256 : (simd_idx, VSIB, kreg_idx) -> ExecutionResult
function exec_scatter_q32_256(src, vsib, k_idx) = {
  let mask : qword = read_kreg(k_idx);
  let data : xmmword = read_xmm(src);
  let indices : ymmword = read_ymm(vsib.vsib_vidx);
  foreach (i from 0 to 3) {
    let ilo : range(0, 192) = i * 64;
    let olo : range(0, 96) = i * 32;
    if mask[i] == bitone then {
      let idx : qword = indices[(ilo + 63)..ilo];
      let addr = gather_addr_q(vsib.vsib_base, idx, vsib.vsib_scale);
      mem_write32(addr, data[(olo + 31)..olo]);
    }
  };
  write_kreg(k_idx, zeros());
  Ok(())
}

val exec_scatter_q32_128 : (simd_idx, VSIB, kreg_idx) -> ExecutionResult
function exec_scatter_q32_128(src, vsib, k_idx) = {
  let mask : qword = read_kreg(k_idx);
  let data : xmmword = read_xmm(src);
  let indices : xmmword = read_xmm(vsib.vsib_vidx);
  foreach (i from 0 to 1) {
    let ilo : range(0, 64) = i * 64;
    let olo : range(0, 32) = i * 32;
    if mask[i] == bitone then {
      let idx : qword = indices[(ilo + 63)..ilo];
      let addr = gather_addr_q(vsib.vsib_base, idx, vsib.vsib_scale);
      mem_write32(addr, data[(olo + 31)..olo]);
    }
  };
  write_kreg(k_idx, zeros());
  Ok(())
}

// VPSCATTERQQ / VSCATTERQPD: 64-bit indices, 64-bit elements
val exec_scatter_q64_512 : (simd_idx, VSIB, kreg_idx) -> ExecutionResult
function exec_scatter_q64_512(src, vsib, k_idx) = {
  let mask : qword = read_kreg(k_idx);
  let data : zmmword = read_zmm(src);
  let indices : zmmword = read_zmm(vsib.vsib_vidx);
  foreach (i from 0 to 7) {
    let lo : range(0, 448) = i * 64;
    if mask[i] == bitone then {
      let idx : qword = indices[(lo + 63)..lo];
      let addr = gather_addr_q(vsib.vsib_base, idx, vsib.vsib_scale);
      mem_write64(addr, data[(lo + 63)..lo]);
    }
  };
  write_kreg(k_idx, zeros());
  Ok(())
}

val exec_scatter_q64_256 : (simd_idx, VSIB, kreg_idx) -> ExecutionResult
function exec_scatter_q64_256(src, vsib, k_idx) = {
  let mask : qword = read_kreg(k_idx);
  let data : ymmword = read_ymm(src);
  let indices : ymmword = read_ymm(vsib.vsib_vidx);
  foreach (i from 0 to 3) {
    let lo : range(0, 192) = i * 64;
    if mask[i] == bitone then {
      let idx : qword = indices[(lo + 63)..lo];
      let addr = gather_addr_q(vsib.vsib_base, idx, vsib.vsib_scale);
      mem_write64(addr, data[(lo + 63)..lo]);
    }
  };
  write_kreg(k_idx, zeros());
  Ok(())
}

val exec_scatter_q64_128 : (simd_idx, VSIB, kreg_idx) -> ExecutionResult
function exec_scatter_q64_128(src, vsib, k_idx) = {
  let mask : qword = read_kreg(k_idx);
  let data : xmmword = read_xmm(src);
  let indices : xmmword = read_xmm(vsib.vsib_vidx);
  foreach (i from 0 to 1) {
    let lo : range(0, 64) = i * 64;
    if mask[i] == bitone then {
      let idx : qword = indices[(lo + 63)..lo];
      let addr = gather_addr_q(vsib.vsib_base, idx, vsib.vsib_scale);
      mem_write64(addr, data[(lo + 63)..lo]);
    }
  };
  write_kreg(k_idx, zeros());
  Ok(())
}

/* ---- VPCLMULQDQ: carry-less multiply per 128-bit lane ---- */

val avx_vpclmulqdq_lane : (xmmword, xmmword, byte) -> xmmword
function avx_vpclmulqdq_lane(src1, src2, imm8) = {
  let sel_a : qword = if imm8[0] == bitone then src1[127..64] else src1[63..0];
  let sel_b : qword = if imm8[4] == bitone then src2[127..64] else src2[63..0];
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

val avx_vpshldw_elem : (word, word, nat) -> word
function avx_vpshldw_elem(src1, src2, cnt) = {
  let count : int = cnt % 16;
  let concat : dword = src1 @ src2;
  let shifted : dword = sail_shiftleft(concat, count);
  shifted[31..16]
}

val avx_vpshldd_elem : (dword, dword, nat) -> dword
function avx_vpshldd_elem(src1, src2, cnt) = {
  let count : int = cnt % 32;
  let concat : qword = src1 @ src2;
  let shifted : qword = sail_shiftleft(concat, count);
  shifted[63..32]
}

val avx_vpshldq_elem : (qword, qword, nat) -> qword
function avx_vpshldq_elem(src1, src2, cnt) = {
  let count : int = cnt % 64;
  let concat : bits(128) = src1 @ src2;
  let shifted : bits(128) = sail_shiftleft(concat, count);
  shifted[127..64]
}

val avx_vpshrdw_elem : (word, word, nat) -> word
function avx_vpshrdw_elem(src1, src2, cnt) = {
  let count : int = cnt % 16;
  let concat : dword = src2 @ src1;
  let shifted : dword = sail_shiftright(concat, count);
  shifted[15..0]
}

val avx_vpshrdd_elem : (dword, dword, nat) -> dword
function avx_vpshrdd_elem(src1, src2, cnt) = {
  let count : int = cnt % 32;
  let concat : qword = src2 @ src1;
  let shifted : qword = sail_shiftright(concat, count);
  shifted[31..0]
}

val avx_vpshrdq_elem : (qword, qword, nat) -> qword
function avx_vpshrdq_elem(src1, src2, cnt) = {
  let count : int = cnt % 64;
  let concat : bits(128) = src2 @ src1;
  let shifted : bits(128) = sail_shiftright(concat, count);
  shifted[63..0]
}

// Variable versions (VPSHLDVW/D/Q)
val avx_vpshldvw_128 : (xmmword, xmmword, xmmword) -> xmmword
function avx_vpshldvw_128(dst, src1, src2) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    r[(lo + 15)..lo] = avx_vpshldw_elem(src1[(lo + 15)..lo], dst[(lo + 15)..lo], unsigned(src2[(lo + 15)..lo]));
  }; r
}
val avx_vpshldvw_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_vpshldvw_256(dst, src1, src2) = {
  avx_vpshldvw_128(dst[255..128], src1[255..128], src2[255..128]) @
  avx_vpshldvw_128(dst[127..0], src1[127..0], src2[127..0])
}
val avx_vpshldvw_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_vpshldvw_512(dst, src1, src2) = {
  avx_vpshldvw_256(dst[511..256], src1[511..256], src2[511..256]) @
  avx_vpshldvw_256(dst[255..0], src1[255..0], src2[255..0])
}

val avx_vpshldvd_128 : (xmmword, xmmword, xmmword) -> xmmword
function avx_vpshldvd_128(dst, src1, src2) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    r[(lo + 31)..lo] = avx_vpshldd_elem(src1[(lo + 31)..lo], dst[(lo + 31)..lo], unsigned(src2[(lo + 31)..lo]));
  }; r
}
val avx_vpshldvd_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_vpshldvd_256(dst, src1, src2) = {
  avx_vpshldvd_128(dst[255..128], src1[255..128], src2[255..128]) @
  avx_vpshldvd_128(dst[127..0], src1[127..0], src2[127..0])
}
val avx_vpshldvd_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_vpshldvd_512(dst, src1, src2) = {
  avx_vpshldvd_256(dst[511..256], src1[511..256], src2[511..256]) @
  avx_vpshldvd_256(dst[255..0], src1[255..0], src2[255..0])
}

val avx_vpshldvq_128 : (xmmword, xmmword, xmmword) -> xmmword
function avx_vpshldvq_128(dst, src1, src2) = {
  avx_vpshldq_elem(src1[127..64], dst[127..64], unsigned(src2[127..64])) @
  avx_vpshldq_elem(src1[63..0], dst[63..0], unsigned(src2[63..0]))
}
val avx_vpshldvq_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_vpshldvq_256(dst, src1, src2) = {
  avx_vpshldvq_128(dst[255..128], src1[255..128], src2[255..128]) @
  avx_vpshldvq_128(dst[127..0], src1[127..0], src2[127..0])
}
val avx_vpshldvq_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_vpshldvq_512(dst, src1, src2) = {
  avx_vpshldvq_256(dst[511..256], src1[511..256], src2[511..256]) @
  avx_vpshldvq_256(dst[255..0], src1[255..0], src2[255..0])
}

// Variable versions (VPSHRDVW/D/Q)
val avx_vpshrdvw_128 : (xmmword, xmmword, xmmword) -> xmmword
function avx_vpshrdvw_128(dst, src1, src2) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    r[(lo + 15)..lo] = avx_vpshrdw_elem(src1[(lo + 15)..lo], dst[(lo + 15)..lo], unsigned(src2[(lo + 15)..lo]));
  }; r
}
val avx_vpshrdvw_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_vpshrdvw_256(dst, src1, src2) = {
  avx_vpshrdvw_128(dst[255..128], src1[255..128], src2[255..128]) @
  avx_vpshrdvw_128(dst[127..0], src1[127..0], src2[127..0])
}
val avx_vpshrdvw_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_vpshrdvw_512(dst, src1, src2) = {
  avx_vpshrdvw_256(dst[511..256], src1[511..256], src2[511..256]) @
  avx_vpshrdvw_256(dst[255..0], src1[255..0], src2[255..0])
}

val avx_vpshrdvd_128 : (xmmword, xmmword, xmmword) -> xmmword
function avx_vpshrdvd_128(dst, src1, src2) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    r[(lo + 31)..lo] = avx_vpshrdd_elem(src1[(lo + 31)..lo], dst[(lo + 31)..lo], unsigned(src2[(lo + 31)..lo]));
  }; r
}
val avx_vpshrdvd_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_vpshrdvd_256(dst, src1, src2) = {
  avx_vpshrdvd_128(dst[255..128], src1[255..128], src2[255..128]) @
  avx_vpshrdvd_128(dst[127..0], src1[127..0], src2[127..0])
}
val avx_vpshrdvd_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_vpshrdvd_512(dst, src1, src2) = {
  avx_vpshrdvd_256(dst[511..256], src1[511..256], src2[511..256]) @
  avx_vpshrdvd_256(dst[255..0], src1[255..0], src2[255..0])
}

val avx_vpshrdvq_128 : (xmmword, xmmword, xmmword) -> xmmword
function avx_vpshrdvq_128(dst, src1, src2) = {
  avx_vpshrdq_elem(src1[127..64], dst[127..64], unsigned(src2[127..64])) @
  avx_vpshrdq_elem(src1[63..0], dst[63..0], unsigned(src2[63..0]))
}
val avx_vpshrdvq_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_vpshrdvq_256(dst, src1, src2) = {
  avx_vpshrdvq_128(dst[255..128], src1[255..128], src2[255..128]) @
  avx_vpshrdvq_128(dst[127..0], src1[127..0], src2[127..0])
}
val avx_vpshrdvq_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_vpshrdvq_512(dst, src1, src2) = {
  avx_vpshrdvq_256(dst[511..256], src1[511..256], src2[511..256]) @
  avx_vpshrdvq_256(dst[255..0], src1[255..0], src2[255..0])
}

// Immediate versions (VPSHLDW/D/Q imm8)
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
val avx_vpmadd52luq_elem : (qword, qword, qword) -> qword
function avx_vpmadd52luq_elem(dst, src1, src2) = {
  let a : int = unsigned(src1[51..0]);
  let b : int = unsigned(src2[51..0]);
  let product : int = a * b;
  let low52 : qword = get_slice_int(64, product, 0);
  // Add low 52 bits of product to dst, keep result as 64-bit
  let sum : int = unsigned(dst) + unsigned(low52[51..0] : bits(52));
  get_slice_int(64, sum, 0)
}

val avx_vpmadd52huq_elem : (qword, qword, qword) -> qword
function avx_vpmadd52huq_elem(dst, src1, src2) = {
  let a : int = unsigned(src1[51..0]);
  let b : int = unsigned(src2[51..0]);
  let product : int = a * b;
  let high52 : qword = get_slice_int(64, product, 52);
  let sum : int = unsigned(dst) + unsigned(high52[51..0] : bits(52));
  get_slice_int(64, sum, 0)
}

val avx_vpmadd52luq_128 : (xmmword, xmmword, xmmword) -> xmmword
function avx_vpmadd52luq_128(dst, src1, src2) = {
  avx_vpmadd52luq_elem(dst[127..64], src1[127..64], src2[127..64]) @
  avx_vpmadd52luq_elem(dst[63..0], src1[63..0], src2[63..0])
}
val avx_vpmadd52luq_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_vpmadd52luq_256(dst, src1, src2) = {
  avx_vpmadd52luq_128(dst[255..128], src1[255..128], src2[255..128]) @
  avx_vpmadd52luq_128(dst[127..0], src1[127..0], src2[127..0])
}
val avx_vpmadd52luq_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_vpmadd52luq_512(dst, src1, src2) = {
  avx_vpmadd52luq_256(dst[511..256], src1[511..256], src2[511..256]) @
  avx_vpmadd52luq_256(dst[255..0], src1[255..0], src2[255..0])
}

val avx_vpmadd52huq_128 : (xmmword, xmmword, xmmword) -> xmmword
function avx_vpmadd52huq_128(dst, src1, src2) = {
  avx_vpmadd52huq_elem(dst[127..64], src1[127..64], src2[127..64]) @
  avx_vpmadd52huq_elem(dst[63..0], src1[63..0], src2[63..0])
}
val avx_vpmadd52huq_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_vpmadd52huq_256(dst, src1, src2) = {
  avx_vpmadd52huq_128(dst[255..128], src1[255..128], src2[255..128]) @
  avx_vpmadd52huq_128(dst[127..0], src1[127..0], src2[127..0])
}
val avx_vpmadd52huq_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_vpmadd52huq_512(dst, src1, src2) = {
  avx_vpmadd52huq_256(dst[511..256], src1[511..256], src2[511..256]) @
  avx_vpmadd52huq_256(dst[255..0], src1[255..0], src2[255..0])
}

/* ---- VPMULTISHIFTQB: multi-shift qword bytes (VBMI) ---- */
// For each byte in src1 (shift control), extract 8 consecutive bits from src2 qword
// starting at bit position = src1_byte[5:0], within the same 64-bit lane.
val avx_vpmultishiftqb_lane : (qword, qword) -> qword
function avx_vpmultishiftqb_lane(ctrl, src) = {
  var r : qword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 56) = i * 8;
    let shift : nat = unsigned(ctrl[(lo + 5)..(lo)]);
    // Extract 8 bits starting at 'shift' from src (wrapping within 64 bits)
    var byte_val : byte = zeros();
    foreach (b from 0 to 7) {
      let bit_pos : range(0, 63) = (shift + b) % 64;
      byte_val[b] = src[bit_pos];
    };
    r[(lo + 7)..lo] = byte_val;
  };
  r
}

val avx_vpmultishiftqb_128 : (xmmword, xmmword) -> xmmword
function avx_vpmultishiftqb_128(ctrl, src) = {
  avx_vpmultishiftqb_lane(ctrl[127..64], src[127..64]) @
  avx_vpmultishiftqb_lane(ctrl[63..0], src[63..0])
}
val avx_vpmultishiftqb_256 : (ymmword, ymmword) -> ymmword
function avx_vpmultishiftqb_256(ctrl, src) = {
  avx_vpmultishiftqb_128(ctrl[255..128], src[255..128]) @
  avx_vpmultishiftqb_128(ctrl[127..0], src[127..0])
}
val avx_vpmultishiftqb_512 : (zmmword, zmmword) -> zmmword
function avx_vpmultishiftqb_512(ctrl, src) = {
  avx_vpmultishiftqb_256(ctrl[511..256], src[511..256]) @
  avx_vpmultishiftqb_256(ctrl[255..0], src[255..0])
}

/* ---- VPSHUFBITQMB: shuffle bits to mask (BITALG) ---- */
// For each byte in src1, use it as an index to select a bit from the
// corresponding qword lane of src2. The selected bit goes to kmask.
val avx_vpshufbitqmb_lane : (qword, qword) -> byte
function avx_vpshufbitqmb_lane(ctrl, src) = {
  var r : byte = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 56) = i * 8;
    let bit_idx : range(0, 63) = unsigned(ctrl[(lo + 5)..(lo)]);
    r[i] = src[bit_idx];
  };
  r
}

val avx_vpshufbitqmb_128 : (xmmword, xmmword) -> word
function avx_vpshufbitqmb_128(ctrl, src) = {
  avx_vpshufbitqmb_lane(ctrl[127..64], src[127..64]) @
  avx_vpshufbitqmb_lane(ctrl[63..0], src[63..0])
}
val avx_vpshufbitqmb_256 : (ymmword, ymmword) -> dword
function avx_vpshufbitqmb_256(ctrl, src) = {
  avx_vpshufbitqmb_128(ctrl[255..128], src[255..128]) @
  avx_vpshufbitqmb_128(ctrl[127..0], src[127..0])
}
val avx_vpshufbitqmb_512 : (zmmword, zmmword) -> qword
function avx_vpshufbitqmb_512(ctrl, src) = {
  avx_vpshufbitqmb_256(ctrl[511..256], src[511..256]) @
  avx_vpshufbitqmb_256(ctrl[255..0], src[255..0])
}

/* VPEXPANDB/W and VPCOMPRESSB/W (VBMI2) — simplified pass-through in decoder */

/* ---- GFNI: Galois Field operations ---- */

// GF(2^8) multiplication using AES polynomial (x^8 + x^4 + x^3 + x + 1)
val gf2p8_mul : (byte, byte) -> byte
function gf2p8_mul(a, b) = {
  var result : bits(9) = zeros();
  var aa : bits(9) = sail_zero_extend(a, 9);
  foreach (i from 0 to 7) {
    if b[i] == bitone then result = result ^ aa;
    aa = aa << 1;
    if aa[8] == bitone then aa = aa ^ 0b100011011 // 0x11B
  };
  result[7..0]
}

// GF2P8MULB: byte-wise GF(2^8) multiply
val avx_gf2p8mulb_128 : (xmmword, xmmword) -> xmmword
function avx_gf2p8mulb_128(src1, src2) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 15) {
    let lo : range(0, 120) = i * 8;
    r[(lo + 7)..lo] = gf2p8_mul(src1[(lo + 7)..lo], src2[(lo + 7)..lo]);
  };
  r
}
val avx_gf2p8mulb_256 : (ymmword, ymmword) -> ymmword
function avx_gf2p8mulb_256(src1, src2) = {
  avx_gf2p8mulb_128(src1[255..128], src2[255..128]) @
  avx_gf2p8mulb_128(src1[127..0], src2[127..0])
}
val avx_gf2p8mulb_512 : (zmmword, zmmword) -> zmmword
function avx_gf2p8mulb_512(src1, src2) = {
  avx_gf2p8mulb_256(src1[511..256], src2[511..256]) @
  avx_gf2p8mulb_256(src1[255..0], src2[255..0])
}

// GF2P8AFFINEQB: For each byte in src1, compute an affine transformation
// using an 8x8 bit matrix from the corresponding qword of src2, then XOR with imm8.
// result_byte[i] = popcount(src1_byte & matrix_row[i]) ^ imm8[i]
// where matrix_row[i] is the i-th byte of the qword (MSB first: row0 = qword[63:56])
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
    foreach (j from 0 to 7) { if product[j] == bitone then bit = if bit == bitzero then bitone else bitzero };
    // XOR with imm8 bit
    r[i] = if bit == imm8[i] then bitzero else bitone;
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

val avx_vexp2ps_512 : zmmword -> zmmword
function avx_vexp2ps_512(src) = {
  __f32_exp2(src[511..480]) @ __f32_exp2(src[479..448]) @
  __f32_exp2(src[447..416]) @ __f32_exp2(src[415..384]) @
  __f32_exp2(src[383..352]) @ __f32_exp2(src[351..320]) @
  __f32_exp2(src[319..288]) @ __f32_exp2(src[287..256]) @
  __f32_exp2(src[255..224]) @ __f32_exp2(src[223..192]) @
  __f32_exp2(src[191..160]) @ __f32_exp2(src[159..128]) @
  __f32_exp2(src[127..96])  @ __f32_exp2(src[95..64])   @
  __f32_exp2(src[63..32])   @ __f32_exp2(src[31..0])
}

val avx_vexp2pd_512 : zmmword -> zmmword
function avx_vexp2pd_512(src) = {
  __f64_exp2(src[511..448]) @ __f64_exp2(src[447..384]) @
  __f64_exp2(src[383..320]) @ __f64_exp2(src[319..256]) @
  __f64_exp2(src[255..192]) @ __f64_exp2(src[191..128]) @
  __f64_exp2(src[127..64])  @ __f64_exp2(src[63..0])
}

// =========================================================================
// VRCP28PS/PD/SS/SD — Approximate Reciprocal (28 bits, AVX-512ER / KNL)
// =========================================================================

val avx_vrcp28ps_512 : zmmword -> zmmword
function avx_vrcp28ps_512(src) = {
  __f32_rcp28(src[511..480]) @ __f32_rcp28(src[479..448]) @
  __f32_rcp28(src[447..416]) @ __f32_rcp28(src[415..384]) @
  __f32_rcp28(src[383..352]) @ __f32_rcp28(src[351..320]) @
  __f32_rcp28(src[319..288]) @ __f32_rcp28(src[287..256]) @
  __f32_rcp28(src[255..224]) @ __f32_rcp28(src[223..192]) @
  __f32_rcp28(src[191..160]) @ __f32_rcp28(src[159..128]) @
  __f32_rcp28(src[127..96])  @ __f32_rcp28(src[95..64])   @
  __f32_rcp28(src[63..32])   @ __f32_rcp28(src[31..0])
}

val avx_vrcp28pd_512 : zmmword -> zmmword
function avx_vrcp28pd_512(src) = {
  __f64_rcp28(src[511..448]) @ __f64_rcp28(src[447..384]) @
  __f64_rcp28(src[383..320]) @ __f64_rcp28(src[319..256]) @
  __f64_rcp28(src[255..192]) @ __f64_rcp28(src[191..128]) @
  __f64_rcp28(src[127..64])  @ __f64_rcp28(src[63..0])
}

// =========================================================================
// VRSQRT28PS/PD/SS/SD — Approximate Reciprocal Square Root (28 bits, AVX-512ER / KNL)
// =========================================================================

val avx_vrsqrt28ps_512 : zmmword -> zmmword
function avx_vrsqrt28ps_512(src) = {
  __f32_rsqrt28(src[511..480]) @ __f32_rsqrt28(src[479..448]) @
  __f32_rsqrt28(src[447..416]) @ __f32_rsqrt28(src[415..384]) @
  __f32_rsqrt28(src[383..352]) @ __f32_rsqrt28(src[351..320]) @
  __f32_rsqrt28(src[319..288]) @ __f32_rsqrt28(src[287..256]) @
  __f32_rsqrt28(src[255..224]) @ __f32_rsqrt28(src[223..192]) @
  __f32_rsqrt28(src[191..160]) @ __f32_rsqrt28(src[159..128]) @
  __f32_rsqrt28(src[127..96])  @ __f32_rsqrt28(src[95..64])   @
  __f32_rsqrt28(src[63..32])   @ __f32_rsqrt28(src[31..0])
}

val avx_vrsqrt28pd_512 : zmmword -> zmmword
function avx_vrsqrt28pd_512(src) = {
  __f64_rsqrt28(src[511..448]) @ __f64_rsqrt28(src[447..384]) @
  __f64_rsqrt28(src[383..320]) @ __f64_rsqrt28(src[319..256]) @
  __f64_rsqrt28(src[255..192]) @ __f64_rsqrt28(src[191..128]) @
  __f64_rsqrt28(src[127..64])  @ __f64_rsqrt28(src[63..0])
}

// VGETEXPPD — Convert Exponents of Packed Float64 Values to Float64 Values (AVX-512)
// VGETEXPPS — Convert Exponents of Packed Float32 Values to Float32 Values (AVX-512)
// VGETEXPSD — Convert Exponent of Scalar Float64 Value to Float64 Value (AVX-512)
// VGETEXPSS — Convert Exponent of Scalar Float32 Value to Float32 Value (AVX-512)
//
// These instructions convert the biased exponent of each FP element to an
// FP value representing the unbiased integer exponent.

// =========================================================================
// Packed PS (float32) helpers: 128 -> 256 -> 512
// =========================================================================

val vgetexpps_xmm : xmmword -> xmmword
function vgetexpps_xmm(a) =
  __f32_getexp(a[127..96]) @ __f32_getexp(a[95..64]) @
  __f32_getexp(a[63..32])  @ __f32_getexp(a[31..0])

val vgetexpps_ymm : ymmword -> ymmword
function vgetexpps_ymm(a) =
  vgetexpps_xmm(a[255..128]) @ vgetexpps_xmm(a[127..0])

val vgetexpps_zmm : zmmword -> zmmword
function vgetexpps_zmm(a) =
  vgetexpps_ymm(a[511..256]) @ vgetexpps_ymm(a[255..0])

// =========================================================================
// Packed PD (float64) helpers: 128 -> 256 -> 512
// =========================================================================

val vgetexppd_xmm : xmmword -> xmmword
function vgetexppd_xmm(a) =
  __f64_getexp(a[127..64]) @ __f64_getexp(a[63..0])

val vgetexppd_ymm : ymmword -> ymmword
function vgetexppd_ymm(a) =
  vgetexppd_xmm(a[255..128]) @ vgetexppd_xmm(a[127..0])

val vgetexppd_zmm : zmmword -> zmmword
function vgetexppd_zmm(a) =
  vgetexppd_ymm(a[511..256]) @ vgetexppd_ymm(a[255..0])

// VRCP14PD — Compute Approximate Reciprocals of Packed Float64 Values (AVX-512)
// VRCP14PS — Compute Approximate Reciprocals of Packed Float32 Values (AVX-512)
// VRCP14SD — Compute Approximate Reciprocal of Scalar Float64 Value (AVX-512)
// VRCP14SS — Compute Approximate Reciprocal of Scalar Float32 Value (AVX-512)
//
// These instructions compute approximate reciprocals with a relative error
// bound of 2^-14.

// =========================================================================
// Packed PS (float32) helpers: 128 -> 256 -> 512
// =========================================================================

val vrcp14ps_xmm : xmmword -> xmmword
function vrcp14ps_xmm(a) =
  __f32_rcp14(a[127..96]) @ __f32_rcp14(a[95..64]) @
  __f32_rcp14(a[63..32])  @ __f32_rcp14(a[31..0])

val vrcp14ps_ymm : ymmword -> ymmword
function vrcp14ps_ymm(a) =
  vrcp14ps_xmm(a[255..128]) @ vrcp14ps_xmm(a[127..0])

val vrcp14ps_zmm : zmmword -> zmmword
function vrcp14ps_zmm(a) =
  vrcp14ps_ymm(a[511..256]) @ vrcp14ps_ymm(a[255..0])

// =========================================================================
// Packed PD (float64) helpers: 128 -> 256 -> 512
// =========================================================================

val vrcp14pd_xmm : xmmword -> xmmword
function vrcp14pd_xmm(a) =
  __f64_rcp14(a[127..64]) @ __f64_rcp14(a[63..0])

val vrcp14pd_ymm : ymmword -> ymmword
function vrcp14pd_ymm(a) =
  vrcp14pd_xmm(a[255..128]) @ vrcp14pd_xmm(a[127..0])

val vrcp14pd_zmm : zmmword -> zmmword
function vrcp14pd_zmm(a) =
  vrcp14pd_ymm(a[511..256]) @ vrcp14pd_ymm(a[255..0])

// =========================================================================
// VRCP28 / VRCPPH / VRCPSH stubs (external, no YMM/ZMM infrastructure yet)
// =========================================================================

val __vrcp28pd : unit -> ExecutionResult
val exec_vrcp28pd : unit -> ExecutionResult
function exec_vrcp28pd() = __vrcp28pd()

val __vrcp28ps : unit -> ExecutionResult
val exec_vrcp28ps : unit -> ExecutionResult
function exec_vrcp28ps() = __vrcp28ps()

val __vrcp28sd : unit -> ExecutionResult
val exec_vrcp28sd : unit -> ExecutionResult
function exec_vrcp28sd() = __vrcp28sd()

val __vrcp28ss : unit -> ExecutionResult
val exec_vrcp28ss : unit -> ExecutionResult
function exec_vrcp28ss() = __vrcp28ss()

val __vrcpph : unit -> ExecutionResult
val exec_vrcpph : unit -> ExecutionResult
function exec_vrcpph() = __vrcpph()

val __vrcpsh : unit -> ExecutionResult
val exec_vrcpsh : unit -> ExecutionResult
function exec_vrcpsh() = __vrcpsh()

// VRSQRT14PD — Compute Approximate Reciprocal of Square Roots of Packed Float64 (AVX-512)
// VRSQRT14PS — Compute Approximate Reciprocal of Square Roots of Packed Float32 (AVX-512)
// VRSQRT14SD — Compute Approximate Reciprocal of Square Root of Scalar Float64 (AVX-512)
// VRSQRT14SS — Compute Approximate Reciprocal of Square Root of Scalar Float32 (AVX-512)
//
// These instructions compute approximate reciprocal square roots with a
// relative error bound of 2^-14.

// =========================================================================
// Packed PS (float32) helpers: 128 -> 256 -> 512
// =========================================================================

val vrsqrt14ps_xmm : xmmword -> xmmword
function vrsqrt14ps_xmm(a) =
  __f32_rsqrt14(a[127..96]) @ __f32_rsqrt14(a[95..64]) @
  __f32_rsqrt14(a[63..32])  @ __f32_rsqrt14(a[31..0])

val vrsqrt14ps_ymm : ymmword -> ymmword
function vrsqrt14ps_ymm(a) =
  vrsqrt14ps_xmm(a[255..128]) @ vrsqrt14ps_xmm(a[127..0])

val vrsqrt14ps_zmm : zmmword -> zmmword
function vrsqrt14ps_zmm(a) =
  vrsqrt14ps_ymm(a[511..256]) @ vrsqrt14ps_ymm(a[255..0])

// =========================================================================
// Packed PD (float64) helpers: 128 -> 256 -> 512
// =========================================================================

val vrsqrt14pd_xmm : xmmword -> xmmword
function vrsqrt14pd_xmm(a) =
  __f64_rsqrt14(a[127..64]) @ __f64_rsqrt14(a[63..0])

val vrsqrt14pd_ymm : ymmword -> ymmword
function vrsqrt14pd_ymm(a) =
  vrsqrt14pd_xmm(a[255..128]) @ vrsqrt14pd_xmm(a[127..0])

val vrsqrt14pd_zmm : zmmword -> zmmword
function vrsqrt14pd_zmm(a) =
  vrsqrt14pd_ymm(a[511..256]) @ vrsqrt14pd_ymm(a[255..0])

// =========================================================================
// VRSQRT28 / VRSQRTPH / VRSQRTSH stubs (external, no YMM/ZMM infrastructure yet)
// =========================================================================

val __vrsqrt28pd : unit -> ExecutionResult
val exec_vrsqrt28pd : unit -> ExecutionResult
function exec_vrsqrt28pd() = __vrsqrt28pd()

val __vrsqrt28ps : unit -> ExecutionResult
val exec_vrsqrt28ps : unit -> ExecutionResult
function exec_vrsqrt28ps() = __vrsqrt28ps()

val __vrsqrt28sd : unit -> ExecutionResult
val exec_vrsqrt28sd : unit -> ExecutionResult
function exec_vrsqrt28sd() = __vrsqrt28sd()

val __vrsqrt28ss : unit -> ExecutionResult
val exec_vrsqrt28ss : unit -> ExecutionResult
function exec_vrsqrt28ss() = __vrsqrt28ss()

val __vrsqrtph : unit -> ExecutionResult
val exec_vrsqrtph : unit -> ExecutionResult
function exec_vrsqrtph() = __vrsqrtph()

val __vrsqrtsh : unit -> ExecutionResult
val exec_vrsqrtsh : unit -> ExecutionResult
function exec_vrsqrtsh() = __vrsqrtsh()

// VSCALEFPD — Scale Packed Float64 Values With Float64 Values (AVX-512)
// VSCALEFPS — Scale Packed Float32 Values With Float32 Values (AVX-512)
// VSCALEFSD — Scale Scalar Float64 Value With Float64 Value (AVX-512)
// VSCALEFSS — Scale Scalar Float32 Value With Float32 Value (AVX-512)
//
// These instructions scale floating-point values by powers of two:
// DEST = SRC1 * 2^floor(SRC2).

// =========================================================================
// Packed PS (float32) helpers: 128 -> 256 -> 512
// =========================================================================

val vscalefps_xmm : (xmmword, xmmword) -> xmmword
function vscalefps_xmm(a, b) =
  __f32_scalef(a[127..96], b[127..96]) @
  __f32_scalef(a[95..64],  b[95..64])  @
  __f32_scalef(a[63..32],  b[63..32])  @
  __f32_scalef(a[31..0],   b[31..0])

val vscalefps_ymm : (ymmword, ymmword) -> ymmword
function vscalefps_ymm(a, b) =
  vscalefps_xmm(a[255..128], b[255..128]) @ vscalefps_xmm(a[127..0], b[127..0])

val vscalefps_zmm : (zmmword, zmmword) -> zmmword
function vscalefps_zmm(a, b) =
  vscalefps_ymm(a[511..256], b[511..256]) @ vscalefps_ymm(a[255..0], b[255..0])

// =========================================================================
// Packed PD (float64) helpers: 128 -> 256 -> 512
// =========================================================================

val vscalefpd_xmm : (xmmword, xmmword) -> xmmword
function vscalefpd_xmm(a, b) =
  __f64_scalef(a[127..64], b[127..64]) @ __f64_scalef(a[63..0], b[63..0])

val vscalefpd_ymm : (ymmword, ymmword) -> ymmword
function vscalefpd_ymm(a, b) =
  vscalefpd_xmm(a[255..128], b[255..128]) @ vscalefpd_xmm(a[127..0], b[127..0])

val vscalefpd_zmm : (zmmword, zmmword) -> zmmword
function vscalefpd_zmm(a, b) =
  vscalefpd_ymm(a[511..256], b[511..256]) @ vscalefpd_ymm(a[255..0], b[255..0])

// VPMASKMOV — Conditional SIMD Integer Packed Loads and Stores (AVX2)
//
// Conditionally loads/stores packed dword/qword values using a mask register.
// Modeled as external function (no YMM/ZMM infrastructure).

val __vpmaskmov : unit -> ExecutionResult
val exec_vpmaskmov : unit -> ExecutionResult
function exec_vpmaskmov() = __vpmaskmov()

// VPMOVB2M, VPMOVW2M, VPMOVD2M, VPMOVQ2M — Convert Packed Integers to Mask
// VPMOVM2B, VPMOVM2W, VPMOVM2D, VPMOVM2Q — Convert Mask to Packed Integers
//
// Fully implemented inline in decode_evex.sail using helpers from avx512_int.sail:
//   avx_vpmovb2m_{128,256,512}, avx_vpmovw2m_{128,256,512},
//   avx_vpmovd2m_{128,256,512}, avx_vpmovq2m_{128,256,512},
//   avx_vpmovm2b_{128,256,512}, avx_vpmovm2w_{128,256,512},
//   avx_vpmovm2d_{128,256,512}, avx_vpmovm2q_{128,256,512}

// VPMOVWB, VPMOVDB, VPMOVQB, VPMOVDW, VPMOVQW, VPMOVQD — Narrowing Truncation
// VPMOVSWB, VPMOVSDB, VPMOVSQB, VPMOVSDW, VPMOVSQW, VPMOVSQD — Signed Saturation
// VPMOVUSWB, VPMOVUSDB, VPMOVUSQB, VPMOVUSDW, VPMOVUSQW, VPMOVUSQD — Unsigned Saturation
//
// All 18 narrowing down-convert instructions are fully implemented inline in
// decode_evex.sail using helpers from avx512_int.sail:
//   avx_pmovwb_{128,256,512}, avx_pmovdb_{128,256,512}, avx_pmovqb_{128,256,512},
//   avx_pmovdw_{128,256,512}, avx_pmovqw_{128,256,512}, avx_pmovqd_{128,256,512},
//   avx_pmovswb_{128,256,512}, avx_pmovsdb_{128,256,512}, avx_pmovsqb_{128,256,512},
//   avx_pmovsdw_{128,256,512}, avx_pmovsqw_{128,256,512}, avx_pmovsqd_{128,256,512},
//   avx_pmovuswb_{128,256,512}, avx_pmovusdb_{128,256,512}, avx_pmovusqb_{128,256,512},
//   avx_pmovusdw_{128,256,512}, avx_pmovusqw_{128,256,512}, avx_pmovusqd_{128,256,512}

// VPMULTISHIFTQB — Select Packed Unaligned Bytes from Quadword Sources (AVX-512 VBMI)
//
// For each byte in the destination, a shift amount from the source selects
// 8 contiguous bits from the corresponding quadword of the other source.

val __vpmultishiftqb : unit -> ExecutionResult
val exec_vpmultishiftqb : unit -> ExecutionResult
function exec_vpmultishiftqb() = __vpmultishiftqb()

// VPOPCNT — Packed Population Count (AVX-512 VPOPCNTDQ / AVX-512 BITALG)
//
// Counts the number of set bits in each byte, word, doubleword, or quadword element.

val __vpopcnt : unit -> ExecutionResult
val exec_vpopcnt : unit -> ExecutionResult
function exec_vpopcnt() = __vpopcnt()

// =========================================================================
// Scalar FMA helpers for EVEX-encoded instructions
// 132: dest = fma(dest, src3, src2)
// 213: dest = fma(src2, dest, src3)  
// 231: dest = fma(src2, src3, dest)
// =========================================================================

val exec_vfmadd132ss : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfmadd132ss(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..32] @ __f32_fmadd(d[31..0], src3[31..0], src2[31..0])); Ok(())
}
val exec_vfmadd132sd : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfmadd132sd(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..64] @ __f64_fmadd(d[63..0], src3[63..0], src2[63..0])); Ok(())
}
val exec_vfmsub132ss : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfmsub132ss(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..32] @ __f32_fmsub(d[31..0], src3[31..0], src2[31..0])); Ok(())
}
val exec_vfmsub132sd : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfmsub132sd(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..64] @ __f64_fmsub(d[63..0], src3[63..0], src2[63..0])); Ok(())
}
val exec_vfnmadd132ss : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfnmadd132ss(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..32] @ __f32_fnmadd(d[31..0], src3[31..0], src2[31..0])); Ok(())
}
val exec_vfnmadd132sd : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfnmadd132sd(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..64] @ __f64_fnmadd(d[63..0], src3[63..0], src2[63..0])); Ok(())
}
val exec_vfnmsub132ss : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfnmsub132ss(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..32] @ __f32_fnmsub(d[31..0], src3[31..0], src2[31..0])); Ok(())
}
val exec_vfnmsub132sd : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfnmsub132sd(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..64] @ __f64_fnmsub(d[63..0], src3[63..0], src2[63..0])); Ok(())
}

val exec_vfmadd213ss : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfmadd213ss(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..32] @ __f32_fmadd(src2[31..0], d[31..0], src3[31..0])); Ok(())
}
val exec_vfmadd213sd : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfmadd213sd(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..64] @ __f64_fmadd(src2[63..0], d[63..0], src3[63..0])); Ok(())
}
val exec_vfmsub213ss : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfmsub213ss(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..32] @ __f32_fmsub(src2[31..0], d[31..0], src3[31..0])); Ok(())
}
val exec_vfmsub213sd : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfmsub213sd(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..64] @ __f64_fmsub(src2[63..0], d[63..0], src3[63..0])); Ok(())
}
val exec_vfnmadd213ss : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfnmadd213ss(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..32] @ __f32_fnmadd(src2[31..0], d[31..0], src3[31..0])); Ok(())
}
val exec_vfnmadd213sd : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfnmadd213sd(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..64] @ __f64_fnmadd(src2[63..0], d[63..0], src3[63..0])); Ok(())
}
val exec_vfnmsub213ss : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfnmsub213ss(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..32] @ __f32_fnmsub(src2[31..0], d[31..0], src3[31..0])); Ok(())
}
val exec_vfnmsub213sd : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfnmsub213sd(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..64] @ __f64_fnmsub(src2[63..0], d[63..0], src3[63..0])); Ok(())
}

val exec_vfmadd231ss : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfmadd231ss(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..32] @ __f32_fmadd(src2[31..0], src3[31..0], d[31..0])); Ok(())
}
val exec_vfmadd231sd : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfmadd231sd(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..64] @ __f64_fmadd(src2[63..0], src3[63..0], d[63..0])); Ok(())
}
val exec_vfmsub231ss : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfmsub231ss(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..32] @ __f32_fmsub(src2[31..0], src3[31..0], d[31..0])); Ok(())
}
val exec_vfmsub231sd : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfmsub231sd(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..64] @ __f64_fmsub(src2[63..0], src3[63..0], d[63..0])); Ok(())
}
val exec_vfnmadd231ss : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfnmadd231ss(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..32] @ __f32_fnmadd(src2[31..0], src3[31..0], d[31..0])); Ok(())
}
val exec_vfnmadd231sd : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfnmadd231sd(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..64] @ __f64_fnmadd(src2[63..0], src3[63..0], d[63..0])); Ok(())
}
val exec_vfnmsub231ss : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfnmsub231ss(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..32] @ __f32_fnmsub(src2[31..0], src3[31..0], d[31..0])); Ok(())
}
val exec_vfnmsub231sd : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfnmsub231sd(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..64] @ __f64_fnmsub(src2[63..0], src3[63..0], d[63..0])); Ok(())
}

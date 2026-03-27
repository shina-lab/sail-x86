// x86-64 — EVEX Permute/Shuffle/Compress (0F38 map)
//
// VBROADCAST, VPERM, VPSHUF, VCOMPRESS, VEXPAND.
// Called from dispatch_evex_0f38 in insn_evex.sail.

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

val avx_pshufb_128 : (xmmword, xmmword) -> xmmword
function avx_pshufb_128(src, ctrl) = {
  var r : xmmword = zeros();
  foreach (j from 0 to 15) {
    let jj : range(0, 120) = j * 8;
    let c : byte = ctrl[(jj + 7)..jj];
    r[(jj + 7)..jj] = pshufb_byte(src, c)
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
  let lo : bits(64) = blend(src[63..0], src[127..64], ctrl[1]);
  let hi : bits(64) = blend(src[63..0], src[127..64], ctrl[65]);
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

val avx_vperm2_d_128 : (xmmword, xmmword, xmmword) -> xmmword
function avx_vperm2_d_128(t1, t2, idx) = {
  let combined : bits(256) = t2 @ t1;
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    let id : range(0, 7) = unsigned(idx[(lo + 2)..lo]);
    r[(lo + 31)..lo] = combined[(id * 32 + 31) .. (id * 32)];
  };
  r
}

val avx_vperm2_d_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_vperm2_d_256(t1, t2, idx) = {
  let combined : zmmword = t2 @ t1;
  var r : ymmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 224) = i * 32;
    let id : range(0, 15) = unsigned(idx[(lo + 3)..lo]);
    r[(lo + 31)..lo] = combined[(id * 32 + 31) .. (id * 32)];
  };
  r
}

val avx_vperm2_d_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_vperm2_d_512(t1, t2, idx) = {
  let combined : bits(1024) = t2 @ t1;
  var r : zmmword = zeros();
  foreach (i from 0 to 15) {
    let lo : range(0, 480) = i * 32;
    let id : range(0, 31) = unsigned(idx[(lo + 4)..lo]);
    r[(lo + 31)..lo] = combined[(id * 32 + 31) .. (id * 32)];
  };
  r
}

val avx_vperm2_q_128 : (xmmword, xmmword, xmmword) -> xmmword
function avx_vperm2_q_128(t1, t2, idx) = {
  let combined : bits(256) = t2 @ t1;
  var r : xmmword = zeros();
  foreach (i from 0 to 1) {
    let lo : range(0, 64) = i * 64;
    let id : range(0, 3) = unsigned(idx[(lo + 1)..lo]);
    r[(lo + 63)..lo] = combined[(id * 64 + 63) .. (id * 64)];
  };
  r
}

val avx_vperm2_q_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_vperm2_q_256(t1, t2, idx) = {
  let combined : zmmword = t2 @ t1;
  var r : ymmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 192) = i * 64;
    let id : range(0, 7) = unsigned(idx[(lo + 2)..lo]);
    r[(lo + 63)..lo] = combined[(id * 64 + 63) .. (id * 64)];
  };
  r
}

val avx_vperm2_q_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_vperm2_q_512(t1, t2, idx) = {
  let combined : bits(1024) = t2 @ t1;
  var r : zmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 448) = i * 64;
    let id : range(0, 15) = unsigned(idx[(lo + 3)..lo]);
    r[(lo + 63)..lo] = combined[(id * 64 + 63) .. (id * 64)];
  };
  r
}

/* ---- Packed FMA helpers ---- */

val avx_vperm2_w_128 : (xmmword, xmmword, xmmword) -> xmmword
function avx_vperm2_w_128(t1, t2, idx) = {
  let combined : bits(256) = t2 @ t1;
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    let id : range(0, 15) = unsigned(idx[(lo + 3)..lo]);
    r[(lo + 15)..lo] = combined[(id * 16 + 15) .. (id * 16)];
  };
  r
}

val avx_vperm2_w_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_vperm2_w_256(t1, t2, idx) = {
  let combined : zmmword = t2 @ t1;
  var r : ymmword = zeros();
  foreach (i from 0 to 15) {
    let lo : range(0, 240) = i * 16;
    let id : range(0, 31) = unsigned(idx[(lo + 4)..lo]);
    r[(lo + 15)..lo] = combined[(id * 16 + 15) .. (id * 16)];
  };
  r
}

val avx_vperm2_w_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_vperm2_w_512(t1, t2, idx) = {
  let combined : bits(1024) = t2 @ t1;
  var r : zmmword = zeros();
  foreach (i from 0 to 31) {
    let lo : range(0, 496) = i * 16;
    let id : range(0, 63) = unsigned(idx[(lo + 5)..lo]);
    r[(lo + 15)..lo] = combined[(id * 16 + 15) .. (id * 16)];
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
  let combined : bits(256) = t2 @ t1;
  var r : xmmword = zeros();
  foreach (i from 0 to 15) {
    let lo : range(0, 120) = i * 8;
    let id : range(0, 31) = unsigned(idx[(lo + 4)..lo]);
    r[(lo + 7)..lo] = combined[(id * 8 + 7) .. (id * 8)];
  };
  r
}

val avx_vperm2_b_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_vperm2_b_256(t1, t2, idx) = {
  let combined : zmmword = t2 @ t1;
  var r : ymmword = zeros();
  foreach (i from 0 to 31) {
    let lo : range(0, 248) = i * 8;
    let id : range(0, 63) = unsigned(idx[(lo + 5)..lo]);
    r[(lo + 7)..lo] = combined[(id * 8 + 7) .. (id * 8)];
  };
  r
}

val avx_vperm2_b_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_vperm2_b_512(t1, t2, idx) = {
  let combined : bits(1024) = t2 @ t1;
  var r : zmmword = zeros();
  foreach (i from 0 to 63) {
    let lo : range(0, 504) = i * 8;
    let id : range(0, 127) = unsigned(idx[(lo + 6)..lo]);
    r[(lo + 7)..lo] = combined[(id * 8 + 7) .. (id * 8)];
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

val popcount_mask : forall 'n, 0 < 'n & 'n <= 64. (bits('n), int) -> int
function popcount_mask(v, upto) = {
  assert(upto >= 0);
  let w : qword = zero_extend(v);
  popcount(w & ((0x0000000000000001 << upto) - 1))
}

// For expand/compress, we use a simpler strategy: iterate and use get_slice/set_slice
// with computed bit offsets, working element-by-element.

val avx_vexpandps_128 : (xmmword, byte) -> xmmword
function avx_vexpandps_128(src, mask) = {
  var result : xmmword = zeros();
  foreach (i from 0 to 3) {
    let j = popcount_mask(mask, i);
    assert(j >= 0);
    let dst_lo : range(0, 96) = i * 32;
    let src_elem : dword = get_slice_int(32, unsigned(src), j * 32);
    let lane_mask : dword = sign_extend(mask[i..i]);
    result[(dst_lo + 31)..dst_lo] = src_elem & lane_mask;
  };
  result
}

val avx_vexpandps_256 : (ymmword, byte) -> ymmword
function avx_vexpandps_256(src, mask) = {
  var result : ymmword = zeros();
  foreach (i from 0 to 7) {
    let j = popcount_mask(mask, i);
    assert(j >= 0);
    let dst_lo : range(0, 224) = i * 32;
    let src_elem : dword = get_slice_int(32, unsigned(src), j * 32);
    let lane_mask : dword = sign_extend(mask[i..i]);
    result[(dst_lo + 31)..dst_lo] = src_elem & lane_mask;
  };
  result
}

val avx_vexpandps_512 : (zmmword, word) -> zmmword
function avx_vexpandps_512(src, mask) = {
  var result : zmmword = zeros();
  foreach (i from 0 to 15) {
    let j = popcount_mask(mask, i);
    assert(j >= 0);
    let dst_lo : range(0, 480) = i * 32;
    let src_elem : dword = get_slice_int(32, unsigned(src), j * 32);
    let lane_mask : dword = sign_extend(mask[i..i]);
    result[(dst_lo + 31)..dst_lo] = src_elem & lane_mask;
  };
  result
}

val avx_vexpandpd_128 : (xmmword, byte) -> xmmword
function avx_vexpandpd_128(src, mask) = {
  var result : xmmword = zeros();
  foreach (i from 0 to 1) {
    let j = popcount_mask(mask, i);
    assert(j >= 0);
    let dst_lo : range(0, 64) = i * 64;
    let src_elem : qword = get_slice_int(64, unsigned(src), j * 64);
    let lane_mask : qword = sign_extend(mask[i..i]);
    result[(dst_lo + 63)..dst_lo] = src_elem & lane_mask;
  };
  result
}

val avx_vexpandpd_256 : (ymmword, byte) -> ymmword
function avx_vexpandpd_256(src, mask) = {
  var result : ymmword = zeros();
  foreach (i from 0 to 3) {
    let j = popcount_mask(mask, i);
    assert(j >= 0);
    let dst_lo : range(0, 192) = i * 64;
    let src_elem : qword = get_slice_int(64, unsigned(src), j * 64);
    let lane_mask : qword = sign_extend(mask[i..i]);
    result[(dst_lo + 63)..dst_lo] = src_elem & lane_mask;
  };
  result
}

val avx_vexpandpd_512 : (zmmword, byte) -> zmmword
function avx_vexpandpd_512(src, mask) = {
  var result : zmmword = zeros();
  foreach (i from 0 to 7) {
    let j = popcount_mask(mask, i);
    assert(j >= 0);
    let dst_lo : range(0, 448) = i * 64;
    let src_elem : qword = get_slice_int(64, unsigned(src), j * 64);
    let lane_mask : qword = sign_extend(mask[i..i]);
    result[(dst_lo + 63)..dst_lo] = src_elem & lane_mask;
  };
  result
}

/* ---- VCOMPRESSPS/PD: compress from masked positions to contiguous ---- */

val avx_vcompressps_128 : (xmmword, byte) -> xmmword
function avx_vcompressps_128(src, mask) = {
  var result : xmmword = zeros();
  foreach (i from 0 to 3) {
    let j = popcount_mask(mask, i);
    assert(j >= 0);
    let src_lo : range(0, 96) = i * 32;
    let src_elem : dword = src[(src_lo + 31)..src_lo];
    let lane_mask : dword = sign_extend(mask[i..i]);
    result = result | (zero_extend(src_elem & lane_mask) << (j * 32));
  };
  result
}

val avx_vcompressps_256 : (ymmword, byte) -> ymmword
function avx_vcompressps_256(src, mask) = {
  var result : ymmword = zeros();
  foreach (i from 0 to 7) {
    let j = popcount_mask(mask, i);
    assert(j >= 0);
    let src_lo : range(0, 224) = i * 32;
    let src_elem : dword = src[(src_lo + 31)..src_lo];
    let lane_mask : dword = sign_extend(mask[i..i]);
    result = result | (zero_extend(src_elem & lane_mask) << (j * 32));
  };
  result
}

val avx_vcompressps_512 : (zmmword, word) -> zmmword
function avx_vcompressps_512(src, mask) = {
  var result : zmmword = zeros();
  foreach (i from 0 to 15) {
    let j = popcount_mask(mask, i);
    assert(j >= 0);
    let src_lo : range(0, 480) = i * 32;
    let src_elem : dword = src[(src_lo + 31)..src_lo];
    let lane_mask : dword = sign_extend(mask[i..i]);
    result = result | (zero_extend(src_elem & lane_mask) << (j * 32));
  };
  result
}

val avx_vcompresspd_128 : (xmmword, byte) -> xmmword
function avx_vcompresspd_128(src, mask) = {
  var result : xmmword = zeros();
  foreach (i from 0 to 1) {
    let j = popcount_mask(mask, i);
    assert(j >= 0);
    let src_lo : range(0, 64) = i * 64;
    let src_elem : qword = src[(src_lo + 63)..src_lo];
    let lane_mask : qword = sign_extend(mask[i..i]);
    result = result | (zero_extend(src_elem & lane_mask) << (j * 64));
  };
  result
}

val avx_vcompresspd_256 : (ymmword, byte) -> ymmword
function avx_vcompresspd_256(src, mask) = {
  var result : ymmword = zeros();
  foreach (i from 0 to 3) {
    let j = popcount_mask(mask, i);
    assert(j >= 0);
    let src_lo : range(0, 192) = i * 64;
    let src_elem : qword = src[(src_lo + 63)..src_lo];
    let lane_mask : qword = sign_extend(mask[i..i]);
    result = result | (zero_extend(src_elem & lane_mask) << (j * 64));
  };
  result
}

val avx_vcompresspd_512 : (zmmword, byte) -> zmmword
function avx_vcompresspd_512(src, mask) = {
  var result : zmmword = zeros();
  foreach (i from 0 to 7) {
    let j = popcount_mask(mask, i);
    assert(j >= 0);
    let src_lo : range(0, 448) = i * 64;
    let src_elem : qword = src[(src_lo + 63)..src_lo];
    let lane_mask : qword = sign_extend(mask[i..i]);
    result = result | (zero_extend(src_elem & lane_mask) << (j * 64));
  };
  result
}

// VPEXPANDD/Q and VPCOMPRESSD/Q use the same logic as the FP variants
// (dword elements = same as PS, qword elements = same as PD)

// Memory store forms: write only the compressed (contiguous) elements.
// We extract dword/qword elements by shifting right and truncating.
val avx_vcompress_dword_mem_512 : (qword, zmmword, word) -> unit
function avx_vcompress_dword_mem_512(addr, src, mask) = {
  foreach (i from 0 to 15) {
    if mask[i] == 0b1 then {
      let off = popcount(mask & ~(0xFFFF << i)) * 4;
      let elem : dword = truncate(src >> (i * 32), 32);
      write_mem(addr + off, elem);
    };
  };
}

val avx_vcompress_dword_mem_256 : (qword, ymmword, byte) -> unit
function avx_vcompress_dword_mem_256(addr, src, mask) = {
  foreach (i from 0 to 7) {
    if mask[i] == 0b1 then {
      let off = popcount(mask & ~(0xFF << i)) * 4;
      let elem : dword = truncate(src >> (i * 32), 32);
      write_mem(addr + off, elem);
    };
  };
}

val avx_vcompress_dword_mem_128 : (qword, xmmword, byte) -> unit
function avx_vcompress_dword_mem_128(addr, src, mask) = {
  foreach (i from 0 to 3) {
    if mask[i] == 0b1 then {
      let off = popcount(mask & ~(0xFF << i)) * 4;
      let elem : dword = truncate(src >> (i * 32), 32);
      write_mem(addr + off, elem);
    };
  };
}

val avx_vcompress_qword_mem_512 : (qword, zmmword, byte) -> unit
function avx_vcompress_qword_mem_512(addr, src, mask) = {
  foreach (i from 0 to 7) {
    if mask[i] == 0b1 then {
      let off = popcount(mask & ~(0xFF << i)) * 8;
      let elem : qword = truncate(src >> (i * 64), 64);
      write_mem(addr + off, elem);
    };
  };
}

val avx_vcompress_qword_mem_256 : (qword, ymmword, byte) -> unit
function avx_vcompress_qword_mem_256(addr, src, mask) = {
  foreach (i from 0 to 3) {
    if mask[i] == 0b1 then {
      let off = popcount(mask & ~(0xFF << i)) * 8;
      let elem : qword = truncate(src >> (i * 64), 64);
      write_mem(addr + off, elem);
    };
  };
}

val avx_vcompress_qword_mem_128 : (qword, xmmword, byte) -> unit
function avx_vcompress_qword_mem_128(addr, src, mask) = {
  foreach (i from 0 to 1) {
    if mask[i] == 0b1 then {
      let off = popcount(mask & ~(0xFF << i)) * 8;
      let elem : qword = truncate(src >> (i * 64), 64);
      write_mem(addr + off, elem);
    };
  };
}

/* ---- VRNDSCALE: round to specified precision ---- */

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

/* ---- VPDPBUSD: Multiply and Add Unsigned and Signed Bytes ---- */
// For each dword position:
//   temp = src1.u8[0]*src2.s8[0] + src1.u8[1]*src2.s8[1] + src1.u8[2]*src2.s8[2] + src1.u8[3]*src2.s8[3]
//   dst.dword += temp

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

/* ---- VPCOMPRESSB/W: compress byte/word elements ---- */

// VPCOMPRESSB register form helpers
val avx_vpcompressb_128 : (xmmword, word) -> xmmword
function avx_vpcompressb_128(src, mask) = {
  var result : xmmword = zeros();
  foreach (i from 0 to 15) {
    let j = popcount_mask(mask, i);
    assert(j >= 0);
    let src_elem : byte = truncate(src >> (i * 8), 8);
    let lane_mask : byte = sign_extend(mask[i..i]);
    result = result | (zero_extend(src_elem & lane_mask) << (j * 8));
  };
  result
}

val avx_vpcompressb_256 : (ymmword, dword) -> ymmword
function avx_vpcompressb_256(src, mask) = {
  var result : ymmword = zeros();
  foreach (i from 0 to 31) {
    let j = popcount_mask(mask, i);
    assert(j >= 0);
    let src_elem : byte = truncate(src >> (i * 8), 8);
    let lane_mask : byte = sign_extend(mask[i..i]);
    result = result | (zero_extend(src_elem & lane_mask) << (j * 8));
  };
  result
}

val avx_vpcompressb_512 : (zmmword, qword) -> zmmword
function avx_vpcompressb_512(src, mask) = {
  var result : zmmword = zeros();
  foreach (i from 0 to 63) {
    let j = popcount_mask(mask, i);
    assert(j >= 0);
    let src_elem : byte = truncate(src >> (i * 8), 8);
    let lane_mask : byte = sign_extend(mask[i..i]);
    result = result | (zero_extend(src_elem & lane_mask) << (j * 8));
  };
  result
}

// VPCOMPRESSW register form helpers
val avx_vpcompressw_128 : (xmmword, byte) -> xmmword
function avx_vpcompressw_128(src, mask) = {
  var result : xmmword = zeros();
  foreach (i from 0 to 7) {
    let j = popcount_mask(mask, i);
    assert(j >= 0);
    let src_elem : word = truncate(src >> (i * 16), 16);
    let lane_mask : word = sign_extend(mask[i..i]);
    result = result | (zero_extend(src_elem & lane_mask) << (j * 16));
  };
  result
}

val avx_vpcompressw_256 : (ymmword, word) -> ymmword
function avx_vpcompressw_256(src, mask) = {
  var result : ymmword = zeros();
  foreach (i from 0 to 15) {
    let j = popcount_mask(mask, i);
    assert(j >= 0);
    let src_elem : word = truncate(src >> (i * 16), 16);
    let lane_mask : word = sign_extend(mask[i..i]);
    result = result | (zero_extend(src_elem & lane_mask) << (j * 16));
  };
  result
}

val avx_vpcompressw_512 : (zmmword, dword) -> zmmword
function avx_vpcompressw_512(src, mask) = {
  var result : zmmword = zeros();
  foreach (i from 0 to 31) {
    let j = popcount_mask(mask, i);
    assert(j >= 0);
    let src_elem : word = truncate(src >> (i * 16), 16);
    let lane_mask : word = sign_extend(mask[i..i]);
    result = result | (zero_extend(src_elem & lane_mask) << (j * 16));
  };
  result
}

// VPCOMPRESSB memory store helpers
val avx_vpcompressb_mem_128 : (qword, xmmword, word) -> unit
function avx_vpcompressb_mem_128(addr, src, mask) = {
  foreach (i from 0 to 15) {
    if mask[i] == 0b1 then {
      let off = popcount(mask & ~(0xFFFF << i));
      let elem : byte = truncate(src >> (i * 8), 8);
      write_mem(addr + off, elem);
    };
  };
}

val avx_vpcompressb_mem_256 : (qword, ymmword, dword) -> unit
function avx_vpcompressb_mem_256(addr, src, mask) = {
  foreach (i from 0 to 31) {
    if mask[i] == 0b1 then {
      let off = popcount(mask & ~(0xFFFFFFFF << i));
      let elem : byte = truncate(src >> (i * 8), 8);
      write_mem(addr + off, elem);
    };
  };
}

val avx_vpcompressb_mem_512 : (qword, zmmword, qword) -> unit
function avx_vpcompressb_mem_512(addr, src, mask) = {
  foreach (i from 0 to 63) {
    if mask[i] == 0b1 then {
      let off = popcount(mask & ~(0xFFFFFFFFFFFFFFFF << i));
      let elem : byte = truncate(src >> (i * 8), 8);
      write_mem(addr + off, elem);
    };
  };
}

// VPCOMPRESSW memory store helpers
val avx_vpcompressw_mem_128 : (qword, xmmword, byte) -> unit
function avx_vpcompressw_mem_128(addr, src, mask) = {
  foreach (i from 0 to 7) {
    if mask[i] == 0b1 then {
      let off = popcount(mask & ~(0xFF << i)) * 2;
      let elem : word = truncate(src >> (i * 16), 16);
      write_mem(addr + off, elem);
    };
  };
}

val avx_vpcompressw_mem_256 : (qword, ymmword, word) -> unit
function avx_vpcompressw_mem_256(addr, src, mask) = {
  foreach (i from 0 to 15) {
    if mask[i] == 0b1 then {
      let off = popcount(mask & ~(0xFFFF << i)) * 2;
      let elem : word = truncate(src >> (i * 16), 16);
      write_mem(addr + off, elem);
    };
  };
}

val avx_vpcompressw_mem_512 : (qword, zmmword, dword) -> unit
function avx_vpcompressw_mem_512(addr, src, mask) = {
  foreach (i from 0 to 31) {
    if mask[i] == 0b1 then {
      let off = popcount(mask & ~(0xFFFFFFFF << i)) * 2;
      let elem : word = truncate(src >> (i * 16), 16);
      write_mem(addr + off, elem);
    };
  };
}

/* ---- VPEXPANDB/W: expand byte/word elements ---- */

val avx_vpexpandb_128 : (xmmword, word) -> xmmword
function avx_vpexpandb_128(src, mask) = {
  var result : xmmword = zeros();
  foreach (i from 0 to 15) {
    let j = popcount_mask(mask, i);
    assert(j >= 0);
    let src_elem : byte = get_slice_int(8, unsigned(src), j * 8);
    let lane_mask : byte = sign_extend(mask[i..i]);
    result[(i * 8 + 7)..(i * 8)] = src_elem & lane_mask;
  };
  result
}

val avx_vpexpandb_256 : (ymmword, dword) -> ymmword
function avx_vpexpandb_256(src, mask) = {
  var result : ymmword = zeros();
  foreach (i from 0 to 31) {
    let j = popcount_mask(mask, i);
    assert(j >= 0);
    let src_elem : byte = get_slice_int(8, unsigned(src), j * 8);
    let lane_mask : byte = sign_extend(mask[i..i]);
    result[(i * 8 + 7)..(i * 8)] = src_elem & lane_mask;
  };
  result
}

val avx_vpexpandb_512 : (zmmword, qword) -> zmmword
function avx_vpexpandb_512(src, mask) = {
  var result : zmmword = zeros();
  foreach (i from 0 to 63) {
    let j = popcount_mask(mask, i);
    assert(j >= 0);
    let src_elem : byte = get_slice_int(8, unsigned(src), j * 8);
    let lane_mask : byte = sign_extend(mask[i..i]);
    result[(i * 8 + 7)..(i * 8)] = src_elem & lane_mask;
  };
  result
}

val avx_vpexpandw_128 : (xmmword, byte) -> xmmword
function avx_vpexpandw_128(src, mask) = {
  var result : xmmword = zeros();
  foreach (i from 0 to 7) {
    let j = popcount_mask(mask, i);
    assert(j >= 0);
    let src_elem : word = get_slice_int(16, unsigned(src), j * 16);
    let lane_mask : word = sign_extend(mask[i..i]);
    result[(i * 16 + 15)..(i * 16)] = src_elem & lane_mask;
  };
  result
}

val avx_vpexpandw_256 : (ymmword, word) -> ymmword
function avx_vpexpandw_256(src, mask) = {
  var result : ymmword = zeros();
  foreach (i from 0 to 15) {
    let j = popcount_mask(mask, i);
    assert(j >= 0);
    let src_elem : word = get_slice_int(16, unsigned(src), j * 16);
    let lane_mask : word = sign_extend(mask[i..i]);
    result[(i * 16 + 15)..(i * 16)] = src_elem & lane_mask;
  };
  result
}

val avx_vpexpandw_512 : (zmmword, dword) -> zmmword
function avx_vpexpandw_512(src, mask) = {
  var result : zmmword = zeros();
  foreach (i from 0 to 31) {
    let j = popcount_mask(mask, i);
    assert(j >= 0);
    let src_elem : word = get_slice_int(16, unsigned(src), j * 16);
    let lane_mask : word = sign_extend(mask[i..i]);
    result[(i * 16 + 15)..(i * 16)] = src_elem & lane_mask;
  };
  result
}

/* ---- GFNI: Galois Field operations ---- */

// GF(2^8) multiplication using AES polynomial (x^8 + x^4 + x^3 + x + 1)


val dispatch_evex_perm : (range(0, 255), Prefixes) -> unit
function dispatch_evex_perm(op, pfx) = {
  let mp = get_mandatory_prefix(pfx);

  match op {
  // 0F38 18: VBROADCASTSS (66 prefix, W=0)
  24 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    // Tuple1 Scalar: disp_n = 4 for dword
    let src = modrm_rm_evex(modrm, pfx, 4);
    let elem : dword = match src {
      RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
      RM_mem(m) => v(m),
    };
    match pfx.evex_ll {
      0 => evex_write(dst, evex_wmask(pfx, 4), broadcast_f32_xmm(elem)),
      1 => evex_write(dst, evex_wmask(pfx, 8), broadcast_f32_ymm(elem)),
      2 => evex_write(dst, evex_wmask(pfx, 16), broadcast_f32_zmm(elem)),
      3 => raise_UD(),
    }
  },

  // 0F38 19: VBROADCASTSD (66 prefix, W=1)
  // 0F38 19: VBROADCASTSD (66 prefix, W=1)
  25 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    // Tuple1 Scalar: disp_n = 8 for qword
    let src = modrm_rm_evex(modrm, pfx, 8);
    let elem : qword = match src {
      RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
      RM_mem(m) => v(m),
    };
    match pfx.evex_ll {
      0 => evex_write(dst, evex_wmask(pfx, 2), elem @ elem),
      1 => evex_write(dst, evex_wmask(pfx, 4), broadcast_f64_ymm(elem)),
      2 => evex_write(dst, evex_wmask(pfx, 8), broadcast_f64_zmm(elem)),
      3 => raise_UD(),
    }
  },

  // 0F38 7B: VPBROADCASTW (66,W0) [BW] — from GPR
  // 0F38 7B: VPBROADCASTW (66,W0) [BW] — from GPR
  123 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let elem : word = v(32, modrm_rm_reg(modrm, pfx))[15..0];
    let w : dword = elem @ elem;
    let q : qword = w @ w;
    let x : xmmword = q @ q;
    match pfx.evex_ll {
      0 => evex_write(dst, evex_wmask(pfx, 8), x),
      1 => evex_write(dst, evex_wmask(pfx, 16), x @ x),
      2 => evex_write(dst, evex_wmask(pfx, 32), x @ x @ x @ x),
      3 => raise_UD(),
    }
  },

  // 0F38 7C: VPBROADCASTD (66 prefix, W=0)
  // 0F38 7C: VPBROADCASTD (66 prefix, W=0)
  124 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, 4);
    let elem : dword = match src {
      RM_reg(_) => {
        // Source is a GPR (r/m field selects GPR, not XMM)
        v(modrm_rm_reg(modrm, pfx))
      },
      RM_mem(m) => v(m),
    };
    match pfx.evex_ll {
      0 => evex_write(dst, evex_wmask(pfx, 4), broadcast_f32_xmm(elem)),
      1 => evex_write(dst, evex_wmask(pfx, 8), broadcast_f32_ymm(elem)),
      2 => evex_write(dst, evex_wmask(pfx, 16), broadcast_f32_zmm(elem)),
      3 => raise_UD(),
    }
  },

  // 0F38 58: VPBROADCASTD (66,W0) [F] — from XMM/mem
  // 0F38 58: VPBROADCASTD (66,W0) [F] — from XMM/mem
  88 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, 4);
    let elem : dword = match src {
      RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
      RM_mem(m) => v(m),
    };
    match pfx.evex_ll {
      0 => evex_write(dst, evex_wmask(pfx, 4), broadcast_f32_xmm(elem)),
      1 => evex_write(dst, evex_wmask(pfx, 8), broadcast_f32_ymm(elem)),
      2 => evex_write(dst, evex_wmask(pfx, 16), broadcast_f32_zmm(elem)),
      3 => raise_UD(),
    }
  },

  // 0F38 59: VPBROADCASTQ (66,W1) [F] — from XMM/mem
  // 0F38 59: VPBROADCASTQ (66,W1) [F] — from XMM/mem
  89 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, 8);
    let elem : qword = match src {
      RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
      RM_mem(m) => v(m),
    };
    match pfx.evex_ll {
      0 => evex_write(dst, evex_wmask(pfx, 2), elem @ elem),
      1 => evex_write(dst, evex_wmask(pfx, 4), broadcast_f64_ymm(elem)),
      2 => evex_write(dst, evex_wmask(pfx, 8), broadcast_f64_zmm(elem)),
      3 => raise_UD(),
    }
  },

  // 0F38 78: VPBROADCASTB (66,W0) [BW] — from XMM/mem
  // 0F38 78: VPBROADCASTB (66,W0) [BW] — from XMM/mem
  120 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, 4);
    let elem : byte = match src {
      RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[7..0],
      RM_mem(m) => v(m),
    };
    match pfx.evex_ll {
      0 => evex_write(dst, evex_wmask(pfx, 16), broadcast_byte_xmm(elem)),
      1 => evex_write(dst, evex_wmask(pfx, 32), broadcast_byte_ymm(elem)),
      2 => evex_write(dst, evex_wmask(pfx, 64), broadcast_byte_zmm(elem)),
      3 => raise_UD(),
    }
  },

  // 0F38 79: VPBROADCASTW (66,W0) [BW] — from XMM/mem
  // 0F38 79: VPBROADCASTW (66,W0) [BW] — from XMM/mem
  121 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, 4);
    let elem : word = match src {
      RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[15..0],
      RM_mem(m) => v(m),
    };
    let w : dword = elem @ elem;
    let q : qword = w @ w;
    let x : xmmword = q @ q;
    match pfx.evex_ll {
      0 => evex_write(dst, evex_wmask(pfx, 8), x),
      1 => evex_write(dst, evex_wmask(pfx, 16), x @ x),
      2 => evex_write(dst, evex_wmask(pfx, 32), x @ x @ x @ x),
      3 => raise_UD(),
    }
  },

  // 0F38 1A: VBROADCASTF32X4 (66,W0) / VBROADCASTF64X2 (66,W1) [F]
  // 0F38 1A: VBROADCASTF32X4 (66,W0) / VBROADCASTF64X2 (66,W1) [F]
  26 => {
    if mp != MP_66 then raise_UD();
    let (dst, src) = fetch_modrm_evex(pfx, 16);
    let src : xmmword = rm_mem(src);
    match (pfx.rex_w, pfx.evex_ll) {
      (true, 1)  => evex_write(dst, evex_wmask(pfx, 4), src @ src),
      (true, 2)  => evex_write(dst, evex_wmask(pfx, 8), src @ src @ src @ src),
      (false, 1) => evex_write(dst, evex_wmask(pfx, 8), src @ src),
      (false, 2) => evex_write(dst, evex_wmask(pfx, 16), src @ src @ src @ src),
      _ => raise_UD(),
    }
  },

  // 0F38 1B: VBROADCASTF32X8 (66,W0) / VBROADCASTF64X4 (66,W1) [F] (512-bit only)
  // 0F38 1B: VBROADCASTF32X8 (66,W0) / VBROADCASTF64X4 (66,W1) [F] (512-bit only)
  27 => {
    if mp != MP_66 then raise_UD();
    let (dst, src) = fetch_modrm_evex(pfx, 32);
    let src : ymmword = rm_mem(src);
    if pfx.rex_w then evex_write(dst, evex_wmask(pfx, 8), src @ src)
    else evex_write(dst, evex_wmask(pfx, 16), src @ src)
  },

  // 0F38 5A: VBROADCASTI32X4 (66,W0) / VBROADCASTI64X2 (66,W1) [F]
  // 0F38 5A: VBROADCASTI32X4 (66,W0) / VBROADCASTI64X2 (66,W1) [F]
  90 => {
    if mp != MP_66 then raise_UD();
    let (dst, src) = fetch_modrm_evex(pfx, 16);
    let src : xmmword = rm_mem(src);
    match (pfx.rex_w, pfx.evex_ll) {
      (true, 1)  => evex_write(dst, evex_wmask(pfx, 4), src @ src),
      (true, 2)  => evex_write(dst, evex_wmask(pfx, 8), src @ src @ src @ src),
      (false, 1) => evex_write(dst, evex_wmask(pfx, 8), src @ src),
      (false, 2) => evex_write(dst, evex_wmask(pfx, 16), src @ src @ src @ src),
      _ => raise_UD(),
    }
  },

  // 0F38 5B: VBROADCASTI32X8 (66,W0) / VBROADCASTI64X4 (66,W1) [F] (512-bit only)
  // 0F38 5B: VBROADCASTI32X8 (66,W0) / VBROADCASTI64X4 (66,W1) [F] (512-bit only)
  91 => {
    if mp != MP_66 then raise_UD();
    let (dst, src) = fetch_modrm_evex(pfx, 32);
    let src : ymmword = rm_mem(src);
    if pfx.rex_w then evex_write(dst, evex_wmask(pfx, 8), src @ src)
    else evex_write(dst, evex_wmask(pfx, 16), src @ src)
  },

  // 0F38 3A: VPMINUW (66) [BW] / VPBROADCASTMW2D (F3,W0) [CD]
  58 => {
    if mp == MP_66 then {
      // VPMINUW: packed minimum of unsigned words
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let src1_idx = pfx.evex_vvvvv;
      match pfx.evex_ll {
        0 => evex_write(dst, evex_wmask(pfx, 8), avx_pminuw_128(read_xmm(src1_idx), evex_src_xmm(modrm, src, pfx))),
        1 => evex_write(dst, evex_wmask(pfx, 16), avx_pminuw_256(read_ymm(src1_idx), evex_src_ymm(modrm, src, pfx))),
        2 => evex_write(dst, evex_wmask(pfx, 32), avx_pminuw_512(read_zmm(src1_idx), evex_src_zmm(modrm, src, pfx))),
        3 => raise_UD(),
      }
    } else if mp == MP_F3 then {
      if ~(pfx.rex_w) then {
        // VPBROADCASTMW2D: broadcast low word of k-register to all dword elements
        let modrm = fetch(1);
        let dst = evex_reg_idx(modrm, pfx);
        let k_idx : kreg_idx = unsigned(modrm[2..0]);
        let k_val = read_kreg(k_idx);
        let w : word = k_val[15..0];
        let d : dword = zero_extend(w);
        match pfx.evex_ll {
          0 => evex_write(dst, evex_wmask(pfx, 4), d @ d @ d @ d),
          1 => evex_write(dst, evex_wmask(pfx, 8), d @ d @ d @ d @ d @ d @ d @ d),
          2 => evex_write(dst, evex_wmask(pfx, 16), d @ d @ d @ d @ d @ d @ d @ d @ d @ d @ d @ d @ d @ d @ d @ d),
          3 => raise_UD(),
        }
      } else {
        raise_UD()
      }
    } else {
      raise_UD()
    }
  },

  // 0F38 3B: VPMINUD (66, W=0)
  // 0F38 7A: VPBROADCASTB from GPR (66, W=0)
  // r/m field selects a GPR (mod=11 always for this opcode)
  122 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let elem : byte = v(32, modrm_rm_reg(modrm, pfx))[7..0];
    match pfx.evex_ll {
      0 => evex_write(dst, evex_wmask(pfx, 16), broadcast_byte_xmm(elem)),
      1 => evex_write(dst, evex_wmask(pfx, 32), broadcast_byte_ymm(elem)),
      2 => evex_write(dst, evex_wmask(pfx, 64), broadcast_byte_zmm(elem)),
      3 => raise_UD(),
    }
  },

  // 0F38 0C: VPERMILPS (66,W0) — register control [F]
  // 0F38 0C: VPERMILPS (66,W0) — register control [F]
  12 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let src1_idx = pfx.evex_vvvvv;
    match pfx.evex_ll {
      0 => evex_write(dst, evex_wmask(pfx, 4), avx_vpermilps_128(read_xmm(src1_idx), evex_bcast_src_f32_xmm(modrm, src, pfx, is_mem))),
      1 => evex_write(dst, evex_wmask(pfx, 8), avx_vpermilps_256(read_ymm(src1_idx), evex_bcast_src_f32_ymm(modrm, src, pfx, is_mem))),
      2 => evex_write(dst, evex_wmask(pfx, 16), avx_vpermilps_512(read_zmm(src1_idx), evex_bcast_src_f32_zmm(modrm, src, pfx, is_mem))),
      3 => raise_UD(),
    }
  },

  // 0F38 0D: VPERMILPD (66,W1) — register control [F]
  // 0F38 0D: VPERMILPD (66,W1) — register control [F]
  13 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let src1_idx = pfx.evex_vvvvv;
    match pfx.evex_ll {
      0 => evex_write(dst, evex_wmask(pfx, 2), avx_vpermilpd_128(read_xmm(src1_idx), evex_bcast_src_f64_xmm(modrm, src, pfx, is_mem))),
      1 => evex_write(dst, evex_wmask(pfx, 4), avx_vpermilpd_256(read_ymm(src1_idx), evex_bcast_src_f64_ymm(modrm, src, pfx, is_mem))),
      2 => evex_write(dst, evex_wmask(pfx, 8), avx_vpermilpd_512(read_zmm(src1_idx), evex_bcast_src_f64_zmm(modrm, src, pfx, is_mem))),
      3 => raise_UD(),
    }
  },

  // 0F38 16: VPERMPS (66,W0) / VPERMPD (66,W1) [F]
  // 0F38 16: VPERMPS (66,W0) / VPERMPD (66,W1) [F]
  22 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let idx_reg = pfx.evex_vvvvv;
    match (pfx.rex_w, pfx.evex_ll) {
      // VPERMPD
      (true, 1) => evex_write(dst, evex_wmask(pfx, 4), avx_vpermpd_256(evex_bcast_src_f64_ymm(modrm, src, pfx, is_mem), read_ymm(idx_reg))),
      (true, 2) => evex_write(dst, evex_wmask(pfx, 8), avx_vpermpd_512(evex_bcast_src_f64_zmm(modrm, src, pfx, is_mem), read_zmm(idx_reg))),
      // VPERMPS
      (false, 1) => evex_write(dst, evex_wmask(pfx, 8), avx_vpermps_256(evex_bcast_src_f32_ymm(modrm, src, pfx, is_mem), read_ymm(idx_reg))),
      (false, 2) => evex_write(dst, evex_wmask(pfx, 16), avx_vpermps_512(evex_bcast_src_f32_zmm(modrm, src, pfx, is_mem), read_zmm(idx_reg))),
      _ => raise_UD(),
    }
  },

  // 0F38 36: VPERMD (66,W0) / VPERMQ (66,W1) [F]
  // 0F38 36: VPERMD (66,W0) / VPERMQ (66,W1) [F]
  54 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let idx_reg = pfx.evex_vvvvv;
    match (pfx.rex_w, pfx.evex_ll) {
      // VPERMQ
      (true, 1) => evex_write(dst, evex_wmask(pfx, 4), avx_vpermq_256(evex_bcast_src_f64_ymm(modrm, src, pfx, is_mem), read_ymm(idx_reg))),
      (true, 2) => evex_write(dst, evex_wmask(pfx, 8), avx_vpermq_512(evex_bcast_src_f64_zmm(modrm, src, pfx, is_mem), read_zmm(idx_reg))),
      // VPERMD
      (false, 1) => evex_write(dst, evex_wmask(pfx, 8), avx_vpermd_256(evex_bcast_src_f32_ymm(modrm, src, pfx, is_mem), read_ymm(idx_reg))),
      (false, 2) => evex_write(dst, evex_wmask(pfx, 16), avx_vpermd_512(evex_bcast_src_f32_zmm(modrm, src, pfx, is_mem), read_zmm(idx_reg))),
      _ => raise_UD(),
    }
  },

  // 0F38 00: VPSHUFB (66) [BW]
  // 0F38 00: VPSHUFB (66) [BW]
  0 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let src1_idx = pfx.evex_vvvvv;
    match pfx.evex_ll {
      0 => evex_write(dst, evex_wmask(pfx, 16), avx_pshufb_128(read_xmm(src1_idx), evex_src_xmm(modrm, src, pfx))),
      1 => evex_write(dst, evex_wmask(pfx, 32), avx_pshufb_256(read_ymm(src1_idx), evex_src_ymm(modrm, src, pfx))),
      2 => evex_write(dst, evex_wmask(pfx, 64), avx_pshufb_512(read_zmm(src1_idx), evex_src_zmm(modrm, src, pfx))),
      3 => raise_UD(),
    }
  },

  // 0F38 75: VPERMI2B (66,W0) [VBMI] / VPERMI2W (66,W1) [BW]
  117 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let src1_idx = pfx.evex_vvvvv;
    match (pfx.rex_w, pfx.evex_ll) {
      // VPERMI2W
      (true, 0) => { let idx = read_xmm(dst); evex_write(dst, evex_wmask(pfx, 8), avx_vperm2_w_128(read_xmm(src1_idx), evex_src_xmm(modrm, src, pfx), idx)) },
      (true, 1) => { let idx = read_ymm(dst); evex_write(dst, evex_wmask(pfx, 16), avx_vperm2_w_256(read_ymm(src1_idx), evex_src_ymm(modrm, src, pfx), idx)) },
      (true, 2) => { let idx = read_zmm(dst); evex_write(dst, evex_wmask(pfx, 32), avx_vperm2_w_512(read_zmm(src1_idx), evex_src_zmm(modrm, src, pfx), idx)) },
      // VPERMI2B
      (false, 0) => { let idx = read_xmm(dst); evex_write(dst, evex_wmask(pfx, 16), avx_vperm2_b_128(read_xmm(src1_idx), evex_src_xmm(modrm, src, pfx), idx)) },
      (false, 1) => { let idx = read_ymm(dst); evex_write(dst, evex_wmask(pfx, 32), avx_vperm2_b_256(read_ymm(src1_idx), evex_src_ymm(modrm, src, pfx), idx)) },
      (false, 2) => { let idx = read_zmm(dst); evex_write(dst, evex_wmask(pfx, 64), avx_vperm2_b_512(read_zmm(src1_idx), evex_src_zmm(modrm, src, pfx), idx)) },
      _ => raise_UD(),
    }
  },

  // 0F38 76: VPERMI2D (66,W0) / VPERMI2Q (66,W1) [F]
  118 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let src1_idx = pfx.evex_vvvvv;
    match (pfx.rex_w, pfx.evex_ll) {
      // VPERMI2Q
      (true, 0) => { let idx = read_xmm(dst); evex_write(dst, evex_wmask(pfx, 2), avx_vperm2_q_128(read_xmm(src1_idx), evex_bcast_src_f64_xmm(modrm, src, pfx, is_mem), idx)) },
      (true, 1) => { let idx = read_ymm(dst); evex_write(dst, evex_wmask(pfx, 4), avx_vperm2_q_256(read_ymm(src1_idx), evex_bcast_src_f64_ymm(modrm, src, pfx, is_mem), idx)) },
      (true, 2) => { let idx = read_zmm(dst); evex_write(dst, evex_wmask(pfx, 8), avx_vperm2_q_512(read_zmm(src1_idx), evex_bcast_src_f64_zmm(modrm, src, pfx, is_mem), idx)) },
      // VPERMI2D
      (false, 0) => { let idx = read_xmm(dst); evex_write(dst, evex_wmask(pfx, 4), avx_vperm2_d_128(read_xmm(src1_idx), evex_bcast_src_f32_xmm(modrm, src, pfx, is_mem), idx)) },
      (false, 1) => { let idx = read_ymm(dst); evex_write(dst, evex_wmask(pfx, 8), avx_vperm2_d_256(read_ymm(src1_idx), evex_bcast_src_f32_ymm(modrm, src, pfx, is_mem), idx)) },
      (false, 2) => { let idx = read_zmm(dst); evex_write(dst, evex_wmask(pfx, 16), avx_vperm2_d_512(read_zmm(src1_idx), evex_bcast_src_f32_zmm(modrm, src, pfx, is_mem), idx)) },
      _ => raise_UD(),
    }
  },

  // 0F38 77: VPERMI2PS (66,W0) / VPERMI2PD (66,W1) [F]
  // 0F38 77: VPERMI2PS (66,W0) / VPERMI2PD (66,W1) [F]
  119 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let src1_idx = pfx.evex_vvvvv;
    match (pfx.rex_w, pfx.evex_ll) {
      // VPERMI2PD (same as Q)
      (true, 0) => { let idx = read_xmm(dst); evex_write(dst, evex_wmask(pfx, 2), avx_vperm2_q_128(read_xmm(src1_idx), evex_bcast_src_f64_xmm(modrm, src, pfx, is_mem), idx)) },
      (true, 1) => { let idx = read_ymm(dst); evex_write(dst, evex_wmask(pfx, 4), avx_vperm2_q_256(read_ymm(src1_idx), evex_bcast_src_f64_ymm(modrm, src, pfx, is_mem), idx)) },
      (true, 2) => { let idx = read_zmm(dst); evex_write(dst, evex_wmask(pfx, 8), avx_vperm2_q_512(read_zmm(src1_idx), evex_bcast_src_f64_zmm(modrm, src, pfx, is_mem), idx)) },
      // VPERMI2PS (same as D)
      (false, 0) => { let idx = read_xmm(dst); evex_write(dst, evex_wmask(pfx, 4), avx_vperm2_d_128(read_xmm(src1_idx), evex_bcast_src_f32_xmm(modrm, src, pfx, is_mem), idx)) },
      (false, 1) => { let idx = read_ymm(dst); evex_write(dst, evex_wmask(pfx, 8), avx_vperm2_d_256(read_ymm(src1_idx), evex_bcast_src_f32_ymm(modrm, src, pfx, is_mem), idx)) },
      (false, 2) => { let idx = read_zmm(dst); evex_write(dst, evex_wmask(pfx, 16), avx_vperm2_d_512(read_zmm(src1_idx), evex_bcast_src_f32_zmm(modrm, src, pfx, is_mem), idx)) },
      _ => raise_UD(),
    }
  },

  // 0F38 7E: VPERMT2D (66,W0) / VPERMT2Q (66,W1) [F]
  // 0F38 7E: VPERMT2D (66,W0) / VPERMT2Q (66,W1) [F]
  126 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let idx_reg = pfx.evex_vvvvv;
    match (pfx.rex_w, pfx.evex_ll) {
      // VPERMT2Q
      (true, 0) => evex_write(dst, evex_wmask(pfx, 2), avx_vperm2_q_128(read_xmm(dst), evex_bcast_src_f64_xmm(modrm, src, pfx, is_mem), read_xmm(idx_reg))),
      (true, 1) => evex_write(dst, evex_wmask(pfx, 4), avx_vperm2_q_256(read_ymm(dst), evex_bcast_src_f64_ymm(modrm, src, pfx, is_mem), read_ymm(idx_reg))),
      (true, 2) => evex_write(dst, evex_wmask(pfx, 8), avx_vperm2_q_512(read_zmm(dst), evex_bcast_src_f64_zmm(modrm, src, pfx, is_mem), read_zmm(idx_reg))),
      // VPERMT2D
      (false, 0) => evex_write(dst, evex_wmask(pfx, 4), avx_vperm2_d_128(read_xmm(dst), evex_bcast_src_f32_xmm(modrm, src, pfx, is_mem), read_xmm(idx_reg))),
      (false, 1) => evex_write(dst, evex_wmask(pfx, 8), avx_vperm2_d_256(read_ymm(dst), evex_bcast_src_f32_ymm(modrm, src, pfx, is_mem), read_ymm(idx_reg))),
      (false, 2) => evex_write(dst, evex_wmask(pfx, 16), avx_vperm2_d_512(read_zmm(dst), evex_bcast_src_f32_zmm(modrm, src, pfx, is_mem), read_zmm(idx_reg))),
      _ => raise_UD(),
    }
  },

  // 0F38 7F: VPERMT2PS (66,W0) / VPERMT2PD (66,W1) [F]
  // 0F38 7F: VPERMT2PS (66,W0) / VPERMT2PD (66,W1) [F]
  127 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let idx_reg = pfx.evex_vvvvv;
    match (pfx.rex_w, pfx.evex_ll) {
      // VPERMT2PD
      (true, 0) => evex_write(dst, evex_wmask(pfx, 2), avx_vperm2_q_128(read_xmm(dst), evex_bcast_src_f64_xmm(modrm, src, pfx, is_mem), read_xmm(idx_reg))),
      (true, 1) => evex_write(dst, evex_wmask(pfx, 4), avx_vperm2_q_256(read_ymm(dst), evex_bcast_src_f64_ymm(modrm, src, pfx, is_mem), read_ymm(idx_reg))),
      (true, 2) => evex_write(dst, evex_wmask(pfx, 8), avx_vperm2_q_512(read_zmm(dst), evex_bcast_src_f64_zmm(modrm, src, pfx, is_mem), read_zmm(idx_reg))),
      // VPERMT2PS
      (false, 0) => evex_write(dst, evex_wmask(pfx, 4), avx_vperm2_d_128(read_xmm(dst), evex_bcast_src_f32_xmm(modrm, src, pfx, is_mem), read_xmm(idx_reg))),
      (false, 1) => evex_write(dst, evex_wmask(pfx, 8), avx_vperm2_d_256(read_ymm(dst), evex_bcast_src_f32_ymm(modrm, src, pfx, is_mem), read_ymm(idx_reg))),
      (false, 2) => evex_write(dst, evex_wmask(pfx, 16), avx_vperm2_d_512(read_zmm(dst), evex_bcast_src_f32_zmm(modrm, src, pfx, is_mem), read_zmm(idx_reg))),
      _ => raise_UD(),
    }
  },

  // 0F38 35: VPMOVZXDQ (66) [F] / VPMOVQD (F3) [F]
  // 0F38 7D: VPERMT2W (66,W1) [BW] / VPERMT2B (66,W0) [VBMI]
  125 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let idx_reg = pfx.evex_vvvvv;
    match (pfx.rex_w, pfx.evex_ll) {
      // VPERMT2W
      (true, 0) => evex_write(dst, evex_wmask(pfx, 8), avx_vperm2_w_128(read_xmm(dst), evex_src_xmm(modrm, src, pfx), read_xmm(idx_reg))),
      (true, 1) => evex_write(dst, evex_wmask(pfx, 16), avx_vperm2_w_256(read_ymm(dst), evex_src_ymm(modrm, src, pfx), read_ymm(idx_reg))),
      (true, 2) => evex_write(dst, evex_wmask(pfx, 32), avx_vperm2_w_512(read_zmm(dst), evex_src_zmm(modrm, src, pfx), read_zmm(idx_reg))),
      // VPERMT2B
      (false, 0) => evex_write(dst, evex_wmask(pfx, 16), avx_vperm2_b_128(read_xmm(dst), evex_src_xmm(modrm, src, pfx), read_xmm(idx_reg))),
      (false, 1) => evex_write(dst, evex_wmask(pfx, 32), avx_vperm2_b_256(read_ymm(dst), evex_src_ymm(modrm, src, pfx), read_ymm(idx_reg))),
      (false, 2) => evex_write(dst, evex_wmask(pfx, 64), avx_vperm2_b_512(read_zmm(dst), evex_src_zmm(modrm, src, pfx), read_zmm(idx_reg))),
      _ => raise_UD(),
    }
  },

  // 0F38 62: VPEXPANDB (66,W0) / VPEXPANDW (66,W1) [VBMI2]
  98 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, 1);
    let k : qword = evex_kmask64(pfx);
    match (pfx.rex_w, pfx.evex_ll) {
      // VPEXPANDW
      (true, 0) => write_xmm(dst, avx_vpexpandw_128(evex_src_xmm(modrm, src, pfx), k[7..0])),
      (true, 1) => write_ymm(dst, avx_vpexpandw_256(evex_src_ymm(modrm, src, pfx), k[15..0])),
      (true, 2) => write_zmm(dst, avx_vpexpandw_512(evex_src_zmm(modrm, src, pfx), k[31..0])),
      // VPEXPANDB
      (false, 0) => write_xmm(dst, avx_vpexpandb_128(evex_src_xmm(modrm, src, pfx), k[15..0])),
      (false, 1) => write_ymm(dst, avx_vpexpandb_256(evex_src_ymm(modrm, src, pfx), k[31..0])),
      (false, 2) => write_zmm(dst, avx_vpexpandb_512(evex_src_zmm(modrm, src, pfx), k[63..0])),
      _ => raise_UD(),
    }
  },

  // 0F38 63: VPCOMPRESSB (66,W0) / VPCOMPRESSW (66,W1) [VBMI2]
  99 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let src = evex_reg_idx(modrm, pfx);
    let dest = modrm_rm_evex(modrm, pfx, 1);
    let k : qword = evex_kmask64(pfx);
    match dest {
      RM_reg(_) => {
        let dst_reg = evex_rm_reg_idx(modrm, pfx);
        match (pfx.rex_w, pfx.evex_ll) {
          // VPCOMPRESSW
          (true, 0) => write_xmm(dst_reg, avx_vpcompressw_128(read_xmm(src), k[7..0])),
          (true, 1) => write_ymm(dst_reg, avx_vpcompressw_256(read_ymm(src), k[15..0])),
          (true, 2) => write_zmm(dst_reg, avx_vpcompressw_512(read_zmm(src), k[31..0])),
          // VPCOMPRESSB
          (false, 0) => write_xmm(dst_reg, avx_vpcompressb_128(read_xmm(src), k[15..0])),
          (false, 1) => write_ymm(dst_reg, avx_vpcompressb_256(read_ymm(src), k[31..0])),
          (false, 2) => write_zmm(dst_reg, avx_vpcompressb_512(read_zmm(src), k[63..0])),
          _ => raise_UD(),
        }
      },
      RM_mem(m) => {
        let a = seg_linear(m, 64);
        match (pfx.rex_w, pfx.evex_ll) {
          // VPCOMPRESSW mem
          (true, 0) => avx_vpcompressw_mem_128(a, read_xmm(src), k[7..0]),
          (true, 1) => avx_vpcompressw_mem_256(a, read_ymm(src), k[15..0]),
          (true, 2) => avx_vpcompressw_mem_512(a, read_zmm(src), k[31..0]),
          // VPCOMPRESSB mem
          (false, 0) => avx_vpcompressb_mem_128(a, read_xmm(src), k[15..0]),
          (false, 1) => avx_vpcompressb_mem_256(a, read_ymm(src), k[31..0]),
          (false, 2) => avx_vpcompressb_mem_512(a, read_zmm(src), k[63..0]),
          _ => raise_UD(),
        }
      },
    }
  },

  // 0F38 70: VPSHLDVW (66, W=1) [VBMI2]
  // 0F38 8D: VPERMW (66,W1) [BW] / VPERMB (66,W0) [VBMI]
  141 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let ctrl = read_zmm(pfx.evex_vvvvv);
    match (pfx.rex_w, pfx.evex_ll) {
      // VPERMW
      (true, 0) => evex_write(dst, evex_wmask(pfx, 8), avx_vpermw_128(evex_src_xmm(modrm, src, pfx), read_xmm(pfx.evex_vvvvv))),
      (true, 1) => evex_write(dst, evex_wmask(pfx, 16), avx_vpermw_256(evex_src_ymm(modrm, src, pfx), read_ymm(pfx.evex_vvvvv))),
      (true, 2) => evex_write(dst, evex_wmask(pfx, 32), avx_vpermw_512(evex_src_zmm(modrm, src, pfx), ctrl)),
      // VPERMB
      (false, 0) => evex_write(dst, evex_wmask(pfx, 16), avx_vpermb_128(evex_src_xmm(modrm, src, pfx), read_xmm(pfx.evex_vvvvv))),
      (false, 1) => evex_write(dst, evex_wmask(pfx, 32), avx_vpermb_256(evex_src_ymm(modrm, src, pfx), read_ymm(pfx.evex_vvvvv))),
      (false, 2) => evex_write(dst, evex_wmask(pfx, 64), avx_vpermb_512(evex_src_zmm(modrm, src, pfx), ctrl)),
      _ => raise_UD(),
    }
  },

  // 0F38 2A: VMOVNTDQA (66) [F] / VPBROADCASTMB2Q (F3,W1) [CD]
  // 0F38 2A: VMOVNTDQA (66) [F] / VPBROADCASTMB2Q (F3,W1) [CD]
  42 => {
    if mp == MP_66 then {
      // VMOVNTDQA: memory source only (SDM: ModRM.MOD != 11b)
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match src {
        RM_reg(_) => raise_UD(),
        RM_mem(_) => {
          match (pfx.rex_w, pfx.evex_ll) {
            (true, 0) => evex_write(dst, evex_wmask(pfx, 2), evex_src_xmm(modrm, src, pfx)),
            (true, 1) => evex_write(dst, evex_wmask(pfx, 4), evex_src_ymm(modrm, src, pfx)),
            (true, 2) => evex_write(dst, evex_wmask(pfx, 8), evex_src_zmm(modrm, src, pfx)),
            (false, 0) => evex_write(dst, evex_wmask(pfx, 4), evex_src_xmm(modrm, src, pfx)),
            (false, 1) => evex_write(dst, evex_wmask(pfx, 8), evex_src_ymm(modrm, src, pfx)),
            (false, 2) => evex_write(dst, evex_wmask(pfx, 16), evex_src_zmm(modrm, src, pfx)),
            _ => raise_UD(),
          }
        },
      }
    } else if mp == MP_F3 then {
      // VPBROADCASTMB2Q: broadcast low byte of k-register to all qword elements
      if ~(pfx.rex_w) then raise_UD();
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let k_idx : kreg_idx = unsigned(modrm[2..0]);
      let k_val = read_kreg(k_idx);
      let b : byte = k_val[7..0];
      let q : qword = zero_extend(b);
      match pfx.evex_ll {
        0 => evex_write(dst, evex_wmask(pfx, 2), q @ q),
        1 => evex_write(dst, evex_wmask(pfx, 4), q @ q @ q @ q),
        2 => evex_write(dst, evex_wmask(pfx, 8), q @ q @ q @ q @ q @ q @ q @ q),
        3 => raise_UD(),
      }
    } else {
      raise_UD()
    }
  },

  // 0F38 8F: VPSHUFBITQMB (66,W0) [BITALG]
  // 0F38 8F: VPSHUFBITQMB (66,W0) [BITALG]
  143 => {
    if mp != MP_66 | pfx.rex_w then raise_UD();
    let modrm = fetch(1);
    let dst_k : range(0, 7) = unsigned(modrm[5..3]);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    match pfx.evex_ll {
      0 => {
        let r = avx_vpshufbitqmb_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, src, pfx));
        write_kreg(dst_k, zero_extend(r))
      },
      1 => {
        let r = avx_vpshufbitqmb_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, src, pfx));
        write_kreg(dst_k, zero_extend(r))
      },
      2 => {
        let r = avx_vpshufbitqmb_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, src, pfx));
        write_kreg(dst_k, r)
      },
      3 => raise_UD(),
    }
  },

  // =====================================================================
  // Gather (0x90-0x93) — VSIB addressing
  // =====================================================================

  // 0F38 90: VPGATHERDD (66,W0) / VPGATHERDQ (66,W1) [F]
  // 0F38 2A: VPBROADCASTMB2Q (F3, W=1) [CD] — also VMOVNTDQA (66)
  42 => {
    if mp == MP_F3 & pfx.rex_w then {
      // VPBROADCASTMB2Q: broadcast low byte of kmask to all qword elements
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src_k : range(0, 7) = unsigned(modrm[2..0]);
      let k_byte : byte = read_kreg(src_k)[7..0];
      match pfx.evex_ll {
        0 => evex_write(dst, evex_wmask(pfx, 2), avx_vpbroadcastmb2q_128(k_byte)),
        1 => evex_write(dst, evex_wmask(pfx, 4), avx_vpbroadcastmb2q_256(k_byte)),
        2 => evex_write(dst, evex_wmask(pfx, 8), avx_vpbroadcastmb2q_512(k_byte)),
        3 => raise_UD(),
      }
    } else if mp == MP_66 then {
      // VMOVNTDQA (already handled if present, otherwise fallthrough)
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match (pfx.rex_w, pfx.evex_ll) {
        (true, 0) => evex_write(dst, evex_wmask(pfx, 2), evex_src_xmm(modrm, src, pfx)),
        (true, 1) => evex_write(dst, evex_wmask(pfx, 4), evex_src_ymm(modrm, src, pfx)),
        (true, 2) => evex_write(dst, evex_wmask(pfx, 8), evex_src_zmm(modrm, src, pfx)),
        (false, 0) => evex_write(dst, evex_wmask(pfx, 4), evex_src_xmm(modrm, src, pfx)),
        (false, 1) => evex_write(dst, evex_wmask(pfx, 8), evex_src_ymm(modrm, src, pfx)),
        (false, 2) => evex_write(dst, evex_wmask(pfx, 16), evex_src_zmm(modrm, src, pfx)),
        _ => raise_UD(),
      }
    } else {
      raise_UD()
    }
  },

  // 0F38 44: VPLZCNTD (66, W=0) / VPLZCNTQ (66, W=1) [CD]
  // 0F38 88: VEXPANDPS (66, W=0) / VEXPANDPD (66, W=1) [F]
  136 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
    let k : qword = evex_kmask64(pfx);
    match (pfx.rex_w, pfx.evex_ll) {
      // VEXPANDPD xmm1/ymm1/zmm1, xmm2/ymm2/zmm2/m128/m256/m512
      (true, 0) => write_xmm(dst, avx_vexpandpd_128(evex_src_xmm(modrm, src, pfx), k[7..0])),
      (true, 1) => write_ymm(dst, avx_vexpandpd_256(evex_src_ymm(modrm, src, pfx), k[7..0])),
      (true, 2) => write_zmm(dst, avx_vexpandpd_512(evex_src_zmm(modrm, src, pfx), k[7..0])),
      // VEXPANDPS xmm1/ymm1/zmm1, xmm2/ymm2/zmm2/m128/m256/m512
      (false, 0) => write_xmm(dst, avx_vexpandps_128(evex_src_xmm(modrm, src, pfx), k[7..0])),
      (false, 1) => write_ymm(dst, avx_vexpandps_256(evex_src_ymm(modrm, src, pfx), k[7..0])),
      (false, 2) => write_zmm(dst, avx_vexpandps_512(evex_src_zmm(modrm, src, pfx), k[15..0])),
      _ => raise_UD(),
    }
  },

  // 0F38 89: VPEXPANDD (66, W=0) / VPEXPANDQ (66, W=1) [F]
  // 0F38 89: VPEXPANDD (66, W=0) / VPEXPANDQ (66, W=1) [F]
  137 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
    let k : qword = evex_kmask64(pfx);
    match (pfx.rex_w, pfx.evex_ll) {
      // VPEXPANDQ — same as VEXPANDPD (qword elements)
      (true, 0) => write_xmm(dst, avx_vexpandpd_128(evex_src_xmm(modrm, src, pfx), k[7..0])),
      (true, 1) => write_ymm(dst, avx_vexpandpd_256(evex_src_ymm(modrm, src, pfx), k[7..0])),
      (true, 2) => write_zmm(dst, avx_vexpandpd_512(evex_src_zmm(modrm, src, pfx), k[7..0])),
      // VPEXPANDD — same as VEXPANDPS (dword elements)
      (false, 0) => write_xmm(dst, avx_vexpandps_128(evex_src_xmm(modrm, src, pfx), k[7..0])),
      (false, 1) => write_ymm(dst, avx_vexpandps_256(evex_src_ymm(modrm, src, pfx), k[7..0])),
      (false, 2) => write_zmm(dst, avx_vexpandps_512(evex_src_zmm(modrm, src, pfx), k[15..0])),
      _ => raise_UD(),
    }
  },

  // 0F38 8A: VCOMPRESSPS (66, W=0) / VCOMPRESSPD (66, W=1) [F]
  // SDM: reg=src, r/m=dst; memory form writes only compressed elements
  138 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let src = evex_reg_idx(modrm, pfx);
    let dest = modrm_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
    let k : qword = evex_kmask64(pfx);
    match dest {
      RM_reg(_) => {
        let dst_reg = evex_rm_reg_idx(modrm, pfx);
        match (pfx.rex_w, pfx.evex_ll) {
          (true, 0) => write_xmm(dst_reg, avx_vcompresspd_128(read_xmm(src), k[7..0])),
          (true, 1) => write_ymm(dst_reg, avx_vcompresspd_256(read_ymm(src), k[7..0])),
          (true, 2) => write_zmm(dst_reg, avx_vcompresspd_512(read_zmm(src), k[7..0])),
          (false, 0) => write_xmm(dst_reg, avx_vcompressps_128(read_xmm(src), k[7..0])),
          (false, 1) => write_ymm(dst_reg, avx_vcompressps_256(read_ymm(src), k[7..0])),
          (false, 2) => write_zmm(dst_reg, avx_vcompressps_512(read_zmm(src), k[15..0])),
          _ => raise_UD(),
        }
      },
      RM_mem(m) => {
        let a = seg_linear(m, 64);
        match (pfx.rex_w, pfx.evex_ll) {
          (true, 0) => avx_vcompress_qword_mem_128(a, read_xmm(src), k[7..0]),
          (true, 1) => avx_vcompress_qword_mem_256(a, read_ymm(src), k[7..0]),
          (true, 2) => avx_vcompress_qword_mem_512(a, read_zmm(src), k[7..0]),
          (false, 0) => avx_vcompress_dword_mem_128(a, read_xmm(src), k[7..0]),
          (false, 1) => avx_vcompress_dword_mem_256(a, read_ymm(src), k[7..0]),
          (false, 2) => avx_vcompress_dword_mem_512(a, read_zmm(src), k[15..0]),
          _ => raise_UD(),
        }
      },
    }
  },

  // 0F38 8B: VPCOMPRESSD (66, W=0) / VPCOMPRESSQ (66, W=1) [F]
  // SDM: reg=src, r/m=dst; memory form writes only compressed elements
  139 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let src = evex_reg_idx(modrm, pfx);
    let dest = modrm_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
    let k : qword = evex_kmask64(pfx);
    match dest {
      RM_reg(_) => {
        let dst_reg = evex_rm_reg_idx(modrm, pfx);
        match (pfx.rex_w, pfx.evex_ll) {
          (true, 0) => write_xmm(dst_reg, avx_vcompresspd_128(read_xmm(src), k[7..0])),
          (true, 1) => write_ymm(dst_reg, avx_vcompresspd_256(read_ymm(src), k[7..0])),
          (true, 2) => write_zmm(dst_reg, avx_vcompresspd_512(read_zmm(src), k[7..0])),
          (false, 0) => write_xmm(dst_reg, avx_vcompressps_128(read_xmm(src), k[7..0])),
          (false, 1) => write_ymm(dst_reg, avx_vcompressps_256(read_ymm(src), k[7..0])),
          (false, 2) => write_zmm(dst_reg, avx_vcompressps_512(read_zmm(src), k[15..0])),
          _ => raise_UD(),
        }
      },
      RM_mem(m) => {
        let a = seg_linear(m, 64);
        match (pfx.rex_w, pfx.evex_ll) {
          (true, 0) => avx_vcompress_qword_mem_128(a, read_xmm(src), k[7..0]),
          (true, 1) => avx_vcompress_qword_mem_256(a, read_ymm(src), k[7..0]),
          (true, 2) => avx_vcompress_qword_mem_512(a, read_zmm(src), k[7..0]),
          (false, 0) => avx_vcompress_dword_mem_128(a, read_xmm(src), k[7..0]),
          (false, 1) => avx_vcompress_dword_mem_256(a, read_ymm(src), k[7..0]),
          (false, 2) => avx_vcompress_dword_mem_512(a, read_zmm(src), k[15..0]),
          _ => raise_UD(),
        }
      },
    }
  },

  // 0F38 64: VPBLENDMD (66,W0) / VPBLENDMQ (66,W1) — mask-controlled blend
  100 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let src1_idx = pfx.evex_vvvvv;
    let k : qword = evex_kmask64(pfx);
    match (pfx.rex_w, pfx.evex_ll) {
      // VPBLENDMQ: qword blend
      (true, 0) => {
        let src1 : xmmword = read_xmm(src1_idx);
        let src2 : xmmword = evex_bcast_src_f64_xmm(modrm, src, pfx, is_mem);
        let z_keep : xmmword = sign_extend(~(pfx.evex_z));
        let src1_eff : xmmword = src1 & z_keep;
        var result : xmmword = zeros();
        foreach (i from 0 to 1) {
          let lo = i * 64;
          result[(lo + 63) .. lo] = blend(src1_eff[(lo + 63) .. lo], src2[(lo + 63) .. lo], k[i])
        };
        write_xmm(dst, result)
      },
      (true, 1) => {
        let src1 : ymmword = read_ymm(src1_idx);
        let src2 : ymmword = evex_bcast_src_f64_ymm(modrm, src, pfx, is_mem);
        let z_keep : ymmword = sign_extend(~(pfx.evex_z));
        let src1_eff : ymmword = src1 & z_keep;
        var result : ymmword = zeros();
        foreach (i from 0 to 3) {
          let lo = i * 64;
          result[(lo + 63) .. lo] = blend(src1_eff[(lo + 63) .. lo], src2[(lo + 63) .. lo], k[i])
        };
        write_ymm(dst, result)
      },
      (true, 2) => {
        let src1 : zmmword = read_zmm(src1_idx);
        let src2 : zmmword = evex_bcast_src_f64_zmm(modrm, src, pfx, is_mem);
        let z_keep : zmmword = sign_extend(~(pfx.evex_z));
        let src1_eff : zmmword = src1 & z_keep;
        var result : zmmword = zeros();
        foreach (i from 0 to 7) {
          let lo = i * 64;
          result[(lo + 63) .. lo] = blend(src1_eff[(lo + 63) .. lo], src2[(lo + 63) .. lo], k[i])
        };
        write_zmm(dst, result)
      },
      // VPBLENDMD: dword blend
      (false, 0) => {
        let src1 : xmmword = read_xmm(src1_idx);
        let src2 : xmmword = evex_bcast_src_f32_xmm(modrm, src, pfx, is_mem);
        let z_keep : xmmword = sign_extend(~(pfx.evex_z));
        let src1_eff : xmmword = src1 & z_keep;
        var result : xmmword = zeros();
        foreach (i from 0 to 3) {
          let lo = i * 32;
          result[(lo + 31) .. lo] = blend(src1_eff[(lo + 31) .. lo], src2[(lo + 31) .. lo], k[i])
        };
        write_xmm(dst, result)
      },
      (false, 1) => {
        let src1 : ymmword = read_ymm(src1_idx);
        let src2 : ymmword = evex_bcast_src_f32_ymm(modrm, src, pfx, is_mem);
        let z_keep : ymmword = sign_extend(~(pfx.evex_z));
        let src1_eff : ymmword = src1 & z_keep;
        var result : ymmword = zeros();
        foreach (i from 0 to 7) {
          let lo = i * 32;
          result[(lo + 31) .. lo] = blend(src1_eff[(lo + 31) .. lo], src2[(lo + 31) .. lo], k[i])
        };
        write_ymm(dst, result)
      },
      (false, 2) => {
        let src1 : zmmword = read_zmm(src1_idx);
        let src2 : zmmword = evex_bcast_src_f32_zmm(modrm, src, pfx, is_mem);
        let z_keep : zmmword = sign_extend(~(pfx.evex_z));
        let src1_eff : zmmword = src1 & z_keep;
        var result : zmmword = zeros();
        foreach (i from 0 to 15) {
          let lo = i * 32;
          result[(lo + 31) .. lo] = blend(src1_eff[(lo + 31) .. lo], src2[(lo + 31) .. lo], k[i])
        };
        write_zmm(dst, result)
      },
      _ => raise_UD(),
    }
  },

  // 0F38 65: VBLENDMPS (66,W0) / VBLENDMPD (66,W1) — mask-controlled FP blend
  101 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let src1_idx = pfx.evex_vvvvv;
    let k : qword = evex_kmask64(pfx);
    match (pfx.rex_w, pfx.evex_ll) {
      // VBLENDMPD: qword blend
      (true, 0) => {
        let src1 : xmmword = read_xmm(src1_idx);
        let src2 : xmmword = evex_bcast_src_f64_xmm(modrm, src, pfx, is_mem);
        let z_keep : xmmword = sign_extend(~(pfx.evex_z));
        let src1_eff : xmmword = src1 & z_keep;
        var result : xmmword = zeros();
        foreach (i from 0 to 1) {
          let lo = i * 64;
          result[(lo + 63) .. lo] = blend(src1_eff[(lo + 63) .. lo], src2[(lo + 63) .. lo], k[i])
        };
        write_xmm(dst, result)
      },
      (true, 1) => {
        let src1 : ymmword = read_ymm(src1_idx);
        let src2 : ymmword = evex_bcast_src_f64_ymm(modrm, src, pfx, is_mem);
        let z_keep : ymmword = sign_extend(~(pfx.evex_z));
        let src1_eff : ymmword = src1 & z_keep;
        var result : ymmword = zeros();
        foreach (i from 0 to 3) {
          let lo = i * 64;
          result[(lo + 63) .. lo] = blend(src1_eff[(lo + 63) .. lo], src2[(lo + 63) .. lo], k[i])
        };
        write_ymm(dst, result)
      },
      (true, 2) => {
        let src1 : zmmword = read_zmm(src1_idx);
        let src2 : zmmword = evex_bcast_src_f64_zmm(modrm, src, pfx, is_mem);
        let z_keep : zmmword = sign_extend(~(pfx.evex_z));
        let src1_eff : zmmword = src1 & z_keep;
        var result : zmmword = zeros();
        foreach (i from 0 to 7) {
          let lo = i * 64;
          result[(lo + 63) .. lo] = blend(src1_eff[(lo + 63) .. lo], src2[(lo + 63) .. lo], k[i])
        };
        write_zmm(dst, result)
      },
      // VBLENDMPS: dword blend
      (false, 0) => {
        let src1 : xmmword = read_xmm(src1_idx);
        let src2 : xmmword = evex_bcast_src_f32_xmm(modrm, src, pfx, is_mem);
        let z_keep : xmmword = sign_extend(~(pfx.evex_z));
        let src1_eff : xmmword = src1 & z_keep;
        var result : xmmword = zeros();
        foreach (i from 0 to 3) {
          let lo = i * 32;
          result[(lo + 31) .. lo] = blend(src1_eff[(lo + 31) .. lo], src2[(lo + 31) .. lo], k[i])
        };
        write_xmm(dst, result)
      },
      (false, 1) => {
        let src1 : ymmword = read_ymm(src1_idx);
        let src2 : ymmword = evex_bcast_src_f32_ymm(modrm, src, pfx, is_mem);
        let z_keep : ymmword = sign_extend(~(pfx.evex_z));
        let src1_eff : ymmword = src1 & z_keep;
        var result : ymmword = zeros();
        foreach (i from 0 to 7) {
          let lo = i * 32;
          result[(lo + 31) .. lo] = blend(src1_eff[(lo + 31) .. lo], src2[(lo + 31) .. lo], k[i])
        };
        write_ymm(dst, result)
      },
      (false, 2) => {
        let src1 : zmmword = read_zmm(src1_idx);
        let src2 : zmmword = evex_bcast_src_f32_zmm(modrm, src, pfx, is_mem);
        let z_keep : zmmword = sign_extend(~(pfx.evex_z));
        let src1_eff : zmmword = src1 & z_keep;
        var result : zmmword = zeros();
        foreach (i from 0 to 15) {
          let lo = i * 32;
          result[(lo + 31) .. lo] = blend(src1_eff[(lo + 31) .. lo], src2[(lo + 31) .. lo], k[i])
        };
        write_zmm(dst, result)
      },
      _ => raise_UD(),
    }
  },

  _ => raise_UD(),
  }
}

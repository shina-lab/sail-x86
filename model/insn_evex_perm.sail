// x86-64 — EVEX Permute/Shuffle/Compress (0F38 map)
//
// VBROADCAST, VPERM, VPSHUF, VCOMPRESS, VEXPAND.
// Called from dispatch_evex_0f38 in insn_evex.sail.

// Broadcast a byte to all lanes

// =========================================================================
// AVX-512 packed unsigned byte minimum
// =========================================================================

val avx_vpermilps_128 : (xmmword, xmmword) -> xmmword
function avx_vpermilps_128(src, ctrl) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo = i * 32;
    r[(lo + 31)..lo] = velem(32, src, velem(32, ctrl, i)[1..0]);
  };
  r
}

val avx_vpermilps : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), bits('vl)) -> bits('vl)
function avx_vpermilps(vl, src, ctrl) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) {
    let lo = i * 128;
    r[(lo + 127)..lo] = avx_vpermilps_128(velem(128, src, i), velem(128, ctrl, i))
  };
  r
}

// VPERMILPD (register control): per-element select within 128-bit lane
// Each qword in ctrl: bit 1 selects low(0) or high(1) qword from lane
val avx_vpermilpd_128 : (xmmword, xmmword) -> xmmword
function avx_vpermilpd_128(src, ctrl) = {
  let lo : bits(64) = blend(src[63..0], src[127..64], ctrl[1]);
  let hi : bits(64) = blend(src[63..0], src[127..64], ctrl[65]);
  hi @ lo
}

val avx_vpermilpd : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), bits('vl)) -> bits('vl)
function avx_vpermilpd(vl, src, ctrl) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) {
    let lo = i * 128;
    r[(lo + 127)..lo] = avx_vpermilpd_128(velem(128, src, i), velem(128, ctrl, i))
  };
  r
}

// Full cross-lane permute of dwords using index register.
// Used for VPERMPS/VPERMD (identical at data level).
val avx_vpermd_256 : (ymmword, ymmword) -> ymmword
function avx_vpermd_256(src, idx) = {
  var r : ymmword = zeros();
  foreach (i from 0 to 7) {
    let lo = i * 32;
    r[(lo + 31)..lo] = velem(32, src, velem(32, idx, i)[2..0])
  };
  r
}

val avx_vpermd_512 : (zmmword, zmmword) -> zmmword
function avx_vpermd_512(src, idx) = {
  var r : zmmword = zeros();
  foreach (i from 0 to 15) {
    let lo = i * 32;
    r[(lo + 31)..lo] = velem(32, src, velem(32, idx, i)[3..0])
  };
  r
}

// Full cross-lane permute of qwords using index register.
// Used for VPERMPD/VPERMQ (identical at data level).
val avx_vpermq_256 : (ymmword, ymmword) -> ymmword
function avx_vpermq_256(src, idx) = {
  var r : ymmword = zeros();
  foreach (i from 0 to 3) {
    let lo = i * 64;
    r[(lo + 63)..lo] = velem(64, src, velem(64, idx, i)[1..0])
  };
  r
}

val avx_vpermq_512 : (zmmword, zmmword) -> zmmword
function avx_vpermq_512(src, idx) = {
  var r : zmmword = zeros();
  foreach (i from 0 to 7) {
    let lo = i * 64;
    r[(lo + 63)..lo] = velem(64, src, velem(64, idx, i)[2..0])
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
    let lo = i * 32;
    r[(lo + 31)..lo] = velem(32, combined, velem(32, idx, i)[2..0])
  };
  r
}

val avx_vperm2_d_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_vperm2_d_256(t1, t2, idx) = {
  let combined : zmmword = t2 @ t1;
  var r : ymmword = zeros();
  foreach (i from 0 to 7) {
    let lo = i * 32;
    r[(lo + 31)..lo] = velem(32, combined, velem(32, idx, i)[3..0])
  };
  r
}

val avx_vperm2_d_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_vperm2_d_512(t1, t2, idx) = {
  let combined : bits(1024) = t2 @ t1;
  var r : zmmword = zeros();
  foreach (i from 0 to 15) {
    let lo = i * 32;
    r[(lo + 31)..lo] = velem(32, combined, velem(32, idx, i)[4..0])
  };
  r
}

val avx_vperm2_q_128 : (xmmword, xmmword, xmmword) -> xmmword
function avx_vperm2_q_128(t1, t2, idx) = {
  let combined : bits(256) = t2 @ t1;
  var r : xmmword = zeros();
  foreach (i from 0 to 1) {
    let lo = i * 64;
    r[(lo + 63)..lo] = velem(64, combined, velem(64, idx, i)[1..0])
  };
  r
}

val avx_vperm2_q_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_vperm2_q_256(t1, t2, idx) = {
  let combined : zmmword = t2 @ t1;
  var r : ymmword = zeros();
  foreach (i from 0 to 3) {
    let lo = i * 64;
    r[(lo + 63)..lo] = velem(64, combined, velem(64, idx, i)[2..0])
  };
  r
}

val avx_vperm2_q_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_vperm2_q_512(t1, t2, idx) = {
  let combined : bits(1024) = t2 @ t1;
  var r : zmmword = zeros();
  foreach (i from 0 to 7) {
    let lo = i * 64;
    r[(lo + 63)..lo] = velem(64, combined, velem(64, idx, i)[3..0])
  };
  r
}

/* ---- Packed FMA helpers ---- */

val avx_vperm2_w_128 : (xmmword, xmmword, xmmword) -> xmmword
function avx_vperm2_w_128(t1, t2, idx) = {
  let combined : bits(256) = t2 @ t1;
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo = i * 16;
    r[(lo + 15)..lo] = velem(16, combined, velem(16, idx, i)[3..0])
  };
  r
}

val avx_vperm2_w_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_vperm2_w_256(t1, t2, idx) = {
  let combined : zmmword = t2 @ t1;
  var r : ymmword = zeros();
  foreach (i from 0 to 15) {
    let lo = i * 16;
    r[(lo + 15)..lo] = velem(16, combined, velem(16, idx, i)[4..0])
  };
  r
}

val avx_vperm2_w_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_vperm2_w_512(t1, t2, idx) = {
  let combined : bits(1024) = t2 @ t1;
  var r : zmmword = zeros();
  foreach (i from 0 to 31) {
    let lo = i * 16;
    r[(lo + 15)..lo] = velem(16, combined, velem(16, idx, i)[5..0])
  };
  r
}

/* ---- VPERMW: single-source word permute ---- */

val avx_vpermw_128 : (xmmword, xmmword) -> xmmword
function avx_vpermw_128(src, idx) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo = i * 16;
    r[(lo + 15)..lo] = velem(16, src, velem(16, idx, i)[2..0])
  };
  r
}

val avx_vpermw_256 : (ymmword, ymmword) -> ymmword
function avx_vpermw_256(src, idx) = {
  var r : ymmword = zeros();
  foreach (i from 0 to 15) {
    let lo = i * 16;
    r[(lo + 15)..lo] = velem(16, src, velem(16, idx, i)[3..0])
  };
  r
}

val avx_vpermw_512 : (zmmword, zmmword) -> zmmword
function avx_vpermw_512(src, idx) = {
  var r : zmmword = zeros();
  foreach (i from 0 to 31) {
    let lo = i * 16;
    r[(lo + 15)..lo] = velem(16, src, velem(16, idx, i)[4..0])
  };
  r
}

/* ---- 2-source byte permute (VPERMI2B/VPERMT2B) ---- */

val avx_vperm2_b_128 : (xmmword, xmmword, xmmword) -> xmmword
function avx_vperm2_b_128(t1, t2, idx) = {
  let combined : bits(256) = t2 @ t1;
  var r : xmmword = zeros();
  foreach (i from 0 to 15) {
    let lo = i * 8;
    r[(lo + 7)..lo] = velem(8, combined, velem(8, idx, i)[4..0])
  };
  r
}

val avx_vperm2_b_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_vperm2_b_256(t1, t2, idx) = {
  let combined : zmmword = t2 @ t1;
  var r : ymmword = zeros();
  foreach (i from 0 to 31) {
    let lo = i * 8;
    r[(lo + 7)..lo] = velem(8, combined, velem(8, idx, i)[5..0])
  };
  r
}

val avx_vperm2_b_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_vperm2_b_512(t1, t2, idx) = {
  let combined : bits(1024) = t2 @ t1;
  var r : zmmword = zeros();
  foreach (i from 0 to 63) {
    let lo = i * 8;
    r[(lo + 7)..lo] = velem(8, combined, velem(8, idx, i)[6..0])
  };
  r
}

/* ---- VPERMB: single-source byte permute ---- */

val avx_vpermb_128 : (xmmword, xmmword) -> xmmword
function avx_vpermb_128(src, idx) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 15) {
    let lo = i * 8;
    r[(lo + 7)..lo] = velem(8, src, velem(8, idx, i)[3..0])
  };
  r
}

val avx_vpermb_256 : (ymmword, ymmword) -> ymmword
function avx_vpermb_256(src, idx) = {
  var r : ymmword = zeros();
  foreach (i from 0 to 31) {
    let lo = i * 8;
    r[(lo + 7)..lo] = velem(8, src, velem(8, idx, i)[4..0])
  };
  r
}

val avx_vpermb_512 : (zmmword, zmmword) -> zmmword
function avx_vpermb_512(src, idx) = {
  var r : zmmword = zeros();
  foreach (i from 0 to 63) {
    let lo = i * 8;
    r[(lo + 7)..lo] = velem(8, src, velem(8, idx, i)[5..0])
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

val avx_vpshufbitqmb_lane : (qword, qword) -> byte
function avx_vpshufbitqmb_lane(ctrl, src) = {
  var r : byte = zeros();
  foreach (i from 0 to 7) {
    let bit_idx : range(0, 63) = unsigned(velem(8, ctrl, i)[5..0]);
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
    let src = modrm_xrm_evex(modrm, pfx, 4);
    let elem : dword = decode_scalar_src(32, src);
    let vl = evex_vl(pfx);
    evex_write(dst, evex_wmask(pfx, vl / 32), broadcast(vl, elem))
  },

  // 0F38 19: VBROADCASTSD (66 prefix, W=1)
  25 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, 8);
    let elem : qword = decode_scalar_src(64, src);
    let vl = evex_vl(pfx);
    evex_write(dst, evex_wmask(pfx, vl / 64), broadcast(vl, elem))
  },

  // 0F38 7B: VPBROADCASTW (66,W0) [BW] — from GPR
  // 0F38 7B: VPBROADCASTW (66,W0) [BW] — from GPR
  123 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let elem : word = v(32, modrm_rm_reg(modrm, pfx))[15..0];
    let vl = evex_vl(pfx);
    evex_write(dst, evex_wmask(pfx, vl / 16), broadcast(vl, elem))
  },

  // 0F38 7C: VPBROADCASTD (66 prefix, W=0)
  // 0F38 7C: VPBROADCASTD (66 prefix, W=0)
  124 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, 4);
    let elem : dword = v(src);
    let vl = evex_vl(pfx);
    evex_write(dst, evex_wmask(pfx, vl / 32), broadcast(vl, elem))
  },

  // 0F38 58: VPBROADCASTD (66,W0) [F] — from XMM/mem
  88 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, 4);
    let elem : dword = decode_scalar_src(32, src);
    let vl = evex_vl(pfx);
    evex_write(dst, evex_wmask(pfx, vl / 32), broadcast(vl, elem))
  },

  // 0F38 59: VPBROADCASTQ (66,W1) [F] — from XMM/mem
  // 0F38 59: VPBROADCASTQ (66,W1) [F] — from XMM/mem
  89 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, 8);
    let elem : qword = decode_scalar_src(64, src);
    let vl = evex_vl(pfx);
    evex_write(dst, evex_wmask(pfx, vl / 64), broadcast(vl, elem))
  },

  // 0F38 78: VPBROADCASTB (66,W0) [BW] — from XMM/mem
  // 0F38 78: VPBROADCASTB (66,W0) [BW] — from XMM/mem
  120 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, 4);
    let elem : byte = decode_scalar_src(src);
    let vl = evex_vl(pfx);
    evex_write(dst, evex_wmask(pfx, vl / 8), broadcast(vl, elem))
  },

  // 0F38 79: VPBROADCASTW (66,W0) [BW] — from XMM/mem
  121 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, 4);
    let elem : word = decode_scalar_src(16, src);
    let vl = evex_vl(pfx);
    evex_write(dst, evex_wmask(pfx, vl / 16), broadcast(vl, elem))
  },

  // 0F38 1A: VBROADCASTF32X4 (66,W0) / VBROADCASTF64X2 (66,W1) [F]
  // 0F38 1A: VBROADCASTF32X4 (66,W0) / VBROADCASTF64X2 (66,W1) [F]
  26 => {
    if mp != MP_66 then raise_UD();
    let (dst, src) = fetch_modrm_evex(pfx, 16);
    let src : xmmword = match src { XRM_mem(m) => read_mem(m), _ => raise_UD() };
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
    let src : ymmword = match src { XRM_mem(m) => read_mem(m), _ => raise_UD() };
    if pfx.rex_w then evex_write(dst, evex_wmask(pfx, 8), src @ src)
    else evex_write(dst, evex_wmask(pfx, 16), src @ src)
  },

  // 0F38 5A: VBROADCASTI32X4 (66,W0) / VBROADCASTI64X2 (66,W1) [F]
  // 0F38 5A: VBROADCASTI32X4 (66,W0) / VBROADCASTI64X2 (66,W1) [F]
  90 => {
    if mp != MP_66 then raise_UD();
    let (dst, src) = fetch_modrm_evex(pfx, 16);
    let src : xmmword = match src { XRM_mem(m) => read_mem(m), _ => raise_UD() };
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
    let src : ymmword = match src { XRM_mem(m) => read_mem(m), _ => raise_UD() };
    if pfx.rex_w then evex_write(dst, evex_wmask(pfx, 8), src @ src)
    else evex_write(dst, evex_wmask(pfx, 16), src @ src)
  },

  // 0F38 3A: VPMINUW (66) [BW] / VPBROADCASTMW2D (F3,W0) [CD]
  58 => {
    if mp == MP_66 then {
      // VPMINUW: packed minimum of unsigned words
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let src1_idx = pfx.evex_vvvvv;
      let vl = evex_vl(pfx);
      let mask = evex_wmask(pfx, vl / 16);
      evex_write(dst, mask, packed_binop(PB_MinU, 16, read_simd(vl, src1_idx), evex_src(vl, src)))
    } else if mp == MP_F3 then {
      if ~(pfx.rex_w) then {
        // VPBROADCASTMW2D: broadcast low word of k-register to all dword elements
        let modrm = fetch(1);
        let dst = evex_reg_idx(modrm, pfx);
        let k_idx : kreg_idx = unsigned(modrm[2..0]);
        let k_val = read_kreg(k_idx);
        let w : word = k_val[15..0];
        let d : dword = zero_extend(w);
        let vl = evex_vl(pfx);
        evex_write(dst, evex_wmask(pfx, vl / 32), broadcast(vl, d))
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
    let vl = evex_vl(pfx);
    evex_write(dst, evex_wmask(pfx, vl / 8), broadcast(vl, elem))
  },

  // 0F38 0C: VPERMILPS (66,W0) — register control [F]
  // 0F38 0C: VPERMILPS (66,W0) — register control [F]
  12 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));

    let src1_idx = pfx.evex_vvvvv;
    let vl = evex_vl(pfx);
    evex_write(dst, evex_wmask(pfx, vl / 32), avx_vpermilps(read_simd(vl, src1_idx), evex_bcast_src(vl, src, pfx, 32)))
  },

  // 0F38 0D: VPERMILPD (66,W1) — register control [F]
  // 0F38 0D: VPERMILPD (66,W1) — register control [F]
  13 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));

    let src1_idx = pfx.evex_vvvvv;
    let vl = evex_vl(pfx);
    evex_write(dst, evex_wmask(pfx, vl / 64), avx_vpermilpd(read_simd(vl, src1_idx), evex_bcast_src(vl, src, pfx, 64)))
  },

  // 0F38 16: VPERMPS (66,W0) / VPERMPD (66,W1) [F]
  // 0F38 36: VPERMD (66,W0) / VPERMQ (66,W1) [F]
  // FP and integer permutes are identical at the data level.
  op if op == 22 | op == 54 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let idx_reg = pfx.evex_vvvvv;
    match (pfx.rex_w, pfx.evex_ll) {
      (true, 1)  => evex_write(dst, evex_wmask(pfx, 4), avx_vpermq_256(evex_bcast_src(256, src, pfx, 64), read_simd(256, idx_reg))),
      (true, 2)  => evex_write(dst, evex_wmask(pfx, 8), avx_vpermq_512(evex_bcast_src(512, src, pfx, 64), ZMM[idx_reg])),
      (false, 1) => evex_write(dst, evex_wmask(pfx, 8), avx_vpermd_256(evex_bcast_src(256, src, pfx, 32), read_simd(256, idx_reg))),
      (false, 2) => evex_write(dst, evex_wmask(pfx, 16), avx_vpermd_512(evex_bcast_src(512, src, pfx, 32), ZMM[idx_reg])),
      _ => raise_UD(),
    }
  },

  // 0F38 00: VPSHUFB (66) [BW]
  // 0F38 00: VPSHUFB (66) [BW]
  0 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let src1_idx = pfx.evex_vvvvv;
    let vl = evex_vl(pfx);
    evex_write(dst, evex_wmask(pfx, vl / 8), packed_binop(PB_Pshufb, 128, read_simd(vl, src1_idx), evex_src(vl, src)))
  },

  // 0F38 75: VPERMI2B (66,W0) [VBMI] / VPERMI2W (66,W1) [BW]
  117 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let src1_idx = pfx.evex_vvvvv;
    match (pfx.rex_w, pfx.evex_ll) {
      // VPERMI2W
      (true, 0) => { let idx : xmmword = read_simd(dst); evex_write(dst, evex_wmask(pfx, 8), avx_vperm2_w_128(read_simd(src1_idx), evex_src(128, src), idx)) },
      (true, 1) => { let idx = read_simd(256, dst); evex_write(dst, evex_wmask(pfx, 16), avx_vperm2_w_256(read_simd(256, src1_idx), evex_src(256, src), idx)) },
      (true, 2) => { let idx = ZMM[dst]; evex_write(dst, evex_wmask(pfx, 32), avx_vperm2_w_512(ZMM[src1_idx], evex_src(512, src), idx)) },
      // VPERMI2B
      (false, 0) => { let idx : xmmword = read_simd(dst); evex_write(dst, evex_wmask(pfx, 16), avx_vperm2_b_128(read_simd(src1_idx), evex_src(128, src), idx)) },
      (false, 1) => { let idx = read_simd(256, dst); evex_write(dst, evex_wmask(pfx, 32), avx_vperm2_b_256(read_simd(256, src1_idx), evex_src(256, src), idx)) },
      (false, 2) => { let idx = ZMM[dst]; evex_write(dst, evex_wmask(pfx, 64), avx_vperm2_b_512(ZMM[src1_idx], evex_src(512, src), idx)) },
      _ => raise_UD(),
    }
  },

  // 0F38 76: VPERMI2D (66,W0) / VPERMI2Q (66,W1) [F]
  118 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));

    let src1_idx = pfx.evex_vvvvv;
    match (pfx.rex_w, pfx.evex_ll) {
      // VPERMI2Q
      (true, 0) => { let idx : xmmword = read_simd(dst); evex_write(dst, evex_wmask(pfx, 2), avx_vperm2_q_128(read_simd(src1_idx), evex_bcast_src(128, src, pfx, 64), idx)) },
      (true, 1) => { let idx = read_simd(256, dst); evex_write(dst, evex_wmask(pfx, 4), avx_vperm2_q_256(read_simd(256, src1_idx), evex_bcast_src(256, src, pfx, 64), idx)) },
      (true, 2) => { let idx = ZMM[dst]; evex_write(dst, evex_wmask(pfx, 8), avx_vperm2_q_512(ZMM[src1_idx], evex_bcast_src(512, src, pfx, 64), idx)) },
      // VPERMI2D
      (false, 0) => { let idx : xmmword = read_simd(dst); evex_write(dst, evex_wmask(pfx, 4), avx_vperm2_d_128(read_simd(src1_idx), evex_bcast_src(128, src, pfx, 32), idx)) },
      (false, 1) => { let idx = read_simd(256, dst); evex_write(dst, evex_wmask(pfx, 8), avx_vperm2_d_256(read_simd(256, src1_idx), evex_bcast_src(256, src, pfx, 32), idx)) },
      (false, 2) => { let idx = ZMM[dst]; evex_write(dst, evex_wmask(pfx, 16), avx_vperm2_d_512(ZMM[src1_idx], evex_bcast_src(512, src, pfx, 32), idx)) },
      _ => raise_UD(),
    }
  },

  // 0F38 77: VPERMI2PS (66,W0) / VPERMI2PD (66,W1) [F]
  // 0F38 77: VPERMI2PS (66,W0) / VPERMI2PD (66,W1) [F]
  119 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));

    let src1_idx = pfx.evex_vvvvv;
    match (pfx.rex_w, pfx.evex_ll) {
      // VPERMI2PD (same as Q)
      (true, 0) => { let idx : xmmword = read_simd(dst); evex_write(dst, evex_wmask(pfx, 2), avx_vperm2_q_128(read_simd(src1_idx), evex_bcast_src(128, src, pfx, 64), idx)) },
      (true, 1) => { let idx = read_simd(256, dst); evex_write(dst, evex_wmask(pfx, 4), avx_vperm2_q_256(read_simd(256, src1_idx), evex_bcast_src(256, src, pfx, 64), idx)) },
      (true, 2) => { let idx = ZMM[dst]; evex_write(dst, evex_wmask(pfx, 8), avx_vperm2_q_512(ZMM[src1_idx], evex_bcast_src(512, src, pfx, 64), idx)) },
      // VPERMI2PS (same as D)
      (false, 0) => { let idx : xmmword = read_simd(dst); evex_write(dst, evex_wmask(pfx, 4), avx_vperm2_d_128(read_simd(src1_idx), evex_bcast_src(128, src, pfx, 32), idx)) },
      (false, 1) => { let idx = read_simd(256, dst); evex_write(dst, evex_wmask(pfx, 8), avx_vperm2_d_256(read_simd(256, src1_idx), evex_bcast_src(256, src, pfx, 32), idx)) },
      (false, 2) => { let idx = ZMM[dst]; evex_write(dst, evex_wmask(pfx, 16), avx_vperm2_d_512(ZMM[src1_idx], evex_bcast_src(512, src, pfx, 32), idx)) },
      _ => raise_UD(),
    }
  },

  // 0F38 7E: VPERMT2D (66,W0) / VPERMT2Q (66,W1) [F]
  // 0F38 7E: VPERMT2D (66,W0) / VPERMT2Q (66,W1) [F]
  126 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));

    let idx_reg = pfx.evex_vvvvv;
    match (pfx.rex_w, pfx.evex_ll) {
      // VPERMT2Q
      (true, 0) => evex_write(dst, evex_wmask(pfx, 2), avx_vperm2_q_128(read_simd(dst), evex_bcast_src(128, src, pfx, 64), read_simd(idx_reg))),
      (true, 1) => evex_write(dst, evex_wmask(pfx, 4), avx_vperm2_q_256(read_simd(256, dst), evex_bcast_src(256, src, pfx, 64), read_simd(256, idx_reg))),
      (true, 2) => evex_write(dst, evex_wmask(pfx, 8), avx_vperm2_q_512(ZMM[dst], evex_bcast_src(512, src, pfx, 64), ZMM[idx_reg])),
      // VPERMT2D
      (false, 0) => evex_write(dst, evex_wmask(pfx, 4), avx_vperm2_d_128(read_simd(dst), evex_bcast_src(128, src, pfx, 32), read_simd(idx_reg))),
      (false, 1) => evex_write(dst, evex_wmask(pfx, 8), avx_vperm2_d_256(read_simd(256, dst), evex_bcast_src(256, src, pfx, 32), read_simd(256, idx_reg))),
      (false, 2) => evex_write(dst, evex_wmask(pfx, 16), avx_vperm2_d_512(ZMM[dst], evex_bcast_src(512, src, pfx, 32), ZMM[idx_reg])),
      _ => raise_UD(),
    }
  },

  // 0F38 7F: VPERMT2PS (66,W0) / VPERMT2PD (66,W1) [F]
  // 0F38 7F: VPERMT2PS (66,W0) / VPERMT2PD (66,W1) [F]
  127 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));

    let idx_reg = pfx.evex_vvvvv;
    match (pfx.rex_w, pfx.evex_ll) {
      // VPERMT2PD
      (true, 0) => evex_write(dst, evex_wmask(pfx, 2), avx_vperm2_q_128(read_simd(dst), evex_bcast_src(128, src, pfx, 64), read_simd(idx_reg))),
      (true, 1) => evex_write(dst, evex_wmask(pfx, 4), avx_vperm2_q_256(read_simd(256, dst), evex_bcast_src(256, src, pfx, 64), read_simd(256, idx_reg))),
      (true, 2) => evex_write(dst, evex_wmask(pfx, 8), avx_vperm2_q_512(ZMM[dst], evex_bcast_src(512, src, pfx, 64), ZMM[idx_reg])),
      // VPERMT2PS
      (false, 0) => evex_write(dst, evex_wmask(pfx, 4), avx_vperm2_d_128(read_simd(dst), evex_bcast_src(128, src, pfx, 32), read_simd(idx_reg))),
      (false, 1) => evex_write(dst, evex_wmask(pfx, 8), avx_vperm2_d_256(read_simd(256, dst), evex_bcast_src(256, src, pfx, 32), read_simd(256, idx_reg))),
      (false, 2) => evex_write(dst, evex_wmask(pfx, 16), avx_vperm2_d_512(ZMM[dst], evex_bcast_src(512, src, pfx, 32), ZMM[idx_reg])),
      _ => raise_UD(),
    }
  },

  // 0F38 35: VPMOVZXDQ (66) [F] / VPMOVQD (F3) [F]
  // 0F38 7D: VPERMT2W (66,W1) [BW] / VPERMT2B (66,W0) [VBMI]
  125 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let idx_reg = pfx.evex_vvvvv;
    match (pfx.rex_w, pfx.evex_ll) {
      // VPERMT2W
      (true, 0) => evex_write(dst, evex_wmask(pfx, 8), avx_vperm2_w_128(read_simd(dst), evex_src(128, src), read_simd(idx_reg))),
      (true, 1) => evex_write(dst, evex_wmask(pfx, 16), avx_vperm2_w_256(read_simd(256, dst), evex_src(256, src), read_simd(256, idx_reg))),
      (true, 2) => evex_write(dst, evex_wmask(pfx, 32), avx_vperm2_w_512(ZMM[dst], evex_src(512, src), ZMM[idx_reg])),
      // VPERMT2B
      (false, 0) => evex_write(dst, evex_wmask(pfx, 16), avx_vperm2_b_128(read_simd(dst), evex_src(128, src), read_simd(idx_reg))),
      (false, 1) => evex_write(dst, evex_wmask(pfx, 32), avx_vperm2_b_256(read_simd(256, dst), evex_src(256, src), read_simd(256, idx_reg))),
      (false, 2) => evex_write(dst, evex_wmask(pfx, 64), avx_vperm2_b_512(ZMM[dst], evex_src(512, src), ZMM[idx_reg])),
      _ => raise_UD(),
    }
  },

  // 0F38 62: VPEXPANDB (66,W0) / VPEXPANDW (66,W1) [VBMI2]
  98 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, 1);
    let k : qword = evex_kmask64(pfx);
    match (pfx.rex_w, pfx.evex_ll) {
      // VPEXPANDW
      (true, 0) => write_simd(128, dst, avx_vpexpandw_128(evex_src(128, src), k[7..0])),
      (true, 1) => write_simd(256, dst, avx_vpexpandw_256(evex_src(256, src), k[15..0])),
      (true, 2) => write_simd(512, dst, avx_vpexpandw_512(evex_src(512, src), k[31..0])),
      // VPEXPANDB
      (false, 0) => write_simd(128, dst, avx_vpexpandb_128(evex_src(128, src), k[15..0])),
      (false, 1) => write_simd(256, dst, avx_vpexpandb_256(evex_src(256, src), k[31..0])),
      (false, 2) => write_simd(512, dst, avx_vpexpandb_512(evex_src(512, src), k[63..0])),
      _ => raise_UD(),
    }
  },

  // 0F38 63: VPCOMPRESSB (66,W0) / VPCOMPRESSW (66,W1) [VBMI2]
  99 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let src = evex_reg_idx(modrm, pfx);
    let dest = modrm_xrm_evex(modrm, pfx, 1);
    let k : qword = evex_kmask64(pfx);
    match dest {
      XRM_reg(xi) => {
        let dst_reg = xi;
        match (pfx.rex_w, pfx.evex_ll) {
          // VPCOMPRESSW
          (true, 0) => write_simd(128, dst_reg, avx_vpcompressw_128(read_simd(128, src), k[7..0])),
          (true, 1) => write_simd(256, dst_reg, avx_vpcompressw_256(read_simd(256, src), k[15..0])),
          (true, 2) => write_simd(512, dst_reg, avx_vpcompressw_512(ZMM[src], k[31..0])),
          // VPCOMPRESSB
          (false, 0) => write_simd(128, dst_reg, avx_vpcompressb_128(read_simd(128, src), k[15..0])),
          (false, 1) => write_simd(256, dst_reg, avx_vpcompressb_256(read_simd(256, src), k[31..0])),
          (false, 2) => write_simd(512, dst_reg, avx_vpcompressb_512(ZMM[src], k[63..0])),
          _ => raise_UD(),
        }
      },
      XRM_mem(m) => {
        let a = seg_linear(m, 64);
        match (pfx.rex_w, pfx.evex_ll) {
          // VPCOMPRESSW mem
          (true, 0) => avx_vpcompressw_mem_128(a, read_simd(128, src), k[7..0]),
          (true, 1) => avx_vpcompressw_mem_256(a, read_simd(256, src), k[15..0]),
          (true, 2) => avx_vpcompressw_mem_512(a, ZMM[src], k[31..0]),
          // VPCOMPRESSB mem
          (false, 0) => avx_vpcompressb_mem_128(a, read_simd(128, src), k[15..0]),
          (false, 1) => avx_vpcompressb_mem_256(a, read_simd(256, src), k[31..0]),
          (false, 2) => avx_vpcompressb_mem_512(a, ZMM[src], k[63..0]),
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
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let ctrl = ZMM[pfx.evex_vvvvv];
    match (pfx.rex_w, pfx.evex_ll) {
      // VPERMW
      (true, 0) => evex_write(dst, evex_wmask(pfx, 8), avx_vpermw_128(evex_src(128, src), read_simd(pfx.evex_vvvvv))),
      (true, 1) => evex_write(dst, evex_wmask(pfx, 16), avx_vpermw_256(evex_src(256, src), read_simd(256, pfx.evex_vvvvv))),
      (true, 2) => evex_write(dst, evex_wmask(pfx, 32), avx_vpermw_512(evex_src(512, src), ctrl)),
      // VPERMB
      (false, 0) => evex_write(dst, evex_wmask(pfx, 16), avx_vpermb_128(evex_src(128, src), read_simd(pfx.evex_vvvvv))),
      (false, 1) => evex_write(dst, evex_wmask(pfx, 32), avx_vpermb_256(evex_src(256, src), read_simd(256, pfx.evex_vvvvv))),
      (false, 2) => evex_write(dst, evex_wmask(pfx, 64), avx_vpermb_512(evex_src(512, src), ctrl)),
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
      let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match src {
        XRM_reg(_) => raise_UD(),
        XRM_mem(_) => {
          match (pfx.rex_w, pfx.evex_ll) {
            (true, 0) => evex_write(dst, evex_wmask(pfx, 2), evex_src(128, src)),
            (true, 1) => evex_write(dst, evex_wmask(pfx, 4), evex_src(256, src)),
            (true, 2) => evex_write(dst, evex_wmask(pfx, 8), evex_src(512, src)),
            (false, 0) => evex_write(dst, evex_wmask(pfx, 4), evex_src(128, src)),
            (false, 1) => evex_write(dst, evex_wmask(pfx, 8), evex_src(256, src)),
            (false, 2) => evex_write(dst, evex_wmask(pfx, 16), evex_src(512, src)),
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
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    match pfx.evex_ll {
      0 => {
        let r = avx_vpshufbitqmb_128(read_simd(pfx.evex_vvvvv), evex_src(128, src));
        write_kreg(dst_k, zero_extend(r))
      },
      1 => {
        let r = avx_vpshufbitqmb_256(read_simd(256, pfx.evex_vvvvv), evex_src(256, src));
        write_kreg(dst_k, zero_extend(r))
      },
      2 => {
        let r = avx_vpshufbitqmb_512(ZMM[pfx.evex_vvvvv], evex_src(512, src));
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
      let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match (pfx.rex_w, pfx.evex_ll) {
        (true, 0) => evex_write(dst, evex_wmask(pfx, 2), evex_src(128, src)),
        (true, 1) => evex_write(dst, evex_wmask(pfx, 4), evex_src(256, src)),
        (true, 2) => evex_write(dst, evex_wmask(pfx, 8), evex_src(512, src)),
        (false, 0) => evex_write(dst, evex_wmask(pfx, 4), evex_src(128, src)),
        (false, 1) => evex_write(dst, evex_wmask(pfx, 8), evex_src(256, src)),
        (false, 2) => evex_write(dst, evex_wmask(pfx, 16), evex_src(512, src)),
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
    let src = modrm_xrm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
    let k : qword = evex_kmask64(pfx);
    match (pfx.rex_w, pfx.evex_ll) {
      // VEXPANDPD xmm1/ymm1/zmm1, xmm2/ymm2/zmm2/m128/m256/m512
      (true, 0) => write_simd(128, dst, avx_vexpandpd_128(evex_src(128, src), k[7..0])),
      (true, 1) => write_simd(256, dst, avx_vexpandpd_256(evex_src(256, src), k[7..0])),
      (true, 2) => write_simd(512, dst, avx_vexpandpd_512(evex_src(512, src), k[7..0])),
      // VEXPANDPS xmm1/ymm1/zmm1, xmm2/ymm2/zmm2/m128/m256/m512
      (false, 0) => write_simd(128, dst, avx_vexpandps_128(evex_src(128, src), k[7..0])),
      (false, 1) => write_simd(256, dst, avx_vexpandps_256(evex_src(256, src), k[7..0])),
      (false, 2) => write_simd(512, dst, avx_vexpandps_512(evex_src(512, src), k[15..0])),
      _ => raise_UD(),
    }
  },

  // 0F38 89: VPEXPANDD (66, W=0) / VPEXPANDQ (66, W=1) [F]
  // 0F38 89: VPEXPANDD (66, W=0) / VPEXPANDQ (66, W=1) [F]
  137 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
    let k : qword = evex_kmask64(pfx);
    match (pfx.rex_w, pfx.evex_ll) {
      // VPEXPANDQ — same as VEXPANDPD (qword elements)
      (true, 0) => write_simd(128, dst, avx_vexpandpd_128(evex_src(128, src), k[7..0])),
      (true, 1) => write_simd(256, dst, avx_vexpandpd_256(evex_src(256, src), k[7..0])),
      (true, 2) => write_simd(512, dst, avx_vexpandpd_512(evex_src(512, src), k[7..0])),
      // VPEXPANDD — same as VEXPANDPS (dword elements)
      (false, 0) => write_simd(128, dst, avx_vexpandps_128(evex_src(128, src), k[7..0])),
      (false, 1) => write_simd(256, dst, avx_vexpandps_256(evex_src(256, src), k[7..0])),
      (false, 2) => write_simd(512, dst, avx_vexpandps_512(evex_src(512, src), k[15..0])),
      _ => raise_UD(),
    }
  },

  // 0F38 8A: VCOMPRESSPS (66, W=0) / VCOMPRESSPD (66, W=1) [F]
  // SDM: reg=src, r/m=dst; memory form writes only compressed elements
  138 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let src = evex_reg_idx(modrm, pfx);
    let dest = modrm_xrm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
    let k : qword = evex_kmask64(pfx);
    match dest {
      XRM_reg(xi) => {
        let dst_reg = xi;
        match (pfx.rex_w, pfx.evex_ll) {
          (true, 0) => write_simd(128, dst_reg, avx_vcompresspd_128(read_simd(128, src), k[7..0])),
          (true, 1) => write_simd(256, dst_reg, avx_vcompresspd_256(read_simd(256, src), k[7..0])),
          (true, 2) => write_simd(512, dst_reg, avx_vcompresspd_512(ZMM[src], k[7..0])),
          (false, 0) => write_simd(128, dst_reg, avx_vcompressps_128(read_simd(128, src), k[7..0])),
          (false, 1) => write_simd(256, dst_reg, avx_vcompressps_256(read_simd(256, src), k[7..0])),
          (false, 2) => write_simd(512, dst_reg, avx_vcompressps_512(ZMM[src], k[15..0])),
          _ => raise_UD(),
        }
      },
      XRM_mem(m) => {
        let a = seg_linear(m, 64);
        match (pfx.rex_w, pfx.evex_ll) {
          (true, 0) => avx_vcompress_qword_mem_128(a, read_simd(128, src), k[7..0]),
          (true, 1) => avx_vcompress_qword_mem_256(a, read_simd(256, src), k[7..0]),
          (true, 2) => avx_vcompress_qword_mem_512(a, ZMM[src], k[7..0]),
          (false, 0) => avx_vcompress_dword_mem_128(a, read_simd(128, src), k[7..0]),
          (false, 1) => avx_vcompress_dword_mem_256(a, read_simd(256, src), k[7..0]),
          (false, 2) => avx_vcompress_dword_mem_512(a, ZMM[src], k[15..0]),
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
    let dest = modrm_xrm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
    let k : qword = evex_kmask64(pfx);
    match dest {
      XRM_reg(xi) => {
        let dst_reg = xi;
        match (pfx.rex_w, pfx.evex_ll) {
          (true, 0) => write_simd(128, dst_reg, avx_vcompresspd_128(read_simd(128, src), k[7..0])),
          (true, 1) => write_simd(256, dst_reg, avx_vcompresspd_256(read_simd(256, src), k[7..0])),
          (true, 2) => write_simd(512, dst_reg, avx_vcompresspd_512(ZMM[src], k[7..0])),
          (false, 0) => write_simd(128, dst_reg, avx_vcompressps_128(read_simd(128, src), k[7..0])),
          (false, 1) => write_simd(256, dst_reg, avx_vcompressps_256(read_simd(256, src), k[7..0])),
          (false, 2) => write_simd(512, dst_reg, avx_vcompressps_512(ZMM[src], k[15..0])),
          _ => raise_UD(),
        }
      },
      XRM_mem(m) => {
        let a = seg_linear(m, 64);
        match (pfx.rex_w, pfx.evex_ll) {
          (true, 0) => avx_vcompress_qword_mem_128(a, read_simd(128, src), k[7..0]),
          (true, 1) => avx_vcompress_qword_mem_256(a, read_simd(256, src), k[7..0]),
          (true, 2) => avx_vcompress_qword_mem_512(a, ZMM[src], k[7..0]),
          (false, 0) => avx_vcompress_dword_mem_128(a, read_simd(128, src), k[7..0]),
          (false, 1) => avx_vcompress_dword_mem_256(a, read_simd(256, src), k[7..0]),
          (false, 2) => avx_vcompress_dword_mem_512(a, ZMM[src], k[15..0]),
          _ => raise_UD(),
        }
      },
    }
  },

  // 0F38 64: VPBLENDMD (66,W0) / VPBLENDMQ (66,W1) — mask-controlled blend
  // Semantics: writemask selects src2 (mask=1) or merge/zero from src1 (mask=0).
  100 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    let src1 = read_simd(vl, pfx.evex_vvvvv);
    if pfx.rex_w then
      write_simd(vl, dst, apply_writemask(evex_wmask(pfx, vl / 64), evex_bcast_src(src, pfx, 64), src1))
    else
      write_simd(vl, dst, apply_writemask(evex_wmask(pfx, vl / 32), evex_bcast_src(src, pfx, 32), src1))
  },

  // 0F38 65: VBLENDMPS (66,W0) / VBLENDMPD (66,W1) — mask-controlled FP blend
  // Semantics: writemask selects src2 (mask=1) or merge/zero from src1 (mask=0).
  101 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    let src1 = read_simd(vl, pfx.evex_vvvvv);
    if pfx.rex_w then
      write_simd(vl, dst, apply_writemask(evex_wmask(pfx, vl / 64), evex_bcast_src(src, pfx, 64), src1))
    else
      write_simd(vl, dst, apply_writemask(evex_wmask(pfx, vl / 32), evex_bcast_src(src, pfx, 32), src1))
  },

  _ => raise_UD(),
  }
}

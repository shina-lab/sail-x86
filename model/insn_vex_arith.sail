// x86-64 — VEX Arithmetic/Misc (0F38 map)
//
// SSSE3, SSE4, broadcast, BMI, variable shifts, gather, test,
// maskmov, sign/zero-extend, permute.

// =========================================================================
// VEX 0F38 helpers — VTESTPS/PD, VMASKMOV, variable shifts, permute
// =========================================================================

// VMASKMOVPS load 128-bit: conditional load of dword lanes based on sign bit of mask
val vex_maskmovps_load_128 : (xmmword, xmmword) -> xmmword
function vex_maskmovps_load_128(mask, data) =
  blend(0x00000000, data[127..96], mask[127]) @
  blend(0x00000000, data[95..64],  mask[95]) @
  blend(0x00000000, data[63..32],  mask[63]) @
  blend(0x00000000, data[31..0],   mask[31])

val vex_maskmovps_load_256 : (ymmword, ymmword) -> ymmword
function vex_maskmovps_load_256(mask, data) =
  vex_maskmovps_load_128(mask[255..128], data[255..128]) @
  vex_maskmovps_load_128(mask[127..0], data[127..0])

// VMASKMOVPD load 128-bit: conditional load of qword lanes based on sign bit of mask
val vex_maskmovpd_load_128 : (xmmword, xmmword) -> xmmword
function vex_maskmovpd_load_128(mask, data) =
  blend(0x0000000000000000, data[127..64], mask[127]) @
  blend(0x0000000000000000, data[63..0],   mask[63])

val vex_maskmovpd_load_256 : (ymmword, ymmword) -> ymmword
function vex_maskmovpd_load_256(mask, data) =
  vex_maskmovpd_load_128(mask[255..128], data[255..128]) @
  vex_maskmovpd_load_128(mask[127..0], data[127..0])

// VMASKMOVPS store helpers: return (data_to_write, write_mask) pairs not needed;
// we write individual dwords/qwords conditionally in the dispatch code.

// VPERMPS/VPERMD 256-bit: permute 8 dwords using index vector
val vex_vpermd_256 : (ymmword, ymmword) -> ymmword
function vex_vpermd_256(ctrl, src) = {
  var result : ymmword = zeros();
  foreach (i from 0 to 7) {
    let idx : range(0, 7) = unsigned(ctrl[(i * 32 + 2) .. (i * 32)]);
    result[(i * 32 + 31) .. (i * 32)] = src[(idx * 32 + 31) .. (idx * 32)]
  };
  result
}

// VPSRLVD 128-bit: variable logical right shift, dword granularity
val vex_psrlvd_128 : (xmmword, xmmword) -> xmmword
function vex_psrlvd_128(data, shift) = {
  var result : xmmword = zeros();
  foreach (i from 0 to 3) {
    let count : range(0, 4294967295) = unsigned(shift[(i * 32 + 31) .. (i * 32)]);
    result[(i * 32 + 31) .. (i * 32)] = sail_shiftright(data[(i * 32 + 31) .. (i * 32)], count)
  };
  result
}

val vex_psrlvd_256 : (ymmword, ymmword) -> ymmword
function vex_psrlvd_256(data, shift) = {
  var result : ymmword = zeros();
  foreach (i from 0 to 7) {
    let count : range(0, 4294967295) = unsigned(shift[(i * 32 + 31) .. (i * 32)]);
    result[(i * 32 + 31) .. (i * 32)] = sail_shiftright(data[(i * 32 + 31) .. (i * 32)], count)
  };
  result
}

// VPSRLVQ 128-bit: variable logical right shift, qword granularity
val vex_psrlvq_128 : (xmmword, xmmword) -> xmmword
function vex_psrlvq_128(data, shift) = {
  var result : xmmword = zeros();
  foreach (i from 0 to 1) {
    let count : range(0, 4294967295) = unsigned(shift[(i * 64 + 31) .. (i * 64)]);
    result[(i * 64 + 63) .. (i * 64)] = sail_shiftright(data[(i * 64 + 63) .. (i * 64)], count)
  };
  result
}

val vex_psrlvq_256 : (ymmword, ymmword) -> ymmword
function vex_psrlvq_256(data, shift) = {
  var result : ymmword = zeros();
  foreach (i from 0 to 3) {
    let count : range(0, 4294967295) = unsigned(shift[(i * 64 + 31) .. (i * 64)]);
    result[(i * 64 + 63) .. (i * 64)] = sail_shiftright(data[(i * 64 + 63) .. (i * 64)], count)
  };
  result
}

// VPSRAVD 128-bit: variable arithmetic right shift, dword granularity
val vex_psravd_128 : (xmmword, xmmword) -> xmmword
function vex_psravd_128(data, shift) = {
  var result : xmmword = zeros();
  foreach (i from 0 to 3) {
    let count : range(0, 4294967295) = unsigned(shift[(i * 32 + 31) .. (i * 32)]);
    result[(i * 32 + 31) .. (i * 32)] = data[(i * 32 + 31) .. (i * 32)] >>> count
  };
  result
}

val vex_psravd_256 : (ymmword, ymmword) -> ymmword
function vex_psravd_256(data, shift) = {
  var result : ymmword = zeros();
  foreach (i from 0 to 7) {
    let count : range(0, 4294967295) = unsigned(shift[(i * 32 + 31) .. (i * 32)]);
    result[(i * 32 + 31) .. (i * 32)] = data[(i * 32 + 31) .. (i * 32)] >>> count
  };
  result
}

// VPSLLVD 128-bit: variable logical left shift, dword granularity
val vex_psllvd_128 : (xmmword, xmmword) -> xmmword
function vex_psllvd_128(data, shift) = {
  var result : xmmword = zeros();
  foreach (i from 0 to 3) {
    let count : range(0, 4294967295) = unsigned(shift[(i * 32 + 31) .. (i * 32)]);
    result[(i * 32 + 31) .. (i * 32)] = sail_shiftleft(data[(i * 32 + 31) .. (i * 32)], count)
  };
  result
}

val vex_psllvd_256 : (ymmword, ymmword) -> ymmword
function vex_psllvd_256(data, shift) = {
  var result : ymmword = zeros();
  foreach (i from 0 to 7) {
    let count : range(0, 4294967295) = unsigned(shift[(i * 32 + 31) .. (i * 32)]);
    result[(i * 32 + 31) .. (i * 32)] = sail_shiftleft(data[(i * 32 + 31) .. (i * 32)], count)
  };
  result
}

// VPSLLVQ 128-bit: variable logical left shift, qword granularity
val vex_psllvq_128 : (xmmword, xmmword) -> xmmword
function vex_psllvq_128(data, shift) = {
  var result : xmmword = zeros();
  foreach (i from 0 to 1) {
    let count : range(0, 4294967295) = unsigned(shift[(i * 64 + 31) .. (i * 64)]);
    result[(i * 64 + 63) .. (i * 64)] = sail_shiftleft(data[(i * 64 + 63) .. (i * 64)], count)
  };
  result
}

val vex_psllvq_256 : (ymmword, ymmword) -> ymmword
function vex_psllvq_256(data, shift) = {
  var result : ymmword = zeros();
  foreach (i from 0 to 3) {
    let count : range(0, 4294967295) = unsigned(shift[(i * 64 + 31) .. (i * 64)]);
    result[(i * 64 + 63) .. (i * 64)] = sail_shiftleft(data[(i * 64 + 63) .. (i * 64)], count)
  };
  result
}


val dispatch_vex_0f38_arith : (range(0, 255), Prefixes) -> unit
function dispatch_vex_0f38_arith(op, pfx) = {
  let mp = get_mandatory_prefix(pfx);

  match op {

  // 0F38 00: VPSHUFB xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  0 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = decode_rm(modrm, pfx);
    let src1_idx = pfx.vex_vvvv;
    if pfx.vex_l then {
      let src1 : ymmword = read_ymm(src1_idx);
      let src2 : ymmword = decode_vex_src_ymm(modrm, src, pfx);
      write_ymm(dst, vex_pshufb_256(src1, src2))
    } else {
      let src1 : xmmword = read_xmm(src1_idx);
      let src2 : xmmword = decode_vex_src_xmm(modrm, src, pfx);
      write_xmm(dst, vex_pshufb_128(src1, src2))
    }
  },

  // 0F38 01: VPHADDW xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  1 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = decode_rm(modrm, pfx);
    let src1_idx = pfx.vex_vvvv;
    if pfx.vex_l then {
      let src1 : ymmword = read_ymm(src1_idx);
      let src2 : ymmword = decode_vex_src_ymm(modrm, src, pfx);
      write_ymm(dst, avx_phaddw_256(src1, src2))
    } else {
      let src1 : xmmword = read_xmm(src1_idx);
      let src2 : xmmword = decode_vex_src_xmm(modrm, src, pfx);
      write_xmm(dst, avx_phaddw_128(src1, src2))
    }
  },

  // 0F38 02: VPHADDD xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  2 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = decode_rm(modrm, pfx);
    let src1_idx = pfx.vex_vvvv;
    if pfx.vex_l then {
      let src1 : ymmword = read_ymm(src1_idx);
      let src2 : ymmword = decode_vex_src_ymm(modrm, src, pfx);
      write_ymm(dst, avx_phaddd_256(src1, src2))
    } else {
      let src1 : xmmword = read_xmm(src1_idx);
      let src2 : xmmword = decode_vex_src_xmm(modrm, src, pfx);
      write_xmm(dst, avx_phaddd_128(src1, src2))
    }
  },

  // 0F38 03: VPHADDSW xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  3 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = decode_rm(modrm, pfx);
    let src1_idx = pfx.vex_vvvv;
    if pfx.vex_l then {
      let src1 : ymmword = read_ymm(src1_idx);
      let src2 : ymmword = decode_vex_src_ymm(modrm, src, pfx);
      write_ymm(dst, avx_phaddsw_256(src1, src2))
    } else {
      let src1 : xmmword = read_xmm(src1_idx);
      let src2 : xmmword = decode_vex_src_xmm(modrm, src, pfx);
      write_xmm(dst, avx_phaddsw_128(src1, src2))
    }
  },

  // 0F38 04: VPMADDUBSW xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  4 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = decode_rm(modrm, pfx);
    let src1_idx = pfx.vex_vvvv;
    if pfx.vex_l then {
      let src1 : ymmword = read_ymm(src1_idx);
      let src2 : ymmword = decode_vex_src_ymm(modrm, src, pfx);
      write_ymm(dst, vex_pmaddubsw_256(src1, src2))
    } else {
      let src1 : xmmword = read_xmm(src1_idx);
      let src2 : xmmword = decode_vex_src_xmm(modrm, src, pfx);
      write_xmm(dst, vex_pmaddubsw_128(src1, src2))
    }
  },

  // 0F38 05: VPHSUBW xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  5 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = decode_rm(modrm, pfx);
    let src1_idx = pfx.vex_vvvv;
    if pfx.vex_l then {
      let src1 : ymmword = read_ymm(src1_idx);
      let src2 : ymmword = decode_vex_src_ymm(modrm, src, pfx);
      write_ymm(dst, avx_phsubw_256(src1, src2))
    } else {
      let src1 : xmmword = read_xmm(src1_idx);
      let src2 : xmmword = decode_vex_src_xmm(modrm, src, pfx);
      write_xmm(dst, avx_phsubw_128(src1, src2))
    }
  },

  // 0F38 06: VPHSUBD xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  6 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = decode_rm(modrm, pfx);
    let src1_idx = pfx.vex_vvvv;
    if pfx.vex_l then {
      let src1 : ymmword = read_ymm(src1_idx);
      let src2 : ymmword = decode_vex_src_ymm(modrm, src, pfx);
      write_ymm(dst, avx_phsubd_256(src1, src2))
    } else {
      let src1 : xmmword = read_xmm(src1_idx);
      let src2 : xmmword = decode_vex_src_xmm(modrm, src, pfx);
      write_xmm(dst, avx_phsubd_128(src1, src2))
    }
  },

  // 0F38 07: VPHSUBSW xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  7 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = decode_rm(modrm, pfx);
    let src1_idx = pfx.vex_vvvv;
    if pfx.vex_l then {
      let src1 : ymmword = read_ymm(src1_idx);
      let src2 : ymmword = decode_vex_src_ymm(modrm, src, pfx);
      write_ymm(dst, avx_phsubsw_256(src1, src2))
    } else {
      let src1 : xmmword = read_xmm(src1_idx);
      let src2 : xmmword = decode_vex_src_xmm(modrm, src, pfx);
      write_xmm(dst, avx_phsubsw_128(src1, src2))
    }
  },

  // 0F38 08: VPSIGNB xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  8 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = decode_rm(modrm, pfx);
    let src1_idx = pfx.vex_vvvv;
    if pfx.vex_l then {
      let src1 : ymmword = read_ymm(src1_idx);
      let src2 : ymmword = decode_vex_src_ymm(modrm, src, pfx);
      write_ymm(dst, avx_psignb_256(src1, src2))
    } else {
      let src1 : xmmword = read_xmm(src1_idx);
      let src2 : xmmword = decode_vex_src_xmm(modrm, src, pfx);
      write_xmm(dst, avx_psignb_128(src1, src2))
    }
  },

  // 0F38 09: VPSIGNW xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  9 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = decode_rm(modrm, pfx);
    let src1_idx = pfx.vex_vvvv;
    if pfx.vex_l then {
      let src1 : ymmword = read_ymm(src1_idx);
      let src2 : ymmword = decode_vex_src_ymm(modrm, src, pfx);
      write_ymm(dst, avx_psignw_256(src1, src2))
    } else {
      let src1 : xmmword = read_xmm(src1_idx);
      let src2 : xmmword = decode_vex_src_xmm(modrm, src, pfx);
      write_xmm(dst, avx_psignw_128(src1, src2))
    }
  },

  // 0F38 0A: VPSIGND xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  10 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = decode_rm(modrm, pfx);
    let src1_idx = pfx.vex_vvvv;
    if pfx.vex_l then {
      let src1 : ymmword = read_ymm(src1_idx);
      let src2 : ymmword = decode_vex_src_ymm(modrm, src, pfx);
      write_ymm(dst, avx_psignd_256(src1, src2))
    } else {
      let src1 : xmmword = read_xmm(src1_idx);
      let src2 : xmmword = decode_vex_src_xmm(modrm, src, pfx);
      write_xmm(dst, avx_psignd_128(src1, src2))
    }
  },

  // 0F38 0B: VPMULHRSW xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  11 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = decode_rm(modrm, pfx);
    let src1_idx = pfx.vex_vvvv;
    if pfx.vex_l then {
      let src1 : ymmword = read_ymm(src1_idx);
      let src2 : ymmword = decode_vex_src_ymm(modrm, src, pfx);
      write_ymm(dst, vex_pmulhrsw_256(src1, src2))
    } else {
      let src1 : xmmword = read_xmm(src1_idx);
      let src2 : xmmword = decode_vex_src_xmm(modrm, src, pfx);
      write_xmm(dst, vex_pmulhrsw_128(src1, src2))
    }
  },

  // 0F38 18: VBROADCASTSS xmm1, xmm2/m32 (VEX.128/256)
  // SDM: VEX.vvvv must be 1111b
  24 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = decode_rm(modrm, pfx);
    let val32 : dword = match src {
      RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[31..0],
      RM_mem(m) => read_mem(m),
    };
    if pfx.vex_l then {
      // 256-bit: broadcast to 8 dwords
      write_ymm(dst, val32 @ val32 @ val32 @ val32 @
                     val32 @ val32 @ val32 @ val32)
    } else {
      // 128-bit: broadcast to 4 dwords
      write_xmm(dst, val32 @ val32 @ val32 @ val32)
    }
  },

  // 0F38 19: VBROADCASTSD ymm1, xmm2/m64 (VEX.256 only)
  // SDM: VEX.128 form #UDs, VEX.vvvv must be 1111b
  25 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    if ~(pfx.vex_l) then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = decode_rm(modrm, pfx);
    let val64 : qword = match src {
      RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[63..0],
      RM_mem(m) => read_mem(m),
    };
    write_ymm(dst, val64 @ val64 @ val64 @ val64)
  },

  // 0F38 1A: VBROADCASTF128 ymm1, m128 (VEX.256 only)
  // SDM: VEX.vvvv must be 1111b
  26 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    if ~(pfx.vex_l) then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = decode_rm(modrm, pfx);
    let v : xmmword = rm_mem(src);
    write_ymm(dst, v @ v)
  },

  // 0F38 78: VPBROADCASTB xmm/ymm, xmm/m8 (66 prefix)
  // SDM: VEX.vvvv must be 1111b
  120 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = decode_rm(modrm, pfx);
    let val8 : byte = match src {
      RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[7..0],
      RM_mem(m) => read_mem(m),
    };
    if pfx.vex_l then {
      write_ymm(dst, val8 @ val8 @ val8 @ val8 @ val8 @ val8 @ val8 @ val8 @
                     val8 @ val8 @ val8 @ val8 @ val8 @ val8 @ val8 @ val8 @
                     val8 @ val8 @ val8 @ val8 @ val8 @ val8 @ val8 @ val8 @
                     val8 @ val8 @ val8 @ val8 @ val8 @ val8 @ val8 @ val8)
    } else {
      write_xmm(dst, val8 @ val8 @ val8 @ val8 @ val8 @ val8 @ val8 @ val8 @
                     val8 @ val8 @ val8 @ val8 @ val8 @ val8 @ val8 @ val8)
    }
  },

  // 0F38 79: VPBROADCASTW xmm/ymm, xmm/m16 (66 prefix)
  // SDM: VEX.vvvv must be 1111b
  121 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = decode_rm(modrm, pfx);
    let val16 : word = match src {
      RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[15..0],
      RM_mem(m) => read_mem(m),
    };
    if pfx.vex_l then {
      write_ymm(dst, val16 @ val16 @ val16 @ val16 @ val16 @ val16 @ val16 @ val16 @
                     val16 @ val16 @ val16 @ val16 @ val16 @ val16 @ val16 @ val16)
    } else {
      write_xmm(dst, val16 @ val16 @ val16 @ val16 @ val16 @ val16 @ val16 @ val16)
    }
  },

  // 0F38 58: VPBROADCASTD xmm/ymm, xmm/m32 (66 prefix) — same as VBROADCASTSS but int
  // SDM: VEX.vvvv must be 1111b
  88 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = decode_rm(modrm, pfx);
    let val32 : dword = match src {
      RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[31..0],
      RM_mem(m) => read_mem(m),
    };
    if pfx.vex_l then {
      write_ymm(dst, val32 @ val32 @ val32 @ val32 @ val32 @ val32 @ val32 @ val32)
    } else {
      write_xmm(dst, val32 @ val32 @ val32 @ val32)
    }
  },

  // 0F38 59: VPBROADCASTQ xmm/ymm, xmm/m64 (66 prefix)
  // SDM: VEX.vvvv must be 1111b
  89 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = decode_rm(modrm, pfx);
    let val64 : qword = match src {
      RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[63..0],
      RM_mem(m) => read_mem(m),
    };
    if pfx.vex_l then {
      write_ymm(dst, val64 @ val64 @ val64 @ val64)
    } else {
      write_xmm(dst, val64 @ val64)
    }
  },

  // 0F38 5A: VBROADCASTI128 ymm, m128 (VEX.256 only, vvvv must be 1111b)
  90 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    if ~(pfx.vex_l) then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = decode_rm(modrm, pfx);
    let v : xmmword = rm_mem(src);
    write_ymm(dst, v @ v)
  },

  // 0F38 13: VCVTPH2PS xmm/ymm, xmm/m64/m128 (66 prefix)
  // SDM: VEX.vvvv must be 1111b
  19 => {
    if ~(has_f16c) then raise_UD();
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src2 = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      // 256-bit: 8 FP16 -> 8 FP32
      let src : xmmword = decode_vex_src_xmm(modrm, src2, pfx);
      write_ymm(dst, avx_vcvtph2ps_256(src))
    } else {
      // 128-bit: 4 FP16 -> 4 FP32
      let src : xmmword = decode_vex_src_xmm(modrm, src2, pfx);
      write_xmm(dst, avx_vcvtph2ps_128(src[63..0]))
    }
  },

  // 0F38 1C: VPABSB xmm/ymm, xmm/ymm/m (66 prefix)
  // SDM: VEX.vvvv must be 1111b
  28 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src2 = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let src : ymmword = decode_vex_src_ymm(modrm, src2, pfx);
      write_ymm(dst, vex_pabsb_256(src))
    } else {
      let src : xmmword = decode_vex_src_xmm(modrm, src2, pfx);
      write_xmm(dst, vex_pabsb_128(src))
    }
  },

  // 0F38 1D: VPABSW xmm/ymm, xmm/ymm/m (66 prefix)
  // SDM: VEX.vvvv must be 1111b
  29 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src2 = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let src : ymmword = decode_vex_src_ymm(modrm, src2, pfx);
      write_ymm(dst, vex_pabsw_256(src))
    } else {
      let src : xmmword = decode_vex_src_xmm(modrm, src2, pfx);
      write_xmm(dst, vex_pabsw_128(src))
    }
  },

  // 0F38 1E: VPABSD xmm/ymm, xmm/ymm/m (66 prefix)
  // SDM: VEX.vvvv must be 1111b
  30 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src2 = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let src : ymmword = decode_vex_src_ymm(modrm, src2, pfx);
      write_ymm(dst, vex_pabsd_256(src))
    } else {
      let src : xmmword = decode_vex_src_xmm(modrm, src2, pfx);
      write_xmm(dst, vex_pabsd_128(src))
    }
  },

  // 0F38 F2: ANDN (NP, VEX.NDS.LZ) — dest = ~vvvv & src
  242 => {
    if ~(has_bmi1) then raise_UD();
    if mp != MP_NONE then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_reg(modrm, pfx);
    let src2 = decode_rm(modrm, pfx);
    let os : {32, 64} = if pfx.vex_w then 64 else 32;
    let src = rm(os, src2);
    let v : gpr_idx = pfx.vex_vvvv % 16;
    let vval = reg(os, v);
    let result = ~(vval) & src;
    reg(dst) = result;
    SF = result[os - 1];
    ZF = is_zero(result);
    OF = 0b0;
    CF = 0b0
  },

  // 0F38 F3: BLSI/BLSMSK/BLSR (NP, VEX.NDD.LZ) — selected by modrm /reg
  243 => {
    if ~(has_bmi1) then raise_UD();
    if mp != MP_NONE then raise_UD();
    let modrm = fetch_byte();
    let reg_field : range(0, 7) = unsigned(modrm[5..3]);
    let src2 = decode_rm(modrm, pfx);
    let os : {16, 32, 64} = if pfx.vex_w then 64 else 32;
    let src = rm(os, src2);
    let dst : gpr_idx = pfx.vex_vvvv % 16;
    match reg_field {
      // BLSR: dest = (src - 1) & src
      1 => {
        let result = (src - 1) & src;
        reg(dst) = result;
        SF = result[os - 1];
        ZF = is_zero(result);
        CF = is_zero(src);
        OF = 0b0
      },
      // BLSMSK: dest = (src - 1) ^ src
      2 => {
        let result = (src - 1) ^ src;
        reg(dst) = result;
        SF = result[os - 1];
        ZF = 0b0;
        CF = is_zero(src);
        OF = 0b0
      },
      // BLSI: dest = (-src) & src (isolate lowest set bit)
      3 => {
        let result = (~(src) + 1) & src;
        reg(dst) = result;
        SF = result[os - 1];
        ZF = is_zero(result);
        CF = is_nonzero(src);
        OF = 0b0
      },
      _ => raise_UD(),
    }
  },

  // 0F38 DB: VAESIMC — VEX.128.66.0F38.WIG DB
  219 => {
    if ~(has_aesni) then raise_UD();
    if mp != MP_66 then raise_UD();
    if pfx.vex_l then raise_UD();
    if pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src2 = decode_rm(modrm, pfx);
    let src : xmmword = decode_vex_src_xmm(modrm, src2, pfx);
    write_xmm(dst, __aesimc(src))
  },

  // 0F38 DC: VAESENC — VEX.128.66.0F38.WIG DC
  220 => {
    if ~(has_aesni) then raise_UD();
    if mp != MP_66 then raise_UD();
    if pfx.vex_l then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = decode_rm(modrm, pfx);
    let state : xmmword = read_xmm(pfx.vex_vvvv);
    let roundkey : xmmword = decode_vex_src_xmm(modrm, src, pfx);
    write_xmm(dst, __aesenc(state, roundkey))
  },

  // 0F38 DD: VAESENCLAST — VEX.128.66.0F38.WIG DD
  221 => {
    if ~(has_aesni) then raise_UD();
    if mp != MP_66 then raise_UD();
    if pfx.vex_l then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = decode_rm(modrm, pfx);
    let state : xmmword = read_xmm(pfx.vex_vvvv);
    let roundkey : xmmword = decode_vex_src_xmm(modrm, src, pfx);
    write_xmm(dst, __aesenclast(state, roundkey))
  },

  // 0F38 DE: VAESDEC — VEX.128.66.0F38.WIG DE
  222 => {
    if ~(has_aesni) then raise_UD();
    if mp != MP_66 then raise_UD();
    if pfx.vex_l then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = decode_rm(modrm, pfx);
    let state : xmmword = read_xmm(pfx.vex_vvvv);
    let roundkey : xmmword = decode_vex_src_xmm(modrm, src, pfx);
    write_xmm(dst, __aesdec(state, roundkey))
  },

  // 0F38 DF: VAESDECLAST — VEX.128.66.0F38.WIG DF
  223 => {
    if ~(has_aesni) then raise_UD();
    if mp != MP_66 then raise_UD();
    if pfx.vex_l then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = decode_rm(modrm, pfx);
    let state : xmmword = read_xmm(pfx.vex_vvvv);
    let roundkey : xmmword = decode_vex_src_xmm(modrm, src, pfx);
    write_xmm(dst, __aesdeclast(state, roundkey))
  },

  // 0F38 F5: BZHI (NP) / PDEP (F2) / PEXT (F3) — multiplexed by mandatory prefix
  245 => {
    if ~(has_bmi2) then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_reg(modrm, pfx);
    let src2 = decode_rm(modrm, pfx);
    let os : {32, 64} = if pfx.vex_w then 64 else 32;
    match mp {
      MP_NONE => {
        // BZHI: VEX.NDS.LZ.0F38.W0/W1 F5
        // dest = src1 & ((1 << src2[7:0]) - 1), if index < operand size
        let src1 = rm(os, src2);
        let v : gpr_idx = pfx.vex_vvvv % 16;
        let src2 = reg(os, v);
        let index : range(0, 255) = unsigned(src2[7..0]);
        var result = zeros(os);
        if index >= os then {
          result = src1;
          CF = 0b1
        } else {
          let shift_amt : range(0, 255) = os - index;
          result = (src1 << shift_amt) >> shift_amt;
          CF = 0b0
        };
        reg(dst) = result;
        SF = result[os - 1];
        ZF = is_zero(result);
        OF = 0b0
      },
      MP_F2 => {
        // PDEP: VEX.NDS.LZ.F2.0F38.W0/W1 F5
        // Parallel bit deposit: scatter contiguous low bits of src to mask positions
        let src : qword = zero_extend(reg(os, pfx.vex_vvvv % 16));
        let mask : qword = zero_extend(rm(os, src2));
        var temp : qword = zeros();
        var k : range(0, 63) = 0;
        foreach (i from 0 to (os - 1)) {
          temp[i] = src[k] & mask[i];
          k = (k + unsigned(mask[i])) % 64
        };
        reg(dst) = temp[(os - 1) .. 0]
      },
      MP_F3 => {
        // PEXT: VEX.NDS.LZ.F3.0F38.W0/W1 F5
        // Parallel bit extract: gather bits at mask positions to contiguous low bits
        let src : qword = zero_extend(reg(os, pfx.vex_vvvv % 16));
        let mask : qword = zero_extend(rm(os, src2));
        var temp : qword = zeros();
        var k : range(0, 63) = 0;
        foreach (i from 0 to (os - 1)) {
          temp[k] = src[i] & mask[i];
          k = (k + unsigned(mask[i])) % 64
        };
        reg(dst) = temp[(os - 1) .. 0]
      },
      _ => raise_UD(),
    }
  },

  // 0F38 F6: MULX (F2, VEX.NDD.LZ) — unsigned multiply without affecting flags
  246 => {
    if ~(has_bmi2) then raise_UD();
    if mp != MP_F2 then raise_UD();
    let modrm = fetch_byte();
    let dst_hi = modrm_reg(modrm, pfx);
    let src = decode_rm(modrm, pfx);
    let os : {16, 32, 64} = if pfx.vex_w then 64 else 32;
    let dst_lo : gpr_idx = pfx.vex_vvvv % 16;
    // Implicit source is EDX/RDX
    let src1 = reg(os, RDX);
    let src2 = rm(os, src);
    let product = to_bits_truncate(os * 2, unsigned(src1) * unsigned(src2));
    reg(dst_lo) = product[(os - 1)..0];
    reg(dst_hi) = product[(os * 2 - 1)..os]
  },

  // 0F38 F7: BEXTR (NP) / SARX (F3) / SHLX (66) / SHRX (F2) — multiplexed by prefix
  247 => {
    if mp == MP_NONE then { if ~(has_bmi1) then raise_UD() }
    else { if ~(has_bmi2) then raise_UD() };
    let modrm = fetch_byte();
    let dst = modrm_reg(modrm, pfx);
    let src2 = decode_rm(modrm, pfx);
    let os : {16, 32, 64} = if pfx.vex_w then 64 else 32;
    match mp {
      MP_NONE => {
        // BEXTR: VEX.NDS.LZ.0F38 F7 — bit field extract
        let src = rm(os, src2);
        let v : gpr_idx = pfx.vex_vvvv % 16;
        let ctrl = reg(os, v);
        let start : range(0, 255) = unsigned(ctrl[7..0]);
        let len : range(0, 255) = unsigned(ctrl[15..8]);
        var result = zeros(os);
        if start < os then {
          let shifted = src >> start;
          if len >= os then {
            result = shifted
          } else {
            // Create mask with len low bits set
            let shift_amt : range(0, 255) = os - len;
            result = (shifted << shift_amt) >> shift_amt
          }
        };
        reg(dst) = result;
        ZF = is_zero(result);
        OF = 0b0;
        CF = 0b0
      },
      MP_F3 => {
        // SARX: VEX.NDS.LZ.F3.0F38.W0/W1 F7 — arithmetic right shift, no flags
        let src1 = rm(os, src2);
        let v : gpr_idx = pfx.vex_vvvv % 16;
        let count_val = reg(os, v);
        let count : range(0, 63) = if pfx.vex_w then unsigned(count_val[5..0])
                                    else unsigned(count_val[4..0]);
        reg(dst) = src1 >>> count
      },
      MP_66 => {
        // SHLX: VEX.NDS.LZ.66.0F38.W0/W1 F7 — logical left shift, no flags
        let src1 = rm(os, src2);
        let v : gpr_idx = pfx.vex_vvvv % 16;
        let count_val = reg(os, v);
        let count : range(0, 63) = if pfx.vex_w then unsigned(count_val[5..0])
                                    else unsigned(count_val[4..0]);
        reg(dst) = src1 << count
      },
      MP_F2 => {
        // SHRX: VEX.NDS.LZ.F2.0F38.W0/W1 F7 — logical right shift, no flags
        let src1 = rm(os, src2);
        let v : gpr_idx = pfx.vex_vvvv % 16;
        let count_val = reg(os, v);
        let count : range(0, 63) = if pfx.vex_w then unsigned(count_val[5..0])
                                    else unsigned(count_val[4..0]);
        reg(dst) = src1 >> count
      },
    }
  },

  // -----------------------------------------------------------------------
  // SSE4.1 sign/zero-extend, arithmetic, min/max (0F38 20..41)
  // -----------------------------------------------------------------------

  // 0F38 20: VPMOVSXBW (66 prefix, vvvv must be 1111b)
  // 128-bit: sign-extend 8 bytes (low qword) to 8 words
  // 256-bit: sign-extend 16 bytes (full xmm) to 16 words
  32 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src2 = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let src : xmmword = decode_vex_src_xmm(modrm, src2, pfx);
      write_ymm(dst, avx_pmovsxbw_256(src))
    } else {
      let src : qword = match src2 {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[63..0],
        RM_mem(m) => read_mem(m),
      };
      write_xmm(dst, avx_pmovsxbw_128(src))
    }
  },

  // 0F38 21: VPMOVSXBD (66 prefix, vvvv must be 1111b)
  // 128-bit: sign-extend 4 bytes (32 bits) to 4 dwords
  // 256-bit: sign-extend 8 bytes (64 bits) to 8 dwords
  33 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src2 = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let src : qword = match src2 {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[63..0],
        RM_mem(m) => read_mem(m),
      };
      write_ymm(dst, avx_pmovsxbd_256(src))
    } else {
      let src : dword = match src2 {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[31..0],
        RM_mem(m) => read_mem(m),
      };
      write_xmm(dst, avx_pmovsxbd_128(src))
    }
  },

  // 0F38 22: VPMOVSXBQ (66 prefix, vvvv must be 1111b)
  // 128-bit: sign-extend 2 bytes (16 bits) to 2 qwords
  // 256-bit: sign-extend 4 bytes (32 bits) to 4 qwords
  34 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src2 = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let src : dword = match src2 {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[31..0],
        RM_mem(m) => read_mem(m),
      };
      write_ymm(dst, avx_pmovsxbq_256(src))
    } else {
      let src : word = match src2 {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[15..0],
        RM_mem(m) => read_mem(m),
      };
      write_xmm(dst, avx_pmovsxbq_128(src))
    }
  },

  // 0F38 23: VPMOVSXWD (66 prefix, vvvv must be 1111b)
  // 128-bit: sign-extend 4 words (64 bits) to 4 dwords
  // 256-bit: sign-extend 8 words (128 bits) to 8 dwords
  35 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src2 = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let src : xmmword = decode_vex_src_xmm(modrm, src2, pfx);
      write_ymm(dst, avx_pmovsxwd_256(src))
    } else {
      let src : qword = match src2 {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[63..0],
        RM_mem(m) => read_mem(m),
      };
      write_xmm(dst, avx_pmovsxwd_128(src))
    }
  },

  // 0F38 24: VPMOVSXWQ (66 prefix, vvvv must be 1111b)
  // 128-bit: sign-extend 2 words (32 bits) to 2 qwords
  // 256-bit: sign-extend 4 words (64 bits) to 4 qwords
  36 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src2 = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let src : qword = match src2 {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[63..0],
        RM_mem(m) => read_mem(m),
      };
      write_ymm(dst, avx_pmovsxwq_256(src))
    } else {
      let src : dword = match src2 {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[31..0],
        RM_mem(m) => read_mem(m),
      };
      write_xmm(dst, avx_pmovsxwq_128(src))
    }
  },

  // 0F38 25: VPMOVSXDQ (66 prefix, vvvv must be 1111b)
  // 128-bit: sign-extend 2 dwords (64 bits) to 2 qwords
  // 256-bit: sign-extend 4 dwords (128 bits) to 4 qwords
  37 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src2 = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let src : xmmword = decode_vex_src_xmm(modrm, src2, pfx);
      write_ymm(dst, avx_pmovsxdq_256(src))
    } else {
      let src : qword = match src2 {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[63..0],
        RM_mem(m) => read_mem(m),
      };
      write_xmm(dst, avx_pmovsxdq_128(src))
    }
  },

  // 0F38 28: VPMULDQ (66 prefix)
  // Multiply signed dwords at positions 0 and 2 producing qword results
  40 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = decode_rm(modrm, pfx);
    let v = pfx.vex_vvvv;
    if pfx.vex_l then {
      write_ymm(dst, avx_pmuldq_256(read_ymm(v), decode_vex_src_ymm(modrm, src, pfx)))
    } else {
      write_xmm(dst, avx_pmuldq_128(read_xmm(v), decode_vex_src_xmm(modrm, src, pfx)))
    }
  },

  // 0F38 29: VPCMPEQQ (66 prefix)
  // Compare packed qwords for equality; result is all 1s or all 0s per lane
  41 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = decode_rm(modrm, pfx);
    let v = pfx.vex_vvvv;
    if pfx.vex_l then {
      write_ymm(dst, avx_pcmpeqq_256(read_ymm(v), decode_vex_src_ymm(modrm, src, pfx)))
    } else {
      write_xmm(dst, avx_pcmpeqq_128(read_xmm(v), decode_vex_src_xmm(modrm, src, pfx)))
    }
  },

  // 0F38 2A: VMOVNTDQA (66 prefix, vvvv must be 1111b)
  // Non-temporal aligned load; memory-only source
  42 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = decode_rm(modrm, pfx);
    if pfx.vex_l then write_ymm(dst, rm_mem(src))
    else write_xmm(dst, rm_mem(src))
  },

  // 0F38 2B: VPACKUSDW (66 prefix)
  // Pack dwords to words with unsigned saturation
  43 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = decode_rm(modrm, pfx);
    let v = pfx.vex_vvvv;
    if pfx.vex_l then {
      write_ymm(dst, avx_packusdw_256(read_ymm(v), decode_vex_src_ymm(modrm, src, pfx)))
    } else {
      write_xmm(dst, avx_packusdw_128(read_xmm(v), decode_vex_src_xmm(modrm, src, pfx)))
    }
  },

  // 0F38 30: VPMOVZXBW (66 prefix, vvvv must be 1111b)
  // 128-bit: zero-extend 8 bytes (64 bits) to 8 words
  // 256-bit: zero-extend 16 bytes (128 bits) to 16 words
  48 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src2 = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let src : xmmword = decode_vex_src_xmm(modrm, src2, pfx);
      write_ymm(dst, avx_pmovzxbw_256(src))
    } else {
      let src : qword = match src2 {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[63..0],
        RM_mem(m) => read_mem(m),
      };
      write_xmm(dst, avx_pmovzxbw_128(src))
    }
  },

  // 0F38 31: VPMOVZXBD (66 prefix, vvvv must be 1111b)
  // 128-bit: zero-extend 4 bytes (32 bits) to 4 dwords
  // 256-bit: zero-extend 8 bytes (64 bits) to 8 dwords
  49 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src2 = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let src : qword = match src2 {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[63..0],
        RM_mem(m) => read_mem(m),
      };
      write_ymm(dst, avx_pmovzxbd_256(src))
    } else {
      let src : dword = match src2 {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[31..0],
        RM_mem(m) => read_mem(m),
      };
      write_xmm(dst, avx_pmovzxbd_128(src))
    }
  },

  // 0F38 32: VPMOVZXBQ (66 prefix, vvvv must be 1111b)
  // 128-bit: zero-extend 2 bytes (16 bits) to 2 qwords
  // 256-bit: zero-extend 4 bytes (32 bits) to 4 qwords
  50 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src2 = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let src : dword = match src2 {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[31..0],
        RM_mem(m) => read_mem(m),
      };
      write_ymm(dst, avx_pmovzxbq_256(src))
    } else {
      let src : word = match src2 {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[15..0],
        RM_mem(m) => read_mem(m),
      };
      write_xmm(dst, avx_pmovzxbq_128(src))
    }
  },

  // 0F38 33: VPMOVZXWD (66 prefix, vvvv must be 1111b)
  // 128-bit: zero-extend 4 words (64 bits) to 4 dwords
  // 256-bit: zero-extend 8 words (128 bits) to 8 dwords
  51 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src2 = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let src : xmmword = decode_vex_src_xmm(modrm, src2, pfx);
      write_ymm(dst, avx_pmovzxwd_256(src))
    } else {
      let src : qword = match src2 {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[63..0],
        RM_mem(m) => read_mem(m),
      };
      write_xmm(dst, avx_pmovzxwd_128(src))
    }
  },

  // 0F38 34: VPMOVZXWQ (66 prefix, vvvv must be 1111b)
  // 128-bit: zero-extend 2 words (32 bits) to 2 qwords
  // 256-bit: zero-extend 4 words (64 bits) to 4 qwords
  52 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src2 = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let src : qword = match src2 {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[63..0],
        RM_mem(m) => read_mem(m),
      };
      write_ymm(dst, avx_pmovzxwq_256(src))
    } else {
      let src : dword = match src2 {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[31..0],
        RM_mem(m) => read_mem(m),
      };
      write_xmm(dst, avx_pmovzxwq_128(src))
    }
  },

  // 0F38 35: VPMOVZXDQ (66 prefix, vvvv must be 1111b)
  // 128-bit: zero-extend 2 dwords (64 bits) to 2 qwords
  // 256-bit: zero-extend 4 dwords (128 bits) to 4 qwords
  53 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src2 = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let src : xmmword = decode_vex_src_xmm(modrm, src2, pfx);
      write_ymm(dst, avx_pmovzxdq_256(src))
    } else {
      let src : qword = match src2 {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[63..0],
        RM_mem(m) => read_mem(m),
      };
      write_xmm(dst, avx_pmovzxdq_128(src))
    }
  },

  // 0F38 38: VPMINSB (66 prefix)
  // Packed minimum of signed bytes
  56 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = decode_rm(modrm, pfx);
    let v = pfx.vex_vvvv;
    if pfx.vex_l then {
      write_ymm(dst, avx_pminsb_256(read_ymm(v), decode_vex_src_ymm(modrm, src, pfx)))
    } else {
      write_xmm(dst, avx_pminsb_128(read_xmm(v), decode_vex_src_xmm(modrm, src, pfx)))
    }
  },

  // 0F38 39: VPMINSD (66 prefix)
  // Packed minimum of signed dwords
  57 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = decode_rm(modrm, pfx);
    let v = pfx.vex_vvvv;
    if pfx.vex_l then {
      write_ymm(dst, avx_pminsd_256(read_ymm(v), decode_vex_src_ymm(modrm, src, pfx)))
    } else {
      write_xmm(dst, avx_pminsd_128(read_xmm(v), decode_vex_src_xmm(modrm, src, pfx)))
    }
  },

  // 0F38 3A: VPMINUW (66 prefix)
  // Packed minimum of unsigned words
  58 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = decode_rm(modrm, pfx);
    let v = pfx.vex_vvvv;
    if pfx.vex_l then {
      write_ymm(dst, avx_pminuw_256(read_ymm(v), decode_vex_src_ymm(modrm, src, pfx)))
    } else {
      write_xmm(dst, avx_pminuw_128(read_xmm(v), decode_vex_src_xmm(modrm, src, pfx)))
    }
  },

  // 0F38 3B: VPMINUD (66 prefix)
  // Packed minimum of unsigned dwords
  59 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = decode_rm(modrm, pfx);
    let v = pfx.vex_vvvv;
    if pfx.vex_l then {
      write_ymm(dst, avx_pminud_256(read_ymm(v), decode_vex_src_ymm(modrm, src, pfx)))
    } else {
      write_xmm(dst, avx_pminud_128(read_xmm(v), decode_vex_src_xmm(modrm, src, pfx)))
    }
  },

  // 0F38 3C: VPMAXSB (66 prefix)
  // Packed maximum of signed bytes
  60 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = decode_rm(modrm, pfx);
    let v = pfx.vex_vvvv;
    if pfx.vex_l then {
      write_ymm(dst, avx_pmaxsb_256(read_ymm(v), decode_vex_src_ymm(modrm, src, pfx)))
    } else {
      write_xmm(dst, avx_pmaxsb_128(read_xmm(v), decode_vex_src_xmm(modrm, src, pfx)))
    }
  },

  // 0F38 3D: VPMAXSD (66 prefix)
  // Packed maximum of signed dwords
  61 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = decode_rm(modrm, pfx);
    let v = pfx.vex_vvvv;
    if pfx.vex_l then {
      write_ymm(dst, avx_pmaxsd_256(read_ymm(v), decode_vex_src_ymm(modrm, src, pfx)))
    } else {
      write_xmm(dst, avx_pmaxsd_128(read_xmm(v), decode_vex_src_xmm(modrm, src, pfx)))
    }
  },

  // 0F38 3E: VPMAXUW (66 prefix)
  // Packed maximum of unsigned words
  62 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = decode_rm(modrm, pfx);
    let v = pfx.vex_vvvv;
    if pfx.vex_l then {
      write_ymm(dst, avx_maxuw_256(read_ymm(v), decode_vex_src_ymm(modrm, src, pfx)))
    } else {
      write_xmm(dst, avx_maxuw_128(read_xmm(v), decode_vex_src_xmm(modrm, src, pfx)))
    }
  },

  // 0F38 3F: VPMAXUD (66 prefix)
  // Packed maximum of unsigned dwords
  63 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = decode_rm(modrm, pfx);
    let v = pfx.vex_vvvv;
    if pfx.vex_l then {
      write_ymm(dst, avx_pmaxud_256(read_ymm(v), decode_vex_src_ymm(modrm, src, pfx)))
    } else {
      write_xmm(dst, avx_pmaxud_128(read_xmm(v), decode_vex_src_xmm(modrm, src, pfx)))
    }
  },

  // 0F38 40: VPMULLD (66 prefix)
  // Multiply packed dword integers, store low 32 bits of each result
  64 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = decode_rm(modrm, pfx);
    let v = pfx.vex_vvvv;
    if pfx.vex_l then {
      write_ymm(dst, avx_pmulld_256(read_ymm(v), decode_vex_src_ymm(modrm, src, pfx)))
    } else {
      write_xmm(dst, avx_pmulld_128(read_xmm(v), decode_vex_src_xmm(modrm, src, pfx)))
    }
  },

  // 0F38 41: VPHMINPOSUW (66 prefix, VEX.128 only, vvvv must be 1111b)
  // Packed horizontal minimum of unsigned words
  65 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    if pfx.vex_l then raise_UD(); // VEX.128 only
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src2 = decode_rm(modrm, pfx);
    let src : xmmword = decode_vex_src_xmm(modrm, src2, pfx);
    write_xmm(dst, avx_phminposuw_128(src))
  },

  // 0F38 0E: VTESTPS xmm, xmm/m128 or ymm, ymm/m256 (VEX.128/256.66.0F38.W0)
  // SDM: VEX.vvvv must be 1111b
  // Sets ZF if AND(src1, src2) == 0; sets CF if AND(NOT src1, src2) == 0
  // Clears OF, AF, PF, SF
  14 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 | pfx.vex_w then raise_UD();
    let modrm = fetch_byte();
    let src1_idx = modrm_xmm_reg(modrm, pfx);
    let src = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let src1 : ymmword = read_ymm(src1_idx);
      let src2 : ymmword = decode_vex_src_ymm(modrm, src, pfx);
      let tmp1 : ymmword = src1 & src2;
      let tmp2 : ymmword = ~(src1) & src2;
      ZF = is_zero(tmp1[255..192] | tmp1[191..128] | tmp1[127..64] | tmp1[63..0]);
      CF = is_zero(tmp2[255..192] | tmp2[191..128] | tmp2[127..64] | tmp2[63..0]);
    } else {
      let src1 : xmmword = read_xmm(src1_idx);
      let src2 : xmmword = decode_vex_src_xmm(modrm, src, pfx);
      let tmp1 : xmmword = src1 & src2;
      let tmp2 : xmmword = ~(src1) & src2;
      ZF = is_zero(tmp1[127..64] | tmp1[63..0]);
      CF = is_zero(tmp2[127..64] | tmp2[63..0]);
    };
    OF = 0b0;
    AF = 0b0;
    PF = 0b0;
    SF = 0b0
  },

  // 0F38 0F: VTESTPD xmm, xmm/m128 or ymm, ymm/m256 (VEX.128/256.66.0F38.W0)
  // SDM: VEX.vvvv must be 1111b
  // Same logic as VTESTPS but for packed doubles (bit-level identical)
  15 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 | pfx.vex_w then raise_UD();
    let modrm = fetch_byte();
    let src1_idx = modrm_xmm_reg(modrm, pfx);
    let src = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let src1 : ymmword = read_ymm(src1_idx);
      let src2 : ymmword = decode_vex_src_ymm(modrm, src, pfx);
      let tmp1 : ymmword = src1 & src2;
      let tmp2 : ymmword = ~(src1) & src2;
      ZF = is_zero(tmp1[255..192] | tmp1[191..128] | tmp1[127..64] | tmp1[63..0]);
      CF = is_zero(tmp2[255..192] | tmp2[191..128] | tmp2[127..64] | tmp2[63..0]);
    } else {
      let src1 : xmmword = read_xmm(src1_idx);
      let src2 : xmmword = decode_vex_src_xmm(modrm, src, pfx);
      let tmp1 : xmmword = src1 & src2;
      let tmp2 : xmmword = ~(src1) & src2;
      ZF = is_zero(tmp1[127..64] | tmp1[63..0]);
      CF = is_zero(tmp2[127..64] | tmp2[63..0]);
    };
    OF = 0b0;
    AF = 0b0;
    PF = 0b0;
    SF = 0b0
  },

  // 0F38 16: VPERMPS ymm, ymm, ymm/m256 (VEX.256.66.0F38.W0)
  // VEX.256 only; L=0 → #UD
  22 => {
    if mp != MP_66 | pfx.vex_w then raise_UD();
    if ~(pfx.vex_l) then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src2 = decode_rm(modrm, pfx);
    let ctrl : ymmword = read_ymm(pfx.vex_vvvv);
    let src : ymmword = decode_vex_src_ymm(modrm, src2, pfx);
    write_ymm(dst, vex_vpermd_256(ctrl, src))
  },

  // 0F38 2C: VMASKMOVPS load xmm1, xmm2, m128 (VEX.128/256.66.0F38.W0)
  // dst = modrm_reg, mask = vvvv, src = memory (RM_reg → #UD)
  44 => {
    if mp != MP_66 | pfx.vex_w then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let mask : ymmword = read_ymm(pfx.vex_vvvv);
      let data : ymmword = rm_mem(src);
      write_ymm(dst, vex_maskmovps_load_256(mask, data))
    } else {
      let mask : xmmword = read_xmm(pfx.vex_vvvv);
      let data : xmmword = rm_mem(src);
      write_xmm(dst, vex_maskmovps_load_128(mask, data))
    }
  },

  // 0F38 2D: VMASKMOVPD load xmm1, xmm2, m128 (VEX.128/256.66.0F38.W0)
  // dst = modrm_reg, mask = vvvv, src = memory (RM_reg → #UD)
  45 => {
    if mp != MP_66 | pfx.vex_w then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let mask : ymmword = read_ymm(pfx.vex_vvvv);
      let data : ymmword = rm_mem(src);
      write_ymm(dst, vex_maskmovpd_load_256(mask, data))
    } else {
      let mask : xmmword = read_xmm(pfx.vex_vvvv);
      let data : xmmword = rm_mem(src);
      write_xmm(dst, vex_maskmovpd_load_128(mask, data))
    }
  },

  // 0F38 2E: VMASKMOVPS store m128, xmm2, xmm1 (VEX.128/256.66.0F38.W0)
  // src = modrm_reg, mask = vvvv, dst = memory (RM_reg → #UD)
  46 => {
    if mp != MP_66 | pfx.vex_w then raise_UD();
    let modrm = fetch_byte();
    let src_idx = modrm_xmm_reg(modrm, pfx);
    let src2 = decode_rm(modrm, pfx);
    match src2 {
      RM_reg(_) => raise_UD(),
      RM_mem(m) => {
        let a = seg_linear(m, if pfx.vex_l then 32 else 16);
        if pfx.vex_l then {
          let mask : ymmword = read_ymm(pfx.vex_vvvv);
          let src : ymmword = read_ymm(src_idx);
          foreach (i from 0 to 7) {
            if mask[(i * 32 + 31)] == 0b1 then
              write_mem(4, a + zero_extend(to_bits(64, i * 4)), src[(i * 32 + 31) .. (i * 32)])
          }
        } else {
          let mask : xmmword = read_xmm(pfx.vex_vvvv);
          let src : xmmword = read_xmm(src_idx);
          foreach (i from 0 to 3) {
            if mask[(i * 32 + 31)] == 0b1 then
              write_mem(4, a + zero_extend(to_bits(64, i * 4)), src[(i * 32 + 31) .. (i * 32)])
          }
        }
      },
    }
  },

  // 0F38 2F: VMASKMOVPD store m128, xmm2, xmm1 (VEX.128/256.66.0F38.W0)
  // src = modrm_reg, mask = vvvv, dst = memory (RM_reg → #UD)
  47 => {
    if mp != MP_66 | pfx.vex_w then raise_UD();
    let modrm = fetch_byte();
    let src_idx = modrm_xmm_reg(modrm, pfx);
    let src2 = decode_rm(modrm, pfx);
    match src2 {
      RM_reg(_) => raise_UD(),
      RM_mem(m) => {
        let a = seg_linear(m, if pfx.vex_l then 32 else 16);
        if pfx.vex_l then {
          let mask : ymmword = read_ymm(pfx.vex_vvvv);
          let src : ymmword = read_ymm(src_idx);
          foreach (i from 0 to 3) {
            if mask[(i * 64 + 63)] == 0b1 then
              write_mem(8, a + zero_extend(to_bits(64, i * 8)), src[(i * 64 + 63) .. (i * 64)])
          }
        } else {
          let mask : xmmword = read_xmm(pfx.vex_vvvv);
          let src : xmmword = read_xmm(src_idx);
          foreach (i from 0 to 1) {
            if mask[(i * 64 + 63)] == 0b1 then
              write_mem(8, a + zero_extend(to_bits(64, i * 8)), src[(i * 64 + 63) .. (i * 64)])
          }
        }
      },
    }
  },

  // 0F38 36: VPERMD ymm1, ymm2, ymm3/m256 (VEX.256.66.0F38.W0)
  // VEX.256 only; L=0 → #UD
  54 => {
    if mp != MP_66 | pfx.vex_w then raise_UD();
    if ~(pfx.vex_l) then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src2 = decode_rm(modrm, pfx);
    let ctrl : ymmword = read_ymm(pfx.vex_vvvv);
    let src : ymmword = decode_vex_src_ymm(modrm, src2, pfx);
    write_ymm(dst, vex_vpermd_256(ctrl, src))
  },

  // 0F38 45: VPSRLVD (W0) / VPSRLVQ (W1) (VEX.128/256.66.0F38)
  // Variable logical right shift per element
  69 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = decode_rm(modrm, pfx);
    let v = pfx.vex_vvvv;
    match (pfx.vex_l, pfx.vex_w) {
      // VPSRLVQ ymm1, ymm2, ymm3/m256
      (true, true)   => write_ymm(dst, vex_psrlvq_256(read_ymm(v), decode_vex_src_ymm(modrm, src, pfx))),
      // VPSRLVQ xmm1, xmm2, xmm3/m128
      (false, true)  => write_xmm(dst, vex_psrlvq_128(read_xmm(v), decode_vex_src_xmm(modrm, src, pfx))),
      // VPSRLVD ymm1, ymm2, ymm3/m256
      (true, false)  => write_ymm(dst, vex_psrlvd_256(read_ymm(v), decode_vex_src_ymm(modrm, src, pfx))),
      // VPSRLVD xmm1, xmm2, xmm3/m128
      (false, false) => write_xmm(dst, vex_psrlvd_128(read_xmm(v), decode_vex_src_xmm(modrm, src, pfx))),
    }
  },

  // 0F38 46: VPSRAVD (VEX.128/256.66.0F38.W0)
  // Variable arithmetic right shift, dword only (no qword form in AVX2)
  70 => {
    if mp != MP_66 | pfx.vex_w then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = decode_rm(modrm, pfx);
    let v = pfx.vex_vvvv;
    if pfx.vex_l then {
      write_ymm(dst, vex_psravd_256(read_ymm(v), decode_vex_src_ymm(modrm, src, pfx)))
    } else {
      write_xmm(dst, vex_psravd_128(read_xmm(v), decode_vex_src_xmm(modrm, src, pfx)))
    }
  },

  // 0F38 47: VPSLLVD (W0) / VPSLLVQ (W1) (VEX.128/256.66.0F38)
  // Variable logical left shift per element
  71 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = decode_rm(modrm, pfx);
    let v = pfx.vex_vvvv;
    match (pfx.vex_l, pfx.vex_w) {
      // VPSLLVQ ymm1, ymm2, ymm3/m256
      (true, true)   => write_ymm(dst, vex_psllvq_256(read_ymm(v), decode_vex_src_ymm(modrm, src, pfx))),
      // VPSLLVQ xmm1, xmm2, xmm3/m128
      (false, true)  => write_xmm(dst, vex_psllvq_128(read_xmm(v), decode_vex_src_xmm(modrm, src, pfx))),
      // VPSLLVD ymm1, ymm2, ymm3/m256
      (true, false)  => write_ymm(dst, vex_psllvd_256(read_ymm(v), decode_vex_src_ymm(modrm, src, pfx))),
      // VPSLLVD xmm1, xmm2, xmm3/m128
      (false, false) => write_xmm(dst, vex_psllvd_128(read_xmm(v), decode_vex_src_xmm(modrm, src, pfx))),
    }
  },

  // 0F38 90: VPGATHERDD (66,W0) / VPGATHERDQ (66,W1) — dword indices, VEX gather
  144 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let vsib = decode_vsib_vex(modrm, pfx);
    let mask_idx = pfx.vex_vvvv;
    if pfx.vex_w then {
      // VPGATHERDQ: dword indices, qword elements
      if pfx.vex_l then {
        var result : ymmword = read_ymm(dst);
        let mask : ymmword = read_ymm(mask_idx);
        let indices : xmmword = read_xmm(vsib.vsib_vidx);
        foreach (i from 0 to 3) {
          if mask[(i * 64 + 63)] == 0b1 then {
            let idx : dword = indices[(i * 32 + 31) .. (i * 32)];
            let addr = gather_addr(vsib.vsib_base, idx, vsib.vsib_scale);
            result[(i * 64 + 63) .. (i * 64)] = read_mem(8, addr)
          }
        };
        write_ymm(dst, result);
        write_ymm(mask_idx, zeros())
      } else {
        var result : xmmword = read_xmm(dst);
        let mask : xmmword = read_xmm(mask_idx);
        let indices : xmmword = read_xmm(vsib.vsib_vidx);
        foreach (i from 0 to 1) {
          if mask[(i * 64 + 63)] == 0b1 then {
            let idx : dword = indices[(i * 32 + 31) .. (i * 32)];
            let addr = gather_addr(vsib.vsib_base, idx, vsib.vsib_scale);
            result[(i * 64 + 63) .. (i * 64)] = read_mem(8, addr)
          }
        };
        write_xmm(dst, result);
        write_xmm(mask_idx, zeros())
      }
    } else {
      // VPGATHERDD: dword indices, dword elements
      if pfx.vex_l then {
        var result : ymmword = read_ymm(dst);
        let mask : ymmword = read_ymm(mask_idx);
        let indices : ymmword = read_ymm(vsib.vsib_vidx);
        foreach (i from 0 to 7) {
          if mask[(i * 32 + 31)] == 0b1 then {
            let idx : dword = indices[(i * 32 + 31) .. (i * 32)];
            let addr = gather_addr(vsib.vsib_base, idx, vsib.vsib_scale);
            result[(i * 32 + 31) .. (i * 32)] = read_mem(4, addr)
          }
        };
        write_ymm(dst, result);
        write_ymm(mask_idx, zeros())
      } else {
        var result : xmmword = read_xmm(dst);
        let mask : xmmword = read_xmm(mask_idx);
        let indices : xmmword = read_xmm(vsib.vsib_vidx);
        foreach (i from 0 to 3) {
          if mask[(i * 32 + 31)] == 0b1 then {
            let idx : dword = indices[(i * 32 + 31) .. (i * 32)];
            let addr = gather_addr(vsib.vsib_base, idx, vsib.vsib_scale);
            result[(i * 32 + 31) .. (i * 32)] = read_mem(4, addr)
          }
        };
        write_xmm(dst, result);
        write_xmm(mask_idx, zeros())
      }
    }
  },

  // 0F38 91: VPGATHERQD (66,W0) / VPGATHERQQ (66,W1) — qword indices, VEX gather
  145 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let vsib = decode_vsib_vex(modrm, pfx);
    let mask_idx = pfx.vex_vvvv;
    if pfx.vex_w then {
      // VPGATHERQQ: qword indices, qword elements
      if pfx.vex_l then {
        var result : ymmword = read_ymm(dst);
        let mask : ymmword = read_ymm(mask_idx);
        let indices : ymmword = read_ymm(vsib.vsib_vidx);
        foreach (i from 0 to 3) {
          if mask[(i * 64 + 63)] == 0b1 then {
            let idx : qword = indices[(i * 64 + 63) .. (i * 64)];
            let addr = gather_addr_q(vsib.vsib_base, idx, vsib.vsib_scale);
            result[(i * 64 + 63) .. (i * 64)] = read_mem(8, addr)
          }
        };
        write_ymm(dst, result);
        write_ymm(mask_idx, zeros())
      } else {
        var result : xmmword = read_xmm(dst);
        let mask : xmmword = read_xmm(mask_idx);
        let indices : xmmword = read_xmm(vsib.vsib_vidx);
        foreach (i from 0 to 1) {
          if mask[(i * 64 + 63)] == 0b1 then {
            let idx : qword = indices[(i * 64 + 63) .. (i * 64)];
            let addr = gather_addr_q(vsib.vsib_base, idx, vsib.vsib_scale);
            result[(i * 64 + 63) .. (i * 64)] = read_mem(8, addr)
          }
        };
        write_xmm(dst, result);
        write_xmm(mask_idx, zeros())
      }
    } else {
      // VPGATHERQD: qword indices, dword elements
      if pfx.vex_l then {
        var result : xmmword = read_xmm(dst);
        let mask : xmmword = read_xmm(mask_idx);
        let indices : ymmword = read_ymm(vsib.vsib_vidx);
        foreach (i from 0 to 3) {
          if mask[(i * 32 + 31)] == 0b1 then {
            let idx : qword = indices[(i * 64 + 63) .. (i * 64)];
            let addr = gather_addr_q(vsib.vsib_base, idx, vsib.vsib_scale);
            result[(i * 32 + 31) .. (i * 32)] = read_mem(4, addr)
          }
        };
        write_xmm(dst, result);
        write_xmm(mask_idx, zeros())
      } else {
        var result : xmmword = read_xmm(dst);
        let mask : xmmword = read_xmm(mask_idx);
        let indices : xmmword = read_xmm(vsib.vsib_vidx);
        foreach (i from 0 to 1) {
          if mask[(i * 32 + 31)] == 0b1 then {
            let idx : qword = indices[(i * 64 + 63) .. (i * 64)];
            let addr = gather_addr_q(vsib.vsib_base, idx, vsib.vsib_scale);
            result[(i * 32 + 31) .. (i * 32)] = read_mem(4, addr)
          }
        };
        write_xmm(dst, result);
        write_xmm(mask_idx, zeros())
      }
    }
  },

  // 0F38 92: VGATHERDPS (66,W0) / VGATHERDPD (66,W1) — same encoding as 90 but FP
  146 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let vsib = decode_vsib_vex(modrm, pfx);
    let mask_idx = pfx.vex_vvvv;
    if pfx.vex_w then {
      // VGATHERDPD: dword indices, f64 elements
      if pfx.vex_l then {
        var result : ymmword = read_ymm(dst);
        let mask : ymmword = read_ymm(mask_idx);
        let indices : xmmword = read_xmm(vsib.vsib_vidx);
        foreach (i from 0 to 3) {
          if mask[(i * 64 + 63)] == 0b1 then {
            let idx : dword = indices[(i * 32 + 31) .. (i * 32)];
            let addr = gather_addr(vsib.vsib_base, idx, vsib.vsib_scale);
            result[(i * 64 + 63) .. (i * 64)] = read_mem(8, addr)
          }
        };
        write_ymm(dst, result);
        write_ymm(mask_idx, zeros())
      } else {
        var result : xmmword = read_xmm(dst);
        let mask : xmmword = read_xmm(mask_idx);
        let indices : xmmword = read_xmm(vsib.vsib_vidx);
        foreach (i from 0 to 1) {
          if mask[(i * 64 + 63)] == 0b1 then {
            let idx : dword = indices[(i * 32 + 31) .. (i * 32)];
            let addr = gather_addr(vsib.vsib_base, idx, vsib.vsib_scale);
            result[(i * 64 + 63) .. (i * 64)] = read_mem(8, addr)
          }
        };
        write_xmm(dst, result);
        write_xmm(mask_idx, zeros())
      }
    } else {
      // VGATHERDPS: dword indices, f32 elements
      if pfx.vex_l then {
        var result : ymmword = read_ymm(dst);
        let mask : ymmword = read_ymm(mask_idx);
        let indices : ymmword = read_ymm(vsib.vsib_vidx);
        foreach (i from 0 to 7) {
          if mask[(i * 32 + 31)] == 0b1 then {
            let idx : dword = indices[(i * 32 + 31) .. (i * 32)];
            let addr = gather_addr(vsib.vsib_base, idx, vsib.vsib_scale);
            result[(i * 32 + 31) .. (i * 32)] = read_mem(4, addr)
          }
        };
        write_ymm(dst, result);
        write_ymm(mask_idx, zeros())
      } else {
        var result : xmmword = read_xmm(dst);
        let mask : xmmword = read_xmm(mask_idx);
        let indices : xmmword = read_xmm(vsib.vsib_vidx);
        foreach (i from 0 to 3) {
          if mask[(i * 32 + 31)] == 0b1 then {
            let idx : dword = indices[(i * 32 + 31) .. (i * 32)];
            let addr = gather_addr(vsib.vsib_base, idx, vsib.vsib_scale);
            result[(i * 32 + 31) .. (i * 32)] = read_mem(4, addr)
          }
        };
        write_xmm(dst, result);
        write_xmm(mask_idx, zeros())
      }
    }
  },

  // 0F38 93: VGATHERQPS (66,W0) / VGATHERQPD (66,W1) — same encoding as 91 but FP
  147 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let vsib = decode_vsib_vex(modrm, pfx);
    let mask_idx = pfx.vex_vvvv;
    if pfx.vex_w then {
      // VGATHERQPD: qword indices, f64 elements
      if pfx.vex_l then {
        var result : ymmword = read_ymm(dst);
        let mask : ymmword = read_ymm(mask_idx);
        let indices : ymmword = read_ymm(vsib.vsib_vidx);
        foreach (i from 0 to 3) {
          if mask[(i * 64 + 63)] == 0b1 then {
            let idx : qword = indices[(i * 64 + 63) .. (i * 64)];
            let addr = gather_addr_q(vsib.vsib_base, idx, vsib.vsib_scale);
            result[(i * 64 + 63) .. (i * 64)] = read_mem(8, addr)
          }
        };
        write_ymm(dst, result);
        write_ymm(mask_idx, zeros())
      } else {
        var result : xmmword = read_xmm(dst);
        let mask : xmmword = read_xmm(mask_idx);
        let indices : xmmword = read_xmm(vsib.vsib_vidx);
        foreach (i from 0 to 1) {
          if mask[(i * 64 + 63)] == 0b1 then {
            let idx : qword = indices[(i * 64 + 63) .. (i * 64)];
            let addr = gather_addr_q(vsib.vsib_base, idx, vsib.vsib_scale);
            result[(i * 64 + 63) .. (i * 64)] = read_mem(8, addr)
          }
        };
        write_xmm(dst, result);
        write_xmm(mask_idx, zeros())
      }
    } else {
      // VGATHERQPS: qword indices, f32 elements
      if pfx.vex_l then {
        var result : xmmword = read_xmm(dst);
        let mask : xmmword = read_xmm(mask_idx);
        let indices : ymmword = read_ymm(vsib.vsib_vidx);
        foreach (i from 0 to 3) {
          if mask[(i * 32 + 31)] == 0b1 then {
            let idx : qword = indices[(i * 64 + 63) .. (i * 64)];
            let addr = gather_addr_q(vsib.vsib_base, idx, vsib.vsib_scale);
            result[(i * 32 + 31) .. (i * 32)] = read_mem(4, addr)
          }
        };
        write_xmm(dst, result);
        write_xmm(mask_idx, zeros())
      } else {
        var result : xmmword = read_xmm(dst);
        let mask : xmmword = read_xmm(mask_idx);
        let indices : xmmword = read_xmm(vsib.vsib_vidx);
        foreach (i from 0 to 1) {
          if mask[(i * 32 + 31)] == 0b1 then {
            let idx : qword = indices[(i * 64 + 63) .. (i * 64)];
            let addr = gather_addr_q(vsib.vsib_base, idx, vsib.vsib_scale);
            result[(i * 32 + 31) .. (i * 32)] = read_mem(4, addr)
          }
        };
        write_xmm(dst, result);
        write_xmm(mask_idx, zeros())
      }
    }
  },

  // 0F38 0C: VPERMILPS xmm/ymm, xmm/ymm, xmm/ymm/m (66, register-controlled)
  // VEX.NDS: VPERMILPS dst(reg), src(vvvv), ctrl(r/m)
  12 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src2 = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let src : ymmword = read_ymm(pfx.vex_vvvv);
      let ctrl : ymmword = decode_vex_src_ymm(modrm, src2, pfx);
      var result : ymmword = zeros();
      // Per 128-bit lane, select from 4 dwords within that lane
      foreach (i from 0 to 3) {
        let sel : range(0, 3) = unsigned(ctrl[(i * 32 + 1) .. (i * 32)]);
        result[(i * 32 + 31) .. (i * 32)] = src[(sel * 32 + 31) .. (sel * 32)]
      };
      foreach (i from 4 to 7) {
        let sel : range(0, 3) = unsigned(ctrl[(i * 32 + 1) .. (i * 32)]);
        result[(i * 32 + 31) .. (i * 32)] = src[((sel + 4) * 32 + 31) .. ((sel + 4) * 32)]
      };
      write_ymm(dst, result)
    } else {
      let src : xmmword = read_xmm(pfx.vex_vvvv);
      let ctrl : xmmword = decode_vex_src_xmm(modrm, src2, pfx);
      var result : xmmword = zeros();
      foreach (i from 0 to 3) {
        let sel : range(0, 3) = unsigned(ctrl[(i * 32 + 1) .. (i * 32)]);
        result[(i * 32 + 31) .. (i * 32)] = src[(sel * 32 + 31) .. (sel * 32)]
      };
      write_xmm(dst, result)
    }
  },

  // 0F38 0D: VPERMILPD xmm/ymm, xmm/ymm, xmm/ymm/m (66, register-controlled)
  // VEX.NDS: VPERMILPD dst(reg), src(vvvv), ctrl(r/m)
  13 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src2 = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let src : ymmword = read_ymm(pfx.vex_vvvv);
      let ctrl : ymmword = decode_vex_src_ymm(modrm, src2, pfx);
      var result : ymmword = zeros();
      // Per 128-bit lane, select from 2 qwords within that lane using bit 1
      let s0 : range(0, 1) = unsigned(ctrl[1]);
      result[63..0] = src[(s0 * 64 + 63) .. (s0 * 64)];
      let s1 : range(0, 1) = unsigned(ctrl[65]);
      result[127..64] = src[(s1 * 64 + 63 + 0) .. (s1 * 64 + 0)];
      let s2 : range(0, 1) = unsigned(ctrl[129]);
      result[191..128] = src[((s2 + 2) * 64 + 63) .. ((s2 + 2) * 64)];
      let s3 : range(0, 1) = unsigned(ctrl[193]);
      result[255..192] = src[((s3 + 2) * 64 + 63) .. ((s3 + 2) * 64)];
      write_ymm(dst, result)
    } else {
      let src : xmmword = read_xmm(pfx.vex_vvvv);
      let ctrl : xmmword = decode_vex_src_xmm(modrm, src2, pfx);
      var result : xmmword = zeros();
      let s0 : range(0, 1) = unsigned(ctrl[1]);
      result[63..0] = src[(s0 * 64 + 63) .. (s0 * 64)];
      let s1 : range(0, 1) = unsigned(ctrl[65]);
      result[127..64] = src[(s1 * 64 + 63) .. (s1 * 64)];
      write_xmm(dst, result)
    }
  },

  // 0F38 17: VPTEST xmm/ymm, xmm/ymm/m (66 prefix, vvvv must be 1111b)
  23 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch_byte();
    let src1_idx = modrm_xmm_reg(modrm, pfx);
    let src = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let src1 : ymmword = read_ymm(src1_idx);
      let src2 : ymmword = decode_vex_src_ymm(modrm, src, pfx);
      let tmp1 : ymmword = src1 & src2;
      let tmp2 : ymmword = ~(src1) & src2;
      ZF = is_zero(tmp1[255..192] | tmp1[191..128] | tmp1[127..64] | tmp1[63..0]);
      CF = is_zero(tmp2[255..192] | tmp2[191..128] | tmp2[127..64] | tmp2[63..0]);
    } else {
      let src1 : xmmword = read_xmm(src1_idx);
      let src2 : xmmword = decode_vex_src_xmm(modrm, src, pfx);
      let tmp1 : xmmword = src1 & src2;
      let tmp2 : xmmword = ~(src1) & src2;
      ZF = is_zero(tmp1[127..64] | tmp1[63..0]);
      CF = is_zero(tmp2[127..64] | tmp2[63..0]);
    };
    OF = 0b0;
    AF = 0b0;
    PF = 0b0;
    SF = 0b0
  },

  // 0F38 37: VPCMPGTQ xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  55 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let src1 : ymmword = read_ymm(pfx.vex_vvvv);
      let src2 : ymmword = decode_vex_src_ymm(modrm, src, pfx);
      var result : ymmword = zeros();
      foreach (i from 0 to 3) {
        let a : bits(64) = src1[(i * 64 + 63) .. (i * 64)];
        let b : bits(64) = src2[(i * 64 + 63) .. (i * 64)];
        result[(i * 64 + 63) .. (i * 64)] = cmp_gt(a, b)
      };
      write_ymm(dst, result)
    } else {
      let src1 : xmmword = read_xmm(pfx.vex_vvvv);
      let src2 : xmmword = decode_vex_src_xmm(modrm, src, pfx);
      var result : xmmword = zeros();
      foreach (i from 0 to 1) {
        let a : bits(64) = src1[(i * 64 + 63) .. (i * 64)];
        let b : bits(64) = src2[(i * 64 + 63) .. (i * 64)];
        result[(i * 64 + 63) .. (i * 64)] = cmp_gt(a, b)
      };
      write_xmm(dst, result)
    }
  },

  // 0F38 8C: VPMASKMOVD/Q (load) xmm/ymm, xmm/ymm, m (66 prefix)
  140 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = decode_rm(modrm, pfx);
    match src {
      RM_mem(m) => {
        let a = seg_linear(m, if pfx.vex_l then 32 else 16);
        let mask_idx = pfx.vex_vvvv;
        match (pfx.vex_l, pfx.rex_w) {
          // VPMASKMOVQ: qword elements
          (true, true) => {
            let mask : ymmword = read_ymm(mask_idx);
            var result : ymmword = zeros();
            foreach (i from 0 to 3) {
              if mask[(i * 64 + 63)] == 0b1 then
                result[(i * 64 + 63) .. (i * 64)] = read_mem(8, a + to_bits(64, i * 8))
            };
            write_ymm(dst, result)
          },
          (false, true) => {
            let mask : xmmword = read_xmm(mask_idx);
            var result : xmmword = zeros();
            foreach (i from 0 to 1) {
              if mask[(i * 64 + 63)] == 0b1 then
                result[(i * 64 + 63) .. (i * 64)] = read_mem(8, a + to_bits(64, i * 8))
            };
            write_xmm(dst, result)
          },
          // VPMASKMOVD: dword elements
          (true, false) => {
            let mask : ymmword = read_ymm(mask_idx);
            var result : ymmword = zeros();
            foreach (i from 0 to 7) {
              if mask[(i * 32 + 31)] == 0b1 then
                result[(i * 32 + 31) .. (i * 32)] = read_mem(4, a + to_bits(64, i * 4))
            };
            write_ymm(dst, result)
          },
          (false, false) => {
            let mask : xmmword = read_xmm(mask_idx);
            var result : xmmword = zeros();
            foreach (i from 0 to 3) {
              if mask[(i * 32 + 31)] == 0b1 then
                result[(i * 32 + 31) .. (i * 32)] = read_mem(4, a + to_bits(64, i * 4))
            };
            write_xmm(dst, result)
          },
        }
      },
      RM_reg(_) => raise_UD(),
    }
  },

  // 0F38 8E: VPMASKMOVD/Q (store) m, xmm/ymm, xmm/ymm (66 prefix)
  142 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let src = modrm_xmm_reg(modrm, pfx);
    let dest = decode_rm(modrm, pfx);
    match dest {
      RM_mem(m) => {
        let a = seg_linear(m, if pfx.vex_l then 32 else 16);
        let mask_idx = pfx.vex_vvvv;
        match (pfx.vex_l, pfx.rex_w) {
          // VPMASKMOVQ: qword elements
          (true, true) => {
            let mask : ymmword = read_ymm(mask_idx);
            let data : ymmword = read_ymm(src);
            foreach (i from 0 to 3) {
              if mask[(i * 64 + 63)] == 0b1 then
                write_mem(8, a + to_bits(64, i * 8), data[(i * 64 + 63) .. (i * 64)])
            }
          },
          (false, true) => {
            let mask : xmmword = read_xmm(mask_idx);
            let data : xmmword = read_xmm(src);
            foreach (i from 0 to 1) {
              if mask[(i * 64 + 63)] == 0b1 then
                write_mem(8, a + to_bits(64, i * 8), data[(i * 64 + 63) .. (i * 64)])
            }
          },
          // VPMASKMOVD: dword elements
          (true, false) => {
            let mask : ymmword = read_ymm(mask_idx);
            let data : ymmword = read_ymm(src);
            foreach (i from 0 to 7) {
              if mask[(i * 32 + 31)] == 0b1 then
                write_mem(4, a + to_bits(64, i * 4), data[(i * 32 + 31) .. (i * 32)])
            }
          },
          (false, false) => {
            let mask : xmmword = read_xmm(mask_idx);
            let data : xmmword = read_xmm(src);
            foreach (i from 0 to 3) {
              if mask[(i * 32 + 31)] == 0b1 then
                write_mem(4, a + to_bits(64, i * 4), data[(i * 32 + 31) .. (i * 32)])
            }
          },
        }
      },
      RM_reg(_) => raise_UD(),
    }
  },

  // VGF2P8MULB: VEX.128/256.66.0F38.W0 CF /r
  207 => {
    let mp = get_mandatory_prefix(pfx);
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src1_idx = pfx.vex_vvvv;
    let src = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      // 256-bit: call __gf2p8mulb on each 128-bit half
      let src1 : ymmword = read_ymm(src1_idx);
      let src2 : ymmword = match src {
        RM_reg(_) => read_ymm(modrm_xmm_rm(modrm, pfx)),
        RM_mem(m) => read_mem(m),
      };
      let lo = __gf2p8mulb(src1[127..0], src2[127..0]);
      let hi = __gf2p8mulb(src1[255..128], src2[255..128]);
      write_ymm(dst, hi @ lo)
    } else {
      let src1 : xmmword = read_xmm(src1_idx);
      let src2 : xmmword = decode_xmm_src(modrm, src, pfx);
      write_xmm(dst, __gf2p8mulb(src1, src2))
    }
  },

  _ => raise_UD(),
  }
}

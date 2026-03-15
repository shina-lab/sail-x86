// x86-64 — VEX Immediate Instructions (0F3A map)
//
// Blend, round, dpps, palignr, permil, insert/extract, cvtps2ph,
// kshift, mpsadbw, pblendd.

// =========================================================================
// VEX 0F3A helpers — blend, palignr, round, dpps/dppd, permute
// =========================================================================

// VBLENDPS 128-bit: for each dword i, select from src1 or src2 based on imm8[i]
val avx_blendps_128 : (xmmword, xmmword, byte) -> xmmword
function avx_blendps_128(src1, src2, imm) =
  blend32(src1[127..96], src2[127..96], imm[3..3]) @
  blend32(src1[95..64],  src2[95..64],  imm[2..2]) @
  blend32(src1[63..32],  src2[63..32],  imm[1..1]) @
  blend32(src1[31..0],   src2[31..0],   imm[0..0])

val avx_blendps_256 : (ymmword, ymmword, byte) -> ymmword
function avx_blendps_256(src1, src2, imm) =
  blend32(src1[255..224], src2[255..224], imm[7..7]) @
  blend32(src1[223..192], src2[223..192], imm[6..6]) @
  blend32(src1[191..160], src2[191..160], imm[5..5]) @
  blend32(src1[159..128], src2[159..128], imm[4..4]) @
  blend32(src1[127..96],  src2[127..96],  imm[3..3]) @
  blend32(src1[95..64],   src2[95..64],   imm[2..2]) @
  blend32(src1[63..32],   src2[63..32],   imm[1..1]) @
  blend32(src1[31..0],    src2[31..0],    imm[0..0])

// VBLENDPD 128-bit: for each qword i, select based on imm8[i]
val avx_blendpd_128 : (xmmword, xmmword, byte) -> xmmword
function avx_blendpd_128(src1, src2, imm) =
  blend64(src1[127..64], src2[127..64], imm[1..1]) @
  blend64(src1[63..0],   src2[63..0],   imm[0..0])

val avx_blendpd_256 : (ymmword, ymmword, byte) -> ymmword
function avx_blendpd_256(src1, src2, imm) =
  blend64(src1[255..192], src2[255..192], imm[3..3]) @
  blend64(src1[191..128], src2[191..128], imm[2..2]) @
  blend64(src1[127..64],  src2[127..64],  imm[1..1]) @
  blend64(src1[63..0],    src2[63..0],    imm[0..0])

// VPBLENDW 128-bit: for each word i, select based on imm8[i]
val avx_pblendw_128 : (xmmword, xmmword, byte) -> xmmword
function avx_pblendw_128(src1, src2, imm) =
  blend16(src1[127..112], src2[127..112], imm[7..7]) @
  blend16(src1[111..96],  src2[111..96],  imm[6..6]) @
  blend16(src1[95..80],   src2[95..80],   imm[5..5]) @
  blend16(src1[79..64],   src2[79..64],   imm[4..4]) @
  blend16(src1[63..48],   src2[63..48],   imm[3..3]) @
  blend16(src1[47..32],   src2[47..32],   imm[2..2]) @
  blend16(src1[31..16],   src2[31..16],   imm[1..1]) @
  blend16(src1[15..0],    src2[15..0],    imm[0..0])

// VPBLENDD 128-bit: for each dword i, select based on imm8[i]
val avx_pblendd_128 : (xmmword, xmmword, byte) -> xmmword
function avx_pblendd_128(src1, src2, imm) =
  blend32(src1[127..96], src2[127..96], imm[3..3]) @
  blend32(src1[95..64],  src2[95..64],  imm[2..2]) @
  blend32(src1[63..32],  src2[63..32],  imm[1..1]) @
  blend32(src1[31..0],   src2[31..0],   imm[0..0])

val avx_pblendd_256 : (ymmword, ymmword, byte) -> ymmword
function avx_pblendd_256(src1, src2, imm) =
  blend32(src1[255..224], src2[255..224], imm[7..7]) @
  blend32(src1[223..192], src2[223..192], imm[6..6]) @
  blend32(src1[191..160], src2[191..160], imm[5..5]) @
  blend32(src1[159..128], src2[159..128], imm[4..4]) @
  blend32(src1[127..96],  src2[127..96],  imm[3..3]) @
  blend32(src1[95..64],   src2[95..64],   imm[2..2]) @
  blend32(src1[63..32],   src2[63..32],   imm[1..1]) @
  blend32(src1[31..0],    src2[31..0],    imm[0..0])

// VPALIGNR 128-bit: concatenate src1(high):src2(low), shift right by imm bytes, take low 128 bits
val avx_palignr_128 : (xmmword, xmmword, byte) -> xmmword
function avx_palignr_128(src1, src2, imm) = {
  let shift_bytes : range(0, 255) = unsigned(imm);
  let concat : ymmword = src1 @ src2;
  (concat >> (shift_bytes * 8))[127..0]
}

// VROUNDPS 128-bit
val avx_roundps_128 : (xmmword, byte) -> xmmword
function avx_roundps_128(src, imm) = {
  let d0 : dword = __f32_round(src[31..0], imm);
  let d1 : dword = __f32_round(src[63..32], imm);
  let d2 : dword = __f32_round(src[95..64], imm);
  let d3 : dword = __f32_round(src[127..96], imm);
  d3 @ d2 @ d1 @ d0
}

// VROUNDPD 128-bit
val avx_roundpd_128 : (xmmword, byte) -> xmmword
function avx_roundpd_128(src, imm) = {
  let lo : qword = __f64_round(src[63..0], imm);
  let hi : qword = __f64_round(src[127..64], imm);
  hi @ lo
}

// VDPPS 128-bit: dot product of packed singles
val avx_dpps_128 : (xmmword, xmmword, byte) -> xmmword
function avx_dpps_128(a, b, imm) = {
  let zero : dword = 0x00000000;
  let temp0 : dword = if imm[4] == bitone then __f32_mul(a[31..0], b[31..0]) else zero;
  let temp1 : dword = if imm[5] == bitone then __f32_mul(a[63..32], b[63..32]) else zero;
  let temp2 : dword = if imm[6] == bitone then __f32_mul(a[95..64], b[95..64]) else zero;
  let temp3 : dword = if imm[7] == bitone then __f32_mul(a[127..96], b[127..96]) else zero;
  let sum01 : dword = __f32_add(temp0, temp1);
  let sum23 : dword = __f32_add(temp2, temp3);
  let sum : dword = __f32_add(sum01, sum23);
  let d0 : dword = sum & sign_extend(imm[0..0]);
  let d1 : dword = sum & sign_extend(imm[1..1]);
  let d2 : dword = sum & sign_extend(imm[2..2]);
  let d3 : dword = sum & sign_extend(imm[3..3]);
  d3 @ d2 @ d1 @ d0
}

// VDPPD 128-bit: dot product of packed doubles
val avx_dppd_128 : (xmmword, xmmword, byte) -> xmmword
function avx_dppd_128(a, b, imm) = {
  let zero : qword = 0x0000000000000000;
  let temp0 : qword = if imm[4] == bitone then __f64_mul(a[63..0], b[63..0]) else zero;
  let temp1 : qword = if imm[5] == bitone then __f64_mul(a[127..64], b[127..64]) else zero;
  let sum : qword = __f64_add(temp0, temp1);
  let lo : qword = sum & sign_extend(imm[0..0]);
  let hi : qword = sum & sign_extend(imm[1..1]);
  hi @ lo
}

// VPERMQ: permute 256-bit qwords based on imm8
val avx_vpermq : (ymmword, byte) -> ymmword
function avx_vpermq(src, imm) = {
  let sel0 : range(0, 3) = unsigned(imm[1..0]);
  let sel1 : range(0, 3) = unsigned(imm[3..2]);
  let sel2 : range(0, 3) = unsigned(imm[5..4]);
  let sel3 : range(0, 3) = unsigned(imm[7..6]);
  let q0 : qword = match sel0 { 0 => src[63..0], 1 => src[127..64], 2 => src[191..128], _ => src[255..192] };
  let q1 : qword = match sel1 { 0 => src[63..0], 1 => src[127..64], 2 => src[191..128], _ => src[255..192] };
  let q2 : qword = match sel2 { 0 => src[63..0], 1 => src[127..64], 2 => src[191..128], _ => src[255..192] };
  let q3 : qword = match sel3 { 0 => src[63..0], 1 => src[127..64], 2 => src[191..128], _ => src[255..192] };
  q3 @ q2 @ q1 @ q0
}

// VINSERTPS for VEX: takes dst xmm value, handles mem flag
val avx_insertps : (xmmword, xmmword, byte, bool) -> xmmword
function avx_insertps(dst, src, imm8, is_mem) = {
  // For memory operand, count_s (imm8[7:6]) is ignored — the 32-bit value is used directly
  let src_float : dword = if is_mem then src[31..0] else {
    let src_sel : range(0, 3) = unsigned(imm8[7..6]);
    match src_sel { 0 => src[31..0], 1 => src[63..32], 2 => src[95..64], _ => src[127..96] }
  };
  let dst_sel : range(0, 3) = unsigned(imm8[5..4]);
  let m0 : dword = zeros() - zero_extend(bool_to_bit(dst_sel == 0));
  let m1 : dword = zeros() - zero_extend(bool_to_bit(dst_sel == 1));
  let m2 : dword = zeros() - zero_extend(bool_to_bit(dst_sel == 2));
  let m3 : dword = zeros() - zero_extend(bool_to_bit(dst_sel == 3));
  let t0 : dword = (src_float & m0) | (dst[31..0] & not_vec(m0));
  let t1 : dword = (src_float & m1) | (dst[63..32] & not_vec(m1));
  let t2 : dword = (src_float & m2) | (dst[95..64] & not_vec(m2));
  let t3 : dword = (src_float & m3) | (dst[127..96] & not_vec(m3));
  let d0 : dword = t0 & sign_extend(~(imm8[0..0]));
  let d1 : dword = t1 & sign_extend(~(imm8[1..1]));
  let d2 : dword = t2 & sign_extend(~(imm8[2..2]));
  let d3 : dword = t3 & sign_extend(~(imm8[3..3]));
  d3 @ d2 @ d1 @ d0
}

// Extract word from XMM at position sel (0..7)
function extract_word_from_xmm(s, sel) = {
  match sel {
    0 => s[15..0],
    1 => s[31..16],
    2 => s[47..32],
    3 => s[63..48],
    4 => s[79..64],
    5 => s[95..80],
    6 => s[111..96],
    7 => s[127..112]
  }
}

// =========================================================================
// VEX 0F3A map dispatch
// =========================================================================

val dispatch_vex_0f3a : (byte, Prefixes) -> unit
function dispatch_vex_0f3a(opcode, pfx) = {
  let op : range(0, 255) = unsigned(opcode);
  let mp = get_mandatory_prefix(pfx);

  match op {

  // 0F3A 18: VINSERTF128 ymm1, ymm2, xmm3/m128, imm8
  24 => {
    if mp != MP_66 then raise_UD();
    if not_bool(pfx.vex_l) then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let src1 : ymmword = read_ymm(pfx.vex_vvvv);
    let src2 : xmmword = match rm {
      RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
      RM_mem(addr) => mem_read128(fixup_addr(addr)),
    };
    let imm = fetch_byte();
    // imm8[0] selects which 128-bit lane to replace
    if imm[0] == bitzero then
      write_ymm(dst, src1[255..128] @ src2)
    else
      write_ymm(dst, src2 @ src1[127..0])
  },

  // 0F3A 19: VEXTRACTF128 xmm1/m128, ymm2, imm8
  25 => {
    if mp != MP_66 then raise_UD();
    if not_bool(pfx.vex_l) then raise_UD();
    let modrm = fetch_byte();
    let src = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let src_ymm : ymmword = read_ymm(src);
    let imm = fetch_byte();
    let extracted : xmmword =
      if imm[0] == bitzero then src_ymm[127..0]
      else src_ymm[255..128];
    match rm {
      RM_reg(_) => write_xmm(modrm_xmm_rm(modrm, pfx), extracted),
      RM_mem(addr) => mem_write128(fixup_addr(addr), extracted),
    }
  },

  // 0F3A 30: KSHIFTRW k1, k2, imm8 (66, W1)
  48 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let k1 : range(0, 7) = unsigned(modrm[5..3]);
    let k2 : range(0, 7) = unsigned(modrm[2..0]);
    let imm = fetch_byte();
    let shift : range(0, 255) = unsigned(imm);
    let src : bits(16) = read_kreg(k2)[15..0];
    write_kreg(k1, zero_extend(sail_shiftright(src, shift)))
  },

  // 0F3A 32: KSHIFTLW k1, k2, imm8 (66, W1)
  50 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let k1 : range(0, 7) = unsigned(modrm[5..3]);
    let k2 : range(0, 7) = unsigned(modrm[2..0]);
    let imm = fetch_byte();
    let shift : range(0, 255) = unsigned(imm);
    let src : bits(16) = read_kreg(k2)[15..0];
    write_kreg(k1, zero_extend(sail_shiftleft(src, shift)))
  },

  // 0F3A 1D: VCVTPS2PH xmm/m64/m128, xmm/ymm, imm8 (66 prefix)
  // SDM: imm8[2]=0 → use imm8[1:0] for rounding; imm8[2]=1 → use MXCSR.RC
  29 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let src = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let imm = fetch_byte();
    // Apply rounding control from imm8
    let saved_mxcsr = __stmxcsr();
    if imm[2] == bitzero then {
      let rc : range(0, 3) = unsigned(imm[1..0]);
      let new_mxcsr : dword = (saved_mxcsr & 0xFFFF9FFF) | to_bits(32, rc * 8192);
      __ldmxcsr(new_mxcsr)
    };
    if pfx.vex_l then {
      let res : xmmword = avx_vcvtps2ph_256(read_ymm(src));
      match rm {
        RM_reg(_) => write_xmm(modrm_xmm_rm(modrm, pfx), res),
        RM_mem(addr) => mem_write128(fixup_addr(addr), res),
      }
    } else {
      let res : bits(64) = avx_vcvtps2ph_128(read_xmm(src));
      match rm {
        RM_reg(_) => write_xmm(modrm_xmm_rm(modrm, pfx), zero_extend(res)),
        RM_mem(addr) => mem_write64(fixup_addr(addr), res),
      }
    };
    __ldmxcsr(saved_mxcsr)
  },

  // 0F3A DF: VAESKEYGENASSIST — VEX.128.66.0F3A.WIG DF
  223 => {
    if mp != MP_66 then raise_UD();
    if pfx.vex_l then raise_UD();
    if pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let src : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
    let imm = fetch_byte();
    write_xmm(dst, __aeskeygenassist(src, imm))
  },

  // 0F3A F0: RORX — VEX.LZ.F2.0F3A.W0/W1 F0
  240 => {
    if mp != MP_F2 then raise_UD();
    if pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let os : OperandSize = if pfx.vex_w then OS64 else OS32;
    let src : qword = read_rm_val(rm, os, true);
    let imm = fetch_byte();
    if pfx.vex_w then {
      // 64-bit rotate right
      let rot : range(0, 63) = unsigned(imm[5..0]);
      let result : bits(64) = (src[63..0] >> rot) | (src[63..0] << (64 - rot));
      write_gpr(dst, OS64, zero_extend(result));
    } else {
      // 32-bit rotate right
      let rot : range(0, 31) = unsigned(imm[4..0]);
      let result : bits(32) = (src[31..0] >> rot) | (src[31..0] << (32 - rot));
      write_gpr(dst, OS32, zero_extend(result));
    }
  },

  // 0F3A 00: VPERMQ ymm1, ymm2/m256, imm8 (66, W1) — VEX.256 only
  0 => {
    if mp != MP_66 then raise_UD();
    if not_bool(pfx.vex_l) then raise_UD();
    if not_bool(pfx.vex_w) then raise_UD();
    if pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let src : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
    let imm = fetch_byte();
    write_ymm(dst, avx_vpermq(src, imm))
  },

  // 0F3A 01: VPERMPD ymm1, ymm2/m256, imm8 (66, W1) — VEX.256 only
  1 => {
    if mp != MP_66 then raise_UD();
    if not_bool(pfx.vex_l) then raise_UD();
    if not_bool(pfx.vex_w) then raise_UD();
    if pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let src : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
    let imm = fetch_byte();
    // Same permutation as VPERMQ — permute qwords (doubles are 64-bit like qwords)
    write_ymm(dst, avx_vpermq(src, imm))
  },

  // 0F3A 02: VPBLENDD xmm/ymm, xmm/ymm, xmm/ymm/m, imm8 (66, W0)
  2 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let src1 : ymmword = read_ymm(pfx.vex_vvvv);
      let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      let imm = fetch_byte();
      write_ymm(dst, avx_pblendd_256(src1, src2, imm))
    } else {
      let src1 : xmmword = read_xmm(pfx.vex_vvvv);
      let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
      let imm = fetch_byte();
      write_xmm(dst, avx_pblendd_128(src1, src2, imm))
    }
  },

  // 0F3A 08: VROUNDPS xmm/ymm, xmm/ymm/m, imm8 (66) — vvvv must be 1111b
  8 => {
    if mp != MP_66 then raise_UD();
    if pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let src : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      let imm = fetch_byte();
      let lo : xmmword = avx_roundps_128(src[127..0], imm);
      let hi : xmmword = avx_roundps_128(src[255..128], imm);
      write_ymm(dst, hi @ lo)
    } else {
      let src : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
      let imm = fetch_byte();
      write_xmm(dst, avx_roundps_128(src, imm))
    }
  },

  // 0F3A 09: VROUNDPD xmm/ymm, xmm/ymm/m, imm8 (66) — vvvv must be 1111b
  9 => {
    if mp != MP_66 then raise_UD();
    if pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let src : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      let imm = fetch_byte();
      let lo : xmmword = avx_roundpd_128(src[127..0], imm);
      let hi : xmmword = avx_roundpd_128(src[255..128], imm);
      write_ymm(dst, hi @ lo)
    } else {
      let src : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
      let imm = fetch_byte();
      write_xmm(dst, avx_roundpd_128(src, imm))
    }
  },

  // 0F3A 0A: VROUNDSS xmm, xmm, xmm/m32, imm8 (66) — VEX.128 only, has vvvv source
  10 => {
    if mp != MP_66 then raise_UD();
    if pfx.vex_l then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let src1 : xmmword = read_xmm(pfx.vex_vvvv);
    let src2_lo : dword = match rm {
      RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[31..0],
      RM_mem(addr) => mem_read32(fixup_addr(addr)),
    };
    let imm = fetch_byte();
    let rounded : dword = __f32_round(src2_lo, imm);
    write_xmm(dst, src1[127..32] @ rounded)
  },

  // 0F3A 0B: VROUNDSD xmm, xmm, xmm/m64, imm8 (66) — VEX.128 only, has vvvv source
  11 => {
    if mp != MP_66 then raise_UD();
    if pfx.vex_l then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let src1 : xmmword = read_xmm(pfx.vex_vvvv);
    let src2_lo : qword = match rm {
      RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[63..0],
      RM_mem(addr) => mem_read64(fixup_addr(addr)),
    };
    let imm = fetch_byte();
    let rounded : qword = __f64_round(src2_lo, imm);
    write_xmm(dst, src1[127..64] @ rounded)
  },

  // 0F3A 0C: VBLENDPS xmm/ymm, xmm/ymm, xmm/ymm/m, imm8 (66)
  12 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let src1 : ymmword = read_ymm(pfx.vex_vvvv);
      let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      let imm = fetch_byte();
      write_ymm(dst, avx_blendps_256(src1, src2, imm))
    } else {
      let src1 : xmmword = read_xmm(pfx.vex_vvvv);
      let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
      let imm = fetch_byte();
      write_xmm(dst, avx_blendps_128(src1, src2, imm))
    }
  },

  // 0F3A 0D: VBLENDPD xmm/ymm, xmm/ymm, xmm/ymm/m, imm8 (66)
  13 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let src1 : ymmword = read_ymm(pfx.vex_vvvv);
      let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      let imm = fetch_byte();
      write_ymm(dst, avx_blendpd_256(src1, src2, imm))
    } else {
      let src1 : xmmword = read_xmm(pfx.vex_vvvv);
      let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
      let imm = fetch_byte();
      write_xmm(dst, avx_blendpd_128(src1, src2, imm))
    }
  },

  // 0F3A 0E: VPBLENDW xmm/ymm, xmm/ymm, xmm/ymm/m, imm8 (66)
  14 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let src1 : ymmword = read_ymm(pfx.vex_vvvv);
      let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      let imm = fetch_byte();
      // For 256-bit, same imm8 pattern applies to each 128-bit lane
      let lo : xmmword = avx_pblendw_128(src1[127..0], src2[127..0], imm);
      let hi : xmmword = avx_pblendw_128(src1[255..128], src2[255..128], imm);
      write_ymm(dst, hi @ lo)
    } else {
      let src1 : xmmword = read_xmm(pfx.vex_vvvv);
      let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
      let imm = fetch_byte();
      write_xmm(dst, avx_pblendw_128(src1, src2, imm))
    }
  },

  // 0F3A 0F: VPALIGNR xmm/ymm, xmm/ymm, xmm/ymm/m, imm8 (66)
  15 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let src1 : ymmword = read_ymm(pfx.vex_vvvv);
      let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      let imm = fetch_byte();
      // Each 128-bit lane is aligned independently
      let lo : xmmword = avx_palignr_128(src1[127..0], src2[127..0], imm);
      let hi : xmmword = avx_palignr_128(src1[255..128], src2[255..128], imm);
      write_ymm(dst, hi @ lo)
    } else {
      let src1 : xmmword = read_xmm(pfx.vex_vvvv);
      let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
      let imm = fetch_byte();
      write_xmm(dst, avx_palignr_128(src1, src2, imm))
    }
  },

  // 0F3A 14: VPEXTRB r/m8, xmm, imm8 (66) — VEX.128 only, vvvv must be 1111b
  20 => {
    if mp != MP_66 then raise_UD();
    if pfx.vex_l then raise_UD();
    if pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch_byte();
    let src = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let imm = fetch_byte();
    let v : byte = extract_byte_from_xmm(read_xmm(src), imm);
    match rm {
      RM_reg(_) => {
        let dst_reg = modrm_rm_reg(modrm, pfx);
        write_gpr32(dst_reg, zero_extend(v));
      },
      RM_mem(addr) => mem_write8(fixup_addr(addr), v),
    }
  },

  // 0F3A 15: VPEXTRW r/m16, xmm, imm8 (66) — VEX.128 only, vvvv must be 1111b
  21 => {
    if mp != MP_66 then raise_UD();
    if pfx.vex_l then raise_UD();
    if pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch_byte();
    let src = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let imm = fetch_byte();
    let sel : range(0, 7) = unsigned(imm[2..0]);
    let w : word = extract_word_from_xmm(read_xmm(src), sel);
    match rm {
      RM_reg(_) => {
        let dst_reg = modrm_rm_reg(modrm, pfx);
        write_gpr32(dst_reg, zero_extend(w));
      },
      RM_mem(addr) => mem_write16(fixup_addr(addr), w),
    }
  },

  // 0F3A 16: VPEXTRD/VPEXTRQ r/m, xmm, imm8 (66) — VEX.128 only, vvvv must be 1111b
  22 => {
    if mp != MP_66 then raise_UD();
    if pfx.vex_l then raise_UD();
    if pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch_byte();
    let src = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let imm = fetch_byte();
    let src_xmm : xmmword = read_xmm(src);
    match rm {
      RM_reg(_) => {
        let dst_reg = modrm_rm_reg(modrm, pfx);
        if pfx.rex_w then write_gpr64(dst_reg, extract_qword_from_xmm(src_xmm, imm))
        else write_gpr32(dst_reg, extract_dword_from_xmm(src_xmm, imm))
      },
      RM_mem(addr) => {
        let a = fixup_addr(addr);
        if pfx.rex_w then mem_write64(a, extract_qword_from_xmm(src_xmm, imm))
        else mem_write32(a, extract_dword_from_xmm(src_xmm, imm))
      },
    }
  },

  // 0F3A 17: VEXTRACTPS r/m32, xmm, imm8 (66) — VEX.128 only, vvvv must be 1111b
  23 => {
    if mp != MP_66 then raise_UD();
    if pfx.vex_l then raise_UD();
    if pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch_byte();
    let src = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let imm = fetch_byte();
    let v : dword = extract_dword_from_xmm(read_xmm(src), imm);
    match rm {
      RM_reg(_) => {
        let dst_reg = modrm_rm_reg(modrm, pfx);
        write_gpr32(dst_reg, v);
      },
      RM_mem(addr) => mem_write32(fixup_addr(addr), v),
    }
  },

  // 0F3A 20: VPINSRB xmm, xmm, r/m8, imm8 (66) — VEX.128 only
  32 => {
    if mp != MP_66 then raise_UD();
    if pfx.vex_l then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let src1 : xmmword = read_xmm(pfx.vex_vvvv);
    let v : byte = match rm {
      RM_reg(_) => read_gpr8l(modrm_rm_reg(modrm, pfx)),
      RM_mem(addr) => mem_read8(fixup_addr(addr)),
    };
    let imm = fetch_byte();
    let sel : range(0, 15) = unsigned(imm[3..0]);
    write_xmm(dst, insert_byte(src1, v, sel))
  },

  // 0F3A 21: VINSERTPS xmm, xmm, xmm/m32, imm8 (66) — VEX.128 only
  33 => {
    if mp != MP_66 then raise_UD();
    if pfx.vex_l then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let dst_base : xmmword = read_xmm(pfx.vex_vvvv);
    let is_mem : bool = match rm { RM_reg(_) => false, RM_mem(_) => true };
    let src : xmmword = match rm {
      RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
      RM_mem(addr) => zero_extend(mem_read32(fixup_addr(addr))),
    };
    let imm = fetch_byte();
    write_xmm(dst, avx_insertps(dst_base, src, imm, is_mem))
  },

  // 0F3A 22: VPINSRD/VPINSRQ xmm, xmm, r/m, imm8 (66) — VEX.128 only
  34 => {
    if mp != MP_66 then raise_UD();
    if pfx.vex_l then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let src1 : xmmword = read_xmm(pfx.vex_vvvv);
    let imm = fetch_byte();
    if pfx.rex_w then {
      // VPINSRQ xmm1, xmm2, r/m64, imm8
      let v : qword = match rm {
        RM_reg(_) => read_gpr64(modrm_rm_reg(modrm, pfx)),
        RM_mem(addr) => mem_read64(fixup_addr(addr)),
      };
      let sel : range(0, 1) = unsigned(imm[0..0]);
      let r : xmmword = match sel {
        0 => src1[127..64] @ v,
        1 => v @ src1[63..0]
      };
      write_xmm(dst, r)
    } else {
      // VPINSRD xmm1, xmm2, r/m32, imm8
      let v : dword = match rm {
        RM_reg(_) => read_gpr32(modrm_rm_reg(modrm, pfx)),
        RM_mem(addr) => mem_read32(fixup_addr(addr)),
      };
      let sel : range(0, 3) = unsigned(imm[1..0]);
      write_xmm(dst, insert_dword(src1, v, sel))
    }
  },

  // 0F3A 40: VDPPS xmm/ymm, xmm/ymm, xmm/ymm/m, imm8 (66)
  64 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let src1 : ymmword = read_ymm(pfx.vex_vvvv);
      let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      let imm = fetch_byte();
      // 256-bit DPPS: each 128-bit lane independently
      let lo : xmmword = avx_dpps_128(src1[127..0], src2[127..0], imm);
      let hi : xmmword = avx_dpps_128(src1[255..128], src2[255..128], imm);
      write_ymm(dst, hi @ lo)
    } else {
      let src1 : xmmword = read_xmm(pfx.vex_vvvv);
      let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
      let imm = fetch_byte();
      write_xmm(dst, avx_dpps_128(src1, src2, imm))
    }
  },

  // 0F3A 41: VDPPD xmm, xmm, xmm/m128, imm8 (66) — VEX.128 only
  65 => {
    if mp != MP_66 then raise_UD();
    if pfx.vex_l then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let src1 : xmmword = read_xmm(pfx.vex_vvvv);
    let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
    let imm = fetch_byte();
    write_xmm(dst, avx_dppd_128(src1, src2, imm))
  },

  // 0F3A 42: VMPSADBW xmm/ymm, xmm/ymm, xmm/ymm/m, imm8 (66)
  66 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let src1 : ymmword = read_ymm(pfx.vex_vvvv);
      let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      let imm = fetch_byte();
      // 256-bit: each 128-bit lane independently, imm8[2:0] for low lane, imm8[5:3] for high lane
      let lo : xmmword = __mpsadbw(src1[127..0], src2[127..0], 0b00000 @ imm[2..0]);
      let hi : xmmword = __mpsadbw(src1[255..128], src2[255..128], 0b00000 @ imm[5..3]);
      write_ymm(dst, hi @ lo)
    } else {
      let src1 : xmmword = read_xmm(pfx.vex_vvvv);
      let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
      let imm = fetch_byte();
      write_xmm(dst, __mpsadbw(src1, src2, imm))
    }
  },

  // 0F3A 44: VPCLMULQDQ xmm, xmm, xmm/m128, imm8 (66) — VEX.128 only
  68 => {
    if mp != MP_66 then raise_UD();
    if pfx.vex_l then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let src1 : xmmword = read_xmm(pfx.vex_vvvv);
    let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
    let imm = fetch_byte();
    let sel_a : qword = blend64(src1[63..0], src1[127..64], imm[0..0]);
    let sel_b : qword = blend64(src2[63..0], src2[127..64], imm[4..4]);
    let result : xmmword = __pclmulqdq(sel_a, sel_b);
    write_xmm(dst, result)
  },

  // 0F3A 04: VPERMILPS xmm/ymm, xmm/ymm/m, imm8 (66, vvvv must be 1111b)
  4 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let imm = fetch_byte();
    if pfx.vex_l then {
      let src : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      var result : ymmword = zeros();
      // Each 128-bit lane: same imm8 selects dwords within that lane
      foreach (i from 0 to 3) {
        let sel : range(0, 3) = unsigned(imm[(i * 2 + 1) .. (i * 2)]);
        result[(i * 32 + 31) .. (i * 32)] = src[(sel * 32 + 31) .. (sel * 32)]
      };
      foreach (i from 4 to 7) {
        let sel : range(0, 3) = unsigned(imm[((i - 4) * 2 + 1) .. ((i - 4) * 2)]);
        result[(i * 32 + 31) .. (i * 32)] = src[((sel + 4) * 32 + 31) .. ((sel + 4) * 32)]
      };
      write_ymm(dst, result)
    } else {
      let src : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
      var result : xmmword = zeros();
      foreach (i from 0 to 3) {
        let sel : range(0, 3) = unsigned(imm[(i * 2 + 1) .. (i * 2)]);
        result[(i * 32 + 31) .. (i * 32)] = src[(sel * 32 + 31) .. (sel * 32)]
      };
      write_xmm(dst, result)
    }
  },

  // 0F3A 05: VPERMILPD xmm/ymm, xmm/ymm/m, imm8 (66, vvvv must be 1111b)
  5 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let imm = fetch_byte();
    if pfx.vex_l then {
      let src : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      var result : ymmword = zeros();
      // Bit 0 selects for element 0, bit 1 for element 1 (lane 0)
      // Bit 2 selects for element 2, bit 3 for element 3 (lane 1)
      let s0 : range(0, 1) = unsigned(imm[0..0]);
      result[63..0] = src[(s0 * 64 + 63) .. (s0 * 64)];
      let s1 : range(0, 1) = unsigned(imm[1..1]);
      result[127..64] = src[(s1 * 64 + 63) .. (s1 * 64)];
      let s2 : range(0, 1) = unsigned(imm[2..2]);
      result[191..128] = src[((s2 + 2) * 64 + 63) .. ((s2 + 2) * 64)];
      let s3 : range(0, 1) = unsigned(imm[3..3]);
      result[255..192] = src[((s3 + 2) * 64 + 63) .. ((s3 + 2) * 64)];
      write_ymm(dst, result)
    } else {
      let src : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
      var result : xmmword = zeros();
      let s0 : range(0, 1) = unsigned(imm[0..0]);
      result[63..0] = src[(s0 * 64 + 63) .. (s0 * 64)];
      let s1 : range(0, 1) = unsigned(imm[1..1]);
      result[127..64] = src[(s1 * 64 + 63) .. (s1 * 64)];
      write_xmm(dst, result)
    }
  },

  // 0F3A 06: VPERM2F128 ymm, ymm, ymm/m256, imm8 (66, VEX.256 only)
  6 => {
    if mp != MP_66 | ~(pfx.vex_l) then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let src1 : ymmword = read_ymm(pfx.vex_vvvv);
    let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
    let imm = fetch_byte();
    // Low 128-bit result selected by imm8[1:0], zeroed if imm8[3]
    let sel_lo : range(0, 3) = unsigned(imm[1..0]);
    let lo_selected : xmmword = match sel_lo {
      0 => src1[127..0],
      1 => src1[255..128],
      2 => src2[127..0],
      3 => src2[255..128],
    };
    let lo_result : xmmword = lo_selected & sign_extend(~(imm[3..3]));
    // High 128-bit result selected by imm8[5:4], zeroed if imm8[7]
    let sel_hi : range(0, 3) = unsigned(imm[5..4]);
    let hi_selected : xmmword = match sel_hi {
      0 => src1[127..0],
      1 => src1[255..128],
      2 => src2[127..0],
      3 => src2[255..128],
    };
    let hi_result : xmmword = hi_selected & sign_extend(~(imm[7..7]));
    write_ymm(dst, hi_result @ lo_result)
  },

  // 0F3A 38: VINSERTI128 ymm, ymm, xmm/m128, imm8 (66, VEX.256 only)
  56 => {
    if mp != MP_66 | ~(pfx.vex_l) then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let src1 : ymmword = read_ymm(pfx.vex_vvvv);
    let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
    let imm = fetch_byte();
    if imm[0] == bitzero then {
      // Insert into lower 128 bits
      write_ymm(dst, src1[255..128] @ src2)
    } else {
      // Insert into upper 128 bits
      write_ymm(dst, src2 @ src1[127..0])
    }
  },

  // 0F3A 39: VEXTRACTI128 xmm/m128, ymm, imm8 (66, VEX.256 only, vvvv must be 1111b)
  57 => {
    if mp != MP_66 | ~(pfx.vex_l) | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch_byte();
    let src = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let imm = fetch_byte();
    let v : ymmword = read_ymm(src);
    let extracted : xmmword = (v >> (unsigned(zero_extend(imm[0..0]) : bits(1)) * 128))[127..0];
    match rm {
      RM_reg(_) => write_xmm(modrm_xmm_rm(modrm, pfx), extracted),
      RM_mem(addr) => {
        let a = fixup_addr(addr);
        mem_write128(a, extracted)
      },
    }
  },

  // 0F3A 46: VPERM2I128 ymm, ymm, ymm/m256, imm8 (66, VEX.256 only)
  70 => {
    if mp != MP_66 | ~(pfx.vex_l) then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let src1 : ymmword = read_ymm(pfx.vex_vvvv);
    let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
    let imm = fetch_byte();
    // Same logic as VPERM2F128
    let sel_lo : range(0, 3) = unsigned(imm[1..0]);
    let lo_selected : xmmword = match sel_lo {
      0 => src1[127..0],
      1 => src1[255..128],
      2 => src2[127..0],
      3 => src2[255..128],
    };
    let lo_result : xmmword = lo_selected & sign_extend(~(imm[3..3]));
    let sel_hi : range(0, 3) = unsigned(imm[5..4]);
    let hi_selected : xmmword = match sel_hi {
      0 => src1[127..0],
      1 => src1[255..128],
      2 => src2[127..0],
      3 => src2[255..128],
    };
    let hi_result : xmmword = hi_selected & sign_extend(~(imm[7..7]));
    write_ymm(dst, hi_result @ lo_result)
  },

  // VGF2P8AFFINEQB: VEX.128/256.66.0F3A.W1 CE /r ib
  206 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src1_idx = pfx.vex_vvvv;
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let src1 : ymmword = read_ymm(src1_idx);
      let src2 : ymmword = match rm {
        RM_reg(_) => read_ymm(modrm_xmm_rm(modrm, pfx)),
        RM_mem(addr) => mem_read256(fixup_addr(addr)),
      };
      let imm = fetch_byte();
      let lo = __gf2p8affineqb(src1[127..0], src2[127..0], imm);
      let hi = __gf2p8affineqb(src1[255..128], src2[255..128], imm);
      write_ymm(dst, hi @ lo)
    } else {
      let src1 : xmmword = read_xmm(src1_idx);
      let src2 : xmmword = decode_xmm_src(modrm, rm, pfx);
      let imm = fetch_byte();
      write_xmm(dst, __gf2p8affineqb(src1, src2, imm))
    }
  },

  // VGF2P8AFFINEINVQB: VEX.128/256.66.0F3A.W1 CF /r ib
  207 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let src1_idx = pfx.vex_vvvv;
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let src1 : ymmword = read_ymm(src1_idx);
      let src2 : ymmword = match rm {
        RM_reg(_) => read_ymm(modrm_xmm_rm(modrm, pfx)),
        RM_mem(addr) => mem_read256(fixup_addr(addr)),
      };
      let imm = fetch_byte();
      let lo = __gf2p8affineinvqb(src1[127..0], src2[127..0], imm);
      let hi = __gf2p8affineinvqb(src1[255..128], src2[255..128], imm);
      write_ymm(dst, hi @ lo)
    } else {
      let src1 : xmmword = read_xmm(src1_idx);
      let src2 : xmmword = decode_xmm_src(modrm, rm, pfx);
      let imm = fetch_byte();
      write_xmm(dst, __gf2p8affineinvqb(src1, src2, imm))
    }
  },

  _ => raise_UD(),
  }
}

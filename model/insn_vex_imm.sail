// x86-64 — VEX Immediate Instructions (0F3A map)
//
// Blend, round, dpps, palignr, permil, insert/extract, cvtps2ph,
// kshift, mpsadbw, pblendd.

// =========================================================================
// VEX 0F3A helpers — blend, palignr, round, dpps/dppd, permute
// =========================================================================

// Immediate blend: for each eb-wide element i, select src1 or src2 based on imm[i].
val avx_blend_imm : forall 'vl 'eb, 'vl in {128, 256} & 'eb in {16, 32, 64}.
  (int('eb), bits('vl), bits('vl), byte) -> bits('vl)
function avx_blend_imm(eb, src1, src2, imm) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 'eb - 1)) {
    let lo = i * 'eb;
    assert(i < 8);
    r[(lo + 'eb - 1)..lo] = blend(src1[(lo + 'eb - 1)..lo], src2[(lo + 'eb - 1)..lo], imm[i])
  };
  r
}

// VEX blend dispatch helper.
val vex_exec_blend : ({16, 32, 64}, Prefixes) -> unit
function vex_exec_blend(eb, pfx) = {
  let modrm = fetch(1);
  let dst = modrm_xmm_reg(modrm, pfx);
  let src = modrm_rm(modrm, pfx);
  let vl = vex_vl(pfx);
  let src1 = read_simd(vl, pfx.vex_vvvv);
  let src2 = decode_vex_src(vl, modrm, src, pfx);
  let imm = fetch(1);
  write_simd(vl, dst, avx_blend_imm(eb, src1, src2, imm))
}

// VPALIGNR 128-bit: concatenate src1(high):src2(low), shift right by imm bytes, take low 128 bits
val avx_palignr_128 : (xmmword, xmmword, byte) -> xmmword
function avx_palignr_128(src1, src2, imm) = {
  let shift_bytes : range(0, 255) = unsigned(imm);
  let concat : ymmword = src1 @ src2;
  (concat >> (shift_bytes * 8))[127..0]
}

// VROUNDPS: round each f32 element per imm control
val avx_roundps : forall 'vl, 'vl in {128, 256}. (implicit('vl), bits('vl), byte) -> bits('vl)
function avx_roundps(vl, src, imm) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 32 - 1)) {
    let lo = i * 32;
    r[(lo + 31)..lo] = fp_round(src[(lo + 31)..lo], imm)
  };
  r
}

// VROUNDPD: round each f64 element per imm control
val avx_roundpd : forall 'vl, 'vl in {128, 256}. (implicit('vl), bits('vl), byte) -> bits('vl)
function avx_roundpd(vl, src, imm) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 64 - 1)) {
    let lo = i * 64;
    r[(lo + 63)..lo] = fp_round(src[(lo + 63)..lo], imm)
  };
  r
}

// VDPPS 128-bit: dot product of packed singles
val avx_dpps_128 : (xmmword, xmmword, byte) -> xmmword
function avx_dpps_128(a, b, imm) = {
  let temp0 : dword = fp_mul(a[31..0], b[31..0]) & sign_extend(imm[4]);
  let temp1 : dword = fp_mul(a[63..32], b[63..32]) & sign_extend(imm[5]);
  let temp2 : dword = fp_mul(a[95..64], b[95..64]) & sign_extend(imm[6]);
  let temp3 : dword = fp_mul(a[127..96], b[127..96]) & sign_extend(imm[7]);
  let sum01 : dword = fp_add(temp0, temp1);
  let sum23 : dword = fp_add(temp2, temp3);
  let sum : dword = fp_add(sum01, sum23);
  let d0 : dword = sum & sign_extend(imm[0]);
  let d1 : dword = sum & sign_extend(imm[1]);
  let d2 : dword = sum & sign_extend(imm[2]);
  let d3 : dword = sum & sign_extend(imm[3]);
  d3 @ d2 @ d1 @ d0
}

// VDPPD 128-bit: dot product of packed doubles
val avx_dppd_128 : (xmmword, xmmword, byte) -> xmmword
function avx_dppd_128(a, b, imm) = {
  let temp0 : qword = fp_mul(a[63..0], b[63..0]) & sign_extend(imm[4]);
  let temp1 : qword = fp_mul(a[127..64], b[127..64]) & sign_extend(imm[5]);
  let sum : qword = fp_add(temp0, temp1);
  let lo : qword = sum & sign_extend(imm[0]);
  let hi : qword = sum & sign_extend(imm[1]);
  hi @ lo
}

// VPERMQ: permute 256-bit qwords based on imm8
val avx_vpermq : (ymmword, byte) -> ymmword
function avx_vpermq(src, imm) = {
  let sel0 : range(0, 3) = unsigned(imm[1..0]);
  let sel1 : range(0, 3) = unsigned(imm[3..2]);
  let sel2 : range(0, 3) = unsigned(imm[5..4]);
  let sel3 : range(0, 3) = unsigned(imm[7..6]);
  let q0 : qword = match sel0 { 0 => src[63..0], 1 => src[127..64], 2 => src[191..128], 3 => src[255..192] };
  let q1 : qword = match sel1 { 0 => src[63..0], 1 => src[127..64], 2 => src[191..128], 3 => src[255..192] };
  let q2 : qword = match sel2 { 0 => src[63..0], 1 => src[127..64], 2 => src[191..128], 3 => src[255..192] };
  let q3 : qword = match sel3 { 0 => src[63..0], 1 => src[127..64], 2 => src[191..128], 3 => src[255..192] };
  q3 @ q2 @ q1 @ q0
}

// VINSERTPS for VEX: takes dst xmm value, handles mem flag
val avx_insertps : (xmmword, xmmword, byte, bool) -> xmmword
function avx_insertps(dst, src, imm8, is_mem) = {
  // For memory operand, count_s (imm8[7:6]) is ignored — the 32-bit value is used directly
  let src_float : dword = if is_mem then src[31..0] else {
    let src_sel : range(0, 3) = unsigned(imm8[7..6]);
    match src_sel { 0 => src[31..0], 1 => src[63..32], 2 => src[95..64], 3 => src[127..96] }
  };
  let sel = imm8[5..4];
  let m0 : dword = sign_extend(~(sel[1] | sel[0]));
  let x1 : bits(2) = sel ^ 0b01;
  let m1 : dword = sign_extend(~(x1[1] | x1[0]));
  let x2 : bits(2) = sel ^ 0b10;
  let m2 : dword = sign_extend(~(x2[1] | x2[0]));
  let x3 : bits(2) = sel ^ 0b11;
  let m3 : dword = sign_extend(~(x3[1] | x3[0]));
  let t0 : dword = (src_float & m0) | (dst[31..0] & ~(m0));
  let t1 : dword = (src_float & m1) | (dst[63..32] & ~(m1));
  let t2 : dword = (src_float & m2) | (dst[95..64] & ~(m2));
  let t3 : dword = (src_float & m3) | (dst[127..96] & ~(m3));
  let d0 : dword = t0 & sign_extend(~(imm8[0]));
  let d1 : dword = t1 & sign_extend(~(imm8[1]));
  let d2 : dword = t2 & sign_extend(~(imm8[2]));
  let d3 : dword = t3 & sign_extend(~(imm8[3]));
  d3 @ d2 @ d1 @ d0
}


// =========================================================================
// VEX 0F3A map dispatch
// =========================================================================

val dispatch_vex_0f3a : (byte, Prefixes) -> unit
function dispatch_vex_0f3a(opcode, pfx) = {
  let op : range(0, 255) = unsigned(opcode);
  let mp = get_mandatory_prefix(pfx);

  match op {

  // 0F3A 18: VINSERTF128 / 0F3A 38: VINSERTI128
  // ymm1, ymm2, xmm3/m128, imm8 (66, VEX.256 only) — identical semantics
  op if op == 24 | op == 56 => {
    if mp != MP_66 | ~(pfx.vex_l) then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    let src1 : ymmword = read_simd(pfx.vex_vvvv);
    let src2 : xmmword = decode_vex_src(128, modrm, src, pfx);
    let imm = fetch(1);
    if imm[0] == 0b0 then write_simd(256, dst, src1[255..128] @ src2)
    else write_simd(256, dst, src2 @ src1[127..0])
  },

  // 0F3A 19: VEXTRACTF128 / 0F3A 39: VEXTRACTI128
  // xmm1/m128, ymm2, imm8 (66, VEX.256 only, vvvv must be 1111b) — identical
  op if op == 25 | op == 57 => {
    if mp != MP_66 | ~(pfx.vex_l) | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch(1);
    let src = modrm_xmm_reg(modrm, pfx);
    let dest = modrm_rm(modrm, pfx);
    let imm = fetch(1);
    let x : ymmword = read_simd(src);
    let extracted : xmmword = if imm[0] == 0b0 then x[127..0] else x[255..128];
    match dest {
      RM_reg(_) => write_simd(128, modrm_xmm_rm(modrm, pfx), extracted),
      RM_mem(m) => write_mem(m, extracted),
    }
  },

  // 0F3A 30: KSHIFTRW (66,W1) / KSHIFTRB (66,W0)
  48 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let k1 : range(0, 7) = unsigned(modrm[5..3]);
    let k2 : range(0, 7) = unsigned(modrm[2..0]);
    let imm = fetch(1);
    let shift : range(0, 255) = unsigned(imm);
    let w_mask : qword = sign_extend(bool_to_bit(pfx.vex_w));
    let mask : qword = (0x000000000000FF00 & w_mask) | 0x00000000000000FF;
    let src : qword = read_kreg(k2) & mask;
    write_kreg(k1, (src >> shift) & mask)
  },

  // 0F3A 31: KSHIFTRD (66,W0) / KSHIFTRQ (66,W1)
  49 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let k1 : range(0, 7) = unsigned(modrm[5..3]);
    let k2 : range(0, 7) = unsigned(modrm[2..0]);
    let imm = fetch(1);
    let shift : range(0, 255) = unsigned(imm);
    let w_mask : qword = sign_extend(bool_to_bit(pfx.vex_w));
    let mask : qword = (0xFFFFFFFF00000000 & w_mask) | 0x00000000FFFFFFFF;
    let src : qword = read_kreg(k2) & mask;
    write_kreg(k1, (src >> shift) & mask)
  },

  // 0F3A 32: KSHIFTLW (66,W1) / KSHIFTLB (66,W0)
  50 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let k1 : range(0, 7) = unsigned(modrm[5..3]);
    let k2 : range(0, 7) = unsigned(modrm[2..0]);
    let imm = fetch(1);
    let shift : range(0, 255) = unsigned(imm);
    let w_mask : qword = sign_extend(bool_to_bit(pfx.vex_w));
    let mask : qword = (0x000000000000FF00 & w_mask) | 0x00000000000000FF;
    let src : qword = read_kreg(k2) & mask;
    write_kreg(k1, (src << shift) & mask)
  },

  // 0F3A 33: KSHIFTLD (66,W0) / KSHIFTLQ (66,W1)
  51 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let k1 : range(0, 7) = unsigned(modrm[5..3]);
    let k2 : range(0, 7) = unsigned(modrm[2..0]);
    let imm = fetch(1);
    let shift : range(0, 255) = unsigned(imm);
    let w_mask : qword = sign_extend(bool_to_bit(pfx.vex_w));
    let mask : qword = (0xFFFFFFFF00000000 & w_mask) | 0x00000000FFFFFFFF;
    let src : qword = read_kreg(k2) & mask;
    write_kreg(k1, (src << shift) & mask)
  },

  // 0F3A 1D: VCVTPS2PH xmm/m64/m128, xmm/ymm, imm8 (66 prefix)
  // SDM: imm8[2]=0 → use imm8[1:0] for rounding; imm8[2]=1 → use MXCSR.RC
  29 => {
    if ~(has_f16c) then raise_UD();
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let src = modrm_xmm_reg(modrm, pfx);
    let dest = modrm_rm(modrm, pfx);
    let imm = fetch(1);
    let rc : bits(2) = if imm[2] == 0b0 then imm[1..0] else __stmxcsr()[14..13];
    let vl = if pfx.vex_l then 256 else 128;
    let res = avx_vcvtps2ph(read_simd(vl, src), rc);
    match dest {
      RM_reg(_) => write_simd(128, modrm_xmm_rm(modrm, pfx), zero_extend(res)),
      RM_mem(m) => write_mem(m, res),
    }
  },

  // 0F3A DF: VAESKEYGENASSIST — VEX.128.66.0F3A.WIG DF
  223 => {
    if ~(has_aesni) then raise_UD();
    if mp != MP_66 then raise_UD();
    if pfx.vex_l then raise_UD();
    if pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src2 = modrm_rm(modrm, pfx);
    let src : xmmword = decode_vex_src(128, modrm, src2, pfx);
    let imm = fetch(1);
    write_simd(128, dst, __aeskeygenassist(src, imm))
  },

  // 0F3A F0: RORX — VEX.LZ.F2.0F3A.W0/W1 F0
  240 => {
    if mp != MP_F2 then raise_UD();
    if pfx.vex_vvvv != 0 then raise_UD();
    let (dst, src2) = fetch_modrm(pfx);
    let os : {32, 64} = if pfx.vex_w then 64 else 32;
    let src = v(os, src2);
    let imm = fetch(1);
    let shift : range(0, 63) = unsigned(imm[(if pfx.vex_w then 5 else 4)..0]);
    assert(shift < os);
    v(os, dst) = rotr(src, shift);
  },

  // 0F3A 00: VPERMQ ymm1, ymm2/m256, imm8 (66, W1) — VEX.256 only
  0 => {
    if mp != MP_66 then raise_UD();
    if ~(pfx.vex_l) then raise_UD();
    if ~(pfx.vex_w) then raise_UD();
    if pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src2 = modrm_rm(modrm, pfx);
    let src : ymmword = decode_vex_src(256, modrm, src2, pfx);
    let imm = fetch(1);
    write_simd(256, dst, avx_vpermq(src, imm))
  },

  // 0F3A 01: VPERMPD ymm1, ymm2/m256, imm8 (66, W1) — VEX.256 only
  1 => {
    if mp != MP_66 then raise_UD();
    if ~(pfx.vex_l) then raise_UD();
    if ~(pfx.vex_w) then raise_UD();
    if pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src2 = modrm_rm(modrm, pfx);
    let src : ymmword = decode_vex_src(256, modrm, src2, pfx);
    let imm = fetch(1);
    // Same permutation as VPERMQ — permute qwords (doubles are 64-bit like qwords)
    write_simd(256, dst, avx_vpermq(src, imm))
  },

  // 0F3A 02: VPBLENDD xmm/ymm, xmm/ymm, xmm/ymm/m, imm8 (66, W0)
  2 => { if mp != MP_66 then raise_UD(); vex_exec_blend(32, pfx) },

  // 0F3A 08: VROUNDPS xmm/ymm, xmm/ymm/m, imm8 (66) — vvvv must be 1111b
  8 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src2 = modrm_rm(modrm, pfx);
    let vl = vex_vl(pfx);
    let src = decode_vex_src(vl, modrm, src2, pfx);
    let imm = fetch(1);
    write_simd(vl, dst, avx_roundps(src, imm))
  },

  // 0F3A 09: VROUNDPD xmm/ymm, xmm/ymm/m, imm8 (66) — vvvv must be 1111b
  9 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src2 = modrm_rm(modrm, pfx);
    let vl = vex_vl(pfx);
    let src = decode_vex_src(vl, modrm, src2, pfx);
    let imm = fetch(1);
    write_simd(vl, dst, avx_roundpd(src, imm))
  },

  // 0F3A 0A: VROUNDSS xmm, xmm, xmm/m32, imm8 (66) — VEX.128 only, has vvvv source
  10 => {
    if mp != MP_66 then raise_UD();
    if pfx.vex_l then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    let src1 : xmmword = read_simd(pfx.vex_vvvv);
    let src2_lo : dword = match src {
      RM_reg(_) => read_simd(128, modrm_xmm_rm(modrm, pfx))[31..0],
      RM_mem(m) => v(m),
    };
    let imm = fetch(1);
    let rounded : dword = fp_round(src2_lo, imm);
    write_simd(128, dst, src1[127..32] @ rounded)
  },

  // 0F3A 0B: VROUNDSD xmm, xmm, xmm/m64, imm8 (66) — VEX.128 only, has vvvv source
  11 => {
    if mp != MP_66 then raise_UD();
    if pfx.vex_l then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    let src1 : xmmword = read_simd(pfx.vex_vvvv);
    let src2_lo : qword = match src {
      RM_reg(_) => read_simd(128, modrm_xmm_rm(modrm, pfx))[63..0],
      RM_mem(m) => v(m),
    };
    let imm = fetch(1);
    let rounded : qword = fp_round(src2_lo, imm);
    write_simd(128, dst, src1[127..64] @ rounded)
  },

  // 0F3A 0C: VBLENDPS xmm/ymm, xmm/ymm, xmm/ymm/m, imm8 (66)
  12 => { if mp != MP_66 then raise_UD(); vex_exec_blend(32, pfx) },
  // 0F3A 0D: VBLENDPD xmm/ymm, xmm/ymm, xmm/ymm/m, imm8 (66)
  13 => { if mp != MP_66 then raise_UD(); vex_exec_blend(64, pfx)
  },

  // 0F3A 0E: VPBLENDW xmm/ymm, xmm/ymm, xmm/ymm/m, imm8 (66)
  // For 256-bit, same imm8 pattern applies to each 128-bit lane
  14 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    let imm = fetch(1);
    if pfx.vex_l then {
      let src1 : ymmword = read_simd(pfx.vex_vvvv);
      let src2 : ymmword = decode_vex_src(256, modrm, src, pfx);
      // VPBLENDW 256-bit: same imm8 applied to each 128-bit lane independently
      let lo = avx_blend_imm(16, src1[127..0], src2[127..0], imm);
      let hi = avx_blend_imm(16, src1[255..128], src2[255..128], imm);
      write_simd(256, dst, hi @ lo)
    } else {
      let src1 : xmmword = read_simd(pfx.vex_vvvv);
      let src2 : xmmword = decode_vex_src(128, modrm, src, pfx);
      write_simd(128, dst, avx_blend_imm(16, src1, src2, imm))
    }
  },

  // 0F3A 0F: VPALIGNR xmm/ymm, xmm/ymm, xmm/ymm/m, imm8 (66)
  15 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    if pfx.vex_l then {
      let src1 : ymmword = read_simd(pfx.vex_vvvv);
      let src2 : ymmword = decode_vex_src(256, modrm, src, pfx);
      let imm = fetch(1);
      // Each 128-bit lane is aligned independently
      let lo : xmmword = avx_palignr_128(src1[127..0], src2[127..0], imm);
      let hi : xmmword = avx_palignr_128(src1[255..128], src2[255..128], imm);
      write_simd(256, dst, hi @ lo)
    } else {
      let src1 : xmmword = read_simd(pfx.vex_vvvv);
      let src2 : xmmword = decode_vex_src(128, modrm, src, pfx);
      let imm = fetch(1);
      write_simd(128, dst, avx_palignr_128(src1, src2, imm))
    }
  },

  // 0F3A 14: VPEXTRB r/m8, xmm, imm8 (66) — VEX.128 only, vvvv must be 1111b
  20 => {
    if mp != MP_66 then raise_UD();
    if pfx.vex_l then raise_UD();
    if pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch(1);
    let src = modrm_xmm_reg(modrm, pfx);
    let dest = modrm_rm(modrm, pfx);
    let imm = fetch(1);
    let x : byte = (ZMM[src] >> (unsigned(imm[3..0]) * 8))[7..0];
    match dest {
      RM_reg(r) => v(r) = zero_extend(32, x),
      RM_mem(m) => v(m) = x,
    }
  },

  // 0F3A 15: VPEXTRW r/m16, xmm, imm8 (66) — VEX.128 only, vvvv must be 1111b
  21 => {
    if mp != MP_66 then raise_UD();
    if pfx.vex_l then raise_UD();
    if pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch(1);
    let src = modrm_xmm_reg(modrm, pfx);
    let dest = modrm_rm(modrm, pfx);
    let imm = fetch(1);
    let sel : range(0, 7) = unsigned(imm[2..0]);
    let w : word = (ZMM[src] >> (sel * 16))[15..0];
    match dest {
      RM_reg(r) => v(r) = zero_extend(32, w),
      RM_mem(m) => v(m) = w,
    }
  },

  // 0F3A 16: VPEXTRD/VPEXTRQ r/m, xmm, imm8 (66) — VEX.128 only, vvvv must be 1111b
  22 => {
    if mp != MP_66 then raise_UD();
    if pfx.vex_l then raise_UD();
    if pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch(1);
    let src = modrm_xmm_reg(modrm, pfx);
    let dest = modrm_rm(modrm, pfx);
    let imm = fetch(1);
    let eb = if pfx.rex_w then 64 else 32;
    v(dest) = (ZMM[src] >> (unsigned(imm[(eb / 32 - 1)..0]) * eb))[(eb - 1)..0]
  },

  // 0F3A 17: VEXTRACTPS r/m32, xmm, imm8 (66) — VEX.128 only, vvvv must be 1111b
  23 => {
    if mp != MP_66 then raise_UD();
    if pfx.vex_l then raise_UD();
    if pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch(1);
    let src = modrm_xmm_reg(modrm, pfx);
    let dest = modrm_rm(modrm, pfx);
    let imm = fetch(1);
    v(dest) = (ZMM[src] >> (unsigned(imm[1..0]) * 32))[31..0]
  },

  // 0F3A 20: VPINSRB xmm, xmm, r/m8, imm8 (66) — VEX.128 only
  32 => {
    if mp != MP_66 then raise_UD();
    if pfx.vex_l then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    let src1 : xmmword = read_simd(pfx.vex_vvvv);
    let x : byte = v(src);
    let imm = fetch(1);
    let sel : range(0, 15) = unsigned(imm[3..0]);
    write_simd(128, dst, insert_byte(src1, x, sel))
  },

  // 0F3A 21: VINSERTPS xmm, xmm, xmm/m32, imm8 (66) — VEX.128 only
  33 => {
    if mp != MP_66 then raise_UD();
    if pfx.vex_l then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src2 = modrm_rm(modrm, pfx);
    let dst_base : xmmword = read_simd(pfx.vex_vvvv);
    let is_mem : bool = match src2 { RM_reg(_) => false, RM_mem(_) => true };
    let src : xmmword = match src2 {
      RM_reg(_) => read_simd(modrm_xmm_rm(modrm, pfx)),
      RM_mem(m) => zero_extend(v(32, m)),
    };
    let imm = fetch(1);
    write_simd(128, dst, avx_insertps(dst_base, src, imm, is_mem))
  },

  // 0F3A 22: VPINSRD/VPINSRQ xmm, xmm, r/m, imm8 (66) — VEX.128 only
  34 => {
    if mp != MP_66 then raise_UD();
    if pfx.vex_l then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    let src1 : xmmword = read_simd(pfx.vex_vvvv);
    let imm = fetch(1);
    if pfx.rex_w then {
      // VPINSRQ xmm1, xmm2, r/m64, imm8
      let x : qword = v(src);
      let sel : range(0, 1) = unsigned(imm[0]);
      let r : xmmword = match sel {
        0 => src1[127..64] @ x,
        1 => x @ src1[63..0]
      };
      write_simd(128, dst, r)
    } else {
      // VPINSRD xmm1, xmm2, r/m32, imm8
      let x : dword = v(src);
      let sel : range(0, 3) = unsigned(imm[1..0]);
      write_simd(128, dst, insert_dword(src1, x, sel))
    }
  },

  // 0F3A 40: VDPPS xmm/ymm, xmm/ymm, xmm/ymm/m, imm8 (66)
  64 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    if pfx.vex_l then {
      let src1 : ymmword = read_simd(pfx.vex_vvvv);
      let src2 : ymmword = decode_vex_src(256, modrm, src, pfx);
      let imm = fetch(1);
      // 256-bit DPPS: each 128-bit lane independently
      let lo : xmmword = avx_dpps_128(src1[127..0], src2[127..0], imm);
      let hi : xmmword = avx_dpps_128(src1[255..128], src2[255..128], imm);
      write_simd(256, dst, hi @ lo)
    } else {
      let src1 : xmmword = read_simd(pfx.vex_vvvv);
      let src2 : xmmword = decode_vex_src(128, modrm, src, pfx);
      let imm = fetch(1);
      write_simd(128, dst, avx_dpps_128(src1, src2, imm))
    }
  },

  // 0F3A 41: VDPPD xmm, xmm, xmm/m128, imm8 (66) — VEX.128 only
  65 => {
    if mp != MP_66 then raise_UD();
    if pfx.vex_l then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    let src1 : xmmword = read_simd(pfx.vex_vvvv);
    let src2 : xmmword = decode_vex_src(128, modrm, src, pfx);
    let imm = fetch(1);
    write_simd(128, dst, avx_dppd_128(src1, src2, imm))
  },

  // 0F3A 42: VMPSADBW xmm/ymm, xmm/ymm, xmm/ymm/m, imm8 (66)
  66 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    if pfx.vex_l then {
      let src1 : ymmword = read_simd(pfx.vex_vvvv);
      let src2 : ymmword = decode_vex_src(256, modrm, src, pfx);
      let imm = fetch(1);
      // 256-bit: each 128-bit lane independently, imm8[2:0] for low lane, imm8[5:3] for high lane
      let lo : xmmword = mpsadbw(src1[127..0], src2[127..0], 0b00000 @ imm[2..0]);
      let hi : xmmword = mpsadbw(src1[255..128], src2[255..128], 0b00000 @ imm[5..3]);
      write_simd(256, dst, hi @ lo)
    } else {
      let src1 : xmmword = read_simd(pfx.vex_vvvv);
      let src2 : xmmword = decode_vex_src(128, modrm, src, pfx);
      let imm = fetch(1);
      write_simd(128, dst, mpsadbw(src1, src2, imm))
    }
  },

  // 0F3A 44: VPCLMULQDQ xmm, xmm, xmm/m128, imm8 (66) — VEX.128 only
  68 => {
    if ~(has_pclmulqdq) then raise_UD();
    if mp != MP_66 then raise_UD();
    if pfx.vex_l then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    let src1 : xmmword = read_simd(pfx.vex_vvvv);
    let src2 : xmmword = decode_vex_src(128, modrm, src, pfx);
    let imm = fetch(1);
    let sel_a : qword = blend(src1[63..0], src1[127..64], imm[0]);
    let sel_b : qword = blend(src2[63..0], src2[127..64], imm[4]);
    let result : xmmword = pclmulqdq(sel_a, sel_b);
    write_simd(128, dst, result)
  },

  // 0F3A 04: VPERMILPS xmm/ymm, xmm/ymm/m, imm8 (66, vvvv must be 1111b)
  // Per-lane dword shuffle — same as VPSHUFD
  4 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src2 = modrm_rm(modrm, pfx);
    let vl = vex_vl(pfx);
    let src = decode_vex_src(vl, modrm, src2, pfx);
    let imm = fetch(1);
    write_simd(vl, dst, packed_lane_imm_op(PLI_Pshufd, src, imm))
  },

  // 0F3A 05: VPERMILPD xmm/ymm, xmm/ymm/m, imm8 (66, vvvv must be 1111b)
  5 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src2 = modrm_rm(modrm, pfx);
    let imm = fetch(1);
    let vl = vex_vl(pfx);
    let src : ymmword = decode_vex_src(256, modrm, src2, pfx);
    // Per-lane qword select: within each 128-bit lane, imm8[i] selects low or high qword
    var result : ymmword = zeros();
    foreach (i from 0 to (vl / 64 - 1)) {
      let lane_base = (i / 2) * 128;
      let sel : range(0, 1) = unsigned(imm[i]);
      result[(i * 64 + 63)..(i * 64)] = src[(lane_base + sel * 64 + 63)..(lane_base + sel * 64)]
    };
    write_simd(vl, dst, result[(vl - 1)..0])
  },

  // 0F3A 06: VPERM2F128 / 0F3A 46: VPERM2I128
  // ymm, ymm, ymm/m256, imm8 (66, VEX.256 only) — identical semantics
  op if op == 6 | op == 70 => {
    if mp != MP_66 | ~(pfx.vex_l) then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    let src1 : ymmword = read_simd(pfx.vex_vvvv);
    let src2 : ymmword = decode_vex_src(256, modrm, src, pfx);
    let imm = fetch(1);
    // Low 128-bit result selected by imm8[1:0], zeroed if imm8[3]
    let sel_lo : range(0, 3) = unsigned(imm[1..0]);
    let lo_selected : xmmword = match sel_lo {
      0 => src1[127..0], 1 => src1[255..128],
      2 => src2[127..0], 3 => src2[255..128],
    };
    let lo_result : xmmword = lo_selected & sign_extend(~(imm[3]));
    // High 128-bit result selected by imm8[5:4], zeroed if imm8[7]
    let sel_hi : range(0, 3) = unsigned(imm[5..4]);
    let hi_selected : xmmword = match sel_hi {
      0 => src1[127..0], 1 => src1[255..128],
      2 => src2[127..0], 3 => src2[255..128],
    };
    let hi_result : xmmword = hi_selected & sign_extend(~(imm[7]));
    write_simd(256, dst, hi_result @ lo_result)
  },

  // 0F3A 38: VINSERTI128 — merged with 0F3A 18 above
  // 0F3A 39: VEXTRACTI128 — merged with 0F3A 19 above

  // 0F3A 46: VPERM2I128 — merged with 0F3A 06 above

  // VGF2P8AFFINEQB: VEX.128/256.66.0F3A.W1 CE /r ib
  206 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    let vl = vex_vl(pfx);
    let imm = fetch(1);
    write_simd(vl, dst, avx_gf2p8affineqb(read_simd(vl, pfx.vex_vvvv), decode_vex_src(modrm, src, pfx), imm))
  },

  // VGF2P8AFFINEINVQB: VEX.128/256.66.0F3A.W1 CF /r ib
  207 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    let vl = vex_vl(pfx);
    let imm = fetch(1);
    write_simd(vl, dst, avx_gf2p8affineinvqb(read_simd(vl, pfx.vex_vvvv), decode_vex_src(modrm, src, pfx), imm))
  },

  _ => raise_UD(),
  }
}

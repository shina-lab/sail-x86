// x86-64 — VEX Immediate Instructions (0F3A map)
//
// Blend, round, dpps, palignr, permil, insert/extract, cvtps2ph,
// kshift, mpsadbw, pblendd.

// Variable blend: for each eb-wide element, select src1 or src2 based on mask sign bit.
val avx_blendv : forall 'vl 'eb, 'vl in {128, 256} & 'eb in {8, 32, 64}.
  (int('eb), bits('vl), bits('vl), bits('vl)) -> bits('vl)
function avx_blendv(eb, src1, src2, mask) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 'eb - 1)) {
    let lo = i * 'eb;
    r[(lo + 'eb - 1)..lo] = blend(velem('eb, src1, i), velem('eb, src2, i), mask[lo + 'eb - 1])
  };
  r
}

// Immediate blend: for each eb-wide element i, select src1 or src2 based on imm[i].
val avx_blend_imm : forall 'vl 'eb, 'vl in {128, 256} & 'eb in {16, 32, 64}.
  (int('eb), bits('vl), bits('vl), byte) -> bits('vl)
function avx_blend_imm(eb, src1, src2, imm) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 'eb - 1)) {
    let lo = i * 'eb;
    assert(i < 8);
    r[(lo + 'eb - 1)..lo] = blend(velem('eb, src1, i), velem('eb, src2, i), imm[i])
  };
  r
}

// VEX blend dispatch helper.
val vex_exec_blend : ({16, 32, 64}, Prefixes) -> unit
function vex_exec_blend(eb, pfx) = {
  let modrm = fetch(1);
  let dst = modrm_xreg(modrm, pfx);
  let src = modrm_xrm(modrm, pfx);
  let vl = vex_vl(pfx);
  let imm = fetch(1);
  write_simd(vl, dst, avx_blend_imm(eb, read_simd(vl, pfx.vex_vvvv), decode_vex_src(vl, src), imm))
}

// VPALIGNR 128-bit: concatenate src1(high):src2(low), shift right by imm bytes, take low 128 bits
val avx_palignr_128 : (xmmword, xmmword, byte) -> xmmword
function avx_palignr_128(src1, src2, imm) = {
  let shift_bytes : range(0, 255) = unsigned(imm);
  ((src1 @ src2) >> (shift_bytes * 8))[127..0]
}

// VROUND{PS,PD}: round each element per imm control
val avx_round_packed : forall 'vl 'eb, 'vl in {128, 256} & 'eb in {32, 64}.
  (int('eb), bits('vl), byte) -> bits('vl)
function avx_round_packed(eb, src, imm) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 'eb - 1)) {
    let lo = i * 'eb;
    r[(lo + 'eb - 1)..lo] = fp_round(velem('eb, src, i), imm)
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
  let sum : dword = fp_add(fp_add(temp0, temp1), fp_add(temp2, temp3));
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
  (sum & sign_extend(imm[1])) @ (sum & sign_extend(imm[0]))
}

// VPERMQ: permute 256-bit qwords based on imm8
val avx_vpermq : (ymmword, byte) -> ymmword
function avx_vpermq(src, imm) = {
  velem(64, src, imm[7..6]) @ velem(64, src, imm[5..4]) @ velem(64, src, imm[3..2]) @ velem(64, src, imm[1..0])
}

// VINSERTPS for VEX: takes dst xmm value, handles mem flag
val avx_insertps : (xmmword, xmmword, byte, bool) -> xmmword
function avx_insertps(dst, src, imm8, is_mem) = {
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

// Per-128-bit-lane binary+imm operations.
enum VexLaneBinImmOp = { VLBI_Palignr, VLBI_Dpps, VLBI_Dppd, VLBI_BlendW, VLBI_Pclmulqdq }

val vex_lane_bin_imm_elem : (VexLaneBinImmOp, xmmword, xmmword, byte) -> xmmword
function vex_lane_bin_imm_elem(op, a, b, imm) = match op {
  VLBI_Palignr => avx_palignr_128(a, b, imm),
  VLBI_Dpps    => avx_dpps_128(a, b, imm),
  VLBI_Dppd    => avx_dppd_128(a, b, imm),
  VLBI_BlendW  => avx_blend_imm(16, a, b, imm),
  VLBI_Pclmulqdq => pclmulqdq_lane(a, b, imm),
}

val vex_lane_bin_imm_op : forall 'vl, 'vl in {128, 256}.
  (VexLaneBinImmOp, bits('vl), bits('vl), byte) -> bits('vl)
function vex_lane_bin_imm_op(op, a, b, imm) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) {
    let lo = i * 128;
    r[(lo + 127)..lo] = vex_lane_bin_imm_elem(op, velem(128, a, i), velem(128, b, i), imm)
  };
  r
}

val vex_exec_lane_bin_imm : (VexLaneBinImmOp, Prefixes) -> unit
function vex_exec_lane_bin_imm(op, pfx) = {
  let modrm = fetch(1);
  let dst = modrm_xreg(modrm, pfx);
  let src = modrm_xrm(modrm, pfx);
  let vl = vex_vl(pfx);
  let imm = fetch(1);
  write_simd(vl, dst, vex_lane_bin_imm_op(op, read_simd(vl, pfx.vex_vvvv), decode_vex_src(vl, src), imm))
}

// Common VEX 0F3A fetch: modrm → reg index, r/m operand, imm8.
val vex_fetch_xrm_imm : Prefixes -> (simd_idx, XRM, byte)
function vex_fetch_xrm_imm(pfx) = {
  let modrm = fetch(1);
  (modrm_xreg(modrm, pfx), modrm_xrm(modrm, pfx), fetch(1))
}

// VPERM2F128/I128 lane selector: pick one of four 128-bit halves, optionally zero.
val vperm2_select : (ymmword, ymmword, bits(2), bit) -> xmmword
function vperm2_select(a, b, sel, zero) = {
  let selected : xmmword = match unsigned(sel) {
    0 => a[127..0], 1 => a[255..128],
    2 => b[127..0], _ => b[255..128],
  };
  selected & sign_extend(~(zero))
}

// VEX 0F3A map dispatch
val dispatch_vex_0f3a : (byte, Prefixes) -> unit
function dispatch_vex_0f3a(opcode, pfx) = {
  let op : range(0, 255) = unsigned(opcode);
  let mp = get_mandatory_prefix(pfx);
  // RORX (F0h/240) is BMI2 GPR-only: no AVX requirement.
  // All other opcodes are SIMD and require AVX.
  if op != 240 & ~(avx_enabled()) then raise_UD();
  // All opcodes in this map require 66h mandatory prefix except RORX (F0h/240)
  if op != 240 & mp != MP_66 then raise_UD();

  match op {
  // 0F3A 00/01: VPERMQ / VPERMPD — ymm, ymm/m256, imm8 (W1, VEX.256, vvvv=1111b)
  op if op == 0 | op == 1 => {
    if ~(pfx.vex_l) | ~(pfx.vex_w) | pfx.vex_vvvv != 0 then raise_UD();
    let (dst, src, imm) = vex_fetch_xrm_imm(pfx);
    write_simd(256, dst, avx_vpermq(decode_vex_src(256, src), imm))
  },

  // 0F3A 02/0C: VPBLENDD / VBLENDPS — dword blend
  op if op == 2 | op == 12 => vex_exec_blend(32, pfx),
  // 0F3A 0D: VBLENDPD — qword blend
  13 => vex_exec_blend(64, pfx),

  // 0F3A 04: VPERMILPS — per-lane dword shuffle (vvvv=1111b)
  4 => {
    if pfx.vex_vvvv != 0 then raise_UD();
    let (dst, src, imm) = vex_fetch_xrm_imm(pfx);
    let vl = vex_vl(pfx);
    write_simd(vl, dst, packed_lane_imm_op(PLI_Pshufd, decode_vex_src(vl, src), imm))
  },

  // 0F3A 05: VPERMILPD — per-lane qword select (vvvv=1111b)
  5 => {
    if pfx.vex_vvvv != 0 then raise_UD();
    let (dst, src2, imm) = vex_fetch_xrm_imm(pfx);
    let vl = vex_vl(pfx);
    let src : ymmword = decode_vex_src(256, src2);
    var result : ymmword = zeros();
    foreach (i from 0 to (vl / 64 - 1)) {
      let lane_base = (i / 2) * 128;
      let sel : range(0, 1) = unsigned(imm[i]);
      result[(i * 64 + 63)..(i * 64)] = src[(lane_base + sel * 64 + 63)..(lane_base + sel * 64)]
    };
    write_simd(vl, dst, result[(vl - 1)..0])
  },

  // 0F3A 06/46: VPERM2F128 / VPERM2I128 — ymm, ymm, ymm/m256, imm8 (VEX.256)
  op if op == 6 | op == 70 => {
    if ~(pfx.vex_l) then raise_UD();
    let (dst, src, imm) = vex_fetch_xrm_imm(pfx);
    let src1 : ymmword = read_simd(pfx.vex_vvvv);
    let src2 : ymmword = decode_vex_src(256, src);
    write_simd(256, dst, vperm2_select(src1, src2, imm[5..4], imm[7]) @ vperm2_select(src1, src2, imm[1..0], imm[3]))
  },

  // 0F3A 08/09: VROUNDPS/PD (vvvv=1111b)
  op if op == 8 | op == 9 => {
    if pfx.vex_vvvv != 0 then raise_UD();
    let (dst, src2, imm) = vex_fetch_xrm_imm(pfx);
    let vl = vex_vl(pfx);
    write_simd(vl, dst, avx_round_packed(if op == 8 then 32 else 64, decode_vex_src(vl, src2), imm))
  },

  // 0F3A 0A/0B: VROUNDSS/SD — VEX.128
  op if op == 10 | op == 11 => {
    if pfx.vex_l then raise_UD();
    let (dst, src, imm) = vex_fetch_xrm_imm(pfx);
    let base : xmmword = read_simd(128, pfx.vex_vvvv);
    if op == 10
    then write_simd(128, dst, base[127..32] @ fp_round(decode_scalar_src(src) : dword, imm))
    else write_simd(128, dst, base[127..64] @ fp_round(decode_scalar_src(src) : qword, imm))
  },

  // 0F3A 0E: VPBLENDW — per-lane word blend
  14 => vex_exec_lane_bin_imm(VLBI_BlendW, pfx),
  // 0F3A 0F: VPALIGNR — per-lane byte align
  15 => vex_exec_lane_bin_imm(VLBI_Palignr, pfx),

  // 0F3A 14-17: VPEXTRB/W/D/Q, VEXTRACTPS — VEX.128, vvvv=1111b
  op if 20 <= op & op <= 23 => {
    if pfx.vex_l | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch(1);
    let src = modrm_xreg(modrm, pfx);
    let dest = modrm_rm(modrm, pfx);
    let imm = fetch(1);
    match op {
      20 => { // VPEXTRB
        let x : byte = velem(8, ZMM[src], imm[3..0]);
        match dest { RM_reg(r) => v(r) = zero_extend(32, x), RM_mem(m) => v(m) = x }
      },
      21 => { // VPEXTRW
        let w : word = velem(16, ZMM[src], imm[2..0]);
        match dest { RM_reg(r) => v(r) = zero_extend(32, w), RM_mem(m) => v(m) = w }
      },
      22 => { // VPEXTRD/Q
        let eb = if pfx.rex_w then 64 else 32;
        v(dest) = (ZMM[src] >> (unsigned(imm[(eb / 32 - 1)..0]) * eb))[(eb - 1)..0]
      },
      _ => v(dest) = velem(32, ZMM[src], imm[1..0]), // VEXTRACTPS
    }
  },

  // 0F3A 18/38: VINSERTF128 / VINSERTI128 — VEX.256
  op if op == 24 | op == 56 => {
    if ~(pfx.vex_l) then raise_UD();
    let (dst, src, imm) = vex_fetch_xrm_imm(pfx);
    let src1 : ymmword = read_simd(pfx.vex_vvvv);
    let src2 : xmmword = decode_vex_src(128, src);
    if imm[0] == 0b0 then write_simd(256, dst, src1[255..128] @ src2)
    else write_simd(256, dst, src2 @ src1[127..0])
  },

  // 0F3A 19/39: VEXTRACTF128 / VEXTRACTI128 — VEX.256, vvvv=1111b
  op if op == 25 | op == 57 => {
    if ~(pfx.vex_l) | pfx.vex_vvvv != 0 then raise_UD();
    let (src, dest, imm) = vex_fetch_xrm_imm(pfx);
    let x : ymmword = read_simd(src);
    let extracted : xmmword = if imm[0] == 0b0 then x[127..0] else x[255..128];
    match dest {
      XRM_reg(xi) => write_simd(128, xi, extracted),
      XRM_mem(m)  => write_mem(m, extracted),
    }
  },

  // 0F3A 1D: VCVTPS2PH
  29 => {
    if ~(has_f16c) then raise_UD();
    let (src, dest, imm) = vex_fetch_xrm_imm(pfx);
    let rc : bits(2) = if imm[2] == 0b0 then imm[1..0] else __stmxcsr()[14..13];
    let vl = vex_vl(pfx);
    let res = avx_vcvtps2ph(read_simd(vl, src), rc);
    match dest {
      XRM_reg(xi) => write_simd(128, xi, zero_extend(res)),
      XRM_mem(m)  => write_mem(m, res),
    }
  },

  // 0F3A 20/22: VPINSRB / VPINSRD/Q — VEX.128
  op if op == 32 | op == 34 => {
    if pfx.vex_l then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xreg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    let src1 : xmmword = read_simd(pfx.vex_vvvv);
    let imm = fetch(1);
    if op == 32 then
      write_simd(128, dst, insert_byte(src1, v(src), unsigned(imm[3..0])))
    else if pfx.rex_w then {
      let x : qword = v(src);
      write_simd(128, dst, match unsigned(imm[0]) { 0 => src1[127..64] @ x, _ => x @ src1[63..0] })
    } else {
      write_simd(128, dst, insert_dword(src1, v(src), unsigned(imm[1..0])))
    }
  },

  // 0F3A 21: VINSERTPS — VEX.128
  33 => {
    if pfx.vex_l then raise_UD();
    let (dst, src2, imm) = vex_fetch_xrm_imm(pfx);
    let is_mem : bool = match src2 { XRM_reg(_) => false, XRM_mem(_) => true };
    let src : xmmword = match src2 {
      XRM_reg(xi) => read_simd(xi),
      XRM_mem(m)  => zero_extend(v(32, m)),
    };
    write_simd(128, dst, avx_insertps(read_simd(pfx.vex_vvvv), src, imm, is_mem))
  },

  // 0F3A 30-33: KSHIFTR/L {B,W,D,Q}
  op if 48 <= op & op <= 51 => {
    let modrm = fetch(1);
    let k1 : range(0, 7) = unsigned(modrm[5..3]);
    let k2 : range(0, 7) = unsigned(modrm[2..0]);
    let shift : range(0, 255) = unsigned(fetch(1));
    let w_mask : qword = sign_extend(bool_to_bit(pfx.vex_w));
    let mask : qword = if op == 48 | op == 50
      then (0x000000000000FF00 & w_mask) | 0x00000000000000FF
      else (0xFFFFFFFF00000000 & w_mask) | 0x00000000FFFFFFFF;
    let src : qword = read_kreg(k2) & mask;
    if op <= 49
    then write_kreg(k1, (src >> shift) & mask)
    else write_kreg(k1, (src << shift) & mask)
  },

  // 0F3A 40: VDPPS — per-lane dot product of singles
  64 => vex_exec_lane_bin_imm(VLBI_Dpps, pfx),
  // 0F3A 41: VDPPD — VEX.128 only
  65 => { if pfx.vex_l then raise_UD(); vex_exec_lane_bin_imm(VLBI_Dppd, pfx) },

  // 0F3A 42: VMPSADBW — per-lane with different imm bits per lane
  66 => {
    let (dst, src, imm) = vex_fetch_xrm_imm(pfx);
    if pfx.vex_l then {
      let src1 : ymmword = read_simd(pfx.vex_vvvv);
      let src2 : ymmword = decode_vex_src(256, src);
      let lo : xmmword = mpsadbw(src1[127..0], src2[127..0], 0b00000 @ imm[2..0]);
      let hi : xmmword = mpsadbw(src1[255..128], src2[255..128], 0b00000 @ imm[5..3]);
      write_simd(256, dst, hi @ lo)
    } else {
      write_simd(128, dst, mpsadbw(read_simd(pfx.vex_vvvv), decode_vex_src(128, src), imm))
    }
  },

  // 0F3A 44: VPCLMULQDQ — the VEX.128 form comes with PCLMULQDQ + AVX,
  // the VEX.256 form with the VPCLMULQDQ extension (CPUID.07H:ECX[10])
  68 => {
    let supported = if pfx.vex_l then has_vpclmulqdq else has_pclmulqdq;
    if ~(supported) then raise_UD();
    vex_exec_lane_bin_imm(VLBI_Pclmulqdq, pfx)
  },

  // 0F3A 4A/4B/4C: VBLENDVPS/VPD/VB — variable blend, is4 (mask in imm8[7:4])
  op if 74 <= op & op <= 76 => {
    if pfx.vex_w then raise_UD();
    let (dst, src2, imm) = vex_fetch_xrm_imm(pfx);
    let eb : {8, 32, 64} = match op { 74 => 32, 75 => 64, _ => 8 };
    let mask_idx : simd_idx = unsigned(imm[7..4]);
    let vl = vex_vl(pfx);
    write_simd(vl, dst, avx_blendv(eb, read_simd(vl, pfx.vex_vvvv), decode_vex_src(vl, src2), read_simd(vl, mask_idx)))
  },

  // 0F3A 60-63: VPCMPxSTRx — VEX.128, vvvv=1111b
  // bit 0: 0=mask→XMM0, 1=index→ECX; bit 1: 0=explicit(EAX/EDX), 1=implicit
  op if 96 <= op & op <= 99 => {
    if pfx.vex_l | pfx.vex_vvvv != 0 then raise_UD();
    let (dst, src2, imm) = vex_fetch_xrm_imm(pfx);
    let a : xmmword = read_simd(dst);
    let b : xmmword = decode_vex_src(128, src2);
    let ub : range(0, 15) = if imm[0] == bitone then 7 else 15;
    let la = if op >= 98 then pcmp_implicit_len(a, ub) else pcmp_clamp_len(v(RAX), ub + 1);
    let lb = if op >= 98 then pcmp_implicit_len(b, ub) else pcmp_clamp_len(v(RDX), ub + 1);
    let (int_res2, cf, zf, sf, of) = pcmpxstrx_core(a, la, b, lb, imm);
    if op % 2 == 0
      then ZMM[0][127..0] = pcmp_expand_mask(int_res2, ub, imm[6])
      else v(RCX) = to_bits(32, pcmp_bit_index(int_res2, ub, imm[6]));
    CF = cf;
    ZF = zf;
    SF = sf;
    OF = of;
    AF = 0b0;
    PF = 0b0
  },

  // 0F3A CE/CF: VGF2P8AFFINEQB / VGF2P8AFFINEINVQB
  op if op == 206 | op == 207 => {
    let (dst, src, imm) = vex_fetch_xrm_imm(pfx);
    let vl = vex_vl(pfx);
    let a = read_simd(vl, pfx.vex_vvvv);
    let b = decode_vex_src(vl, src);
    if op == 206
    then write_simd(vl, dst, avx_gf2p8affineqb(a, b, imm))
    else write_simd(vl, dst, avx_gf2p8affineinvqb(a, b, imm))
  },

  // 0F3A DF: VAESKEYGENASSIST — VEX.128, vvvv=1111b
  223 => {
    if ~(has_aesni) | pfx.vex_l | pfx.vex_vvvv != 0 then raise_UD();
    let (dst, src, imm) = vex_fetch_xrm_imm(pfx);
    write_simd(128, dst, aeskeygenassist(decode_vex_src(128, src), imm))
  },

  // 0F3A F0: RORX — VEX.LZ.F2.0F3A
  240 => {
    if mp != MP_F2 | pfx.vex_vvvv != 0 then raise_UD();
    let (dst, src2) = fetch_modrm(pfx);
    let os : {32, 64} = if pfx.vex_w then 64 else 32;
    let imm = fetch(1);
    let shift : range(0, 63) = unsigned(imm[(if pfx.vex_w then 5 else 4)..0]);
    assert(shift < os);
    v(os, dst) = rotr(v(os, src2), shift);
  },

  _ => raise_UD(),
  }
}

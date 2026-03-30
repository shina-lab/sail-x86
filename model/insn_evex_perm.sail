// x86-64 — EVEX Permute/Shuffle/Compress (0F38 map)
//
// VBROADCAST, VPERM, VPSHUF, VCOMPRESS, VEXPAND.
// Called from dispatch_evex_0f38 in insn_evex_dispatch.sail.

// VPERMILPS (register control): per-element select within 128-bit lane
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

/* ---- VPERMQ/VPERMPD (imm8): qword permute per 256-bit lane ---- */

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
  123 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let elem : word = v(32, modrm_rm_reg(modrm, pfx))[15..0];
    let vl = evex_vl(pfx);
    evex_write(dst, evex_wmask(pfx, vl / 16), broadcast(vl, elem))
  },

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
  27 => {
    if mp != MP_66 then raise_UD();
    let (dst, src) = fetch_modrm_evex(pfx, 32);
    let src : ymmword = match src { XRM_mem(m) => read_mem(m), _ => raise_UD() };
    if pfx.rex_w then evex_write(dst, evex_wmask(pfx, 8), src @ src)
    else evex_write(dst, evex_wmask(pfx, 16), src @ src)
  },

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
    if pfx.evex_ll == 0 then raise_UD();
    let eb = evex_elem(pfx);
    let vl = evex_vl(pfx);
    evex_write(dst, evex_wmask(pfx, vl / eb), packed_permute(eb, evex_bcast_src(vl, src, pfx, eb), read_simd(vl, pfx.evex_vvvvv)))
  },

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
    let eb = evex_elem_bw(pfx);
    let vl = evex_vl(pfx);
    let idx = read_simd(vl, dst);
    evex_write(dst, evex_wmask(pfx, vl / eb), packed_permute2(eb, read_simd(vl, pfx.evex_vvvvv), evex_src(vl, src), idx))
  },

  // 0F38 76: VPERMI2D (66,W0) / VPERMI2Q (66,W1) [F]
  // 0F38 77: VPERMI2PS (66,W0) / VPERMI2PD (66,W1) [F]
  op if op == 118 | op == 119 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let eb = evex_elem(pfx);
    let vl = evex_vl(pfx);
    let idx = read_simd(vl, dst);
    evex_write(dst, evex_wmask(pfx, vl / eb), packed_permute2(eb, read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(vl, src, pfx, eb), idx))
  },

  // 0F38 7E: VPERMT2D (66,W0) / VPERMT2Q (66,W1) [F]
  // 0F38 7F: VPERMT2PS (66,W0) / VPERMT2PD (66,W1) [F]
  op if op == 126 | op == 127 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let eb = evex_elem(pfx);
    let vl = evex_vl(pfx);
    evex_write(dst, evex_wmask(pfx, vl / eb), packed_permute2(eb, read_simd(vl, dst), evex_bcast_src(vl, src, pfx, eb), read_simd(vl, pfx.evex_vvvvv)))
  },

  // 0F38 7D: VPERMT2W (66,W1) [BW] / VPERMT2B (66,W0) [VBMI]
  125 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let eb = evex_elem_bw(pfx);
    let vl = evex_vl(pfx);
    evex_write(dst, evex_wmask(pfx, vl / eb), packed_permute2(eb, read_simd(vl, dst), evex_src(vl, src), read_simd(vl, pfx.evex_vvvvv)))
  },

  // 0F38 62: VPEXPANDB (66,W0) / VPEXPANDW (66,W1) [VBMI2]
  98 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, 1);
    let eb = evex_elem_bw(pfx);
    let vl = evex_vl(pfx);
    write_simd(vl, dst, packed_expand(eb, evex_src(vl, src), evex_kmask64(pfx)))
  },

  // 0F38 63: VPCOMPRESSB (66,W0) / VPCOMPRESSW (66,W1) [VBMI2]
  99 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let src = evex_reg_idx(modrm, pfx);
    let dest = modrm_xrm_evex(modrm, pfx, 1);
    let eb = evex_elem_bw(pfx);
    let vl = evex_vl(pfx);
    let k = evex_kmask64(pfx);
    match dest {
      XRM_reg(xi) => write_simd(vl, xi, packed_compress(eb, read_simd(vl, src), k)),
      XRM_mem(m) => packed_compress_mem(eb, seg_linear(m, 64), read_simd(vl, src), k),
    }
  },

  // 0F38 70: VPSHLDVW (66, W=1) [VBMI2]
  // 0F38 8D: VPERMW (66,W1) [BW] / VPERMB (66,W0) [VBMI]
  141 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let eb = evex_elem_bw(pfx);
    let vl = evex_vl(pfx);
    evex_write(dst, evex_wmask(pfx, vl / eb), packed_permute(eb, evex_src(vl, src), read_simd(vl, pfx.evex_vvvvv)))
  },

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

  // 0F38 88: VEXPANDPS (66,W0) / VEXPANDPD (66,W1) [F]
  // 0F38 89: VPEXPANDD (66,W0) / VPEXPANDQ (66,W1) [F]
  op if op == 136 | op == 137 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
    let eb = evex_elem(pfx);
    let vl = evex_vl(pfx);
    write_simd(vl, dst, packed_expand(eb, evex_src(vl, src), evex_kmask64(pfx)))
  },

  // 0F38 8A: VCOMPRESSPS (66,W0) / VCOMPRESSPD (66,W1) [F]
  // 0F38 8B: VPCOMPRESSD (66,W0) / VPCOMPRESSQ (66,W1) [F]
  op if op == 138 | op == 139 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let src = evex_reg_idx(modrm, pfx);
    let dest = modrm_xrm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
    let eb = evex_elem(pfx);
    let vl = evex_vl(pfx);
    let k = evex_kmask64(pfx);
    match dest {
      XRM_reg(xi) => write_simd(vl, xi, packed_compress(eb, read_simd(vl, src), k)),
      XRM_mem(m) => packed_compress_mem(eb, seg_linear(m, 64), read_simd(vl, src), k),
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

// x86-64 — EVEX FMA Instructions (0F38 map)

// gather_addr is defined in insn_sse4_helpers.sail

// Unified EVEX gather: parameterized by index width 'iw and element width 'ew.
// Covers all four combinations: d32 (32,32), d64 (32,64), q32 (64,32), q64 (64,64).
val exec_gather : forall 'vl 'iw 'ew, 'vl in {128, 256, 512} & 'iw in {32, 64} & 'ew in {32, 64}.
  (implicit('vl), int('iw), int('ew), simd_idx, VSIB, kreg_idx) -> unit
function exec_gather(vl, iw, ew, dst, vsib, k_idx) = {
  let mask = read_kreg(k_idx);
  var result : bits(512) = ZMM[dst];
  let indices : bits(512) = ZMM[vsib.vsib_vidx];
  let n = vl / (if iw >= ew then iw else ew);
  foreach (i from 0 to (n - 1)) {
    if mask[i] == 0b1 then {
      let idx : bits('iw) = (indices >> (i * iw))[iw - 1 .. 0];
      let v : bits('ew) = read_mem(gather_addr(vsib.vsib_base, idx, vsib.vsib_scale));
      let olo = i * ew;
      result = (result & ~(zero_extend(ones() : bits('ew)) << olo)) | (zero_extend(v) << olo);
    }
  };
  // Zero from active region (n * ew) to 511
  ZMM[dst] = result & (ones() >> (512 - n * ew));
  write_kreg(k_idx, zeros())
}

// Unified EVEX scatter: parameterized by index width 'iw and element width 'ew.
val exec_scatter : forall 'vl 'iw 'ew, 'vl in {128, 256, 512} & 'iw in {32, 64} & 'ew in {32, 64}.
  (implicit('vl), int('iw), int('ew), simd_idx, VSIB, kreg_idx) -> unit
function exec_scatter(vl, iw, ew, src, vsib, k_idx) = {
  let mask = read_kreg(k_idx);
  let data : bits(512) = ZMM[src];
  let indices : bits(512) = ZMM[vsib.vsib_vidx];
  let n = vl / (if iw >= ew then iw else ew);
  foreach (i from 0 to (n - 1)) {
    if mask[i] == 0b1 then {
      let idx : bits('iw) = (indices >> (i * iw))[iw - 1 .. 0];
      let v : bits('ew) = (data >> (i * ew))[ew - 1 .. 0];
      write_mem(ew, gather_addr(vsib.vsib_base, idx, vsib.vsib_scale), v);
    }
  };
  write_kreg(k_idx, zeros())
}

/* ---- VPCLMULQDQ: carry-less multiply per 128-bit lane ---- */

// VPMADD52LUQ (shift=0) extracts low 52 bits of 52×52 product;
// VPMADD52HUQ (shift=52) extracts high 52 bits.
val avx_vpmadd52 : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), int, bits('vl), bits('vl), bits('vl)) -> bits('vl)
function avx_vpmadd52(vl, shift, dst, src1, src2) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 64 - 1)) {
    let lo = i * 64;
    let a : int = unsigned(velem(64, src1, i)[51..0]);
    let b : int = unsigned(velem(64, src2, i)[51..0]);
    let extracted : qword = get_slice_int(64, a * b, shift);
    let sum : int = unsigned(velem(64, dst, i)) + unsigned(extracted[51..0] : bits(52));
    r[(lo + 63)..lo] = get_slice_int(64, sum, 0)
  };
  r
}

// EVEX scalar FMA: decode modrm, handle embedded rounding, dispatch
val evex_exec_fma_scalar : (PackedTernaryOp, FMAOrder, Prefixes) -> unit
function evex_exec_fma_scalar(op, order, pfx) = {
  let modrm = fetch(1);
  let dst = evex_reg_idx(modrm, pfx);
  let src = modrm_xrm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
  let (_, saved_mxcsr) = evex_begin_rc_xrm(pfx, src);
  let src2 : xmmword = read_simd(pfx.evex_vvvvv);
  let src3 = evex_src(128, src);
  exec_vfma_scalar(op, order, pfx.rex_w, dst, src2, src3);
  evex_end_rc(saved_mxcsr)
}

// EVEX packed FMA: decode modrm, handle embedded rounding, apply packed ternary op
val evex_exec_fma_packed : (PackedTernaryOp, FMAOrder, Prefixes) -> unit
function evex_exec_fma_packed(op, order, pfx) = {
  let modrm = fetch(1);
  let dst = evex_reg_idx(modrm, pfx);
  let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
  let (eff_ll, saved_mxcsr) = evex_begin_rc_xrm(pfx, src);
  let vl = ll_to_vl(eff_ll);
  let eb = evex_elem(pfx);
  let d = read_simd(vl, dst);
  let v = read_simd(vl, pfx.evex_vvvvv);
  let r = evex_bcast_src(vl, src, pfx, eb);
  let mask = evex_wmask(pfx, vl / eb);
  match order {
    FMA_132 => evex_write(dst, mask, packed_ternop(op, eb, d, r, v)),
    FMA_213 => evex_write(dst, mask, packed_ternop(op, eb, v, d, r)),
    FMA_231 => evex_write(dst, mask, packed_ternop(op, eb, v, r, d)),
  };
  evex_end_rc(saved_mxcsr)
}

val dispatch_evex_fma : (range(0, 255), Prefixes) -> unit
function dispatch_evex_fma(op, pfx) = {
  let mp = get_mandatory_prefix(pfx);

  match op {
  // 0F38 90/92: VPGATHERDD/DQ, VGATHERDPS/DPD — dword indices (identical)
  // 0F38 91/93: VPGATHERQD/QQ, VGATHERQPS/QPD — qword indices (identical)
  op if 144 <= op & op <= 147 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let vl = evex_vl(pfx);
    let vsib = decode_vsib_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
    let idx_eb : {32, 64} = if op == 144 | op == 146 then 32 else 64;
    let eb : {32, 64} = if pfx.rex_w then 64 else 32;
    exec_gather(vl, idx_eb, eb, dst, vsib, pfx.evex_aaa)
  },

  // =====================================================================
  // FMA 132 forms (0x96-0x9F)
  // =====================================================================

  // 0F38 96: VFMADDSUB132PS (66,W0) / VFMADDSUB132PD (66,W1) [F]
  150 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let (eff_ll, saved_mxcsr) = evex_begin_rc_xrm(pfx, src);
    let vl = ll_to_vl(eff_ll);
    let eb = evex_elem(pfx);
    let mask = evex_wmask(pfx, vl / eb);
    evex_write(dst, mask, avx_fmaddsub(eb, read_simd(vl, dst), evex_bcast_src(src, pfx, eb), read_simd(vl, pfx.evex_vvvvv)));
    evex_end_rc(saved_mxcsr)
  },

  // 0F38 97: VFMSUBADD132PS (66,W0) / VFMSUBADD132PD (66,W1) [F]
  151 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let (eff_ll, saved_mxcsr) = evex_begin_rc_xrm(pfx, src);
    let vl = ll_to_vl(eff_ll);
    let eb = evex_elem(pfx);
    let mask = evex_wmask(pfx, vl / eb);
    evex_write(dst, mask, avx_fmsubadd(eb, read_simd(vl, dst), evex_bcast_src(src, pfx, eb), read_simd(vl, pfx.evex_vvvvv)));
    evex_end_rc(saved_mxcsr)
  },

  // 0F38 98-9F: VFMADD/VFMSUB/VFNMADD/VFNMSUB 132 PS/PD/SS/SD
  152 => { if mp != MP_66 then raise_UD(); evex_exec_fma_packed(PT_FMAdd,  FMA_132, pfx) },
  153 => { if mp != MP_66 then raise_UD(); evex_exec_fma_scalar(PT_FMAdd,  FMA_132, pfx) },
  154 => { if mp != MP_66 then raise_UD(); evex_exec_fma_packed(PT_FMSub,  FMA_132, pfx) },
  155 => { if mp != MP_66 then raise_UD(); evex_exec_fma_scalar(PT_FMSub,  FMA_132, pfx) },
  156 => { if mp != MP_66 then raise_UD(); evex_exec_fma_packed(PT_FNMAdd, FMA_132, pfx) },
  157 => { if mp != MP_66 then raise_UD(); evex_exec_fma_scalar(PT_FNMAdd, FMA_132, pfx) },
  158 => { if mp != MP_66 then raise_UD(); evex_exec_fma_packed(PT_FNMSub, FMA_132, pfx) },
  159 => { if mp != MP_66 then raise_UD(); evex_exec_fma_scalar(PT_FNMSub, FMA_132, pfx) },

  // =====================================================================
  // Scatter (0xA0-0xA3) — VSIB addressing
  // =====================================================================

  // 0F38 A0: VPSCATTERDD (66,W0) / VPSCATTERDQ (66,W1) [F]
  160 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let src = evex_reg_idx(modrm, pfx);
    let vl = evex_vl(pfx);
    let vsib = decode_vsib_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
    if pfx.rex_w then exec_scatter(vl, 32, 64, src, vsib, pfx.evex_aaa)
    else exec_scatter(vl, 32, 32, src, vsib, pfx.evex_aaa)
  },

  // 0F38 A1: VPSCATTERQD (66,W0) / VPSCATTERQQ (66,W1) [F]
  161 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let src = evex_reg_idx(modrm, pfx);
    let vl = evex_vl(pfx);
    let vsib = decode_vsib_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
    if pfx.rex_w then exec_scatter(vl, 64, 64, src, vsib, pfx.evex_aaa)
    else exec_scatter(vl, 64, 32, src, vsib, pfx.evex_aaa)
  },

  // 0F38 A2: VSCATTERDPS (66,W0) / VSCATTERDPD (66,W1) [F]
  162 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let src = evex_reg_idx(modrm, pfx);
    let vl = evex_vl(pfx);
    let vsib = decode_vsib_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
    if pfx.rex_w then exec_scatter(vl, 32, 64, src, vsib, pfx.evex_aaa)
    else exec_scatter(vl, 32, 32, src, vsib, pfx.evex_aaa)
  },

  // 0F38 A3: VSCATTERQPS (66,W0) / VSCATTERQPD (66,W1) [F]
  163 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let src = evex_reg_idx(modrm, pfx);
    let vl = evex_vl(pfx);
    let vsib = decode_vsib_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
    if pfx.rex_w then exec_scatter(vl, 64, 64, src, vsib, pfx.evex_aaa)
    else exec_scatter(vl, 64, 32, src, vsib, pfx.evex_aaa)
  },

  // =====================================================================
  // FMA 213 forms (0xA6-0xAF)
  // =====================================================================

  // 0F38 A6: VFMADDSUB213PS (66,W0) / VFMADDSUB213PD (66,W1) [F]
  166 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let (eff_ll, saved_mxcsr) = evex_begin_rc_xrm(pfx, src);
    let vl = ll_to_vl(eff_ll);
    let eb = evex_elem(pfx);
    let mask = evex_wmask(pfx, vl / eb);
    evex_write(dst, mask, avx_fmaddsub(eb, read_simd(vl, pfx.evex_vvvvv), read_simd(vl, dst), evex_bcast_src(src, pfx, eb)));
    evex_end_rc(saved_mxcsr)
  },

  // 0F38 A7: VFMSUBADD213PS (66,W0) / VFMSUBADD213PD (66,W1) [F]
  167 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let (eff_ll, saved_mxcsr) = evex_begin_rc_xrm(pfx, src);
    let vl = ll_to_vl(eff_ll);
    let eb = evex_elem(pfx);
    let mask = evex_wmask(pfx, vl / eb);
    evex_write(dst, mask, avx_fmsubadd(eb, read_simd(vl, pfx.evex_vvvvv), read_simd(vl, dst), evex_bcast_src(src, pfx, eb)));
    evex_end_rc(saved_mxcsr)
  },

  // 0F38 A8-AF: VFMADD/VFMSUB/VFNMADD/VFNMSUB 213 PS/PD/SS/SD
  168 => { if mp != MP_66 then raise_UD(); evex_exec_fma_packed(PT_FMAdd,  FMA_213, pfx) },
  169 => { if mp != MP_66 then raise_UD(); evex_exec_fma_scalar(PT_FMAdd,  FMA_213, pfx) },
  170 => { if mp != MP_66 then raise_UD(); evex_exec_fma_packed(PT_FMSub,  FMA_213, pfx) },
  171 => { if mp != MP_66 then raise_UD(); evex_exec_fma_scalar(PT_FMSub,  FMA_213, pfx) },
  172 => { if mp != MP_66 then raise_UD(); evex_exec_fma_packed(PT_FNMAdd, FMA_213, pfx) },
  173 => { if mp != MP_66 then raise_UD(); evex_exec_fma_scalar(PT_FNMAdd, FMA_213, pfx) },
  174 => { if mp != MP_66 then raise_UD(); evex_exec_fma_packed(PT_FNMSub, FMA_213, pfx) },
  175 => { if mp != MP_66 then raise_UD(); evex_exec_fma_scalar(PT_FNMSub, FMA_213, pfx) },

  // 0F38 B4: VPMADD52LUQ (66,W1) [IFMA]
  180 => {
    if mp != MP_66 | ~(pfx.rex_w) then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    let mask = evex_wmask(pfx, vl / 64);
    match vl {
      _ => evex_write(dst, mask, avx_vpmadd52(0, read_simd(vl, dst), read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(vl, src, pfx, 64))),
    }
  },

  // 0F38 B5: VPMADD52HUQ (66,W1) [IFMA]
  181 => {
    if mp != MP_66 | ~(pfx.rex_w) then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    let mask = evex_wmask(pfx, vl / 64);
    match vl {
      _ => evex_write(dst, mask, avx_vpmadd52(52, read_simd(vl, dst), read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(vl, src, pfx, 64))),
    }
  },

  // =====================================================================
  // FMA 231 forms (0xB6-0xBF)
  // =====================================================================

  // 0F38 B6: VFMADDSUB231PS (66,W0) / VFMADDSUB231PD (66,W1) [F]
  182 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let (eff_ll, saved_mxcsr) = evex_begin_rc_xrm(pfx, src);
    let vl = ll_to_vl(eff_ll);
    let eb = evex_elem(pfx);
    let mask = evex_wmask(pfx, vl / eb);
    evex_write(dst, mask, avx_fmaddsub(eb, read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(src, pfx, eb), read_simd(vl, dst)));
    evex_end_rc(saved_mxcsr)
  },

  // 0F38 B7: VFMSUBADD231PS (66,W0) / VFMSUBADD231PD (66,W1) [F]
  183 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let (eff_ll, saved_mxcsr) = evex_begin_rc_xrm(pfx, src);
    let vl = ll_to_vl(eff_ll);
    let eb = evex_elem(pfx);
    let mask = evex_wmask(pfx, vl / eb);
    evex_write(dst, mask, avx_fmsubadd(eb, read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(src, pfx, eb), read_simd(vl, dst)));
    evex_end_rc(saved_mxcsr)
  },

  // 0F38 B8-BF: VFMADD/VFMSUB/VFNMADD/VFNMSUB 231 PS/PD/SS/SD
  184 => { if mp != MP_66 then raise_UD(); evex_exec_fma_packed(PT_FMAdd,  FMA_231, pfx) },
  185 => { if mp != MP_66 then raise_UD(); evex_exec_fma_scalar(PT_FMAdd,  FMA_231, pfx) },
  186 => { if mp != MP_66 then raise_UD(); evex_exec_fma_packed(PT_FMSub,  FMA_231, pfx) },
  187 => { if mp != MP_66 then raise_UD(); evex_exec_fma_scalar(PT_FMSub,  FMA_231, pfx) },
  188 => { if mp != MP_66 then raise_UD(); evex_exec_fma_packed(PT_FNMAdd, FMA_231, pfx) },
  189 => { if mp != MP_66 then raise_UD(); evex_exec_fma_scalar(PT_FNMAdd, FMA_231, pfx) },
  190 => { if mp != MP_66 then raise_UD(); evex_exec_fma_packed(PT_FNMSub, FMA_231, pfx) },
  191 => { if mp != MP_66 then raise_UD(); evex_exec_fma_scalar(PT_FNMSub, FMA_231, pfx) },

  // 0F38 2C: VSCALEFPS (66,W0) / VSCALEFPD (66,W1) [F]
  44 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let (eff_ll, saved_mxcsr) = evex_begin_rc_xrm(pfx, src);
    // VSCALEFPD xmm1/ymm1/zmm1, xmm2/ymm2/zmm2, xmm3/ymm3/zmm3/m128/m256/m512
    // VSCALEFPS xmm1/ymm1/zmm1, xmm2/ymm2/zmm2, xmm3/ymm3/zmm3/m128/m256/m512
    let vl = ll_to_vl(eff_ll);
    let eb = evex_elem(pfx);
    evex_write(dst, evex_wmask(pfx, vl / eb), packed_binop(PB_FPScalef, eb, read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(vl, src, pfx, eb)));
    evex_end_rc(saved_mxcsr)
  },

  // 0F38 2D: VSCALEFSS (66,W0) / VSCALEFSD (66,W1) [T1S]
  45 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
    let (_, saved_mxcsr) = evex_begin_rc_xrm(pfx, src);
    let src1 : xmmword = read_simd(pfx.evex_vvvvv);
    let src2 = evex_src(128, src);
    // VSCALEFSD xmm1, xmm2, xmm3/m64 / VSCALEFSS xmm1, xmm2, xmm3/m32
    if pfx.rex_w then evex_write_scalar(dst, src1[127..64] @ fp_scalef(src1[63..0], src2[63..0]), pfx, 64)
    else evex_write_scalar(dst, src1[127..32] @ fp_scalef(src1[31..0], src2[31..0]), pfx, 32);
    evex_end_rc(saved_mxcsr)
  },

  // 0F38 42: VGETEXPPS (66,W0) / VGETEXPPD (66,W1) [F]
  66 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let (eff_ll, saved_mxcsr) = evex_begin_rc_xrm(pfx, src);
    // VGETEXPPD xmm1/ymm1/zmm1, xmm2/ymm2/zmm2/m128/m256/m512
    // VGETEXPPS xmm1/ymm1/zmm1, xmm2/ymm2/zmm2/m128/m256/m512
    let vl = ll_to_vl(eff_ll);
    let eb = evex_elem(pfx);
    evex_write(dst, evex_wmask(pfx, vl / eb), packed_unop(PU_FPGetexp, eb, evex_bcast_src(vl, src, pfx, eb)));
    evex_end_rc(saved_mxcsr)
  },

  // 0F38 43: VGETEXPSS (66,W0) / VGETEXPSD (66,W1) [T1S]
  67 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
    let (_, saved_mxcsr) = evex_begin_rc_xrm(pfx, src);
    let src1 : xmmword = read_simd(pfx.evex_vvvvv);
    let src2 = evex_src(128, src);
    // VGETEXPSD xmm1, xmm2, xmm3/m64 / VGETEXPSS xmm1, xmm2, xmm3/m32
    if pfx.rex_w then evex_write_scalar(dst, src1[127..64] @ fp_getexp(src2[63..0]), pfx, 64)
    else evex_write_scalar(dst, src1[127..32] @ fp_getexp(src2[31..0]), pfx, 32);
    evex_end_rc(saved_mxcsr)
  },

  // 0F38 4C: VRCP14PS (66,W0) / VRCP14PD (66,W1) [F]
  76 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { XRM_mem(_) => true, _ => false };
    // VRCP14PD xmm1/ymm1/zmm1, xmm2/ymm2/zmm2/m128/m256/m512
    // VRCP14PS xmm1/ymm1/zmm1, xmm2/ymm2/zmm2/m128/m256/m512
    let vl = evex_vl(pfx);
    let eb = evex_elem(pfx);
    evex_write(dst, evex_wmask(pfx, vl / eb), packed_unop(PU_FPRcp14, eb, evex_bcast_src(vl, src, pfx, eb)))
  },

  // 0F38 4D: VRCP14SS (66,W0) / VRCP14SD (66,W1) [T1S]
  77 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
    let src1 : xmmword = read_simd(pfx.evex_vvvvv);
    let src2 = evex_src(128, src);
    // VRCP14SD xmm1, xmm2, xmm3/m64 / VRCP14SS xmm1, xmm2, xmm3/m32
    if pfx.rex_w then evex_write_scalar(dst, src1[127..64] @ fp_rcp14(src2[63..0]), pfx, 64)
    else evex_write_scalar(dst, src1[127..32] @ fp_rcp14(src2[31..0]), pfx, 32)
  },

  // 0F38 4E: VRSQRT14PS (66,W0) / VRSQRT14PD (66,W1) [F]
  78 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { XRM_mem(_) => true, _ => false };
    // VRSQRT14PD xmm1/ymm1/zmm1, xmm2/ymm2/zmm2/m128/m256/m512
    // VRSQRT14PS xmm1/ymm1/zmm1, xmm2/ymm2/zmm2/m128/m256/m512
    let vl = evex_vl(pfx);
    let eb = evex_elem(pfx);
    evex_write(dst, evex_wmask(pfx, vl / eb), packed_unop(PU_FPRsqrt14, eb, evex_bcast_src(vl, src, pfx, eb)))
  },

  // 0F38 4F: VRSQRT14SS (66,W0) / VRSQRT14SD (66,W1) [T1S]
  79 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
    let src1 : xmmword = read_simd(pfx.evex_vvvvv);
    let src2 = evex_src(128, src);
    // VRSQRT14SD xmm1, xmm2, xmm3/m64 / VRSQRT14SS xmm1, xmm2, xmm3/m32
    if pfx.rex_w then evex_write_scalar(dst, src1[127..64] @ fp_rsqrt14(src2[63..0]), pfx, 64)
    else evex_write_scalar(dst, src1[127..32] @ fp_rsqrt14(src2[31..0]), pfx, 32)
  },

  // 0F38 2A: VPBROADCASTMB2Q (F3, W=1) [CD] — also VMOVNTDQA (66)
  // 0F38 C6: VGATHERPF0DPS/DPD, VGATHERPF1DPS/DPD (66) [PF]
  // Gather prefetch — architectural NOP (just compute VSIB addresses and discard)
  198 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let reg_field : range(0, 7) = unsigned(modrm[5..3]);
    // reg=1: PF0, reg=2: PF1; VSIB addressing
    if (reg_field != 1 & reg_field != 2) then raise_UD();
    let disp_n : range(4, 64) = if pfx.rex_w then 8 else 4;
    let _ = decode_vsib_evex(modrm, pfx, disp_n)
  },

  // 0F38 C7: VGATHERPF0QPS/QPD, VGATHERPF1QPS/QPD (66) [PF]
  // Gather prefetch (qword index) — architectural NOP
  // 0F38 C7: VGATHERPF0QPS/QPD, VGATHERPF1QPS/QPD (66) [PF]
  // Gather prefetch (qword index) — architectural NOP
  199 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let reg_field : range(0, 7) = unsigned(modrm[5..3]);
    if (reg_field != 1 & reg_field != 2) then raise_UD();
    let disp_n : range(4, 64) = if pfx.rex_w then 8 else 4;
    let _ = decode_vsib_evex(modrm, pfx, disp_n)
  },

  // 0F38 C8: VEXP2PS (66,W0) / VEXP2PD (66,W1) [ER] — 512-bit only
  200 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { XRM_mem(_) => true, _ => false };
    if pfx.rex_w then evex_write(dst, evex_wmask(pfx, 8), packed_unop(PU_FPExp2, 64, evex_bcast_src(512, src, pfx, 64)))
    else evex_write(dst, evex_wmask(pfx, 16), packed_unop(PU_FPExp2, 32, evex_bcast_src(512, src, pfx, 32)))
  },

  // 0F38 CA: VRCP28PS (66,W0) / VRCP28PD (66,W1) [ER] — 512-bit only
  202 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { XRM_mem(_) => true, _ => false };
    if pfx.rex_w then evex_write(dst, evex_wmask(pfx, 8), packed_unop(PU_FPRcp28, 64, evex_bcast_src(512, src, pfx, 64)))
    else evex_write(dst, evex_wmask(pfx, 16), packed_unop(PU_FPRcp28, 32, evex_bcast_src(512, src, pfx, 32)))
  },

  // 0F38 CB: VRCP28SS (66,W0) / VRCP28SD (66,W1) [ER] — scalar
  203 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
    let src1 : xmmword = read_simd(pfx.evex_vvvvv);
    let src2 = evex_src(128, src);
    if pfx.rex_w then evex_write_scalar(dst, src1[127..64] @ fp_rcp28(src2[63..0]), pfx, 64)
    else evex_write_scalar(dst, src1[127..32] @ fp_rcp28(src2[31..0]), pfx, 32)
  },

  // 0F38 CC: VRSQRT28PS (66,W0) / VRSQRT28PD (66,W1) [ER] — 512-bit only
  204 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { XRM_mem(_) => true, _ => false };
    if pfx.rex_w then evex_write(dst, evex_wmask(pfx, 8), packed_unop(PU_FPRsqrt28, 64, evex_bcast_src(512, src, pfx, 64)))
    else evex_write(dst, evex_wmask(pfx, 16), packed_unop(PU_FPRsqrt28, 32, evex_bcast_src(512, src, pfx, 32)))
  },

  // 0F38 CD: VRSQRT28SS (66,W0) / VRSQRT28SD (66,W1) [ER] — scalar
  205 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
    let src1 : xmmword = read_simd(pfx.evex_vvvvv);
    let src2 = evex_src(128, src);
    if pfx.rex_w then evex_write_scalar(dst, src1[127..64] @ fp_rsqrt28(src2[63..0]), pfx, 64)
    else evex_write_scalar(dst, src1[127..32] @ fp_rsqrt28(src2[31..0]), pfx, 32)
  },

  // 0F38 CF: VGF2P8MULB (66,W0) [GFNI]
  207 => {
    if mp != MP_66 | pfx.rex_w then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    let mask = evex_wmask(pfx, vl / 8);
    match vl {
      _ => evex_write(dst, mask, avx_gf2p8mulb(read_simd(vl, pfx.evex_vvvvv), evex_src(vl, src))),
    }
  },

  _ => raise_UD(),
  }
}

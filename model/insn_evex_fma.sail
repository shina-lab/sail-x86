// x86-64 — EVEX FMA Instructions (0F38 map)

// gather_addr and gather_addr_q are defined in insn_sse4_helpers.sail

// VPGATHERDD / VGATHERDPS: dword indices, dword elements (same width)
val exec_gather_d32 : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), simd_idx, VSIB, kreg_idx) -> unit
function exec_gather_d32(vl, dst, vsib, k_idx) = {
  let mask = read_kreg(k_idx);
  var result : bits('vl) = read_simd(dst);
  let indices : bits('vl) = read_simd(vsib.vsib_vidx);
  foreach (i from 0 to ('vl / 32 - 1)) {
    let lo = i * 32;
    if mask[i] == 0b1 then {
      let idx : dword = indices[(lo + 31)..lo];
      result = [result with (lo + 31)..lo = read_mem(gather_addr(vsib.vsib_base, idx, vsib.vsib_scale))];
    }
  };
  write_simd(vl, dst, result);
  write_kreg(k_idx, zeros())
}

// VPGATHERDQ / VGATHERDPD: dword indices, qword elements
// Index vector is half width (vl/2 bits of dwords).
val exec_gather_d64 : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), simd_idx, VSIB, kreg_idx) -> unit
function exec_gather_d64(vl, dst, vsib, k_idx) = {
  let mask = read_kreg(k_idx);
  var result : bits('vl) = read_simd(dst);
  let n = vl / 64;
  foreach (i from 0 to (n - 1)) {
    let ilo = i * 32;
    let olo = i * 64;
    if mask[i] == 0b1 then {
      let idx : dword = ZMM[vsib.vsib_vidx][(ilo + 31)..ilo];
      result = [result with (olo + 63)..olo = read_mem(gather_addr(vsib.vsib_base, idx, vsib.vsib_scale))];
    }
  };
  write_simd(vl, dst, result);
  write_kreg(k_idx, zeros())
}

// VPGATHERQD / VGATHERQPS: qword indices, dword elements
// Output is half width (vl/2 bits of dwords), written to lower half of register.
val exec_gather_q32 : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), simd_idx, VSIB, kreg_idx) -> unit
function exec_gather_q32(vl, dst, vsib, k_idx) = {
  let mask = read_kreg(k_idx);
  let n = vl / 64;
  let indices : bits('vl) = read_simd(vsib.vsib_vidx);
  var result : bits(div('vl, 2)) = ZMM[dst][(vl / 2 - 1)..0];
  foreach (i from 0 to (n - 1)) {
    let ilo = i * 64;
    let olo = i * 32;
    if mask[i] == 0b1 then {
      let idx : qword = indices[(ilo + 63)..ilo];
      result = [result with (olo + 31)..olo = read_mem(gather_addr_q(vsib.vsib_base, idx, vsib.vsib_scale))];
    }
  };
  // Zero-extend the narrow result to full register width
  ZMM[dst] = zero_extend(result);
  write_kreg(k_idx, zeros())
}

// VPGATHERQQ / VGATHERQPD: qword indices, qword elements (same width)
val exec_gather_q64 : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), simd_idx, VSIB, kreg_idx) -> unit
function exec_gather_q64(vl, dst, vsib, k_idx) = {
  let mask = read_kreg(k_idx);
  var result : bits('vl) = read_simd(dst);
  let indices : bits('vl) = read_simd(vsib.vsib_vidx);
  foreach (i from 0 to ('vl / 64 - 1)) {
    let lo = i * 64;
    if mask[i] == 0b1 then {
      let idx : qword = indices[(lo + 63)..lo];
      result = [result with (lo + 63)..lo = read_mem(gather_addr_q(vsib.vsib_base, idx, vsib.vsib_scale))];
    }
  };
  write_simd(vl, dst, result);
  write_kreg(k_idx, zeros())
}

/* ---- Scatter: VPSCATTERDD/DQ, VSCATTERDPS/DPD (dword indices) ---- */
// VPSCATTERDD / VSCATTERDPS: dword indices, dword elements
val exec_scatter_d32 : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), simd_idx, VSIB, kreg_idx) -> unit
function exec_scatter_d32(vl, src, vsib, k_idx) = {
  let mask = read_kreg(k_idx);
  let data : bits('vl) = read_simd(src);
  let indices : bits('vl) = read_simd(vsib.vsib_vidx);
  foreach (i from 0 to ('vl / 32 - 1)) {
    let lo = i * 32;
    if mask[i] == 0b1 then
      write_mem(32, gather_addr(vsib.vsib_base, indices[(lo + 31)..lo], vsib.vsib_scale), data[(lo + 31)..lo]);
  };
  write_kreg(k_idx, zeros())
}

// VPSCATTERDQ / VSCATTERDPD: dword indices, qword elements
val exec_scatter_d64 : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), simd_idx, VSIB, kreg_idx) -> unit
function exec_scatter_d64(vl, src, vsib, k_idx) = {
  let mask = read_kreg(k_idx);
  let data : bits('vl) = read_simd(src);
  let n = vl / 64;
  foreach (i from 0 to (n - 1)) {
    let ilo = i * 32;
    let olo = i * 64;
    if mask[i] == 0b1 then
      write_mem(64, gather_addr(vsib.vsib_base, ZMM[vsib.vsib_vidx][(ilo + 31)..ilo], vsib.vsib_scale), data[(olo + 63)..olo]);
  };
  write_kreg(k_idx, zeros())
}

// VPSCATTERQD / VSCATTERQPS: qword indices, dword elements
val exec_scatter_q32 : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), simd_idx, VSIB, kreg_idx) -> unit
function exec_scatter_q32(vl, src, vsib, k_idx) = {
  let mask = read_kreg(k_idx);
  let indices : bits('vl) = read_simd(vsib.vsib_vidx);
  let n = vl / 64;
  foreach (i from 0 to (n - 1)) {
    let ilo = i * 64;
    let olo = i * 32;
    if mask[i] == 0b1 then
      write_mem(32, gather_addr_q(vsib.vsib_base, indices[(ilo + 63)..ilo], vsib.vsib_scale), ZMM[src][(olo + 31)..olo]);
  };
  write_kreg(k_idx, zeros())
}

// VPSCATTERQQ / VSCATTERQPD: qword indices, qword elements
val exec_scatter_q64 : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), simd_idx, VSIB, kreg_idx) -> unit
function exec_scatter_q64(vl, src, vsib, k_idx) = {
  let mask = read_kreg(k_idx);
  let data : bits('vl) = read_simd(src);
  let indices : bits('vl) = read_simd(vsib.vsib_vidx);
  foreach (i from 0 to ('vl / 64 - 1)) {
    let lo = i * 64;
    if mask[i] == 0b1 then
      write_mem(64, gather_addr_q(vsib.vsib_base, indices[(lo + 63)..lo], vsib.vsib_scale), data[(lo + 63)..lo]);
  };
  write_kreg(k_idx, zeros())
}

/* ---- VPCLMULQDQ: carry-less multiply per 128-bit lane ---- */

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

val avx_vpmadd52luq : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), bits('vl), bits('vl)) -> bits('vl)
function avx_vpmadd52luq(vl, dst, src1, src2) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 64 - 1)) {
    let lo = i * 64;
    r[(lo + 63)..lo] = avx_vpmadd52luq_elem(dst[(lo + 63)..lo], src1[(lo + 63)..lo], src2[(lo + 63)..lo])
  };
  r
}

val avx_vpmadd52huq : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), bits('vl), bits('vl)) -> bits('vl)
function avx_vpmadd52huq(vl, dst, src1, src2) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 64 - 1)) {
    let lo = i * 64;
    r[(lo + 63)..lo] = avx_vpmadd52huq_elem(dst[(lo + 63)..lo], src1[(lo + 63)..lo], src2[(lo + 63)..lo])
  };
  r
}

val avx_gf2p8mulb : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), bits('vl)) -> bits('vl)
function avx_gf2p8mulb(vl, src1, src2) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 8 - 1)) {
    let lo = i * 8;
    r[(lo + 7)..lo] = gf2p8_mul(src1[(lo + 7)..lo], src2[(lo + 7)..lo])
  };
  r
}

// Per-element FP unary helpers (polymorphic over vl and eb)
val avx_vexp2 : forall 'vl 'eb, 'vl in {128, 256, 512} & 'eb in {32, 64}.
  (int('eb), bits('vl)) -> bits('vl)
function avx_vexp2(eb, src) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 'eb - 1)) {
    let lo = i * 'eb;
    r[(lo + 'eb - 1)..lo] = match eb {
      32 => __f32_exp2(src[(lo + 'eb - 1)..lo]),
      64 => __f64_exp2(src[(lo + 'eb - 1)..lo]),
    }
  };
  r
}

val avx_vrcp28 : forall 'vl 'eb, 'vl in {128, 256, 512} & 'eb in {32, 64}.
  (int('eb), bits('vl)) -> bits('vl)
function avx_vrcp28(eb, src) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 'eb - 1)) {
    let lo = i * 'eb;
    r[(lo + 'eb - 1)..lo] = match eb {
      32 => __f32_rcp28(src[(lo + 'eb - 1)..lo]),
      64 => __f64_rcp28(src[(lo + 'eb - 1)..lo]),
    }
  };
  r
}

val avx_vrsqrt28 : forall 'vl 'eb, 'vl in {128, 256, 512} & 'eb in {32, 64}.
  (int('eb), bits('vl)) -> bits('vl)
function avx_vrsqrt28(eb, src) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 'eb - 1)) {
    let lo = i * 'eb;
    r[(lo + 'eb - 1)..lo] = match eb {
      32 => __f32_rsqrt28(src[(lo + 'eb - 1)..lo]),
      64 => __f64_rsqrt28(src[(lo + 'eb - 1)..lo]),
    }
  };
  r
}

val avx_vgetexp : forall 'vl 'eb, 'vl in {128, 256, 512} & 'eb in {32, 64}.
  (int('eb), bits('vl)) -> bits('vl)
function avx_vgetexp(eb, src) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 'eb - 1)) {
    let lo = i * 'eb;
    r[(lo + 'eb - 1)..lo] = match eb {
      32 => __f32_getexp(src[(lo + 'eb - 1)..lo]),
      64 => __f64_getexp(src[(lo + 'eb - 1)..lo]),
    }
  };
  r
}

val avx_vrcp14 : forall 'vl 'eb, 'vl in {128, 256, 512} & 'eb in {32, 64}.
  (int('eb), bits('vl)) -> bits('vl)
function avx_vrcp14(eb, src) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 'eb - 1)) {
    let lo = i * 'eb;
    r[(lo + 'eb - 1)..lo] = match eb {
      32 => __f32_rcp14(src[(lo + 'eb - 1)..lo]),
      64 => __f64_rcp14(src[(lo + 'eb - 1)..lo]),
    }
  };
  r
}

val avx_vrsqrt14 : forall 'vl 'eb, 'vl in {128, 256, 512} & 'eb in {32, 64}.
  (int('eb), bits('vl)) -> bits('vl)
function avx_vrsqrt14(eb, src) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 'eb - 1)) {
    let lo = i * 'eb;
    r[(lo + 'eb - 1)..lo] = match eb {
      32 => __f32_rsqrt14(src[(lo + 'eb - 1)..lo]),
      64 => __f64_rsqrt14(src[(lo + 'eb - 1)..lo]),
    }
  };
  r
}

val avx_vscalef : forall 'vl 'eb, 'vl in {128, 256, 512} & 'eb in {32, 64}.
  (int('eb), bits('vl), bits('vl)) -> bits('vl)
function avx_vscalef(eb, a, b) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 'eb - 1)) {
    let lo = i * 'eb;
    r[(lo + 'eb - 1)..lo] = match eb {
      32 => __f32_scalef(a[(lo + 'eb - 1)..lo], b[(lo + 'eb - 1)..lo]),
      64 => __f64_scalef(a[(lo + 'eb - 1)..lo], b[(lo + 'eb - 1)..lo]),
    }
  };
  r
}

val dispatch_evex_fma : (range(0, 255), Prefixes) -> unit
function dispatch_evex_fma(op, pfx) = {
  let mp = get_mandatory_prefix(pfx);

  match op {
  // 0F38 90: VPGATHERDD (66,W0) / VPGATHERDQ (66,W1) [F]
  144 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let vl = evex_vl(pfx);
    let vsib = decode_vsib_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
    if pfx.rex_w then exec_gather_d64(vl, dst, vsib, pfx.evex_aaa)
    else exec_gather_d32(vl, dst, vsib, pfx.evex_aaa)
  },

  // 0F38 91: VPGATHERQD (66,W0) / VPGATHERQQ (66,W1) [F]
  145 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let vl = evex_vl(pfx);
    let vsib = decode_vsib_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
    if pfx.rex_w then exec_gather_q64(vl, dst, vsib, pfx.evex_aaa)
    else exec_gather_q32(vl, dst, vsib, pfx.evex_aaa)
  },

  // 0F38 92: VGATHERDPS (66,W0) / VGATHERDPD (66,W1) [F]
  146 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let vl = evex_vl(pfx);
    let vsib = decode_vsib_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
    if pfx.rex_w then exec_gather_d64(vl, dst, vsib, pfx.evex_aaa)
    else exec_gather_d32(vl, dst, vsib, pfx.evex_aaa)
  },

  // 0F38 93: VGATHERQPS (66,W0) / VGATHERQPD (66,W1) [F]
  147 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let vl = evex_vl(pfx);
    let vsib = decode_vsib_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
    if pfx.rex_w then exec_gather_q64(vl, dst, vsib, pfx.evex_aaa)
    else exec_gather_q32(vl, dst, vsib, pfx.evex_aaa)
  },

  // =====================================================================
  // FMA 132 forms (0x96-0x9F)
  // =====================================================================

  // 0F38 96: VFMADDSUB132PS (66,W0) / VFMADDSUB132PD (66,W1) [F]
  150 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let (eff_ll, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
    let vl = ll_to_vl(eff_ll);
    let eb = evex_elem(pfx);
    let mask = evex_wmask(pfx, vl / eb);
    evex_write(dst, mask, avx_fmaddsub(eb, read_simd(vl, dst), evex_bcast_src(modrm, src, pfx, eb), read_simd(vl, pfx.evex_vvvvv)));
    evex_end_rc(saved_mxcsr)
  },

  // 0F38 97: VFMSUBADD132PS (66,W0) / VFMSUBADD132PD (66,W1) [F]
  151 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let (eff_ll, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
    let vl = ll_to_vl(eff_ll);
    let eb = evex_elem(pfx);
    let mask = evex_wmask(pfx, vl / eb);
    evex_write(dst, mask, avx_fmsubadd(eb, read_simd(vl, dst), evex_bcast_src(modrm, src, pfx, eb), read_simd(vl, pfx.evex_vvvvv)));
    evex_end_rc(saved_mxcsr)
  },

  // 0F38 98: VFMADD132PS (66,W0) / VFMADD132PD (66,W1) [F]
  152 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let (eff_ll, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
    let vl = ll_to_vl(eff_ll);
    let eb = evex_elem(pfx);
    let mask = evex_wmask(pfx, vl / eb);
    evex_write(dst, mask, packed_ternop(PT_FMAdd, eb, read_simd(vl, dst), evex_bcast_src(modrm, src, pfx, eb), read_simd(vl, pfx.evex_vvvvv)));
    evex_end_rc(saved_mxcsr)
  },

  // 0F38 99: VFMADD132SS (66,W0) / VFMADD132SD (66,W1) [F]
  153 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let (_, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
    let src2 = read_xmm(pfx.evex_vvvvv);
    let src3 = evex_src(128,modrm, src, pfx);
    exec_vfma_scalar(PT_FMAdd, FMA_132, pfx.rex_w, dst, src2, src3);
    evex_end_rc(saved_mxcsr)
  },

  // 0F38 9A: VFMSUB132PS (66,W0) / VFMSUB132PD (66,W1) [F]
  154 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let (eff_ll, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
    let vl = ll_to_vl(eff_ll);
    let eb = evex_elem(pfx);
    let mask = evex_wmask(pfx, vl / eb);
    evex_write(dst, mask, packed_ternop(PT_FMSub, eb, read_simd(vl, dst), evex_bcast_src(modrm, src, pfx, eb), read_simd(vl, pfx.evex_vvvvv)));
    evex_end_rc(saved_mxcsr)
  },

  // 0F38 9B: VFMSUB132SS (66,W0) / VFMSUB132SD (66,W1) [F]
  155 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let (_, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
    let src2 = read_xmm(pfx.evex_vvvvv);
    let src3 = evex_src(128,modrm, src, pfx);
    exec_vfma_scalar(PT_FMSub, FMA_132, pfx.rex_w, dst, src2, src3);
    evex_end_rc(saved_mxcsr)
  },

  // 0F38 9C: VFNMADD132PS (66,W0) / VFNMADD132PD (66,W1) [F]
  156 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let (eff_ll, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
    let vl = ll_to_vl(eff_ll);
    let eb = evex_elem(pfx);
    let mask = evex_wmask(pfx, vl / eb);
    evex_write(dst, mask, packed_ternop(PT_FNMAdd, eb, read_simd(vl, dst), evex_bcast_src(modrm, src, pfx, eb), read_simd(vl, pfx.evex_vvvvv)));
    evex_end_rc(saved_mxcsr)
  },

  // 0F38 9D: VFNMADD132SS (66,W0) / VFNMADD132SD (66,W1) [F]
  157 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let (_, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
    let src2 = read_xmm(pfx.evex_vvvvv);
    let src3 = evex_src(128,modrm, src, pfx);
    exec_vfma_scalar(PT_FNMAdd, FMA_132, pfx.rex_w, dst, src2, src3);
    evex_end_rc(saved_mxcsr)
  },

  // 0F38 9E: VFNMSUB132PS (66,W0) / VFNMSUB132PD (66,W1) [F]
  158 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let (eff_ll, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
    let vl = ll_to_vl(eff_ll);
    let eb = evex_elem(pfx);
    let mask = evex_wmask(pfx, vl / eb);
    evex_write(dst, mask, packed_ternop(PT_FNMSub, eb, read_simd(vl, dst), evex_bcast_src(modrm, src, pfx, eb), read_simd(vl, pfx.evex_vvvvv)));
    evex_end_rc(saved_mxcsr)
  },

  // 0F38 9F: VFNMSUB132SS (66,W0) / VFNMSUB132SD (66,W1) [F]
  159 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let (_, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
    let src2 = read_xmm(pfx.evex_vvvvv);
    let src3 = evex_src(128,modrm, src, pfx);
    exec_vfma_scalar(PT_FNMSub, FMA_132, pfx.rex_w, dst, src2, src3);
    evex_end_rc(saved_mxcsr)
  },

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
    if pfx.rex_w then exec_scatter_d64(vl, src, vsib, pfx.evex_aaa)
    else exec_scatter_d32(vl, src, vsib, pfx.evex_aaa)
  },

  // 0F38 A1: VPSCATTERQD (66,W0) / VPSCATTERQQ (66,W1) [F]
  161 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let src = evex_reg_idx(modrm, pfx);
    let vl = evex_vl(pfx);
    let vsib = decode_vsib_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
    if pfx.rex_w then exec_scatter_q64(vl, src, vsib, pfx.evex_aaa)
    else exec_scatter_q32(vl, src, vsib, pfx.evex_aaa)
  },

  // 0F38 A2: VSCATTERDPS (66,W0) / VSCATTERDPD (66,W1) [F]
  162 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let src = evex_reg_idx(modrm, pfx);
    let vl = evex_vl(pfx);
    let vsib = decode_vsib_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
    if pfx.rex_w then exec_scatter_d64(vl, src, vsib, pfx.evex_aaa)
    else exec_scatter_d32(vl, src, vsib, pfx.evex_aaa)
  },

  // 0F38 A3: VSCATTERQPS (66,W0) / VSCATTERQPD (66,W1) [F]
  163 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let src = evex_reg_idx(modrm, pfx);
    let vl = evex_vl(pfx);
    let vsib = decode_vsib_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
    if pfx.rex_w then exec_scatter_q64(vl, src, vsib, pfx.evex_aaa)
    else exec_scatter_q32(vl, src, vsib, pfx.evex_aaa)
  },

  // =====================================================================
  // FMA 213 forms (0xA6-0xAF)
  // =====================================================================

  // 0F38 A6: VFMADDSUB213PS (66,W0) / VFMADDSUB213PD (66,W1) [F]
  166 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let (eff_ll, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
    let vl = ll_to_vl(eff_ll);
    let eb = evex_elem(pfx);
    let mask = evex_wmask(pfx, vl / eb);
    evex_write(dst, mask, avx_fmaddsub(eb, read_simd(vl, pfx.evex_vvvvv), read_simd(vl, dst), evex_bcast_src(modrm, src, pfx, eb)));
    evex_end_rc(saved_mxcsr)
  },

  // 0F38 A7: VFMSUBADD213PS (66,W0) / VFMSUBADD213PD (66,W1) [F]
  167 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let (eff_ll, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
    let vl = ll_to_vl(eff_ll);
    let eb = evex_elem(pfx);
    let mask = evex_wmask(pfx, vl / eb);
    evex_write(dst, mask, avx_fmsubadd(eb, read_simd(vl, pfx.evex_vvvvv), read_simd(vl, dst), evex_bcast_src(modrm, src, pfx, eb)));
    evex_end_rc(saved_mxcsr)
  },

  // 0F38 A8: VFMADD213PS (66,W0) / VFMADD213PD (66,W1) [F]
  168 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let (eff_ll, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
    let vl = ll_to_vl(eff_ll);
    let eb = evex_elem(pfx);
    let mask = evex_wmask(pfx, vl / eb);
    evex_write(dst, mask, packed_ternop(PT_FMAdd, eb, read_simd(vl, pfx.evex_vvvvv), read_simd(vl, dst), evex_bcast_src(modrm, src, pfx, eb)));
    evex_end_rc(saved_mxcsr)
  },

  // 0F38 A9: VFMADD213SS (66,W0) / VFMADD213SD (66,W1) [F]
  169 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let (_, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
    let src2 = read_xmm(pfx.evex_vvvvv);
    let src3 = evex_src(128,modrm, src, pfx);
    exec_vfma_scalar(PT_FMAdd, FMA_213, pfx.rex_w, dst, src2, src3);
    evex_end_rc(saved_mxcsr)
  },

  // 0F38 AA: VFMSUB213PS (66,W0) / VFMSUB213PD (66,W1) [F]
  170 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let (eff_ll, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
    let vl = ll_to_vl(eff_ll);
    let eb = evex_elem(pfx);
    let mask = evex_wmask(pfx, vl / eb);
    evex_write(dst, mask, packed_ternop(PT_FMSub, eb, read_simd(vl, pfx.evex_vvvvv), read_simd(vl, dst), evex_bcast_src(modrm, src, pfx, eb)));
    evex_end_rc(saved_mxcsr)
  },

  // 0F38 AB: VFMSUB213SS (66,W0) / VFMSUB213SD (66,W1) [F]
  171 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let (_, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
    let src2 = read_xmm(pfx.evex_vvvvv);
    let src3 = evex_src(128,modrm, src, pfx);
    exec_vfma_scalar(PT_FMSub, FMA_213, pfx.rex_w, dst, src2, src3);
    evex_end_rc(saved_mxcsr)
  },

  // 0F38 AC: VFNMADD213PS (66,W0) / VFNMADD213PD (66,W1) [F]
  172 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let (eff_ll, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
    let vl = ll_to_vl(eff_ll);
    let eb = evex_elem(pfx);
    let mask = evex_wmask(pfx, vl / eb);
    evex_write(dst, mask, packed_ternop(PT_FNMAdd, eb, read_simd(vl, pfx.evex_vvvvv), read_simd(vl, dst), evex_bcast_src(modrm, src, pfx, eb)));
    evex_end_rc(saved_mxcsr)
  },

  // 0F38 AD: VFNMADD213SS (66,W0) / VFNMADD213SD (66,W1) [F]
  173 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let (_, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
    let src2 = read_xmm(pfx.evex_vvvvv);
    let src3 = evex_src(128,modrm, src, pfx);
    exec_vfma_scalar(PT_FNMAdd, FMA_213, pfx.rex_w, dst, src2, src3);
    evex_end_rc(saved_mxcsr)
  },

  // 0F38 AE: VFNMSUB213PS (66,W0) / VFNMSUB213PD (66,W1) [F]
  174 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let (eff_ll, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
    let vl = ll_to_vl(eff_ll);
    let eb = evex_elem(pfx);
    let mask = evex_wmask(pfx, vl / eb);
    evex_write(dst, mask, packed_ternop(PT_FNMSub, eb, read_simd(vl, pfx.evex_vvvvv), read_simd(vl, dst), evex_bcast_src(modrm, src, pfx, eb)));
    evex_end_rc(saved_mxcsr)
  },

  // 0F38 AF: VFNMSUB213SS (66,W0) / VFNMSUB213SD (66,W1) [F]
  175 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let (_, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
    let src2 = read_xmm(pfx.evex_vvvvv);
    let src3 = evex_src(128,modrm, src, pfx);
    exec_vfma_scalar(PT_FNMSub, FMA_213, pfx.rex_w, dst, src2, src3);
    evex_end_rc(saved_mxcsr)
  },

  // 0F38 B4: VPMADD52LUQ (66,W1) [IFMA]
  180 => {
    if mp != MP_66 | ~(pfx.rex_w) then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    let mask = evex_wmask(pfx, vl / 64);
    match vl {
      _ => evex_write(dst, mask, avx_vpmadd52luq(read_simd(vl, dst), read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(vl, modrm, src, pfx, 64))),
    }
  },

  // 0F38 B5: VPMADD52HUQ (66,W1) [IFMA]
  181 => {
    if mp != MP_66 | ~(pfx.rex_w) then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    let mask = evex_wmask(pfx, vl / 64);
    match vl {
      _ => evex_write(dst, mask, avx_vpmadd52huq(read_simd(vl, dst), read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(vl, modrm, src, pfx, 64))),
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
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let (eff_ll, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
    let vl = ll_to_vl(eff_ll);
    let eb = evex_elem(pfx);
    let mask = evex_wmask(pfx, vl / eb);
    evex_write(dst, mask, avx_fmaddsub(eb, read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(modrm, src, pfx, eb), read_simd(vl, dst)));
    evex_end_rc(saved_mxcsr)
  },

  // 0F38 B7: VFMSUBADD231PS (66,W0) / VFMSUBADD231PD (66,W1) [F]
  183 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let (eff_ll, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
    let vl = ll_to_vl(eff_ll);
    let eb = evex_elem(pfx);
    let mask = evex_wmask(pfx, vl / eb);
    evex_write(dst, mask, avx_fmsubadd(eb, read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(modrm, src, pfx, eb), read_simd(vl, dst)));
    evex_end_rc(saved_mxcsr)
  },

  // 0F38 B8: VFMADD231PS (66,W0) / VFMADD231PD (66,W1) [F]
  184 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let (eff_ll, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
    let vl = ll_to_vl(eff_ll);
    let eb = evex_elem(pfx);
    let mask = evex_wmask(pfx, vl / eb);
    evex_write(dst, mask, packed_ternop(PT_FMAdd, eb, read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(modrm, src, pfx, eb), read_simd(vl, dst)));
    evex_end_rc(saved_mxcsr)
  },

  // 0F38 B9: VFMADD231SS (66,W0) / VFMADD231SD (66,W1) [F]
  185 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let (_, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
    let src2 = read_xmm(pfx.evex_vvvvv);
    let src3 = evex_src(128,modrm, src, pfx);
    exec_vfma_scalar(PT_FMAdd, FMA_231, pfx.rex_w, dst, src2, src3);
    evex_end_rc(saved_mxcsr)
  },

  // 0F38 BA: VFMSUB231PS (66,W0) / VFMSUB231PD (66,W1) [F]
  186 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let (eff_ll, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
    let vl = ll_to_vl(eff_ll);
    let eb = evex_elem(pfx);
    let mask = evex_wmask(pfx, vl / eb);
    evex_write(dst, mask, packed_ternop(PT_FMSub, eb, read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(modrm, src, pfx, eb), read_simd(vl, dst)));
    evex_end_rc(saved_mxcsr)
  },

  // 0F38 BB: VFMSUB231SS (66,W0) / VFMSUB231SD (66,W1) [F]
  187 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let (_, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
    let src2 = read_xmm(pfx.evex_vvvvv);
    let src3 = evex_src(128,modrm, src, pfx);
    exec_vfma_scalar(PT_FMSub, FMA_231, pfx.rex_w, dst, src2, src3);
    evex_end_rc(saved_mxcsr)
  },

  // 0F38 BC: VFNMADD231PS (66,W0) / VFNMADD231PD (66,W1) [F]
  188 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let (eff_ll, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
    let vl = ll_to_vl(eff_ll);
    let eb = evex_elem(pfx);
    let mask = evex_wmask(pfx, vl / eb);
    evex_write(dst, mask, packed_ternop(PT_FNMAdd, eb, read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(modrm, src, pfx, eb), read_simd(vl, dst)));
    evex_end_rc(saved_mxcsr)
  },

  // 0F38 BD: VFNMADD231SS (66,W0) / VFNMADD231SD (66,W1) [F]
  189 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let (_, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
    let src2 = read_xmm(pfx.evex_vvvvv);
    let src3 = evex_src(128,modrm, src, pfx);
    exec_vfma_scalar(PT_FNMAdd, FMA_231, pfx.rex_w, dst, src2, src3);
    evex_end_rc(saved_mxcsr)
  },

  // 0F38 BE: VFNMSUB231PS (66,W0) / VFNMSUB231PD (66,W1) [F]
  190 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let (eff_ll, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
    let vl = ll_to_vl(eff_ll);
    let eb = evex_elem(pfx);
    let mask = evex_wmask(pfx, vl / eb);
    evex_write(dst, mask, packed_ternop(PT_FNMSub, eb, read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(modrm, src, pfx, eb), read_simd(vl, dst)));
    evex_end_rc(saved_mxcsr)
  },

  // 0F38 BF: VFNMSUB231SS (66,W0) / VFNMSUB231SD (66,W1) [F]
  191 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let (_, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
    let src2 = read_xmm(pfx.evex_vvvvv);
    let src3 = evex_src(128,modrm, src, pfx);
    exec_vfma_scalar(PT_FNMSub, FMA_231, pfx.rex_w, dst, src2, src3);
    evex_end_rc(saved_mxcsr)
  },

  // 0F38 2C: VSCALEFPS (66,W0) / VSCALEFPD (66,W1) [F]
  44 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let (eff_ll, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
    // VSCALEFPD xmm1/ymm1/zmm1, xmm2/ymm2/zmm2, xmm3/ymm3/zmm3/m128/m256/m512
    // VSCALEFPS xmm1/ymm1/zmm1, xmm2/ymm2/zmm2, xmm3/ymm3/zmm3/m128/m256/m512
    let vl = ll_to_vl(eff_ll);
    let eb = evex_elem(pfx);
    evex_write(dst, evex_wmask(pfx, vl / eb), avx_vscalef(eb, read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(vl, modrm, src, pfx, eb)));
    evex_end_rc(saved_mxcsr)
  },

  // 0F38 2D: VSCALEFSS (66,W0) / VSCALEFSD (66,W1) [T1S]
  45 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let (_, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
    let src1 = read_xmm(pfx.evex_vvvvv);
    let src2 = evex_src(128,modrm, src, pfx);
    // VSCALEFSD xmm1, xmm2, xmm3/m64 / VSCALEFSS xmm1, xmm2, xmm3/m32
    if pfx.rex_w then evex_write_scalar(dst, src1[127..64] @ __f64_scalef(src1[63..0], src2[63..0]), pfx, 64)
    else evex_write_scalar(dst, src1[127..32] @ __f32_scalef(src1[31..0], src2[31..0]), pfx, 32);
    evex_end_rc(saved_mxcsr)
  },

  // 0F38 42: VGETEXPPS (66,W0) / VGETEXPPD (66,W1) [F]
  66 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let (eff_ll, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
    // VGETEXPPD xmm1/ymm1/zmm1, xmm2/ymm2/zmm2/m128/m256/m512
    // VGETEXPPS xmm1/ymm1/zmm1, xmm2/ymm2/zmm2/m128/m256/m512
    let vl = ll_to_vl(eff_ll);
    let eb = evex_elem(pfx);
    evex_write(dst, evex_wmask(pfx, vl / eb), avx_vgetexp(eb, evex_bcast_src(vl, modrm, src, pfx, eb)));
    evex_end_rc(saved_mxcsr)
  },

  // 0F38 43: VGETEXPSS (66,W0) / VGETEXPSD (66,W1) [T1S]
  67 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let (_, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
    let src1 = read_xmm(pfx.evex_vvvvv);
    let src2 = evex_src(128,modrm, src, pfx);
    // VGETEXPSD xmm1, xmm2, xmm3/m64 / VGETEXPSS xmm1, xmm2, xmm3/m32
    if pfx.rex_w then evex_write_scalar(dst, src1[127..64] @ __f64_getexp(src2[63..0]), pfx, 64)
    else evex_write_scalar(dst, src1[127..32] @ __f32_getexp(src2[31..0]), pfx, 32);
    evex_end_rc(saved_mxcsr)
  },

  // 0F38 4C: VRCP14PS (66,W0) / VRCP14PD (66,W1) [F]
  76 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    // VRCP14PD xmm1/ymm1/zmm1, xmm2/ymm2/zmm2/m128/m256/m512
    // VRCP14PS xmm1/ymm1/zmm1, xmm2/ymm2/zmm2/m128/m256/m512
    let vl = evex_vl(pfx);
    let eb = evex_elem(pfx);
    evex_write(dst, evex_wmask(pfx, vl / eb), avx_vrcp14(eb, evex_bcast_src(vl, modrm, src, pfx, eb)))
  },

  // 0F38 4D: VRCP14SS (66,W0) / VRCP14SD (66,W1) [T1S]
  77 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
    let src1 = read_xmm(pfx.evex_vvvvv);
    let src2 = evex_src(128,modrm, src, pfx);
    // VRCP14SD xmm1, xmm2, xmm3/m64 / VRCP14SS xmm1, xmm2, xmm3/m32
    if pfx.rex_w then evex_write_scalar(dst, src1[127..64] @ __f64_rcp14(src2[63..0]), pfx, 64)
    else evex_write_scalar(dst, src1[127..32] @ __f32_rcp14(src2[31..0]), pfx, 32)
  },

  // 0F38 4E: VRSQRT14PS (66,W0) / VRSQRT14PD (66,W1) [F]
  78 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    // VRSQRT14PD xmm1/ymm1/zmm1, xmm2/ymm2/zmm2/m128/m256/m512
    // VRSQRT14PS xmm1/ymm1/zmm1, xmm2/ymm2/zmm2/m128/m256/m512
    let vl = evex_vl(pfx);
    let eb = evex_elem(pfx);
    evex_write(dst, evex_wmask(pfx, vl / eb), avx_vrsqrt14(eb, evex_bcast_src(vl, modrm, src, pfx, eb)))
  },

  // 0F38 4F: VRSQRT14SS (66,W0) / VRSQRT14SD (66,W1) [T1S]
  79 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
    let src1 = read_xmm(pfx.evex_vvvvv);
    let src2 = evex_src(128,modrm, src, pfx);
    // VRSQRT14SD xmm1, xmm2, xmm3/m64 / VRSQRT14SS xmm1, xmm2, xmm3/m32
    if pfx.rex_w then evex_write_scalar(dst, src1[127..64] @ __f64_rsqrt14(src2[63..0]), pfx, 64)
    else evex_write_scalar(dst, src1[127..32] @ __f32_rsqrt14(src2[31..0]), pfx, 32)
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
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    if pfx.rex_w then evex_write(dst, evex_wmask(pfx, 8), avx_vexp2(64, evex_bcast_src(512,modrm, src, pfx, 64)))
    else evex_write(dst, evex_wmask(pfx, 16), avx_vexp2(32, evex_bcast_src(512,modrm, src, pfx, 32)))
  },

  // 0F38 CA: VRCP28PS (66,W0) / VRCP28PD (66,W1) [ER] — 512-bit only
  202 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    if pfx.rex_w then evex_write(dst, evex_wmask(pfx, 8), avx_vrcp28(64, evex_bcast_src(512,modrm, src, pfx, 64)))
    else evex_write(dst, evex_wmask(pfx, 16), avx_vrcp28(32, evex_bcast_src(512,modrm, src, pfx, 32)))
  },

  // 0F38 CB: VRCP28SS (66,W0) / VRCP28SD (66,W1) [ER] — scalar
  203 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
    let src1 = read_xmm(pfx.evex_vvvvv);
    let src2 = evex_src(128,modrm, src, pfx);
    if pfx.rex_w then evex_write_scalar(dst, src1[127..64] @ __f64_rcp28(src2[63..0]), pfx, 64)
    else evex_write_scalar(dst, src1[127..32] @ __f32_rcp28(src2[31..0]), pfx, 32)
  },

  // 0F38 CC: VRSQRT28PS (66,W0) / VRSQRT28PD (66,W1) [ER] — 512-bit only
  204 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    if pfx.rex_w then evex_write(dst, evex_wmask(pfx, 8), avx_vrsqrt28(64, evex_bcast_src(512,modrm, src, pfx, 64)))
    else evex_write(dst, evex_wmask(pfx, 16), avx_vrsqrt28(32, evex_bcast_src(512,modrm, src, pfx, 32)))
  },

  // 0F38 CD: VRSQRT28SS (66,W0) / VRSQRT28SD (66,W1) [ER] — scalar
  205 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
    let src1 = read_xmm(pfx.evex_vvvvv);
    let src2 = evex_src(128,modrm, src, pfx);
    if pfx.rex_w then evex_write_scalar(dst, src1[127..64] @ __f64_rsqrt28(src2[63..0]), pfx, 64)
    else evex_write_scalar(dst, src1[127..32] @ __f32_rsqrt28(src2[31..0]), pfx, 32)
  },

  // 0F38 CF: VGF2P8MULB (66,W0) [GFNI]
  207 => {
    if mp != MP_66 | pfx.rex_w then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    let mask = evex_wmask(pfx, vl / 8);
    match vl {
      _ => evex_write(dst, mask, avx_gf2p8mulb(read_simd(vl, pfx.evex_vvvvv), evex_src(vl, modrm, src, pfx))),
    }
  },

  _ => raise_UD(),
  }
}

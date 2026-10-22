// x86-64 — EVEX FMA Instructions (0F38 map)

// gather_addr, vsib_read and vsib_write are defined in insn_sse4_helpers.sail

// EVEX gathers: 'iw-bit indices and 'ew-bit elements, as many as the wider
// of the two fits in VL, under k1.  Covers all four combinations: d32
// (32,32), d64 (32,64), q32 (64,32), q64 (64,64).  Element by element from
// the LSB (SDM VPGATHERDD etc., Operation, Vol.2C p.5-549: "IF k1[j] THEN
// DEST[i+31:i] := MEM[...]; k1[j] := 0"), and both registers are written
// as the loop goes, so that a fault on an element leaves "the destination
// register and the mask register (k1) ... partially updated; those
// elements that have been gathered are placed into the destination
// register and have their mask bits set to zero" (p.5-548), and the rest
// as it was (Vol.3A §7.5, p.7-5).  The rest of k1 and of the destination
// are cleared only after the loop: "k1[MAX_KL-1:KL] := 0",
// "DEST[MAXVL-1:VL] := 0" (DEST[MAXVL-1:VL/2] for qword indices and dword
// elements).  For dword elements with qword indices the SDM also lets
// those higher parts be zeroed "even if the instruction triggers an
// exception" (p.5-548), which the model does not do.
val exec_gather : forall 'vl 'iw 'ew, 'vl in {128, 256, 512} & 'iw in {32, 64} & 'ew in {32, 64}.
  (implicit('vl), int('iw), int('ew), simd_idx, VSIB, kreg_idx) -> unit
function exec_gather(vl, iw, ew, dst, vsib, k_idx) = {
  let indices : bits(512) = ZMM[vsib.vsib_vidx];
  let n = vl / (if iw >= ew then iw else ew);
  let elem : bits(512) = zero_extend(ones() : bits('ew));
  let hits = pending_dbp;
  var k : qword = read_kreg(k_idx);
  var stopped : bool = false;
  foreach (i from 0 to (n - 1)) {
    if ~(stopped) & k[i] == bitone then {
      let idx : bits('iw) = (indices >> (i * iw))[iw - 1 .. 0];
      match vsib_read(ew, gather_addr(vsib, idx), hits) {
        Some(v) => {
          let olo = i * ew;
          ZMM[dst] = (ZMM[dst] & ~(elem << olo)) | (zero_extend(v) << olo);
          k[i] = bitzero;
          write_kreg(k_idx, k)
        },
        None() => stopped = true,
      }
    }
  };
  if ~(stopped) then {
    ZMM[dst] = ZMM[dst] & (ones() >> (512 - n * ew));
    write_kreg(k_idx, zeros())
  }
}

// EVEX scatters, with the same indices, elements and order as the
// gathers (SDM VPSCATTERDD etc., Operation, Vol.2C p.5-619: "IF k1[j] ...
// THEN MEM[...] := SRC[i+31:i]; k1[j] := 0").  k1 is written as the loop
// goes, so that after a fault on an element "the mask register [is]
// partially updated" (p.5-619), with the bits of the stored elements
// clear (APM VPSCATTERDD p.1573: "Elements that have been stored will
// have their mask elements set to zero"); the VPSCATTERQQ Operation omits
// its "k1[j] := 0", which the description and the other forms have.
// Writes in order from the LSB are one of those the SDM allows ("Only
// writes to overlapping vector indices are guaranteed to be ordered with
// respect to each other (from LSB to MSB of the source registers) ...
// Writes that are not overlapped may happen in any order"); the model does
// not skip the "earlier" of two writes that completely overlap, which "may
// be skipped".  k1[MAX_KL-1:KL] is cleared at the end.
val exec_scatter : forall 'vl 'iw 'ew, 'vl in {128, 256, 512} & 'iw in {32, 64} & 'ew in {32, 64}.
  (implicit('vl), int('iw), int('ew), simd_idx, VSIB, kreg_idx) -> unit
function exec_scatter(vl, iw, ew, src, vsib, k_idx) = {
  let data : bits(512) = ZMM[src];
  let indices : bits(512) = ZMM[vsib.vsib_vidx];
  let n = vl / (if iw >= ew then iw else ew);
  let hits = pending_dbp;
  var k : qword = read_kreg(k_idx);
  var stopped : bool = false;
  foreach (i from 0 to (n - 1)) {
    if ~(stopped) & k[i] == bitone then {
      let idx : bits('iw) = (indices >> (i * iw))[iw - 1 .. 0];
      let v : bits('ew) = (data >> (i * ew))[ew - 1 .. 0];
      if vsib_write(ew, gather_addr(vsib, idx), v, hits) then {
        k[i] = bitzero;
        write_kreg(k_idx, k)
      } else stopped = true
    }
  };
  if ~(stopped) then write_kreg(k_idx, zeros())
}

/* ---- VPMADD52LUQ / VPMADD52HUQ: 52-bit multiply-add ---- */

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

// EVEX scalar FMA: decode modrm, handle embedded rounding, dispatch.
// The low element is written under the writemask: if k1[0] is clear it
// keeps its value (merging) or becomes zero (zeroing); bits 127:eb are
// DEST's (SDM VFMADD132SS etc., EVEX operation).
val evex_fma_scalar_elem : forall 'eb, 'eb in {32, 64}.
  (PackedTernaryOp, FMAOrder, bits('eb), bits('eb), bits('eb)) -> bits('eb)
function evex_fma_scalar_elem(op, order, d, src2, src3) = match order {
  FMA_132 => packed_ternary_elem(op, d, src3, src2),
  FMA_213 => packed_ternary_elem(op, src2, d, src3),
  FMA_231 => packed_ternary_elem(op, src2, src3, d),
}

val evex_exec_fma_scalar : (PackedTernaryOp, FMAOrder, Prefixes) -> unit
function evex_exec_fma_scalar(op, order, pfx) = {
  let modrm = fetch(1);
  let dst = evex_reg_idx(modrm, pfx);
  let src = modrm_xrm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
  let (_, saved_mxcsr) = evex_begin_rc_xrm(pfx, src);
  let src2 : xmmword = read_simd(pfx.evex_vvvvv);
  let d : xmmword = read_simd(dst);
  if pfx.rex_w then {
    let r = evex_fma_scalar_elem(op, order, d[63..0], src2[63..0], decode_scalar_src(64, src));
    evex_write_scalar(dst, d[127..64] @ r, pfx, 64)
  } else {
    let r = evex_fma_scalar_elem(op, order, d[31..0], src2[31..0], decode_scalar_src(32, src));
    evex_write_scalar(dst, d[127..32] @ r, pfx, 32)
  };
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

// EVEX packed FMADDSUB/FMSUBADD
val evex_exec_fmaddsub_packed : (bool, FMAOrder, Prefixes) -> unit
function evex_exec_fmaddsub_packed(is_addsub, order, pfx) = {
  let modrm = fetch(1);
  let dst = evex_reg_idx(modrm, pfx);
  let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
  let (eff_ll, saved) = evex_begin_rc_xrm(pfx, src);
  let vl = ll_to_vl(eff_ll);
  let eb = evex_elem(pfx);
  let d = read_simd(vl, dst);
  let v = read_simd(vl, pfx.evex_vvvvv);
  let r = evex_bcast_src(vl, src, pfx, eb);
  let mask = evex_wmask(pfx, vl / eb);
  match order {
    FMA_132 => evex_write(dst, mask, if is_addsub then avx_fmaddsub(eb, d, r, v) else avx_fmsubadd(eb, d, r, v)),
    FMA_213 => evex_write(dst, mask, if is_addsub then avx_fmaddsub(eb, v, d, r) else avx_fmsubadd(eb, v, d, r)),
    FMA_231 => evex_write(dst, mask, if is_addsub then avx_fmaddsub(eb, v, r, d) else avx_fmsubadd(eb, v, r, d)),
  };
  evex_end_rc(saved)
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
    let eb = evex_elem(pfx);
    exec_gather(vl, idx_eb, eb, dst, vsib, pfx.evex_aaa)
  },

  // =====================================================================
  // FMA 132 forms (0x96-0x9F)
  // =====================================================================

  // 0F38 96: VFMADDSUB132PS (66,W0) / VFMADDSUB132PD (66,W1) [F]
  150 => { if mp != MP_66 then raise_UD(); evex_exec_fmaddsub_packed(true, FMA_132, pfx) },

  // 0F38 97: VFMSUBADD132PS (66,W0) / VFMSUBADD132PD (66,W1) [F]
  151 => { if mp != MP_66 then raise_UD(); evex_exec_fmaddsub_packed(false, FMA_132, pfx) },

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
  166 => { if mp != MP_66 then raise_UD(); evex_exec_fmaddsub_packed(true, FMA_213, pfx) },

  // 0F38 A7: VFMSUBADD213PS (66,W0) / VFMSUBADD213PD (66,W1) [F]
  167 => { if mp != MP_66 then raise_UD(); evex_exec_fmaddsub_packed(false, FMA_213, pfx) },

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
  182 => { if mp != MP_66 then raise_UD(); evex_exec_fmaddsub_packed(true, FMA_231, pfx) },

  // 0F38 B7: VFMSUBADD231PS (66,W0) / VFMSUBADD231PD (66,W1) [F]
  183 => { if mp != MP_66 then raise_UD(); evex_exec_fmaddsub_packed(false, FMA_231, pfx) },

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
    let src2 = evex_scalar_xsrc(src, evex_elem(pfx));
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
    let src2 = evex_scalar_xsrc(src, evex_elem(pfx));
    // VGETEXPSD xmm1, xmm2, xmm3/m64 / VGETEXPSS xmm1, xmm2, xmm3/m32
    if pfx.rex_w then evex_write_scalar(dst, src1[127..64] @ fp_getexp(src2[63..0]), pfx, 64)
    else evex_write_scalar(dst, src1[127..32] @ fp_getexp(src2[31..0]), pfx, 32);
    evex_end_rc(saved_mxcsr)
  },

  // 0F38 4C: VRCP14PS (66,W0) / VRCP14PD (66,W1) [F]
  76 => { if mp != MP_66 then raise_UD(); evex_exec_unop_bcast(PU_FPRcp14, evex_elem(pfx), pfx) },

  // 0F38 4D: VRCP14SS (66,W0) / VRCP14SD (66,W1) [T1S]
  77 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
    let src1 : xmmword = read_simd(pfx.evex_vvvvv);
    let src2 = evex_scalar_xsrc(src, evex_elem(pfx));
    // VRCP14SD xmm1, xmm2, xmm3/m64 / VRCP14SS xmm1, xmm2, xmm3/m32
    if pfx.rex_w then evex_write_scalar(dst, src1[127..64] @ fp_rcp14(src2[63..0]), pfx, 64)
    else evex_write_scalar(dst, src1[127..32] @ fp_rcp14(src2[31..0]), pfx, 32)
  },

  // 0F38 4E: VRSQRT14PS (66,W0) / VRSQRT14PD (66,W1) [F]
  78 => { if mp != MP_66 then raise_UD(); evex_exec_unop_bcast(PU_FPRsqrt14, evex_elem(pfx), pfx) },

  // 0F38 4F: VRSQRT14SS (66,W0) / VRSQRT14SD (66,W1) [T1S]
  79 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
    let src1 : xmmword = read_simd(pfx.evex_vvvvv);
    let src2 = evex_scalar_xsrc(src, evex_elem(pfx));
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
    let src2 = evex_scalar_xsrc(src, evex_elem(pfx));
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
    let src2 = evex_scalar_xsrc(src, evex_elem(pfx));
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

  // 0F38 DC-DF: VAESENC/VAESENCLAST/VAESDEC/VAESDECLAST (66) [VAES]
  // One AES round per 128-bit lane.  The instructions have no opmask
  // operand, so EVEX.aaa must be 000b and hence EVEX.z must be 0 (SDM
  // Vol.2A Table 2-42; APM Vol.4 §3.2.4 and the VAESENC row "62 RXBR'.2
  // x.vvvv.01 0.00.0.V'.000 DC /r"), which evex_check_form raises (K_NONE
  // forms); the result is written unmasked.
  op if 220 <= op & op <= 223 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    write_simd(vl, dst, avx_aes_round(aes_round_of_opcode(op), read_simd(vl, pfx.evex_vvvvv), evex_src(vl, src)))
  },

  _ => raise_UD(),
  }
}

// x86-64 — EVEX Integer Operations (0F map)
//
// Packed integer arithmetic, logic, pack/unpack, shift, and compare.
// Called from dispatch_evex_0f in insn_evex_dispatch.sail.

// AVX-512 writemask helpers
//
// Per SDM: if aaa=0 (k0), no masking (all elements written).
// Otherwise, each bit of the mask register controls one element.
// z=0: merging (unmasked elements keep old dest value)
// z=1: zeroing (unmasked elements become zero)

// Apply 16-bit writemask to a 512-bit ZMM result (32-bit elements, 16 lanes).
// mask_val is the low 16 bits of the mask register.
// old_dst is the previous destination value (for merging).

// Polymorphic compare-to-mask helpers for EVEX compare instructions.
// Each compares 'vl/'eb elements and produces a qword mask (one bit per element).
val avx_pcmpeq_mask : forall 'vl 'eb, 'vl in {128, 256, 512} & 'eb in {8, 16, 32, 64}.
  (int('eb), bits('vl), bits('vl)) -> qword
function avx_pcmpeq_mask(eb, a, b) = {
  var r : qword = zeros();
  foreach (i from 0 to ('vl / 'eb - 1)) {
    r[i] = is_eq(velem('eb, a, i), velem('eb, b, i))
  };
  r
}

val avx_pcmpgt_mask : forall 'vl 'eb, 'vl in {128, 256, 512} & 'eb in {8, 16, 32, 64}.
  (int('eb), bits('vl), bits('vl)) -> qword
function avx_pcmpgt_mask(eb, a, b) = {
  var r : qword = zeros();
  foreach (i from 0 to ('vl / 'eb - 1)) {
    r[i] = is_gt(velem('eb, a, i), velem('eb, b, i))
  };
  r
}

// EVEX integer compare → kmask helpers
enum CmpOp = { CMP_EQ, CMP_GT }

val evex_exec_cmp_mask : (CmpOp, {8, 16}, Prefixes) -> unit
function evex_exec_cmp_mask(cmp, eb, pfx) = {
  let modrm = fetch(1);
  let dst_k : range(0, 7) = unsigned(modrm[5..3]);
  let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
  let vl = evex_vl(pfx);
  let a = read_simd(vl, pfx.evex_vvvvv);
  let b = evex_src(vl, src);
  let k : qword = if cmp == CMP_EQ then avx_pcmpeq_mask(eb, a, b) else avx_pcmpgt_mask(eb, a, b);
  write_kreg(dst_k, k & evex_kmask64(pfx))
}

val evex_exec_cmp_mask_bcast : (CmpOp, {32, 64}, Prefixes) -> unit
function evex_exec_cmp_mask_bcast(cmp, eb, pfx) = {
  let modrm = fetch(1);
  let dst_k : range(0, 7) = unsigned(modrm[5..3]);
  let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
  let vl = evex_vl(pfx);
  let a = read_simd(vl, pfx.evex_vvvvv);
  let b = evex_bcast_src(vl, src, pfx, eb);
  let k : qword = if cmp == CMP_EQ then avx_pcmpeq_mask(eb, a, b) else avx_pcmpgt_mask(eb, a, b);
  write_kreg(dst_k, k & evex_kmask64(pfx))
}

// VPSLLDQ: byte shift left per 128-bit lane
val avx_pslldq_lane : (xmmword, range(0, 255)) -> xmmword
function avx_pslldq_lane(a, count) = a << (count * 8)

val avx_pslldq : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), range(0, 255)) -> bits('vl)
function avx_pslldq(vl, a, count) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) {
    let lo = i * 128;
    r[(lo + 127)..lo] = avx_pslldq_lane(velem(128, a, i), count)
  };
  r
}

// VPSRLDQ: byte shift right per 128-bit lane
val avx_psrldq_lane : (xmmword, range(0, 255)) -> xmmword
function avx_psrldq_lane(a, count) = a >> (count * 8)

val avx_psrldq : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), range(0, 255)) -> bits('vl)
function avx_psrldq(vl, a, count) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) {
    let lo = i * 128;
    r[(lo + 127)..lo] = avx_psrldq_lane(velem(128, a, i), count)
  };
  r
}

// Packed rotate: rotate each element left or right by a scalar count.
enum RotateDir = { ROT_Left, ROT_Right }

val packed_rotate : forall 'vl 'eb, 'vl in {128, 256, 512} & 'eb in {32, 64}.
  (RotateDir, int('eb), bits('vl), range(0, 255)) -> bits('vl)
function packed_rotate(dir, eb, src, count) = {
  var r : bits('vl) = zeros();
  let c_bv : bits(8) = to_bits(8, count);
  let mask : bits(8) = to_bits_truncate(eb - 1);
  let c : bits(8) = c_bv & mask;
  let rc : bits(8) = (to_bits_truncate(eb) - c) & mask;
  foreach (i from 0 to ('vl / 'eb - 1)) {
    let lo = i * 'eb;
    let elem = velem('eb, src, i);
    r[(lo + 'eb - 1)..lo] = match dir {
      ROT_Left  => (elem << c) | (elem >> rc),
      ROT_Right => (elem >> c) | (elem << rc),
    }
  };
  r
}

// Clamp a 64-bit shift count to range(0, 255), saturating at 255.
val clamp_shift_bv64 : bits(64) -> range(0, 255)
function clamp_shift_bv64(raw) =
  unsigned(raw[7..0] | sign_extend(is_nonzero(raw[63..8])))

// EVEX shift-by-xmm: count comes from low 64 bits of second source XMM.
val evex_exec_shift_xmm : (PackedShiftOp, {16, 32, 64}, Prefixes) -> unit
function evex_exec_shift_xmm(op, eb, pfx) = {
  let modrm = fetch(1);
  let dst = evex_reg_idx(modrm, pfx);
  let src = modrm_xrm_evex(modrm, pfx, 16);
  let count_xmm : xmmword = evex_src(128, src);
  let count = clamp_shift_bv64(count_xmm[63..0]);
  let vl = evex_vl(pfx);
  let nm : range(2, 32) = vl / eb; assert(nm == 2 | nm == 4 | nm == 8 | nm == 16 | nm == 32);
  evex_write(dst, evex_wmask(pfx, nm), packed_uniform_shift(op, eb, read_simd(vl, pfx.evex_vvvvv), count))
}

// EVEX unpack helpers (VPUNPCKL/H BW/WD/DQ/QDQ)
val evex_exec_unpack : ({8, 16}, {0, 64}, Prefixes) -> unit
function evex_exec_unpack(eb, half, pfx) = {
  let modrm = fetch(1);
  let dst = evex_reg_idx(modrm, pfx);
  let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
  let vl = evex_vl(pfx);
  let nm : range(8, 64) = vl / eb; assert(nm == 8 | nm == 16 | nm == 32 | nm == 64);
  evex_write(dst, evex_wmask(pfx, nm), packed_unpack(eb, half, read_simd(vl, pfx.evex_vvvvv), evex_src(vl, src)))
}

val evex_exec_unpack_bcast : ({32, 64}, {0, 64}, Prefixes) -> unit
function evex_exec_unpack_bcast(eb, half, pfx) = {
  let modrm = fetch(1);
  let dst = evex_reg_idx(modrm, pfx);
  let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
  let vl = evex_vl(pfx);
  let nm : range(2, 16) = vl / eb; assert(nm == 2 | nm == 4 | nm == 8 | nm == 16);
  evex_write(dst, evex_wmask(pfx, nm), packed_unpack(eb, half, read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(src, pfx, eb)))
}

val dispatch_evex_int : (range(0, 255), Prefixes) -> unit
function dispatch_evex_int(op, pfx) = {
  let mp = get_mandatory_prefix(pfx);

  match op {
  // 0F 6F: VMOVDQA32/64 (66), VMOVDQU32/64 (F3), VMOVDQU8/16 (F2)
  111 => {
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let mp = get_mandatory_prefix(pfx);
    let vl = evex_vl(pfx);
    let s = evex_src(vl, src);
    // Element size depends on prefix: F2→byte/word, others→dword/qword
    match mp {
      MP_F2 => if pfx.rex_w
               then evex_write(dst, evex_wmask(pfx, vl / 16), s)
               else evex_write(dst, evex_wmask(pfx, vl / 8), s),
      _     => { let eb = evex_elem(pfx);
                 evex_write(dst, evex_wmask(pfx, vl / eb), s) },
    }
  },

  // 0F 7F: VMOVDQA32/VMOVDQA64/VMOVDQU32/VMOVDQU64 (EVEX store)
  127 => {
    let modrm = fetch(1);
    let src = evex_reg_idx(modrm, pfx);
    let dest = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    match dest {
      XRM_reg(xi) => {
        let eb = evex_elem(pfx);
        let vl = evex_vl(pfx);
        let nm : range(2, 16) = vl / eb; assert(nm == 2 | nm == 4 | nm == 8 | nm == 16);
        evex_write(xi, evex_wmask(pfx, nm), read_simd(vl, src))
      },
      XRM_mem(m) => {
        let mask : qword = evex_kmask64(pfx);
        let elem_size : {1, 2, 4, 8} =
          if pfx.has_repne then (if pfx.rex_w then 2 else 1)
          else (if pfx.rex_w then 8 else 4);
        let nbytes : {16, 32, 64} = match pfx.evex_ll { 0 => 16, 1 => 32, 2 => 64 , 3 => { raise_UD(); 16 } };
        evex_masked_mem_store(m, ZMM[src], mask, nbytes, elem_size)
      },
    }
  },

  // 0F DB: VPANDD/Q (66) / 0F EB: VPORD/Q (66) / 0F EF: VPXORD/Q (66)
  219 => { if mp != MP_66 then raise_UD(); evex_exec_binop_bcast(PB_And, evex_elem(pfx), pfx) },
  235 => { if mp != MP_66 then raise_UD(); evex_exec_binop_bcast(PB_Or,  evex_elem(pfx), pfx) },
  239 => { if mp != MP_66 then raise_UD(); evex_exec_binop_bcast(PB_Xor, evex_elem(pfx), pfx) },

  // 0F FE: VPADDD (EVEX, 66 prefix, W0)
  254 => { if mp != MP_66 then raise_UD(); evex_exec_binop_bcast(PB_Add, 32, pfx) },
  // 0F FA: VPSUBD (EVEX, 66 prefix, W0)
  250 => { if mp != MP_66 then raise_UD(); evex_exec_binop_bcast(PB_Sub, 32, pfx) },
  // 0F D4: VPADDQ (EVEX, 66 prefix, W1)
  212 => { if mp != MP_66 then raise_UD(); evex_exec_binop_bcast(PB_Add, 64, pfx) },
  // 0F FB: VPSUBQ (EVEX, 66 prefix, W1)
  251 => { if mp != MP_66 then raise_UD(); evex_exec_binop_bcast(PB_Sub, 64, pfx) },

  // 0F 6E: VMOVD (66, W=0) / VMOVQ (66, W=1) — load from GPR/mem to XMM
  110 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
    match (src, pfx.rex_w) {
      (RM_reg(r), true)   => evex_write(dst, evex_wmask(pfx, 8), zero_extend(v(64, r)) : zmmword),
      (RM_mem(m), true)   => evex_write(dst, evex_wmask(pfx, 8), zero_extend(v(64, m)) : zmmword),
      (RM_reg(r), false)  => evex_write(dst, evex_wmask(pfx, 16), zero_extend(v(32, r)) : zmmword),
      (RM_mem(m), false)  => evex_write(dst, evex_wmask(pfx, 16), zero_extend(v(32, m)) : zmmword),
    }
  },

  // 0F 74: VPCMPEQB → kmask (66, EVEX)
  116 => { if mp != MP_66 then raise_UD(); evex_exec_cmp_mask(CMP_EQ,  8, pfx) },
  // 0F 76: VPCMPEQD → kmask (66, EVEX, W0) — supports m32bcst
  118 => { if mp != MP_66 then raise_UD(); evex_exec_cmp_mask_bcast(CMP_EQ, 32, pfx) },

  // 0F 7E: VMOVD (66, W=0) / VMOVQ (66, W=1) — store from XMM to GPR/mem
  126 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let src = evex_reg_idx(modrm, pfx);
    let dest = modrm_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
    let src_xmm : xmmword = read_simd(src);
    match (dest, pfx.rex_w) {
      (RM_reg(r), true) => v(r) = src_xmm[63..0],
      (RM_mem(m), true)   => v(m) = src_xmm[63..0],
      (RM_reg(r), false) => v(r) = src_xmm[31..0],
      (RM_mem(m), false)  => v(m) = src_xmm[31..0],
    }
  },

  // 0F DA: VPMINUB (66, EVEX)
  218 => { if mp != MP_66 then raise_UD(); evex_exec_binop(PB_MinU, 8, pfx) },

  // 0F E7: VMOVNTDQ (66, EVEX) — non-temporal store (we just do a regular store)
  231 => {
    if mp != MP_66 then raise_UD();
    let (src, dest) = fetch_modrm_evex(pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    match dest {
      XRM_mem(m) => write_mem(seg_linear(m, 64), read_simd(vl, src)),
      _ => raise_UD(),
    }
  },

  // 0F F8: VPSUBB (66, EVEX)
  248 => { if mp != MP_66 then raise_UD(); evex_exec_binop(PB_Sub, 8, pfx) },
  // 0F FC: VPADDB (66, EVEX)
  252 => { if mp != MP_66 then raise_UD(); evex_exec_binop(PB_Add, 8, pfx) },

  // 0F DF: VPANDND (66,W0) / VPANDNQ (66,W1)
  223 => { if mp != MP_66 then raise_UD(); evex_exec_binop_bcast(PB_Andn, evex_elem(pfx), pfx) },

  // 0F FD: VPADDW (66, EVEX) [BW]
  253 => { if mp != MP_66 then raise_UD(); evex_exec_binop(PB_Add, 16, pfx) },
  // 0F F9: VPSUBW (66, EVEX) [BW]
  249 => { if mp != MP_66 then raise_UD(); evex_exec_binop(PB_Sub, 16, pfx) },
  // 0F EC-ED: VPADDSB/W (66, EVEX) [BW]
  236 => { if mp != MP_66 then raise_UD(); evex_exec_binop(PB_SatAddS,  8, pfx) },
  237 => { if mp != MP_66 then raise_UD(); evex_exec_binop(PB_SatAddS, 16, pfx) },
  // 0F E8-E9: VPSUBSB/W (66, EVEX) [BW]
  232 => { if mp != MP_66 then raise_UD(); evex_exec_binop(PB_SatSubS,  8, pfx) },
  233 => { if mp != MP_66 then raise_UD(); evex_exec_binop(PB_SatSubS, 16, pfx) },
  // 0F DC-DD: VPADDUSB/W (66, EVEX) [BW]
  220 => { if mp != MP_66 then raise_UD(); evex_exec_binop(PB_SatAddU,  8, pfx) },
  221 => { if mp != MP_66 then raise_UD(); evex_exec_binop(PB_SatAddU, 16, pfx) },
  // 0F D8-D9: VPSUBUSB/W (66, EVEX) [BW]
  216 => { if mp != MP_66 then raise_UD(); evex_exec_binop(PB_SatSubU,  8, pfx) },
  217 => { if mp != MP_66 then raise_UD(); evex_exec_binop(PB_SatSubU, 16, pfx) },
  // 0F D5: VPMULLW (66, EVEX) [BW]
  213 => { if mp != MP_66 then raise_UD(); evex_exec_binop(PB_MulLow, 16, pfx) },
  // 0F E4: VPMULHUW (66, EVEX) [BW]
  228 => { if mp != MP_66 then raise_UD(); evex_exec_binop(PB_MulHighU, 16, pfx) },
  // 0F E5: VPMULHW (66, EVEX) [BW]
  229 => { if mp != MP_66 then raise_UD(); evex_exec_binop(PB_MulHighS, 16, pfx) },
  // 0F DE: VPMAXUB (66, EVEX) [BW]
  222 => { if mp != MP_66 then raise_UD(); evex_exec_binop(PB_MaxU, 8, pfx) },
  // 0F EA: VPMINSW (66, EVEX) [BW]
  234 => { if mp != MP_66 then raise_UD(); evex_exec_binop(PB_MinS, 16, pfx) },
  // 0F EE: VPMAXSW (66, EVEX) [BW]
  238 => { if mp != MP_66 then raise_UD(); evex_exec_binop(PB_MaxS, 16, pfx) },
  // 0F E0: VPAVGB (66, EVEX) [BW]
  224 => { if mp != MP_66 then raise_UD(); evex_exec_binop(PB_Avg, 8, pfx) },
  // 0F E3: VPAVGW (66, EVEX) [BW]
  227 => { if mp != MP_66 then raise_UD(); evex_exec_binop(PB_Avg, 16, pfx) },
  // 0F F4: VPMULUDQ (66, EVEX, W1) [F] — supports m64bcst
  244 => { if mp != MP_66 then raise_UD(); evex_exec_binop_bcast(PB_Pmuludq, 64, pfx) },
  // 0F F5: VPMADDWD (66, EVEX) [BW]
  245 => { if mp != MP_66 then raise_UD(); evex_exec_binop(PB_Pmaddwd, 32, pfx) },
  // 0F F6: VPSADBW (66, EVEX) [BW] — no writemask
  246 => { if mp != MP_66 then raise_UD(); evex_exec_binop(PB_Psadbw, 64, pfx) },

  // 0F 64: VPCMPGTB → kmask (66, EVEX) [BW]
  100 => { if mp != MP_66 then raise_UD(); evex_exec_cmp_mask(CMP_GT,  8, pfx) },
  // 0F 65: VPCMPGTW → kmask (66, EVEX) [BW]
  101 => { if mp != MP_66 then raise_UD(); evex_exec_cmp_mask(CMP_GT, 16, pfx) },
  // 0F 66: VPCMPGTD → kmask (66, EVEX, W0) [F] — supports m32bcst
  102 => { if mp != MP_66 then raise_UD(); evex_exec_cmp_mask_bcast(CMP_GT, 32, pfx) },
  // 0F 75: VPCMPEQW → kmask (66, EVEX) [BW]
  117 => { if mp != MP_66 then raise_UD(); evex_exec_cmp_mask(CMP_EQ, 16, pfx) },

  // 0F 60: VPUNPCKLBW (66, EVEX) [BW]
  96 => { if mp != MP_66 then raise_UD(); evex_exec_unpack( 8, 0, pfx) },
  // 0F 61: VPUNPCKLWD (66, EVEX) [BW]
  97 => { if mp != MP_66 then raise_UD(); evex_exec_unpack(16, 0, pfx) },
  // 0F 62: VPUNPCKLDQ (66, EVEX, W0) [F] — supports m32bcst
  98 => { if mp != MP_66 then raise_UD(); evex_exec_unpack_bcast(32, 0, pfx) },
  // 0F 68: VPUNPCKHBW (66, EVEX) [BW]
  104 => { if mp != MP_66 then raise_UD(); evex_exec_unpack( 8, 64, pfx) },
  // 0F 69: VPUNPCKHWD (66, EVEX) [BW]
  105 => { if mp != MP_66 then raise_UD(); evex_exec_unpack(16, 64, pfx) },
  // 0F 6A: VPUNPCKHDQ (66, EVEX, W0) [F] — supports m32bcst
  106 => { if mp != MP_66 then raise_UD(); evex_exec_unpack_bcast(32, 64, pfx) },
  // 0F 6C: VPUNPCKLQDQ (66, EVEX, W1) [F] — supports m64bcst
  108 => { if mp != MP_66 then raise_UD(); evex_exec_unpack_bcast(64, 0, pfx) },
  // 0F 6D: VPUNPCKHQDQ (66, EVEX, W1) [F] — supports m64bcst
  109 => { if mp != MP_66 then raise_UD(); evex_exec_unpack_bcast(64, 64, pfx) },

  // 0F 63: VPACKSSWB (66, EVEX) [BW]
  99 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    evex_write(dst, evex_wmask(pfx, vl / 8), packed_pack(PN_SatS, 16, 8, read_simd(vl, pfx.evex_vvvvv), evex_src(vl, src)))
  },

  // 0F 67: VPACKUSWB (66, EVEX) [BW]
  103 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    evex_write(dst, evex_wmask(pfx, vl / 8), packed_pack(PN_SatSU, 16, 8, read_simd(vl, pfx.evex_vvvvv), evex_src(vl, src)))
  },

  // 0F 6B: VPACKSSDW (66, EVEX, W0) [BW] — supports m32bcst
  107 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    evex_write(dst, evex_wmask(pfx, vl / 16), packed_pack(PN_SatS, 32, 16, read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(vl, src, pfx, 32)))
  },

  // 0F 70: VPSHUFD (66, W0, m32bcst) / VPSHUFHW (F3) / VPSHUFLW (F2)
  112 => {
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let imm = fetch(1);
    let vl = evex_vl(pfx);
    match mp {
      MP_66 => evex_write(dst, evex_wmask(pfx, vl / 32), packed_lane_imm_op(PLI_Pshufd, evex_bcast_src(vl, src, pfx, 32), imm)),
      MP_F3 => evex_write(dst, evex_wmask(pfx, vl / 16), packed_lane_imm_op(PLI_Pshufhw, evex_src(vl, src), imm)),
      MP_F2 => evex_write(dst, evex_wmask(pfx, vl / 16), packed_lane_imm_op(PLI_Pshuflw, evex_src(vl, src), imm)),
      _ => raise_UD(),
    }
  },

  // 0F 71: Group 12 — shift word by imm8 (66, EVEX)
  // /2=VPSRLW, /4=VPSRAW, /6=VPSLLW
  113 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let digit : range(0, 7) = unsigned(modrm[5..3]);
    let xi = xrm_reg(modrm_xrm_evex(modrm, pfx, 1));
    let dst = pfx.evex_vvvvv;
    let imm = fetch(1);
    let count : range(0, 255) = unsigned(imm);
    let vl = evex_vl(pfx);
    let nm : range(8, 32) = vl / 16; assert(nm == 8 | nm == 16 | nm == 32);
    let shift_op : PackedShiftOp = match digit {
      2 => PS_Srl, 4 => PS_Sra, 6 => PS_Sll,
      _ => { raise_UD(); PS_Srl },
    };
    evex_write(dst, evex_wmask(pfx, nm), packed_uniform_shift(shift_op, 16, read_simd(vl, xi), count))
  },

  // 0F 72: Group 13 — shift/rotate dword/qword by imm8 (66, EVEX)
  // /0=VPRORD(W0)/VPRORQ(W1), /1=VPROLD(W0)/VPROLQ(W1)
  // /2=VPSRLD(W0)/VPSRLQ(W1), /4=VPSRAD(W0)/VPSRAQ(W1), /6=VPSLLD(W0)/VPSLLQ(W1)
  114 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let digit : range(0, 7) = unsigned(modrm[5..3]);
    let xi = xrm_reg(modrm_xrm_evex(modrm, pfx, 1));
    let dst = pfx.evex_vvvvv;
    let imm = fetch(1);
    let count : range(0, 255) = unsigned(imm);
    let eb = evex_elem(pfx);
    let vl = evex_vl(pfx);
    let nm : range(2, 16) = vl / eb; assert(nm == 2 | nm == 4 | nm == 8 | nm == 16);
    let src = read_simd(vl, xi);
    match digit {
      0 => evex_write(dst, evex_wmask(pfx, nm), packed_rotate(ROT_Right, eb, src, count)),
      1 => evex_write(dst, evex_wmask(pfx, nm), packed_rotate(ROT_Left,  eb, src, count)),
      2 => evex_write(dst, evex_wmask(pfx, nm), packed_uniform_shift(PS_Srl, eb, src, count)),
      4 => evex_write(dst, evex_wmask(pfx, nm), packed_uniform_shift(PS_Sra, eb, src, count)),
      6 => evex_write(dst, evex_wmask(pfx, nm), packed_uniform_shift(PS_Sll, eb, src, count)),
      _ => raise_UD(),
    }
  },

  // 0F 73: Group 14 — shift qword/dq by imm8 (66, EVEX)
  // /2=VPSRLQ(W1), /3=VPSRLDQ, /6=VPSLLQ(W1), /7=VPSLLDQ
  115 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let digit : range(0, 7) = unsigned(modrm[5..3]);
    let xi = xrm_reg(modrm_xrm_evex(modrm, pfx, 1));
    let dst = pfx.evex_vvvvv;
    let imm = fetch(1);
    let count : range(0, 255) = unsigned(imm);
    let vl = evex_vl(pfx);
    let nm : range(2, 8) = vl / 64; assert(nm == 2 | nm == 4 | nm == 8);
    let src = read_simd(vl, xi);
    match digit {
      2 => evex_write(dst, evex_wmask(pfx, nm), packed_uniform_shift(PS_Srl, 64, src, count)),
      3 => evex_write(dst, evex_wmask(pfx, nm), avx_psrldq(src, count)),
      6 => evex_write(dst, evex_wmask(pfx, nm), packed_uniform_shift(PS_Sll, 64, src, count)),
      7 => evex_write(dst, evex_wmask(pfx, nm), avx_pslldq(src, count)),
      _ => raise_UD(),
    }
  },

  // 0F C4: VPINSRW (66) — insert word from r32/m16 into XMM [BW]
  196 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, 2);
    let src1 : xmmword = read_simd(pfx.evex_vvvvv);
    let word_val : bits(16) = match src {
      RM_reg(r) => v(32, r)[15..0],
      RM_mem(m) => v(m),
    };
    let imm = fetch(1);
    let sel : range(0, 7) = unsigned(imm[2..0]);
    var result = src1;
    let lo : range(0, 112) = sel * 16;
    result[(lo + 15)..lo] = word_val;
    evex_write(dst, evex_wmask(pfx, 8), result)
  },

  // 0F C5: VPEXTRW (66) — extract word from XMM to r32 [BW]
  197 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let xi = xrm_reg(modrm_xrm_evex(modrm, pfx, 1));
    let src_xmm : xmmword = read_simd(xi);
    let dst_gpr = modrm_reg(modrm, pfx);
    let imm = fetch(1);
    let word_val : bits(16) = velem(16, src_xmm, imm[2..0]);
    v(dst_gpr) = zero_extend(64, word_val)
  },

  // 0F D6: VMOVQ store (66,W1) — store low qword of XMM to XMM/m64
  214 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let src_xmm : xmmword = read_simd(evex_reg_idx(modrm, pfx));
    let dest = modrm_xrm_evex(modrm, pfx, 8);
    let qval : qword = src_xmm[63..0];
    match dest {
      XRM_reg(xi) => evex_write(xi, evex_wmask(pfx, 2), zero_extend(qval) : xmmword),
      XRM_mem(m) => v(m) = qval,
    }
  },

  // Shift by xmm count: VPSRLW/D/Q, VPSRAW/D/Q, VPSLLW/D/Q
  209 => { if mp != MP_66 then raise_UD(); evex_exec_shift_xmm(PS_Srl, 16, pfx) },
  210 => { if mp != MP_66 then raise_UD(); evex_exec_shift_xmm(PS_Srl, 32, pfx) },
  211 => { if mp != MP_66 then raise_UD(); evex_exec_shift_xmm(PS_Srl, 64, pfx) },
  225 => { if mp != MP_66 then raise_UD(); evex_exec_shift_xmm(PS_Sra, 16, pfx) },
  226 => { if mp != MP_66 then raise_UD(); evex_exec_shift_xmm(PS_Sra, evex_elem(pfx), pfx) },
  241 => { if mp != MP_66 then raise_UD(); evex_exec_shift_xmm(PS_Sll, 16, pfx) },
  242 => { if mp != MP_66 then raise_UD(); evex_exec_shift_xmm(PS_Sll, 32, pfx) },
  243 => { if mp != MP_66 then raise_UD(); evex_exec_shift_xmm(PS_Sll, 64, pfx) },

  _ => raise_UD(),
  }
}

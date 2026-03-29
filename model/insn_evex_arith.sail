// x86-64 — EVEX Arithmetic/Misc (0F38 map)
//
// Integer min/max/abs, multiply, variable shifts, narrowing/widening
// converts, VNNI, test-mask, and bit manipulation.
// Called from dispatch_evex_0f38 in insn_evex.sail.

// =========================================================================
// AVX-512 VPTESTM: test mask (element-wise AND → nonzero bit per element)
// =========================================================================

val avx_ptestm : forall 'vl 'eb, 'vl in {128, 256, 512} & 'eb in {8, 16, 32, 64}.
  (int('eb), bits('vl), bits('vl), bit) -> qword
function avx_ptestm(eb, a, b, neg) = {
  var r : qword = zeros();
  foreach (i from 0 to ('vl / 'eb - 1)) {
    let lo = i * 'eb;
    r[i] = is_nonzero(velem('eb, a, i) & velem('eb, b, i)) ^ neg;
  };
  r
}

// =========================================================================
// VPCMPUB: compare unsigned bytes with imm8 predicate, produce kmask
// imm8: 0=eq, 1=lt, 2=le, 4=neq, 5=nlt(>=), 6=nle(>)
// =========================================================================

// =========================================================================
// VPACKUSDW: pack dwords to words with unsigned saturation
// Per 128-bit lane: 4 dwords from src1 -> 4 words, 4 dwords from src2 -> 4 words
// Each signed dword is clamped to [0, 65535] before truncation
// =========================================================================

// =========================================================================
// VPERMI2/VPERMT2: 2-source permute using index vector
// vperm2_d: select dwords from combined (t1,t2) table using idx
// vperm2_q: select qwords from combined (t1,t2) table using idx
// =========================================================================

// All 18 VPMOV narrowing functions replaced by packed_narrow_unop(op, src_eb, dst_eb, src)
// in insn_vex.sail. See PackedNarrowOp enum: PN_Trunc, PN_SatU, PN_SatS.

// =====================================================================
// VPMOVM2: mask register -> vector (each bit -> all-ones or all-zeros element)
// =====================================================================

val avx_vpmovm2 : forall 'vl 'eb, 'vl in {128, 256, 512} & 'eb in {8, 16, 32, 64}.
  (implicit('vl), int('eb), qword) -> bits('vl)
function avx_vpmovm2(vl, eb, k) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 'eb - 1)) {
    let lo = i * 'eb;
    r[(lo + 'eb - 1)..lo] = sign_extend([k[i]]);
  };
  r
}

// =====================================================================
// VPMOV2M: vector -> mask (MSB of each element -> mask bit)
// =====================================================================

val avx_vpmov2m : forall 'vl 'eb, 'vl in {128, 256, 512} & 'eb in {8, 16, 32, 64}.
  (int('eb), bits('vl)) -> qword
function avx_vpmov2m(eb, src) = {
  var r : qword = zeros();
  foreach (i from 0 to ('vl / 'eb - 1)) {
    r[i] = src[(i + 1) * 'eb - 1];
  };
  r
}

/* ---- VPCONFLICTD/Q: conflict detection ---- */
// For each element i, produce a bitmask of preceding elements (j < i) that have the same value.
val avx_vpconflict : forall 'vl 'eb, 'vl in {128, 256, 512} & 'eb in {32, 64}.
  (int('eb), bits('vl)) -> bits('vl)
function avx_vpconflict(eb, src) = {
  var result : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 'eb - 1)) {
    let ilo = i * 'eb;
    let elem_i = src[(ilo + 'eb - 1)..ilo];
    var mask : bits('eb) = zeros();
    foreach (j from 0 to ('vl / 'eb - 1)) {
      if j < i then {
        let jlo = j * 'eb;
        mask[j] = is_eq(elem_i, src[(jlo + 'eb - 1)..jlo]);
      }
    };
    result[(ilo + 'eb - 1)..ilo] = mask;
  };
  result
}

/* ---- VFPCLASS: classify FP value ---- */
// Returns true if any of the imm8-selected classes match:
// bit 0: QNaN, bit 1: +0, bit 2: -0, bit 3: +Inf, bit 4: -Inf
// bit 5: denormal, bit 6: negative finite, bit 7: SNaN

/* ---- BF16: convert FP32 to BFloat16 ---- */
// Per SDM: RNE, denormals flush to zero, NaN→QNaN, infinity preserved.
// This is pure integer arithmetic — no FPU involved.
val convert_fp32_to_bf16 : dword -> word
function convert_fp32_to_bf16(x) = {
  let exp : byte = x[30..23];
  let mant : bits(23) = x[22..0];
  let exp_zero : bit = is_zero(exp);
  let exp_all  : bit = is_zero(~(exp));
  let mant_nz  : bit = is_nonzero(mant);
  // Compute all four cases unconditionally
  let r_zero   : word = x[31] @ zeros(15);                   // zero/denormal → signed zero
  let r_nan    : word = x[31..16] | 0x0040;                  // NaN → force QNaN
  let r_inf    : word = x[31..16];                            // infinity → preserve
  let r_normal : word = (x + 0x00007FFF + zero_extend(x[16]))[31..16]; // normal → RNE
  // Select by classification: start with normal, override special cases
  let r1 : word = blend(r_normal, r_zero, exp_zero);
  let r2 : word = blend(r1, r_inf, exp_all & ~(mant_nz));
  blend(r2, r_nan, exp_all & mant_nz)
}

/* ---- VCVTNEPS2BF16: convert packed FP32 → packed BF16 (narrowing) ---- */
val avx_vcvtneps2bf16 : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl)) -> bits(div('vl, 2))
function avx_vcvtneps2bf16(vl, src) = {
  var r : bits(div('vl, 2)) = zeros();
  foreach (i from 0 to ('vl / 32 - 1)) {
    let slo = i * 32;
    let dlo = i * 16;
    r[(dlo + 15)..dlo] = convert_fp32_to_bf16(src[(slo + 31)..slo]);
  };
  r
}

/* ---- VCVTNE2PS2BF16: convert two packed FP32 → packed BF16 ---- */
// Upper half of result = narrowed src1 (vvvv), lower half = narrowed src2 (rm)
val avx_vcvtne2ps2bf16 : forall 'vl, 'vl in {128, 256, 512}. (bits('vl), bits('vl)) -> bits('vl)
function avx_vcvtne2ps2bf16(src1, src2) = {
  let n = 'vl / 32;  // number of dwords per source
  var r : bits('vl) = zeros();
  // Lower half: convert src2 dwords to BF16
  foreach (i from 0 to (n - 1)) {
    r[(i * 16 + 15)..(i * 16)] = convert_fp32_to_bf16(src2[(i * 32 + 31)..(i * 32)]);
  };
  // Upper half: convert src1 dwords to BF16
  foreach (i from 0 to (n - 1)) {
    let dlo = n * 16 + i * 16;
    r[(dlo + 15)..dlo] = convert_fp32_to_bf16(src1[(i * 32 + 31)..(i * 32)]);
  };
  r
}

/* ---- VDPBF16PS: BF16 dot product accumulating to FP32 ---- */
// Per dword: dest += make_fp32(src1.bf16[hi]) * make_fp32(src2.bf16[hi])
//                  + make_fp32(src1.bf16[lo]) * make_fp32(src2.bf16[lo])
val avx_vdpbf16ps : forall 'vl, 'vl in {128, 256, 512}. (bits('vl), bits('vl), bits('vl)) -> bits('vl)
function avx_vdpbf16ps(dst, src1, src2) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 32 - 1)) {
    let lo = i * 32;
    r[(lo + 31)..lo] = __vdpbf16ps_elem(velem(32, dst, i), velem(32, src1, i), velem(32, src2, i));
  };
  r
}


val avx_vpmultishiftqb_lane : (qword, qword) -> qword
function avx_vpmultishiftqb_lane(ctrl, src) = {
  var r : qword = zeros();
  foreach (i from 0 to 7) {
    let lo = i * 8;
    let shift : nat = unsigned(velem(8, ctrl, i)[5..0]);
    // Extract 8 bits starting at 'shift' from src (wrapping within 64 bits)
    var byte_val : byte = zeros();
    foreach (b from 0 to 7) {
      let bit_pos : range(0, 63) = (shift + b) % 64;
      byte_val[b] = src[bit_pos];
    };
    r[(lo + 7)..lo] = byte_val;
  };
  r
}

val avx_vpmultishiftqb : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), bits('vl)) -> bits('vl)
function avx_vpmultishiftqb(vl, ctrl, src) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 64 - 1)) {
    let lo = i * 64;
    r[(lo + 63)..lo] = avx_vpmultishiftqb_lane(velem(64, ctrl, i), velem(64, src, i))
  };
  r
}

val dispatch_evex_arith : (range(0, 255), Prefixes) -> unit
function dispatch_evex_arith(op, pfx) = {
  let mp = get_mandatory_prefix(pfx);

  match op {
  // 0F38 26: VPTESTMB (66, W=0) / VPTESTMW (66, W=1) / VPTESTNMB (F3, W=0) / VPTESTNMW (F3, W=1)
  38 => {
    let modrm = fetch(1);
    let dst_k : range(0, 7) = unsigned(modrm[5..3]);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    if mp != MP_66 & mp != MP_F3 then raise_UD();
    let neg_bit : bit = bool_to_bit(mp == MP_F3);
    let eb : {8, 16} = if pfx.rex_w then 16 else 8;
    let vl = evex_vl(pfx);
    let src1 = read_simd(vl, pfx.evex_vvvvv);
    let src2 = evex_src(vl, src);
    let k_mask : qword = avx_ptestm(eb, src1, src2, neg_bit) & evex_kmask64(pfx);
    write_kreg(dst_k, k_mask)
  },

  // 0F38 27: VPTESTMD (66, W=0) / VPTESTMQ (66, W=1) / VPTESTNMD (F3, W=0) / VPTESTNMQ (F3, W=1)
  39 => {
    let modrm = fetch(1);
    let dst_k : range(0, 7) = unsigned(modrm[5..3]);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    if mp != MP_66 & mp != MP_F3 then raise_UD();
    let neg_bit : bit = bool_to_bit(mp == MP_F3);
    let eb = evex_elem(pfx);
    let vl = evex_vl(pfx);
    let k_mask : qword = avx_ptestm(eb, read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(src, pfx, eb), neg_bit) & evex_kmask64(pfx);
    write_kreg(dst_k, k_mask)
  },

  // 0F38 29: VPCMPEQQ (66,W1) [F] / VPMOVB2M (F3,W0) / VPMOVW2M (F3,W1) [BW]
  41 => {
    if mp == MP_F3 then {
      // VPMOVB2M (W0) / VPMOVW2M (W1): vector -> mask register
      let modrm = fetch(1);
      let dst_k : kreg_idx = unsigned(modrm[5..3]);
      let xi = xrm_reg(modrm_xrm_evex(modrm, pfx, 1));
      let eb : {8, 16} = if pfx.rex_w then 16 else 8;
      let vl = evex_vl(pfx);
      write_kreg(dst_k, avx_vpmov2m(eb, read_simd(vl, xi)))
    } else if mp == MP_66 then {
      let modrm = fetch(1);
      let dst_k : range(0, 7) = unsigned(modrm[5..3]);
      let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let vl = evex_vl(pfx);
      let k_mask = avx_pcmpeq_mask(64, read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(src, pfx, 64)) & evex_kmask64(pfx);
      write_kreg(dst_k, k_mask)
    } else {
      raise_UD()
    }
  },

  // 0F38 37: VPCMPGTQ (66,W1) [F]
  55 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst_k : range(0, 7) = unsigned(modrm[5..3]);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    let k_mask = avx_pcmpgt_mask(64, read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(src, pfx, 64)) & evex_kmask64(pfx);
    write_kreg(dst_k, k_mask)
  },

  // 0F38 38: VPMINSB (66) [BW] / VPMOVM2D (F3,W0) / VPMOVM2Q (F3,W1) [DQ]
  56 => {
    if mp == MP_66 then {
      evex_exec_binop(PB_MinS, 8, pfx)
    } else if mp == MP_F3 then {
      // VPMOVM2D (W0) / VPMOVM2Q (W1): mask register -> vector
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let k_idx : kreg_idx = unsigned(modrm[2..0]);
      let k_val = read_kreg(k_idx);
      let eb = evex_elem(pfx);
      let vl = evex_vl(pfx);
      let mask = evex_wmask(pfx, vl / eb);
      let result = avx_vpmovm2(vl, eb, k_val);
      evex_write(dst, mask, result)
    } else {
      raise_UD()
    }
  },

  // 0F38 39: VPMINSD (66,W0) / VPMINSQ (66,W1) [F] / VPMOVD2M (F3,W0) / VPMOVQ2M (F3,W1) [DQ]
  57 => {
    if mp == MP_66 then {
      evex_exec_binop_bcast(PB_MinS, evex_elem(pfx), pfx)
    } else if mp == MP_F3 then {
      // VPMOVD2M (W0) / VPMOVQ2M (W1): vector -> mask register
      let modrm = fetch(1);
      let dst_k : kreg_idx = unsigned(modrm[5..3]);
      let xi = xrm_reg(modrm_xrm_evex(modrm, pfx, 1));
      let eb = evex_elem(pfx);
      let vl = evex_vl(pfx);
      write_kreg(dst_k, avx_vpmov2m(eb, read_simd(vl, xi)))
    } else {
      raise_UD()
    }
  },

  // 0F38 3A: VPBROADCASTMW2D (F3,W0) [CD]
  // 0F38 3B: VPMINUD (66, W=0) / VPMINUQ (66, W=1)
  59 => { if mp != MP_66 then raise_UD(); evex_exec_binop_bcast(PB_MinU, evex_elem(pfx), pfx) },

  // 0F38 2B: VPACKUSDW (66,W0) [BW] — supports m32bcst
  43 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    let mask = evex_wmask(pfx, vl / 16);
    evex_write(dst, mask, packed_pack(PN_SatSU, 32, 16, read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(vl, src, pfx, 32)))
  },

  // 0F38 3C: VPMAXSB (66) [BW]
  60 => { if mp != MP_66 then raise_UD(); evex_exec_binop(PB_MaxS, 8, pfx) },
  // 0F38 3D: VPMAXSD (66,W0) / VPMAXSQ (66,W1) [F]
  61 => { if mp != MP_66 then raise_UD(); evex_exec_binop_bcast(PB_MaxS, evex_elem(pfx), pfx) },
  // 0F38 3E: VPMAXUW (66) [BW]
  62 => { if mp != MP_66 then raise_UD(); evex_exec_binop(PB_MaxU, 16, pfx) },
  // 0F38 3F: VPMAXUD (66,W0) / VPMAXUQ (66,W1) [F]
  63 => { if mp != MP_66 then raise_UD(); evex_exec_binop_bcast(PB_MaxU, evex_elem(pfx), pfx) },

  // 0F38 7A: VPBROADCASTB from GPR (66, W=0)
  // r/m field selects a GPR (mod=11 always for this opcode)
  // 0F38 04: VPMADDUBSW (66) [BW]
  4 => { if mp != MP_66 then raise_UD(); evex_exec_binop(PB_Pmaddubsw, 16, pfx) },

  // 0F38 0B: VPMULHRSW (66) [BW]
  11 => { if mp != MP_66 then raise_UD(); evex_exec_binop(PB_MulHRS, 16, pfx) },

  // 0F38 28: VPMULDQ (66,W1) [F] / VPMOVM2B (F3,W0) / VPMOVM2W (F3,W1) [BW]
  40 => {
    if mp == MP_66 then {
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
  
      let vl = evex_vl(pfx);
      let mask = evex_wmask(pfx, vl / 64);
      evex_write(dst, mask, packed_binop(PB_Pmuldq, 64, read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(vl, src, pfx, 64)))
    } else if mp == MP_F3 then {
      // VPMOVM2B (W0) / VPMOVM2W (W1): mask register -> vector
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let k_idx : kreg_idx = unsigned(modrm[2..0]);
      let k_val = read_kreg(k_idx);
      let eb : {8, 16} = if pfx.rex_w then 16 else 8;
      let vl = evex_vl(pfx);
      let mask = evex_wmask(pfx, vl / eb);
      let result = avx_vpmovm2(vl, eb, k_val);
      evex_write(dst, mask, result)
    } else {
      raise_UD()
    }
  },

  // 0F38 40: VPMULLD (66,W0) / VPMULLQ (66,W1) [F/DQ]
  64 => { if mp != MP_66 then raise_UD(); evex_exec_binop_bcast(PB_MulLow, evex_elem(pfx), pfx) },

  // 0F38 1C: VPABSB (66) [BW]
  28 => { if mp != MP_66 then raise_UD(); evex_exec_unop(PU_Abs, 8, pfx)
  },

  // 0F38 1D: VPABSW (66) [BW]
  29 => { if mp != MP_66 then raise_UD(); evex_exec_unop(PU_Abs, 16, pfx) },
  // 0F38 1E: VPABSD (66,W0) [F]
  30 => { if mp != MP_66 then raise_UD(); evex_exec_unop_bcast(PU_Abs, 32, pfx) },

  // 0F38 1F: VPABSQ (66,W1) [F]
  31 => { if mp != MP_66 then raise_UD(); evex_exec_unop_bcast(PU_Abs, 64, pfx) },

  // 0F38 10: VPSRLVW (66,W1) [BW] / VPMOVUSWB (F3) [BW]
  16 => {
    let modrm = fetch(1);
    if mp == MP_66 then {
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let src1_idx = pfx.evex_vvvvv;
      let vl = evex_vl(pfx);
      let mask = evex_wmask(pfx, vl / 16);
      evex_write(dst, mask, packed_binop(PB_Srl, 16, read_simd(vl, src1_idx), evex_src(vl, src)))
    } else if mp == MP_F3 then {
      // VPMOVUSWB: src=reg, dst=r/m (narrowing: word->byte, unsigned saturation)
      let src = evex_reg_idx(modrm, pfx);
      let vl = evex_vl(pfx);
      let nbytes = vl / 16;
      let res = packed_narrow_unop(PN_SatU, 16, 8, read_simd(vl, src));
      let dest = modrm_xrm_evex(modrm, pfx, nbytes);
      evex_write_rm(dest, pfx, evex_wmask(pfx, vl / 16), res)
    } else {
      raise_UD()
    }
  },

  // 0F38 11: VPSRAVW (66,W1) [BW] / VPMOVUSDB (F3) [F]
  17 => {
    let modrm = fetch(1);
    if mp == MP_66 then {
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let src1_idx = pfx.evex_vvvvv;
      let vl = evex_vl(pfx);
      let mask = evex_wmask(pfx, vl / 16);
      evex_write(dst, mask, packed_binop(PB_Sra, 16, read_simd(vl, src1_idx), evex_src(vl, src)))
    } else if mp == MP_F3 then {
      // VPMOVUSDB: src=reg, dst=r/m (narrowing: dword->byte, unsigned saturation)
      let src = evex_reg_idx(modrm, pfx);
      let vl = evex_vl(pfx);
      let nbytes = vl / 32;
      let res = packed_narrow_unop(PN_SatU, 32, 8, read_simd(vl, src));
      let dest = modrm_xrm_evex(modrm, pfx, nbytes);
      evex_write_rm(dest, pfx, evex_wmask(pfx, vl / 32), res)
    } else {
      raise_UD()
    }
  },

  // 0F38 12: VPSLLVW (66,W1) [BW] / VPMOVUSQB (F3) [F]
  18 => {
    let modrm = fetch(1);
    if mp == MP_66 then {
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let src1_idx = pfx.evex_vvvvv;
      let vl = evex_vl(pfx);
      let mask = evex_wmask(pfx, vl / 16);
      evex_write(dst, mask, packed_binop(PB_Sll, 16, read_simd(vl, src1_idx), evex_src(vl, src)))
    } else if mp == MP_F3 then {
      // VPMOVUSQB: src=reg, dst=r/m (narrowing: qword->byte, unsigned saturation)
      let src = evex_reg_idx(modrm, pfx);
      let vl = evex_vl(pfx);
      let nbytes = vl / 64;
      let res = packed_narrow_unop(PN_SatU, 64, 8, read_simd(vl, src));
      let dest = modrm_xrm_evex(modrm, pfx, nbytes);
      evex_write_rm(dest, pfx, evex_wmask(pfx, vl / 64), res)
    } else {
      raise_UD()
    }
  },

  // 0F38 13: VCVTPH2PS (66,W0) [F] / VPMOVUSDW (F3) [F]
  19 => {
    if mp == MP_66 then {
      // VCVTPH2PS: convert packed FP16 (half width) to FP32
      if pfx.rex_w then raise_UD();
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let vl = evex_vl(pfx);
      let src = modrm_xrm_evex(modrm, pfx, vl / 16);
      let mask = evex_wmask(pfx, vl / 32);
      evex_write(dst, mask, avx_vcvtph2ps(evex_widen_src(vl, 2, src)))
    } else if mp == MP_F3 then {
      let modrm = fetch(1);
      let src = evex_reg_idx(modrm, pfx);
      let vl = evex_vl(pfx);
      let nbytes = vl / 16;
      let res = packed_narrow_unop(PN_SatU, 32, 16, read_simd(vl, src));
      let dest = modrm_xrm_evex(modrm, pfx, nbytes);
      evex_write_rm(dest, pfx, evex_wmask(pfx, vl / 32), res)
    } else {
      raise_UD()
    }
  },

  // 0F38 14: VPRORVD (66,W0) / VPRORVQ (66,W1) [F] / VPMOVUSQW (F3) [F]
  20 => {
    let modrm = fetch(1);
    if mp == MP_66 then {
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let src1_idx = pfx.evex_vvvvv;
      let vl = evex_vl(pfx);
      let eb = evex_elem(pfx);
      let mask = evex_wmask(pfx, vl / eb);
      evex_write(dst, mask, packed_binop(PB_Ror, eb, read_simd(vl, src1_idx), evex_bcast_src(src, pfx, eb)))
    } else if mp == MP_F3 then {
      // VPMOVUSQW: src=reg, dst=r/m (narrowing: qword->word, unsigned saturation)
      let src = evex_reg_idx(modrm, pfx);
      let vl = evex_vl(pfx);
      let nbytes = vl / 32;
      let res = packed_narrow_unop(PN_SatU, 64, 16, read_simd(vl, src));
      let dest = modrm_xrm_evex(modrm, pfx, nbytes);
      evex_write_rm(dest, pfx, evex_wmask(pfx, vl / 64), res)
    } else {
      raise_UD()
    }
  },

  // 0F38 15: VPROLVD (66,W0) / VPROLVQ (66,W1) [F] / VPMOVUSQD (F3) [F]
  21 => {
    let modrm = fetch(1);
    if mp == MP_66 then {
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let src1_idx = pfx.evex_vvvvv;
      let vl = evex_vl(pfx);
      let eb = evex_elem(pfx);
      let mask = evex_wmask(pfx, vl / eb);
      evex_write(dst, mask, packed_binop(PB_Rol, eb, read_simd(vl, src1_idx), evex_bcast_src(src, pfx, eb)))
    } else if mp == MP_F3 then {
      // VPMOVUSQD: src=reg, dst=r/m (narrowing: qword->dword, unsigned saturation)
      let src = evex_reg_idx(modrm, pfx);
      let vl = evex_vl(pfx);
      let nbytes = vl / 16;
      let res = packed_narrow_unop(PN_SatU, 64, 32, read_simd(vl, src));
      let dest = modrm_xrm_evex(modrm, pfx, nbytes);
      evex_write_rm(dest, pfx, evex_wmask(pfx, vl / 64), res)
    } else {
      raise_UD()
    }
  },

  // 0F38 20: VPMOVSXBW (66) [BW] / VPMOVSWB (F3) [BW]
  32 => {
    let modrm = fetch(1);
    if mp == MP_66 then {
      let dst = evex_reg_idx(modrm, pfx);
      let vl = evex_vl(pfx);
      let src2 = modrm_xrm_evex(modrm, pfx, vl / 16);
      let src = evex_widen_src(vl, 2, src2);
      let mask = evex_wmask(pfx, vl / 16);
      evex_write(dst, mask, packed_widen_unop(vl, PW_SignExtend, 8, 16, src))
    } else if mp == MP_F3 then {
      // VPMOVSWB: src=reg, dst=r/m (narrowing: word->byte, signed saturation)
      let src = evex_reg_idx(modrm, pfx);
      let vl = evex_vl(pfx);
      let nbytes = vl / 16;
      let res = packed_narrow_unop(PN_SatS, 16, 8, read_simd(vl, src));
      let dest = modrm_xrm_evex(modrm, pfx, nbytes);
      evex_write_rm(dest, pfx, evex_wmask(pfx, vl / 16), res)
    } else {
      raise_UD()
    }
  },

  // 0F38 21: VPMOVSXBD (66) [F] / VPMOVSDB (F3) [F]
  33 => {
    let modrm = fetch(1);
    if mp == MP_66 then {
      let dst = evex_reg_idx(modrm, pfx);
      let vl = evex_vl(pfx);
      let src2 = modrm_xrm_evex(modrm, pfx, vl / 32);
      let src = evex_widen_src(vl, 4, src2);
      let mask = evex_wmask(pfx, vl / 32);
      evex_write(dst, mask, packed_widen_unop(vl, PW_SignExtend, 8, 32, src))
    } else if mp == MP_F3 then {
      // VPMOVSDB: src=reg, dst=r/m (narrowing: dword->byte, signed saturation)
      let src = evex_reg_idx(modrm, pfx);
      let vl = evex_vl(pfx);
      let nbytes = vl / 32;
      let res = packed_narrow_unop(PN_SatS, 32, 8, read_simd(vl, src));
      let dest = modrm_xrm_evex(modrm, pfx, nbytes);
      evex_write_rm(dest, pfx, evex_wmask(pfx, vl / 32), res)
    } else {
      raise_UD()
    }
  },

  // 0F38 22: VPMOVSXBQ (66) [F] / VPMOVSQB (F3) [F]
  34 => {
    let modrm = fetch(1);
    if mp == MP_66 then {
      let dst = evex_reg_idx(modrm, pfx);
      let vl = evex_vl(pfx);
      let src2 = modrm_xrm_evex(modrm, pfx, vl / 64);
      let src = evex_widen_src(vl, 8, src2);
      let mask = evex_wmask(pfx, vl / 64);
      evex_write(dst, mask, packed_widen_unop(vl, PW_SignExtend, 8, 64, src))
    } else if mp == MP_F3 then {
      // VPMOVSQB: src=reg, dst=r/m (narrowing: qword->byte, signed saturation)
      let src = evex_reg_idx(modrm, pfx);
      let vl = evex_vl(pfx);
      let nbytes = vl / 64;
      let res = packed_narrow_unop(PN_SatS, 64, 8, read_simd(vl, src));
      let dest = modrm_xrm_evex(modrm, pfx, nbytes);
      evex_write_rm(dest, pfx, evex_wmask(pfx, vl / 64), res)
    } else {
      raise_UD()
    }
  },

  // 0F38 23: VPMOVSXWD (66) [F] / VPMOVSDW (F3) [F]
  35 => {
    let modrm = fetch(1);
    if mp == MP_66 then {
      let dst = evex_reg_idx(modrm, pfx);
      let vl = evex_vl(pfx);
      let src2 = modrm_xrm_evex(modrm, pfx, vl / 16);
      let src = evex_widen_src(vl, 2, src2);
      let mask = evex_wmask(pfx, vl / 32);
      evex_write(dst, mask, packed_widen_unop(vl, PW_SignExtend, 16, 32, src))
    } else if mp == MP_F3 then {
      // VPMOVSDW: src=reg, dst=r/m (narrowing: dword->word, signed saturation)
      let src = evex_reg_idx(modrm, pfx);
      let vl = evex_vl(pfx);
      let nbytes = vl / 16;
      let res = packed_narrow_unop(PN_SatS, 32, 16, read_simd(vl, src));
      let dest = modrm_xrm_evex(modrm, pfx, nbytes);
      evex_write_rm(dest, pfx, evex_wmask(pfx, vl / 32), res)
    } else {
      raise_UD()
    }
  },

  // 0F38 24: VPMOVSXWQ (66) [F] / VPMOVSQW (F3) [F]
  36 => {
    let modrm = fetch(1);
    if mp == MP_66 then {
      let dst = evex_reg_idx(modrm, pfx);
      let vl = evex_vl(pfx);
      let src2 = modrm_xrm_evex(modrm, pfx, vl / 32);
      let src = evex_widen_src(vl, 4, src2);
      let mask = evex_wmask(pfx, vl / 64);
      evex_write(dst, mask, packed_widen_unop(vl, PW_SignExtend, 16, 64, src))
    } else if mp == MP_F3 then {
      // VPMOVSQW: src=reg, dst=r/m (narrowing: qword->word, signed saturation)
      let src = evex_reg_idx(modrm, pfx);
      let vl = evex_vl(pfx);
      let nbytes = vl / 32;
      let res = packed_narrow_unop(PN_SatS, 64, 16, read_simd(vl, src));
      let dest = modrm_xrm_evex(modrm, pfx, nbytes);
      evex_write_rm(dest, pfx, evex_wmask(pfx, vl / 64), res)
    } else {
      raise_UD()
    }
  },

  // 0F38 25: VPMOVSXDQ (66) [F] / VPMOVSQD (F3) [F]
  37 => {
    let modrm = fetch(1);
    if mp == MP_66 then {
      let dst = evex_reg_idx(modrm, pfx);
      let vl = evex_vl(pfx);
      let src2 = modrm_xrm_evex(modrm, pfx, vl / 16);
      let src = evex_widen_src(vl, 2, src2);
      let mask = evex_wmask(pfx, vl / 64);
      evex_write(dst, mask, packed_widen_unop(vl, PW_SignExtend, 32, 64, src))
    } else if mp == MP_F3 then {
      // VPMOVSQD: src=reg, dst=r/m (narrowing: qword->dword, signed saturation)
      let src = evex_reg_idx(modrm, pfx);
      let vl = evex_vl(pfx);
      let nbytes = vl / 16;
      let res = packed_narrow_unop(PN_SatS, 64, 32, read_simd(vl, src));
      let dest = modrm_xrm_evex(modrm, pfx, nbytes);
      evex_write_rm(dest, pfx, evex_wmask(pfx, vl / 64), res)
    } else {
      raise_UD()
    }
  },

  // 0F38 30: VPMOVZXBW (66) [BW] / VPMOVWB (F3) [BW]
  48 => {
    let modrm = fetch(1);
    if mp == MP_66 then {
      let dst = evex_reg_idx(modrm, pfx);
      let vl = evex_vl(pfx);
      let src2 = modrm_xrm_evex(modrm, pfx, vl / 16);
      let src = evex_widen_src(vl, 2, src2);
      let mask = evex_wmask(pfx, vl / 16);
      evex_write(dst, mask, packed_widen_unop(vl, PW_ZeroExtend, 8, 16, src))
    } else if mp == MP_F3 then {
      // VPMOVWB: src=reg, dst=r/m (narrowing: word->byte, truncation)
      let src = evex_reg_idx(modrm, pfx);
      let vl = evex_vl(pfx);
      let nbytes = vl / 16;
      let res = packed_narrow_unop(PN_Trunc, 16, 8, read_simd(vl, src));
      let dest = modrm_xrm_evex(modrm, pfx, nbytes);
      evex_write_rm(dest, pfx, evex_wmask(pfx, vl / 16), res)
    } else {
      raise_UD()
    }
  },

  // 0F38 31: VPMOVZXBD (66) [F] / VPMOVDB (F3) [F]
  49 => {
    let modrm = fetch(1);
    if mp == MP_66 then {
      let dst = evex_reg_idx(modrm, pfx);
      let vl = evex_vl(pfx);
      let src2 = modrm_xrm_evex(modrm, pfx, vl / 32);
      let src = evex_widen_src(vl, 4, src2);
      let mask = evex_wmask(pfx, vl / 32);
      evex_write(dst, mask, packed_widen_unop(vl, PW_ZeroExtend, 8, 32, src))
    } else if mp == MP_F3 then {
      // VPMOVDB: src=reg, dst=r/m (narrowing: dword->byte, truncation)
      let src = evex_reg_idx(modrm, pfx);
      let vl = evex_vl(pfx);
      let nbytes = vl / 32;
      let res = packed_narrow_unop(PN_Trunc, 32, 8, read_simd(vl, src));
      let dest = modrm_xrm_evex(modrm, pfx, nbytes);
      evex_write_rm(dest, pfx, evex_wmask(pfx, vl / 32), res)
    } else {
      raise_UD()
    }
  },

  // 0F38 32: VPMOVZXBQ (66) [F] / VPMOVQB (F3) [F]
  50 => {
    let modrm = fetch(1);
    if mp == MP_66 then {
      let dst = evex_reg_idx(modrm, pfx);
      let vl = evex_vl(pfx);
      let src2 = modrm_xrm_evex(modrm, pfx, vl / 64);
      let src = evex_widen_src(vl, 8, src2);
      let mask = evex_wmask(pfx, vl / 64);
      evex_write(dst, mask, packed_widen_unop(vl, PW_ZeroExtend, 8, 64, src))
    } else if mp == MP_F3 then {
      // VPMOVQB: src=reg, dst=r/m (narrowing: qword->byte, truncation)
      let src = evex_reg_idx(modrm, pfx);
      let vl = evex_vl(pfx);
      let nbytes = vl / 64;
      let res = packed_narrow_unop(PN_Trunc, 64, 8, read_simd(vl, src));
      let dest = modrm_xrm_evex(modrm, pfx, nbytes);
      evex_write_rm(dest, pfx, evex_wmask(pfx, vl / 64), res)
    } else {
      raise_UD()
    }
  },

  // 0F38 33: VPMOVZXWD (66) [F] / VPMOVDW (F3) [F]
  51 => {
    let modrm = fetch(1);
    if mp == MP_66 then {
      let dst = evex_reg_idx(modrm, pfx);
      let vl = evex_vl(pfx);
      let src2 = modrm_xrm_evex(modrm, pfx, vl / 16);
      let src = evex_widen_src(vl, 2, src2);
      let mask = evex_wmask(pfx, vl / 32);
      evex_write(dst, mask, packed_widen_unop(vl, PW_ZeroExtend, 16, 32, src))
    } else if mp == MP_F3 then {
      // VPMOVDW: src=reg, dst=r/m (narrowing: dword->word, truncation)
      let src = evex_reg_idx(modrm, pfx);
      let vl = evex_vl(pfx);
      let nbytes = vl / 16;
      let res = packed_narrow_unop(PN_Trunc, 32, 16, read_simd(vl, src));
      let dest = modrm_xrm_evex(modrm, pfx, nbytes);
      evex_write_rm(dest, pfx, evex_wmask(pfx, vl / 32), res)
    } else {
      raise_UD()
    }
  },

  // 0F38 34: VPMOVZXWQ (66) [F] / VPMOVQW (F3) [F]
  52 => {
    let modrm = fetch(1);
    if mp == MP_66 then {
      let dst = evex_reg_idx(modrm, pfx);
      let vl = evex_vl(pfx);
      let src2 = modrm_xrm_evex(modrm, pfx, vl / 32);
      let src = evex_widen_src(vl, 4, src2);
      let mask = evex_wmask(pfx, vl / 64);
      evex_write(dst, mask, packed_widen_unop(vl, PW_ZeroExtend, 16, 64, src))
    } else if mp == MP_F3 then {
      // VPMOVQW: src=reg, dst=r/m (narrowing: qword->word, truncation)
      let src = evex_reg_idx(modrm, pfx);
      let vl = evex_vl(pfx);
      let nbytes = vl / 32;
      let res = packed_narrow_unop(PN_Trunc, 64, 16, read_simd(vl, src));
      let dest = modrm_xrm_evex(modrm, pfx, nbytes);
      evex_write_rm(dest, pfx, evex_wmask(pfx, vl / 64), res)
    } else {
      raise_UD()
    }
  },

  // 0F38 45: VPSRLVD (66,W0) / VPSRLVQ (66,W1) [F]
  69 => { if mp != MP_66 then raise_UD(); evex_exec_binop_bcast(PB_Srl, evex_elem(pfx), pfx) },
  // 0F38 46: VPSRAVD (66,W0) / VPSRAVQ (66,W1) [F]
  70 => { if mp != MP_66 then raise_UD(); evex_exec_binop_bcast(PB_Sra, evex_elem(pfx), pfx) },
  // 0F38 47: VPSLLVD (66,W0) / VPSLLVQ (66,W1) [F]
  71 => { if mp != MP_66 then raise_UD(); evex_exec_binop_bcast(PB_Sll, evex_elem(pfx), pfx) },

  // 0F38 35: VPMOVZXDQ (66) [F] / VPMOVQD (F3) [F]
  53 => {
    let modrm = fetch(1);
    if mp == MP_66 then {
      let dst = evex_reg_idx(modrm, pfx);
      let vl = evex_vl(pfx);
      let src2 = modrm_xrm_evex(modrm, pfx, vl / 16);
      let src = evex_widen_src(vl, 2, src2);
      let mask = evex_wmask(pfx, vl / 64);
      evex_write(dst, mask, packed_widen_unop(vl, PW_ZeroExtend, 32, 64, src))
    } else if mp == MP_F3 then {
      // VPMOVQD: src=reg, dst=r/m (narrowing: qword->dword, truncation)
      let src = evex_reg_idx(modrm, pfx);
      let vl = evex_vl(pfx);
      let nbytes = vl / 16;
      let res = packed_narrow_unop(PN_Trunc, 64, 32, read_simd(vl, src));
      let dest = modrm_xrm_evex(modrm, pfx, nbytes);
      evex_write_rm(dest, pfx, evex_wmask(pfx, vl / 64), res)
    } else {
      raise_UD()
    }
  },

  // 0F38 7D: VPERMT2W (66,W1) [BW] / VPERMT2B (66,W0) [VBMI]
  // 0F38 70: VPSHLDVW (66, W=1) [VBMI2]
  112 => {
    if mp != MP_66 | ~(pfx.rex_w) then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    let mask = evex_wmask(pfx, vl / 16);
    evex_write(dst, mask, packed_ternop(PT_FunnelShl, 16, read_simd(vl, dst), read_simd(vl, pfx.evex_vvvvv), evex_src(vl, src)))
  },

  // 0F38 71: VPSHLDVD (66, W=0) / VPSHLDVQ (66, W=1) [VBMI2]
  113 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    let eb = evex_elem(pfx);
    let mask = evex_wmask(pfx, vl / eb);
    evex_write(dst, mask, packed_ternop(PT_FunnelShl, eb, read_simd(vl, dst), read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(src, pfx, eb)))
  },

  // 0F38 72: VPSHRDVW (66,W1) / VCVTNE2PS2BF16 (F2,W0) / VCVTNEPS2BF16 (F3,W0)
  114 => {
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    match mp {
      MP_66 => {
        // VPSHRDVW (W=1 required)
        if ~(pfx.rex_w) then raise_UD();
        let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
        let vl = evex_vl(pfx);
        let mask = evex_wmask(pfx, vl / 16);
        evex_write(dst, mask, packed_ternop(PT_FunnelShr, 16, read_simd(vl, dst), read_simd(vl, pfx.evex_vvvvv), evex_src(vl, src)))
      },
      MP_F2 => {
        // VCVTNE2PS2BF16: convert two packed FP32 → packed BF16 (W=0)
        if pfx.rex_w then raise_UD();
        let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
        let vl = evex_vl(pfx);
        let mask = evex_wmask(pfx, vl / 16);
        let s1 = read_simd(vl, pfx.evex_vvvvv);
        let s2 = evex_bcast_src(vl, src, pfx, 32);
        evex_write(dst, mask, avx_vcvtne2ps2bf16(s1, s2))
      },
      MP_F3 => {
        // VCVTNEPS2BF16: convert packed FP32 → packed BF16 (W=0)
        if pfx.rex_w then raise_UD();
        let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
        let vl = evex_vl(pfx);
        let res = avx_vcvtneps2bf16(evex_bcast_src(vl, src, pfx, 32));
        match vl {
          128 => evex_write(dst, evex_wmask(pfx, 8), zero_extend(128, res)),
          256 => evex_write(dst, evex_wmask(pfx, 8), res),
          512 => evex_write(dst, evex_wmask(pfx, 16), res),
        }
      },
      _ => raise_UD(),
    }
  },

  // 0F38 73: VPSHRDVD (66, W=0) / VPSHRDVQ (66, W=1) [VBMI2]
  115 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    let eb = evex_elem(pfx);
    let mask = evex_wmask(pfx, vl / eb);
    evex_write(dst, mask, packed_ternop(PT_FunnelShr, eb, read_simd(vl, dst), read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(src, pfx, eb)))
  },

  // 0F38 83: VPMULTISHIFTQB (66,W1) [VBMI]
  131 => {
    if mp != MP_66 | ~(pfx.rex_w) then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    let mask = evex_wmask(pfx, vl / 8);
    evex_write(dst, mask, avx_vpmultishiftqb(read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(src, pfx, 64)))
  },

  // 0F38 44: VPLZCNTD (66, W=0) / VPLZCNTQ (66, W=1) [CD]
  68 => { if mp != MP_66 then raise_UD(); evex_exec_unop_bcast(PU_Lzcnt, evex_elem(pfx), pfx) },

  // 0F38 50: VPDPBUSD (66) [VNNI]
  80 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    let mask = evex_wmask(pfx, vl / 32);
    evex_write(dst, mask, packed_ternop(PT_DPBusd, 32, read_simd(vl, dst), read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(src, pfx, 32)))
  },

  // 0F38 51: VPDPBUSDS (66) [VNNI]
  81 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    let mask = evex_wmask(pfx, vl / 32);
    evex_write(dst, mask, packed_ternop(PT_DPBusds, 32, read_simd(vl, dst), read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(src, pfx, 32)))
  },

  // 0F38 52: VPDPWSSD (66) [VNNI] / VDPBF16PS (F3) [BF16]
  82 => {
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));

    match mp {
      MP_66 => {
        // VPDPWSSD xmm1/ymm1/zmm1, xmm2/ymm2/zmm2, xmm3/ymm3/zmm3/m128/m256/m512
        let vl = evex_vl(pfx);
        let mask = evex_wmask(pfx, vl / 32);
        evex_write(dst, mask, packed_ternop(PT_DPWssd, 32, read_simd(vl, dst), read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(src, pfx, 32)))
      },
      MP_F3 => {
        // VDPBF16PS: BF16 dot product accumulating to FP32 (W=0)
        if pfx.rex_w then raise_UD();
        let vl = evex_vl(pfx);
        let mask = evex_wmask(pfx, vl / 32);
        evex_write(dst, mask, avx_vdpbf16ps(read_simd(vl, dst), read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(src, pfx, 32)))
      },
      _ => raise_UD(),
    }
  },

  // 0F38 53: VPDPWSSDS (66) [VNNI]
  83 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    let mask = evex_wmask(pfx, vl / 32);
    evex_write(dst, mask, packed_ternop(PT_DPWssds, 32, read_simd(vl, dst), read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(src, pfx, 32)))
  },

  // 0F38 54: VPOPCNTB (66, W=0) / VPOPCNTW (66, W=1) [BITALG]
  84 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    let eb : {8, 16} = if pfx.rex_w then 16 else 8;
    let mask = evex_wmask(pfx, vl / eb);
    evex_write(dst, mask, packed_unop(PU_Popcnt, eb, evex_src(vl, src)))
  },

  // 0F38 55: VPOPCNTD (66, W=0) / VPOPCNTQ (66, W=1) [VPOPCNTDQ]
  85 => { if mp != MP_66 then raise_UD(); evex_exec_unop_bcast(PU_Popcnt, evex_elem(pfx), pfx) },

  // 0F38 C4: VPCONFLICTD (66, W=0) / VPCONFLICTQ (66, W=1) [CD]
  196 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));

    let eb = evex_elem(pfx);
    let vl = evex_vl(pfx);
    let mask = evex_wmask(pfx, vl / eb);
    let bcast_src = evex_bcast_src(vl, src, pfx, eb);
    evex_write(dst, mask, avx_vpconflict(eb, bcast_src))
  },

  // 0F38 66: VPBLENDMB (66,W0) / VPBLENDMW (66,W1) — mask-controlled byte/word blend
  // Semantics: writemask selects src2 (mask=1) or merge/zero from src1 (mask=0).
  102 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    let src1 = read_simd(vl, pfx.evex_vvvvv);
    if pfx.rex_w then
      write_simd(vl, dst, apply_writemask(evex_wmask(pfx, vl / 16), evex_src(src), src1))
    else
      write_simd(vl, dst, apply_writemask(evex_wmask(pfx, vl / 8), evex_src(src), src1))
  },

  _ => raise_UD(),
  }
}

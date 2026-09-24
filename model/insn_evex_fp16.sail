// x86-64 — EVEX FP16 Operations (MAP5 and MAP6)
//
// Half-precision (16-bit) packed and scalar floating-point arithmetic,
// conversions, and special operations.

// EVEX FP16 binary arithmetic helper for PH/SH with {er} support.
val evex_fp16_binop_er : (PackedBinOp, simd_idx, XRM, MandatoryPrefix, Prefixes) -> unit
function evex_fp16_binop_er(op, dst, src, mp, pfx) = match mp {
    MP_NONE => {
      let (eff_ll, saved) = evex_begin_rc_xrm(pfx, src);
      let vl = ll_to_vl(eff_ll);
      evex_write(dst, evex_wmask(pfx, vl / 16), packed_binop(op, 16, read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(src, pfx, 16)));
      evex_end_rc(saved)
    },
    MP_F3 => {
      let src1 : xmmword = read_simd(pfx.evex_vvvvv);
      evex_write_scalar(dst, src1[127..16] @ packed_elem_op(op, src1[15..0], decode_scalar_src(16, src)), pfx, 16)
    },
    _ => raise_UD(),
  }

// EVEX FP16 binary arithmetic helper for PH/SH without {er} (MIN/MAX).
val evex_fp16_binop : (PackedBinOp, simd_idx, XRM, MandatoryPrefix, Prefixes) -> unit
function evex_fp16_binop(op, dst, src, mp, pfx) = match mp {
  MP_NONE => {
    let vl = evex_vl(pfx);
    evex_write(dst, evex_wmask(pfx, vl / 16), packed_binop(op, 16, read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(src, pfx, 16)))
  },
  MP_F3 => {
    let src1 : xmmword = read_simd(pfx.evex_vvvvv);
    evex_write_scalar(dst, src1[127..16] @ packed_elem_op(op, src1[15..0], decode_scalar_src(16, src)), pfx, 16)
  },
  _ => raise_UD(),
}

// =========================================================================
// FP16 widening conversion helpers (N × fp16 → N × wider)
// =========================================================================

val avx_cvtph2dq : forall 'n, 'n in {4, 8, 16}. (int('n), bits('n * 16)) -> bits('n * 32)
function avx_cvtph2dq(n, src) = {
  var r : bits('n * 32) = zeros();
  foreach (i from 0 to ('n - 1)) {
    let lo = i * 32;
    r[(lo + 31)..lo] = __f16_to_int32(velem(16, src, i))
  };
  r
}

val avx_cvttph2dq : forall 'n, 'n in {4, 8, 16}. (int('n), bits('n * 16)) -> bits('n * 32)
function avx_cvttph2dq(n, src) = {
  var r : bits('n * 32) = zeros();
  foreach (i from 0 to ('n - 1)) {
    let lo = i * 32;
    r[(lo + 31)..lo] = __f16_to_int32_trunc(velem(16, src, i))
  };
  r
}

val avx_cvtph2udq : forall 'n, 'n in {4, 8, 16}. (int('n), bits('n * 16)) -> bits('n * 32)
function avx_cvtph2udq(n, src) = {
  var r : bits('n * 32) = zeros();
  foreach (i from 0 to ('n - 1)) {
    let lo = i * 32;
    r[(lo + 31)..lo] = __f16_to_uint32(velem(16, src, i))
  };
  r
}

val avx_cvttph2udq : forall 'n, 'n in {4, 8, 16}. (int('n), bits('n * 16)) -> bits('n * 32)
function avx_cvttph2udq(n, src) = {
  var r : bits('n * 32) = zeros();
  foreach (i from 0 to ('n - 1)) {
    let lo = i * 32;
    r[(lo + 31)..lo] = __f16_to_uint32_trunc(velem(16, src, i))
  };
  r
}

val avx_cvtph2qq : forall 'n, 'n in {2, 4, 8}. (int('n), bits('n * 16)) -> bits('n * 64)
function avx_cvtph2qq(n, src) = {
  var r : bits('n * 64) = zeros();
  foreach (i from 0 to ('n - 1)) {
    let lo = i * 64;
    r[(lo + 63)..lo] = __f16_to_int64(velem(16, src, i))
  };
  r
}

val avx_cvttph2qq : forall 'n, 'n in {2, 4, 8}. (int('n), bits('n * 16)) -> bits('n * 64)
function avx_cvttph2qq(n, src) = {
  var r : bits('n * 64) = zeros();
  foreach (i from 0 to ('n - 1)) {
    let lo = i * 64;
    r[(lo + 63)..lo] = __f16_to_int64_trunc(velem(16, src, i))
  };
  r
}

val avx_cvtph2uqq : forall 'n, 'n in {2, 4, 8}. (int('n), bits('n * 16)) -> bits('n * 64)
function avx_cvtph2uqq(n, src) = {
  var r : bits('n * 64) = zeros();
  foreach (i from 0 to ('n - 1)) {
    let lo = i * 64;
    r[(lo + 63)..lo] = __f16_to_uint64(velem(16, src, i))
  };
  r
}

val avx_cvttph2uqq : forall 'n, 'n in {2, 4, 8}. (int('n), bits('n * 16)) -> bits('n * 64)
function avx_cvttph2uqq(n, src) = {
  var r : bits('n * 64) = zeros();
  foreach (i from 0 to ('n - 1)) {
    let lo = i * 64;
    r[(lo + 63)..lo] = __f16_to_uint64_trunc(velem(16, src, i))
  };
  r
}

val avx_cvtph2pd : forall 'n, 'n in {2, 4, 8}. (int('n), bits('n * 16)) -> bits('n * 64)
function avx_cvtph2pd(n, src) = {
  var r : bits('n * 64) = zeros();
  foreach (i from 0 to ('n - 1)) {
    let lo = i * 64;
    r[(lo + 63)..lo] = __f16_to_f64(velem(16, src, i))
  };
  r
}

// =========================================================================
// FP16 narrowing conversion helpers (N × wider → N × fp16)
// =========================================================================

val avx_cvtdq2ph : forall 'n, 'n in {4, 8, 16}. (int('n), bits('n * 32)) -> bits('n * 16)
function avx_cvtdq2ph(n, src) = {
  var r : bits('n * 16) = zeros();
  foreach (i from 0 to ('n - 1)) {
    let lo = i * 16;
    r[(lo + 15)..lo] = __int32_to_f16(velem(32, src, i))
  };
  r
}

val avx_cvtudq2ph : forall 'n, 'n in {4, 8, 16}. (int('n), bits('n * 32)) -> bits('n * 16)
function avx_cvtudq2ph(n, src) = {
  var r : bits('n * 16) = zeros();
  foreach (i from 0 to ('n - 1)) {
    let lo = i * 16;
    r[(lo + 15)..lo] = __uint32_to_f16(velem(32, src, i))
  };
  r
}

val avx_cvtqq2ph : forall 'n, 'n in {2, 4, 8}. (int('n), bits('n * 64)) -> bits('n * 16)
function avx_cvtqq2ph(n, src) = {
  var r : bits('n * 16) = zeros();
  foreach (i from 0 to ('n - 1)) {
    let lo = i * 16;
    r[(lo + 15)..lo] = __int64_to_f16(velem(64, src, i))
  };
  r
}

val avx_cvtuqq2ph : forall 'n, 'n in {2, 4, 8}. (int('n), bits('n * 64)) -> bits('n * 16)
function avx_cvtuqq2ph(n, src) = {
  var r : bits('n * 16) = zeros();
  foreach (i from 0 to ('n - 1)) {
    let lo = i * 16;
    r[(lo + 15)..lo] = __uint64_to_f16(velem(64, src, i))
  };
  r
}

val avx_cvtph2ps : forall 'n, 'n in {4, 8, 16}. (int('n), bits('n * 16)) -> bits('n * 32)
function avx_cvtph2ps(n, src) = {
  var r : bits('n * 32) = zeros();
  foreach (i from 0 to ('n - 1)) {
    let lo = i * 32;
    r[(lo + 31)..lo] = __f16_to_f32(velem(16, src, i))
  };
  r
}

val avx_cvtps2ph : forall 'n, 'n in {4, 8, 16}. (int('n), bits('n * 32)) -> bits('n * 16)
function avx_cvtps2ph(n, src) = {
  var r : bits('n * 16) = zeros();
  foreach (i from 0 to ('n - 1)) {
    let lo = i * 16;
    r[(lo + 15)..lo] = __f32_to_f16(velem(32, src, i))
  };
  r
}

val avx_cvtpd2ph : forall 'n, 'n in {2, 4, 8}. (int('n), bits('n * 64)) -> bits('n * 16)
function avx_cvtpd2ph(n, src) = {
  var r : bits('n * 16) = zeros();
  foreach (i from 0 to ('n - 1)) {
    let lo = i * 16;
    r[(lo + 15)..lo] = __f64_to_f16(velem(64, src, i))
  };
  r
}

// =========================================================================
// FP16 FPCLASS helper (pure Sail bit manipulation)
// Classifies a single FP16 value against imm8 class bits:
//   bit 0: QNaN, bit 1: +0, bit 2: -0, bit 3: +Inf,
//   bit 4: -Inf, bit 5: Denormal, bit 6: Negative finite, bit 7: SNaN
// =========================================================================

// VFPCLASS: classify IEEE 754 float against imm8 predicates.
val fpclass : forall 'e 'f, 'e > 0 & 'f > 0 & 'e <= 64 & 'f <= 64.
  (bit, bits('e), bits('f), byte) -> bit
function fpclass(sign, exp, frac, imm) = {
  let exp_all  : bit = is_zero(~(exp));
  let exp_zero : bit = is_zero(exp);
  let frac_nz  : bit = is_nonzero(frac);
  let frac_zero : bit = ~(frac_nz);
  let is_qnan  : bit = exp_all & frac_nz & frac['f - 1];
  let is_snan  : bit = exp_all & frac_nz & ~(frac['f - 1]);
  (imm[0] & is_qnan) |
  (imm[1] & ~(sign) & exp_zero & frac_zero) |
  (imm[2] & sign & exp_zero & frac_zero) |
  (imm[3] & ~(sign) & exp_all & frac_zero) |
  (imm[4] & sign & exp_all & frac_zero) |
  (imm[5] & exp_zero & frac_nz) |
  (imm[6] & sign & ~(exp_all) & ~(exp_zero & frac_zero)) |
  (imm[7] & is_snan)
}

// Per-element fpclass: extract sign/exp/frac fields by element width.
val fpclass_elem : forall 'eb, 'eb in {16, 32, 64}. (bits('eb), byte) -> bit
function fpclass_elem(v, imm) = match 'eb {
  16 => fpclass(v[15], v[14..10], v[9..0], imm),
  32 => fpclass(v[31], v[30..23], v[22..0], imm),
  64 => fpclass(v[63], v[62..52], v[51..0], imm),
}

// Packed fpclass: classify each element, return kmask.
val packed_fpclass : forall 'vl 'eb, 'vl in {128, 256, 512} & 'eb in {16, 32, 64}.
  (int('eb), bits('vl), byte) -> qword
function packed_fpclass(eb, src, imm) = {
  var r : qword = zeros();
  foreach (i from 0 to ('vl / 'eb - 1)) {
    r[i] = fpclass_elem(velem('eb, src, i), imm);
  };
  r
}

// =========================================================================
// Complex FP16 multiply/accumulate helpers
// =========================================================================

// Complex multiply-accumulate one pair: dest += src1 * src2 (or conjugate of src2)
// conj=true: conjugate (VFCMADDCPH), conj=false: normal (VFMADDCPH)
val cfmaddcph_pair : (word, word, word, word, word, word, bool) -> (word, word)
function cfmaddcph_pair(s1_re, s1_im, s2_re, s2_im, a_re, a_im, conj) = {
  let tmp_re : word = fp_fmadd(s1_re, s2_re, a_re);
  let tmp_im : word = fp_fmadd(s1_im, s2_re, a_im);
  if conj then
    (fp_fmadd(s1_im, s2_im, tmp_re), fp_fnmadd(s1_re, s2_im, tmp_im))
  else
    (fp_fnmadd(s1_im, s2_im, tmp_re), fp_fmadd(s1_re, s2_im, tmp_im))
}

val cfmaddcph : forall 'vl, 'vl in {128, 256, 512}. (bits('vl), bits('vl), bits('vl), bool) -> bits('vl)
function cfmaddcph(src1, src2, acc, conj) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 32 - 1)) {
    let lo = i * 32;
    let (re, im) = cfmaddcph_pair(velem(16, src1, i*2), velem(16, src1, i*2+1), velem(16, src2, i*2), velem(16, src2, i*2+1), velem(16, acc, i*2), velem(16, acc, i*2+1), conj);
    r[(lo + 15)..lo] = re;
    r[(lo + 31)..(lo + 16)] = im;
  };
  r
}

// Complex multiply one pair: dest = src1 * src2 (or conjugate of src2)
val cfmulcph_pair : (word, word, word, word, bool) -> (word, word)
function cfmulcph_pair(s1_re, s1_im, s2_re, s2_im, conj) = {
  let tmp_re : word = fp_mul(s1_re, s2_re);
  let tmp_im : word = fp_mul(s1_im, s2_re);
  if conj then
    (fp_fmadd(s1_im, s2_im, tmp_re), fp_fnmadd(s1_re, s2_im, tmp_im))
  else
    (fp_fnmadd(s1_im, s2_im, tmp_re), fp_fmadd(s1_re, s2_im, tmp_im))
}

val cfmulcph : forall 'vl, 'vl in {128, 256, 512}. (bits('vl), bits('vl), bool) -> bits('vl)
function cfmulcph(src1, src2, conj) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 32 - 1)) {
    let lo = i * 32;
    let (re, im) = cfmulcph_pair(velem(16, src1, i*2), velem(16, src1, i*2+1), velem(16, src2, i*2), velem(16, src2, i*2+1), conj);
    r[(lo + 15)..lo] = re;
    r[(lo + 31)..(lo + 16)] = im;
  };
  r
}

// =========================================================================
// EVEX MAP5 dispatch — FP16 basic arithmetic (NP prefix, W=0)
// =========================================================================

// Compressed displacement for FP16 Full tuple: broadcast uses 2 bytes, vector uses 16/32/64
val evex_full_disp_n_fp16 : Prefixes -> range(2, 64)
function evex_full_disp_n_fp16(pfx) =
  if pfx.evex_b then 2
  else match pfx.evex_ll {
    0 => 16,
    1 => 32,
    2 => 64,
    3 => raise_UD(),
  }

val dispatch_evex_map5 : (byte, Prefixes) -> unit
function dispatch_evex_map5(opcode, pfx) = {
  let mp = get_mandatory_prefix(pfx);
  let op : range(0, 255) = unsigned(opcode);

  match op {

    // MAP5 0x51: VSQRTPH xmm/ymm/zmm (NP, W=0) or VSQRTSH (F3, W=0)
    81 => {
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
      match mp {
        MP_NONE => {
          let (eff_ll, saved) = evex_begin_rc_xrm(pfx, src);
          let vl = ll_to_vl(eff_ll);
          evex_write(dst, evex_wmask(pfx, vl / 16),
                     packed_unop(PU_FSqrt, 16, evex_bcast_src(vl, src, pfx, 16)));
          evex_end_rc(saved)
        },
        MP_F3 => {
          // VSQRTSH: scalar FP16 square root (lowest 16 bits)
          let src1 : xmmword = read_simd(pfx.evex_vvvvv);
          let src2 : word = decode_scalar_src(src);
          let r : word = fp_sqrt(src2);
          evex_write_scalar(dst, src1[127..16] @ r, pfx, 16)
        },
        _ => raise_UD(),
      }
    },

    // MAP5 0x58: VADDPH/VADDSH
    88 => {
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
      evex_fp16_binop_er(PB_FAdd, dst, src, mp, pfx)
    },

    // MAP5 0x59: VMULPH/VMULSH
    89 => {
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
      evex_fp16_binop_er(PB_FMul, dst, src, mp, pfx)
    },

    // MAP5 0x5C: VSUBPH/VSUBSH
    92 => {
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
      evex_fp16_binop_er(PB_FSub, dst, src, mp, pfx)
    },

    // MAP5 0x5D: VMINPH/VMINSH
    93 => {
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
      evex_fp16_binop(PB_FMin, dst, src, mp, pfx)
    },

    // MAP5 0x5E: VDIVPH/VDIVSH
    94 => {
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
      evex_fp16_binop_er(PB_FDiv, dst, src, mp, pfx)
    },

    // MAP5 0x5F: VMAXPH/VMAXSH
    95 => {
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
      evex_fp16_binop(PB_FMax, dst, src, mp, pfx)
    },

    // MAP5 0x5A: VCVTPH2PD (NP), VCVTSH2SD (F3), VCVTPD2PH (66/W1), VCVTSD2SH (F2/W1)
    90 => {
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      match mp {
        MP_NONE => {
          // VCVTPH2PD: packed FP16 to FP64
          let disp_n : range(2, 16) = if pfx.evex_b then 2 else match pfx.evex_ll {
            0 => 4, 1 => 8, 2 => 16, 3 => raise_UD(),
          };
          let src = modrm_xrm_evex(modrm, pfx, disp_n);
          match pfx.evex_ll {
            0 => evex_write(dst, evex_wmask(pfx, 2), avx_cvtph2pd(2, decode_scalar_src(32, src))),
            1 => evex_write(dst, evex_wmask(pfx, 4), avx_cvtph2pd(4, decode_scalar_src(64, src))),
            2 => evex_write(dst, evex_wmask(pfx, 8), avx_cvtph2pd(8, evex_bcast_src(128, src, pfx, 16))),
            3 => raise_UD(),
          }
        },
        MP_F3 => {
          // VCVTSH2SD: scalar FP16 to FP64
          let src = modrm_xrm_evex(modrm, pfx, 2);
          let src1 : xmmword = read_simd(pfx.evex_vvvvv);
          let src2 : word = decode_scalar_src(src);
          let r : qword = __f16_to_f64(src2);
          evex_write_scalar(dst, src1[127..64] @ r, pfx, 64)
        },
        MP_66 => {
          // VCVTPD2PH: packed FP64 to FP16 (W=1)
          let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
          let (eff_ll, saved) = evex_begin_rc_xrm(pfx, src);
          match eff_ll {
            0 => evex_write(dst, evex_wmask(pfx, 2), avx_cvtpd2ph(2, evex_bcast_src(128, src, pfx, 64))),
            1 => evex_write(dst, evex_wmask(pfx, 4), avx_cvtpd2ph(4, evex_bcast_src(256, src, pfx, 64))),
            2 => evex_write(dst, evex_wmask(pfx, 8), avx_cvtpd2ph(8, evex_bcast_src(512, src, pfx, 64))),
            3 => raise_UD(),
          };
          evex_end_rc(saved)
        },
        MP_F2 => {
          // VCVTSD2SH: scalar FP64 to FP16
          let src = modrm_xrm_evex(modrm, pfx, 8);
          let src1 : xmmword = read_simd(pfx.evex_vvvvv);
          let src2 : qword = decode_scalar_src(64, src);
          let r : word = __f64_to_f16(src2);
          evex_write_scalar(dst, src1[127..16] @ r, pfx, 16)
        },
      }
    },

    // MAP5 0x5B: VCVTDQ2PH (NP/W0), VCVTQQ2PH (NP/W1), VCVTPH2DQ (66), VCVTTPH2DQ (F3)
    91 => {
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      match mp {
        MP_NONE => {
          let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
          if pfx.vex_w then {
            // VCVTQQ2PH: convert packed int64 to FP16
            match pfx.evex_ll {
              0 => evex_write(dst, evex_wmask(pfx, 2), avx_cvtqq2ph(2, evex_bcast_src(128, src, pfx, 64))),
              1 => evex_write(dst, evex_wmask(pfx, 4), avx_cvtqq2ph(4, evex_bcast_src(256, src, pfx, 64))),
              2 => evex_write(dst, evex_wmask(pfx, 8), avx_cvtqq2ph(8, evex_bcast_src(512, src, pfx, 64))),
              3 => raise_UD(),
            }
          } else {
            // VCVTDQ2PH: convert packed int32 to FP16
            match pfx.evex_ll {
              0 => evex_write(dst, evex_wmask(pfx, 4), avx_cvtdq2ph(4, evex_bcast_src(128, src, pfx, 32))),
              1 => evex_write(dst, evex_wmask(pfx, 8), avx_cvtdq2ph(8, evex_bcast_src(256, src, pfx, 32))),
              2 => evex_write(dst, evex_wmask(pfx, 16), avx_cvtdq2ph(16, evex_bcast_src(512, src, pfx, 32))),
              3 => raise_UD(),
            }
          }
        },
        MP_66 => {
          // VCVTPH2DQ: packed FP16 to int32 (rounding)
          let disp_n : range(2, 32) = if pfx.evex_b then 2 else match pfx.evex_ll {
            0 => 8, 1 => 16, 2 => 32, 3 => raise_UD(),
          };
          let src = modrm_xrm_evex(modrm, pfx, disp_n);
          let (eff_ll, saved) = evex_begin_rc_xrm(pfx, src);
          match eff_ll {
            0 => evex_write(dst, evex_wmask(pfx, 4), avx_cvtph2dq(4, decode_scalar_src(64, src))),
            1 => evex_write(dst, evex_wmask(pfx, 8), avx_cvtph2dq(8, evex_bcast_src(128, src, pfx, 16))),
            2 => evex_write(dst, evex_wmask(pfx, 16), avx_cvtph2dq(16, evex_bcast_src(256, src, pfx, 16))),
            3 => raise_UD(),
          };
          evex_end_rc(saved)
        },
        MP_F3 => {
          // VCVTTPH2DQ: packed FP16 to int32 (truncation)
          let disp_n : range(2, 32) = if pfx.evex_b then 2 else match pfx.evex_ll {
            0 => 8, 1 => 16, 2 => 32, 3 => raise_UD(),
          };
          let src = modrm_xrm_evex(modrm, pfx, disp_n);
          match pfx.evex_ll {
            0 => evex_write(dst, evex_wmask(pfx, 4), avx_cvttph2dq(4, decode_scalar_src(64, src))),
            1 => evex_write(dst, evex_wmask(pfx, 8), avx_cvttph2dq(8, evex_bcast_src(128, src, pfx, 16))),
            2 => evex_write(dst, evex_wmask(pfx, 16), avx_cvttph2dq(16, evex_bcast_src(256, src, pfx, 16))),
            3 => raise_UD(),
          }
        },
        _ => raise_UD(),
      }
    },

    // MAP5 0x10: VMOVSH (F3) — scalar FP16 move (load or reg-reg)
    16 => {
      if mp != MP_F3 then raise_UD();
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_xrm_evex(modrm, pfx, 2);
      match src {
        XRM_mem(m) => {
          // VMOVSH load: 2-operand, load 16-bit under the writemask (k[0]
          // clear leaves the low element or zeroes it), upper bits zero
          let src : word = v(m);
          let old : word = read_simd(128, dst)[15..0];
          let merge : word = blend(old, zeros(), pfx.evex_z);
          let lo : word = blend(merge, src, evex_kmask64(pfx)[0]);
          write_simd(128, dst, zero_extend(lo))
        },
        XRM_reg(xi) => {
          // VMOVSH reg-reg: 3-operand (src1=vvvvv upper bits, src2=src low 16 bits)
          let src1 : xmmword = read_simd(pfx.evex_vvvvv);
          let src2 : word = read_simd(128, xi)[15..0];
          evex_write_scalar(dst, src1[127..16] @ src2, pfx, 16)
        },
      }
    },

    // MAP5 0x11: VMOVSH (F3) — scalar FP16 store
    17 => {
      if mp != MP_F3 then raise_UD();
      let modrm = fetch(1);
      let src = evex_reg_idx(modrm, pfx);
      let dest = modrm_xrm_evex(modrm, pfx, 2);
      match dest {
        XRM_mem(m) => {
          // VMOVSH store: write low 16 bits of src to memory when k[0] is set
          if evex_kmask64(pfx)[0] == bitone then
            v(m) = read_simd(128, src)[15..0]
        },
        XRM_reg(xi) => {
          // VMOVSH reg-reg store: 3-operand (src1=vvvvv upper bits, src2=reg low 16)
          let dst_reg = xi;
          let src1 : xmmword = read_simd(pfx.evex_vvvvv);
          let src2 : word = read_simd(128, src)[15..0];
          write_simd(128, dst_reg, src1[127..16] @ src2)
        },
      }
    },

    // MAP5 0x2A: VCVTSI2SH (F3) — int to scalar FP16
    42 => {
      if mp != MP_F3 then raise_UD();
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_rm_evex(modrm, pfx, if pfx.vex_w then 8 else 4);
      let src1 : xmmword = read_simd(pfx.evex_vvvvv);
      if pfx.vex_w then {
        // VCVTSI2SH r64 → FP16
        let x : qword = v(src);
        let r : word = __int64_to_f16(x);
        evex_write_scalar(dst, src1[127..16] @ r, pfx, 16)
      } else {
        // VCVTSI2SH r32 → FP16
        let x : dword = v(src);
        let r : word = __int32_to_f16(x);
        evex_write_scalar(dst, src1[127..16] @ r, pfx, 16)
      }
    },

    // MAP5 0x2C: VCVTTSH2SI (F3) — FP16 to int with truncation
    44 => {
      if mp != MP_F3 then raise_UD();
      let modrm = fetch(1);
      let dst_gpr = modrm_reg(modrm, pfx);
      let src = modrm_xrm_evex(modrm, pfx, 2);
      let src : word = decode_scalar_src(16, src);
      if pfx.vex_w then
        v(dst_gpr) = __f16_to_int64_trunc(src)
      else
        v(dst_gpr) = __f16_to_int32_trunc(src)
    },

    // MAP5 0x2D: VCVTSH2SI (F3) — FP16 to int with rounding
    45 => {
      if mp != MP_F3 then raise_UD();
      let modrm = fetch(1);
      let dst_gpr = modrm_reg(modrm, pfx);
      let src = modrm_xrm_evex(modrm, pfx, 2);
      let src : word = decode_scalar_src(16, src);
      if pfx.vex_w then
        v(dst_gpr) = __f16_to_int64(src)
      else
        v(dst_gpr) = __f16_to_int32(src)
    },

    // MAP5 0x2E: VUCOMISH (NP) — unordered compare scalar FP16, set EFLAGS
    46 => {
      if mp != MP_NONE then raise_UD();
      let modrm = fetch(1);
      let src_reg = evex_reg_idx(modrm, pfx);
      let src = modrm_xrm_evex(modrm, pfx, 2);
      set_eflags_fp_compare(read_simd(128, src_reg)[15..0] : word, decode_scalar_src(16, src))
    },

    // MAP5 0x2F: VCOMISH (NP) — ordered compare scalar FP16, set EFLAGS
    47 => {
      if mp != MP_NONE then raise_UD();
      let modrm = fetch(1);
      let src_reg = evex_reg_idx(modrm, pfx);
      let src = modrm_xrm_evex(modrm, pfx, 2);
      set_eflags_fp_compare(read_simd(128, src_reg)[15..0] : word, decode_scalar_src(16, src))
    },

    // MAP5 0x6E: VMOVW (66) — load 16-bit value to XMM low, zero-extend
    110 => {
      if mp != MP_66 then raise_UD();
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_rm_evex(modrm, pfx, 2);
      let src : word = match src {
        RM_reg(r) => v(64, r)[15..0],
        RM_mem(m) => v(m),
      };
      write_simd(128, dst, zero_extend(src))
    },

    // MAP5 0x78: VCVTTPH2UDQ (NP), VCVTTPH2UQQ (66), VCVTTSH2USI (F3)
    120 => {
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      match mp {
        MP_NONE => {
          // VCVTTPH2UDQ: packed FP16 to uint32 (truncation)
          let disp_n : range(2, 32) = if pfx.evex_b then 2 else match pfx.evex_ll {
            0 => 8, 1 => 16, 2 => 32, 3 => raise_UD(),
          };
          let src = modrm_xrm_evex(modrm, pfx, disp_n);
          match pfx.evex_ll {
            0 => evex_write(dst, evex_wmask(pfx, 4), avx_cvttph2udq(4, decode_scalar_src(64, src))),
            1 => evex_write(dst, evex_wmask(pfx, 8), avx_cvttph2udq(8, evex_bcast_src(128, src, pfx, 16))),
            2 => evex_write(dst, evex_wmask(pfx, 16), avx_cvttph2udq(16, evex_bcast_src(256, src, pfx, 16))),
            3 => raise_UD(),
          }
        },
        MP_66 => {
          // VCVTTPH2UQQ: packed FP16 to uint64 (truncation)
          let disp_n : range(2, 16) = if pfx.evex_b then 2 else match pfx.evex_ll {
            0 => 4, 1 => 8, 2 => 16, 3 => raise_UD(),
          };
          let src = modrm_xrm_evex(modrm, pfx, disp_n);
          match pfx.evex_ll {
            0 => evex_write(dst, evex_wmask(pfx, 2), avx_cvttph2uqq(2, decode_scalar_src(32, src))),
            1 => evex_write(dst, evex_wmask(pfx, 4), avx_cvttph2uqq(4, decode_scalar_src(64, src))),
            2 => evex_write(dst, evex_wmask(pfx, 8), avx_cvttph2uqq(8, evex_bcast_src(128, src, pfx, 16))),
            3 => raise_UD(),
          }
        },
        MP_F3 => {
          // VCVTTSH2USI: scalar FP16 to unsigned int (truncation)
          let src = modrm_xrm_evex(modrm, pfx, 2);
          let dst_gpr = modrm_reg(modrm, pfx);
          let src : word = decode_scalar_src(src);
          if pfx.vex_w then
            v(dst_gpr) = __f16_to_uint64_trunc(src)
          else
            v(dst_gpr) = __f16_to_uint32_trunc(src)
        },
        _ => raise_UD(),
      }
    },

    // MAP5 0x79: VCVTPH2UDQ (NP), VCVTPH2UQQ (66), VCVTSH2USI (F3)
    121 => {
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      match mp {
        MP_NONE => {
          // VCVTPH2UDQ: packed FP16 to uint32 (rounding)
          let disp_n : range(2, 32) = if pfx.evex_b then 2 else match pfx.evex_ll {
            0 => 8, 1 => 16, 2 => 32, 3 => raise_UD(),
          };
          let src = modrm_xrm_evex(modrm, pfx, disp_n);
          let (eff_ll, saved) = evex_begin_rc_xrm(pfx, src);
          match eff_ll {
            0 => evex_write(dst, evex_wmask(pfx, 4), avx_cvtph2udq(4, decode_scalar_src(64, src))),
            1 => evex_write(dst, evex_wmask(pfx, 8), avx_cvtph2udq(8, evex_bcast_src(128, src, pfx, 16))),
            2 => evex_write(dst, evex_wmask(pfx, 16), avx_cvtph2udq(16, evex_bcast_src(256, src, pfx, 16))),
            3 => raise_UD(),
          };
          evex_end_rc(saved)
        },
        MP_66 => {
          // VCVTPH2UQQ: packed FP16 to uint64 (rounding)
          let disp_n : range(2, 16) = if pfx.evex_b then 2 else match pfx.evex_ll {
            0 => 4, 1 => 8, 2 => 16, 3 => raise_UD(),
          };
          let src = modrm_xrm_evex(modrm, pfx, disp_n);
          let (eff_ll, saved) = evex_begin_rc_xrm(pfx, src);
          match eff_ll {
            0 => evex_write(dst, evex_wmask(pfx, 2), avx_cvtph2uqq(2, decode_scalar_src(32, src))),
            1 => evex_write(dst, evex_wmask(pfx, 4), avx_cvtph2uqq(4, decode_scalar_src(64, src))),
            2 => evex_write(dst, evex_wmask(pfx, 8), avx_cvtph2uqq(8, evex_bcast_src(128, src, pfx, 16))),
            3 => raise_UD(),
          };
          evex_end_rc(saved)
        },
        MP_F3 => {
          // VCVTSH2USI: scalar FP16 to unsigned int (rounding)
          let src = modrm_xrm_evex(modrm, pfx, 2);
          let dst_gpr = modrm_reg(modrm, pfx);
          let src : word = decode_scalar_src(src);
          if pfx.vex_w then
            v(dst_gpr) = __f16_to_uint64(src)
          else
            v(dst_gpr) = __f16_to_uint32(src)
        },
        _ => raise_UD(),
      }
    },

    // MAP5 0x7A: VCVTTPH2QQ (66), VCVTUDQ2PH (F2/W0), VCVTUQQ2PH (F2/W1)
    122 => {
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      match mp {
        MP_66 => {
          // VCVTTPH2QQ: packed FP16 to int64 (truncation)
          let disp_n : range(2, 16) = if pfx.evex_b then 2 else match pfx.evex_ll {
            0 => 4, 1 => 8, 2 => 16, 3 => raise_UD(),
          };
          let src = modrm_xrm_evex(modrm, pfx, disp_n);
          match pfx.evex_ll {
            0 => evex_write(dst, evex_wmask(pfx, 2), avx_cvttph2qq(2, decode_scalar_src(32, src))),
            1 => evex_write(dst, evex_wmask(pfx, 4), avx_cvttph2qq(4, decode_scalar_src(64, src))),
            2 => evex_write(dst, evex_wmask(pfx, 8), avx_cvttph2qq(8, evex_bcast_src(128, src, pfx, 16))),
            3 => raise_UD(),
          }
        },
        MP_F2 => {
          let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
          let (eff_ll, saved) = evex_begin_rc_xrm(pfx, src);
          if pfx.vex_w then {
            // VCVTUQQ2PH: packed uint64 to FP16
            match eff_ll {
              0 => evex_write(dst, evex_wmask(pfx, 2), avx_cvtuqq2ph(2, evex_bcast_src(128, src, pfx, 64))),
              1 => evex_write(dst, evex_wmask(pfx, 4), avx_cvtuqq2ph(4, evex_bcast_src(256, src, pfx, 64))),
              2 => evex_write(dst, evex_wmask(pfx, 8), avx_cvtuqq2ph(8, evex_bcast_src(512, src, pfx, 64))),
              3 => raise_UD(),
            }
          } else {
            // VCVTUDQ2PH: packed uint32 to FP16
            match eff_ll {
              0 => evex_write(dst, evex_wmask(pfx, 4), avx_cvtudq2ph(4, evex_bcast_src(128, src, pfx, 32))),
              1 => evex_write(dst, evex_wmask(pfx, 8), avx_cvtudq2ph(8, evex_bcast_src(256, src, pfx, 32))),
              2 => evex_write(dst, evex_wmask(pfx, 16), avx_cvtudq2ph(16, evex_bcast_src(512, src, pfx, 32))),
              3 => raise_UD(),
            }
          };
          evex_end_rc(saved)
        },
        _ => raise_UD(),
      }
    },

    // MAP5 0x7B: VCVTPH2QQ (66), VCVTUSI2SH (F3)
    123 => {
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      match mp {
        MP_66 => {
          // VCVTPH2QQ: packed FP16 to int64 (rounding)
          let disp_n : range(2, 16) = if pfx.evex_b then 2 else match pfx.evex_ll {
            0 => 4, 1 => 8, 2 => 16, 3 => raise_UD(),
          };
          let src = modrm_xrm_evex(modrm, pfx, disp_n);
          let (eff_ll, saved) = evex_begin_rc_xrm(pfx, src);
          match eff_ll {
            0 => evex_write(dst, evex_wmask(pfx, 2), avx_cvtph2qq(2, decode_scalar_src(32, src))),
            1 => evex_write(dst, evex_wmask(pfx, 4), avx_cvtph2qq(4, decode_scalar_src(64, src))),
            2 => evex_write(dst, evex_wmask(pfx, 8), avx_cvtph2qq(8, evex_bcast_src(128, src, pfx, 16))),
            3 => raise_UD(),
          };
          evex_end_rc(saved)
        },
        MP_F3 => {
          // VCVTUSI2SH: unsigned int to scalar FP16
          let src = modrm_rm_evex(modrm, pfx, if pfx.vex_w then 8 else 4);
          let src1 : xmmword = read_simd(pfx.evex_vvvvv);
          if pfx.vex_w then {
            // VCVTUSI2SH r64 → FP16
            let x : qword = v(src);
            let r : word = __uint64_to_f16(x);
            evex_write_scalar(dst, src1[127..16] @ r, pfx, 16)
          } else {
            // VCVTUSI2SH r32 → FP16
            let x : dword = v(src);
            let r : word = __uint32_to_f16(x);
            evex_write_scalar(dst, src1[127..16] @ r, pfx, 16)
          }
        },
        _ => raise_UD(),
      }
    },

    // MAP5 0x7C: VCVTTPH2UW (NP), VCVTTPH2W (66)
    124 => {
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
      let op : PackedUnaryOp = match mp {
        MP_NONE => PU_CvtTPH2UW,
        MP_66   => PU_CvtTPH2W,
        _       => raise_UD(),
      };
      let vl = evex_vl(pfx);
      evex_write(dst, evex_wmask(pfx, vl / 16),
                 packed_unop(op, 16, evex_bcast_src(vl, src, pfx, 16)))
    },

    // MAP5 0x7D: VCVTPH2UW (NP), VCVTPH2W (66), VCVTW2PH (F3), VCVTUW2PH (F2)
    125 => {
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
      let op : PackedUnaryOp = match mp {
        MP_NONE => PU_CvtPH2UW,
        MP_66   => PU_CvtPH2W,
        MP_F3   => PU_CvtW2PH,
        MP_F2   => PU_CvtUW2PH,
      };
      let (eff_ll, saved) = evex_begin_rc_xrm(pfx, src);
      let vl = ll_to_vl(eff_ll);
      evex_write(dst, evex_wmask(pfx, vl / 16),
                 packed_unop(op, 16, evex_bcast_src(vl, src, pfx, 16)));
      evex_end_rc(saved)
    },

    // MAP5 0x7E: VMOVW (66) — store XMM low 16-bit to mem/GPR
    126 => {
      if mp != MP_66 then raise_UD();
      let modrm = fetch(1);
      let src = evex_reg_idx(modrm, pfx);
      let dest = modrm_rm_evex(modrm, pfx, 2);
      let x : word = read_simd(128, src)[15..0];
      match dest {
        RM_mem(m) => v(m) = x,
        RM_reg(_) => {
          let dst_gpr = modrm_rm_reg(modrm, pfx);
          v(dst_gpr) = zero_extend(32, x)
        },
      }
    },

    // MAP5 0x1D: VCVTPS2PHX (66, W=0) / VCVTSS2SH (NP, W=0)
    29 => {
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      match mp {
        MP_66 => {
          // VCVTPS2PHX: packed FP32 to FP16 (EVEX.66.MAP5.W0)
          let disp_n : range(4, 64) = if pfx.evex_b then 4 else match pfx.evex_ll {
            0 => 16, 1 => 32, 2 => 64, 3 => raise_UD(),
          };
          let src = modrm_xrm_evex(modrm, pfx, disp_n);
          let (eff_ll, saved) = evex_begin_rc_xrm(pfx, src);
          match eff_ll {
            0 => evex_write(dst, evex_wmask(pfx, 4), avx_cvtps2ph(4, evex_bcast_src(128, src, pfx, 32))),
            1 => evex_write(dst, evex_wmask(pfx, 8), avx_cvtps2ph(8, evex_bcast_src(256, src, pfx, 32))),
            2 => evex_write(dst, evex_wmask(pfx, 16), avx_cvtps2ph(16, evex_bcast_src(512, src, pfx, 32))),
            3 => raise_UD(),
          };
          evex_end_rc(saved)
        },
        MP_NONE => {
          // VCVTSS2SH: scalar FP32 to FP16 (EVEX.NP.MAP5.W0)
          let src = modrm_xrm_evex(modrm, pfx, 4);
          let src1 : xmmword = read_simd(pfx.evex_vvvvv);
          let src2 : dword = decode_scalar_src(32, src);
          let r : word = __f32_to_f16(src2);
          evex_write_scalar(dst, src1[127..16] @ r, pfx, 16)
        },
        _ => raise_UD(),
      }
    },

    _ => raise_UD(),
  }
}

// =========================================================================
// EVEX MAP6 dispatch — FP16 FMA and special operations (66 prefix, W=0)
// =========================================================================

// FP16 FMA element-wise helpers
// EVEX FP16 packed FMADDSUB/FMSUBADD helper
val evex_exec_fmaddsub16_packed : (bool, FMAOrder, Prefixes) -> unit
function evex_exec_fmaddsub16_packed(is_addsub, order, pfx) = {
  let modrm = fetch(1);
  let dst = evex_reg_idx(modrm, pfx);
  let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
  let (eff_ll, saved) = evex_begin_rc_xrm(pfx, src);
  let vl = ll_to_vl(eff_ll);
  let d = read_simd(vl, dst);
  let v = read_simd(vl, pfx.evex_vvvvv);
  let r = evex_bcast_src(vl, src, pfx, 16);
  let mask = evex_wmask(pfx, vl / 16);
  match order {
    FMA_132 => evex_write(dst, mask, if is_addsub then avx_fmaddsub(16, d, r, v) else avx_fmsubadd(16, d, r, v)),
    FMA_213 => evex_write(dst, mask, if is_addsub then avx_fmaddsub(16, v, d, r) else avx_fmsubadd(16, v, d, r)),
    FMA_231 => evex_write(dst, mask, if is_addsub then avx_fmaddsub(16, v, r, d) else avx_fmsubadd(16, v, r, d)),
  };
  evex_end_rc(saved)
}

// EVEX FP16 scalar FMA helper
val evex_exec_fma16_scalar : (PackedTernaryOp, FMAOrder, Prefixes) -> unit
function evex_exec_fma16_scalar(op, order, pfx) = {
  let modrm = fetch(1);
  let dst = evex_reg_idx(modrm, pfx);
  let src = modrm_xrm_evex(modrm, pfx, 2);
  let src1 : xmmword = read_simd(pfx.evex_vvvvv);
  let d : word = read_simd(128, dst)[15..0];
  let r : word = decode_scalar_src(16, src);
  let result : word = match order {
    FMA_132 => packed_ternary_elem(op, d, r, src1[15..0]),
    FMA_213 => packed_ternary_elem(op, src1[15..0], d, r),
    FMA_231 => packed_ternary_elem(op, src1[15..0], r, d),
  };
  // Scalar FMA keeps DEST[127:16] (unlike the two-source scalar ops,
  // which take the upper bits from src1).
  evex_write_scalar(dst, read_simd(128, dst)[127..16] @ result, pfx, 16)
}

// EVEX FP16 packed FMA helper: decode, apply packed ternary op with {er}
val evex_exec_fma16_packed : (PackedTernaryOp, FMAOrder, Prefixes) -> unit
function evex_exec_fma16_packed(op, order, pfx) = {
  let modrm = fetch(1);
  let dst = evex_reg_idx(modrm, pfx);
  let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
  let (eff_ll, saved) = evex_begin_rc_xrm(pfx, src);
  let vl = ll_to_vl(eff_ll);
  let d = read_simd(vl, dst);
  let v = read_simd(vl, pfx.evex_vvvvv);
  let r = evex_bcast_src(vl, src, pfx, 16);
  let mask = evex_wmask(pfx, vl / 16);
  match order {
    FMA_132 => evex_write(dst, mask, packed_ternop(op, 16, d, r, v)),
    FMA_213 => evex_write(dst, mask, packed_ternop(op, 16, v, d, r)),
    FMA_231 => evex_write(dst, mask, packed_ternop(op, 16, v, r, d)),
  };
  evex_end_rc(saved)
}

val dispatch_evex_map6 : (byte, Prefixes) -> unit
function dispatch_evex_map6(opcode, pfx) = {
  let mp = get_mandatory_prefix(pfx);
  let op : range(0, 255) = unsigned(opcode);

  match op {

    // MAP6 0x98: VFMADD132PH (66, W=0)
    152 => { if mp != MP_66 then raise_UD(); evex_exec_fma16_packed(PT_FMAdd, FMA_132, pfx) },

    // MAP6 0xA8: VFMADD213PH (66, W=0)
    168 => { if mp != MP_66 then raise_UD(); evex_exec_fma16_packed(PT_FMAdd, FMA_213, pfx) },

    // MAP6 0xB8: VFMADD231PH (66, W=0)
    184 => { if mp != MP_66 then raise_UD(); evex_exec_fma16_packed(PT_FMAdd, FMA_231, pfx) },

    // MAP6 0x9A: VFMSUB132PH (66, W=0)
    154 => { if mp != MP_66 then raise_UD(); evex_exec_fma16_packed(PT_FMSub, FMA_132, pfx) },

    // MAP6 0xAA: VFMSUB213PH (66, W=0)
    170 => { if mp != MP_66 then raise_UD(); evex_exec_fma16_packed(PT_FMSub, FMA_213, pfx) },

    // MAP6 0xBA: VFMSUB231PH (66, W=0)
    186 => { if mp != MP_66 then raise_UD(); evex_exec_fma16_packed(PT_FMSub, FMA_231, pfx) },

    // MAP6 0x9C: VFNMADD132PH (66, W=0)
    156 => { if mp != MP_66 then raise_UD(); evex_exec_fma16_packed(PT_FNMAdd, FMA_132, pfx) },

    // MAP6 0xAC: VFNMADD213PH (66, W=0)
    172 => { if mp != MP_66 then raise_UD(); evex_exec_fma16_packed(PT_FNMAdd, FMA_213, pfx) },

    // MAP6 0xBC: VFNMADD231PH (66, W=0)
    188 => { if mp != MP_66 then raise_UD(); evex_exec_fma16_packed(PT_FNMAdd, FMA_231, pfx) },

    // MAP6 0x9E: VFNMSUB132PH (66, W=0)
    158 => { if mp != MP_66 then raise_UD(); evex_exec_fma16_packed(PT_FNMSub, FMA_132, pfx) },

    // MAP6 0xAE: VFNMSUB213PH (66, W=0)
    174 => { if mp != MP_66 then raise_UD(); evex_exec_fma16_packed(PT_FNMSub, FMA_213, pfx) },

    // MAP6 0xBE: VFNMSUB231PH (66, W=0)
    190 => { if mp != MP_66 then raise_UD(); evex_exec_fma16_packed(PT_FNMSub, FMA_231, pfx) },

    // MAP6 0x13: VCVTPH2PSX (66, W=0) / VCVTSH2SS (NP, W=0)
    19 => {
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      match mp {
        MP_66 => {
          // VCVTPH2PSX: packed FP16 to FP32
          let disp_n : range(2, 32) = if pfx.evex_b then 2 else match pfx.evex_ll {
            0 => 8, 1 => 16, 2 => 32, 3 => raise_UD(),
          };
          let src = modrm_xrm_evex(modrm, pfx, disp_n);
          match pfx.evex_ll {
            0 => evex_write(dst, evex_wmask(pfx, 4), avx_cvtph2ps(4, decode_scalar_src(64, src))),
            1 => evex_write(dst, evex_wmask(pfx, 8), avx_cvtph2ps(8, evex_bcast_src(128, src, pfx, 16))),
            2 => evex_write(dst, evex_wmask(pfx, 16), avx_cvtph2ps(16, evex_bcast_src(256, src, pfx, 16))),
            3 => raise_UD(),
          }
        },
        MP_NONE => {
          // VCVTSH2SS: scalar FP16 to FP32 (EVEX.LLIG.NP.MAP6.W0 13)
          let src = modrm_xrm_evex(modrm, pfx, 2);
          let src1 : xmmword = read_simd(pfx.evex_vvvvv);
          let src2 : word = decode_scalar_src(src);
          let r : dword = __f16_to_f32(src2);
          // DEST.fp32[0] is under the writemask; DEST[127:32] := SRC1[127:32]
          evex_write_scalar(dst, src1[127..32] @ r, pfx, 32)
        },
        _ => raise_UD(),
      }
    },

    // MAP6 0x2C: VSCALEFPH (66, W=0)
    44 => {
      if mp != MP_66 then raise_UD();
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
      let (eff_ll, saved) = evex_begin_rc_xrm(pfx, src);
      let vl = ll_to_vl(eff_ll);
      evex_write(dst, evex_wmask(pfx, vl / 16),
                 packed_binop(PB_FPScalef, 16, read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(vl, src, pfx, 16)));
      evex_end_rc(saved)
    },

    // MAP6 0x2D: VSCALEFSH (66, W=0)
    45 => {
      if mp != MP_66 then raise_UD();
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_xrm_evex(modrm, pfx, 2);
      let src1 : xmmword = read_simd(pfx.evex_vvvvv);
      let src2 : word = decode_scalar_src(16, src);
      let r : word = fp_scalef(src1[15..0], src2);
      evex_write_scalar(dst, src1[127..16] @ r, pfx, 16)
    },

    // MAP6 0x42: VGETEXPPH (66, W=0)
    66 => {
      if mp != MP_66 then raise_UD();
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
      let vl = evex_vl(pfx);
      evex_write(dst, evex_wmask(pfx, vl / 16),
                 packed_unop(PU_FPGetexp, 16, evex_bcast_src(vl, src, pfx, 16)))
    },

    // MAP6 0x43: VGETEXPSH (66, W=0)
    67 => {
      if mp != MP_66 then raise_UD();
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_xrm_evex(modrm, pfx, 2);
      let src1 : xmmword = read_simd(pfx.evex_vvvvv);
      let src2 : word = decode_scalar_src(16, src);
      let r : word = fp_getexp(src2);
      evex_write_scalar(dst, src1[127..16] @ r, pfx, 16)
    },

    // MAP6 0x4C: VRCPPH (66, W=0)
    76 => {
      if mp != MP_66 then raise_UD();
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
      let vl = evex_vl(pfx);
      evex_write(dst, evex_wmask(pfx, vl / 16),
                 packed_unop(PU_FRcp, 16, evex_bcast_src(vl, src, pfx, 16)))
    },

    // MAP6 0x4D: VRCPSH (66, W=0)
    77 => {
      if mp != MP_66 then raise_UD();
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_xrm_evex(modrm, pfx, 2);
      let src1 : xmmword = read_simd(pfx.evex_vvvvv);
      let src2 : word = decode_scalar_src(16, src);
      let r : word = fp_rcp(src2);
      evex_write_scalar(dst, src1[127..16] @ r, pfx, 16)
    },

    // MAP6 0x4E: VRSQRTPH (66, W=0)
    78 => {
      if mp != MP_66 then raise_UD();
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
      let vl = evex_vl(pfx);
      evex_write(dst, evex_wmask(pfx, vl / 16),
                 packed_unop(PU_FRsqrt, 16, evex_bcast_src(vl, src, pfx, 16)))
    },

    // MAP6 0x4F: VRSQRTSH (66, W=0)
    79 => {
      if mp != MP_66 then raise_UD();
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_xrm_evex(modrm, pfx, 2);
      let src1 : xmmword = read_simd(pfx.evex_vvvvv);
      let src2 : word = decode_scalar_src(16, src);
      let r : word = fp_rsqrt(src2);
      evex_write_scalar(dst, src1[127..16] @ r, pfx, 16)
    },

    // MAP6 0x96: VFMADDSUB132PH (66, W=0)
    150 => { if mp != MP_66 then raise_UD(); evex_exec_fmaddsub16_packed(true, FMA_132, pfx) },

    // MAP6 0x97: VFMSUBADD132PH (66, W=0)
    151 => { if mp != MP_66 then raise_UD(); evex_exec_fmaddsub16_packed(false, FMA_132, pfx) },

    // MAP6 0x99: VFMADD132SH (66, W=0)
    153 => { if mp != MP_66 then raise_UD(); evex_exec_fma16_scalar(PT_FMAdd, FMA_132, pfx) },

    // MAP6 0x9B: VFMSUB132SH (66, W=0)
    155 => { if mp != MP_66 then raise_UD(); evex_exec_fma16_scalar(PT_FMSub, FMA_132, pfx) },

    // MAP6 0x9D: VFNMADD132SH (66, W=0)
    157 => { if mp != MP_66 then raise_UD(); evex_exec_fma16_scalar(PT_FNMAdd, FMA_132, pfx) },

    // MAP6 0x9F: VFNMSUB132SH (66, W=0)
    159 => { if mp != MP_66 then raise_UD(); evex_exec_fma16_scalar(PT_FNMSub, FMA_132, pfx) },

    // MAP6 0xA6: VFMADDSUB213PH (66, W=0)
    166 => { if mp != MP_66 then raise_UD(); evex_exec_fmaddsub16_packed(true, FMA_213, pfx) },

    // MAP6 0xA7: VFMSUBADD213PH (66, W=0)
    167 => { if mp != MP_66 then raise_UD(); evex_exec_fmaddsub16_packed(false, FMA_213, pfx) },

    // MAP6 0xA9: VFMADD213SH (66, W=0)
    169 => { if mp != MP_66 then raise_UD(); evex_exec_fma16_scalar(PT_FMAdd, FMA_213, pfx) },

    // MAP6 0xAB: VFMSUB213SH (66, W=0)
    171 => { if mp != MP_66 then raise_UD(); evex_exec_fma16_scalar(PT_FMSub, FMA_213, pfx) },

    // MAP6 0xAD: VFNMADD213SH (66, W=0)
    173 => { if mp != MP_66 then raise_UD(); evex_exec_fma16_scalar(PT_FNMAdd, FMA_213, pfx) },

    // MAP6 0xAF: VFNMSUB213SH (66, W=0)
    175 => { if mp != MP_66 then raise_UD(); evex_exec_fma16_scalar(PT_FNMSub, FMA_213, pfx) },

    // MAP6 0xB6: VFMADDSUB231PH (66, W=0)
    182 => { if mp != MP_66 then raise_UD(); evex_exec_fmaddsub16_packed(true, FMA_231, pfx) },

    // MAP6 0xB7: VFMSUBADD231PH (66, W=0)
    183 => { if mp != MP_66 then raise_UD(); evex_exec_fmaddsub16_packed(false, FMA_231, pfx) },

    // MAP6 0xB9: VFMADD231SH (66, W=0)
    185 => { if mp != MP_66 then raise_UD(); evex_exec_fma16_scalar(PT_FMAdd, FMA_231, pfx) },

    // MAP6 0xBB: VFMSUB231SH (66, W=0)
    187 => { if mp != MP_66 then raise_UD(); evex_exec_fma16_scalar(PT_FMSub, FMA_231, pfx) },

    // MAP6 0xBD: VFNMADD231SH (66, W=0)
    189 => { if mp != MP_66 then raise_UD(); evex_exec_fma16_scalar(PT_FNMAdd, FMA_231, pfx) },

    // MAP6 0xBF: VFNMSUB231SH (66, W=0)
    191 => { if mp != MP_66 then raise_UD(); evex_exec_fma16_scalar(PT_FNMSub, FMA_231, pfx) },

    // MAP6 0x56: VFCMADDCPH (F2, W=0) / VFMADDCPH (F3, W=0) — complex multiply-accumulate
    86 => {
      if pfx.vex_w then raise_UD();
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let is_mem : bool = match src { XRM_mem(_) => true, _ => false };
      let conj : bool = (mp == MP_F2);
      if mp != MP_F2 & mp != MP_F3 then raise_UD();
      match pfx.evex_ll {
        0 => {
          let acc : xmmword = read_simd(dst);
          let r = cfmaddcph(read_simd(pfx.evex_vvvvv), evex_bcast_src(128, src, pfx, 32), acc, conj);
          evex_write(dst, evex_wmask(pfx, 4), r)
        },
        1 => {
          let acc : ymmword = read_simd(dst);
          let r = cfmaddcph(read_simd(256, pfx.evex_vvvvv), evex_bcast_src(256, src, pfx, 32), acc, conj);
          evex_write(dst, evex_wmask(pfx, 8), r)
        },
        2 => {
          let acc : zmmword = read_simd(dst);
          let r = cfmaddcph(ZMM[pfx.evex_vvvvv], evex_bcast_src(512, src, pfx, 32), acc, conj);
          evex_write(dst, evex_wmask(pfx, 16), r)
        },
        3 => raise_UD(),
      }
    },

    // MAP6 0x57: VFCMADDCSH (F2, W=0) / VFMADDCSH (F3, W=0) — scalar complex multiply-accumulate
    87 => {
      if pfx.vex_w then raise_UD();
      let conj : bool = (mp == MP_F2);
      if mp != MP_F2 & mp != MP_F3 then raise_UD();
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_xrm_evex(modrm, pfx, 4);
      let src1 : xmmword = read_simd(pfx.evex_vvvvv);
      let src2 : dword = decode_scalar_src(32, src);
      let acc : xmmword = read_simd(dst);
      let s1_re : word = src1[15..0];
      let s1_im : word = src1[31..16];
      let s2_re : word = src2[15..0];
      let s2_im : word = src2[31..16];
      let a_re : word = acc[15..0];
      let a_im : word = acc[31..16];
      let tmp_re : word = fp_fmadd(s1_re, s2_re, a_re);
      let tmp_im : word = fp_fmadd(s1_im, s2_re, a_im);
      let (r_re, r_im) : (word, word) = if conj then
        (fp_fmadd(s1_im, s2_im, tmp_re), fp_fnmadd(s1_re, s2_im, tmp_im))
      else
        (fp_fnmadd(s1_im, s2_im, tmp_re), fp_fmadd(s1_re, s2_im, tmp_im));
      write_simd(128, dst, src1[127..32] @ r_im @ r_re)
    },

    // MAP6 0xD6: VFCMULCPH (F2, W=0) / VFMULCPH (F3, W=0) — complex multiply
    214 => {
      if pfx.vex_w then raise_UD();
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let is_mem : bool = match src { XRM_mem(_) => true, _ => false };
      let conj : bool = (mp == MP_F2);
      if mp != MP_F2 & mp != MP_F3 then raise_UD();
      match pfx.evex_ll {
        0 => {
          let r = cfmulcph(read_simd(pfx.evex_vvvvv), evex_bcast_src(128, src, pfx, 32), conj);
          evex_write(dst, evex_wmask(pfx, 4), r)
        },
        1 => {
          let r = cfmulcph(read_simd(256, pfx.evex_vvvvv), evex_bcast_src(256, src, pfx, 32), conj);
          evex_write(dst, evex_wmask(pfx, 8), r)
        },
        2 => {
          let r = cfmulcph(ZMM[pfx.evex_vvvvv], evex_bcast_src(512, src, pfx, 32), conj);
          evex_write(dst, evex_wmask(pfx, 16), r)
        },
        3 => raise_UD(),
      }
    },

    // MAP6 0xD7: VFCMULCSH (F2, W=0) / VFMULCSH (F3, W=0) — scalar complex multiply
    215 => {
      if pfx.vex_w then raise_UD();
      let conj : bool = (mp == MP_F2);
      if mp != MP_F2 & mp != MP_F3 then raise_UD();
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_xrm_evex(modrm, pfx, 4);
      let src1 : xmmword = read_simd(pfx.evex_vvvvv);
      let src2 : dword = decode_scalar_src(32, src);
      let s1_re : word = src1[15..0];
      let s1_im : word = src1[31..16];
      let s2_re : word = src2[15..0];
      let s2_im : word = src2[31..16];
      let tmp_re : word = fp_mul(s1_re, s2_re);
      let tmp_im : word = fp_mul(s1_im, s2_re);
      let (r_re, r_im) : (word, word) = if conj then
        (fp_fmadd(s1_im, s2_im, tmp_re), fp_fnmadd(s1_re, s2_im, tmp_im))
      else
        (fp_fnmadd(s1_im, s2_im, tmp_re), fp_fmadd(s1_re, s2_im, tmp_im));
      write_simd(128, dst, src1[127..32] @ r_im @ r_re)
    },

    _ => raise_UD(),
  }
}

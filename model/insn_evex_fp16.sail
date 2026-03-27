// x86-64 — EVEX FP16 Operations (MAP5 and MAP6)
//
// Half-precision (16-bit) packed and scalar floating-point arithmetic,
// conversions, and special operations.

// Get 32-bit writemask for FP16 ZMM (32 lanes)
val evex_get_mask32 : Prefixes -> dword
function evex_get_mask32(pfx) = evex_kmask64(pfx)[31..0]

// =========================================================================
// FP16 broadcast helpers
// =========================================================================


// =========================================================================
// FP16 special operation helpers (unary)
// =========================================================================

val vgetexpph_xmm : xmmword -> xmmword
function vgetexpph_xmm(a) =
  __f16_getexp(a[127..112]) @ __f16_getexp(a[111..96]) @
  __f16_getexp(a[95..80]) @ __f16_getexp(a[79..64]) @
  __f16_getexp(a[63..48]) @ __f16_getexp(a[47..32]) @
  __f16_getexp(a[31..16]) @ __f16_getexp(a[15..0])
val vgetexpph_ymm : ymmword -> ymmword
function vgetexpph_ymm(a) = vgetexpph_xmm(a[255..128]) @ vgetexpph_xmm(a[127..0])
val vgetexpph_zmm : zmmword -> zmmword
function vgetexpph_zmm(a) = vgetexpph_ymm(a[511..256]) @ vgetexpph_ymm(a[255..0])

val vrcpph_xmm : xmmword -> xmmword
function vrcpph_xmm(a) =
  __f16_rcp(a[127..112]) @ __f16_rcp(a[111..96]) @
  __f16_rcp(a[95..80]) @ __f16_rcp(a[79..64]) @
  __f16_rcp(a[63..48]) @ __f16_rcp(a[47..32]) @
  __f16_rcp(a[31..16]) @ __f16_rcp(a[15..0])
val vrcpph_ymm : ymmword -> ymmword
function vrcpph_ymm(a) = vrcpph_xmm(a[255..128]) @ vrcpph_xmm(a[127..0])
val vrcpph_zmm : zmmword -> zmmword
function vrcpph_zmm(a) = vrcpph_ymm(a[511..256]) @ vrcpph_ymm(a[255..0])

val vrsqrtph_xmm : xmmword -> xmmword
function vrsqrtph_xmm(a) =
  __f16_rsqrt(a[127..112]) @ __f16_rsqrt(a[111..96]) @
  __f16_rsqrt(a[95..80]) @ __f16_rsqrt(a[79..64]) @
  __f16_rsqrt(a[63..48]) @ __f16_rsqrt(a[47..32]) @
  __f16_rsqrt(a[31..16]) @ __f16_rsqrt(a[15..0])
val vrsqrtph_ymm : ymmword -> ymmword
function vrsqrtph_ymm(a) = vrsqrtph_xmm(a[255..128]) @ vrsqrtph_xmm(a[127..0])
val vrsqrtph_zmm : zmmword -> zmmword
function vrsqrtph_zmm(a) = vrsqrtph_ymm(a[511..256]) @ vrsqrtph_ymm(a[255..0])

// =========================================================================
// FP16 special operation helpers (binary: scalef)
// =========================================================================

val vscalefph_xmm : (xmmword, xmmword) -> xmmword
function vscalefph_xmm(a, b) =
  __f16_scalef(a[127..112], b[127..112]) @ __f16_scalef(a[111..96], b[111..96]) @
  __f16_scalef(a[95..80], b[95..80]) @ __f16_scalef(a[79..64], b[79..64]) @
  __f16_scalef(a[63..48], b[63..48]) @ __f16_scalef(a[47..32], b[47..32]) @
  __f16_scalef(a[31..16], b[31..16]) @ __f16_scalef(a[15..0], b[15..0])
val vscalefph_ymm : (ymmword, ymmword) -> ymmword
function vscalefph_ymm(a, b) = vscalefph_xmm(a[255..128], b[255..128]) @ vscalefph_xmm(a[127..0], b[127..0])
val vscalefph_zmm : (zmmword, zmmword) -> zmmword
function vscalefph_zmm(a, b) = vscalefph_ymm(a[511..256], b[511..256]) @ vscalefph_ymm(a[255..0], b[255..0])

// =========================================================================
// FP16 imm8 operation helpers (rndscale, getmant, reduce)
// =========================================================================

val vrndscaleph_xmm : (xmmword, byte) -> xmmword
function vrndscaleph_xmm(a, imm) =
  __f16_rndscale(a[127..112], imm) @ __f16_rndscale(a[111..96], imm) @
  __f16_rndscale(a[95..80], imm) @ __f16_rndscale(a[79..64], imm) @
  __f16_rndscale(a[63..48], imm) @ __f16_rndscale(a[47..32], imm) @
  __f16_rndscale(a[31..16], imm) @ __f16_rndscale(a[15..0], imm)
val vrndscaleph_ymm : (ymmword, byte) -> ymmword
function vrndscaleph_ymm(a, imm) = vrndscaleph_xmm(a[255..128], imm) @ vrndscaleph_xmm(a[127..0], imm)
val vrndscaleph_zmm : (zmmword, byte) -> zmmword
function vrndscaleph_zmm(a, imm) = vrndscaleph_ymm(a[511..256], imm) @ vrndscaleph_ymm(a[255..0], imm)

val vgetmantph_xmm : (xmmword, byte) -> xmmword
function vgetmantph_xmm(a, imm) =
  __f16_getmant(a[127..112], imm) @ __f16_getmant(a[111..96], imm) @
  __f16_getmant(a[95..80], imm) @ __f16_getmant(a[79..64], imm) @
  __f16_getmant(a[63..48], imm) @ __f16_getmant(a[47..32], imm) @
  __f16_getmant(a[31..16], imm) @ __f16_getmant(a[15..0], imm)
val vgetmantph_ymm : (ymmword, byte) -> ymmword
function vgetmantph_ymm(a, imm) = vgetmantph_xmm(a[255..128], imm) @ vgetmantph_xmm(a[127..0], imm)
val vgetmantph_zmm : (zmmword, byte) -> zmmword
function vgetmantph_zmm(a, imm) = vgetmantph_ymm(a[511..256], imm) @ vgetmantph_ymm(a[255..0], imm)

val vreduceph_xmm : (xmmword, byte) -> xmmword
function vreduceph_xmm(a, imm) =
  __f16_reduce(a[127..112], imm) @ __f16_reduce(a[111..96], imm) @
  __f16_reduce(a[95..80], imm) @ __f16_reduce(a[79..64], imm) @
  __f16_reduce(a[63..48], imm) @ __f16_reduce(a[47..32], imm) @
  __f16_reduce(a[31..16], imm) @ __f16_reduce(a[15..0], imm)
val vreduceph_ymm : (ymmword, byte) -> ymmword
function vreduceph_ymm(a, imm) = vreduceph_xmm(a[255..128], imm) @ vreduceph_xmm(a[127..0], imm)
val vreduceph_zmm : (zmmword, byte) -> zmmword
function vreduceph_zmm(a, imm) = vreduceph_ymm(a[511..256], imm) @ vreduceph_ymm(a[255..0], imm)

// =========================================================================
// FP16 FMADDSUB/FMSUBADD helpers
// FMADDSUB: even elements subtract, odd elements add
// FMSUBADD: even elements add, odd elements subtract
// =========================================================================

val vfmaddsubph_xmm : (xmmword, xmmword, xmmword) -> xmmword
function vfmaddsubph_xmm(a, b, c) =
  __f16_fmadd(a[127..112], b[127..112], c[127..112]) @
  __f16_fmsub(a[111..96], b[111..96], c[111..96]) @
  __f16_fmadd(a[95..80], b[95..80], c[95..80]) @
  __f16_fmsub(a[79..64], b[79..64], c[79..64]) @
  __f16_fmadd(a[63..48], b[63..48], c[63..48]) @
  __f16_fmsub(a[47..32], b[47..32], c[47..32]) @
  __f16_fmadd(a[31..16], b[31..16], c[31..16]) @
  __f16_fmsub(a[15..0], b[15..0], c[15..0])
val vfmaddsubph_ymm : (ymmword, ymmword, ymmword) -> ymmword
function vfmaddsubph_ymm(a, b, c) =
  vfmaddsubph_xmm(a[255..128], b[255..128], c[255..128]) @
  vfmaddsubph_xmm(a[127..0], b[127..0], c[127..0])
val vfmaddsubph_zmm : (zmmword, zmmword, zmmword) -> zmmword
function vfmaddsubph_zmm(a, b, c) =
  vfmaddsubph_ymm(a[511..256], b[511..256], c[511..256]) @
  vfmaddsubph_ymm(a[255..0], b[255..0], c[255..0])

val vfmsubaddph_xmm : (xmmword, xmmword, xmmword) -> xmmword
function vfmsubaddph_xmm(a, b, c) =
  __f16_fmsub(a[127..112], b[127..112], c[127..112]) @
  __f16_fmadd(a[111..96], b[111..96], c[111..96]) @
  __f16_fmsub(a[95..80], b[95..80], c[95..80]) @
  __f16_fmadd(a[79..64], b[79..64], c[79..64]) @
  __f16_fmsub(a[63..48], b[63..48], c[63..48]) @
  __f16_fmadd(a[47..32], b[47..32], c[47..32]) @
  __f16_fmsub(a[31..16], b[31..16], c[31..16]) @
  __f16_fmadd(a[15..0], b[15..0], c[15..0])
val vfmsubaddph_ymm : (ymmword, ymmword, ymmword) -> ymmword
function vfmsubaddph_ymm(a, b, c) =
  vfmsubaddph_xmm(a[255..128], b[255..128], c[255..128]) @
  vfmsubaddph_xmm(a[127..0], b[127..0], c[127..0])
val vfmsubaddph_zmm : (zmmword, zmmword, zmmword) -> zmmword
function vfmsubaddph_zmm(a, b, c) =
  vfmsubaddph_ymm(a[511..256], b[511..256], c[511..256]) @
  vfmsubaddph_ymm(a[255..0], b[255..0], c[255..0])

// =========================================================================
// FP16 compare predicate helper
// =========================================================================

val cmp_f16_pred : (word, word, range(0, 31)) -> bit
function cmp_f16_pred(a, b, pred) = {
  let c = __compare_sh(a, b);
  let unord : bit = match c { FP_UNORDERED => 0b1, _ => 0b0 };
  let eq : bit = match c { FP_EQ => 0b1, _ => 0b0 };
  let lt : bit = match c { FP_LT => 0b1, _ => 0b0 };
  let le : bit = lt | eq;
  match pred {
    0  => eq,                    // EQ_OQ
    1  => lt,                    // LT_OS
    2  => le,                    // LE_OS
    3  => unord,                 // UNORD_Q
    4  => ~(eq) | unord,         // NEQ_UQ
    5  => ~(lt) | unord,         // NLT_US
    6  => ~(le) | unord,         // NLE_US
    7  => ~(unord),              // ORD_Q
    8  => eq | unord,            // EQ_UQ
    9  => lt | unord,            // NGE_US
    10 => le | unord,            // NGT_US
    11 => 0b0,               // FALSE_OQ
    12 => ~(eq) & ~(unord),      // NEQ_OQ
    13 => ~(lt) & ~(unord),      // GE_OS
    14 => ~(le) & ~(unord),      // GT_OS
    15 => 0b1,                // TRUE_UQ
    16 => eq,                    // EQ_OS
    17 => lt,                    // LT_OQ
    18 => le,                    // LE_OQ
    19 => unord,                 // UNORD_S
    20 => ~(eq) | unord,         // NEQ_US
    21 => ~(lt) | unord,         // NLT_UQ
    22 => ~(le) | unord,         // NLE_UQ
    23 => ~(unord),              // ORD_S
    24 => eq | unord,            // EQ_US
    25 => lt | unord,            // NGE_UQ
    26 => le | unord,            // NGT_UQ
    27 => 0b0,               // FALSE_OS
    28 => ~(eq) & ~(unord),      // NEQ_OS
    29 => ~(lt) & ~(unord),      // GE_OQ
    30 => ~(le) & ~(unord),      // GT_OQ
    31 => 0b1,                // TRUE_US
  }
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

val fpclass_f16 : (word, byte) -> bit
function fpclass_f16(v, imm) = fpclass(v[15], v[14..10], v[9..0], imm)

val vfpclassph_xmm : (xmmword, byte) -> byte
function vfpclassph_xmm(a, imm) =
  fpclass_f16(a[127..112], imm) @
  fpclass_f16(a[111..96], imm) @
  fpclass_f16(a[95..80], imm) @
  fpclass_f16(a[79..64], imm) @
  fpclass_f16(a[63..48], imm) @
  fpclass_f16(a[47..32], imm) @
  fpclass_f16(a[31..16], imm) @
  fpclass_f16(a[15..0], imm)

val vfpclassph_ymm : (ymmword, byte) -> word
function vfpclassph_ymm(a, imm) =
  vfpclassph_xmm(a[255..128], imm) @ vfpclassph_xmm(a[127..0], imm)

val vfpclassph_zmm : (zmmword, byte) -> dword
function vfpclassph_zmm(a, imm) =
  vfpclassph_ymm(a[511..256], imm) @ vfpclassph_ymm(a[255..0], imm)

// =========================================================================
// Complex FP16 multiply/accumulate helpers
// =========================================================================

// Complex multiply-accumulate one pair: dest += src1 * src2 (or conjugate of src2)
// conj=true: conjugate (VFCMADDCPH), conj=false: normal (VFMADDCPH)
val cfmaddcph_pair : (word, word, word, word, word, word, bool) -> (word, word)
function cfmaddcph_pair(s1_re, s1_im, s2_re, s2_im, a_re, a_im, conj) = {
  let tmp_re : word = __f16_fmadd(s1_re, s2_re, a_re);
  let tmp_im : word = __f16_fmadd(s1_im, s2_re, a_im);
  if conj then
    (__f16_fmadd(s1_im, s2_im, tmp_re), __f16_fnmadd(s1_re, s2_im, tmp_im))
  else
    (__f16_fnmadd(s1_im, s2_im, tmp_re), __f16_fmadd(s1_re, s2_im, tmp_im))
}

val cfmaddcph_xmm : (xmmword, xmmword, xmmword, bool) -> xmmword
function cfmaddcph_xmm(src1, src2, acc, conj) = {
  let (r0, i0) = cfmaddcph_pair(src1[15..0], src1[31..16], src2[15..0], src2[31..16], acc[15..0], acc[31..16], conj);
  let (r1, i1) = cfmaddcph_pair(src1[47..32], src1[63..48], src2[47..32], src2[63..48], acc[47..32], acc[63..48], conj);
  let (r2, i2) = cfmaddcph_pair(src1[79..64], src1[95..80], src2[79..64], src2[95..80], acc[79..64], acc[95..80], conj);
  let (r3, i3) = cfmaddcph_pair(src1[111..96], src1[127..112], src2[111..96], src2[127..112], acc[111..96], acc[127..112], conj);
  i3 @ r3 @ i2 @ r2 @ i1 @ r1 @ i0 @ r0
}

val cfmaddcph_ymm : (ymmword, ymmword, ymmword, bool) -> ymmword
function cfmaddcph_ymm(src1, src2, acc, conj) =
  cfmaddcph_xmm(src1[255..128], src2[255..128], acc[255..128], conj) @
  cfmaddcph_xmm(src1[127..0], src2[127..0], acc[127..0], conj)

val cfmaddcph_zmm : (zmmword, zmmword, zmmword, bool) -> zmmword
function cfmaddcph_zmm(src1, src2, acc, conj) =
  cfmaddcph_ymm(src1[511..256], src2[511..256], acc[511..256], conj) @
  cfmaddcph_ymm(src1[255..0], src2[255..0], acc[255..0], conj)

// Complex multiply one pair: dest = src1 * src2 (or conjugate of src2)
val cfmulcph_pair : (word, word, word, word, bool) -> (word, word)
function cfmulcph_pair(s1_re, s1_im, s2_re, s2_im, conj) = {
  let tmp_re : word = __f16_mul(s1_re, s2_re);
  let tmp_im : word = __f16_mul(s1_im, s2_re);
  if conj then
    (__f16_fmadd(s1_im, s2_im, tmp_re), __f16_fnmadd(s1_re, s2_im, tmp_im))
  else
    (__f16_fnmadd(s1_im, s2_im, tmp_re), __f16_fmadd(s1_re, s2_im, tmp_im))
}

val cfmulcph_xmm : (xmmword, xmmword, bool) -> xmmword
function cfmulcph_xmm(src1, src2, conj) = {
  let (r0, i0) = cfmulcph_pair(src1[15..0], src1[31..16], src2[15..0], src2[31..16], conj);
  let (r1, i1) = cfmulcph_pair(src1[47..32], src1[63..48], src2[47..32], src2[63..48], conj);
  let (r2, i2) = cfmulcph_pair(src1[79..64], src1[95..80], src2[79..64], src2[95..80], conj);
  let (r3, i3) = cfmulcph_pair(src1[111..96], src1[127..112], src2[111..96], src2[127..112], conj);
  i3 @ r3 @ i2 @ r2 @ i1 @ r1 @ i0 @ r0
}

val cfmulcph_ymm : (ymmword, ymmword, bool) -> ymmword
function cfmulcph_ymm(src1, src2, conj) =
  cfmulcph_xmm(src1[255..128], src2[255..128], conj) @
  cfmulcph_xmm(src1[127..0], src2[127..0], conj)

val cfmulcph_zmm : (zmmword, zmmword, bool) -> zmmword
function cfmulcph_zmm(src1, src2, conj) =
  cfmulcph_ymm(src1[511..256], src2[511..256], conj) @
  cfmulcph_ymm(src1[255..0], src2[255..0], conj)

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
      let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
      let is_mem : bool = match src { RM_mem(_) => true, _ => false };
      match mp {
        MP_NONE => {
          let (eff_ll, saved) = evex_begin_rc(pfx, ~(is_mem));
          let vl = ll_to_vl(eff_ll);
          let mask = evex_wmask(pfx, vl / 16);
          evex_write(dst, mask, packed_unop(PU_FSqrt, 16, evex_bcast_src(vl, modrm, src, pfx, 16)));
          evex_end_rc(saved)
        },
        MP_F3 => {
          // VSQRTSH: scalar FP16 square root (lowest 16 bits)
          let src1 : xmmword = read_xmm(pfx.evex_vvvvv);
          let src2 : word = match src {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[15..0],
            RM_mem(m) => v(m),
          };
          let r : word = __f16_sqrt(src2);
          evex_write_scalar(dst, src1[127..16] @ r, pfx, 16)
        },
        _ => raise_UD(),
      }
    },

    // MAP5 0x58: VADDPH (NP, W=0) or VADDSH (F3, W=0)
    88 => {
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
      let is_mem : bool = match src { RM_mem(_) => true, _ => false };
      match mp {
        MP_NONE => {
          let (eff_ll, saved) = evex_begin_rc(pfx, ~(is_mem));
          let vl = ll_to_vl(eff_ll);
          let mask = evex_wmask(pfx, vl / 16);
          evex_write(dst, mask, packed_binop(PB_FAdd, 16, read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(modrm, src, pfx, 16)));
          evex_end_rc(saved)
        },
        MP_F3 => {
          // VADDSH: scalar FP16 add (lowest 16 bits)
          let src1 : xmmword = read_xmm(pfx.evex_vvvvv);
          let src2 : word = match src {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[15..0],
            RM_mem(m) => v(m),
          };
          let r : word = __f16_add(src1[15..0], src2);
          let result : xmmword = src1[127..16] @ r;
          write_xmm(dst, result)
        },
        _ => raise_UD(),
      }
    },

    // MAP5 0x59: VMULPH (NP, W=0) or VMULSH (F3, W=0)
    89 => {
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
      let is_mem : bool = match src { RM_mem(_) => true, _ => false };
      match mp {
        MP_NONE => {
          let (eff_ll, saved) = evex_begin_rc(pfx, ~(is_mem));
          let vl = ll_to_vl(eff_ll);
          let mask = evex_wmask(pfx, vl / 16);
          evex_write(dst, mask, packed_binop(PB_FMul, 16, read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(modrm, src, pfx, 16)));
          evex_end_rc(saved)
        },
        MP_F3 => {
          let src1 : xmmword = read_xmm(pfx.evex_vvvvv);
          let src2 : word = match src {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[15..0],
            RM_mem(m) => v(m),
          };
          let r : word = __f16_mul(src1[15..0], src2);
          evex_write_scalar(dst, src1[127..16] @ r, pfx, 16)
        },
        _ => raise_UD(),
      }
    },

    // MAP5 0x5C: VSUBPH (NP, W=0) or VSUBSH (F3, W=0)
    92 => {
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
      let is_mem : bool = match src { RM_mem(_) => true, _ => false };
      match mp {
        MP_NONE => {
          let (eff_ll, saved) = evex_begin_rc(pfx, ~(is_mem));
          let vl = ll_to_vl(eff_ll);
          let mask = evex_wmask(pfx, vl / 16);
          evex_write(dst, mask, packed_binop(PB_FSub, 16, read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(modrm, src, pfx, 16)));
          evex_end_rc(saved)
        },
        MP_F3 => {
          let src1 : xmmword = read_xmm(pfx.evex_vvvvv);
          let src2 : word = match src {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[15..0],
            RM_mem(m) => v(m),
          };
          let r : word = __f16_sub(src1[15..0], src2);
          evex_write_scalar(dst, src1[127..16] @ r, pfx, 16)
        },
        _ => raise_UD(),
      }
    },

    // MAP5 0x5D: VMINPH (NP, W=0) or VMINSH (F3, W=0)
    93 => {
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
      let is_mem : bool = match src { RM_mem(_) => true, _ => false };
      match mp {
        MP_NONE => {
          let vl = evex_vl(pfx);
          let mask = evex_wmask(pfx, vl / 16);
          evex_write(dst, mask, packed_binop(PB_FMin, 16, read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(modrm, src, pfx, 16)));
        },
        MP_F3 => {
          let src1 : xmmword = read_xmm(pfx.evex_vvvvv);
          let src2 : word = match src {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[15..0],
            RM_mem(m) => v(m),
          };
          let r : word = __f16_min(src1[15..0], src2);
          evex_write_scalar(dst, src1[127..16] @ r, pfx, 16)
        },
        _ => raise_UD(),
      }
    },

    // MAP5 0x5E: VDIVPH (NP, W=0) or VDIVSH (F3, W=0)
    94 => {
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
      let is_mem : bool = match src { RM_mem(_) => true, _ => false };
      match mp {
        MP_NONE => {
          let (eff_ll, saved) = evex_begin_rc(pfx, ~(is_mem));
          let vl = ll_to_vl(eff_ll);
          let mask = evex_wmask(pfx, vl / 16);
          evex_write(dst, mask, packed_binop(PB_FDiv, 16, read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(modrm, src, pfx, 16)));
          evex_end_rc(saved)
        },
        MP_F3 => {
          let src1 : xmmword = read_xmm(pfx.evex_vvvvv);
          let src2 : word = match src {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[15..0],
            RM_mem(m) => v(m),
          };
          let r : word = __f16_div(src1[15..0], src2);
          evex_write_scalar(dst, src1[127..16] @ r, pfx, 16)
        },
        _ => raise_UD(),
      }
    },

    // MAP5 0x5F: VMAXPH (NP, W=0) or VMAXSH (F3, W=0)
    95 => {
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
      let is_mem : bool = match src { RM_mem(_) => true, _ => false };
      match mp {
        MP_NONE => {
          let vl = evex_vl(pfx);
          let mask = evex_wmask(pfx, vl / 16);
          evex_write(dst, mask, packed_binop(PB_FMax, 16, read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(modrm, src, pfx, 16)));
        },
        MP_F3 => {
          let src1 : xmmword = read_xmm(pfx.evex_vvvvv);
          let src2 : word = match src {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[15..0],
            RM_mem(m) => v(m),
          };
          let r : word = __f16_max(src1[15..0], src2);
          evex_write_scalar(dst, src1[127..16] @ r, pfx, 16)
        },
        _ => raise_UD(),
      }
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
          let src = modrm_rm_evex(modrm, pfx, disp_n);
          let is_mem : bool = match src { RM_mem(_) => true, _ => false };
          match pfx.evex_ll {
            0 => {
              let src : dword = match src {
                RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
                RM_mem(m) => v(m),
              };
              let r : xmmword =
                __f16_to_f64(src[31..16]) @ __f16_to_f64(src[15..0]);
              evex_write(dst, evex_wmask(pfx, 2), r)
            },
            1 => {
              let src : qword = match src {
                RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
                RM_mem(m) => v(m),
              };
              let r : ymmword =
                __f16_to_f64(src[63..48]) @ __f16_to_f64(src[47..32]) @
                __f16_to_f64(src[31..16]) @ __f16_to_f64(src[15..0]);
              evex_write(dst, evex_wmask(pfx, 4), r)
            },
            2 => {
              let src : xmmword = evex_bcast_src(128,modrm, src, pfx, 16);
              let r : zmmword =
                __f16_to_f64(src[127..112]) @ __f16_to_f64(src[111..96]) @
                __f16_to_f64(src[95..80]) @ __f16_to_f64(src[79..64]) @
                __f16_to_f64(src[63..48]) @ __f16_to_f64(src[47..32]) @
                __f16_to_f64(src[31..16]) @ __f16_to_f64(src[15..0]);
              evex_write(dst, evex_wmask(pfx, 8), r)
            },
            3 => raise_UD(),
          }
        },
        MP_F3 => {
          // VCVTSH2SD: scalar FP16 to FP64
          let src = modrm_rm_evex(modrm, pfx, 2);
          let src1 : xmmword = read_xmm(pfx.evex_vvvvv);
          let src2 : word = match src {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[15..0],
            RM_mem(m) => v(m),
          };
          let r : qword = __f16_to_f64(src2);
          evex_write_scalar(dst, src1[127..64] @ r, pfx, 64)
        },
        MP_66 => {
          // VCVTPD2PH: packed FP64 to FP16 (W=1)
          let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
          let is_mem : bool = match src { RM_mem(_) => true, _ => false };
          let (eff_ll, saved) = evex_begin_rc(pfx, ~(is_mem));
          match eff_ll {
            0 => {
              let src = evex_bcast_src(128,modrm, src, pfx, 64);
              let r : dword =
                __f64_to_f16(src[127..64]) @ __f64_to_f16(src[63..0]);
              { let r : xmmword = zero_extend(r); evex_write(dst, evex_wmask(pfx, 8), r) }
            },
            1 => {
              let src = evex_bcast_src(256,modrm, src, pfx, 64);
              let r : qword =
                __f64_to_f16(src[255..192]) @ __f64_to_f16(src[191..128]) @
                __f64_to_f16(src[127..64]) @ __f64_to_f16(src[63..0]);
              { let r : xmmword = zero_extend(r); evex_write(dst, evex_wmask(pfx, 8), r) }
            },
            2 => {
              let src = evex_bcast_src(512,modrm, src, pfx, 64);
              let r : xmmword =
                __f64_to_f16(src[511..448]) @ __f64_to_f16(src[447..384]) @
                __f64_to_f16(src[383..320]) @ __f64_to_f16(src[319..256]) @
                __f64_to_f16(src[255..192]) @ __f64_to_f16(src[191..128]) @
                __f64_to_f16(src[127..64]) @ __f64_to_f16(src[63..0]);
              evex_write(dst, evex_wmask(pfx, 8), r)
            },
            3 => raise_UD(),
          };
          evex_end_rc(saved)
        },
        MP_F2 => {
          // VCVTSD2SH: scalar FP64 to FP16
          let src = modrm_rm_evex(modrm, pfx, 8);
          let src1 : xmmword = read_xmm(pfx.evex_vvvvv);
          let src2 : qword = match src {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
            RM_mem(m) => v(m),
          };
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
          let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
          let is_mem : bool = match src { RM_mem(_) => true, _ => false };
          match (pfx.vex_w, pfx.evex_ll) {
            // VCVTQQ2PH: convert packed int64 to FP16
            // SDM: KL=VL/64 elements, result in DEST.fp16[0..KL-1], rest zeroed
            (true, 0) => {
              let src = evex_bcast_src(128,modrm, src, pfx, 64);
              let r : dword =
                __int64_to_f16(src[127..64]) @ __int64_to_f16(src[63..0]);
              { let r : xmmword = zero_extend(r); evex_write(dst, evex_wmask(pfx, 8), r) }
            },
            (true, 1) => {
              let src = evex_bcast_src(256,modrm, src, pfx, 64);
              let r : qword =
                __int64_to_f16(src[255..192]) @ __int64_to_f16(src[191..128]) @
                __int64_to_f16(src[127..64]) @ __int64_to_f16(src[63..0]);
              { let r : xmmword = zero_extend(r); evex_write(dst, evex_wmask(pfx, 8), r) }
            },
            (true, 2) => {
              let src = evex_bcast_src(512,modrm, src, pfx, 64);
              let r : xmmword =
                __int64_to_f16(src[511..448]) @ __int64_to_f16(src[447..384]) @
                __int64_to_f16(src[383..320]) @ __int64_to_f16(src[319..256]) @
                __int64_to_f16(src[255..192]) @ __int64_to_f16(src[191..128]) @
                __int64_to_f16(src[127..64]) @ __int64_to_f16(src[63..0]);
              evex_write(dst, evex_wmask(pfx, 8), r)
            },
            // VCVTDQ2PH: convert packed int32 to FP16
            (false, 0) => {
              let src = evex_bcast_src(128,modrm, src, pfx, 32);
              let r : qword =
                __int32_to_f16(src[127..96]) @ __int32_to_f16(src[95..64]) @
                __int32_to_f16(src[63..32]) @ __int32_to_f16(src[31..0]);
              { let r : xmmword = zero_extend(r); evex_write(dst, evex_wmask(pfx, 8), r) }
            },
            (false, 1) => {
              let src = evex_bcast_src(256,modrm, src, pfx, 32);
              let r : xmmword =
                __int32_to_f16(src[255..224]) @ __int32_to_f16(src[223..192]) @
                __int32_to_f16(src[191..160]) @ __int32_to_f16(src[159..128]) @
                __int32_to_f16(src[127..96]) @ __int32_to_f16(src[95..64]) @
                __int32_to_f16(src[63..32]) @ __int32_to_f16(src[31..0]);
              evex_write(dst, evex_wmask(pfx, 8), r)
            },
            (false, 2) => {
              let src = evex_bcast_src(512,modrm, src, pfx, 32);
              let r : ymmword =
                __int32_to_f16(src[511..480]) @ __int32_to_f16(src[479..448]) @
                __int32_to_f16(src[447..416]) @ __int32_to_f16(src[415..384]) @
                __int32_to_f16(src[383..352]) @ __int32_to_f16(src[351..320]) @
                __int32_to_f16(src[319..288]) @ __int32_to_f16(src[287..256]) @
                __int32_to_f16(src[255..224]) @ __int32_to_f16(src[223..192]) @
                __int32_to_f16(src[191..160]) @ __int32_to_f16(src[159..128]) @
                __int32_to_f16(src[127..96]) @ __int32_to_f16(src[95..64]) @
                __int32_to_f16(src[63..32]) @ __int32_to_f16(src[31..0]);
              evex_write(dst, evex_wmask(pfx, 16), r)
            },
            _ => raise_UD(),
          }
        },
        MP_66 => {
          // VCVTPH2DQ: packed FP16 to int32 (rounding)
          let disp_n : range(2, 32) = if pfx.evex_b then 2 else match pfx.evex_ll {
            0 => 8, 1 => 16, 2 => 32, 3 => raise_UD(),
          };
          let src = modrm_rm_evex(modrm, pfx, disp_n);
          let is_mem : bool = match src { RM_mem(_) => true, _ => false };
          let (eff_ll, saved) = evex_begin_rc(pfx, ~(is_mem));
          match eff_ll {
            0 => {
              let src : qword = match src {
                RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
                RM_mem(m) => v(m),
              };
              let r : xmmword =
                __f16_to_int32(src[63..48]) @ __f16_to_int32(src[47..32]) @
                __f16_to_int32(src[31..16]) @ __f16_to_int32(src[15..0]);
              evex_write(dst, evex_wmask(pfx, 4), r)
            },
            1 => {
              let src = evex_bcast_src(128,modrm, src, pfx, 16);
              let r : ymmword =
                __f16_to_int32(src[127..112]) @ __f16_to_int32(src[111..96]) @
                __f16_to_int32(src[95..80]) @ __f16_to_int32(src[79..64]) @
                __f16_to_int32(src[63..48]) @ __f16_to_int32(src[47..32]) @
                __f16_to_int32(src[31..16]) @ __f16_to_int32(src[15..0]);
              evex_write(dst, evex_wmask(pfx, 8), r)
            },
            2 => {
              let src = evex_bcast_src(256,modrm, src, pfx, 16);
              let r : zmmword =
                __f16_to_int32(src[255..240]) @ __f16_to_int32(src[239..224]) @
                __f16_to_int32(src[223..208]) @ __f16_to_int32(src[207..192]) @
                __f16_to_int32(src[191..176]) @ __f16_to_int32(src[175..160]) @
                __f16_to_int32(src[159..144]) @ __f16_to_int32(src[143..128]) @
                __f16_to_int32(src[127..112]) @ __f16_to_int32(src[111..96]) @
                __f16_to_int32(src[95..80]) @ __f16_to_int32(src[79..64]) @
                __f16_to_int32(src[63..48]) @ __f16_to_int32(src[47..32]) @
                __f16_to_int32(src[31..16]) @ __f16_to_int32(src[15..0]);
              evex_write(dst, evex_wmask(pfx, 16), r)
            },
            3 => raise_UD(),
          };
          evex_end_rc(saved)
        },
        MP_F3 => {
          // VCVTTPH2DQ: packed FP16 to int32 (truncation)
          let disp_n : range(2, 32) = if pfx.evex_b then 2 else match pfx.evex_ll {
            0 => 8, 1 => 16, 2 => 32, 3 => raise_UD(),
          };
          let src = modrm_rm_evex(modrm, pfx, disp_n);
          let is_mem : bool = match src { RM_mem(_) => true, _ => false };
          match pfx.evex_ll {
            0 => {
              let src : qword = match src {
                RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
                RM_mem(m) => v(m),
              };
              let r : xmmword =
                __f16_to_int32_trunc(src[63..48]) @ __f16_to_int32_trunc(src[47..32]) @
                __f16_to_int32_trunc(src[31..16]) @ __f16_to_int32_trunc(src[15..0]);
              evex_write(dst, evex_wmask(pfx, 4), r)
            },
            1 => {
              let src = evex_bcast_src(128,modrm, src, pfx, 16);
              let r : ymmword =
                __f16_to_int32_trunc(src[127..112]) @ __f16_to_int32_trunc(src[111..96]) @
                __f16_to_int32_trunc(src[95..80]) @ __f16_to_int32_trunc(src[79..64]) @
                __f16_to_int32_trunc(src[63..48]) @ __f16_to_int32_trunc(src[47..32]) @
                __f16_to_int32_trunc(src[31..16]) @ __f16_to_int32_trunc(src[15..0]);
              evex_write(dst, evex_wmask(pfx, 8), r)
            },
            2 => {
              let src = evex_bcast_src(256,modrm, src, pfx, 16);
              let r : zmmword =
                __f16_to_int32_trunc(src[255..240]) @ __f16_to_int32_trunc(src[239..224]) @
                __f16_to_int32_trunc(src[223..208]) @ __f16_to_int32_trunc(src[207..192]) @
                __f16_to_int32_trunc(src[191..176]) @ __f16_to_int32_trunc(src[175..160]) @
                __f16_to_int32_trunc(src[159..144]) @ __f16_to_int32_trunc(src[143..128]) @
                __f16_to_int32_trunc(src[127..112]) @ __f16_to_int32_trunc(src[111..96]) @
                __f16_to_int32_trunc(src[95..80]) @ __f16_to_int32_trunc(src[79..64]) @
                __f16_to_int32_trunc(src[63..48]) @ __f16_to_int32_trunc(src[47..32]) @
                __f16_to_int32_trunc(src[31..16]) @ __f16_to_int32_trunc(src[15..0]);
              evex_write(dst, evex_wmask(pfx, 16), r)
            },
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
      let src = modrm_rm_evex(modrm, pfx, 2);
      match src {
        RM_mem(m) => {
          // VMOVSH load: 2-operand, load 16-bit, zero-extend to 128-bit
          let src : word = v(m);
          write_xmm(dst, zero_extend(src))
        },
        RM_reg(_) => {
          // VMOVSH reg-reg: 3-operand (src1=vvvvv upper bits, src2=src low 16 bits)
          let src1 : xmmword = read_xmm(pfx.evex_vvvvv);
          let src2 : word = read_xmm(evex_rm_reg_idx(modrm, pfx))[15..0];
          evex_write_scalar(dst, src1[127..16] @ src2, pfx, 16)
        },
      }
    },

    // MAP5 0x11: VMOVSH (F3) — scalar FP16 store
    17 => {
      if mp != MP_F3 then raise_UD();
      let modrm = fetch(1);
      let src = evex_reg_idx(modrm, pfx);
      let dest = modrm_rm_evex(modrm, pfx, 2);
      match dest {
        RM_mem(m) => {
          // VMOVSH store: write low 16 bits of src to memory
          v(m) = read_xmm(src)[15..0]
        },
        RM_reg(_) => {
          // VMOVSH reg-reg store: 3-operand (src1=vvvvv upper bits, src2=reg low 16)
          let dst_reg = evex_rm_reg_idx(modrm, pfx);
          let src1 : xmmword = read_xmm(pfx.evex_vvvvv);
          let src2 : word = read_xmm(src)[15..0];
          write_xmm(dst_reg, src1[127..16] @ src2)
        },
      }
    },

    // MAP5 0x2A: VCVTSI2SH (F3) — int to scalar FP16
    42 => {
      if mp != MP_F3 then raise_UD();
      let (dst, src) = fetch_modrm_evex(pfx, if pfx.vex_w then 8 else 4);
      let src1 : xmmword = read_xmm(pfx.evex_vvvvv);
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
      let src = modrm_rm_evex(modrm, pfx, 2);
      let src : word = match src {
        RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[15..0],
        RM_mem(m) => v(m),
      };
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
      let src = modrm_rm_evex(modrm, pfx, 2);
      let src : word = match src {
        RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[15..0],
        RM_mem(m) => v(m),
      };
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
      let src = modrm_rm_evex(modrm, pfx, 2);
      let a : word = read_xmm(src_reg)[15..0];
      let b : word = match src {
        RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[15..0],
        RM_mem(m) => v(m),
      };
      match __compare_sh(a, b) {
        FP_UNORDERED => { ZF = 0b1;  PF = 0b1;  CF = 0b1;  },
        FP_GT        => { ZF = 0b0; PF = 0b0; CF = 0b0; },
        FP_LT        => { ZF = 0b0; PF = 0b0; CF = 0b1;  },
        FP_EQ        => { ZF = 0b1;  PF = 0b0; CF = 0b0; },
      };
      OF = 0b0; SF = 0b0; AF = 0b0
    },

    // MAP5 0x2F: VCOMISH (NP) — ordered compare scalar FP16, set EFLAGS
    47 => {
      if mp != MP_NONE then raise_UD();
      let modrm = fetch(1);
      let src_reg = evex_reg_idx(modrm, pfx);
      let src = modrm_rm_evex(modrm, pfx, 2);
      let a : word = read_xmm(src_reg)[15..0];
      let b : word = match src {
        RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[15..0],
        RM_mem(m) => v(m),
      };
      match __compare_sh(a, b) {
        FP_UNORDERED => { ZF = 0b1;  PF = 0b1;  CF = 0b1;  },
        FP_GT        => { ZF = 0b0; PF = 0b0; CF = 0b0; },
        FP_LT        => { ZF = 0b0; PF = 0b0; CF = 0b1;  },
        FP_EQ        => { ZF = 0b1;  PF = 0b0; CF = 0b0; },
      };
      OF = 0b0; SF = 0b0; AF = 0b0
    },

    // MAP5 0x6E: VMOVW (66) — load 16-bit value to XMM low, zero-extend
    110 => {
      if mp != MP_66 then raise_UD();
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_rm_evex(modrm, pfx, 2);
      let src : word = match src {
        RM_reg(_) => v(64, modrm_rm_reg(modrm, pfx))[15..0],
        RM_mem(m) => v(m),
      };
      write_xmm(dst, zero_extend(src))
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
          let src = modrm_rm_evex(modrm, pfx, disp_n);
          let is_mem : bool = match src { RM_mem(_) => true, _ => false };
          match pfx.evex_ll {
            0 => {
              let src : qword = match src {
                RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
                RM_mem(m) => v(m),
              };
              let r : xmmword =
                __f16_to_uint32_trunc(src[63..48]) @ __f16_to_uint32_trunc(src[47..32]) @
                __f16_to_uint32_trunc(src[31..16]) @ __f16_to_uint32_trunc(src[15..0]);
              evex_write(dst, evex_wmask(pfx, 4), r)
            },
            1 => {
              let src = evex_bcast_src(128,modrm, src, pfx, 16);
              let r : ymmword =
                __f16_to_uint32_trunc(src[127..112]) @ __f16_to_uint32_trunc(src[111..96]) @
                __f16_to_uint32_trunc(src[95..80]) @ __f16_to_uint32_trunc(src[79..64]) @
                __f16_to_uint32_trunc(src[63..48]) @ __f16_to_uint32_trunc(src[47..32]) @
                __f16_to_uint32_trunc(src[31..16]) @ __f16_to_uint32_trunc(src[15..0]);
              evex_write(dst, evex_wmask(pfx, 8), r)
            },
            2 => {
              let src = evex_bcast_src(256,modrm, src, pfx, 16);
              let r : zmmword =
                __f16_to_uint32_trunc(src[255..240]) @ __f16_to_uint32_trunc(src[239..224]) @
                __f16_to_uint32_trunc(src[223..208]) @ __f16_to_uint32_trunc(src[207..192]) @
                __f16_to_uint32_trunc(src[191..176]) @ __f16_to_uint32_trunc(src[175..160]) @
                __f16_to_uint32_trunc(src[159..144]) @ __f16_to_uint32_trunc(src[143..128]) @
                __f16_to_uint32_trunc(src[127..112]) @ __f16_to_uint32_trunc(src[111..96]) @
                __f16_to_uint32_trunc(src[95..80]) @ __f16_to_uint32_trunc(src[79..64]) @
                __f16_to_uint32_trunc(src[63..48]) @ __f16_to_uint32_trunc(src[47..32]) @
                __f16_to_uint32_trunc(src[31..16]) @ __f16_to_uint32_trunc(src[15..0]);
              evex_write(dst, evex_wmask(pfx, 16), r)
            },
            3 => raise_UD(),
          }
        },
        MP_66 => {
          // VCVTTPH2UQQ: packed FP16 to uint64 (truncation)
          let disp_n : range(2, 16) = if pfx.evex_b then 2 else match pfx.evex_ll {
            0 => 4, 1 => 8, 2 => 16, 3 => raise_UD(),
          };
          let src = modrm_rm_evex(modrm, pfx, disp_n);
          let is_mem : bool = match src { RM_mem(_) => true, _ => false };
          match pfx.evex_ll {
            0 => {
              let src : dword = match src {
                RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
                RM_mem(m) => v(m),
              };
              let r : xmmword =
                __f16_to_uint64_trunc(src[31..16]) @ __f16_to_uint64_trunc(src[15..0]);
              evex_write(dst, evex_wmask(pfx, 2), r)
            },
            1 => {
              let src : qword = match src {
                RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
                RM_mem(m) => v(m),
              };
              let r : ymmword =
                __f16_to_uint64_trunc(src[63..48]) @ __f16_to_uint64_trunc(src[47..32]) @
                __f16_to_uint64_trunc(src[31..16]) @ __f16_to_uint64_trunc(src[15..0]);
              evex_write(dst, evex_wmask(pfx, 4), r)
            },
            2 => {
              let src : xmmword = evex_bcast_src(128,modrm, src, pfx, 16);
              let r : zmmword =
                __f16_to_uint64_trunc(src[127..112]) @ __f16_to_uint64_trunc(src[111..96]) @
                __f16_to_uint64_trunc(src[95..80]) @ __f16_to_uint64_trunc(src[79..64]) @
                __f16_to_uint64_trunc(src[63..48]) @ __f16_to_uint64_trunc(src[47..32]) @
                __f16_to_uint64_trunc(src[31..16]) @ __f16_to_uint64_trunc(src[15..0]);
              evex_write(dst, evex_wmask(pfx, 8), r)
            },
            3 => raise_UD(),
          }
        },
        MP_F3 => {
          // VCVTTSH2USI: scalar FP16 to unsigned int (truncation)
          let src = modrm_rm_evex(modrm, pfx, 2);
          let dst_gpr = modrm_reg(modrm, pfx);
          let src : word = match src {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[15..0],
            RM_mem(m) => v(m),
          };
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
          let src = modrm_rm_evex(modrm, pfx, disp_n);
          let is_mem : bool = match src { RM_mem(_) => true, _ => false };
          let (eff_ll, saved) = evex_begin_rc(pfx, ~(is_mem));
          match eff_ll {
            0 => {
              let src : qword = match src {
                RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
                RM_mem(m) => v(m),
              };
              let r : xmmword =
                __f16_to_uint32(src[63..48]) @ __f16_to_uint32(src[47..32]) @
                __f16_to_uint32(src[31..16]) @ __f16_to_uint32(src[15..0]);
              evex_write(dst, evex_wmask(pfx, 4), r)
            },
            1 => {
              let src = evex_bcast_src(128,modrm, src, pfx, 16);
              let r : ymmword =
                __f16_to_uint32(src[127..112]) @ __f16_to_uint32(src[111..96]) @
                __f16_to_uint32(src[95..80]) @ __f16_to_uint32(src[79..64]) @
                __f16_to_uint32(src[63..48]) @ __f16_to_uint32(src[47..32]) @
                __f16_to_uint32(src[31..16]) @ __f16_to_uint32(src[15..0]);
              evex_write(dst, evex_wmask(pfx, 8), r)
            },
            2 => {
              let src = evex_bcast_src(256,modrm, src, pfx, 16);
              let r : zmmword =
                __f16_to_uint32(src[255..240]) @ __f16_to_uint32(src[239..224]) @
                __f16_to_uint32(src[223..208]) @ __f16_to_uint32(src[207..192]) @
                __f16_to_uint32(src[191..176]) @ __f16_to_uint32(src[175..160]) @
                __f16_to_uint32(src[159..144]) @ __f16_to_uint32(src[143..128]) @
                __f16_to_uint32(src[127..112]) @ __f16_to_uint32(src[111..96]) @
                __f16_to_uint32(src[95..80]) @ __f16_to_uint32(src[79..64]) @
                __f16_to_uint32(src[63..48]) @ __f16_to_uint32(src[47..32]) @
                __f16_to_uint32(src[31..16]) @ __f16_to_uint32(src[15..0]);
              evex_write(dst, evex_wmask(pfx, 16), r)
            },
            3 => raise_UD(),
          };
          evex_end_rc(saved)
        },
        MP_66 => {
          // VCVTPH2UQQ: packed FP16 to uint64 (rounding)
          let disp_n : range(2, 16) = if pfx.evex_b then 2 else match pfx.evex_ll {
            0 => 4, 1 => 8, 2 => 16, 3 => raise_UD(),
          };
          let src = modrm_rm_evex(modrm, pfx, disp_n);
          let is_mem : bool = match src { RM_mem(_) => true, _ => false };
          let (eff_ll, saved) = evex_begin_rc(pfx, ~(is_mem));
          match eff_ll {
            0 => {
              let src : dword = match src {
                RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
                RM_mem(m) => v(m),
              };
              let r : xmmword =
                __f16_to_uint64(src[31..16]) @ __f16_to_uint64(src[15..0]);
              evex_write(dst, evex_wmask(pfx, 2), r)
            },
            1 => {
              let src : qword = match src {
                RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
                RM_mem(m) => v(m),
              };
              let r : ymmword =
                __f16_to_uint64(src[63..48]) @ __f16_to_uint64(src[47..32]) @
                __f16_to_uint64(src[31..16]) @ __f16_to_uint64(src[15..0]);
              evex_write(dst, evex_wmask(pfx, 4), r)
            },
            2 => {
              let src : xmmword = evex_bcast_src(128,modrm, src, pfx, 16);
              let r : zmmword =
                __f16_to_uint64(src[127..112]) @ __f16_to_uint64(src[111..96]) @
                __f16_to_uint64(src[95..80]) @ __f16_to_uint64(src[79..64]) @
                __f16_to_uint64(src[63..48]) @ __f16_to_uint64(src[47..32]) @
                __f16_to_uint64(src[31..16]) @ __f16_to_uint64(src[15..0]);
              evex_write(dst, evex_wmask(pfx, 8), r)
            },
            3 => raise_UD(),
          };
          evex_end_rc(saved)
        },
        MP_F3 => {
          // VCVTSH2USI: scalar FP16 to unsigned int (rounding)
          let src = modrm_rm_evex(modrm, pfx, 2);
          let dst_gpr = modrm_reg(modrm, pfx);
          let src : word = match src {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[15..0],
            RM_mem(m) => v(m),
          };
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
          let src = modrm_rm_evex(modrm, pfx, disp_n);
          let is_mem : bool = match src { RM_mem(_) => true, _ => false };
          match pfx.evex_ll {
            0 => {
              let src : dword = match src {
                RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
                RM_mem(m) => v(m),
              };
              let r : xmmword =
                __f16_to_int64_trunc(src[31..16]) @ __f16_to_int64_trunc(src[15..0]);
              evex_write(dst, evex_wmask(pfx, 2), r)
            },
            1 => {
              let src : qword = match src {
                RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
                RM_mem(m) => v(m),
              };
              let r : ymmword =
                __f16_to_int64_trunc(src[63..48]) @ __f16_to_int64_trunc(src[47..32]) @
                __f16_to_int64_trunc(src[31..16]) @ __f16_to_int64_trunc(src[15..0]);
              evex_write(dst, evex_wmask(pfx, 4), r)
            },
            2 => {
              let src : xmmword = evex_bcast_src(128,modrm, src, pfx, 16);
              let r : zmmword =
                __f16_to_int64_trunc(src[127..112]) @ __f16_to_int64_trunc(src[111..96]) @
                __f16_to_int64_trunc(src[95..80]) @ __f16_to_int64_trunc(src[79..64]) @
                __f16_to_int64_trunc(src[63..48]) @ __f16_to_int64_trunc(src[47..32]) @
                __f16_to_int64_trunc(src[31..16]) @ __f16_to_int64_trunc(src[15..0]);
              evex_write(dst, evex_wmask(pfx, 8), r)
            },
            3 => raise_UD(),
          }
        },
        MP_F2 => {
          let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
          let is_mem : bool = match src { RM_mem(_) => true, _ => false };
          let (eff_ll, saved) = evex_begin_rc(pfx, ~(is_mem));
          match (pfx.vex_w, eff_ll) {
            // VCVTUQQ2PH: packed uint64 to FP16
            (true, 0) => {
              let src = evex_bcast_src(128,modrm, src, pfx, 64);
              let r : dword =
                __uint64_to_f16(src[127..64]) @ __uint64_to_f16(src[63..0]);
              { let r : xmmword = zero_extend(r); evex_write(dst, evex_wmask(pfx, 8), r) }
            },
            (true, 1) => {
              let src = evex_bcast_src(256,modrm, src, pfx, 64);
              let r : qword =
                __uint64_to_f16(src[255..192]) @ __uint64_to_f16(src[191..128]) @
                __uint64_to_f16(src[127..64]) @ __uint64_to_f16(src[63..0]);
              { let r : xmmword = zero_extend(r); evex_write(dst, evex_wmask(pfx, 8), r) }
            },
            (true, 2) => {
              let src = evex_bcast_src(512,modrm, src, pfx, 64);
              let r : xmmword =
                __uint64_to_f16(src[511..448]) @ __uint64_to_f16(src[447..384]) @
                __uint64_to_f16(src[383..320]) @ __uint64_to_f16(src[319..256]) @
                __uint64_to_f16(src[255..192]) @ __uint64_to_f16(src[191..128]) @
                __uint64_to_f16(src[127..64]) @ __uint64_to_f16(src[63..0]);
              evex_write(dst, evex_wmask(pfx, 8), r)
            },
            // VCVTUDQ2PH: packed uint32 to FP16
            (false, 0) => {
              let src = evex_bcast_src(128,modrm, src, pfx, 32);
              let r : qword =
                __uint32_to_f16(src[127..96]) @ __uint32_to_f16(src[95..64]) @
                __uint32_to_f16(src[63..32]) @ __uint32_to_f16(src[31..0]);
              { let r : xmmword = zero_extend(r); evex_write(dst, evex_wmask(pfx, 8), r) }
            },
            (false, 1) => {
              let src = evex_bcast_src(256,modrm, src, pfx, 32);
              let r : xmmword =
                __uint32_to_f16(src[255..224]) @ __uint32_to_f16(src[223..192]) @
                __uint32_to_f16(src[191..160]) @ __uint32_to_f16(src[159..128]) @
                __uint32_to_f16(src[127..96]) @ __uint32_to_f16(src[95..64]) @
                __uint32_to_f16(src[63..32]) @ __uint32_to_f16(src[31..0]);
              evex_write(dst, evex_wmask(pfx, 8), r)
            },
            (false, 2) => {
              let src = evex_bcast_src(512,modrm, src, pfx, 32);
              let r : ymmword =
                __uint32_to_f16(src[511..480]) @ __uint32_to_f16(src[479..448]) @
                __uint32_to_f16(src[447..416]) @ __uint32_to_f16(src[415..384]) @
                __uint32_to_f16(src[383..352]) @ __uint32_to_f16(src[351..320]) @
                __uint32_to_f16(src[319..288]) @ __uint32_to_f16(src[287..256]) @
                __uint32_to_f16(src[255..224]) @ __uint32_to_f16(src[223..192]) @
                __uint32_to_f16(src[191..160]) @ __uint32_to_f16(src[159..128]) @
                __uint32_to_f16(src[127..96]) @ __uint32_to_f16(src[95..64]) @
                __uint32_to_f16(src[63..32]) @ __uint32_to_f16(src[31..0]);
              evex_write(dst, evex_wmask(pfx, 16), r)
            },
            _ => raise_UD(),
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
          let src = modrm_rm_evex(modrm, pfx, disp_n);
          let is_mem : bool = match src { RM_mem(_) => true, _ => false };
          let (eff_ll, saved) = evex_begin_rc(pfx, ~(is_mem));
          match eff_ll {
            0 => {
              let src : dword = match src {
                RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
                RM_mem(m) => v(m),
              };
              let r : xmmword =
                __f16_to_int64(src[31..16]) @ __f16_to_int64(src[15..0]);
              evex_write(dst, evex_wmask(pfx, 2), r)
            },
            1 => {
              let src : qword = match src {
                RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
                RM_mem(m) => v(m),
              };
              let r : ymmword =
                __f16_to_int64(src[63..48]) @ __f16_to_int64(src[47..32]) @
                __f16_to_int64(src[31..16]) @ __f16_to_int64(src[15..0]);
              evex_write(dst, evex_wmask(pfx, 4), r)
            },
            2 => {
              let src : xmmword = evex_bcast_src(128,modrm, src, pfx, 16);
              let r : zmmword =
                __f16_to_int64(src[127..112]) @ __f16_to_int64(src[111..96]) @
                __f16_to_int64(src[95..80]) @ __f16_to_int64(src[79..64]) @
                __f16_to_int64(src[63..48]) @ __f16_to_int64(src[47..32]) @
                __f16_to_int64(src[31..16]) @ __f16_to_int64(src[15..0]);
              evex_write(dst, evex_wmask(pfx, 8), r)
            },
            3 => raise_UD(),
          };
          evex_end_rc(saved)
        },
        MP_F3 => {
          // VCVTUSI2SH: unsigned int to scalar FP16
          let src = modrm_rm_evex(modrm, pfx, if pfx.vex_w then 8 else 4);
          let src1 : xmmword = read_xmm(pfx.evex_vvvvv);
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
      let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
      let is_mem : bool = match src { RM_mem(_) => true, _ => false };
      match mp {
        MP_NONE => {
          // VCVTTPH2UW: packed FP16 to uint16 (truncation), same width
          match pfx.evex_ll {
            0 => {
              let src = evex_bcast_src(128,modrm, src, pfx, 16);
              let r : xmmword =
                __f16_to_uint16_trunc(src[127..112]) @ __f16_to_uint16_trunc(src[111..96]) @
                __f16_to_uint16_trunc(src[95..80]) @ __f16_to_uint16_trunc(src[79..64]) @
                __f16_to_uint16_trunc(src[63..48]) @ __f16_to_uint16_trunc(src[47..32]) @
                __f16_to_uint16_trunc(src[31..16]) @ __f16_to_uint16_trunc(src[15..0]);
              evex_write(dst, evex_wmask(pfx, 8), r)
            },
            1 => {
              let src = evex_bcast_src(256,modrm, src, pfx, 16);
              let r : ymmword =
                __f16_to_uint16_trunc(src[255..240]) @ __f16_to_uint16_trunc(src[239..224]) @
                __f16_to_uint16_trunc(src[223..208]) @ __f16_to_uint16_trunc(src[207..192]) @
                __f16_to_uint16_trunc(src[191..176]) @ __f16_to_uint16_trunc(src[175..160]) @
                __f16_to_uint16_trunc(src[159..144]) @ __f16_to_uint16_trunc(src[143..128]) @
                __f16_to_uint16_trunc(src[127..112]) @ __f16_to_uint16_trunc(src[111..96]) @
                __f16_to_uint16_trunc(src[95..80]) @ __f16_to_uint16_trunc(src[79..64]) @
                __f16_to_uint16_trunc(src[63..48]) @ __f16_to_uint16_trunc(src[47..32]) @
                __f16_to_uint16_trunc(src[31..16]) @ __f16_to_uint16_trunc(src[15..0]);
              evex_write(dst, evex_wmask(pfx, 16), r)
            },
            2 => {
              let src = evex_bcast_src(512,modrm, src, pfx, 16);
              let r : zmmword =
                __f16_to_uint16_trunc(src[511..496]) @ __f16_to_uint16_trunc(src[495..480]) @
                __f16_to_uint16_trunc(src[479..464]) @ __f16_to_uint16_trunc(src[463..448]) @
                __f16_to_uint16_trunc(src[447..432]) @ __f16_to_uint16_trunc(src[431..416]) @
                __f16_to_uint16_trunc(src[415..400]) @ __f16_to_uint16_trunc(src[399..384]) @
                __f16_to_uint16_trunc(src[383..368]) @ __f16_to_uint16_trunc(src[367..352]) @
                __f16_to_uint16_trunc(src[351..336]) @ __f16_to_uint16_trunc(src[335..320]) @
                __f16_to_uint16_trunc(src[319..304]) @ __f16_to_uint16_trunc(src[303..288]) @
                __f16_to_uint16_trunc(src[287..272]) @ __f16_to_uint16_trunc(src[271..256]) @
                __f16_to_uint16_trunc(src[255..240]) @ __f16_to_uint16_trunc(src[239..224]) @
                __f16_to_uint16_trunc(src[223..208]) @ __f16_to_uint16_trunc(src[207..192]) @
                __f16_to_uint16_trunc(src[191..176]) @ __f16_to_uint16_trunc(src[175..160]) @
                __f16_to_uint16_trunc(src[159..144]) @ __f16_to_uint16_trunc(src[143..128]) @
                __f16_to_uint16_trunc(src[127..112]) @ __f16_to_uint16_trunc(src[111..96]) @
                __f16_to_uint16_trunc(src[95..80]) @ __f16_to_uint16_trunc(src[79..64]) @
                __f16_to_uint16_trunc(src[63..48]) @ __f16_to_uint16_trunc(src[47..32]) @
                __f16_to_uint16_trunc(src[31..16]) @ __f16_to_uint16_trunc(src[15..0]);
              evex_write(dst, evex_wmask(pfx, 32), r)
            },
            3 => raise_UD(),
          }
        },
        MP_66 => {
          // VCVTTPH2W: packed FP16 to int16 (truncation), same width
          match pfx.evex_ll {
            0 => {
              let src = evex_bcast_src(128,modrm, src, pfx, 16);
              let r : xmmword =
                __f16_to_int16_trunc(src[127..112]) @ __f16_to_int16_trunc(src[111..96]) @
                __f16_to_int16_trunc(src[95..80]) @ __f16_to_int16_trunc(src[79..64]) @
                __f16_to_int16_trunc(src[63..48]) @ __f16_to_int16_trunc(src[47..32]) @
                __f16_to_int16_trunc(src[31..16]) @ __f16_to_int16_trunc(src[15..0]);
              evex_write(dst, evex_wmask(pfx, 8), r)
            },
            1 => {
              let src = evex_bcast_src(256,modrm, src, pfx, 16);
              let r : ymmword =
                __f16_to_int16_trunc(src[255..240]) @ __f16_to_int16_trunc(src[239..224]) @
                __f16_to_int16_trunc(src[223..208]) @ __f16_to_int16_trunc(src[207..192]) @
                __f16_to_int16_trunc(src[191..176]) @ __f16_to_int16_trunc(src[175..160]) @
                __f16_to_int16_trunc(src[159..144]) @ __f16_to_int16_trunc(src[143..128]) @
                __f16_to_int16_trunc(src[127..112]) @ __f16_to_int16_trunc(src[111..96]) @
                __f16_to_int16_trunc(src[95..80]) @ __f16_to_int16_trunc(src[79..64]) @
                __f16_to_int16_trunc(src[63..48]) @ __f16_to_int16_trunc(src[47..32]) @
                __f16_to_int16_trunc(src[31..16]) @ __f16_to_int16_trunc(src[15..0]);
              evex_write(dst, evex_wmask(pfx, 16), r)
            },
            2 => {
              let src = evex_bcast_src(512,modrm, src, pfx, 16);
              let r : zmmword =
                __f16_to_int16_trunc(src[511..496]) @ __f16_to_int16_trunc(src[495..480]) @
                __f16_to_int16_trunc(src[479..464]) @ __f16_to_int16_trunc(src[463..448]) @
                __f16_to_int16_trunc(src[447..432]) @ __f16_to_int16_trunc(src[431..416]) @
                __f16_to_int16_trunc(src[415..400]) @ __f16_to_int16_trunc(src[399..384]) @
                __f16_to_int16_trunc(src[383..368]) @ __f16_to_int16_trunc(src[367..352]) @
                __f16_to_int16_trunc(src[351..336]) @ __f16_to_int16_trunc(src[335..320]) @
                __f16_to_int16_trunc(src[319..304]) @ __f16_to_int16_trunc(src[303..288]) @
                __f16_to_int16_trunc(src[287..272]) @ __f16_to_int16_trunc(src[271..256]) @
                __f16_to_int16_trunc(src[255..240]) @ __f16_to_int16_trunc(src[239..224]) @
                __f16_to_int16_trunc(src[223..208]) @ __f16_to_int16_trunc(src[207..192]) @
                __f16_to_int16_trunc(src[191..176]) @ __f16_to_int16_trunc(src[175..160]) @
                __f16_to_int16_trunc(src[159..144]) @ __f16_to_int16_trunc(src[143..128]) @
                __f16_to_int16_trunc(src[127..112]) @ __f16_to_int16_trunc(src[111..96]) @
                __f16_to_int16_trunc(src[95..80]) @ __f16_to_int16_trunc(src[79..64]) @
                __f16_to_int16_trunc(src[63..48]) @ __f16_to_int16_trunc(src[47..32]) @
                __f16_to_int16_trunc(src[31..16]) @ __f16_to_int16_trunc(src[15..0]);
              evex_write(dst, evex_wmask(pfx, 32), r)
            },
            3 => raise_UD(),
          }
        },
        _ => raise_UD(),
      }
    },

    // MAP5 0x7D: VCVTPH2UW (NP), VCVTPH2W (66), VCVTW2PH (F3), VCVTUW2PH (F2)
    125 => {
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
      let is_mem : bool = match src { RM_mem(_) => true, _ => false };
      match mp {
        MP_NONE => {
          // VCVTPH2UW: packed FP16 to uint16 (rounding), same width
          let (eff_ll, saved) = evex_begin_rc(pfx, ~(is_mem));
          match eff_ll {
            0 => {
              let src = evex_bcast_src(128,modrm, src, pfx, 16);
              let r : xmmword =
                __f16_to_uint16(src[127..112]) @ __f16_to_uint16(src[111..96]) @
                __f16_to_uint16(src[95..80]) @ __f16_to_uint16(src[79..64]) @
                __f16_to_uint16(src[63..48]) @ __f16_to_uint16(src[47..32]) @
                __f16_to_uint16(src[31..16]) @ __f16_to_uint16(src[15..0]);
              evex_write(dst, evex_wmask(pfx, 8), r)
            },
            1 => {
              let src = evex_bcast_src(256,modrm, src, pfx, 16);
              let r : ymmword =
                __f16_to_uint16(src[255..240]) @ __f16_to_uint16(src[239..224]) @
                __f16_to_uint16(src[223..208]) @ __f16_to_uint16(src[207..192]) @
                __f16_to_uint16(src[191..176]) @ __f16_to_uint16(src[175..160]) @
                __f16_to_uint16(src[159..144]) @ __f16_to_uint16(src[143..128]) @
                __f16_to_uint16(src[127..112]) @ __f16_to_uint16(src[111..96]) @
                __f16_to_uint16(src[95..80]) @ __f16_to_uint16(src[79..64]) @
                __f16_to_uint16(src[63..48]) @ __f16_to_uint16(src[47..32]) @
                __f16_to_uint16(src[31..16]) @ __f16_to_uint16(src[15..0]);
              evex_write(dst, evex_wmask(pfx, 16), r)
            },
            2 => {
              let src = evex_bcast_src(512,modrm, src, pfx, 16);
              let r : zmmword =
                __f16_to_uint16(src[511..496]) @ __f16_to_uint16(src[495..480]) @
                __f16_to_uint16(src[479..464]) @ __f16_to_uint16(src[463..448]) @
                __f16_to_uint16(src[447..432]) @ __f16_to_uint16(src[431..416]) @
                __f16_to_uint16(src[415..400]) @ __f16_to_uint16(src[399..384]) @
                __f16_to_uint16(src[383..368]) @ __f16_to_uint16(src[367..352]) @
                __f16_to_uint16(src[351..336]) @ __f16_to_uint16(src[335..320]) @
                __f16_to_uint16(src[319..304]) @ __f16_to_uint16(src[303..288]) @
                __f16_to_uint16(src[287..272]) @ __f16_to_uint16(src[271..256]) @
                __f16_to_uint16(src[255..240]) @ __f16_to_uint16(src[239..224]) @
                __f16_to_uint16(src[223..208]) @ __f16_to_uint16(src[207..192]) @
                __f16_to_uint16(src[191..176]) @ __f16_to_uint16(src[175..160]) @
                __f16_to_uint16(src[159..144]) @ __f16_to_uint16(src[143..128]) @
                __f16_to_uint16(src[127..112]) @ __f16_to_uint16(src[111..96]) @
                __f16_to_uint16(src[95..80]) @ __f16_to_uint16(src[79..64]) @
                __f16_to_uint16(src[63..48]) @ __f16_to_uint16(src[47..32]) @
                __f16_to_uint16(src[31..16]) @ __f16_to_uint16(src[15..0]);
              evex_write(dst, evex_wmask(pfx, 32), r)
            },
            3 => raise_UD(),
          };
          evex_end_rc(saved)
        },
        MP_66 => {
          // VCVTPH2W: packed FP16 to int16 (rounding), same width
          let (eff_ll, saved) = evex_begin_rc(pfx, ~(is_mem));
          match eff_ll {
            0 => {
              let src = evex_bcast_src(128,modrm, src, pfx, 16);
              let r : xmmword =
                __f16_to_int16(src[127..112]) @ __f16_to_int16(src[111..96]) @
                __f16_to_int16(src[95..80]) @ __f16_to_int16(src[79..64]) @
                __f16_to_int16(src[63..48]) @ __f16_to_int16(src[47..32]) @
                __f16_to_int16(src[31..16]) @ __f16_to_int16(src[15..0]);
              evex_write(dst, evex_wmask(pfx, 8), r)
            },
            1 => {
              let src = evex_bcast_src(256,modrm, src, pfx, 16);
              let r : ymmword =
                __f16_to_int16(src[255..240]) @ __f16_to_int16(src[239..224]) @
                __f16_to_int16(src[223..208]) @ __f16_to_int16(src[207..192]) @
                __f16_to_int16(src[191..176]) @ __f16_to_int16(src[175..160]) @
                __f16_to_int16(src[159..144]) @ __f16_to_int16(src[143..128]) @
                __f16_to_int16(src[127..112]) @ __f16_to_int16(src[111..96]) @
                __f16_to_int16(src[95..80]) @ __f16_to_int16(src[79..64]) @
                __f16_to_int16(src[63..48]) @ __f16_to_int16(src[47..32]) @
                __f16_to_int16(src[31..16]) @ __f16_to_int16(src[15..0]);
              evex_write(dst, evex_wmask(pfx, 16), r)
            },
            2 => {
              let src = evex_bcast_src(512,modrm, src, pfx, 16);
              let r : zmmword =
                __f16_to_int16(src[511..496]) @ __f16_to_int16(src[495..480]) @
                __f16_to_int16(src[479..464]) @ __f16_to_int16(src[463..448]) @
                __f16_to_int16(src[447..432]) @ __f16_to_int16(src[431..416]) @
                __f16_to_int16(src[415..400]) @ __f16_to_int16(src[399..384]) @
                __f16_to_int16(src[383..368]) @ __f16_to_int16(src[367..352]) @
                __f16_to_int16(src[351..336]) @ __f16_to_int16(src[335..320]) @
                __f16_to_int16(src[319..304]) @ __f16_to_int16(src[303..288]) @
                __f16_to_int16(src[287..272]) @ __f16_to_int16(src[271..256]) @
                __f16_to_int16(src[255..240]) @ __f16_to_int16(src[239..224]) @
                __f16_to_int16(src[223..208]) @ __f16_to_int16(src[207..192]) @
                __f16_to_int16(src[191..176]) @ __f16_to_int16(src[175..160]) @
                __f16_to_int16(src[159..144]) @ __f16_to_int16(src[143..128]) @
                __f16_to_int16(src[127..112]) @ __f16_to_int16(src[111..96]) @
                __f16_to_int16(src[95..80]) @ __f16_to_int16(src[79..64]) @
                __f16_to_int16(src[63..48]) @ __f16_to_int16(src[47..32]) @
                __f16_to_int16(src[31..16]) @ __f16_to_int16(src[15..0]);
              evex_write(dst, evex_wmask(pfx, 32), r)
            },
            3 => raise_UD(),
          };
          evex_end_rc(saved)
        },
        MP_F3 => {
          // VCVTW2PH: packed int16 to FP16, same width
          let (eff_ll, saved) = evex_begin_rc(pfx, ~(is_mem));
          match eff_ll {
            0 => {
              let src = evex_bcast_src(128,modrm, src, pfx, 16);
              let r : xmmword =
                __int16_to_f16(src[127..112]) @ __int16_to_f16(src[111..96]) @
                __int16_to_f16(src[95..80]) @ __int16_to_f16(src[79..64]) @
                __int16_to_f16(src[63..48]) @ __int16_to_f16(src[47..32]) @
                __int16_to_f16(src[31..16]) @ __int16_to_f16(src[15..0]);
              evex_write(dst, evex_wmask(pfx, 8), r)
            },
            1 => {
              let src = evex_bcast_src(256,modrm, src, pfx, 16);
              let r : ymmword =
                __int16_to_f16(src[255..240]) @ __int16_to_f16(src[239..224]) @
                __int16_to_f16(src[223..208]) @ __int16_to_f16(src[207..192]) @
                __int16_to_f16(src[191..176]) @ __int16_to_f16(src[175..160]) @
                __int16_to_f16(src[159..144]) @ __int16_to_f16(src[143..128]) @
                __int16_to_f16(src[127..112]) @ __int16_to_f16(src[111..96]) @
                __int16_to_f16(src[95..80]) @ __int16_to_f16(src[79..64]) @
                __int16_to_f16(src[63..48]) @ __int16_to_f16(src[47..32]) @
                __int16_to_f16(src[31..16]) @ __int16_to_f16(src[15..0]);
              evex_write(dst, evex_wmask(pfx, 16), r)
            },
            2 => {
              let src = evex_bcast_src(512,modrm, src, pfx, 16);
              let r : zmmword =
                __int16_to_f16(src[511..496]) @ __int16_to_f16(src[495..480]) @
                __int16_to_f16(src[479..464]) @ __int16_to_f16(src[463..448]) @
                __int16_to_f16(src[447..432]) @ __int16_to_f16(src[431..416]) @
                __int16_to_f16(src[415..400]) @ __int16_to_f16(src[399..384]) @
                __int16_to_f16(src[383..368]) @ __int16_to_f16(src[367..352]) @
                __int16_to_f16(src[351..336]) @ __int16_to_f16(src[335..320]) @
                __int16_to_f16(src[319..304]) @ __int16_to_f16(src[303..288]) @
                __int16_to_f16(src[287..272]) @ __int16_to_f16(src[271..256]) @
                __int16_to_f16(src[255..240]) @ __int16_to_f16(src[239..224]) @
                __int16_to_f16(src[223..208]) @ __int16_to_f16(src[207..192]) @
                __int16_to_f16(src[191..176]) @ __int16_to_f16(src[175..160]) @
                __int16_to_f16(src[159..144]) @ __int16_to_f16(src[143..128]) @
                __int16_to_f16(src[127..112]) @ __int16_to_f16(src[111..96]) @
                __int16_to_f16(src[95..80]) @ __int16_to_f16(src[79..64]) @
                __int16_to_f16(src[63..48]) @ __int16_to_f16(src[47..32]) @
                __int16_to_f16(src[31..16]) @ __int16_to_f16(src[15..0]);
              evex_write(dst, evex_wmask(pfx, 32), r)
            },
            3 => raise_UD(),
          };
          evex_end_rc(saved)
        },
        MP_F2 => {
          // VCVTUW2PH: packed uint16 to FP16, same width
          let (eff_ll, saved) = evex_begin_rc(pfx, ~(is_mem));
          match eff_ll {
            0 => {
              let src = evex_bcast_src(128,modrm, src, pfx, 16);
              let r : xmmword =
                __uint16_to_f16(src[127..112]) @ __uint16_to_f16(src[111..96]) @
                __uint16_to_f16(src[95..80]) @ __uint16_to_f16(src[79..64]) @
                __uint16_to_f16(src[63..48]) @ __uint16_to_f16(src[47..32]) @
                __uint16_to_f16(src[31..16]) @ __uint16_to_f16(src[15..0]);
              evex_write(dst, evex_wmask(pfx, 8), r)
            },
            1 => {
              let src = evex_bcast_src(256,modrm, src, pfx, 16);
              let r : ymmword =
                __uint16_to_f16(src[255..240]) @ __uint16_to_f16(src[239..224]) @
                __uint16_to_f16(src[223..208]) @ __uint16_to_f16(src[207..192]) @
                __uint16_to_f16(src[191..176]) @ __uint16_to_f16(src[175..160]) @
                __uint16_to_f16(src[159..144]) @ __uint16_to_f16(src[143..128]) @
                __uint16_to_f16(src[127..112]) @ __uint16_to_f16(src[111..96]) @
                __uint16_to_f16(src[95..80]) @ __uint16_to_f16(src[79..64]) @
                __uint16_to_f16(src[63..48]) @ __uint16_to_f16(src[47..32]) @
                __uint16_to_f16(src[31..16]) @ __uint16_to_f16(src[15..0]);
              evex_write(dst, evex_wmask(pfx, 16), r)
            },
            2 => {
              let src = evex_bcast_src(512,modrm, src, pfx, 16);
              let r : zmmword =
                __uint16_to_f16(src[511..496]) @ __uint16_to_f16(src[495..480]) @
                __uint16_to_f16(src[479..464]) @ __uint16_to_f16(src[463..448]) @
                __uint16_to_f16(src[447..432]) @ __uint16_to_f16(src[431..416]) @
                __uint16_to_f16(src[415..400]) @ __uint16_to_f16(src[399..384]) @
                __uint16_to_f16(src[383..368]) @ __uint16_to_f16(src[367..352]) @
                __uint16_to_f16(src[351..336]) @ __uint16_to_f16(src[335..320]) @
                __uint16_to_f16(src[319..304]) @ __uint16_to_f16(src[303..288]) @
                __uint16_to_f16(src[287..272]) @ __uint16_to_f16(src[271..256]) @
                __uint16_to_f16(src[255..240]) @ __uint16_to_f16(src[239..224]) @
                __uint16_to_f16(src[223..208]) @ __uint16_to_f16(src[207..192]) @
                __uint16_to_f16(src[191..176]) @ __uint16_to_f16(src[175..160]) @
                __uint16_to_f16(src[159..144]) @ __uint16_to_f16(src[143..128]) @
                __uint16_to_f16(src[127..112]) @ __uint16_to_f16(src[111..96]) @
                __uint16_to_f16(src[95..80]) @ __uint16_to_f16(src[79..64]) @
                __uint16_to_f16(src[63..48]) @ __uint16_to_f16(src[47..32]) @
                __uint16_to_f16(src[31..16]) @ __uint16_to_f16(src[15..0]);
              evex_write(dst, evex_wmask(pfx, 32), r)
            },
            3 => raise_UD(),
          };
          evex_end_rc(saved)
        },
      }
    },

    // MAP5 0x7E: VMOVW (66) — store XMM low 16-bit to mem/GPR
    126 => {
      if mp != MP_66 then raise_UD();
      let modrm = fetch(1);
      let src = evex_reg_idx(modrm, pfx);
      let dest = modrm_rm_evex(modrm, pfx, 2);
      let x : word = read_xmm(src)[15..0];
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
          let src = modrm_rm_evex(modrm, pfx, disp_n);
          let is_mem : bool = match src { RM_mem(_) => true, _ => false };
          let (eff_ll, saved) = evex_begin_rc(pfx, ~(is_mem));
          match eff_ll {
            0 => {
              let src = evex_bcast_src(128,modrm, src, pfx, 32);
              let r : qword =
                __f32_to_f16(src[127..96]) @ __f32_to_f16(src[95..64]) @
                __f32_to_f16(src[63..32]) @ __f32_to_f16(src[31..0]);
              { let r : xmmword = zero_extend(r); evex_write(dst, evex_wmask(pfx, 8), r) }
            },
            1 => {
              let src = evex_bcast_src(256,modrm, src, pfx, 32);
              let r : xmmword =
                __f32_to_f16(src[255..224]) @ __f32_to_f16(src[223..192]) @
                __f32_to_f16(src[191..160]) @ __f32_to_f16(src[159..128]) @
                __f32_to_f16(src[127..96]) @ __f32_to_f16(src[95..64]) @
                __f32_to_f16(src[63..32]) @ __f32_to_f16(src[31..0]);
              evex_write(dst, evex_wmask(pfx, 8), r)
            },
            2 => {
              let src = evex_bcast_src(512,modrm, src, pfx, 32);
              let r : ymmword =
                __f32_to_f16(src[511..480]) @ __f32_to_f16(src[479..448]) @
                __f32_to_f16(src[447..416]) @ __f32_to_f16(src[415..384]) @
                __f32_to_f16(src[383..352]) @ __f32_to_f16(src[351..320]) @
                __f32_to_f16(src[319..288]) @ __f32_to_f16(src[287..256]) @
                __f32_to_f16(src[255..224]) @ __f32_to_f16(src[223..192]) @
                __f32_to_f16(src[191..160]) @ __f32_to_f16(src[159..128]) @
                __f32_to_f16(src[127..96]) @ __f32_to_f16(src[95..64]) @
                __f32_to_f16(src[63..32]) @ __f32_to_f16(src[31..0]);
              evex_write(dst, evex_wmask(pfx, 16), r)
            },
            3 => raise_UD(),
          };
          evex_end_rc(saved)
        },
        MP_NONE => {
          // VCVTSS2SH: scalar FP32 to FP16 (EVEX.NP.MAP5.W0)
          let src = modrm_rm_evex(modrm, pfx, 4);
          let src1 : xmmword = read_xmm(pfx.evex_vvvvv);
          let src2 : dword = match src {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
            RM_mem(m) => v(m),
          };
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
val vfmadd_ph_xmm : (xmmword, xmmword, xmmword) -> xmmword
function vfmadd_ph_xmm(a, b, c) =
  __f16_fmadd(a[127..112], b[127..112], c[127..112]) @
  __f16_fmadd(a[111..96], b[111..96], c[111..96]) @
  __f16_fmadd(a[95..80], b[95..80], c[95..80]) @
  __f16_fmadd(a[79..64], b[79..64], c[79..64]) @
  __f16_fmadd(a[63..48], b[63..48], c[63..48]) @
  __f16_fmadd(a[47..32], b[47..32], c[47..32]) @
  __f16_fmadd(a[31..16], b[31..16], c[31..16]) @
  __f16_fmadd(a[15..0], b[15..0], c[15..0])

val vfmadd_ph_ymm : (ymmword, ymmword, ymmword) -> ymmword
function vfmadd_ph_ymm(a, b, c) =
  vfmadd_ph_xmm(a[255..128], b[255..128], c[255..128]) @
  vfmadd_ph_xmm(a[127..0], b[127..0], c[127..0])

val vfmadd_ph_zmm : (zmmword, zmmword, zmmword) -> zmmword
function vfmadd_ph_zmm(a, b, c) =
  vfmadd_ph_ymm(a[511..256], b[511..256], c[511..256]) @
  vfmadd_ph_ymm(a[255..0], b[255..0], c[255..0])

val vfmsub_ph_xmm : (xmmword, xmmword, xmmword) -> xmmword
function vfmsub_ph_xmm(a, b, c) =
  __f16_fmsub(a[127..112], b[127..112], c[127..112]) @
  __f16_fmsub(a[111..96], b[111..96], c[111..96]) @
  __f16_fmsub(a[95..80], b[95..80], c[95..80]) @
  __f16_fmsub(a[79..64], b[79..64], c[79..64]) @
  __f16_fmsub(a[63..48], b[63..48], c[63..48]) @
  __f16_fmsub(a[47..32], b[47..32], c[47..32]) @
  __f16_fmsub(a[31..16], b[31..16], c[31..16]) @
  __f16_fmsub(a[15..0], b[15..0], c[15..0])

val vfmsub_ph_ymm : (ymmword, ymmword, ymmword) -> ymmword
function vfmsub_ph_ymm(a, b, c) =
  vfmsub_ph_xmm(a[255..128], b[255..128], c[255..128]) @
  vfmsub_ph_xmm(a[127..0], b[127..0], c[127..0])

val vfmsub_ph_zmm : (zmmword, zmmword, zmmword) -> zmmword
function vfmsub_ph_zmm(a, b, c) =
  vfmsub_ph_ymm(a[511..256], b[511..256], c[511..256]) @
  vfmsub_ph_ymm(a[255..0], b[255..0], c[255..0])

val vfnmadd_ph_xmm : (xmmword, xmmword, xmmword) -> xmmword
function vfnmadd_ph_xmm(a, b, c) =
  __f16_fnmadd(a[127..112], b[127..112], c[127..112]) @
  __f16_fnmadd(a[111..96], b[111..96], c[111..96]) @
  __f16_fnmadd(a[95..80], b[95..80], c[95..80]) @
  __f16_fnmadd(a[79..64], b[79..64], c[79..64]) @
  __f16_fnmadd(a[63..48], b[63..48], c[63..48]) @
  __f16_fnmadd(a[47..32], b[47..32], c[47..32]) @
  __f16_fnmadd(a[31..16], b[31..16], c[31..16]) @
  __f16_fnmadd(a[15..0], b[15..0], c[15..0])

val vfnmadd_ph_ymm : (ymmword, ymmword, ymmword) -> ymmword
function vfnmadd_ph_ymm(a, b, c) =
  vfnmadd_ph_xmm(a[255..128], b[255..128], c[255..128]) @
  vfnmadd_ph_xmm(a[127..0], b[127..0], c[127..0])

val vfnmadd_ph_zmm : (zmmword, zmmword, zmmword) -> zmmword
function vfnmadd_ph_zmm(a, b, c) =
  vfnmadd_ph_ymm(a[511..256], b[511..256], c[511..256]) @
  vfnmadd_ph_ymm(a[255..0], b[255..0], c[255..0])

val vfnmsub_ph_xmm : (xmmword, xmmword, xmmword) -> xmmword
function vfnmsub_ph_xmm(a, b, c) =
  __f16_fnmsub(a[127..112], b[127..112], c[127..112]) @
  __f16_fnmsub(a[111..96], b[111..96], c[111..96]) @
  __f16_fnmsub(a[95..80], b[95..80], c[95..80]) @
  __f16_fnmsub(a[79..64], b[79..64], c[79..64]) @
  __f16_fnmsub(a[63..48], b[63..48], c[63..48]) @
  __f16_fnmsub(a[47..32], b[47..32], c[47..32]) @
  __f16_fnmsub(a[31..16], b[31..16], c[31..16]) @
  __f16_fnmsub(a[15..0], b[15..0], c[15..0])

val vfnmsub_ph_ymm : (ymmword, ymmword, ymmword) -> ymmword
function vfnmsub_ph_ymm(a, b, c) =
  vfnmsub_ph_xmm(a[255..128], b[255..128], c[255..128]) @
  vfnmsub_ph_xmm(a[127..0], b[127..0], c[127..0])

val vfnmsub_ph_zmm : (zmmword, zmmword, zmmword) -> zmmword
function vfnmsub_ph_zmm(a, b, c) =
  vfnmsub_ph_ymm(a[511..256], b[511..256], c[511..256]) @
  vfnmsub_ph_ymm(a[255..0], b[255..0], c[255..0])

val dispatch_evex_map6 : (byte, Prefixes) -> unit
function dispatch_evex_map6(opcode, pfx) = {
  let mp = get_mandatory_prefix(pfx);
  let op : range(0, 255) = unsigned(opcode);

  match op {

    // MAP6 0x98: VFMADD132PH (66, W=0)
    152 => {
      if mp != MP_66 then raise_UD();
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
      let is_mem : bool = match src { RM_mem(_) => true, _ => false };
      let (eff_ll, saved) = evex_begin_rc(pfx, ~(is_mem));
      match eff_ll {
        0 => {
          let a = read_xmm(dst);
          let b = read_xmm(pfx.evex_vvvvv);
          let c = evex_bcast_src(128,modrm, src, pfx, 16);
          let r = vfmadd_ph_xmm(a, c, b);
          evex_write(dst, evex_wmask(pfx, 8), r)
        },
        1 => {
          let a = read_ymm(dst);
          let b = read_ymm(pfx.evex_vvvvv);
          let c = evex_bcast_src(256,modrm, src, pfx, 16);
          let r = vfmadd_ph_ymm(a, c, b);
          evex_write(dst, evex_wmask(pfx, 16), r)
        },
        2 => {
          let a = read_zmm(dst);
          let b = read_zmm(pfx.evex_vvvvv);
          let c = evex_bcast_src(512,modrm, src, pfx, 16);
          let r = vfmadd_ph_zmm(a, c, b);  // 132: dest*src3 + src2
          evex_write(dst, evex_wmask(pfx, 32), r)
        },
        3 => raise_UD(),
      };
      evex_end_rc(saved)
    },

    // MAP6 0xA8: VFMADD213PH (66, W=0)
    168 => {
      if mp != MP_66 then raise_UD();
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
      let is_mem : bool = match src { RM_mem(_) => true, _ => false };
      let (eff_ll, saved) = evex_begin_rc(pfx, ~(is_mem));
      match eff_ll {
        0 => {
          let a = read_xmm(dst);
          let b = read_xmm(pfx.evex_vvvvv);
          let c = evex_bcast_src(128,modrm, src, pfx, 16);
          let r = vfmadd_ph_xmm(b, a, c);
          evex_write(dst, evex_wmask(pfx, 8), r)
        },
        1 => {
          let a = read_ymm(dst);
          let b = read_ymm(pfx.evex_vvvvv);
          let c = evex_bcast_src(256,modrm, src, pfx, 16);
          let r = vfmadd_ph_ymm(b, a, c);
          evex_write(dst, evex_wmask(pfx, 16), r)
        },
        2 => {
          let a = read_zmm(dst);
          let b = read_zmm(pfx.evex_vvvvv);
          let c = evex_bcast_src(512,modrm, src, pfx, 16);
          let r = vfmadd_ph_zmm(b, a, c);  // 213: src2*dest + src3
          evex_write(dst, evex_wmask(pfx, 32), r)
        },
        3 => raise_UD(),
      };
      evex_end_rc(saved)
    },

    // MAP6 0xB8: VFMADD231PH (66, W=0)
    184 => {
      if mp != MP_66 then raise_UD();
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
      let is_mem : bool = match src { RM_mem(_) => true, _ => false };
      let (eff_ll, saved) = evex_begin_rc(pfx, ~(is_mem));
      match eff_ll {
        0 => {
          let a = read_xmm(dst);
          let b = read_xmm(pfx.evex_vvvvv);
          let c = evex_bcast_src(128,modrm, src, pfx, 16);
          let r = vfmadd_ph_xmm(b, c, a);
          evex_write(dst, evex_wmask(pfx, 8), r)
        },
        1 => {
          let a = read_ymm(dst);
          let b = read_ymm(pfx.evex_vvvvv);
          let c = evex_bcast_src(256,modrm, src, pfx, 16);
          let r = vfmadd_ph_ymm(b, c, a);
          evex_write(dst, evex_wmask(pfx, 16), r)
        },
        2 => {
          let a = read_zmm(dst);
          let b = read_zmm(pfx.evex_vvvvv);
          let c = evex_bcast_src(512,modrm, src, pfx, 16);
          let r = vfmadd_ph_zmm(b, c, a);  // 231: src2*src3 + dest
          evex_write(dst, evex_wmask(pfx, 32), r)
        },
        3 => raise_UD(),
      };
      evex_end_rc(saved)
    },

    // MAP6 0x9A: VFMSUB132PH (66, W=0)
    154 => {
      if mp != MP_66 then raise_UD();
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
      let is_mem : bool = match src { RM_mem(_) => true, _ => false };
      let (eff_ll, saved) = evex_begin_rc(pfx, ~(is_mem));
      match eff_ll {
        0 => {
          let a = read_xmm(dst);
          let b = read_xmm(pfx.evex_vvvvv);
          let c = evex_bcast_src(128,modrm, src, pfx, 16);
          let r = vfmsub_ph_xmm(a, c, b);
          evex_write(dst, evex_wmask(pfx, 8), r)
        },
        1 => {
          let a = read_ymm(dst);
          let b = read_ymm(pfx.evex_vvvvv);
          let c = evex_bcast_src(256,modrm, src, pfx, 16);
          let r = vfmsub_ph_ymm(a, c, b);
          evex_write(dst, evex_wmask(pfx, 16), r)
        },
        2 => {
          let a = read_zmm(dst);
          let b = read_zmm(pfx.evex_vvvvv);
          let c = evex_bcast_src(512,modrm, src, pfx, 16);
          let r = vfmsub_ph_zmm(a, c, b);  // 132: dest*src3 - src2
          evex_write(dst, evex_wmask(pfx, 32), r)
        },
        3 => raise_UD(),
      };
      evex_end_rc(saved)
    },

    // MAP6 0xAA: VFMSUB213PH (66, W=0)
    170 => {
      if mp != MP_66 then raise_UD();
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
      let is_mem : bool = match src { RM_mem(_) => true, _ => false };
      let (eff_ll, saved) = evex_begin_rc(pfx, ~(is_mem));
      match eff_ll {
        0 => {
          let a = read_xmm(dst);
          let b = read_xmm(pfx.evex_vvvvv);
          let c = evex_bcast_src(128,modrm, src, pfx, 16);
          let r = vfmsub_ph_xmm(b, a, c);
          evex_write(dst, evex_wmask(pfx, 8), r)
        },
        1 => {
          let a = read_ymm(dst);
          let b = read_ymm(pfx.evex_vvvvv);
          let c = evex_bcast_src(256,modrm, src, pfx, 16);
          let r = vfmsub_ph_ymm(b, a, c);
          evex_write(dst, evex_wmask(pfx, 16), r)
        },
        2 => {
          let a = read_zmm(dst);
          let b = read_zmm(pfx.evex_vvvvv);
          let c = evex_bcast_src(512,modrm, src, pfx, 16);
          let r = vfmsub_ph_zmm(b, a, c);  // 213: src2*dest - src3
          evex_write(dst, evex_wmask(pfx, 32), r)
        },
        3 => raise_UD(),
      };
      evex_end_rc(saved)
    },

    // MAP6 0xBA: VFMSUB231PH (66, W=0)
    186 => {
      if mp != MP_66 then raise_UD();
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
      let is_mem : bool = match src { RM_mem(_) => true, _ => false };
      let (eff_ll, saved) = evex_begin_rc(pfx, ~(is_mem));
      match eff_ll {
        0 => {
          let a = read_xmm(dst);
          let b = read_xmm(pfx.evex_vvvvv);
          let c = evex_bcast_src(128,modrm, src, pfx, 16);
          let r = vfmsub_ph_xmm(b, c, a);
          evex_write(dst, evex_wmask(pfx, 8), r)
        },
        1 => {
          let a = read_ymm(dst);
          let b = read_ymm(pfx.evex_vvvvv);
          let c = evex_bcast_src(256,modrm, src, pfx, 16);
          let r = vfmsub_ph_ymm(b, c, a);
          evex_write(dst, evex_wmask(pfx, 16), r)
        },
        2 => {
          let a = read_zmm(dst);
          let b = read_zmm(pfx.evex_vvvvv);
          let c = evex_bcast_src(512,modrm, src, pfx, 16);
          let r = vfmsub_ph_zmm(b, c, a);  // 231: src2*src3 - dest
          evex_write(dst, evex_wmask(pfx, 32), r)
        },
        3 => raise_UD(),
      };
      evex_end_rc(saved)
    },

    // MAP6 0x9C: VFNMADD132PH (66, W=0)
    156 => {
      if mp != MP_66 then raise_UD();
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
      let is_mem : bool = match src { RM_mem(_) => true, _ => false };
      let (eff_ll, saved) = evex_begin_rc(pfx, ~(is_mem));
      match eff_ll {
        0 => {
          let a = read_xmm(dst);
          let b = read_xmm(pfx.evex_vvvvv);
          let c = evex_bcast_src(128,modrm, src, pfx, 16);
          let r = vfnmadd_ph_xmm(a, c, b);
          evex_write(dst, evex_wmask(pfx, 8), r)
        },
        1 => {
          let a = read_ymm(dst);
          let b = read_ymm(pfx.evex_vvvvv);
          let c = evex_bcast_src(256,modrm, src, pfx, 16);
          let r = vfnmadd_ph_ymm(a, c, b);
          evex_write(dst, evex_wmask(pfx, 16), r)
        },
        2 => {
          let a = read_zmm(dst);
          let b = read_zmm(pfx.evex_vvvvv);
          let c = evex_bcast_src(512,modrm, src, pfx, 16);
          let r = vfnmadd_ph_zmm(a, c, b);  // 132: -dest*src3 + src2
          evex_write(dst, evex_wmask(pfx, 32), r)
        },
        3 => raise_UD(),
      };
      evex_end_rc(saved)
    },

    // MAP6 0xAC: VFNMADD213PH (66, W=0)
    172 => {
      if mp != MP_66 then raise_UD();
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
      let is_mem : bool = match src { RM_mem(_) => true, _ => false };
      let (eff_ll, saved) = evex_begin_rc(pfx, ~(is_mem));
      match eff_ll {
        0 => {
          let a = read_xmm(dst);
          let b = read_xmm(pfx.evex_vvvvv);
          let c = evex_bcast_src(128,modrm, src, pfx, 16);
          let r = vfnmadd_ph_xmm(b, a, c);
          evex_write(dst, evex_wmask(pfx, 8), r)
        },
        1 => {
          let a = read_ymm(dst);
          let b = read_ymm(pfx.evex_vvvvv);
          let c = evex_bcast_src(256,modrm, src, pfx, 16);
          let r = vfnmadd_ph_ymm(b, a, c);
          evex_write(dst, evex_wmask(pfx, 16), r)
        },
        2 => {
          let a = read_zmm(dst);
          let b = read_zmm(pfx.evex_vvvvv);
          let c = evex_bcast_src(512,modrm, src, pfx, 16);
          let r = vfnmadd_ph_zmm(b, a, c);  // 213: -src2*dest + src3
          evex_write(dst, evex_wmask(pfx, 32), r)
        },
        3 => raise_UD(),
      };
      evex_end_rc(saved)
    },

    // MAP6 0xBC: VFNMADD231PH (66, W=0)
    188 => {
      if mp != MP_66 then raise_UD();
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
      let is_mem : bool = match src { RM_mem(_) => true, _ => false };
      let (eff_ll, saved) = evex_begin_rc(pfx, ~(is_mem));
      match eff_ll {
        0 => {
          let a = read_xmm(dst);
          let b = read_xmm(pfx.evex_vvvvv);
          let c = evex_bcast_src(128,modrm, src, pfx, 16);
          let r = vfnmadd_ph_xmm(b, c, a);
          evex_write(dst, evex_wmask(pfx, 8), r)
        },
        1 => {
          let a = read_ymm(dst);
          let b = read_ymm(pfx.evex_vvvvv);
          let c = evex_bcast_src(256,modrm, src, pfx, 16);
          let r = vfnmadd_ph_ymm(b, c, a);
          evex_write(dst, evex_wmask(pfx, 16), r)
        },
        2 => {
          let a = read_zmm(dst);
          let b = read_zmm(pfx.evex_vvvvv);
          let c = evex_bcast_src(512,modrm, src, pfx, 16);
          let r = vfnmadd_ph_zmm(b, c, a);  // 231: -src2*src3 + dest
          evex_write(dst, evex_wmask(pfx, 32), r)
        },
        3 => raise_UD(),
      };
      evex_end_rc(saved)
    },

    // MAP6 0x9E: VFNMSUB132PH (66, W=0)
    158 => {
      if mp != MP_66 then raise_UD();
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
      let is_mem : bool = match src { RM_mem(_) => true, _ => false };
      let (eff_ll, saved) = evex_begin_rc(pfx, ~(is_mem));
      match eff_ll {
        0 => {
          let a = read_xmm(dst);
          let b = read_xmm(pfx.evex_vvvvv);
          let c = evex_bcast_src(128,modrm, src, pfx, 16);
          let r = vfnmsub_ph_xmm(a, c, b);
          evex_write(dst, evex_wmask(pfx, 8), r)
        },
        1 => {
          let a = read_ymm(dst);
          let b = read_ymm(pfx.evex_vvvvv);
          let c = evex_bcast_src(256,modrm, src, pfx, 16);
          let r = vfnmsub_ph_ymm(a, c, b);
          evex_write(dst, evex_wmask(pfx, 16), r)
        },
        2 => {
          let a = read_zmm(dst);
          let b = read_zmm(pfx.evex_vvvvv);
          let c = evex_bcast_src(512,modrm, src, pfx, 16);
          let r = vfnmsub_ph_zmm(a, c, b);  // 132: -dest*src3 - src2
          evex_write(dst, evex_wmask(pfx, 32), r)
        },
        3 => raise_UD(),
      };
      evex_end_rc(saved)
    },

    // MAP6 0xAE: VFNMSUB213PH (66, W=0)
    174 => {
      if mp != MP_66 then raise_UD();
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
      let is_mem : bool = match src { RM_mem(_) => true, _ => false };
      let (eff_ll, saved) = evex_begin_rc(pfx, ~(is_mem));
      match eff_ll {
        0 => {
          let a = read_xmm(dst);
          let b = read_xmm(pfx.evex_vvvvv);
          let c = evex_bcast_src(128,modrm, src, pfx, 16);
          let r = vfnmsub_ph_xmm(b, a, c);
          evex_write(dst, evex_wmask(pfx, 8), r)
        },
        1 => {
          let a = read_ymm(dst);
          let b = read_ymm(pfx.evex_vvvvv);
          let c = evex_bcast_src(256,modrm, src, pfx, 16);
          let r = vfnmsub_ph_ymm(b, a, c);
          evex_write(dst, evex_wmask(pfx, 16), r)
        },
        2 => {
          let a = read_zmm(dst);
          let b = read_zmm(pfx.evex_vvvvv);
          let c = evex_bcast_src(512,modrm, src, pfx, 16);
          let r = vfnmsub_ph_zmm(b, a, c);  // 213: -src2*dest - src3
          evex_write(dst, evex_wmask(pfx, 32), r)
        },
        3 => raise_UD(),
      };
      evex_end_rc(saved)
    },

    // MAP6 0xBE: VFNMSUB231PH (66, W=0)
    190 => {
      if mp != MP_66 then raise_UD();
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
      let is_mem : bool = match src { RM_mem(_) => true, _ => false };
      let (eff_ll, saved) = evex_begin_rc(pfx, ~(is_mem));
      match eff_ll {
        0 => {
          let a = read_xmm(dst);
          let b = read_xmm(pfx.evex_vvvvv);
          let c = evex_bcast_src(128,modrm, src, pfx, 16);
          let r = vfnmsub_ph_xmm(b, c, a);
          evex_write(dst, evex_wmask(pfx, 8), r)
        },
        1 => {
          let a = read_ymm(dst);
          let b = read_ymm(pfx.evex_vvvvv);
          let c = evex_bcast_src(256,modrm, src, pfx, 16);
          let r = vfnmsub_ph_ymm(b, c, a);
          evex_write(dst, evex_wmask(pfx, 16), r)
        },
        2 => {
          let a = read_zmm(dst);
          let b = read_zmm(pfx.evex_vvvvv);
          let c = evex_bcast_src(512,modrm, src, pfx, 16);
          let r = vfnmsub_ph_zmm(b, c, a);  // 231: -src2*src3 - dest
          evex_write(dst, evex_wmask(pfx, 32), r)
        },
        3 => raise_UD(),
      };
      evex_end_rc(saved)
    },

    // MAP6 0x13: VCVTPH2PSX (66, W=0) / VCVTSH2SS (F3, W=0)
    19 => {
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      match mp {
        MP_66 => {
          // VCVTPH2PSX: packed FP16 to FP32
          let disp_n : range(2, 32) = if pfx.evex_b then 2 else match pfx.evex_ll {
            0 => 8, 1 => 16, 2 => 32, 3 => raise_UD(),
          };
          let src = modrm_rm_evex(modrm, pfx, disp_n);
          let is_mem : bool = match src { RM_mem(_) => true, _ => false };
          match pfx.evex_ll {
            0 => {
              let src : qword = match src {
                RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
                RM_mem(m) => v(m),
              };
              let r : xmmword =
                __f16_to_f32(src[63..48]) @ __f16_to_f32(src[47..32]) @
                __f16_to_f32(src[31..16]) @ __f16_to_f32(src[15..0]);
              evex_write(dst, evex_wmask(pfx, 4), r)
            },
            1 => {
              let src = evex_bcast_src(128,modrm, src, pfx, 16);
              let r : ymmword =
                __f16_to_f32(src[127..112]) @ __f16_to_f32(src[111..96]) @
                __f16_to_f32(src[95..80]) @ __f16_to_f32(src[79..64]) @
                __f16_to_f32(src[63..48]) @ __f16_to_f32(src[47..32]) @
                __f16_to_f32(src[31..16]) @ __f16_to_f32(src[15..0]);
              evex_write(dst, evex_wmask(pfx, 8), r)
            },
            2 => {
              let src = evex_bcast_src(256,modrm, src, pfx, 16);
              let r : zmmword =
                __f16_to_f32(src[255..240]) @ __f16_to_f32(src[239..224]) @
                __f16_to_f32(src[223..208]) @ __f16_to_f32(src[207..192]) @
                __f16_to_f32(src[191..176]) @ __f16_to_f32(src[175..160]) @
                __f16_to_f32(src[159..144]) @ __f16_to_f32(src[143..128]) @
                __f16_to_f32(src[127..112]) @ __f16_to_f32(src[111..96]) @
                __f16_to_f32(src[95..80]) @ __f16_to_f32(src[79..64]) @
                __f16_to_f32(src[63..48]) @ __f16_to_f32(src[47..32]) @
                __f16_to_f32(src[31..16]) @ __f16_to_f32(src[15..0]);
              evex_write(dst, evex_wmask(pfx, 16), r)
            },
            3 => raise_UD(),
          }
        },
        MP_F3 => {
          // VCVTSH2SS: scalar FP16 to FP32
          let src = modrm_rm_evex(modrm, pfx, 2);
          let src1 : xmmword = read_xmm(pfx.evex_vvvvv);
          let src2 : word = match src {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[15..0],
            RM_mem(m) => v(m),
          };
          let r : dword = __f16_to_f32(src2);
          write_xmm(dst, src1[127..32] @ r)
        },
        _ => raise_UD(),
      }
    },

    // MAP6 0x2C: VSCALEFPH (66, W=0)
    44 => {
      if mp != MP_66 then raise_UD();
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
      let is_mem : bool = match src { RM_mem(_) => true, _ => false };
      let (eff_ll, saved) = evex_begin_rc(pfx, ~(is_mem));
      match eff_ll {
        0 => {
          let src1 = read_xmm(pfx.evex_vvvvv);
          let src2 = evex_bcast_src(128,modrm, src, pfx, 16);
          let r = vscalefph_xmm(src1, src2);
          evex_write(dst, evex_wmask(pfx, 8), r)
        },
        1 => {
          let src1 = read_ymm(pfx.evex_vvvvv);
          let src2 = evex_bcast_src(256,modrm, src, pfx, 16);
          let r = vscalefph_ymm(src1, src2);
          evex_write(dst, evex_wmask(pfx, 16), r)
        },
        2 => {
          let src1 = read_zmm(pfx.evex_vvvvv);
          let src2 = evex_bcast_src(512,modrm, src, pfx, 16);
          let r = vscalefph_zmm(src1, src2);
          evex_write(dst, evex_wmask(pfx, 32), r)
        },
        3 => raise_UD(),
      };
      evex_end_rc(saved)
    },

    // MAP6 0x2D: VSCALEFSH (66, W=0)
    45 => {
      if mp != MP_66 then raise_UD();
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_rm_evex(modrm, pfx, 2);
      let src1 : xmmword = read_xmm(pfx.evex_vvvvv);
      let src2 : word = match src {
        RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[15..0],
        RM_mem(m) => v(m),
      };
      let r : word = __f16_scalef(src1[15..0], src2);
      evex_write_scalar(dst, src1[127..16] @ r, pfx, 16)
    },

    // MAP6 0x42: VGETEXPPH (66, W=0)
    66 => {
      if mp != MP_66 then raise_UD();
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
      let is_mem : bool = match src { RM_mem(_) => true, _ => false };
      match pfx.evex_ll {
        0 => {
          let src = evex_bcast_src(128,modrm, src, pfx, 16);
          let r = vgetexpph_xmm(src);
          evex_write(dst, evex_wmask(pfx, 8), r)
        },
        1 => {
          let src = evex_bcast_src(256,modrm, src, pfx, 16);
          let r = vgetexpph_ymm(src);
          evex_write(dst, evex_wmask(pfx, 16), r)
        },
        2 => {
          let src = evex_bcast_src(512,modrm, src, pfx, 16);
          let r = vgetexpph_zmm(src);
          evex_write(dst, evex_wmask(pfx, 32), r)
        },
        3 => raise_UD(),
      }
    },

    // MAP6 0x43: VGETEXPSH (66, W=0)
    67 => {
      if mp != MP_66 then raise_UD();
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_rm_evex(modrm, pfx, 2);
      let src1 : xmmword = read_xmm(pfx.evex_vvvvv);
      let src2 : word = match src {
        RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[15..0],
        RM_mem(m) => v(m),
      };
      let r : word = __f16_getexp(src2);
      evex_write_scalar(dst, src1[127..16] @ r, pfx, 16)
    },

    // MAP6 0x4C: VRCPPH (66, W=0)
    76 => {
      if mp != MP_66 then raise_UD();
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
      let is_mem : bool = match src { RM_mem(_) => true, _ => false };
      match pfx.evex_ll {
        0 => {
          let src = evex_bcast_src(128,modrm, src, pfx, 16);
          let r = vrcpph_xmm(src);
          evex_write(dst, evex_wmask(pfx, 8), r)
        },
        1 => {
          let src = evex_bcast_src(256,modrm, src, pfx, 16);
          let r = vrcpph_ymm(src);
          evex_write(dst, evex_wmask(pfx, 16), r)
        },
        2 => {
          let src = evex_bcast_src(512,modrm, src, pfx, 16);
          let r = vrcpph_zmm(src);
          evex_write(dst, evex_wmask(pfx, 32), r)
        },
        3 => raise_UD(),
      }
    },

    // MAP6 0x4D: VRCPSH (66, W=0)
    77 => {
      if mp != MP_66 then raise_UD();
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_rm_evex(modrm, pfx, 2);
      let src1 : xmmword = read_xmm(pfx.evex_vvvvv);
      let src2 : word = match src {
        RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[15..0],
        RM_mem(m) => v(m),
      };
      let r : word = __f16_rcp(src2);
      evex_write_scalar(dst, src1[127..16] @ r, pfx, 16)
    },

    // MAP6 0x4E: VRSQRTPH (66, W=0)
    78 => {
      if mp != MP_66 then raise_UD();
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
      let is_mem : bool = match src { RM_mem(_) => true, _ => false };
      match pfx.evex_ll {
        0 => {
          let src = evex_bcast_src(128,modrm, src, pfx, 16);
          let r = vrsqrtph_xmm(src);
          evex_write(dst, evex_wmask(pfx, 8), r)
        },
        1 => {
          let src = evex_bcast_src(256,modrm, src, pfx, 16);
          let r = vrsqrtph_ymm(src);
          evex_write(dst, evex_wmask(pfx, 16), r)
        },
        2 => {
          let src = evex_bcast_src(512,modrm, src, pfx, 16);
          let r = vrsqrtph_zmm(src);
          evex_write(dst, evex_wmask(pfx, 32), r)
        },
        3 => raise_UD(),
      }
    },

    // MAP6 0x4F: VRSQRTSH (66, W=0)
    79 => {
      if mp != MP_66 then raise_UD();
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_rm_evex(modrm, pfx, 2);
      let src1 : xmmword = read_xmm(pfx.evex_vvvvv);
      let src2 : word = match src {
        RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[15..0],
        RM_mem(m) => v(m),
      };
      let r : word = __f16_rsqrt(src2);
      evex_write_scalar(dst, src1[127..16] @ r, pfx, 16)
    },

    // MAP6 0x96: VFMADDSUB132PH (66, W=0)
    150 => {
      if mp != MP_66 then raise_UD();
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
      let is_mem : bool = match src { RM_mem(_) => true, _ => false };
      let (eff_ll, saved) = evex_begin_rc(pfx, ~(is_mem));
      match eff_ll {
        0 => {
          let a = read_xmm(dst);
          let b = read_xmm(pfx.evex_vvvvv);
          let c = evex_bcast_src(128,modrm, src, pfx, 16);
          let r = vfmaddsubph_xmm(a, c, b);
          evex_write(dst, evex_wmask(pfx, 8), r)
        },
        1 => {
          let a = read_ymm(dst);
          let b = read_ymm(pfx.evex_vvvvv);
          let c = evex_bcast_src(256,modrm, src, pfx, 16);
          let r = vfmaddsubph_ymm(a, c, b);
          evex_write(dst, evex_wmask(pfx, 16), r)
        },
        2 => {
          let a = read_zmm(dst);
          let b = read_zmm(pfx.evex_vvvvv);
          let c = evex_bcast_src(512,modrm, src, pfx, 16);
          let r = vfmaddsubph_zmm(a, c, b);
          evex_write(dst, evex_wmask(pfx, 32), r)
        },
        3 => raise_UD(),
      };
      evex_end_rc(saved)
    },

    // MAP6 0x97: VFMSUBADD132PH (66, W=0)
    151 => {
      if mp != MP_66 then raise_UD();
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
      let is_mem : bool = match src { RM_mem(_) => true, _ => false };
      let (eff_ll, saved) = evex_begin_rc(pfx, ~(is_mem));
      match eff_ll {
        0 => {
          let a = read_xmm(dst);
          let b = read_xmm(pfx.evex_vvvvv);
          let c = evex_bcast_src(128,modrm, src, pfx, 16);
          let r = vfmsubaddph_xmm(a, c, b);
          evex_write(dst, evex_wmask(pfx, 8), r)
        },
        1 => {
          let a = read_ymm(dst);
          let b = read_ymm(pfx.evex_vvvvv);
          let c = evex_bcast_src(256,modrm, src, pfx, 16);
          let r = vfmsubaddph_ymm(a, c, b);
          evex_write(dst, evex_wmask(pfx, 16), r)
        },
        2 => {
          let a = read_zmm(dst);
          let b = read_zmm(pfx.evex_vvvvv);
          let c = evex_bcast_src(512,modrm, src, pfx, 16);
          let r = vfmsubaddph_zmm(a, c, b);
          evex_write(dst, evex_wmask(pfx, 32), r)
        },
        3 => raise_UD(),
      };
      evex_end_rc(saved)
    },

    // MAP6 0x99: VFMADD132SH (66, W=0)
    153 => {
      if mp != MP_66 then raise_UD();
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_rm_evex(modrm, pfx, 2);
      let src1 : xmmword = read_xmm(pfx.evex_vvvvv);
      let a : word = read_xmm(dst)[15..0];
      let c : word = match src {
        RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[15..0],
        RM_mem(m) => v(m),
      };
      let r : word = __f16_fmadd(a, c, src1[15..0]);
      evex_write_scalar(dst, src1[127..16] @ r, pfx, 16)
    },

    // MAP6 0x9B: VFMSUB132SH (66, W=0)
    155 => {
      if mp != MP_66 then raise_UD();
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_rm_evex(modrm, pfx, 2);
      let src1 : xmmword = read_xmm(pfx.evex_vvvvv);
      let a : word = read_xmm(dst)[15..0];
      let c : word = match src {
        RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[15..0],
        RM_mem(m) => v(m),
      };
      let r : word = __f16_fmsub(a, c, src1[15..0]);
      evex_write_scalar(dst, src1[127..16] @ r, pfx, 16)
    },

    // MAP6 0x9D: VFNMADD132SH (66, W=0)
    157 => {
      if mp != MP_66 then raise_UD();
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_rm_evex(modrm, pfx, 2);
      let src1 : xmmword = read_xmm(pfx.evex_vvvvv);
      let a : word = read_xmm(dst)[15..0];
      let c : word = match src {
        RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[15..0],
        RM_mem(m) => v(m),
      };
      let r : word = __f16_fnmadd(a, c, src1[15..0]);
      evex_write_scalar(dst, src1[127..16] @ r, pfx, 16)
    },

    // MAP6 0x9F: VFNMSUB132SH (66, W=0)
    159 => {
      if mp != MP_66 then raise_UD();
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_rm_evex(modrm, pfx, 2);
      let src1 : xmmword = read_xmm(pfx.evex_vvvvv);
      let a : word = read_xmm(dst)[15..0];
      let c : word = match src {
        RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[15..0],
        RM_mem(m) => v(m),
      };
      let r : word = __f16_fnmsub(a, c, src1[15..0]);
      evex_write_scalar(dst, src1[127..16] @ r, pfx, 16)
    },

    // MAP6 0xA6: VFMADDSUB213PH (66, W=0)
    166 => {
      if mp != MP_66 then raise_UD();
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
      let is_mem : bool = match src { RM_mem(_) => true, _ => false };
      let (eff_ll, saved) = evex_begin_rc(pfx, ~(is_mem));
      match eff_ll {
        0 => {
          let a = read_xmm(pfx.evex_vvvvv);
          let b = read_xmm(dst);
          let c = evex_bcast_src(128,modrm, src, pfx, 16);
          let r = vfmaddsubph_xmm(a, b, c);
          evex_write(dst, evex_wmask(pfx, 8), r)
        },
        1 => {
          let a = read_ymm(pfx.evex_vvvvv);
          let b = read_ymm(dst);
          let c = evex_bcast_src(256,modrm, src, pfx, 16);
          let r = vfmaddsubph_ymm(a, b, c);
          evex_write(dst, evex_wmask(pfx, 16), r)
        },
        2 => {
          let a = read_zmm(pfx.evex_vvvvv);
          let b = read_zmm(dst);
          let c = evex_bcast_src(512,modrm, src, pfx, 16);
          let r = vfmaddsubph_zmm(a, b, c);
          evex_write(dst, evex_wmask(pfx, 32), r)
        },
        3 => raise_UD(),
      };
      evex_end_rc(saved)
    },

    // MAP6 0xA7: VFMSUBADD213PH (66, W=0)
    167 => {
      if mp != MP_66 then raise_UD();
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
      let is_mem : bool = match src { RM_mem(_) => true, _ => false };
      let (eff_ll, saved) = evex_begin_rc(pfx, ~(is_mem));
      match eff_ll {
        0 => {
          let a = read_xmm(pfx.evex_vvvvv);
          let b = read_xmm(dst);
          let c = evex_bcast_src(128,modrm, src, pfx, 16);
          let r = vfmsubaddph_xmm(a, b, c);
          evex_write(dst, evex_wmask(pfx, 8), r)
        },
        1 => {
          let a = read_ymm(pfx.evex_vvvvv);
          let b = read_ymm(dst);
          let c = evex_bcast_src(256,modrm, src, pfx, 16);
          let r = vfmsubaddph_ymm(a, b, c);
          evex_write(dst, evex_wmask(pfx, 16), r)
        },
        2 => {
          let a = read_zmm(pfx.evex_vvvvv);
          let b = read_zmm(dst);
          let c = evex_bcast_src(512,modrm, src, pfx, 16);
          let r = vfmsubaddph_zmm(a, b, c);
          evex_write(dst, evex_wmask(pfx, 32), r)
        },
        3 => raise_UD(),
      };
      evex_end_rc(saved)
    },

    // MAP6 0xA9: VFMADD213SH (66, W=0)
    169 => {
      if mp != MP_66 then raise_UD();
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_rm_evex(modrm, pfx, 2);
      let src1 : xmmword = read_xmm(pfx.evex_vvvvv);
      let a : word = src1[15..0];
      let b : word = read_xmm(dst)[15..0];
      let c : word = match src {
        RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[15..0],
        RM_mem(m) => v(m),
      };
      let r : word = __f16_fmadd(a, b, c);
      evex_write_scalar(dst, src1[127..16] @ r, pfx, 16)
    },

    // MAP6 0xAB: VFMSUB213SH (66, W=0)
    171 => {
      if mp != MP_66 then raise_UD();
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_rm_evex(modrm, pfx, 2);
      let src1 : xmmword = read_xmm(pfx.evex_vvvvv);
      let a : word = src1[15..0];
      let b : word = read_xmm(dst)[15..0];
      let c : word = match src {
        RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[15..0],
        RM_mem(m) => v(m),
      };
      let r : word = __f16_fmsub(a, b, c);
      evex_write_scalar(dst, src1[127..16] @ r, pfx, 16)
    },

    // MAP6 0xAD: VFNMADD213SH (66, W=0)
    173 => {
      if mp != MP_66 then raise_UD();
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_rm_evex(modrm, pfx, 2);
      let src1 : xmmword = read_xmm(pfx.evex_vvvvv);
      let a : word = src1[15..0];
      let b : word = read_xmm(dst)[15..0];
      let c : word = match src {
        RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[15..0],
        RM_mem(m) => v(m),
      };
      let r : word = __f16_fnmadd(a, b, c);
      evex_write_scalar(dst, src1[127..16] @ r, pfx, 16)
    },

    // MAP6 0xAF: VFNMSUB213SH (66, W=0)
    175 => {
      if mp != MP_66 then raise_UD();
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_rm_evex(modrm, pfx, 2);
      let src1 : xmmword = read_xmm(pfx.evex_vvvvv);
      let a : word = src1[15..0];
      let b : word = read_xmm(dst)[15..0];
      let c : word = match src {
        RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[15..0],
        RM_mem(m) => v(m),
      };
      let r : word = __f16_fnmsub(a, b, c);
      evex_write_scalar(dst, src1[127..16] @ r, pfx, 16)
    },

    // MAP6 0xB6: VFMADDSUB231PH (66, W=0)
    182 => {
      if mp != MP_66 then raise_UD();
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
      let is_mem : bool = match src { RM_mem(_) => true, _ => false };
      let (eff_ll, saved) = evex_begin_rc(pfx, ~(is_mem));
      match eff_ll {
        0 => {
          let a = read_xmm(pfx.evex_vvvvv);
          let b = evex_bcast_src(128,modrm, src, pfx, 16);
          let c = read_xmm(dst);
          let r = vfmaddsubph_xmm(a, b, c);
          evex_write(dst, evex_wmask(pfx, 8), r)
        },
        1 => {
          let a = read_ymm(pfx.evex_vvvvv);
          let b = evex_bcast_src(256,modrm, src, pfx, 16);
          let c = read_ymm(dst);
          let r = vfmaddsubph_ymm(a, b, c);
          evex_write(dst, evex_wmask(pfx, 16), r)
        },
        2 => {
          let a = read_zmm(pfx.evex_vvvvv);
          let b = evex_bcast_src(512,modrm, src, pfx, 16);
          let c = read_zmm(dst);
          let r = vfmaddsubph_zmm(a, b, c);
          evex_write(dst, evex_wmask(pfx, 32), r)
        },
        3 => raise_UD(),
      };
      evex_end_rc(saved)
    },

    // MAP6 0xB7: VFMSUBADD231PH (66, W=0)
    183 => {
      if mp != MP_66 then raise_UD();
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
      let is_mem : bool = match src { RM_mem(_) => true, _ => false };
      let (eff_ll, saved) = evex_begin_rc(pfx, ~(is_mem));
      match eff_ll {
        0 => {
          let a = read_xmm(pfx.evex_vvvvv);
          let b = evex_bcast_src(128,modrm, src, pfx, 16);
          let c = read_xmm(dst);
          let r = vfmsubaddph_xmm(a, b, c);
          evex_write(dst, evex_wmask(pfx, 8), r)
        },
        1 => {
          let a = read_ymm(pfx.evex_vvvvv);
          let b = evex_bcast_src(256,modrm, src, pfx, 16);
          let c = read_ymm(dst);
          let r = vfmsubaddph_ymm(a, b, c);
          evex_write(dst, evex_wmask(pfx, 16), r)
        },
        2 => {
          let a = read_zmm(pfx.evex_vvvvv);
          let b = evex_bcast_src(512,modrm, src, pfx, 16);
          let c = read_zmm(dst);
          let r = vfmsubaddph_zmm(a, b, c);
          evex_write(dst, evex_wmask(pfx, 32), r)
        },
        3 => raise_UD(),
      };
      evex_end_rc(saved)
    },

    // MAP6 0xB9: VFMADD231SH (66, W=0)
    185 => {
      if mp != MP_66 then raise_UD();
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_rm_evex(modrm, pfx, 2);
      let src1 : xmmword = read_xmm(pfx.evex_vvvvv);
      let a : word = src1[15..0];
      let c : word = match src {
        RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[15..0],
        RM_mem(m) => v(m),
      };
      let b : word = read_xmm(dst)[15..0];
      let r : word = __f16_fmadd(a, c, b);
      evex_write_scalar(dst, src1[127..16] @ r, pfx, 16)
    },

    // MAP6 0xBB: VFMSUB231SH (66, W=0)
    187 => {
      if mp != MP_66 then raise_UD();
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_rm_evex(modrm, pfx, 2);
      let src1 : xmmword = read_xmm(pfx.evex_vvvvv);
      let a : word = src1[15..0];
      let c : word = match src {
        RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[15..0],
        RM_mem(m) => v(m),
      };
      let b : word = read_xmm(dst)[15..0];
      let r : word = __f16_fmsub(a, c, b);
      evex_write_scalar(dst, src1[127..16] @ r, pfx, 16)
    },

    // MAP6 0xBD: VFNMADD231SH (66, W=0)
    189 => {
      if mp != MP_66 then raise_UD();
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_rm_evex(modrm, pfx, 2);
      let src1 : xmmword = read_xmm(pfx.evex_vvvvv);
      let a : word = src1[15..0];
      let c : word = match src {
        RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[15..0],
        RM_mem(m) => v(m),
      };
      let b : word = read_xmm(dst)[15..0];
      let r : word = __f16_fnmadd(a, c, b);
      evex_write_scalar(dst, src1[127..16] @ r, pfx, 16)
    },

    // MAP6 0xBF: VFNMSUB231SH (66, W=0)
    191 => {
      if mp != MP_66 then raise_UD();
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_rm_evex(modrm, pfx, 2);
      let src1 : xmmword = read_xmm(pfx.evex_vvvvv);
      let a : word = src1[15..0];
      let c : word = match src {
        RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[15..0],
        RM_mem(m) => v(m),
      };
      let b : word = read_xmm(dst)[15..0];
      let r : word = __f16_fnmsub(a, c, b);
      evex_write_scalar(dst, src1[127..16] @ r, pfx, 16)
    },

    // MAP6 0x56: VFCMADDCPH (F2, W=0) / VFMADDCPH (F3, W=0) — complex multiply-accumulate
    86 => {
      if pfx.vex_w then raise_UD();
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let is_mem : bool = match src { RM_mem(_) => true, _ => false };
      let conj : bool = (mp == MP_F2);
      if mp != MP_F2 & mp != MP_F3 then raise_UD();
      match pfx.evex_ll {
        0 => {
          let acc : xmmword = read_xmm(dst);
          let r = cfmaddcph_xmm(read_xmm(pfx.evex_vvvvv), evex_bcast_src(128,modrm, src, pfx, 32), acc, conj);
          evex_write(dst, evex_wmask(pfx, 4), r)
        },
        1 => {
          let acc : ymmword = read_ymm(dst);
          let r = cfmaddcph_ymm(read_ymm(pfx.evex_vvvvv), evex_bcast_src(256,modrm, src, pfx, 32), acc, conj);
          evex_write(dst, evex_wmask(pfx, 8), r)
        },
        2 => {
          let acc : zmmword = read_zmm(dst);
          let r = cfmaddcph_zmm(read_zmm(pfx.evex_vvvvv), evex_bcast_src(512,modrm, src, pfx, 32), acc, conj);
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
      let src = modrm_rm_evex(modrm, pfx, 4);
      let src1 : xmmword = read_xmm(pfx.evex_vvvvv);
      let src2 : dword = match src {
        RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
        RM_mem(m) => v(m),
      };
      let acc : xmmword = read_xmm(dst);
      let s1_re : word = src1[15..0];
      let s1_im : word = src1[31..16];
      let s2_re : word = src2[15..0];
      let s2_im : word = src2[31..16];
      let a_re : word = acc[15..0];
      let a_im : word = acc[31..16];
      let tmp_re : word = __f16_fmadd(s1_re, s2_re, a_re);
      let tmp_im : word = __f16_fmadd(s1_im, s2_re, a_im);
      let (r_re, r_im) : (word, word) = if conj then
        (__f16_fmadd(s1_im, s2_im, tmp_re), __f16_fnmadd(s1_re, s2_im, tmp_im))
      else
        (__f16_fnmadd(s1_im, s2_im, tmp_re), __f16_fmadd(s1_re, s2_im, tmp_im));
      write_xmm(dst, src1[127..32] @ r_im @ r_re)
    },

    // MAP6 0xD6: VFCMULCPH (F2, W=0) / VFMULCPH (F3, W=0) — complex multiply
    214 => {
      if pfx.vex_w then raise_UD();
      let modrm = fetch(1);
      let dst = evex_reg_idx(modrm, pfx);
      let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let is_mem : bool = match src { RM_mem(_) => true, _ => false };
      let conj : bool = (mp == MP_F2);
      if mp != MP_F2 & mp != MP_F3 then raise_UD();
      match pfx.evex_ll {
        0 => {
          let r = cfmulcph_xmm(read_xmm(pfx.evex_vvvvv), evex_bcast_src(128,modrm, src, pfx, 32), conj);
          evex_write(dst, evex_wmask(pfx, 4), r)
        },
        1 => {
          let r = cfmulcph_ymm(read_ymm(pfx.evex_vvvvv), evex_bcast_src(256,modrm, src, pfx, 32), conj);
          evex_write(dst, evex_wmask(pfx, 8), r)
        },
        2 => {
          let r = cfmulcph_zmm(read_zmm(pfx.evex_vvvvv), evex_bcast_src(512,modrm, src, pfx, 32), conj);
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
      let src = modrm_rm_evex(modrm, pfx, 4);
      let src1 : xmmword = read_xmm(pfx.evex_vvvvv);
      let src2 : dword = match src {
        RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
        RM_mem(m) => v(m),
      };
      let s1_re : word = src1[15..0];
      let s1_im : word = src1[31..16];
      let s2_re : word = src2[15..0];
      let s2_im : word = src2[31..16];
      let tmp_re : word = __f16_mul(s1_re, s2_re);
      let tmp_im : word = __f16_mul(s1_im, s2_re);
      let (r_re, r_im) : (word, word) = if conj then
        (__f16_fmadd(s1_im, s2_im, tmp_re), __f16_fnmadd(s1_re, s2_im, tmp_im))
      else
        (__f16_fnmadd(s1_im, s2_im, tmp_re), __f16_fmadd(s1_re, s2_im, tmp_im));
      write_xmm(dst, src1[127..32] @ r_im @ r_re)
    },

    _ => raise_UD(),
  }
}

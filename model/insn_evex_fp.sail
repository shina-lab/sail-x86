// x86-64 — EVEX FP Operations (0F map)
//
// FP mov, arithmetic, compare, and convert instructions.
// Called from dispatch_evex_0f in insn_evex.sail.

// =========================================================================
// VMOVSLDUP — Duplicate Even-Indexed Single-FP Values (per 128-bit lane)
// Each pair of 32-bit floats: [A, B] → [A, A] (even index duplicated)
// =========================================================================

val avx_movsldup : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl)) -> bits('vl)
function avx_movsldup(vl, src) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) {
    let lo = i * 128;
    let s = src[(lo + 127)..lo];
    r[(lo + 127)..lo] = s[95..64] @ s[95..64] @ s[31..0] @ s[31..0]
  };
  r
}

// =========================================================================
// VMOVSHDUP — Duplicate Odd-Indexed Single-FP Values (per 128-bit lane)
// Each pair of 32-bit floats: [A, B] → [B, B] (odd index duplicated)
// =========================================================================

val avx_movshdup : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl)) -> bits('vl)
function avx_movshdup(vl, src) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) {
    let lo = i * 128;
    let s = src[(lo + 127)..lo];
    r[(lo + 127)..lo] = s[127..96] @ s[127..96] @ s[63..32] @ s[63..32]
  };
  r
}

// =========================================================================
// VMOVDDUP — Duplicate Low Double-FP Value in each 128-bit lane
// Each 128-bit lane: [A, B] → [A, A] (low qword duplicated)
// =========================================================================

val avx_movddup : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl)) -> bits('vl)
function avx_movddup(vl, src) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) {
    let lo = i * 128;
    r[(lo + 127)..lo] = src[(lo + 63)..lo] @ src[(lo + 63)..lo]
  };
  r
}

// =========================================================================
// VUNPCKLPS — Unpack and Interleave Low Single-FP Values (per 128-bit lane)
// =========================================================================

val avx_unpcklps : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), bits('vl)) -> bits('vl)
function avx_unpcklps(vl, a, b) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) {
    let lo = i * 128;
    let la = a[(lo + 127)..lo];
    let lb = b[(lo + 127)..lo];
    r[(lo + 127)..lo] = lb[63..32] @ la[63..32] @ lb[31..0] @ la[31..0]
  };
  r
}

// =========================================================================
// VUNPCKHPS — Unpack and Interleave High Single-FP Values (per 128-bit lane)
// =========================================================================

val avx_unpckhps : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), bits('vl)) -> bits('vl)
function avx_unpckhps(vl, a, b) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) {
    let lo = i * 128;
    let la = a[(lo + 127)..lo];
    let lb = b[(lo + 127)..lo];
    r[(lo + 127)..lo] = lb[127..96] @ la[127..96] @ lb[95..64] @ la[95..64]
  };
  r
}

// =========================================================================
// VUNPCKLPD — Unpack and Interleave Low Double-FP Values (per 128-bit lane)
// =========================================================================

val avx_unpcklpd : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), bits('vl)) -> bits('vl)
function avx_unpcklpd(vl, a, b) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) {
    let lo = i * 128;
    r[(lo + 127)..lo] = b[(lo + 63)..lo] @ a[(lo + 63)..lo]
  };
  r
}

// =========================================================================
// VUNPCKHPD — Unpack and Interleave High Double-FP Values (per 128-bit lane)
// =========================================================================

val avx_unpckhpd : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), bits('vl)) -> bits('vl)
function avx_unpckhpd(vl, a, b) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) {
    let lo = i * 128;
    r[(lo + 127)..lo] = b[(lo + 127)..(lo + 64)] @ a[(lo + 127)..(lo + 64)]
  };
  r
}

// =========================================================================
// FP compare predicate (5-bit imm8 for AVX/AVX-512 VCMPPS/VCMPPD)
// =========================================================================

// cmp_pred5_f32, cmp_pred5_f64, eval_fp_predicate: defined in insn_sse_fp.sail

// Polymorphic compare-to-kmask for EVEX VCMPPS/VCMPPD
val avx_vcmpps_kmask : forall 'vl, 'vl in {128, 256, 512}.
  (implicit('vl), bits('vl), bits('vl), range(0, 31)) -> qword
function avx_vcmpps_kmask(vl, a, b, pred) = {
  var r : qword = zeros();
  foreach (i from 0 to ('vl / 32 - 1)) {
    let lo = i * 32;
    r[i] = cmp_pred5_f32(a[(lo+31)..lo], b[(lo+31)..lo], pred)
  };
  r
}

val avx_vcmppd_kmask : forall 'vl, 'vl in {128, 256, 512}.
  (implicit('vl), bits('vl), bits('vl), range(0, 31)) -> qword
function avx_vcmppd_kmask(vl, a, b, pred) = {
  var r : qword = zeros();
  foreach (i from 0 to ('vl / 64 - 1)) {
    let lo = i * 64;
    r[i] = cmp_pred5_f64(a[(lo+63)..lo], b[(lo+63)..lo], pred)
  };
  r
}

// VCVTPS2PD: convert N f32 → N f64 (widening)
val avx_cvtps2pd : forall 'n, 'n in {2, 4, 8}. (int('n), bits('n * 32)) -> bits('n * 64)
function avx_cvtps2pd(n, src) = {
  var r : bits('n * 64) = zeros();
  foreach (i from 0 to ('n - 1)) {
    let slo = i * 32;
    let dlo = i * 64;
    r[(dlo + 63)..dlo] = __f32_to_f64(src[(slo + 31)..slo])
  };
  r
}

// VCVTPD2PS: convert N f64 → N f32 (narrowing)
val avx_cvtpd2ps : forall 'n, 'n in {2, 4, 8}. (int('n), bits('n * 64)) -> bits('n * 32)
function avx_cvtpd2ps(n, src) = {
  var r : bits('n * 32) = zeros();
  foreach (i from 0 to ('n - 1)) {
    let slo = i * 64;
    let dlo = i * 32;
    r[(dlo + 31)..dlo] = __f64_to_f32(src[(slo + 63)..slo])
  };
  r
}

// VSHUFPS: shuffle f32 per 128-bit lane
// Low 2 elements from src1 lane (imm8[1:0], imm8[3:2])
// High 2 elements from src2 lane (imm8[5:4], imm8[7:6])
val shufps_lane : (bits(128), bits(128), bits(8)) -> bits(128)
function shufps_lane(src1, src2, imm) =
  select4_f32(src2, imm[7..6]) @
  select4_f32(src2, imm[5..4]) @
  select4_f32(src1, imm[3..2]) @
  select4_f32(src1, imm[1..0])

val avx_shufps : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), bits('vl), bits(8)) -> bits('vl)
function avx_shufps(vl, src1, src2, imm) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) {
    let lo = i * 128;
    r[(lo + 127)..lo] = shufps_lane(src1[(lo + 127)..lo], src2[(lo + 127)..lo], imm)
  };
  r
}

// VSHUFPD: shuffle f64 per 128-bit lane
// Each bit in imm8 selects low(0) or high(1) qword from src1/src2
// Bit 0 → dest[63:0] from src1, Bit 1 → dest[127:64] from src2
// Bit 2 → dest[191:128] from src1, Bit 3 → dest[255:192] from src2, etc.
val shufpd_lane : (bits(128), bits(128), bit, bit) -> bits(128)
function shufpd_lane(src1, src2, ctrl0, ctrl1) = {
  let lo : bits(64) = blend(src1[63..0], src1[127..64], ctrl0);
  let hi : bits(64) = blend(src2[63..0], src2[127..64], ctrl1);
  hi @ lo
}

val avx_shufpd : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), bits('vl), bits(8)) -> bits('vl)
function avx_shufpd(vl, src1, src2, imm) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) {
    let lo = i * 128;
    let b0 = i * 2;
    r[(lo + 127)..lo] = shufpd_lane(src1[(lo + 127)..lo], src2[(lo + 127)..lo], imm[b0], imm[b0 + 1])
  };
  r
}

// Narrowing conversions: N f64 → N u32/i32 (result is half width)
val avx_cvttpd2udq : forall 'n, 'n in {2, 4, 8}. (int('n), bits('n * 64)) -> bits('n * 32)
function avx_cvttpd2udq(n, src) = {
  var r : bits('n * 32) = zeros();
  foreach (i from 0 to ('n - 1)) { let slo = i * 64; let dlo = i * 32;
    r[(dlo + 31)..dlo] = __f64_to_uint32_trunc(src[(slo + 63)..slo]) };
  r
}

val avx_cvtpd2udq : forall 'n, 'n in {2, 4, 8}. (int('n), bits('n * 64)) -> bits('n * 32)
function avx_cvtpd2udq(n, src) = {
  var r : bits('n * 32) = zeros();
  foreach (i from 0 to ('n - 1)) { let slo = i * 64; let dlo = i * 32;
    r[(dlo + 31)..dlo] = __f64_to_uint32(src[(slo + 63)..slo]) };
  r
}

val avx_cvtpd2dq : forall 'n, 'n in {2, 4, 8}. (int('n), bits('n * 64)) -> bits('n * 32)
function avx_cvtpd2dq(n, src) = {
  var r : bits('n * 32) = zeros();
  foreach (i from 0 to ('n - 1)) { let slo = i * 64; let dlo = i * 32;
    r[(dlo + 31)..dlo] = __f64_to_int32(src[(slo + 63)..slo]) };
  r
}

val avx_cvttpd2dq : forall 'n, 'n in {2, 4, 8}. (int('n), bits('n * 64)) -> bits('n * 32)
function avx_cvttpd2dq(n, src) = {
  var r : bits('n * 32) = zeros();
  foreach (i from 0 to ('n - 1)) { let slo = i * 64; let dlo = i * 32;
    r[(dlo + 31)..dlo] = __f64_to_int32_trunc(src[(slo + 63)..slo]) };
  r
}

// Narrowing conversions: N u64/i64 → N f32 (result is half width)
val avx_cvtuqq2ps : forall 'n, 'n in {2, 4, 8}. (int('n), bits('n * 64)) -> bits('n * 32)
function avx_cvtuqq2ps(n, src) = {
  var r : bits('n * 32) = zeros();
  foreach (i from 0 to ('n - 1)) { let slo = i * 64; let dlo = i * 32;
    r[(dlo + 31)..dlo] = __uint64_to_f32(src[(slo + 63)..slo]) };
  r
}

val avx_cvtqq2ps : forall 'n, 'n in {2, 4, 8}. (int('n), bits('n * 64)) -> bits('n * 32)
function avx_cvtqq2ps(n, src) = {
  var r : bits('n * 32) = zeros();
  foreach (i from 0 to ('n - 1)) { let slo = i * 64; let dlo = i * 32;
    r[(dlo + 31)..dlo] = __int64_to_f32(src[(slo + 63)..slo]) };
  r
}

// Same-width conversions (element-wise, already polymorphic over vl)
val avx_cvttps2udq : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl)) -> bits('vl)
function avx_cvttps2udq(vl, src) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 32 - 1)) { let lo = i * 32;
    r[(lo + 31)..lo] = __f32_to_uint32_trunc(src[(lo + 31)..lo]) };
  r
}

val avx_cvtps2udq : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl)) -> bits('vl)
function avx_cvtps2udq(vl, src) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 32 - 1)) { let lo = i * 32;
    r[(lo + 31)..lo] = __f32_to_uint32(src[(lo + 31)..lo]) };
  r
}

val avx_cvttpd2uqq : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl)) -> bits('vl)
function avx_cvttpd2uqq(vl, src) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 64 - 1)) { let lo = i * 64;
    r[(lo + 63)..lo] = __f64_to_uint64_trunc(src[(lo + 63)..lo]) };
  r
}

val avx_cvtpd2uqq : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl)) -> bits('vl)
function avx_cvtpd2uqq(vl, src) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 64 - 1)) { let lo = i * 64;
    r[(lo + 63)..lo] = __f64_to_uint64(src[(lo + 63)..lo]) };
  r
}

val avx_cvttpd2qq : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl)) -> bits('vl)
function avx_cvttpd2qq(vl, src) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 64 - 1)) { let lo = i * 64;
    r[(lo + 63)..lo] = __f64_to_int64_trunc(src[(lo + 63)..lo]) };
  r
}

val avx_cvtpd2qq : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl)) -> bits('vl)
function avx_cvtpd2qq(vl, src) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 64 - 1)) { let lo = i * 64;
    r[(lo + 63)..lo] = __f64_to_int64(src[(lo + 63)..lo]) };
  r
}

val avx_cvtudq2ps : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl)) -> bits('vl)
function avx_cvtudq2ps(vl, src) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 32 - 1)) { let lo = i * 32;
    r[(lo + 31)..lo] = __uint32_to_f32(src[(lo + 31)..lo]) };
  r
}

val avx_cvtuqq2pd : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl)) -> bits('vl)
function avx_cvtuqq2pd(vl, src) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 64 - 1)) { let lo = i * 64;
    r[(lo + 63)..lo] = __uint64_to_f64(src[(lo + 63)..lo]) };
  r
}

val avx_cvtqq2pd : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl)) -> bits('vl)
function avx_cvtqq2pd(vl, src) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 64 - 1)) { let lo = i * 64;
    r[(lo + 63)..lo] = __int64_to_f64(src[(lo + 63)..lo]) };
  r
}

// Widening conversions: N f32 → N u64/i64 (result is double width)
val avx_cvttps2uqq : forall 'n, 'n in {2, 4, 8}. (int('n), bits('n * 32)) -> bits('n * 64)
function avx_cvttps2uqq(n, src) = {
  var r : bits('n * 64) = zeros();
  foreach (i from 0 to ('n - 1)) { let slo = i * 32; let dlo = i * 64;
    r[(dlo + 63)..dlo] = __f32_to_uint64_trunc(src[(slo + 31)..slo]) };
  r
}

val avx_cvtps2uqq : forall 'n, 'n in {2, 4, 8}. (int('n), bits('n * 32)) -> bits('n * 64)
function avx_cvtps2uqq(n, src) = {
  var r : bits('n * 64) = zeros();
  foreach (i from 0 to ('n - 1)) { let slo = i * 32; let dlo = i * 64;
    r[(dlo + 63)..dlo] = __f32_to_uint64(src[(slo + 31)..slo]) };
  r
}

val avx_cvttps2qq : forall 'n, 'n in {2, 4, 8}. (int('n), bits('n * 32)) -> bits('n * 64)
function avx_cvttps2qq(n, src) = {
  var r : bits('n * 64) = zeros();
  foreach (i from 0 to ('n - 1)) { let slo = i * 32; let dlo = i * 64;
    r[(dlo + 63)..dlo] = __f32_to_int64_trunc(src[(slo + 31)..slo]) };
  r
}

val avx_cvtps2qq : forall 'n, 'n in {2, 4, 8}. (int('n), bits('n * 32)) -> bits('n * 64)
function avx_cvtps2qq(n, src) = {
  var r : bits('n * 64) = zeros();
  foreach (i from 0 to ('n - 1)) { let slo = i * 32; let dlo = i * 64;
    r[(dlo + 63)..dlo] = __f32_to_int64(src[(slo + 31)..slo]) };
  r
}

// Widening conversions: N u32/i32 → N f64 (result is double width)
val avx_cvtudq2pd : forall 'n, 'n in {2, 4, 8}. (int('n), bits('n * 32)) -> bits('n * 64)
function avx_cvtudq2pd(n, src) = {
  var r : bits('n * 64) = zeros();
  foreach (i from 0 to ('n - 1)) { let slo = i * 32; let dlo = i * 64;
    r[(dlo + 63)..dlo] = __uint32_to_f64(src[(slo + 31)..slo]) };
  r
}

val avx_cvtdq2pd : forall 'n, 'n in {2, 4, 8}. (int('n), bits('n * 32)) -> bits('n * 64)
function avx_cvtdq2pd(n, src) = {
  var r : bits('n * 64) = zeros();
  foreach (i from 0 to ('n - 1)) { let slo = i * 32; let dlo = i * 64;
    r[(dlo + 63)..dlo] = __int32_to_f64(src[(slo + 31)..slo]) };
  r
}

val dispatch_evex_fp : (range(0, 255), Prefixes) -> unit
function dispatch_evex_fp(op, pfx) = {
  let mp = get_mandatory_prefix(pfx);

  match op {
  // 0F 10: VMOVUPS/VMOVUPD (EVEX load)
  16 => {
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src2 = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src2 { XRM_mem(_) => true, _ => false };
    match mp {
      // VMOVUPS xmm1/ymm1/zmm1, xmm2/ymm2/zmm2/m128/m256/m512
      MP_NONE => {
        match pfx.evex_ll {
          0 => evex_write(dst, evex_wmask(pfx, 4), evex_src(128,modrm, src2, pfx)),
          1 => evex_write(dst, evex_wmask(pfx, 8), evex_src(256,modrm, src2, pfx)),
          2 => evex_write(dst, evex_wmask(pfx, 16), evex_bcast_src(512,modrm, src2, pfx, 32)),
          3 => raise_UD(),
        }
      },
      // VMOVUPD xmm1/ymm1/zmm1, xmm2/ymm2/zmm2/m128/m256/m512
      MP_66 => {
        match pfx.evex_ll {
          0 => evex_write(dst, evex_wmask(pfx, 2), evex_src(128,modrm, src2, pfx)),
          1 => evex_write(dst, evex_wmask(pfx, 4), evex_src(256,modrm, src2, pfx)),
          2 => evex_write(dst, evex_wmask(pfx, 8), evex_bcast_src(512,modrm, src2, pfx, 64)),
          3 => raise_UD(),
        }
      },
      // VMOVSS (scalar f32 load/move, EVEX)
      MP_F3 => {
        // Memory: xmm1 = zero_extend(m32)
        // Register: xmm1 = xmm2[127:32] @ xmm3[31:0]
        match src2 {
          XRM_mem(m) => {
            let data : dword = v(m);
            write_simd(128, dst, zero_extend(data))
          },
          XRM_reg(xi) => {
            let src1 : xmmword = read_simd(pfx.evex_vvvvv);
            let src2 : dword = read_simd(128, xi)[31..0];
            evex_write_scalar(dst, src1[127..32] @ src2, pfx, 32)
          },
        }
      },
      // VMOVSD (scalar f64 load/move, EVEX)
      MP_F2 => {
        // Memory: xmm1 = zero_extend(m64)
        // Register: xmm1 = xmm2[127:64] @ xmm3[63:0]
        match src2 {
          XRM_mem(m) => {
            let data : qword = v(m);
            write_simd(128, dst, zero_extend(data))
          },
          XRM_reg(xi) => {
            let src1 : xmmword = read_simd(pfx.evex_vvvvv);
            let src2 : qword = read_simd(128, xi)[63..0];
            evex_write_scalar(dst, src1[127..64] @ src2, pfx, 64)
          },
        }
      },
    }
  },

  // 0F 11: VMOVUPS/VMOVUPD/VMOVSS/VMOVSD (EVEX store)
  17 => {
    let modrm = fetch(1);
    let src = evex_reg_idx(modrm, pfx);
    let dest = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    match mp {
      // VMOVUPS xmm2/ymm2/zmm2/m128/m256/m512, xmm1/ymm1/zmm1
      MP_NONE => {
        match dest {
          XRM_reg(xi) => {
            let dst = xi;
            match pfx.evex_ll {
              0 => evex_write(dst, evex_wmask(pfx, 4), read_simd(128, src)),
              1 => evex_write(dst, evex_wmask(pfx, 8), read_simd(256, src)),
              2 => evex_write(dst, evex_wmask(pfx, 16), ZMM[src]),
              3 => raise_UD(),
            }
          },
          XRM_mem(m) => {
            let nbytes : {16, 32, 64} = match pfx.evex_ll { 0 => 16, 1 => 32, 2 => 64 , 3 => { raise_UD(); 16 } };
            evex_masked_mem_store(m, ZMM[src], evex_kmask64(pfx), nbytes, 4)
          },
        }
      },
      // VMOVUPD xmm2/ymm2/zmm2/m128/m256/m512, xmm1/ymm1/zmm1
      MP_66 => {
        match dest {
          XRM_reg(xi) => {
            let dst = xi;
            match pfx.evex_ll {
              0 => evex_write(dst, evex_wmask(pfx, 2), read_simd(128, src)),
              1 => evex_write(dst, evex_wmask(pfx, 4), read_simd(256, src)),
              2 => evex_write(dst, evex_wmask(pfx, 8), ZMM[src]),
              3 => raise_UD(),
            }
          },
          XRM_mem(m) => {
            let nbytes : {16, 32, 64} = match pfx.evex_ll { 0 => 16, 1 => 32, 2 => 64 , 3 => { raise_UD(); 16 } };
            evex_masked_mem_store(m, ZMM[src], evex_kmask64(pfx), nbytes, 8)
          },
        }
      },
      // VMOVSS (scalar f32 store/move, EVEX)
      MP_F3 => {
        // Memory: m32 = xmm1[31:0]
        // Register: xmm1{k1}{z} = xmm2[127:32] @ xmm3[31:0]
        match dest {
          XRM_mem(m) => v(m) = read_simd(128, src)[31..0],
          XRM_reg(xi) => {
            let dst = xi;
            let src1 : xmmword = read_simd(pfx.evex_vvvvv);
            let src2 : dword = read_simd(128, src)[31..0];
            evex_write_scalar(dst, src1[127..32] @ src2, pfx, 32)
          },
        }
      },
      // VMOVSD (scalar f64 store/move, EVEX)
      MP_F2 => {
        // Memory: m64 = xmm1[63:0]
        // Register: xmm1{k1}{z} = xmm2[127:64] @ xmm3[63:0]
        match dest {
          XRM_mem(m) => v(m) = read_simd(128, src)[63..0],
          XRM_reg(xi) => {
            let dst = xi;
            let src1 : xmmword = read_simd(pfx.evex_vvvvv);
            let src2 : qword = read_simd(128, src)[63..0];
            evex_write_scalar(dst, src1[127..64] @ src2, pfx, 64)
          },
        }
      },
    }
  },

  // 0F 12: VMOVLPS (NP,mem) / VMOVHLPS (NP,reg) / VMOVLPD (66,mem) / VMOVSLDUP (F3) / VMOVDDUP (F2)
  18 => {
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    match mp {
      // VMOVLPS (mem) or VMOVHLPS (reg) — XMM only
      MP_NONE => {
        if pfx.evex_ll != 0 then raise_UD();
        let src = modrm_xrm_evex(modrm, pfx, 8);
        match src {
          // VMOVHLPS xmm1, xmm2, xmm3
          XRM_reg(xi) => {
            let src1 : xmmword = read_simd(pfx.evex_vvvvv);
            let src2 : xmmword = read_simd(xi);
            let result : xmmword = src1[127..64] @ src2[127..64];
            write_simd(128, dst, result)
          },
          // VMOVLPS xmm2, xmm1, m64
          XRM_mem(m) => {
            let src1 : xmmword = read_simd(pfx.evex_vvvvv);
            let m64val = v(64, m);
            let result : xmmword = src1[127..64] @ m64val;
            write_simd(128, dst, result)
          },
        }
      },
      // VMOVLPD xmm2, xmm1, m64 — XMM only
      MP_66 => {
        if pfx.evex_ll != 0 then raise_UD();
        let src = modrm_xrm_evex(modrm, pfx, 8);
        let src1 : xmmword = read_simd(pfx.evex_vvvvv);
        let m64val : qword = match src { XRM_mem(m) => read_mem(m), _ => raise_UD() };
        let result : xmmword = src1[127..64] @ m64val;
        write_simd(128, dst, result)
      },
      // VMOVSLDUP xmm1/ymm1/zmm1, xmm2/ymm2/zmm2/m128/m256/m512
      MP_F3 => {
        let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
        let vl = ll_to_vl(pfx.evex_ll);
        let mask = evex_wmask(pfx, vl / 32);
        evex_write(dst, mask, avx_movsldup(evex_src(vl, modrm, src, pfx)))
      },
      // VMOVDDUP xmm1/ymm1/zmm1, xmm2/ymm2/zmm2/m128/m256/m512
      MP_F2 => {
        let src2 = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
        match pfx.evex_ll {
          0 => {
            // 128-bit MOVDDUP: source is xmm or m64
            let src : xmmword = match src2 {
              XRM_reg(xi) => read_simd(xi),
              XRM_mem(m) => {
                let data = v(64, m);
                data @ data
              },
            };
            evex_write(dst, evex_wmask(pfx, 2), avx_movddup(src))
          },
          1 => {
            let mask = evex_wmask(pfx, 4);
            evex_write(dst, mask, avx_movddup(evex_src(256, modrm, src2, pfx)))
          },
          2 => {
            let mask = evex_wmask(pfx, 8);
            evex_write(dst, mask, avx_movddup(evex_src(512, modrm, src2, pfx)))
          },
          3 => raise_UD(),
        }
      },
    }
  },

  // 0F 13: VMOVLPS (NP,store) / VMOVLPD (66,store) — XMM only, m64
  19 => {
    let modrm = fetch(1);
    if pfx.evex_ll != 0 then raise_UD();
    let dest = modrm_xrm_evex(modrm, pfx, 8);
    let src : xmmword = read_simd(evex_reg_idx(modrm, pfx));
    match dest { XRM_mem(m) => write_mem(m, src[63..0]), _ => raise_UD() }
  },

  // 0F 14: VUNPCKLPS (NP,W0) / VUNPCKLPD (66,W1)
  20 => {
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = ll_to_vl(pfx.evex_ll);
    match mp {
      // VUNPCKLPS (W0)
      MP_NONE => {
        let mask = evex_wmask(pfx, vl / 32);
        evex_write(dst, mask, avx_unpcklps(read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(modrm, src, pfx, 32)))
      },
      // VUNPCKLPD (W1)
      MP_66 => {
        let mask = evex_wmask(pfx, vl / 64);
        evex_write(dst, mask, avx_unpcklpd(read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(modrm, src, pfx, 64)))
      },
      _ => raise_UD(),
    }
  },

  // 0F 15: VUNPCKHPS (NP,W0) / VUNPCKHPD (66,W1)
  21 => {
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = ll_to_vl(pfx.evex_ll);
    match mp {
      // VUNPCKHPS (W0)
      MP_NONE => {
        let mask = evex_wmask(pfx, vl / 32);
        evex_write(dst, mask, avx_unpckhps(read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(modrm, src, pfx, 32)))
      },
      // VUNPCKHPD (W1)
      MP_66 => {
        let mask = evex_wmask(pfx, vl / 64);
        evex_write(dst, mask, avx_unpckhpd(read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(modrm, src, pfx, 64)))
      },
      _ => raise_UD(),
    }
  },

  // 0F 16: VMOVHPS (NP,mem) / VMOVLHPS (NP,reg) / VMOVHPD (66,mem) / VMOVSHDUP (F3)
  22 => {
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    match mp {
      // VMOVHPS (mem) or VMOVLHPS (reg) — XMM only
      MP_NONE => {
        if pfx.evex_ll != 0 then raise_UD();
        let src = modrm_xrm_evex(modrm, pfx, 8);
        match src {
          // VMOVLHPS xmm1, xmm2, xmm3
          XRM_reg(xi) => {
            let src1 : xmmword = read_simd(pfx.evex_vvvvv);
            let src2 : xmmword = read_simd(xi);
            let result : xmmword = src2[63..0] @ src1[63..0];
            write_simd(128, dst, result)
          },
          // VMOVHPS xmm2, xmm1, m64
          XRM_mem(m) => {
            let src1 : xmmword = read_simd(pfx.evex_vvvvv);
            let m64val = v(64, m);
            let result : xmmword = m64val @ src1[63..0];
            write_simd(128, dst, result)
          },
        }
      },
      // VMOVHPD xmm2, xmm1, m64 — XMM only
      MP_66 => {
        if pfx.evex_ll != 0 then raise_UD();
        let src = modrm_xrm_evex(modrm, pfx, 8);
        let src1 : xmmword = read_simd(pfx.evex_vvvvv);
        let m64val : qword = match src { XRM_mem(m) => read_mem(m), _ => raise_UD() };
        let result : xmmword = m64val @ src1[63..0];
        write_simd(128, dst, result)
      },
      // VMOVSHDUP xmm1/ymm1/zmm1, xmm2/ymm2/zmm2/m128/m256/m512
      MP_F3 => {
        let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
        let vl = ll_to_vl(pfx.evex_ll);
        let mask = evex_wmask(pfx, vl / 32);
        evex_write(dst, mask, avx_movshdup(evex_src(vl, modrm, src, pfx)))
      },
      _ => raise_UD(),
    }
  },

  // 0F 17: VMOVHPS (NP,store) / VMOVHPD (66,store) — XMM only, m64
  23 => {
    let modrm = fetch(1);
    if pfx.evex_ll != 0 then raise_UD();
    let dest = modrm_xrm_evex(modrm, pfx, 8);
    let src : xmmword = read_simd(evex_reg_idx(modrm, pfx));
    match dest { XRM_mem(m) => write_mem(m, src[127..64]), _ => raise_UD() }
  },

  // 0F 28: VMOVAPS/VMOVAPD (EVEX load)
  40 => {
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src2 = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    match pfx.evex_ll {
      0 => if mp == MP_66 then evex_write(dst, evex_wmask(pfx, 2), evex_src(128,modrm, src2, pfx))
             else evex_write(dst, evex_wmask(pfx, 4), evex_src(128,modrm, src2, pfx)),
      1 => if mp == MP_66 then evex_write(dst, evex_wmask(pfx, 4), evex_src(256,modrm, src2, pfx))
             else evex_write(dst, evex_wmask(pfx, 8), evex_src(256,modrm, src2, pfx)),
      2 => if mp == MP_66 then evex_write(dst, evex_wmask(pfx, 8), evex_src(512,modrm, src2, pfx))
             else evex_write(dst, evex_wmask(pfx, 16), evex_src(512,modrm, src2, pfx)),
      3 => raise_UD(),
    }
  },

  // 0F 29: VMOVAPS/VMOVAPD (EVEX store)
  41 => {
    let modrm = fetch(1);
    let src = evex_reg_idx(modrm, pfx);
    let dest = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    match dest {
      XRM_reg(xi) => {
        let dst = xi;
        match pfx.evex_ll {
          0 => if mp == MP_66 then evex_write(dst, evex_wmask(pfx, 2), read_simd(128, src))
                 else evex_write(dst, evex_wmask(pfx, 4), read_simd(128, src)),
          1 => if mp == MP_66 then evex_write(dst, evex_wmask(pfx, 4), read_simd(256, src))
                 else evex_write(dst, evex_wmask(pfx, 8), read_simd(256, src)),
          2 => if mp == MP_66 then evex_write(dst, evex_wmask(pfx, 8), ZMM[src])
                 else evex_write(dst, evex_wmask(pfx, 16), ZMM[src]),
          3 => raise_UD(),
        }
      },
      XRM_mem(m) => {
        let elem : {4, 8} = if mp == MP_66 then 8 else 4;
        let nbytes : {16, 32, 64} = match pfx.evex_ll { 0 => 16, 1 => 32, 2 => 64 , 3 => { raise_UD(); 16 } };
        evex_masked_mem_store(m, ZMM[src], evex_kmask64(pfx), nbytes, elem)
      },
    }
  },

  // 0F 2A: VCVTSI2SS (F3) / VCVTSI2SD (F2) — scalar, GPR/mem to XMM
  // F3: {er}, F2/W1: {er}
  42 => {
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let (_, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
    let os : {16, 32, 64} = if pfx.rex_w then 64 else 32;
    let src_val : qword = match src {
      RM_reg(r) => zero_extend(v(os, r)),
      RM_mem(m) => match os {
        64 => v(m),
        _    => zero_extend(v(32, m)),
      },
    };
    let src1 : xmmword = read_simd(pfx.evex_vvvvv);
    match mp {
      // VCVTSI2SS xmm1, xmm2, r/m32
      MP_F3 => {
        let result : dword = match os {
          64 => __int64_to_f32(src_val),
          _    => __int32_to_f32(src_val[31..0]),
        };
        var xmm : xmmword = src1;
        xmm[31..0] = result;
        write_simd(128, dst, xmm)
      },
      // VCVTSI2SD xmm1, xmm2, r/m32
      MP_F2 => {
        let result : qword = match os {
          64 => __int64_to_f64(src_val),
          _    => __int32_to_f64(src_val[31..0]),
        };
        var xmm : xmmword = src1;
        xmm[63..0] = result;
        write_simd(128, dst, xmm)
      },
      _ => raise_UD(),
    };
    evex_end_rc(saved_mxcsr)
  },

  // 0F 2B: VMOVNTPS (NP) / VMOVNTPD (66) — non-temporal store
  43 => {
    let (src, dest) = fetch_modrm_evex(pfx, evex_full_disp_n(pfx));
    match dest {
      XRM_reg(xi) => raise_UD(),
      XRM_mem(m) => {
        let a = seg_linear(m, 64);
        match pfx.evex_ll {
          0 => write_mem(a, read_simd(128, src)),
          1 => write_mem(a, read_simd(256, src)),
          2 => write_mem(a, ZMM[src]),
          3 => raise_UD(),
        }
      },
    }
  },

  // 0F 2C: VCVTTSS2SI (F3) / VCVTTSD2SI (F2) — scalar, XMM/mem to GPR (truncate)
  // Both support {sae}.
  44 => {
    let modrm = fetch(1);
    let dst_gpr = modrm_reg(modrm, pfx);
    let os : {16, 32, 64} = if pfx.rex_w then 64 else 32;
    match mp {
      // VCVTTSS2SI — supports {sae}
      MP_F3 => {
        let src = modrm_xrm_evex(modrm, pfx, 4);
        let is_mem : bool = match src { XRM_mem(_) => true, _ => false };
        let (_, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
        let src_f32 : dword = match src {
          XRM_reg(xi) => read_simd(128, xi)[31..0],
          XRM_mem(m) => v(m),
        };
        match os {
          64 => v(dst_gpr) = __f32_to_int64_trunc(src_f32),
          _  => v(dst_gpr) = zero_extend(32, __f32_to_int32_trunc(src_f32)),
        };
        evex_end_rc(saved_mxcsr)
      },
      // VCVTTSD2SI — supports {sae}
      MP_F2 => {
        let src = modrm_xrm_evex(modrm, pfx, 8);
        let is_mem : bool = match src { XRM_mem(_) => true, _ => false };
        let (_, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
        let src_f64 : qword = match src {
          XRM_reg(xi) => read_simd(128, xi)[63..0],
          XRM_mem(m) => v(m),
        };
        match os {
          64 => v(dst_gpr) = __f64_to_int64_trunc(src_f64),
          _  => v(dst_gpr) = zero_extend(32, __f64_to_int32_trunc(src_f64)),
        };
        evex_end_rc(saved_mxcsr)
      },
      _ => raise_UD(),
    }
  },

  // 0F 2D: VCVTSS2SI (F3) / VCVTSD2SI (F2) — scalar, XMM/mem to GPR (round)
  // Both support {er}.
  45 => {
    let modrm = fetch(1);
    let dst_gpr = modrm_reg(modrm, pfx);
    let os : {16, 32, 64} = if pfx.rex_w then 64 else 32;
    match mp {
      // VCVTSS2SI — supports {er}
      MP_F3 => {
        let src = modrm_xrm_evex(modrm, pfx, 4);
        let is_mem : bool = match src { XRM_mem(_) => true, _ => false };
        let (_, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
        let src_f32 : dword = match src {
          XRM_reg(xi) => read_simd(128, xi)[31..0],
          XRM_mem(m) => v(m),
        };
        match os {
          64 => v(dst_gpr) = __f32_to_int64(src_f32),
          _  => v(dst_gpr) = zero_extend(32, __f32_to_int32(src_f32)),
        };
        evex_end_rc(saved_mxcsr)
      },
      // VCVTSD2SI — supports {er}
      MP_F2 => {
        let src = modrm_xrm_evex(modrm, pfx, 8);
        let is_mem : bool = match src { XRM_mem(_) => true, _ => false };
        let (_, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
        let src_f64 : qword = match src {
          XRM_reg(xi) => read_simd(128, xi)[63..0],
          XRM_mem(m) => v(m),
        };
        match os {
          64 => v(dst_gpr) = __f64_to_int64(src_f64),
          _  => v(dst_gpr) = zero_extend(32, __f64_to_int32(src_f64)),
        };
        evex_end_rc(saved_mxcsr)
      },
      _ => raise_UD(),
    }
  },

  // 0F 2E: VUCOMISS (NP,W0) / VUCOMISD (66,W1) — compare scalars, set EFLAGS
  46 => {
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    match mp {
      // VUCOMISS xmm1, xmm2/m32
      MP_NONE => {
        let src2 = modrm_xrm_evex(modrm, pfx, 4);
        let src : xmmword = match src2 {
          XRM_reg(xi) => read_simd(xi),
          XRM_mem(m) => zero_extend(v(32, m)),
        };
        let a : dword = read_simd(128, dst)[31..0];
        let b : dword = src[31..0];
        match fp_compare(a, b) {
          FP_UNORDERED => { ZF = 0b1; PF = 0b1; CF = 0b1;  },
          FP_GT        => { ZF = 0b0; PF = 0b0; CF = 0b0; },
          FP_LT        => { ZF = 0b0; PF = 0b0; CF = 0b1;  },
          FP_EQ        => { ZF = 0b1; PF = 0b0; CF = 0b0; },
        };
        OF = 0b0;
        SF = 0b0;
        AF = 0b0
      },
      // VUCOMISD xmm1, xmm2/m64
      MP_66 => {
        let src2 = modrm_xrm_evex(modrm, pfx, 8);
        let src : xmmword = match src2 {
          XRM_reg(xi) => read_simd(xi),
          XRM_mem(m) => zero_extend(v(64, m)),
        };
        let a : qword = read_simd(128, dst)[63..0];
        let b : qword = src[63..0];
        match fp_compare(a, b) {
          FP_UNORDERED => { ZF = 0b1; PF = 0b1; CF = 0b1;  },
          FP_GT        => { ZF = 0b0; PF = 0b0; CF = 0b0; },
          FP_LT        => { ZF = 0b0; PF = 0b0; CF = 0b1;  },
          FP_EQ        => { ZF = 0b1; PF = 0b0; CF = 0b0; },
        };
        OF = 0b0;
        SF = 0b0;
        AF = 0b0
      },
      _ => raise_UD(),
    }
  },

  // 0F 2F: VCOMISS (NP,W0) / VCOMISD (66,W1) — ordered compare scalars, set EFLAGS
  47 => {
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    match mp {
      // VCOMISS xmm1, xmm2/m32
      MP_NONE => {
        let src2 = modrm_xrm_evex(modrm, pfx, 4);
        let src : xmmword = match src2 {
          XRM_reg(xi) => read_simd(xi),
          XRM_mem(m) => zero_extend(v(32, m)),
        };
        let a : dword = read_simd(128, dst)[31..0];
        let b : dword = src[31..0];
        match fp_compare(a, b) {
          FP_UNORDERED => { ZF = 0b1; PF = 0b1; CF = 0b1;  },
          FP_GT        => { ZF = 0b0; PF = 0b0; CF = 0b0; },
          FP_LT        => { ZF = 0b0; PF = 0b0; CF = 0b1;  },
          FP_EQ        => { ZF = 0b1; PF = 0b0; CF = 0b0; },
        };
        OF = 0b0;
        SF = 0b0;
        AF = 0b0
      },
      // VCOMISD xmm1, xmm2/m64
      MP_66 => {
        let src2 = modrm_xrm_evex(modrm, pfx, 8);
        let src : xmmword = match src2 {
          XRM_reg(xi) => read_simd(xi),
          XRM_mem(m) => zero_extend(v(64, m)),
        };
        let a : qword = read_simd(128, dst)[63..0];
        let b : qword = src[63..0];
        match fp_compare(a, b) {
          FP_UNORDERED => { ZF = 0b1; PF = 0b1; CF = 0b1;  },
          FP_GT        => { ZF = 0b0; PF = 0b0; CF = 0b0; },
          FP_LT        => { ZF = 0b0; PF = 0b0; CF = 0b1;  },
          FP_EQ        => { ZF = 0b1; PF = 0b0; CF = 0b0; },
        };
        OF = 0b0;
        SF = 0b0;
        AF = 0b0
      },
      _ => raise_UD(),
    }
  },

  // 0F 58: VADDPS/VADDPD (EVEX) — supports {er} at 512-bit
  88 => {
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { XRM_mem(_) => true, _ => false };
    let (eff_ll, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
    match mp {
      // VADDPS xmm1/ymm1/zmm1, xmm2/ymm2/zmm2, xmm3/ymm3/zmm3/m128/m256/m512
      MP_NONE => {
        let vl = ll_to_vl(eff_ll);
        let mask = evex_wmask(pfx, vl / 32);
        evex_write(dst, mask, packed_binop(PB_FAdd, 32, read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(modrm, src, pfx, 32)))
      },
      // VADDPD xmm1/ymm1/zmm1, xmm2/ymm2/zmm2, xmm3/ymm3/zmm3/m128/m256/m512
      MP_66 => {
        let vl = ll_to_vl(eff_ll);
        let mask = evex_wmask(pfx, vl / 64);
        evex_write(dst, mask, packed_binop(PB_FAdd, 64, read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(modrm, src, pfx, 64)))
      },
      // VADDSS (scalar f32, EVEX) — supports {er}
      MP_F3 => {
        let src1 : xmmword = read_simd(pfx.evex_vvvvv);
        let src2_f32 : dword = match src {
          XRM_reg(xi) => read_simd(128, xi)[31..0],
          XRM_mem(m) => v(m),
        };
        evex_write_scalar(dst, src1[127..32] @ fp_add(src1[31..0], src2_f32), pfx, 32)
      },
      // VADDSD (scalar f64, EVEX) — supports {er}
      MP_F2 => {
        let src1 : xmmword = read_simd(pfx.evex_vvvvv);
        let src2_f64 : qword = match src {
          XRM_reg(xi) => read_simd(128, xi)[63..0],
          XRM_mem(m) => v(m),
        };
        evex_write_scalar(dst, src1[127..64] @ fp_add(src1[63..0], src2_f64), pfx, 64)
      },
    };
    evex_end_rc(saved_mxcsr)
  },

  // 0F 59: VMULPS/VMULPD (EVEX) — supports {er} at 512-bit
  89 => {
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { XRM_mem(_) => true, _ => false };
    let (eff_ll, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
    match mp {
      // VMULPS xmm1/ymm1/zmm1, xmm2/ymm2/zmm2, xmm3/ymm3/zmm3/m128/m256/m512
      MP_NONE => {
        let vl = ll_to_vl(eff_ll);
        let mask = evex_wmask(pfx, vl / 32);
        evex_write(dst, mask, packed_binop(PB_FMul, 32, read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(modrm, src, pfx, 32)))
      },
      // VMULPD xmm1/ymm1/zmm1, xmm2/ymm2/zmm2, xmm3/ymm3/zmm3/m128/m256/m512
      MP_66 => {
        let vl = ll_to_vl(eff_ll);
        let mask = evex_wmask(pfx, vl / 64);
        evex_write(dst, mask, packed_binop(PB_FMul, 64, read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(modrm, src, pfx, 64)))
      },
      // VMULSS (scalar f32, EVEX) — supports {er}
      MP_F3 => {
        let src1 : xmmword = read_simd(pfx.evex_vvvvv);
        let src2_f32 : dword = match src {
          XRM_reg(xi) => read_simd(128, xi)[31..0],
          XRM_mem(m) => v(m),
        };
        evex_write_scalar(dst, src1[127..32] @ fp_mul(src1[31..0], src2_f32), pfx, 32)
      },
      // VMULSD (scalar f64, EVEX) — supports {er}
      MP_F2 => {
        let src1 : xmmword = read_simd(pfx.evex_vvvvv);
        let src2_f64 : qword = match src {
          XRM_reg(xi) => read_simd(128, xi)[63..0],
          XRM_mem(m) => v(m),
        };
        evex_write_scalar(dst, src1[127..64] @ fp_mul(src1[63..0], src2_f64), pfx, 64)
      },
    };
    evex_end_rc(saved_mxcsr)
  },

  // 0F 5A: VCVTPS2PD (NP,W0) / VCVTPD2PS (66,W1) / VCVTSS2SD (F3) / VCVTSD2SS (F2)
  // NP: {sae}, 66: {er}, F3: {sae}, F2: {er}
  90 => {
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    match mp {
      // VCVTPS2PD: f32→f64, source is half-width — supports {sae}
      MP_NONE => {
        // For VCVTPS2PD the source is half-width, so disp_n varies by LL.
        // We need to determine is_mem before modrm_xrm_evex for the rc wrapper,
        // but modrm_xrm_evex needs disp_n which depends on eff_ll. Since EVEX.b=1
        // only applies to reg-reg, for mem operands EVEX.b means broadcast and LL
        // is the real vector length. So we can peek at modrm to check reg vs mem.
        let is_mem : bool = modrm[7..6] != 0b11;
        let (eff_ll, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
        match eff_ll {
          // XMM: 2 f32 (m64/xmm low) → 2 f64 (XMM)
          0 => {
            let src2 = modrm_xrm_evex(modrm, pfx, 8);
            let src : qword = evex_bcast_src(128,modrm, src2, pfx, 32)[63..0];
            evex_write(dst, evex_wmask(pfx, 2), avx_cvtps2pd(2, src))
          },
          // YMM: 4 f32 (XMM) → 4 f64 (YMM)
          1 => {
            let src2 = modrm_xrm_evex(modrm, pfx, 16);
            let src = evex_bcast_src(128,modrm, src2, pfx, 32);
            evex_write(dst, evex_wmask(pfx, 4), avx_cvtps2pd(4, src))
          },
          // ZMM: 8 f32 (YMM) → 8 f64 (ZMM)
          2 => {
            let src2 = modrm_xrm_evex(modrm, pfx, 32);
            let src = evex_bcast_src(256,modrm, src2, pfx, 32);
            evex_write(dst, evex_wmask(pfx, 8), avx_cvtps2pd(8, src))
          },
          3 => raise_UD(),
        };
        evex_end_rc(saved_mxcsr)
      },
      // VCVTPD2PS: f64→f32, result is half-width — supports {er}
      MP_66 => {
        let is_mem : bool = modrm[7..6] != 0b11;
        let (eff_ll, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
        match eff_ll {
          // XMM→XMM low: 2 f64 → 2 f32
          0 => {
            let src2 = modrm_xrm_evex(modrm, pfx, 16);
            let src = evex_bcast_src(128,modrm, src2, pfx, 64);
            let result : qword = avx_cvtpd2ps(2, src);
            evex_write(dst, evex_wmask(pfx, 4), zeros(64) @ result)
          },
          // YMM→XMM: 4 f64 → 4 f32
          1 => {
            let src2 = modrm_xrm_evex(modrm, pfx, 32);
            let src = evex_bcast_src(256,modrm, src2, pfx, 64);
            evex_write(dst, evex_wmask(pfx, 4), avx_cvtpd2ps(4, src))
          },
          // ZMM→YMM: 8 f64 → 8 f32
          2 => {
            let src2 = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
            let src = evex_bcast_src(512,modrm, src2, pfx, 64);
            evex_write(dst, evex_wmask(pfx, 8), avx_cvtpd2ps(8, src))
          },
          3 => raise_UD(),
        };
        evex_end_rc(saved_mxcsr)
      },
      // VCVTSS2SD: scalar f32→f64 — supports {sae}
      MP_F3 => {
        let src = modrm_xrm_evex(modrm, pfx, 4);
        let is_mem : bool = match src { XRM_mem(_) => true, _ => false };
        let (_, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
        let src1 : xmmword = read_simd(pfx.evex_vvvvv);
        let src_f32 : dword = match src {
          XRM_reg(xi) => read_simd(128, xi)[31..0],
          XRM_mem(m) => v(m),
        };
        var result : xmmword = src1;
        result[63..0] = __f32_to_f64(src_f32);
        write_simd(128, dst, result);
        evex_end_rc(saved_mxcsr)
      },
      // VCVTSD2SS: scalar f64→f32 — supports {er}
      MP_F2 => {
        let src = modrm_xrm_evex(modrm, pfx, 8);
        let is_mem : bool = match src { XRM_mem(_) => true, _ => false };
        let (_, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
        let src1 : xmmword = read_simd(pfx.evex_vvvvv);
        let src_f64 : qword = match src {
          XRM_reg(xi) => read_simd(128, xi)[63..0],
          XRM_mem(m) => v(m),
        };
        var result : xmmword = src1;
        result[31..0] = __f64_to_f32(src_f64);
        write_simd(128, dst, result);
        evex_end_rc(saved_mxcsr)
      },
    }
  },

  // 0F 5B: VCVTDQ2PS (NP,W0) / VCVTQQ2PS (NP,W1) / VCVTPS2DQ (66,W0) / VCVTTPS2DQ (F3,W0)
  // VCVTDQ2PS, VCVTQQ2PS, VCVTPS2DQ support {er} at 512-bit
  91 => {
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { XRM_mem(_) => true, _ => false };
    let (eff_ll, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
    match mp {
      MP_NONE => {
        match (pfx.rex_w, eff_ll) {
          // VCVTQQ2PS: i64→f32 (narrowing, result half-width)
          (true, 0) => evex_write(dst, evex_wmask(pfx, 4), zero_extend(avx_cvtqq2ps(2,evex_bcast_src(128,modrm, src, pfx, 64))) : xmmword),
          (true, 1) => evex_write(dst, evex_wmask(pfx, 4), avx_cvtqq2ps(4,evex_bcast_src(256,modrm, src, pfx, 64))),
          (true, 2) => evex_write(dst, evex_wmask(pfx, 8), avx_cvtqq2ps(8,evex_bcast_src(512,modrm, src, pfx, 64))),
          // VCVTDQ2PS: i32→f32
          (false, _) => {
            let vl = ll_to_vl(eff_ll);
            let mask = evex_wmask(pfx, vl / 32);
            evex_write(dst, mask, packed_unop(PU_CvtDQ2PS, 32, evex_bcast_src(vl, modrm, src, pfx, 32)))
          },
          _ => raise_UD(),
        }
      },
      // VCVTPS2DQ xmm1/ymm1/zmm1, xmm2/ymm2/zmm2/m128/m256/m512
      MP_66 => {
        let vl = ll_to_vl(eff_ll);
        let mask = evex_wmask(pfx, vl / 32);
        evex_write(dst, mask, packed_unop(PU_CvtPS2DQ, 32, evex_bcast_src(vl, modrm, src, pfx, 32)))
      },
      // VCVTTPS2DQ (truncation — no {er} but no harm from the wrapper)
      MP_F3 => {
        let vl = ll_to_vl(eff_ll);
        let mask = evex_wmask(pfx, vl / 32);
        evex_write(dst, mask, packed_unop(PU_CvtTPS2DQ, 32, evex_bcast_src(vl, modrm, src, pfx, 32)))
      },
      _ => raise_UD(),
    };
    evex_end_rc(saved_mxcsr)
  },

  // 0F 5C: VSUBPS/VSUBPD (EVEX) — supports {er} at 512-bit
  92 => {
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { XRM_mem(_) => true, _ => false };
    let (eff_ll, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
    match mp {
      // VSUBPS xmm1/ymm1/zmm1, xmm2/ymm2/zmm2, xmm3/ymm3/zmm3/m128/m256/m512
      MP_NONE => {
        let vl = ll_to_vl(eff_ll);
        let mask = evex_wmask(pfx, vl / 32);
        evex_write(dst, mask, packed_binop(PB_FSub, 32, read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(modrm, src, pfx, 32)))
      },
      // VSUBPD xmm1/ymm1/zmm1, xmm2/ymm2/zmm2, xmm3/ymm3/zmm3/m128/m256/m512
      MP_66 => {
        let vl = ll_to_vl(eff_ll);
        let mask = evex_wmask(pfx, vl / 64);
        evex_write(dst, mask, packed_binop(PB_FSub, 64, read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(modrm, src, pfx, 64)))
      },
      // VSUBSS (scalar f32, EVEX) — supports {er}
      MP_F3 => {
        let src1 : xmmword = read_simd(pfx.evex_vvvvv);
        let src2_f32 : dword = match src {
          XRM_reg(xi) => read_simd(128, xi)[31..0],
          XRM_mem(m) => v(m),
        };
        evex_write_scalar(dst, src1[127..32] @ fp_sub(src1[31..0], src2_f32), pfx, 32)
      },
      // VSUBSD (scalar f64, EVEX) — supports {er}
      MP_F2 => {
        let src1 : xmmword = read_simd(pfx.evex_vvvvv);
        let src2_f64 : qword = match src {
          XRM_reg(xi) => read_simd(128, xi)[63..0],
          XRM_mem(m) => v(m),
        };
        evex_write_scalar(dst, src1[127..64] @ fp_sub(src1[63..0], src2_f64), pfx, 64)
      },
    };
    evex_end_rc(saved_mxcsr)
  },

  // 0F 54: VANDPS/PD / 0F 55: VANDNPS/PD / 0F 56: VORPS/PD / 0F 57: VXORPS/PD (EVEX bitwise)
  op if 84 <= op & op <= 87 => {
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { XRM_mem(_) => true, _ => false };
    let vl = evex_vl(pfx);
    let eb = evex_elem(pfx);
    let src1 = read_simd(vl, pfx.evex_vvvvv);
    let src2 = evex_bcast_src(vl, modrm, src, pfx, eb);
    let mask = evex_wmask(pfx, vl / eb);
    match op {
      84 => evex_write(dst, mask, src1 & src2),
      85 => evex_write(dst, mask, ~(src1) & src2),
      86 => evex_write(dst, mask, src1 | src2),
      87 => evex_write(dst, mask, src1 ^ src2),
      _  => (),
    }
  },

  // 0F 78: VCVTTPS2UDQ (NP,W0) / VCVTTPD2UDQ (NP,W1) / VCVTTSS2USI (F3) / VCVTTSD2USI (F2)
  //        / VCVTTPS2UQQ (66,W0) / VCVTTPD2UQQ (66,W1)
  // All packed forms support {sae}; scalar forms support {sae} too.
  // When EVEX.b=1 reg-reg, LL encodes RC but vector length is forced to 512-bit.
  120 => {
    let modrm = fetch(1);
    match mp {
      // NP,W0=VCVTTPS2UDQ, NP,W1=VCVTTPD2UDQ
      MP_NONE => {
        let dst = evex_reg_idx(modrm, pfx);
        let src2 = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
        let is_mem : bool = match src2 { XRM_mem(_) => true, _ => false };
        let (eff_ll, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
        match (pfx.rex_w, eff_ll) {
          // VCVTTPD2UDQ: f64→u32 trunc (narrowing)
          (true, 0) => {
            let src = evex_bcast_src(128,modrm, src2, pfx, 64);
            evex_write(dst, evex_wmask(pfx, 4), zero_extend(avx_cvttpd2udq(2,src)) : xmmword)
          },
          (true, 1) => {
            let src = evex_bcast_src(256,modrm, src2, pfx, 64);
            evex_write(dst, evex_wmask(pfx, 4), avx_cvttpd2udq(4,src))
          },
          (true, 2) => {
            let src = evex_bcast_src(512,modrm, src2, pfx, 64);
            evex_write(dst, evex_wmask(pfx, 8), avx_cvttpd2udq(8,src))
          },
          // VCVTTPS2UDQ: f32→u32 trunc
          (false, _) => {
            let vl = ll_to_vl(eff_ll);
            let mask = evex_wmask(pfx, vl / 32);
            evex_write(dst, mask, avx_cvttps2udq(evex_bcast_src(vl, modrm, src2, pfx, 32)))
          },
          _ => raise_UD(),
        };
        evex_end_rc(saved_mxcsr)
      },
      // VCVTTSS2USI: scalar f32→unsigned GPR trunc — supports {sae}
      MP_F3 => {
        let rm2 = modrm_xrm_evex(modrm, pfx, 4);
        let is_mem : bool = match rm2 { XRM_mem(_) => true, _ => false };
        let (_, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
        let dst_gpr = modrm_reg(modrm, pfx);
        let src_f32 : dword = match rm2 {
          XRM_reg(xi) => read_simd(128, xi)[31..0],
          XRM_mem(m) => v(m),
        };
        if pfx.rex_w then v(dst_gpr) = __f32_to_uint64_trunc(src_f32)
        else v(dst_gpr) = zero_extend(32, __f32_to_uint32_trunc(src_f32));
        evex_end_rc(saved_mxcsr)
      },
      // VCVTTSD2USI: scalar f64→unsigned GPR trunc — supports {sae}
      MP_F2 => {
        let rm2 = modrm_xrm_evex(modrm, pfx, 8);
        let is_mem : bool = match rm2 { XRM_mem(_) => true, _ => false };
        let (_, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
        let dst_gpr = modrm_reg(modrm, pfx);
        let src_f64 : qword = match rm2 {
          XRM_reg(xi) => read_simd(128, xi)[63..0],
          XRM_mem(m) => v(m),
        };
        if pfx.rex_w then v(dst_gpr) = __f64_to_uint64_trunc(src_f64)
        else v(dst_gpr) = zero_extend(32, __f64_to_uint32_trunc(src_f64));
        evex_end_rc(saved_mxcsr)
      },
      // VCVTTPS2UQQ (W0) / VCVTTPD2UQQ (W1) — supports {sae}
      MP_66 => {
        let dst = evex_reg_idx(modrm, pfx);
        let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
        let is_mem : bool = match src { XRM_mem(_) => true, _ => false };
        let (eff_ll, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
        match (pfx.rex_w, eff_ll) {
          // VCVTTPD2UQQ: f64→u64 trunc
          (true, _) => {
            let vl = ll_to_vl(eff_ll);
            let mask = evex_wmask(pfx, vl / 64);
            evex_write(dst, mask, avx_cvttpd2uqq(evex_bcast_src(vl, modrm, src, pfx, 64)))
          },
          // VCVTTPS2UQQ: f32→u64 trunc (widening)
          (false, 0) => evex_write(dst, evex_wmask(pfx, 2), avx_cvttps2uqq(2,evex_bcast_src(128,modrm, src, pfx, 32)[63..0])),
          (false, 1) => evex_write(dst, evex_wmask(pfx, 4), avx_cvttps2uqq(4,evex_bcast_src(128,modrm, src, pfx, 32))),
          (false, 2) => evex_write(dst, evex_wmask(pfx, 8), avx_cvttps2uqq(8,evex_bcast_src(256,modrm, src, pfx, 32))),
          _ => raise_UD(),
        };
        evex_end_rc(saved_mxcsr)
      },
    }
  },

  // 0F 79: VCVTPS2UDQ (NP,W0) / VCVTPD2UDQ (NP,W1) / VCVTSS2USI (F3) / VCVTSD2USI (F2)
  //        / VCVTPS2UQQ (66,W0) / VCVTPD2UQQ (66,W1)
  // All packed forms support {er}; scalar forms support {er} too.
  121 => {
    let modrm = fetch(1);
    match mp {
      // NP,W0=VCVTPS2UDQ, NP,W1=VCVTPD2UDQ — supports {er}
      MP_NONE => {
        let dst = evex_reg_idx(modrm, pfx);
        let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
        let is_mem : bool = match src { XRM_mem(_) => true, _ => false };
        let (eff_ll, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
        match (pfx.rex_w, eff_ll) {
          // VCVTPD2UDQ: f64→u32 round (narrowing)
          (true, 0) => evex_write(dst, evex_wmask(pfx, 4), zero_extend(avx_cvtpd2udq(2,evex_bcast_src(128,modrm, src, pfx, 64))) : xmmword),
          (true, 1) => evex_write(dst, evex_wmask(pfx, 4), avx_cvtpd2udq(4,evex_bcast_src(256,modrm, src, pfx, 64))),
          (true, 2) => evex_write(dst, evex_wmask(pfx, 8), avx_cvtpd2udq(8,evex_bcast_src(512,modrm, src, pfx, 64))),
          // VCVTPS2UDQ: f32→u32 round
          (false, _) => {
            let vl = ll_to_vl(eff_ll);
            let mask = evex_wmask(pfx, vl / 32);
            evex_write(dst, mask, avx_cvtps2udq(evex_bcast_src(vl, modrm, src, pfx, 32)))
          },
          _ => raise_UD(),
        };
        evex_end_rc(saved_mxcsr)
      },
      // VCVTSS2USI: scalar f32→unsigned GPR round — supports {er}
      MP_F3 => {
        let rm2 = modrm_xrm_evex(modrm, pfx, 4);
        let is_mem : bool = match rm2 { XRM_mem(_) => true, _ => false };
        let (_, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
        let dst_gpr = modrm_reg(modrm, pfx);
        let src_f32 : dword = match rm2 {
          XRM_reg(xi) => read_simd(128, xi)[31..0],
          XRM_mem(m) => v(m),
        };
        if pfx.rex_w then v(dst_gpr) = __f32_to_uint64(src_f32)
        else v(dst_gpr) = zero_extend(32, __f32_to_uint32(src_f32));
        evex_end_rc(saved_mxcsr)
      },
      // VCVTSD2USI: scalar f64→unsigned GPR round — supports {er}
      MP_F2 => {
        let rm2 = modrm_xrm_evex(modrm, pfx, 8);
        let is_mem : bool = match rm2 { XRM_mem(_) => true, _ => false };
        let (_, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
        let dst_gpr = modrm_reg(modrm, pfx);
        let src_f64 : qword = match rm2 {
          XRM_reg(xi) => read_simd(128, xi)[63..0],
          XRM_mem(m) => v(m),
        };
        if pfx.rex_w then v(dst_gpr) = __f64_to_uint64(src_f64)
        else v(dst_gpr) = zero_extend(32, __f64_to_uint32(src_f64));
        evex_end_rc(saved_mxcsr)
      },
      // VCVTPS2UQQ (W0) / VCVTPD2UQQ (W1) — supports {er}
      MP_66 => {
        let dst = evex_reg_idx(modrm, pfx);
        let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
        let is_mem : bool = match src { XRM_mem(_) => true, _ => false };
        let (eff_ll, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
        match (pfx.rex_w, eff_ll) {
          // VCVTPD2UQQ: f64→u64 round
          (true, _) => {
            let vl = ll_to_vl(eff_ll);
            let mask = evex_wmask(pfx, vl / 64);
            evex_write(dst, mask, avx_cvtpd2uqq(evex_bcast_src(vl, modrm, src, pfx, 64)))
          },
          // VCVTPS2UQQ: f32→u64 round (widening)
          (false, 0) => evex_write(dst, evex_wmask(pfx, 2), avx_cvtps2uqq(2,evex_bcast_src(128,modrm, src, pfx, 32)[63..0])),
          (false, 1) => evex_write(dst, evex_wmask(pfx, 4), avx_cvtps2uqq(4,evex_bcast_src(128,modrm, src, pfx, 32))),
          (false, 2) => evex_write(dst, evex_wmask(pfx, 8), avx_cvtps2uqq(8,evex_bcast_src(256,modrm, src, pfx, 32))),
          _ => raise_UD(),
        };
        evex_end_rc(saved_mxcsr)
      },
    }
  },

  // 0F 7A: VCVTTPS2QQ (66,W0) / VCVTTPD2QQ (66,W1) / VCVTUDQ2PS (F2,W0) / VCVTUQQ2PS (F2,W1)
  //        / VCVTUDQ2PD (F3,W0) / VCVTUQQ2PD (F3,W1)
  // 66: {sae}, F2: {er}, F3/W1 (VCVTUQQ2PD): {er}
  122 => {
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { XRM_mem(_) => true, _ => false };
    let (eff_ll, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
    match mp {
      // VCVTTPS2QQ (W0) / VCVTTPD2QQ (W1) — supports {sae}
      MP_66 => {
        match (pfx.rex_w, eff_ll) {
          // VCVTTPD2QQ: f64→i64 trunc
          (true, _) => {
            let vl = ll_to_vl(eff_ll);
            let mask = evex_wmask(pfx, vl / 64);
            evex_write(dst, mask, avx_cvttpd2qq(evex_bcast_src(vl, modrm, src, pfx, 64)))
          },
          // VCVTTPS2QQ: f32→i64 trunc (widening)
          (false, 0) => evex_write(dst, evex_wmask(pfx, 2), avx_cvttps2qq(2,evex_bcast_src(128,modrm, src, pfx, 32)[63..0])),
          (false, 1) => evex_write(dst, evex_wmask(pfx, 4), avx_cvttps2qq(4,evex_bcast_src(128,modrm, src, pfx, 32))),
          (false, 2) => evex_write(dst, evex_wmask(pfx, 8), avx_cvttps2qq(8,evex_bcast_src(256,modrm, src, pfx, 32))),
          _ => raise_UD(),
        }
      },
      // VCVTUDQ2PS (W0) / VCVTUQQ2PS (W1) — supports {er}
      MP_F2 => {
        match (pfx.rex_w, eff_ll) {
          // VCVTUQQ2PS: u64→f32 (narrowing)
          (true, 0) => evex_write(dst, evex_wmask(pfx, 4), zero_extend(avx_cvtuqq2ps(2,evex_bcast_src(128,modrm, src, pfx, 64))) : xmmword),
          (true, 1) => evex_write(dst, evex_wmask(pfx, 4), avx_cvtuqq2ps(4,evex_bcast_src(256,modrm, src, pfx, 64))),
          (true, 2) => evex_write(dst, evex_wmask(pfx, 8), avx_cvtuqq2ps(8,evex_bcast_src(512,modrm, src, pfx, 64))),
          // VCVTUDQ2PS: u32→f32
          (false, _) => {
            let vl = ll_to_vl(eff_ll);
            let mask = evex_wmask(pfx, vl / 32);
            evex_write(dst, mask, avx_cvtudq2ps(evex_bcast_src(vl, modrm, src, pfx, 32)))
          },
          _ => raise_UD(),
        }
      },
      // VCVTUDQ2PD (W0) / VCVTUQQ2PD (W1) — W1 supports {er}
      MP_F3 => {
        match (pfx.rex_w, eff_ll) {
          // VCVTUQQ2PD: u64→f64
          (true, _) => {
            let vl = ll_to_vl(eff_ll);
            let mask = evex_wmask(pfx, vl / 64);
            evex_write(dst, mask, avx_cvtuqq2pd(evex_bcast_src(vl, modrm, src, pfx, 64)))
          },
          // VCVTUDQ2PD: u32→f64 (widening, exact — no rounding needed)
          (false, 0) => evex_write(dst, evex_wmask(pfx, 2), avx_cvtudq2pd(2,evex_bcast_src(128,modrm, src, pfx, 32)[63..0])),
          (false, 1) => evex_write(dst, evex_wmask(pfx, 4), avx_cvtudq2pd(4,evex_bcast_src(128,modrm, src, pfx, 32))),
          (false, 2) => evex_write(dst, evex_wmask(pfx, 8), avx_cvtudq2pd(8,evex_bcast_src(256,modrm, src, pfx, 32))),
          _ => raise_UD(),
        }
      },
      _ => raise_UD(),
    };
    evex_end_rc(saved_mxcsr)
  },

  // 0F 7B: VCVTPS2QQ (66,W0) / VCVTPD2QQ (66,W1) / VCVTUSI2SS (F3) / VCVTUSI2SD (F2)
  // 66: {er}, F3: {er}, F2/W1: {er}
  123 => {
    let modrm = fetch(1);
    match mp {
      // VCVTPS2QQ (W0) / VCVTPD2QQ (W1) — supports {er}
      MP_66 => {
        let dst = evex_reg_idx(modrm, pfx);
        let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
        let is_mem : bool = match src { XRM_mem(_) => true, _ => false };
        let (eff_ll, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
        match (pfx.rex_w, eff_ll) {
          // VCVTPD2QQ: f64→i64 round
          (true, _) => {
            let vl = ll_to_vl(eff_ll);
            let mask = evex_wmask(pfx, vl / 64);
            evex_write(dst, mask, avx_cvtpd2qq(evex_bcast_src(vl, modrm, src, pfx, 64)))
          },
          // VCVTPS2QQ: f32→i64 round (widening)
          (false, 0) => evex_write(dst, evex_wmask(pfx, 2), avx_cvtps2qq(2,evex_bcast_src(128,modrm, src, pfx, 32)[63..0])),
          (false, 1) => evex_write(dst, evex_wmask(pfx, 4), avx_cvtps2qq(4,evex_bcast_src(128,modrm, src, pfx, 32))),
          (false, 2) => evex_write(dst, evex_wmask(pfx, 8), avx_cvtps2qq(8,evex_bcast_src(256,modrm, src, pfx, 32))),
          _ => raise_UD(),
        };
        evex_end_rc(saved_mxcsr)
      },
      // VCVTUSI2SS: scalar u32/u64→f32 — supports {er}
      MP_F3 => {
        let dst_xmm = evex_reg_idx(modrm, pfx);
        let rm2 = modrm_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
        let is_mem : bool = match rm2 { RM_mem(_) => true, _ => false };
        let (_, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
        let src1 : xmmword = read_simd(pfx.evex_vvvvv);
        let result_f32 : dword =
          if pfx.rex_w then __uint64_to_f32(v(rm2)) else __uint32_to_f32(v(rm2));
        var dst_val = src1;
        dst_val[31..0] = result_f32;
        write_simd(128, dst_xmm, dst_val);
        evex_end_rc(saved_mxcsr)
      },
      // VCVTUSI2SD: scalar u32/u64→f64 — W1 supports {er}
      MP_F2 => {
        let dst_xmm = evex_reg_idx(modrm, pfx);
        let rm2 = modrm_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
        let is_mem : bool = match rm2 { RM_mem(_) => true, _ => false };
        let (_, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
        let src1 : xmmword = read_simd(pfx.evex_vvvvv);
        let result_f64 : qword =
          if pfx.rex_w then __uint64_to_f64(v(rm2)) else __uint32_to_f64(v(rm2));
        var dst_val = src1;
        dst_val[63..0] = result_f64;
        write_simd(128, dst_xmm, dst_val);
        evex_end_rc(saved_mxcsr)
      },
      _ => raise_UD(),
    }
  },

  // 0F 6F: VMOVDQA32/VMOVDQA64/VMOVDQU32/VMOVDQU64 (EVEX load)
  // 0F 51: VSQRTPS (NP) / VSQRTPD (66) — supports {er} at 512-bit
  81 => {
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { XRM_mem(_) => true, _ => false };
    let (eff_ll, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
    match mp {
      // VSQRTPS xmm1/ymm1/zmm1, xmm2/ymm2/zmm2/m128/m256/m512
      MP_NONE => {
        let vl = ll_to_vl(eff_ll);
        let mask = evex_wmask(pfx, vl / 32);
        evex_write(dst, mask, packed_unop(PU_FSqrt, 32, evex_bcast_src(vl, modrm, src, pfx, 32)))
      },
      // VSQRTPD xmm1/ymm1/zmm1, xmm2/ymm2/zmm2/m128/m256/m512
      MP_66 => {
        let vl = ll_to_vl(eff_ll);
        let mask = evex_wmask(pfx, vl / 64);
        evex_write(dst, mask, packed_unop(PU_FSqrt, 64, evex_bcast_src(vl, modrm, src, pfx, 64)))
      },
      // VSQRTSS (scalar f32, EVEX) — supports {er}
      MP_F3 => {
        let src1 : xmmword = read_simd(pfx.evex_vvvvv);
        let src2_f32 : dword = match src {
          XRM_reg(xi) => read_simd(128, xi)[31..0],
          XRM_mem(m) => v(m),
        };
        evex_write_scalar(dst, src1[127..32] @ fp_sqrt(src2_f32), pfx, 32)
      },
      // VSQRTSD (scalar f64, EVEX) — supports {er}
      MP_F2 => {
        let src1 : xmmword = read_simd(pfx.evex_vvvvv);
        let src2_f64 : qword = match src {
          XRM_reg(xi) => read_simd(128, xi)[63..0],
          XRM_mem(m) => v(m),
        };
        evex_write_scalar(dst, src1[127..64] @ fp_sqrt(src2_f64), pfx, 64)
      },
    };
    evex_end_rc(saved_mxcsr)
  },

  // 0F 5D: VMINPS/PD/SS/SD (EVEX)
  93 => {
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { XRM_mem(_) => true, _ => false };
    match mp {
      // VMINPS xmm1/ymm1/zmm1, xmm2/ymm2/zmm2, xmm3/ymm3/zmm3/m128/m256/m512
      MP_NONE => {
        let vl = evex_vl(pfx);
        let mask = evex_wmask(pfx, vl / 32);
        evex_write(dst, mask, packed_binop(PB_FMin, 32, read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(modrm, src, pfx, 32)))
      },
      // VMINPD xmm1/ymm1/zmm1, xmm2/ymm2/zmm2, xmm3/ymm3/zmm3/m128/m256/m512
      MP_66 => {
        let vl = evex_vl(pfx);
        let mask = evex_wmask(pfx, vl / 64);
        evex_write(dst, mask, packed_binop(PB_FMin, 64, read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(modrm, src, pfx, 64)))
      },
      // VMINSS (scalar f32, EVEX)
      MP_F3 => {
        let src1 : xmmword = read_simd(pfx.evex_vvvvv);
        let src2_f32 : dword = match src {
          XRM_reg(xi) => read_simd(128, xi)[31..0],
          XRM_mem(m) => v(m),
        };
        evex_write_scalar(dst, src1[127..32] @ fp_min(src1[31..0], src2_f32), pfx, 32)
      },
      // VMINSD (scalar f64, EVEX)
      MP_F2 => {
        let src1 : xmmword = read_simd(pfx.evex_vvvvv);
        let src2_f64 : qword = match src {
          XRM_reg(xi) => read_simd(128, xi)[63..0],
          XRM_mem(m) => v(m),
        };
        evex_write_scalar(dst, src1[127..64] @ fp_min(src1[63..0], src2_f64), pfx, 64)
      },
    }
  },

  // 0F 5E: VDIVPS (NP) / VDIVPD (66) — supports {er} at 512-bit
  94 => {
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { XRM_mem(_) => true, _ => false };
    let (eff_ll, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
    match mp {
      // VDIVPS xmm1/ymm1/zmm1, xmm2/ymm2/zmm2, xmm3/ymm3/zmm3/m128/m256/m512
      MP_NONE => {
        let vl = ll_to_vl(eff_ll);
        let mask = evex_wmask(pfx, vl / 32);
        evex_write(dst, mask, packed_binop(PB_FDiv, 32, read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(modrm, src, pfx, 32)))
      },
      // VDIVPD xmm1/ymm1/zmm1, xmm2/ymm2/zmm2, xmm3/ymm3/zmm3/m128/m256/m512
      MP_66 => {
        let vl = ll_to_vl(eff_ll);
        let mask = evex_wmask(pfx, vl / 64);
        evex_write(dst, mask, packed_binop(PB_FDiv, 64, read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(modrm, src, pfx, 64)))
      },
      // VDIVSS (scalar f32, EVEX) — supports {er}
      MP_F3 => {
        let src1 : xmmword = read_simd(pfx.evex_vvvvv);
        let src2_f32 : dword = match src {
          XRM_reg(xi) => read_simd(128, xi)[31..0],
          XRM_mem(m) => v(m),
        };
        evex_write_scalar(dst, src1[127..32] @ fp_div(src1[31..0], src2_f32), pfx, 32)
      },
      // VDIVSD (scalar f64, EVEX) — supports {er}
      MP_F2 => {
        let src1 : xmmword = read_simd(pfx.evex_vvvvv);
        let src2_f64 : qword = match src {
          XRM_reg(xi) => read_simd(128, xi)[63..0],
          XRM_mem(m) => v(m),
        };
        evex_write_scalar(dst, src1[127..64] @ fp_div(src1[63..0], src2_f64), pfx, 64)
      },
    };
    evex_end_rc(saved_mxcsr)
  },

  // 0F 5F: VMAXPS/PD/SS/SD (EVEX)
  95 => {
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { XRM_mem(_) => true, _ => false };
    match mp {
      // VMAXPS xmm1/ymm1/zmm1, xmm2/ymm2/zmm2, xmm3/ymm3/zmm3/m128/m256/m512
      MP_NONE => {
        let vl = evex_vl(pfx);
        let mask = evex_wmask(pfx, vl / 32);
        evex_write(dst, mask, packed_binop(PB_FMax, 32, read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(modrm, src, pfx, 32)))
      },
      // VMAXPD xmm1/ymm1/zmm1, xmm2/ymm2/zmm2, xmm3/ymm3/zmm3/m128/m256/m512
      MP_66 => {
        let vl = evex_vl(pfx);
        let mask = evex_wmask(pfx, vl / 64);
        evex_write(dst, mask, packed_binop(PB_FMax, 64, read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(modrm, src, pfx, 64)))
      },
      // VMAXSS (scalar f32, EVEX)
      MP_F3 => {
        let src1 : xmmword = read_simd(pfx.evex_vvvvv);
        let src2_f32 : dword = match src {
          XRM_reg(xi) => read_simd(128, xi)[31..0],
          XRM_mem(m) => v(m),
        };
        evex_write_scalar(dst, src1[127..32] @ fp_max(src1[31..0], src2_f32), pfx, 32)
      },
      // VMAXSD (scalar f64, EVEX)
      MP_F2 => {
        let src1 : xmmword = read_simd(pfx.evex_vvvvv);
        let src2_f64 : qword = match src {
          XRM_reg(xi) => read_simd(128, xi)[63..0],
          XRM_mem(m) => v(m),
        };
        evex_write_scalar(dst, src1[127..64] @ fp_max(src1[63..0], src2_f64), pfx, 64)
      },
    }
  },

  // 0F 60: VPUNPCKLBW (66, EVEX) [BW]
  // 0F C2: VCMPPS (NP,W0) / VCMPPD (66,W1) / VCMPSS (F3) / VCMPSD (F2) → kmask
  194 => {
    let modrm = fetch(1);
    let dst_k : range(0, 7) = evex_reg_idx(modrm, pfx) % 8;
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { XRM_mem(_) => true, _ => false };
    let src1_idx = pfx.evex_vvvvv;
    match mp {
      // VCMPPS → k
      MP_NONE => {
        let imm = fetch(1);
        let pred : range(0, 31) = unsigned(imm[4..0]);
        let vl = evex_vl(pfx);
        write_kreg(dst_k, avx_vcmpps_kmask(read_simd(vl, src1_idx), evex_bcast_src(modrm, src, pfx, 32), pred))
      },
      // VCMPPD → k
      MP_66 => {
        let imm = fetch(1);
        let pred : range(0, 31) = unsigned(imm[4..0]);
        let vl = evex_vl(pfx);
        write_kreg(dst_k, avx_vcmppd_kmask(read_simd(vl, src1_idx), evex_bcast_src(modrm, src, pfx, 64), pred))
      },
      // VCMPSS → k (scalar, bit 0 only)
      MP_F3 => {
        let rm2 = modrm_xrm_evex(modrm, pfx, 4);
        let imm = fetch(1);
        let pred : range(0, 31) = unsigned(imm[4..0]);
        let src1_f32 = read_simd(128, src1_idx)[31..0];
        let src2_f32 : dword = match rm2 {
          XRM_reg(xi) => read_simd(128, xi)[31..0],
          XRM_mem(m) => v(m),
        };
        write_kreg(dst_k, zero_extend(cmp_pred5_f32(src1_f32, src2_f32, pred)))
      },
      // VCMPSD → k (scalar, bit 0 only)
      MP_F2 => {
        let rm2 = modrm_xrm_evex(modrm, pfx, 8);
        let imm = fetch(1);
        let pred : range(0, 31) = unsigned(imm[4..0]);
        let src1_f64 = read_simd(128, src1_idx)[63..0];
        let src2_f64 : qword = match rm2 {
          XRM_reg(xi) => read_simd(128, xi)[63..0],
          XRM_mem(m) => v(m),
        };
        write_kreg(dst_k, zero_extend(cmp_pred5_f64(src1_f64, src2_f64, pred)))
      },
    }
  },

  // 0F C6: VSHUFPS (NP,W0) / VSHUFPD (66,W1)
  198 => {
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = ll_to_vl(pfx.evex_ll);
    let imm = fetch(1);
    match mp {
      // VSHUFPS xmm1/ymm1/zmm1, xmm2/ymm2/zmm2, xmm3/ymm3/zmm3/m128/m256/m512, imm8
      MP_NONE => {
        let mask = evex_wmask(pfx, vl / 32);
        evex_write(dst, mask, avx_shufps(read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(modrm, src, pfx, 32), imm))
      },
      // VSHUFPD xmm1/ymm1/zmm1, xmm2/ymm2/zmm2, xmm3/ymm3/zmm3/m128/m256/m512, imm8
      MP_66 => {
        let mask = evex_wmask(pfx, vl / 64);
        evex_write(dst, mask, avx_shufpd(read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(modrm, src, pfx, 64), imm))
      },
      _ => raise_UD(),
    }
  },

  // 0F D6: VMOVQ store (66,W1) — store low qword of XMM to XMM/m64
  // 0F E6: VCVTDQ2PD (F3,W0) / VCVTPD2DQ (F2,W1) / VCVTTPD2DQ (66,W1) / VCVTQQ2PD (F3,W1)
  // F3/W1 (VCVTQQ2PD): {er}, F2 (VCVTPD2DQ): {er}, 66 (VCVTTPD2DQ): {sae}
  230 => {
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_xrm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { XRM_mem(_) => true, _ => false };
    let (eff_ll, saved_mxcsr) = evex_begin_rc(pfx, ~(is_mem));
    match mp {
      MP_F3 => {
        match (pfx.rex_w, eff_ll) {
          // VCVTQQ2PD: i64→f64 — supports {er}
          (true, _) => {
            let vl = ll_to_vl(eff_ll);
            let mask = evex_wmask(pfx, vl / 64);
            evex_write(dst, mask, avx_cvtqq2pd(evex_bcast_src(vl, modrm, src, pfx, 64)))
          },
          // VCVTDQ2PD: i32→f64 (widening, exact — no rounding needed)
          (false, 0) => evex_write(dst, evex_wmask(pfx, 2), avx_cvtdq2pd(2, evex_bcast_src(128,modrm, src, pfx, 32)[63..0])),
          (false, 1) => evex_write(dst, evex_wmask(pfx, 4), avx_cvtdq2pd(4, evex_bcast_src(128,modrm, src, pfx, 32))),
          (false, 2) => evex_write(dst, evex_wmask(pfx, 8), avx_cvtdq2pd(8, evex_bcast_src(256,modrm, src, pfx, 32))),
          _ => raise_UD(),
        }
      },
      // VCVTPD2DQ: f64→i32 (round, narrowing) — supports {er}
      MP_F2 => {
        match eff_ll {
          0 => evex_write(dst, evex_wmask(pfx, 4), zero_extend(avx_cvtpd2dq(2, evex_bcast_src(128,modrm, src, pfx, 64))) : xmmword),
          1 => evex_write(dst, evex_wmask(pfx, 4), avx_cvtpd2dq(4, evex_bcast_src(256,modrm, src, pfx, 64))),
          2 => evex_write(dst, evex_wmask(pfx, 8), avx_cvtpd2dq(8, evex_bcast_src(512,modrm, src, pfx, 64))),
          3 => raise_UD(),
        }
      },
      // VCVTTPD2DQ: f64→i32 (truncate, narrowing) — supports {sae}
      MP_66 => {
        match eff_ll {
          0 => evex_write(dst, evex_wmask(pfx, 4), zero_extend(avx_cvttpd2dq(2, evex_bcast_src(128,modrm, src, pfx, 64))) : xmmword),
          1 => evex_write(dst, evex_wmask(pfx, 4), avx_cvttpd2dq(4, evex_bcast_src(256,modrm, src, pfx, 64))),
          2 => evex_write(dst, evex_wmask(pfx, 8), avx_cvttpd2dq(8, evex_bcast_src(512,modrm, src, pfx, 64))),
          3 => raise_UD(),
        }
      },
      _ => raise_UD(),
    };
    evex_end_rc(saved_mxcsr)
  },

  _ => raise_UD(),
  }
}

// x86-64 — SSE Floating-Point Operations
//
// SSE/SSE2/SSE3 data movement, arithmetic, conversion, and comparison.

// Forward declaration (defined in insn_vex_imm.sail)
val extract_word_from_xmm : (xmmword, range(0, 7)) -> word

// =========================================================================
// SSE move helpers
// =========================================================================

val exec_movaps : (simd_idx, xmmword) -> unit
function exec_movaps(dst, src) = {
  write_xmm_legacy(dst, src)
}

val exec_movapd : (simd_idx, xmmword) -> unit
function exec_movapd(dst, src) = {
  write_xmm_legacy(dst, src)
}

val exec_movups : (simd_idx, xmmword) -> unit
function exec_movups(dst, src) = {
  write_xmm_legacy(dst, src)
}

val exec_movupd_load : (simd_idx, xmmword) -> unit
function exec_movupd_load(dst, src) = {
  write_xmm_legacy(dst, src)
}

val exec_movdqa : (simd_idx, xmmword) -> unit
function exec_movdqa(dst, src) = {
  write_xmm_legacy(dst, src)
}

val exec_movdqu : (simd_idx, xmmword) -> unit
function exec_movdqu(dst, src) = {
  write_xmm_legacy(dst, src)
}

val exec_movsd_xmm : (simd_idx, xmmword) -> unit
function exec_movsd_xmm(dst, src) = {
  var xmm : xmmword = read_xmm(dst);
  xmm[63..0] = src[63..0];
  write_xmm_legacy(dst, xmm)
}

val exec_movss_xmm : (simd_idx, xmmword) -> unit
function exec_movss_xmm(dst, src) = {
  var xmm : xmmword = read_xmm(dst);
  xmm[31..0] = src[31..0];
  write_xmm_legacy(dst, xmm)
}

val exec_movshdup : (simd_idx, xmmword) -> unit
function exec_movshdup(dst, src) = {
  write_xmm_legacy(dst, src[127..96] @ src[127..96] @ src[63..32] @ src[63..32])
}

val exec_movsldup : (simd_idx, xmmword) -> unit
function exec_movsldup(dst, src) = {
  write_xmm_legacy(dst, src[95..64] @ src[95..64] @ src[31..0] @ src[31..0])
}

// =========================================================================
// SSE floating-point dispatch
// =========================================================================

// FP comparison predicate helpers (used by CMPPS/CMPPD/CMPSS/CMPSD and
// EVEX VCMPPS/PD/SS/SD). SDM defines 32 predicates (imm8[4:0]).
// Predicates 16-31 repeat 0-15 with signaling/quiet flipped (same results).
//
// eval_fp_predicate: shared predicate logic on a comparison result.
// Returns 1 bit. Used by both SSE (sign-extended to mask) and EVEX (bit to kmask).
val eval_fp_predicate : (FPCompareResult, bits(4)) -> bit
function eval_fp_predicate(r, pred) = {
  let unord : bit = match r { FP_UNORDERED => 0b1, _ => 0b0 };
  let eq : bit = match r { FP_EQ => 0b1, _ => 0b0 };
  let lt : bit = match r { FP_LT => 0b1, _ => 0b0 };
  let gt : bit = match r { FP_GT => 0b1, _ => 0b0 };
  let le : bit = lt | eq;
  match pred {
    0x0 => eq,                      // EQ_OQ
    0x1 => lt,                      // LT_OS
    0x2 => le,                      // LE_OS
    0x3 => unord,                   // UNORD_Q
    0x4 => ~(eq),                   // NEQ_UQ (true for NaN)
    0x5 => ~(lt),                   // NLT_US (true for NaN)
    0x6 => ~(le),                   // NLE_US (true for NaN)
    0x7 => ~(unord),                // ORD_Q
    0x8 => eq | unord,              // EQ_UQ (true for NaN)
    0x9 => lt | unord,              // NGE_US (true for NaN)
    0xA => le | unord,              // NGT_US
    0xB => 0b0,                     // FALSE_OQ
    0xC => ~(eq) & ~(unord),        // NEQ_OQ (false for NaN)
    0xD => ~(lt) & ~(unord),        // GE_OS (false for NaN)
    0xE => gt,                      // GT_OS (false for NaN)
    0xF => 0b1,                     // TRUE_UQ
  }
}

// SSE CMPPS/CMPPD: returns full-width mask (all-ones or all-zeros per element)
val cmp_pred_f32 : (dword, dword, bits(5)) -> dword
function cmp_pred_f32(a, b, pred) = sign_extend(eval_fp_predicate(fp_compare(a, b), pred[3..0]))

val cmp_pred_f64 : (qword, qword, bits(5)) -> qword
function cmp_pred_f64(a, b, pred) = sign_extend(eval_fp_predicate(fp_compare(a, b), pred[3..0]))

// EVEX VCMPPS/VCMPPD: returns 1 bit per element (for kmask)
// pred[3:0] selects comparison; pred[4] only affects signaling (not modeled).
val cmp_pred5_f32 : (dword, dword, range(0, 31)) -> bit
function cmp_pred5_f32(a, b, pred) = eval_fp_predicate(fp_compare(a, b), to_bits(4, pred % 16))

val cmp_pred5_f64 : (qword, qword, range(0, 31)) -> bit
function cmp_pred5_f64(a, b, pred) = eval_fp_predicate(fp_compare(a, b), to_bits(4, pred % 16))

// SHUFPS helper: select one of four dwords by 2-bit index
val select_dword : (xmmword, bits(2)) -> dword
function select_dword(v, sel) = {
  let idx : range(0, 3) = unsigned(sel);
  v[(idx * 32 + 31) .. (idx * 32)]
}

val dispatch_2byte_sse_fp : (range(0, 255), Prefixes) -> unit
function dispatch_2byte_sse_fp(op, pfx) = {
  match op {
    // 0F 10: MOVUPS/MOVUPD/MOVSD/MOVSS xmm, xmm/m
    16 => {
      let mp = get_mandatory_prefix(pfx);
      let modrm = fetch(1);
      let xreg = modrm_xmm_reg(modrm, pfx);
      let src = modrm_rm(modrm, pfx);
      match mp {
        MP_NONE => {
          // MOVUPS xmm1, xmm2/m128
          match src {
            RM_reg(_) => exec_movups(xreg, read_xmm(modrm_xmm_rm(modrm, pfx))),
            RM_mem(m) => write_xmm_legacy(xreg, read_mem(m)),
          }
        },
        MP_66 => {
          // MOVUPD xmm1, xmm2/m128
          match src {
            RM_reg(_) => exec_movupd_load(xreg, read_xmm(modrm_xmm_rm(modrm, pfx))),
            RM_mem(m) => write_xmm_legacy(xreg, read_mem(m)),
          }
        },
        MP_F3 => {
          // MOVSS xmm1, xmm2/m32
          match src {
            RM_reg(_) => exec_movss_xmm(xreg, read_xmm(modrm_xmm_rm(modrm, pfx))),
            RM_mem(m) => {
              let x : xmmword = zero_extend(v(32, m));
              write_xmm_legacy(xreg, x)
            },
          }
        },
        MP_F2 => {
          // MOVSD xmm1, xmm2/m64
          match src {
            RM_reg(_) => exec_movsd_xmm(xreg, read_xmm(modrm_xmm_rm(modrm, pfx))),
            RM_mem(m) => {
              let x : xmmword = zero_extend(v(64, m));
              write_xmm_legacy(xreg, x)
            },
          }
        },
      }
    },
    // 0F 11: MOVUPS/MOVUPD/MOVSD/MOVSS xmm/m, xmm
    17 => {
      let mp = get_mandatory_prefix(pfx);
      let modrm = fetch(1);
      let xreg = modrm_xmm_reg(modrm, pfx);
      let dest = modrm_rm(modrm, pfx);
      match mp {
        MP_NONE => {
          // MOVUPS xmm2/m128, xmm1
          match dest {
            RM_reg(_) => exec_movups(modrm_xmm_rm(modrm, pfx), read_xmm(xreg)),
            RM_mem(m) => {
              write_mem(m,read_xmm(xreg))
            },
          }
        },
        MP_66 => {
          // MOVUPD xmm2/m128, xmm1
          match dest {
            RM_reg(_) => exec_movupd_load(modrm_xmm_rm(modrm, pfx), read_xmm(xreg)),
            RM_mem(m) => {
              write_mem(m,read_xmm(xreg))
            },
          }
        },
        MP_F3 => {
          // MOVSS m32, xmm1
          match dest {
            RM_reg(_) => exec_movss_xmm(modrm_xmm_rm(modrm, pfx), read_xmm(xreg)),
            RM_mem(m) => {
              let data = read_xmm(xreg);
              v(m) = data[31..0]
            },
          }
        },
        MP_F2 => {
          // MOVSD m64, xmm1
          match dest {
            RM_reg(_) => exec_movsd_xmm(modrm_xmm_rm(modrm, pfx), read_xmm(xreg)),
            RM_mem(m) => {
              let data = read_xmm(xreg);
              v(m) = data[63..0]
            },
          }
        },
      }
    },
    // 0F 12: MOVLPS/MOVLPD/MOVSLDUP/MOVDDUP
    18 => {
      let mp = get_mandatory_prefix(pfx);
      let modrm = fetch(1);
      let xreg = modrm_xmm_reg(modrm, pfx);
      let src = modrm_rm(modrm, pfx);
      match mp {
        MP_NONE => {
          // MOVLPS xmm, m64 or MOVHLPS xmm, xmm
          match src {
            RM_reg(_) => {
              let src = read_xmm(modrm_xmm_rm(modrm, pfx));
              write_xmm_legacy(xreg, read_xmm(xreg)[127..64] @ src[127..64])
            },
            RM_mem(m) => {
              var xmm : xmmword = read_xmm(xreg);
              xmm[63..0] = v(m);
              write_xmm_legacy(xreg, xmm)
            },
          }
        },
        MP_66 => {
          // MOVLPD xmm, m64
          var xmm : xmmword = read_xmm(xreg);
          xmm[63..0] = rm_mem(src);
          write_xmm_legacy(xreg, xmm)
        },
        MP_F3 => {
          // MOVSLDUP xmm1, xmm2/m128 (SSE3)
          if ~(has_sse3) then raise_UD();
          match src {
            RM_reg(_) => exec_movsldup(xreg, read_xmm(modrm_xmm_rm(modrm, pfx))),
            RM_mem(m) => exec_movsldup(xreg, read_mem(m)),
          }
        },
        MP_F2 => {
          // MOVDDUP xmm1, xmm2/m64 (SSE3)
          if ~(has_sse3) then raise_UD();
          match src {
            RM_reg(_) => {
              let s = read_xmm(modrm_xmm_rm(modrm, pfx));
              write_xmm_legacy(xreg, s[63..0] @ s[63..0])
            },
            RM_mem(m) => {
              let lo = v(64, m);
              write_xmm_legacy(xreg, lo @ lo)
            },
          }
        },
      }
    },
    // 0F 13: MOVLPS/MOVLPD m64, xmm
    19 => {
      let mp = get_mandatory_prefix(pfx);
      let modrm = fetch(1);
      let xreg = modrm_xmm_reg(modrm, pfx);
      let dest = modrm_rm(modrm, pfx);
      rm_mem(64, dest) = read_xmm(xreg)[63..0]
    },
    // 0F 14: UNPCKLPS/UNPCKLPD
    20 => {
      let mp = get_mandatory_prefix(pfx);
      let modrm = fetch(1);
      let xreg = modrm_xmm_reg(modrm, pfx);
      let src = modrm_rm(modrm, pfx);
      let src : xmmword = match src {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
        RM_mem(m) => read_mem(m),
      };
      match mp {
        MP_NONE => {
          let d : xmmword = read_xmm(xreg);
          let s : xmmword = src;
          write_xmm_legacy(xreg, s[63..32] @ d[63..32] @ s[31..0] @ d[31..0])
        },
        MP_66 => {
          let d : xmmword = read_xmm(xreg);
          let s : xmmword = src;
          write_xmm_legacy(xreg, s[63..0] @ d[63..0])
        },
        _       => raise_UD(),
      }
    },
    // 0F 15: UNPCKHPS/UNPCKHPD
    21 => {
      let mp = get_mandatory_prefix(pfx);
      let modrm = fetch(1);
      let xreg = modrm_xmm_reg(modrm, pfx);
      let src = modrm_rm(modrm, pfx);
      let src : xmmword = match src {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
        RM_mem(m) => read_mem(m),
      };
      match mp {
        MP_NONE => {
          let d : xmmword = read_xmm(xreg);
          let s : xmmword = src;
          write_xmm_legacy(xreg, s[127..96] @ d[127..96] @ s[95..64] @ d[95..64])
        },
        MP_66 => {
          let d : xmmword = read_xmm(xreg);
          let s : xmmword = src;
          write_xmm_legacy(xreg, s[127..64] @ d[127..64])
        },
        _       => raise_UD(),
      }
    },
    // 0F 16: MOVHPS/MOVHPD/MOVSHDUP
    22 => {
      let mp = get_mandatory_prefix(pfx);
      let modrm = fetch(1);
      let xreg = modrm_xmm_reg(modrm, pfx);
      let src = modrm_rm(modrm, pfx);
      match mp {
        MP_NONE => {
          match src {
            RM_reg(_) => {
              let src = read_xmm(modrm_xmm_rm(modrm, pfx));
              write_xmm_legacy(xreg, src[63..0] @ read_xmm(xreg)[63..0])
            },
            RM_mem(m) => {
              var xmm : xmmword = read_xmm(xreg);
              xmm[127..64] = v(m);
              write_xmm_legacy(xreg, xmm)
            },
          }
        },
        MP_66 => {
          var xmm : xmmword = read_xmm(xreg);
          xmm[127..64] = rm_mem(src);
          write_xmm_legacy(xreg, xmm)
        },
        MP_F3 => {
          // MOVSHDUP xmm1, xmm2/m128 (SSE3)
          if ~(has_sse3) then raise_UD();
          match src {
            RM_reg(_) => exec_movshdup(xreg, read_xmm(modrm_xmm_rm(modrm, pfx))),
            RM_mem(m) => exec_movshdup(xreg, read_mem(m)),
          }
        },
        _ => raise_UD(),
      }
    },
    // 0F 17: MOVHPS/MOVHPD m64, xmm
    23 => {
      let modrm = fetch(1);
      let xreg = modrm_xmm_reg(modrm, pfx);
      let dest = modrm_rm(modrm, pfx);
      rm_mem(64, dest) = read_xmm(xreg)[127..64]
    },
    // 0F 28: MOVAPS/MOVAPD xmm, xmm/m128
    40 => {
      let mp = get_mandatory_prefix(pfx);
      let modrm = fetch(1);
      let xreg = modrm_xmm_reg(modrm, pfx);
      let src = modrm_rm(modrm, pfx);
      match src {
        RM_reg(_) => {
          match mp {
            MP_NONE => exec_movaps(xreg, read_xmm(modrm_xmm_rm(modrm, pfx))),
            MP_66   => exec_movapd(xreg, read_xmm(modrm_xmm_rm(modrm, pfx))),
            _       => raise_UD(),
          }
        },
        RM_mem(m) => {
          // MOVAPS/MOVAPD require 16-byte alignment; #GP(0) if unaligned
          if unsigned(m.addr) % 16 != 0 then raise_GP0();
          write_xmm_legacy(xreg, read_mem(m))
        },
      }
    },
    // 0F 29: MOVAPS/MOVAPD xmm/m128, xmm
    41 => {
      let mp = get_mandatory_prefix(pfx);
      let modrm = fetch(1);
      let xreg = modrm_xmm_reg(modrm, pfx);
      let dest = modrm_rm(modrm, pfx);
      match dest {
        RM_reg(_) => {
          match mp {
            MP_NONE => exec_movaps(modrm_xmm_rm(modrm, pfx), read_xmm(xreg)),
            MP_66   => exec_movapd(modrm_xmm_rm(modrm, pfx), read_xmm(xreg)),
            _       => raise_UD(),
          }
        },
        RM_mem(m) => {
          // MOVAPS/MOVAPD require 16-byte alignment; #GP(0) if unaligned
          if unsigned(m.addr) % 16 != 0 then raise_GP0();
          write_mem(m,read_xmm(xreg))
        },
      }
    },
    // 0F 2A: CVTSI2SS/CVTSI2SD
    42 => {
      let mp = get_mandatory_prefix(pfx);
      let modrm = fetch(1);
      let xreg = modrm_xmm_reg(modrm, pfx);
      let src = modrm_rm(modrm, pfx);
      let os = opsize(pfx);
      let src_val : qword = match src {
        RM_reg(_) => zero_extend(v(os, modrm_rm_reg(modrm, pfx))),
        RM_mem(m) => match os {
          64 => v(m),
          _  => zero_extend(v(32, m)),
        },
      };
      match mp {
        // CVTSI2SS xmm, r/m32/64 (F3 prefix)
        MP_F3 => {
          let result : dword = match os {
            64 => __int64_to_f32(src_val),
            _  => __int32_to_f32(src_val[31..0]),
          };
          var xmm : xmmword = read_xmm(xreg);
          xmm[31..0] = result;
          write_xmm_legacy(xreg, xmm)
        },
        // CVTSI2SD xmm, r/m32/64 (F2 prefix)
        MP_F2 => {
          let result : qword = match os {
            64 => __int64_to_f64(src_val),
            _  => __int32_to_f64(src_val[31..0]),
          };
          var xmm : xmmword = read_xmm(xreg);
          xmm[63..0] = result;
          write_xmm_legacy(xreg, xmm)
        },
        // CVTPI2PS xmm, mm/m64 (NP) — SDM: DEST[31:0] := cvt(SRC[31:0]); DEST[63:32] := cvt(SRC[63:32])
        // High quadword unchanged.
        MP_NONE => {
          let mm_src : qword = match src {
            RM_reg(_) => { mmx_touch(); read_mm(unsigned(modrm[2..0])) },
            RM_mem(m) => v(m),
          };
          var xmm : xmmword = read_xmm(xreg);
          xmm[31..0] = __int32_to_f32(mm_src[31..0]);
          xmm[63..32] = __int32_to_f32(mm_src[63..32]);
          write_xmm_legacy(xreg, xmm)
        },
        // CVTPI2PD xmm, mm/m64 (66 prefix) — SDM: full XMM write
        MP_66 => {
          let mm_src : qword = match src {
            RM_reg(_) => { mmx_touch(); read_mm(unsigned(modrm[2..0])) },
            RM_mem(m) => v(m),
          };
          let lo : qword = __int32_to_f64(mm_src[31..0]);
          let hi : qword = __int32_to_f64(mm_src[63..32]);
          write_xmm_legacy(xreg, hi @ lo)
        },
      }
    },
    // 0F 2C: CVTTSS2SI/CVTTSD2SI
    44 => {
      let mp = get_mandatory_prefix(pfx);
      let modrm = fetch(1);
      let reg = modrm_reg(modrm, pfx);
      let src = modrm_rm(modrm, pfx);
      let os = opsize(pfx);
      let src_xmm : xmmword = match src {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
        RM_mem(m) => match mp {
          MP_F3 => zero_extend(v(32, m)),
          MP_F2 => zero_extend(v(64, m)),
          _     => zeros(),
        },
      };
      match mp {
        MP_F3 => {
          match os {
            64 => v(reg) = __f32_to_int64_trunc(src_xmm[31..0]),
            _  => v(reg) = __f32_to_int32_trunc(src_xmm[31..0]),
          }
        },
        MP_F2 => {
          match os {
            64 => v(reg) = __f64_to_int64_trunc(src_xmm[63..0]),
            _  => v(reg) = __f64_to_int32_trunc(src_xmm[63..0]),
          }
        },
        // CVTTPS2PI mm, xmm/m64 (NP) — SDM: truncate 2 floats to 2 dwords in MM
        MP_NONE => {
          let src : qword = match src {
            RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[63..0],
            RM_mem(m) => v(m),
          };
          mmx_touch();
          let mm_dst : range(0, 7) = unsigned(modrm[5..3]);
          write_mm(mm_dst, __f32_to_int32_trunc(src[63..32]) @ __f32_to_int32_trunc(src[31..0]))
        },
        // CVTTPD2PI mm, xmm/m128 (66) — SDM: truncate 2 doubles to 2 dwords in MM
        MP_66 => {
          let src : xmmword = match src {
            RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
            RM_mem(m) => read_mem(m),
          };
          mmx_touch();
          let mm_dst : range(0, 7) = unsigned(modrm[5..3]);
          write_mm(mm_dst, __f64_to_int32_trunc(src[127..64]) @ __f64_to_int32_trunc(src[63..0]))
        },
      }
    },
    // 0F 2D: CVTSS2SI/CVTSD2SI
    45 => {
      let mp = get_mandatory_prefix(pfx);
      let modrm = fetch(1);
      let reg = modrm_reg(modrm, pfx);
      let src = modrm_rm(modrm, pfx);
      let os = opsize(pfx);
      let src_xmm : xmmword = match src {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
        RM_mem(m) => match mp {
          MP_F3 => zero_extend(v(32, m)),
          MP_F2 => zero_extend(v(64, m)),
          _     => zeros(),
        },
      };
      match mp {
        MP_F3 => {
          match os {
            64 => v(reg) = __f32_to_int64(src_xmm[31..0]),
            _    => v(reg) = __f32_to_int32(src_xmm[31..0]),
          }
        },
        MP_F2 => {
          match os {
            64 => v(reg) = __f64_to_int64(src_xmm[63..0]),
            _    => v(reg) = __f64_to_int32(src_xmm[63..0]),
          }
        },
        // CVTPS2PI mm, xmm/m64 (NP) — SDM: round 2 floats to 2 dwords in MM
        MP_NONE => {
          let src : qword = match src {
            RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[63..0],
            RM_mem(m) => v(m),
          };
          mmx_touch();
          let mm_dst : range(0, 7) = unsigned(modrm[5..3]);
          write_mm(mm_dst, __f32_to_int32(src[63..32]) @ __f32_to_int32(src[31..0]))
        },
        // CVTPD2PI mm, xmm/m128 (66) — SDM: round 2 doubles to 2 dwords in MM
        MP_66 => {
          let src : xmmword = match src {
            RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
            RM_mem(m) => read_mem(m),
          };
          mmx_touch();
          let mm_dst : range(0, 7) = unsigned(modrm[5..3]);
          write_mm(mm_dst, __f64_to_int32(src[127..64]) @ __f64_to_int32(src[63..0]))
        },
      }
    },
    // 0F 2E: UCOMISS/UCOMISD
    46 => {
      let mp = get_mandatory_prefix(pfx);
      let modrm = fetch(1);
      let xreg = modrm_xmm_reg(modrm, pfx);
      let src = modrm_rm(modrm, pfx);
      let src_xmm : xmmword = match src {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
        RM_mem(m) => match mp {
          MP_NONE => zero_extend(v(32, m)),
          MP_66   => zero_extend(v(64, m)),
          _       => zeros(),
        },
      };
      match mp {
        MP_NONE => {
          let a : dword = read_xmm(xreg)[31..0];
          let b : dword = src_xmm[31..0];
          match fp_compare(a, b) {
            FP_UNORDERED => { ZF = 0b1; PF = 0b1; CF = 0b1;  },
            FP_GT        => { ZF = 0b0; PF = 0b0; CF = 0b0; },
            FP_LT        => { ZF = 0b0; PF = 0b0; CF = 0b1;  },
            FP_EQ        => { ZF = 0b1; PF = 0b0; CF = 0b0; },
          };
          OF = 0b0;
          AF = 0b0;
          SF = 0b0
        },
        MP_66 => {
          let a : qword = read_xmm(xreg)[63..0];
          let b : qword = src_xmm[63..0];
          match fp_compare(a, b) {
            FP_UNORDERED => { ZF = 0b1; PF = 0b1; CF = 0b1;  },
            FP_GT        => { ZF = 0b0; PF = 0b0; CF = 0b0; },
            FP_LT        => { ZF = 0b0; PF = 0b0; CF = 0b1;  },
            FP_EQ        => { ZF = 0b1; PF = 0b0; CF = 0b0; },
          };
          OF = 0b0;
          AF = 0b0;
          SF = 0b0
        },
        _       => raise_UD(),
      }
    },
    // 0F 2F: COMISS/COMISD
    47 => {
      let mp = get_mandatory_prefix(pfx);
      let modrm = fetch(1);
      let xreg = modrm_xmm_reg(modrm, pfx);
      let src = modrm_rm(modrm, pfx);
      let src_xmm : xmmword = match src {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
        RM_mem(m) => match mp {
          MP_NONE => zero_extend(v(32, m)),
          MP_66   => zero_extend(v(64, m)),
          _       => zeros(),
        },
      };
      match mp {
        MP_NONE => {
          let a : dword = read_xmm(xreg)[31..0];
          let b : dword = src_xmm[31..0];
          match fp_compare(a, b) {
            FP_UNORDERED => { ZF = 0b1; PF = 0b1; CF = 0b1;  },
            FP_GT        => { ZF = 0b0; PF = 0b0; CF = 0b0; },
            FP_LT        => { ZF = 0b0; PF = 0b0; CF = 0b1;  },
            FP_EQ        => { ZF = 0b1; PF = 0b0; CF = 0b0; },
          };
          OF = 0b0;
          AF = 0b0;
          SF = 0b0
        },
        MP_66 => {
          let a : qword = read_xmm(xreg)[63..0];
          let b : qword = src_xmm[63..0];
          match fp_compare(a, b) {
            FP_UNORDERED => { ZF = 0b1; PF = 0b1; CF = 0b1;  },
            FP_GT        => { ZF = 0b0; PF = 0b0; CF = 0b0; },
            FP_LT        => { ZF = 0b0; PF = 0b0; CF = 0b1;  },
            FP_EQ        => { ZF = 0b1; PF = 0b0; CF = 0b0; },
          };
          OF = 0b0;
          AF = 0b0;
          SF = 0b0
        },
        _       => raise_UD(),
      }
    },
    // 0F 50: MOVMSKPS/MOVMSKPD
    80 => {
      let mp = get_mandatory_prefix(pfx);
      let modrm = fetch(1);
      let reg = modrm_reg(modrm, pfx);
      let _ = modrm_rm(modrm, pfx);
      let src_xmm : xmmword = read_xmm(modrm_xmm_rm(modrm, pfx));
      match mp {
        MP_NONE => {
          let mask : bits(4) = src_xmm[127] @ src_xmm[95] @ src_xmm[63] @ src_xmm[31];
          v(reg) = zero_extend(32, mask)
        },
        MP_66 => {
          let mask : bits(2) = src_xmm[127] @ src_xmm[63];
          v(reg) = zero_extend(32, mask)
        },
        _       => raise_UD(),
      }
    },
    // 0F 51-5F: SSE/SSE2 scalar/packed arithmetic
    // These follow a pattern based on mandatory prefix:
    //   NONE=PS, 66=PD, F3=SS, F2=SD
    op if 81 <= op & op <= 95 => {
      let mp = get_mandatory_prefix(pfx);
      let modrm = fetch(1);
      let xreg = modrm_xmm_reg(modrm, pfx);
      let src = modrm_rm(modrm, pfx);
      let src_xmm : xmmword = match src {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
        RM_mem(m) => match mp {
          MP_F3 => zero_extend(v(32, m)),
          MP_F2 => zero_extend(v(64, m)),
          _     => read_mem(m),
        },
      };
      let arith_op : range(0, 15) = op - 80;
      match arith_op {
        // 0F 51: SQRT
        1 => {
          match mp {
            MP_NONE => {
              let r : xmmword = fp_sqrt(src_xmm[127..96]) @
              fp_sqrt(src_xmm[95..64]) @
              fp_sqrt(src_xmm[63..32]) @
              fp_sqrt(src_xmm[31..0]);
              write_xmm_legacy(xreg, r)
            },
            MP_66 => {
              write_xmm_legacy(xreg, fp_sqrt(src_xmm[127..64]) @ fp_sqrt(src_xmm[63..0]))
            },
            MP_F3 => {
              var xmm : xmmword = read_xmm(xreg);
              xmm[31..0] = fp_sqrt(src_xmm[31..0]);
              write_xmm_legacy(xreg, xmm)
            },
            MP_F2 => {
              var xmm : xmmword = read_xmm(xreg);
              xmm[63..0] = fp_sqrt(src_xmm[63..0]);
              write_xmm_legacy(xreg, xmm)
            },
          }
        },
        // 0F 54: ANDPS/ANDPD
        4 => {
          match mp {
            MP_NONE => write_xmm_legacy(xreg, read_xmm(xreg) & src_xmm),
            MP_66 => write_xmm_legacy(xreg, read_xmm(xreg) & src_xmm),
            _       => raise_UD(),
          }
        },
        // 0F 55: ANDNPS/ANDNPD
        5 => {
          match mp {
            MP_NONE => write_xmm_legacy(xreg, ~(read_xmm(xreg)) & src_xmm),
            MP_66 => write_xmm_legacy(xreg, ~(read_xmm(xreg)) & src_xmm),
            _       => raise_UD(),
          }
        },
        // 0F 56: ORPS/ORPD
        6 => {
          match mp {
            MP_NONE => write_xmm_legacy(xreg, read_xmm(xreg) | src_xmm),
            MP_66 => write_xmm_legacy(xreg, read_xmm(xreg) | src_xmm),
            _       => raise_UD(),
          }
        },
        // 0F 57: XORPS/XORPD
        7 => {
          match mp {
            MP_NONE => write_xmm_legacy(xreg, (read_xmm(xreg) ^ src_xmm)),
            MP_66 => write_xmm_legacy(xreg, (read_xmm(xreg) ^ src_xmm)),
            _       => raise_UD(),
          }
        },
        // 0F 58: ADD
        8 => {
          match mp {
            MP_NONE => {
              let a : xmmword = read_xmm(xreg);
              let r : xmmword = fp_add(a[127..96], src_xmm[127..96]) @
              fp_add(a[95..64], src_xmm[95..64]) @
              fp_add(a[63..32], src_xmm[63..32]) @
              fp_add(a[31..0], src_xmm[31..0]);
              write_xmm_legacy(xreg, r)
            },
            MP_66 => {
              let a : xmmword = read_xmm(xreg);
              let lo : qword = fp_add(a[63..0], src_xmm[63..0]);
              let hi : qword = fp_add(a[127..64], src_xmm[127..64]);
              write_xmm_legacy(xreg, hi @ lo)
            },
            MP_F3 => {
              var xmm : xmmword = read_xmm(xreg);
              xmm[31..0] = fp_add(xmm[31..0], src_xmm[31..0]);
              write_xmm_legacy(xreg, xmm)
            },
            MP_F2 => {
              var xmm : xmmword = read_xmm(xreg);
              xmm[63..0] = fp_add(xmm[63..0], src_xmm[63..0]);
              write_xmm_legacy(xreg, xmm)
            },
          }
        },
        // 0F 59: MUL
        9 => {
          match mp {
            MP_NONE => {
              let a : xmmword = read_xmm(xreg);
              let r : xmmword = fp_mul(a[127..96], src_xmm[127..96]) @
              fp_mul(a[95..64], src_xmm[95..64]) @
              fp_mul(a[63..32], src_xmm[63..32]) @
              fp_mul(a[31..0], src_xmm[31..0]);
              write_xmm_legacy(xreg, r)
            },
            MP_66 => {
              let a : xmmword = read_xmm(xreg);
              write_xmm_legacy(xreg, fp_mul(a[127..64], src_xmm[127..64]) @ fp_mul(a[63..0], src_xmm[63..0]))
            },
            MP_F3 => {
              var xmm : xmmword = read_xmm(xreg);
              xmm[31..0] = fp_mul(xmm[31..0], src_xmm[31..0]);
              write_xmm_legacy(xreg, xmm)
            },
            MP_F2 => {
              var xmm : xmmword = read_xmm(xreg);
              xmm[63..0] = fp_mul(xmm[63..0], src_xmm[63..0]);
              write_xmm_legacy(xreg, xmm)
            },
          }
        },
        // 0F 5A: CVTPS2PD/CVTPD2PS/CVTSS2SD/CVTSD2SS
        10 => {
          match mp {
            MP_NONE => {
              let r : xmmword = __f32_to_f64(src_xmm[63..32]) @ __f32_to_f64(src_xmm[31..0]);
              write_xmm_legacy(xreg, r)
            },
            MP_66 => {
              let r : xmmword = zeros(64) @ __f64_to_f32(src_xmm[127..64]) @ __f64_to_f32(src_xmm[63..0]);
              write_xmm_legacy(xreg, r)
            },
            MP_F3 => {
              let result : qword = __f32_to_f64(src_xmm[31..0]);
              var xmm : xmmword = read_xmm(xreg);
              xmm[63..0] = result;
              write_xmm_legacy(xreg, xmm)
            },
            MP_F2 => {
              let result : dword = __f64_to_f32(src_xmm[63..0]);
              var xmm : xmmword = read_xmm(xreg);
              xmm[31..0] = result;
              write_xmm_legacy(xreg, xmm)
            },
          }
        },
        // 0F 5B: CVTDQ2PS/CVTPS2DQ/CVTTPS2DQ
        11 => {
          match mp {
            MP_NONE => {
              let r : xmmword = __int32_to_f32(src_xmm[127..96]) @ __int32_to_f32(src_xmm[95..64]) @
                __int32_to_f32(src_xmm[63..32]) @ __int32_to_f32(src_xmm[31..0]);
              write_xmm_legacy(xreg, r)
            },
            MP_66 => {
              let r : xmmword = __f32_to_int32(src_xmm[127..96]) @ __f32_to_int32(src_xmm[95..64]) @
                __f32_to_int32(src_xmm[63..32]) @ __f32_to_int32(src_xmm[31..0]);
              write_xmm_legacy(xreg, r)
            },
            MP_F3 => {
              let r : xmmword = __f32_to_int32_trunc(src_xmm[127..96]) @ __f32_to_int32_trunc(src_xmm[95..64]) @
                __f32_to_int32_trunc(src_xmm[63..32]) @ __f32_to_int32_trunc(src_xmm[31..0]);
              write_xmm_legacy(xreg, r)
            },
            _       => raise_UD(),
          }
        },
        // 0F 5C: SUB
        12 => {
          match mp {
            MP_NONE => {
              let a : xmmword = read_xmm(xreg);
              let r : xmmword = fp_sub(a[127..96], src_xmm[127..96]) @
              fp_sub(a[95..64], src_xmm[95..64]) @
              fp_sub(a[63..32], src_xmm[63..32]) @
              fp_sub(a[31..0], src_xmm[31..0]);
              write_xmm_legacy(xreg, r)
            },
            MP_66 => {
              let a : xmmword = read_xmm(xreg);
              write_xmm_legacy(xreg, fp_sub(a[127..64], src_xmm[127..64]) @ fp_sub(a[63..0], src_xmm[63..0]))
            },
            MP_F3 => {
              var xmm : xmmword = read_xmm(xreg);
              xmm[31..0] = fp_sub(xmm[31..0], src_xmm[31..0]);
              write_xmm_legacy(xreg, xmm)
            },
            MP_F2 => {
              var xmm : xmmword = read_xmm(xreg);
              xmm[63..0] = fp_sub(xmm[63..0], src_xmm[63..0]);
              write_xmm_legacy(xreg, xmm)
            },
          }
        },
        // 0F 5D: MIN
        13 => {
          match mp {
            MP_NONE => {
              let a : xmmword = read_xmm(xreg);
              let r : xmmword = fp_min(a[127..96], src_xmm[127..96]) @
              fp_min(a[95..64], src_xmm[95..64]) @
              fp_min(a[63..32], src_xmm[63..32]) @
              fp_min(a[31..0], src_xmm[31..0]);
              write_xmm_legacy(xreg, r)
            },
            MP_66 => {
              let a : xmmword = read_xmm(xreg);
              write_xmm_legacy(xreg, fp_min(a[127..64], src_xmm[127..64]) @ fp_min(a[63..0], src_xmm[63..0]))
            },
            MP_F3 => {
              var xmm : xmmword = read_xmm(xreg);
              xmm[31..0] = fp_min(xmm[31..0], src_xmm[31..0]);
              write_xmm_legacy(xreg, xmm)
            },
            MP_F2 => {
              var xmm : xmmword = read_xmm(xreg);
              xmm[63..0] = fp_min(xmm[63..0], src_xmm[63..0]);
              write_xmm_legacy(xreg, xmm)
            },
          }
        },
        // 0F 5E: DIV
        14 => {
          match mp {
            MP_NONE => {
              let a : xmmword = read_xmm(xreg);
              let r : xmmword = fp_div(a[127..96], src_xmm[127..96]) @
              fp_div(a[95..64], src_xmm[95..64]) @
              fp_div(a[63..32], src_xmm[63..32]) @
              fp_div(a[31..0], src_xmm[31..0]);
              write_xmm_legacy(xreg, r)
            },
            MP_66 => {
              let a : xmmword = read_xmm(xreg);
              write_xmm_legacy(xreg, fp_div(a[127..64], src_xmm[127..64]) @ fp_div(a[63..0], src_xmm[63..0]))
            },
            MP_F3 => {
              var xmm : xmmword = read_xmm(xreg);
              xmm[31..0] = fp_div(xmm[31..0], src_xmm[31..0]);
              write_xmm_legacy(xreg, xmm)
            },
            MP_F2 => {
              var xmm : xmmword = read_xmm(xreg);
              xmm[63..0] = fp_div(xmm[63..0], src_xmm[63..0]);
              write_xmm_legacy(xreg, xmm)
            },
          }
        },
        // 0F 5F: MAX
        15 => {
          match mp {
            MP_NONE => {
              let a : xmmword = read_xmm(xreg);
              let r : xmmword = fp_max(a[127..96], src_xmm[127..96]) @
              fp_max(a[95..64], src_xmm[95..64]) @
              fp_max(a[63..32], src_xmm[63..32]) @
              fp_max(a[31..0], src_xmm[31..0]);
              write_xmm_legacy(xreg, r)
            },
            MP_66 => {
              let a : xmmword = read_xmm(xreg);
              write_xmm_legacy(xreg, fp_max(a[127..64], src_xmm[127..64]) @ fp_max(a[63..0], src_xmm[63..0]))
            },
            MP_F3 => {
              var xmm : xmmword = read_xmm(xreg);
              xmm[31..0] = fp_max(xmm[31..0], src_xmm[31..0]);
              write_xmm_legacy(xreg, xmm)
            },
            MP_F2 => {
              var xmm : xmmword = read_xmm(xreg);
              xmm[63..0] = fp_max(xmm[63..0], src_xmm[63..0]);
              write_xmm_legacy(xreg, xmm)
            },
          }
        },
        // 0F 52: RSQRTPS/RSQRTSS
        2 => {
          match mp {
            MP_NONE => {
              var xmm : xmmword = zeros();
              xmm[31..0]   = fp_rsqrt(src_xmm[31..0]);
              xmm[63..32]  = fp_rsqrt(src_xmm[63..32]);
              xmm[95..64]  = fp_rsqrt(src_xmm[95..64]);
              xmm[127..96] = fp_rsqrt(src_xmm[127..96]);
              write_xmm_legacy(xreg, xmm)
            },
            MP_F3 => {
              var xmm : xmmword = read_xmm(xreg);
              xmm[31..0] = fp_rsqrt(src_xmm[31..0]);
              write_xmm_legacy(xreg, xmm)
            },
            _       => raise_UD(),
          }
        },
        // 0F 53: RCPPS/RCPSS
        3 => {
          match mp {
            MP_NONE => {
              var xmm : xmmword = zeros();
              xmm[31..0]   = fp_rcp(src_xmm[31..0]);
              xmm[63..32]  = fp_rcp(src_xmm[63..32]);
              xmm[95..64]  = fp_rcp(src_xmm[95..64]);
              xmm[127..96] = fp_rcp(src_xmm[127..96]);
              write_xmm_legacy(xreg, xmm)
            },
            MP_F3 => {
              var xmm : xmmword = read_xmm(xreg);
              xmm[31..0] = fp_rcp(src_xmm[31..0]);
              write_xmm_legacy(xreg, xmm)
            },
            _       => raise_UD(),
          }
        },
        _ => raise_UD(),
      }
    },
    // 0F C6: SHUFPS/SHUFPD xmm, xmm/m128, imm8
    198 => {
      let mp = get_mandatory_prefix(pfx);
      let modrm = fetch(1);
      let xreg = modrm_xmm_reg(modrm, pfx);
      let src = modrm_rm(modrm, pfx);
      let src_xmm : xmmword = match src {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
        RM_mem(m) => read_mem(m),
      };
      let imm = fetch(1);
      match mp {
        MP_NONE => {
          let d : xmmword = read_xmm(xreg);
          let d0 : dword = select_dword(d, imm[1..0]);
          let d1 : dword = select_dword(d, imm[3..2]);
          let d2 : dword = select_dword(src_xmm, imm[5..4]);
          let d3 : dword = select_dword(src_xmm, imm[7..6]);
          write_xmm_legacy(xreg, d3 @ d2 @ d1 @ d0)
        },
        MP_66 => {
          let d : xmmword = read_xmm(xreg);
          let low : qword = blend(d[63..0], d[127..64], imm[0]);
          let high : qword = blend(src_xmm[63..0], src_xmm[127..64], imm[1]);
          write_xmm_legacy(xreg, high @ low)
        },
        _       => raise_UD(),
      }
    },
    // 0F D6: MOVQ xmm/m64, xmm (66 prefix)
    214 => {
      let mp = get_mandatory_prefix(pfx);
      match mp {
        // 66 0F D6: MOVQ xmm1/m64, xmm2 — store low 64 bits
        MP_66 => {
          let modrm = fetch(1);
          let xreg = modrm_xmm_reg(modrm, pfx);
          let dest = modrm_rm(modrm, pfx);
          let data = read_xmm(xreg);
          match dest {
            RM_reg(_) => {
              let dst_xmm = modrm_xmm_rm(modrm, pfx);
              write_xmm(dst_xmm, zero_extend(data[63..0]))
            },
            RM_mem(m) => v(m) = data[63..0],
          }
        },
        // F2 0F D6: MOVDQ2Q mm, xmm — SDM: DEST := SRC[63:0]
        MP_F2 => {
          let modrm = fetch(1);
          let _ = modrm_rm(modrm, pfx);
          let src_xmm = modrm_xmm_rm(modrm, pfx);
          let mm_dst : range(0, 7) = unsigned(modrm[5..3]);
          mmx_touch();
          write_mm(mm_dst, read_xmm(src_xmm)[63..0])
        },
        // F3 0F D6: MOVQ2DQ xmm, mm — SDM: DEST[63:0] := SRC; DEST[127:64] := 0
        MP_F3 => {
          let modrm = fetch(1);
          let _ = modrm_rm(modrm, pfx);
          let dst_xmm = modrm_xmm_reg(modrm, pfx);
          let mm_src : range(0, 7) = unsigned(modrm[2..0]);
          write_xmm_legacy(dst_xmm, zero_extend(read_mm(mm_src)))
        },
        _ => raise_UD(),
      }
    },
    // 0F E6: CVTDQ2PD/CVTPD2DQ/CVTTPD2DQ
    230 => {
      let mp = get_mandatory_prefix(pfx);
      let modrm = fetch(1);
      let xreg = modrm_xmm_reg(modrm, pfx);
      let src = modrm_rm(modrm, pfx);
      let src_xmm : xmmword = match src {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
        RM_mem(m) => read_mem(m),
      };
      match mp {
        MP_F3 => {
          let r : xmmword = __int32_to_f64(src_xmm[63..32]) @ __int32_to_f64(src_xmm[31..0]);
          write_xmm_legacy(xreg, r)
        },
        MP_F2 => {
          let r : xmmword = zeros(64) @ __f64_to_int32(src_xmm[127..64]) @ __f64_to_int32(src_xmm[63..0]);
          write_xmm_legacy(xreg, r)
        },
        MP_66 => {
          let lo : dword = __f64_to_int32_trunc(src_xmm[63..0]);
          let hi : dword = __f64_to_int32_trunc(src_xmm[127..64]);
          let r : xmmword = zeros(64) @ hi @ lo;
          write_xmm_legacy(xreg, r)
        },
        _       => raise_UD(),
      }
    },
    // 0F 2B: MOVNTPS/MOVNTPD m128, xmm
    43 => {
      let mp = get_mandatory_prefix(pfx);
      let modrm = fetch(1);
      let xreg = modrm_xmm_reg(modrm, pfx);
      let dest = modrm_rm(modrm, pfx);
      if mp != MP_NONE & mp != MP_66 then raise_UD();
      rm_mem(dest) = read_xmm(xreg)
    },
    // 0F 7C: HADDPS/HADDPD (SSE3)
    124 => {
      if ~(has_sse3) then raise_UD();
      let mp = get_mandatory_prefix(pfx);
      let modrm = fetch(1);
      let xreg = modrm_xmm_reg(modrm, pfx);
      let src = modrm_rm(modrm, pfx);
      let src_xmm : xmmword = decode_xmm_src(modrm, src, pfx);
      match mp {
        MP_F2 => {
          let a : xmmword = read_xmm(xreg);
          let d0 : dword = fp_add(a[31..0], a[63..32]);
          let d1 : dword = fp_add(a[95..64], a[127..96]);
          let d2 : dword = fp_add(src_xmm[31..0], src_xmm[63..32]);
          let d3 : dword = fp_add(src_xmm[95..64], src_xmm[127..96]);
          write_xmm_legacy(xreg, d3 @ d2 @ d1 @ d0)
        },
        MP_66 => {
          let a : xmmword = read_xmm(xreg);
          let lo : qword = fp_add(a[63..0], a[127..64]);
          let hi : qword = fp_add(src_xmm[63..0], src_xmm[127..64]);
          write_xmm_legacy(xreg, hi @ lo)
        },
        _       => raise_UD(),
      }
    },
    // 0F 7D: HSUBPS/HSUBPD (SSE3)
    125 => {
      if ~(has_sse3) then raise_UD();
      let mp = get_mandatory_prefix(pfx);
      let modrm = fetch(1);
      let xreg = modrm_xmm_reg(modrm, pfx);
      let src = modrm_rm(modrm, pfx);
      let src_xmm : xmmword = decode_xmm_src(modrm, src, pfx);
      match mp {
        MP_F2 => {
          let a : xmmword = read_xmm(xreg);
          let d0 : dword = fp_sub(a[31..0], a[63..32]);
          let d1 : dword = fp_sub(a[95..64], a[127..96]);
          let d2 : dword = fp_sub(src_xmm[31..0], src_xmm[63..32]);
          let d3 : dword = fp_sub(src_xmm[95..64], src_xmm[127..96]);
          write_xmm_legacy(xreg, d3 @ d2 @ d1 @ d0)
        },
        MP_66 => {
          let a : xmmword = read_xmm(xreg);
          let lo : qword = fp_sub(a[63..0], a[127..64]);
          let hi : qword = fp_sub(src_xmm[63..0], src_xmm[127..64]);
          write_xmm_legacy(xreg, hi @ lo)
        },
        _       => raise_UD(),
      }
    },
    // 0F C2: CMPPS/CMPPD/CMPSS/CMPSD xmm, xmm/m, imm8
    194 => {
      let mp = get_mandatory_prefix(pfx);
      let modrm = fetch(1);
      let xreg = modrm_xmm_reg(modrm, pfx);
      let src = modrm_rm(modrm, pfx);
      let src_xmm : xmmword = match src {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
        RM_mem(m) => match mp {
          MP_F3 => zero_extend(v(32, m)),
          MP_F2 => zero_extend(v(64, m)),
          _     => read_mem(m),
        },
      };
      let imm = fetch(1);
      match mp {
        MP_NONE => {
          let a : xmmword = read_xmm(xreg);
          let pred : bits(5) = zero_extend(imm[2..0]);
          let r : xmmword =
          cmp_pred_f32(a[127..96], src_xmm[127..96], pred) @
          cmp_pred_f32(a[95..64], src_xmm[95..64], pred) @
          cmp_pred_f32(a[63..32], src_xmm[63..32], pred) @
          cmp_pred_f32(a[31..0], src_xmm[31..0], pred);
          write_xmm_legacy(xreg, r)
        },
        MP_66 => {
          let a : xmmword = read_xmm(xreg);
          let pred : bits(5) = zero_extend(imm[2..0]);
          let r : xmmword =
          cmp_pred_f64(a[127..64], src_xmm[127..64], pred) @
          cmp_pred_f64(a[63..0], src_xmm[63..0], pred);
          write_xmm_legacy(xreg, r)
        },
        MP_F3 => {
          let a : xmmword = read_xmm(xreg);
          let pred : bits(5) = zero_extend(imm[2..0]);
          let low : dword = cmp_pred_f32(a[31..0], src_xmm[31..0], pred);
          let r : xmmword = a[127..32] @ low;
          write_xmm_legacy(xreg, r)
        },
        MP_F2 => {
          let a : xmmword = read_xmm(xreg);
          let pred : bits(5) = zero_extend(imm[2..0]);
          let low : qword = cmp_pred_f64(a[63..0], src_xmm[63..0], pred);
          let r : xmmword = a[127..64] @ low;
          write_xmm_legacy(xreg, r)
        },
      }
    },
    // 0F D0: ADDSUBPS/ADDSUBPD (SSE3)
    208 => {
      if ~(has_sse3) then raise_UD();
      let mp = get_mandatory_prefix(pfx);
      let modrm = fetch(1);
      let xreg = modrm_xmm_reg(modrm, pfx);
      let src = modrm_rm(modrm, pfx);
      let src_xmm : xmmword = decode_xmm_src(modrm, src, pfx);
      match mp {
        MP_F2 => {
          let a : xmmword = read_xmm(xreg);
          let d0 : dword = fp_sub(a[31..0], src_xmm[31..0]);
          let d1 : dword = fp_add(a[63..32], src_xmm[63..32]);
          let d2 : dword = fp_sub(a[95..64], src_xmm[95..64]);
          let d3 : dword = fp_add(a[127..96], src_xmm[127..96]);
          write_xmm_legacy(xreg, d3 @ d2 @ d1 @ d0)
        },
        MP_66 => {
          let a : xmmword = read_xmm(xreg);
          let lo : qword = fp_sub(a[63..0], src_xmm[63..0]);
          let hi : qword = fp_add(a[127..64], src_xmm[127..64]);
          write_xmm_legacy(xreg, hi @ lo)
        },
        _       => raise_UD(),
      }
    },
    _ => raise_UD(),
  }
}

// XMM element extraction helpers (shared by decode_sse_fp and decode_sse_int)
val extract_byte_from_xmm : (xmmword, byte) -> byte
function extract_byte_from_xmm(s, imm8) = {
  let sel : range(0, 15) = unsigned(imm8[3..0]);
  match sel {
    0  => s[7..0],
    1  => s[15..8],
    2  => s[23..16],
    3  => s[31..24],
    4  => s[39..32],
    5  => s[47..40],
    6  => s[55..48],
    7  => s[63..56],
    8  => s[71..64],
    9  => s[79..72],
    10 => s[87..80],
    11 => s[95..88],
    12 => s[103..96],
    13 => s[111..104],
    14 => s[119..112],
    15 => s[127..120]
  }
}

val extract_dword_from_xmm : (xmmword, byte) -> dword
function extract_dword_from_xmm(s, imm8) = {
  let sel : range(0, 3) = unsigned(imm8[1..0]);
  match sel {
    0 => s[31..0],
    1 => s[63..32],
    2 => s[95..64],
    3 => s[127..96]
  }
}

val extract_qword_from_xmm : (xmmword, byte) -> qword
function extract_qword_from_xmm(s, imm8) = {
  let sel : range(0, 1) = unsigned(imm8[0]);
  match sel {
    0 => s[63..0],
    1 => s[127..64]
  }
}

// INSERTPS — Insert Scalar Single-Precision FP Value (SSE4.1)
val exec_insertps : (simd_idx, xmmword, byte) -> unit
function exec_insertps(dst, src, imm8) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  // Select source float using imm8[7:6]
  let src_sel : range(0, 3) = unsigned(imm8[7..6]);
  let src_float : dword = b[(src_sel * 32 + 31) .. (src_sel * 32)];
  // Insert at destination position using imm8[5:4]
  let sel = imm8[5..4];
  let m0 : dword = sign_extend(~(sel[1] | sel[0]));
  let x1 : bits(2) = sel ^ 0b01;
  let m1 : dword = sign_extend(~(x1[1] | x1[0]));
  let x2 : bits(2) = sel ^ 0b10;
  let m2 : dword = sign_extend(~(x2[1] | x2[0]));
  let x3 : bits(2) = sel ^ 0b11;
  let m3 : dword = sign_extend(~(x3[1] | x3[0]));
  let t0 : dword = (src_float & m0) | (a[31..0] & ~(m0));
  let t1 : dword = (src_float & m1) | (a[63..32] & ~(m1));
  let t2 : dword = (src_float & m2) | (a[95..64] & ~(m2));
  let t3 : dword = (src_float & m3) | (a[127..96] & ~(m3));
  // Zero lanes indicated by imm8[3:0] (branchless)
  write_xmm_legacy(dst,
    (t3 & sign_extend(~(imm8[3]))) @
    (t2 & sign_extend(~(imm8[2]))) @
    (t1 & sign_extend(~(imm8[1]))) @
    (t0 & sign_extend(~(imm8[0]))))
}

// =========================================================================
// 3-Byte Opcode Map: SSE Floating-Point Operations
// =========================================================================

// 0F 38 xx — SSE FP operations (BLENDVPS, BLENDVPD)
val dispatch_3byte_38_sse_fp : (byte, Prefixes) -> unit
function dispatch_3byte_38_sse_fp(opcode, pfx) = {
  let op : range(0, 255) = unsigned(opcode);
  let mp = get_mandatory_prefix(pfx);
  if mp != MP_66 then raise_UD();
  let modrm = fetch(1);
  let xreg = modrm_xmm_reg(modrm, pfx);
  let src = modrm_rm(modrm, pfx);
  let src_xmm : xmmword = decode_xmm_src(modrm, src, pfx);
  match op {
    // BLENDVPS xmm1, xmm2/m128, <XMM0>
    20 => {
      let a : xmmword = read_xmm(xreg);
      let m : xmmword = read_xmm(0);
      let d0 : dword = blend(a[31..0], src_xmm[31..0], m[31]);
      let d1 : dword = blend(a[63..32], src_xmm[63..32], m[63]);
      let d2 : dword = blend(a[95..64], src_xmm[95..64], m[95]);
      let d3 : dword = blend(a[127..96], src_xmm[127..96], m[127]);
      write_xmm_legacy(xreg, d3 @ d2 @ d1 @ d0)
    },
    // BLENDVPD xmm1, xmm2/m128, <XMM0>
    21 => {
      let a : xmmword = read_xmm(xreg);
      let m : xmmword = read_xmm(0);
      let lo : qword = blend(a[63..0], src_xmm[63..0], m[63]);
      let hi : qword = blend(a[127..64], src_xmm[127..64], m[127]);
      write_xmm_legacy(xreg, hi @ lo)
    },
    _  => raise_UD(),
  }
}

// 0F 3A xx — SSE FP operations (ROUND*, BLEND*, DP*, EXTRACTPS, INSERTPS)
val dispatch_3byte_3a_sse_fp : (byte, Prefixes) -> unit
function dispatch_3byte_3a_sse_fp(opcode, pfx) = {
  let op : range(0, 255) = unsigned(opcode);
  let mp = get_mandatory_prefix(pfx);
  if mp != MP_66 then raise_UD();
  let modrm = fetch(1);
  let xreg = modrm_xmm_reg(modrm, pfx);
  let src = modrm_rm(modrm, pfx);
  match op {
    // SSE4.1 — round
    8 => {
      let src_xmm = decode_xmm_src(modrm, src, pfx);
      let imm = fetch(1);
      let d0 : dword = fp_round(src_xmm[31..0], imm);
      let d1 : dword = fp_round(src_xmm[63..32], imm);
      let d2 : dword = fp_round(src_xmm[95..64], imm);
      let d3 : dword = fp_round(src_xmm[127..96], imm);
      write_xmm_legacy(xreg, d3 @ d2 @ d1 @ d0)
    },
    9 => {
      let src_xmm = decode_xmm_src(modrm, src, pfx);
      let imm = fetch(1);
      let lo : qword = fp_round(src_xmm[63..0], imm);
      let hi : qword = fp_round(src_xmm[127..64], imm);
      write_xmm_legacy(xreg, hi @ lo)
    },
    10 => {
      let src_xmm = decode_xmm_src(modrm, src, pfx);
      let imm = fetch(1);
      let a : xmmword = read_xmm(xreg);
      let lo : dword = fp_round(src_xmm[31..0], imm);
      write_xmm_legacy(xreg, a[127..32] @ lo)
    },
    11 => {
      let src_xmm = decode_xmm_src(modrm, src, pfx);
      let imm = fetch(1);
      let a : xmmword = read_xmm(xreg);
      let lo : qword = fp_round(src_xmm[63..0], imm);
      write_xmm_legacy(xreg, a[127..64] @ lo)
    },

    // SSE4.1 — blend
    12 => {
      let src_xmm = decode_xmm_src(modrm, src, pfx);
      let imm = fetch(1);
      let a : xmmword = read_xmm(xreg);
      write_xmm_legacy(xreg,
        blend(a[127..96], src_xmm[127..96], imm[3]) @
        blend(a[95..64],  src_xmm[95..64],  imm[2]) @
        blend(a[63..32],  src_xmm[63..32],  imm[1]) @
        blend(a[31..0],   src_xmm[31..0],   imm[0]))
    },
    13 => {
      let src_xmm = decode_xmm_src(modrm, src, pfx);
      let imm = fetch(1);
      let a : xmmword = read_xmm(xreg);
      write_xmm_legacy(xreg,
        blend(a[127..64], src_xmm[127..64], imm[1]) @
        blend(a[63..0],   src_xmm[63..0],   imm[0]))
    },

    // PEXTRW r/m16, xmm, imm8 (SSE4.1, 66 0F 3A 15)
    // SDM: ModRM:reg = source XMM, ModRM:r/m = dest (reg: zero-extend to 32, mem: 16 bits)
    21 => {
      let imm = fetch(1);
      let sel : range(0, 7) = unsigned(imm[2..0]);
      let w : word = extract_word_from_xmm(read_xmm(xreg), sel);
      match src {
        RM_reg(_) => {
          let dst_reg = modrm_rm_reg(modrm, pfx);
          v(dst_reg) = zero_extend(32, w)
        },
        RM_mem(m) => v(m) = w,
      }
    },

    // EXTRACTPS r/m32, xmm, imm8
    23 => {
      let imm = fetch(1);
      let data = extract_dword_from_xmm(read_xmm(xreg), imm);
      match src {
        RM_reg(_) => {
          let dst_reg = modrm_rm_reg(modrm, pfx);
          v(dst_reg) = data;
        },
        RM_mem(m) => v(m) = data,
      }
    },

    // INSERTPS xmm, xmm/m32, imm8
    // Memory form: reads 32 bits, imm8[7:6] forced to 0 (count_s ignored).
    33 => {
      let imm = fetch(1);
      match src {
        RM_reg(_) => exec_insertps(xreg, read_xmm(modrm_xmm_rm(modrm, pfx)), imm),
        RM_mem(m) => {
          let src_val : xmmword = zero_extend(v(32, m));
          exec_insertps(xreg, src_val, imm & 0x3F)
        },
      }
    },

    // SSE4.1 — dot product
    64 => {
      let src_xmm = decode_xmm_src(modrm, src, pfx);
      let imm = fetch(1);
      let a : xmmword = read_xmm(xreg);
      let temp0 : dword = fp_mul(a[31..0], src_xmm[31..0]) & sign_extend(imm[4]);
      let temp1 : dword = fp_mul(a[63..32], src_xmm[63..32]) & sign_extend(imm[5]);
      let temp2 : dword = fp_mul(a[95..64], src_xmm[95..64]) & sign_extend(imm[6]);
      let temp3 : dword = fp_mul(a[127..96], src_xmm[127..96]) & sign_extend(imm[7]);
      let sum01 : dword = fp_add(temp0, temp1);
      let sum23 : dword = fp_add(temp2, temp3);
      let sum : dword = fp_add(sum01, sum23);
      write_xmm_legacy(xreg,
        (sum & sign_extend(imm[3])) @
        (sum & sign_extend(imm[2])) @
        (sum & sign_extend(imm[1])) @
        (sum & sign_extend(imm[0])))
    },
    65 => {
      let src_xmm = decode_xmm_src(modrm, src, pfx);
      let imm = fetch(1);
      let a : xmmword = read_xmm(xreg);
      let temp0 : qword = fp_mul(a[63..0], src_xmm[63..0]) & sign_extend(imm[4]);
      let temp1 : qword = fp_mul(a[127..64], src_xmm[127..64]) & sign_extend(imm[5]);
      let sum : qword = fp_add(temp0, temp1);
      write_xmm_legacy(xreg,
        (sum & sign_extend(imm[1])) @
        (sum & sign_extend(imm[0])))
    },

    _ => raise_UD(),
  }
}

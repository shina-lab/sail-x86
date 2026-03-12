// x86-64 — SSE Floating-Point Operations
//
// SSE/SSE2/SSE3 data movement, arithmetic, conversion, and comparison.

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

val __ldmxcsr : dword -> unit
val __stmxcsr : unit -> dword

// =========================================================================
// SSE floating-point dispatch
// =========================================================================

val __f32_rsqrt : dword -> dword
val __f32_rcp : dword -> dword

// FP comparison predicate helpers (used by CMPPS/CMPPD/CMPSS/CMPSD)
val cmp_pred_f32 : (dword, dword, bits(3)) -> dword
function cmp_pred_f32(a, b, pred) = {
  let result = __compare_ss(a, b);
  let cond : bool = match pred {
    0b000 => result == FP_EQ,
    0b001 => result == FP_LT,
    0b010 => result == FP_LT | result == FP_EQ,
    0b011 => result == FP_UNORDERED,
    0b100 => result != FP_EQ,
    0b101 => result != FP_LT,
    0b110 => result != FP_LT & result != FP_EQ,  // NLE: not less-or-equal (true for unordered)
    0b111 => result != FP_UNORDERED,
  };
  zeros() - zero_extend(bool_to_bit(cond))
}

val cmp_pred_f64 : (qword, qword, bits(3)) -> qword
function cmp_pred_f64(a, b, pred) = {
  let result = __compare_sd(a, b);
  let cond : bool = match pred {
    0b000 => result == FP_EQ,
    0b001 => result == FP_LT,
    0b010 => result == FP_LT | result == FP_EQ,
    0b011 => result == FP_UNORDERED,
    0b100 => result != FP_EQ,
    0b101 => result != FP_LT,
    0b110 => result != FP_LT & result != FP_EQ,  // NLE: not less-or-equal (true for unordered)
    0b111 => result != FP_UNORDERED,
  };
  zeros() - zero_extend(bool_to_bit(cond))
}

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
      let modrm = fetch_byte();
      let xreg = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      match mp {
        MP_NONE => {
          // MOVUPS xmm1, xmm2/m128
          match rm {
            RM_reg(_) => exec_movups(xreg, read_xmm(modrm_xmm_rm(modrm, pfx))),
            RM_mem(addr) => {
              write_xmm(xreg, mem_read128(addr))
            },
          }
        },
        MP_66 => {
          // MOVUPD xmm1, xmm2/m128
          match rm {
            RM_reg(_) => exec_movupd_load(xreg, read_xmm(modrm_xmm_rm(modrm, pfx))),
            RM_mem(addr) => {
              write_xmm(xreg, mem_read128(addr))
            },
          }
        },
        MP_F3 => {
          // MOVSS xmm1, xmm2/m32
          match rm {
            RM_reg(_) => exec_movss_xmm(xreg, read_xmm(modrm_xmm_rm(modrm, pfx))),
            RM_mem(addr) => {
              let v : xmmword = zero_extend(mem_read32(addr));
              write_xmm(xreg, v)
            },
          }
        },
        MP_F2 => {
          // MOVSD xmm1, xmm2/m64
          match rm {
            RM_reg(_) => exec_movsd_xmm(xreg, read_xmm(modrm_xmm_rm(modrm, pfx))),
            RM_mem(addr) => {
              let v : xmmword = zero_extend(mem_read64(addr));
              write_xmm(xreg, v)
            },
          }
        },
      }
    },
    // 0F 11: MOVUPS/MOVUPD/MOVSD/MOVSS xmm/m, xmm
    17 => {
      let mp = get_mandatory_prefix(pfx);
      let modrm = fetch_byte();
      let xreg = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      match mp {
        MP_NONE => {
          // MOVUPS xmm2/m128, xmm1
          match rm {
            RM_reg(_) => exec_movups(modrm_xmm_rm(modrm, pfx), read_xmm(xreg)),
            RM_mem(addr) => {
              mem_write128(addr, read_xmm(xreg))
            },
          }
        },
        MP_66 => {
          // MOVUPD xmm2/m128, xmm1
          match rm {
            RM_reg(_) => exec_movupd_load(modrm_xmm_rm(modrm, pfx), read_xmm(xreg)),
            RM_mem(addr) => {
              mem_write128(addr, read_xmm(xreg))
            },
          }
        },
        MP_F3 => {
          // MOVSS m32, xmm1
          match rm {
            RM_reg(_) => exec_movss_xmm(modrm_xmm_rm(modrm, pfx), read_xmm(xreg)),
            RM_mem(addr) => {
              let v = read_xmm(xreg);
              mem_write32(addr, v[31..0])
            },
          }
        },
        MP_F2 => {
          // MOVSD m64, xmm1
          match rm {
            RM_reg(_) => exec_movsd_xmm(modrm_xmm_rm(modrm, pfx), read_xmm(xreg)),
            RM_mem(addr) => {
              let v = read_xmm(xreg);
              mem_write64(addr, v[63..0])
            },
          }
        },
      }
    },
    // 0F 12: MOVLPS/MOVLPD/MOVSLDUP/MOVDDUP
    18 => {
      let mp = get_mandatory_prefix(pfx);
      let modrm = fetch_byte();
      let xreg = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      match mp {
        MP_NONE => {
          // MOVLPS xmm, m64 or MOVHLPS xmm, xmm
          match rm {
            RM_reg(_) => {
              let src = read_xmm(modrm_xmm_rm(modrm, pfx));
              let high : qword = read_xmm(xreg)[127..64];
              write_xmm_legacy(xreg, high @ src[127..64])
            },
            RM_mem(addr) => {
              var xmm : xmmword = read_xmm(xreg);
              xmm[63..0] = mem_read64(addr);
              write_xmm_legacy(xreg, xmm)
            },
          }
        },
        MP_66 => {
          // MOVLPD xmm, m64
          match rm {
            RM_mem(addr) => {
              var xmm : xmmword = read_xmm(xreg);
              xmm[63..0] = mem_read64(addr);
              write_xmm_legacy(xreg, xmm)
            },
            RM_reg(_) => raise_UD(),
          }
        },
        MP_F3 => {
          // MOVSLDUP xmm1, xmm2/m128
          match rm {
            RM_reg(_) => exec_movsldup(xreg, read_xmm(modrm_xmm_rm(modrm, pfx))),
            RM_mem(addr) => exec_movsldup(xreg, mem_read128(addr)),
          }
        },
        MP_F2 => {
          // MOVDDUP xmm1, xmm2/m64
          match rm {
            RM_reg(_) => {
              let s = read_xmm(modrm_xmm_rm(modrm, pfx));
              write_xmm_legacy(xreg, s[63..0] @ s[63..0])
            },
            RM_mem(addr) => {
              let lo = mem_read64(addr);
              write_xmm(xreg, lo @ lo)
            },
          }
        },
      }
    },
    // 0F 13: MOVLPS/MOVLPD m64, xmm
    19 => {
      let mp = get_mandatory_prefix(pfx);
      let modrm = fetch_byte();
      let xreg = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      match rm {
        RM_mem(addr) => {
          let v = read_xmm(xreg);
          mem_write64(addr, v[63..0])
        },
        RM_reg(_) => raise_UD(),
      }
    },
    // 0F 14: UNPCKLPS/UNPCKLPD
    20 => {
      let mp = get_mandatory_prefix(pfx);
      let modrm = fetch_byte();
      let xreg = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src : xmmword = match rm {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
        RM_mem(addr) => mem_read128(addr),
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
      let modrm = fetch_byte();
      let xreg = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src : xmmword = match rm {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
        RM_mem(addr) => mem_read128(addr),
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
      let modrm = fetch_byte();
      let xreg = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      match mp {
        MP_NONE => {
          match rm {
            RM_reg(_) => {
              let src = read_xmm(modrm_xmm_rm(modrm, pfx));
              let low : qword = read_xmm(xreg)[63..0];
              write_xmm_legacy(xreg, src[63..0] @ low)
            },
            RM_mem(addr) => {
              var xmm : xmmword = read_xmm(xreg);
              xmm[127..64] = mem_read64(addr);
              write_xmm_legacy(xreg, xmm)
            },
          }
        },
        MP_66 => {
          match rm {
            RM_mem(addr) => {
              var xmm : xmmword = read_xmm(xreg);
              xmm[127..64] = mem_read64(addr);
              write_xmm_legacy(xreg, xmm)
            },
            RM_reg(_) => raise_UD(),
          }
        },
        MP_F3 => {
          match rm {
            RM_reg(_) => exec_movshdup(xreg, read_xmm(modrm_xmm_rm(modrm, pfx))),
            RM_mem(addr) => exec_movshdup(xreg, mem_read128(addr)),
          }
        },
        _ => raise_UD(),
      }
    },
    // 0F 17: MOVHPS/MOVHPD m64, xmm
    23 => {
      let modrm = fetch_byte();
      let xreg = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      match rm {
        RM_mem(addr) => {
          let v = read_xmm(xreg);
          mem_write64(addr, v[127..64])
        },
        RM_reg(_) => raise_UD(),
      }
    },
    // 0F 28: MOVAPS/MOVAPD xmm, xmm/m128
    40 => {
      let mp = get_mandatory_prefix(pfx);
      let modrm = fetch_byte();
      let xreg = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      match rm {
        RM_reg(_) => {
          match mp {
            MP_NONE => exec_movaps(xreg, read_xmm(modrm_xmm_rm(modrm, pfx))),
            MP_66   => exec_movapd(xreg, read_xmm(modrm_xmm_rm(modrm, pfx))),
            _       => raise_UD(),
          }
        },
        RM_mem(addr) => {
          // MOVAPS/MOVAPD require 16-byte alignment; #GP(0) if unaligned
          if unsigned(addr) % 16 != 0 then raise_GP0();
          write_xmm(xreg, mem_read128(addr))
        },
      }
    },
    // 0F 29: MOVAPS/MOVAPD xmm/m128, xmm
    41 => {
      let mp = get_mandatory_prefix(pfx);
      let modrm = fetch_byte();
      let xreg = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      match rm {
        RM_reg(_) => {
          match mp {
            MP_NONE => exec_movaps(modrm_xmm_rm(modrm, pfx), read_xmm(xreg)),
            MP_66   => exec_movapd(modrm_xmm_rm(modrm, pfx), read_xmm(xreg)),
            _       => raise_UD(),
          }
        },
        RM_mem(addr) => {
          // MOVAPS/MOVAPD require 16-byte alignment; #GP(0) if unaligned
          if unsigned(addr) % 16 != 0 then raise_GP0();
          mem_write128(addr, read_xmm(xreg))
        },
      }
    },
    // 0F 2A: CVTSI2SS/CVTSI2SD
    42 => {
      let mp = get_mandatory_prefix(pfx);
      let modrm = fetch_byte();
      let xreg = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let os = get_operand_size(pfx);
      let src_val : qword = match rm {
        RM_reg(_) => read_gpr(modrm_rm_reg(modrm, pfx), os),
        RM_mem(addr) => match os {
          OS64 => mem_read64(addr),
          _    => zero_extend(mem_read32(addr)),
        },
      };
      match mp {
        MP_F3 => {
          let result : dword = match os {
            OS64 => __int64_to_f32(src_val),
            _    => __int32_to_f32(src_val[31..0]),
          };
          var xmm : xmmword = read_xmm(xreg);
          xmm[31..0] = result;
          write_xmm_legacy(xreg, xmm)
        },
        MP_F2 => {
          let result : qword = match os {
            OS64 => __int64_to_f64(src_val),
            _    => __int32_to_f64(src_val[31..0]),
          };
          var xmm : xmmword = read_xmm(xreg);
          xmm[63..0] = result;
          write_xmm_legacy(xreg, xmm)
        },
        _     => raise_UD(),
      }
    },
    // 0F 2C: CVTTSS2SI/CVTTSD2SI
    44 => {
      let mp = get_mandatory_prefix(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let os = get_operand_size(pfx);
      let src_xmm : xmmword = match rm {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
        RM_mem(addr) => match mp {
          MP_F3 => zero_extend(mem_read32(addr)),
          MP_F2 => zero_extend(mem_read64(addr)),
          _     => zeros(),
        },
      };
      match mp {
        MP_F3 => {
          match os {
            OS64 => write_gpr64(reg, __f32_to_int64_trunc(src_xmm[31..0])),
            _    => write_gpr32(reg, __f32_to_int32_trunc(src_xmm[31..0])),
          }
        },
        MP_F2 => {
          match os {
            OS64 => write_gpr64(reg, __f64_to_int64_trunc(src_xmm[63..0])),
            _    => write_gpr32(reg, __f64_to_int32_trunc(src_xmm[63..0])),
          }
        },
        _     => raise_UD(),
      }
    },
    // 0F 2D: CVTSS2SI/CVTSD2SI
    45 => {
      let mp = get_mandatory_prefix(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let os = get_operand_size(pfx);
      let src_xmm : xmmword = match rm {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
        RM_mem(addr) => match mp {
          MP_F3 => zero_extend(mem_read32(addr)),
          MP_F2 => zero_extend(mem_read64(addr)),
          _     => zeros(),
        },
      };
      match mp {
        MP_F3 => {
          match os {
            OS64 => write_gpr64(reg, __f32_to_int64(src_xmm[31..0])),
            _    => write_gpr32(reg, __f32_to_int32(src_xmm[31..0])),
          }
        },
        MP_F2 => {
          match os {
            OS64 => write_gpr64(reg, __f64_to_int64(src_xmm[63..0])),
            _    => write_gpr32(reg, __f64_to_int32(src_xmm[63..0])),
          }
        },
        _     => raise_UD(),
      }
    },
    // 0F 2E: UCOMISS/UCOMISD
    46 => {
      let mp = get_mandatory_prefix(pfx);
      let modrm = fetch_byte();
      let xreg = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src_xmm : xmmword = match rm {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
        RM_mem(addr) => match mp {
          MP_NONE => zero_extend(mem_read32(addr)),
          MP_66   => zero_extend(mem_read64(addr)),
          _       => zeros(),
        },
      };
      match mp {
        MP_NONE => {
          let a : dword = read_xmm(xreg)[31..0];
          let b : dword = src_xmm[31..0];
          match __compare_ss(a, b) {
            FP_UNORDERED => { ZF = bitone;  PF = bitone;  CF = bitone;  },
            FP_GT        => { ZF = bitzero; PF = bitzero; CF = bitzero; },
            FP_LT        => { ZF = bitzero; PF = bitzero; CF = bitone;  },
            FP_EQ        => { ZF = bitone;  PF = bitzero; CF = bitzero; },
          };
          OF = bitzero;
          AF = bitzero;
          SF = bitzero
        },
        MP_66 => {
          let a : qword = read_xmm(xreg)[63..0];
          let b : qword = src_xmm[63..0];
          match __compare_sd(a, b) {
            FP_UNORDERED => { ZF = bitone;  PF = bitone;  CF = bitone;  },
            FP_GT        => { ZF = bitzero; PF = bitzero; CF = bitzero; },
            FP_LT        => { ZF = bitzero; PF = bitzero; CF = bitone;  },
            FP_EQ        => { ZF = bitone;  PF = bitzero; CF = bitzero; },
          };
          OF = bitzero;
          AF = bitzero;
          SF = bitzero
        },
        _       => raise_UD(),
      }
    },
    // 0F 2F: COMISS/COMISD
    47 => {
      let mp = get_mandatory_prefix(pfx);
      let modrm = fetch_byte();
      let xreg = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src_xmm : xmmword = match rm {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
        RM_mem(addr) => match mp {
          MP_NONE => zero_extend(mem_read32(addr)),
          MP_66   => zero_extend(mem_read64(addr)),
          _       => zeros(),
        },
      };
      match mp {
        MP_NONE => {
          let a : dword = read_xmm(xreg)[31..0];
          let b : dword = src_xmm[31..0];
          match __compare_ss(a, b) {
            FP_UNORDERED => { ZF = bitone;  PF = bitone;  CF = bitone;  },
            FP_GT        => { ZF = bitzero; PF = bitzero; CF = bitzero; },
            FP_LT        => { ZF = bitzero; PF = bitzero; CF = bitone;  },
            FP_EQ        => { ZF = bitone;  PF = bitzero; CF = bitzero; },
          };
          OF = bitzero;
          AF = bitzero;
          SF = bitzero
        },
        MP_66 => {
          let a : qword = read_xmm(xreg)[63..0];
          let b : qword = src_xmm[63..0];
          match __compare_sd(a, b) {
            FP_UNORDERED => { ZF = bitone;  PF = bitone;  CF = bitone;  },
            FP_GT        => { ZF = bitzero; PF = bitzero; CF = bitzero; },
            FP_LT        => { ZF = bitzero; PF = bitzero; CF = bitone;  },
            FP_EQ        => { ZF = bitone;  PF = bitzero; CF = bitzero; },
          };
          OF = bitzero;
          AF = bitzero;
          SF = bitzero
        },
        _       => raise_UD(),
      }
    },
    // 0F 50: MOVMSKPS/MOVMSKPD
    80 => {
      let mp = get_mandatory_prefix(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let _ = decode_rm(modrm, pfx);
      let src_xmm : xmmword = read_xmm(modrm_xmm_rm(modrm, pfx));
      match mp {
        MP_NONE => {
          let mask : bits(4) = src_xmm[127] @ src_xmm[95] @ src_xmm[63] @ src_xmm[31];
          write_gpr32(reg, zero_extend(mask))
        },
        MP_66 => {
          let mask : bits(2) = src_xmm[127] @ src_xmm[63];
          write_gpr32(reg, zero_extend(mask))
        },
        _       => raise_UD(),
      }
    },
    // 0F 51-5F: SSE/SSE2 scalar/packed arithmetic
    // These follow a pattern based on mandatory prefix:
    //   NONE=PS, 66=PD, F3=SS, F2=SD
    op if 81 <= op & op <= 95 => {
      let mp = get_mandatory_prefix(pfx);
      let modrm = fetch_byte();
      let xreg = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src_xmm : xmmword = match rm {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
        RM_mem(addr) => match mp {
          MP_F3 => zero_extend(mem_read32(addr)),
          MP_F2 => zero_extend(mem_read64(addr)),
          _     => mem_read128(addr),
        },
      };
      let arith_op : range(0, 15) = op - 80;
      match arith_op {
        // 0F 51: SQRT
        1 => {
          match mp {
            MP_NONE => {
              let r : xmmword = __f32_sqrt(src_xmm[127..96]) @
              __f32_sqrt(src_xmm[95..64]) @
              __f32_sqrt(src_xmm[63..32]) @
              __f32_sqrt(src_xmm[31..0]);
              write_xmm_legacy(xreg, r)
            },
            MP_66 => {
              write_xmm_legacy(xreg, __f64_sqrt(src_xmm[127..64]) @ __f64_sqrt(src_xmm[63..0]))
            },
            MP_F3 => {
              var xmm : xmmword = read_xmm(xreg);
              xmm[31..0] = __f32_sqrt(src_xmm[31..0]);
              write_xmm_legacy(xreg, xmm)
            },
            MP_F2 => {
              var xmm : xmmword = read_xmm(xreg);
              xmm[63..0] = __f64_sqrt(src_xmm[63..0]);
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
            MP_NONE => write_xmm_legacy(xreg, xor_vec(read_xmm(xreg), src_xmm)),
            MP_66 => write_xmm_legacy(xreg, xor_vec(read_xmm(xreg), src_xmm)),
            _       => raise_UD(),
          }
        },
        // 0F 58: ADD
        8 => {
          match mp {
            MP_NONE => {
              let a : xmmword = read_xmm(xreg);
              let r : xmmword = __f32_add(a[127..96], src_xmm[127..96]) @
              __f32_add(a[95..64], src_xmm[95..64]) @
              __f32_add(a[63..32], src_xmm[63..32]) @
              __f32_add(a[31..0], src_xmm[31..0]);
              write_xmm_legacy(xreg, r)
            },
            MP_66 => {
              let a : xmmword = read_xmm(xreg);
              let lo : qword = __f64_add(a[63..0], src_xmm[63..0]);
              let hi : qword = __f64_add(a[127..64], src_xmm[127..64]);
              write_xmm_legacy(xreg, hi @ lo)
            },
            MP_F3 => {
              var xmm : xmmword = read_xmm(xreg);
              xmm[31..0] = __f32_add(xmm[31..0], src_xmm[31..0]);
              write_xmm_legacy(xreg, xmm)
            },
            MP_F2 => {
              var xmm : xmmword = read_xmm(xreg);
              xmm[63..0] = __f64_add(xmm[63..0], src_xmm[63..0]);
              write_xmm_legacy(xreg, xmm)
            },
          }
        },
        // 0F 59: MUL
        9 => {
          match mp {
            MP_NONE => {
              let a : xmmword = read_xmm(xreg);
              let r : xmmword = __f32_mul(a[127..96], src_xmm[127..96]) @
              __f32_mul(a[95..64], src_xmm[95..64]) @
              __f32_mul(a[63..32], src_xmm[63..32]) @
              __f32_mul(a[31..0], src_xmm[31..0]);
              write_xmm_legacy(xreg, r)
            },
            MP_66 => {
              let a : xmmword = read_xmm(xreg);
              write_xmm_legacy(xreg, __f64_mul(a[127..64], src_xmm[127..64]) @ __f64_mul(a[63..0], src_xmm[63..0]))
            },
            MP_F3 => {
              var xmm : xmmword = read_xmm(xreg);
              xmm[31..0] = __f32_mul(xmm[31..0], src_xmm[31..0]);
              write_xmm_legacy(xreg, xmm)
            },
            MP_F2 => {
              var xmm : xmmword = read_xmm(xreg);
              xmm[63..0] = __f64_mul(xmm[63..0], src_xmm[63..0]);
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
              let r : xmmword = __f32_sub(a[127..96], src_xmm[127..96]) @
              __f32_sub(a[95..64], src_xmm[95..64]) @
              __f32_sub(a[63..32], src_xmm[63..32]) @
              __f32_sub(a[31..0], src_xmm[31..0]);
              write_xmm_legacy(xreg, r)
            },
            MP_66 => {
              let a : xmmword = read_xmm(xreg);
              write_xmm_legacy(xreg, __f64_sub(a[127..64], src_xmm[127..64]) @ __f64_sub(a[63..0], src_xmm[63..0]))
            },
            MP_F3 => {
              var xmm : xmmword = read_xmm(xreg);
              xmm[31..0] = __f32_sub(xmm[31..0], src_xmm[31..0]);
              write_xmm_legacy(xreg, xmm)
            },
            MP_F2 => {
              var xmm : xmmword = read_xmm(xreg);
              xmm[63..0] = __f64_sub(xmm[63..0], src_xmm[63..0]);
              write_xmm_legacy(xreg, xmm)
            },
          }
        },
        // 0F 5D: MIN
        13 => {
          match mp {
            MP_NONE => {
              let a : xmmword = read_xmm(xreg);
              let r : xmmword = __f32_min(a[127..96], src_xmm[127..96]) @
              __f32_min(a[95..64], src_xmm[95..64]) @
              __f32_min(a[63..32], src_xmm[63..32]) @
              __f32_min(a[31..0], src_xmm[31..0]);
              write_xmm_legacy(xreg, r)
            },
            MP_66 => {
              let a : xmmword = read_xmm(xreg);
              write_xmm_legacy(xreg, __f64_min(a[127..64], src_xmm[127..64]) @ __f64_min(a[63..0], src_xmm[63..0]))
            },
            MP_F3 => {
              var xmm : xmmword = read_xmm(xreg);
              xmm[31..0] = __f32_min(xmm[31..0], src_xmm[31..0]);
              write_xmm_legacy(xreg, xmm)
            },
            MP_F2 => {
              var xmm : xmmword = read_xmm(xreg);
              xmm[63..0] = __f64_min(xmm[63..0], src_xmm[63..0]);
              write_xmm_legacy(xreg, xmm)
            },
          }
        },
        // 0F 5E: DIV
        14 => {
          match mp {
            MP_NONE => {
              let a : xmmword = read_xmm(xreg);
              let r : xmmword = __f32_div(a[127..96], src_xmm[127..96]) @
              __f32_div(a[95..64], src_xmm[95..64]) @
              __f32_div(a[63..32], src_xmm[63..32]) @
              __f32_div(a[31..0], src_xmm[31..0]);
              write_xmm_legacy(xreg, r)
            },
            MP_66 => {
              let a : xmmword = read_xmm(xreg);
              write_xmm_legacy(xreg, __f64_div(a[127..64], src_xmm[127..64]) @ __f64_div(a[63..0], src_xmm[63..0]))
            },
            MP_F3 => {
              var xmm : xmmword = read_xmm(xreg);
              xmm[31..0] = __f32_div(xmm[31..0], src_xmm[31..0]);
              write_xmm_legacy(xreg, xmm)
            },
            MP_F2 => {
              var xmm : xmmword = read_xmm(xreg);
              xmm[63..0] = __f64_div(xmm[63..0], src_xmm[63..0]);
              write_xmm_legacy(xreg, xmm)
            },
          }
        },
        // 0F 5F: MAX
        15 => {
          match mp {
            MP_NONE => {
              let a : xmmword = read_xmm(xreg);
              let r : xmmword = __f32_max(a[127..96], src_xmm[127..96]) @
              __f32_max(a[95..64], src_xmm[95..64]) @
              __f32_max(a[63..32], src_xmm[63..32]) @
              __f32_max(a[31..0], src_xmm[31..0]);
              write_xmm_legacy(xreg, r)
            },
            MP_66 => {
              let a : xmmword = read_xmm(xreg);
              write_xmm_legacy(xreg, __f64_max(a[127..64], src_xmm[127..64]) @ __f64_max(a[63..0], src_xmm[63..0]))
            },
            MP_F3 => {
              var xmm : xmmword = read_xmm(xreg);
              xmm[31..0] = __f32_max(xmm[31..0], src_xmm[31..0]);
              write_xmm_legacy(xreg, xmm)
            },
            MP_F2 => {
              var xmm : xmmword = read_xmm(xreg);
              xmm[63..0] = __f64_max(xmm[63..0], src_xmm[63..0]);
              write_xmm_legacy(xreg, xmm)
            },
          }
        },
        // 0F 52: RSQRTPS/RSQRTSS
        2 => {
          match mp {
            MP_NONE => {
              var xmm : xmmword = zeros();
              xmm[31..0]   = __f32_rsqrt(src_xmm[31..0]);
              xmm[63..32]  = __f32_rsqrt(src_xmm[63..32]);
              xmm[95..64]  = __f32_rsqrt(src_xmm[95..64]);
              xmm[127..96] = __f32_rsqrt(src_xmm[127..96]);
              write_xmm_legacy(xreg, xmm)
            },
            MP_F3 => {
              var xmm : xmmword = read_xmm(xreg);
              xmm[31..0] = __f32_rsqrt(src_xmm[31..0]);
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
              xmm[31..0]   = __f32_rcp(src_xmm[31..0]);
              xmm[63..32]  = __f32_rcp(src_xmm[63..32]);
              xmm[95..64]  = __f32_rcp(src_xmm[95..64]);
              xmm[127..96] = __f32_rcp(src_xmm[127..96]);
              write_xmm_legacy(xreg, xmm)
            },
            MP_F3 => {
              var xmm : xmmword = read_xmm(xreg);
              xmm[31..0] = __f32_rcp(src_xmm[31..0]);
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
      let modrm = fetch_byte();
      let xreg = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src_xmm : xmmword = match rm {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
        RM_mem(addr) => mem_read128(addr),
      };
      let imm = fetch_byte();
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
          let low : qword = blend64(d[63..0], d[127..64], imm[0..0]);
          let high : qword = blend64(src_xmm[63..0], src_xmm[127..64], imm[1..1]);
          write_xmm_legacy(xreg, high @ low)
        },
        _       => raise_UD(),
      }
    },
    // 0F D6: MOVQ xmm/m64, xmm (66 prefix)
    214 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then raise_UD();
      let modrm = fetch_byte();
      let xreg = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = read_xmm(xreg);
      match rm {
        RM_reg(_) => {
          let dst_xmm = modrm_xmm_rm(modrm, pfx);
          write_xmm(dst_xmm, zero_extend(v[63..0]))
        },
        RM_mem(addr) => {
          mem_write64(addr, v[63..0])
        },
      }
    },
    // 0F E6: CVTDQ2PD/CVTPD2DQ/CVTTPD2DQ
    230 => {
      let mp = get_mandatory_prefix(pfx);
      let modrm = fetch_byte();
      let xreg = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src_xmm : xmmword = match rm {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
        RM_mem(addr) => mem_read128(addr),
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
      let modrm = fetch_byte();
      let xreg = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      match rm {
        RM_mem(addr) => {
          match mp {
            MP_NONE => {
              mem_write128(addr, read_xmm(xreg))
            },
            MP_66 => {
              mem_write128(addr, read_xmm(xreg))
            },
            _       => raise_UD(),
          }
        },
        RM_reg(_) => raise_UD(),
      }
    },
    // 0F 7C: HADDPS/HADDPD
    124 => {
      let mp = get_mandatory_prefix(pfx);
      let modrm = fetch_byte();
      let xreg = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src_xmm : xmmword = decode_xmm_src(modrm, rm, pfx);
      match mp {
        MP_F2 => {
          let a : xmmword = read_xmm(xreg);
          let d0 : dword = __f32_add(a[31..0], a[63..32]);
          let d1 : dword = __f32_add(a[95..64], a[127..96]);
          let d2 : dword = __f32_add(src_xmm[31..0], src_xmm[63..32]);
          let d3 : dword = __f32_add(src_xmm[95..64], src_xmm[127..96]);
          write_xmm_legacy(xreg, d3 @ d2 @ d1 @ d0)
        },
        MP_66 => {
          let a : xmmword = read_xmm(xreg);
          let lo : qword = __f64_add(a[63..0], a[127..64]);
          let hi : qword = __f64_add(src_xmm[63..0], src_xmm[127..64]);
          write_xmm_legacy(xreg, hi @ lo)
        },
        _       => raise_UD(),
      }
    },
    // 0F 7D: HSUBPS/HSUBPD
    125 => {
      let mp = get_mandatory_prefix(pfx);
      let modrm = fetch_byte();
      let xreg = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src_xmm : xmmword = decode_xmm_src(modrm, rm, pfx);
      match mp {
        MP_F2 => {
          let a : xmmword = read_xmm(xreg);
          let d0 : dword = __f32_sub(a[31..0], a[63..32]);
          let d1 : dword = __f32_sub(a[95..64], a[127..96]);
          let d2 : dword = __f32_sub(src_xmm[31..0], src_xmm[63..32]);
          let d3 : dword = __f32_sub(src_xmm[95..64], src_xmm[127..96]);
          write_xmm_legacy(xreg, d3 @ d2 @ d1 @ d0)
        },
        MP_66 => {
          let a : xmmword = read_xmm(xreg);
          let lo : qword = __f64_sub(a[63..0], a[127..64]);
          let hi : qword = __f64_sub(src_xmm[63..0], src_xmm[127..64]);
          write_xmm_legacy(xreg, hi @ lo)
        },
        _       => raise_UD(),
      }
    },
    // 0F C2: CMPPS/CMPPD/CMPSS/CMPSD xmm, xmm/m, imm8
    194 => {
      let mp = get_mandatory_prefix(pfx);
      let modrm = fetch_byte();
      let xreg = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src_xmm : xmmword = match rm {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
        RM_mem(addr) => match mp {
          MP_F3 => zero_extend(mem_read32(addr)),
          MP_F2 => zero_extend(mem_read64(addr)),
          _     => mem_read128(addr),
        },
      };
      let imm = fetch_byte();
      match mp {
        MP_NONE => {
          let a : xmmword = read_xmm(xreg);
          let pred : bits(3) = imm[2..0];
          let r : xmmword =
          cmp_pred_f32(a[127..96], src_xmm[127..96], pred) @
          cmp_pred_f32(a[95..64], src_xmm[95..64], pred) @
          cmp_pred_f32(a[63..32], src_xmm[63..32], pred) @
          cmp_pred_f32(a[31..0], src_xmm[31..0], pred);
          write_xmm_legacy(xreg, r)
        },
        MP_66 => {
          let a : xmmword = read_xmm(xreg);
          let pred : bits(3) = imm[2..0];
          let r : xmmword =
          cmp_pred_f64(a[127..64], src_xmm[127..64], pred) @
          cmp_pred_f64(a[63..0], src_xmm[63..0], pred);
          write_xmm_legacy(xreg, r)
        },
        MP_F3 => {
          let a : xmmword = read_xmm(xreg);
          let pred : bits(3) = imm[2..0];
          let low : dword = cmp_pred_f32(a[31..0], src_xmm[31..0], pred);
          let r : xmmword = a[127..32] @ low;
          write_xmm_legacy(xreg, r)
        },
        MP_F2 => {
          let a : xmmword = read_xmm(xreg);
          let pred : bits(3) = imm[2..0];
          let low : qword = cmp_pred_f64(a[63..0], src_xmm[63..0], pred);
          let r : xmmword = a[127..64] @ low;
          write_xmm_legacy(xreg, r)
        },
      }
    },
    // 0F D0: ADDSUBPS/ADDSUBPD
    208 => {
      let mp = get_mandatory_prefix(pfx);
      let modrm = fetch_byte();
      let xreg = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src_xmm : xmmword = decode_xmm_src(modrm, rm, pfx);
      match mp {
        MP_F2 => {
          let a : xmmword = read_xmm(xreg);
          let d0 : dword = __f32_sub(a[31..0], src_xmm[31..0]);
          let d1 : dword = __f32_add(a[63..32], src_xmm[63..32]);
          let d2 : dword = __f32_sub(a[95..64], src_xmm[95..64]);
          let d3 : dword = __f32_add(a[127..96], src_xmm[127..96]);
          write_xmm_legacy(xreg, d3 @ d2 @ d1 @ d0)
        },
        MP_66 => {
          let a : xmmword = read_xmm(xreg);
          let lo : qword = __f64_sub(a[63..0], src_xmm[63..0]);
          let hi : qword = __f64_add(a[127..64], src_xmm[127..64]);
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
  let sel : range(0, 1) = unsigned(imm8[0..0]);
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
  let dst_sel : range(0, 3) = unsigned(imm8[5..4]);
  let t0 : dword = if dst_sel == 0 then src_float else a[31..0];
  let t1 : dword = if dst_sel == 1 then src_float else a[63..32];
  let t2 : dword = if dst_sel == 2 then src_float else a[95..64];
  let t3 : dword = if dst_sel == 3 then src_float else a[127..96];
  // Zero lanes indicated by imm8[3:0] (branchless)
  write_xmm_legacy(dst,
    (t3 & sign_extend(~(imm8[3..3]))) @
    (t2 & sign_extend(~(imm8[2..2]))) @
    (t1 & sign_extend(~(imm8[1..1]))) @
    (t0 & sign_extend(~(imm8[0..0]))))
}

// =========================================================================
// 3-Byte Opcode Map: SSE Floating-Point Operations
// =========================================================================

val __f64_round : (qword, byte) -> qword
val __f32_round : (dword, byte) -> dword

// 0F 38 xx — SSE FP operations (BLENDVPS, BLENDVPD)
val dispatch_3byte_38_sse_fp : (byte, Prefixes) -> unit
function dispatch_3byte_38_sse_fp(opcode, pfx) = {
  let op : range(0, 255) = unsigned(opcode);
  let mp = get_mandatory_prefix(pfx);
  if mp != MP_66 then raise_UD();
  let modrm = fetch_byte();
  let xreg = modrm_xmm_reg(modrm, pfx);
  let rm = decode_rm(modrm, pfx);
  let src_xmm : xmmword = decode_xmm_src(modrm, rm, pfx);
  match op {
    // BLENDVPS xmm1, xmm2/m128, <XMM0>
    20 => {
      let a : xmmword = read_xmm(xreg);
      let m : xmmword = read_xmm(0);
      let d0 : dword = blend32(a[31..0], src_xmm[31..0], m[31..31]);
      let d1 : dword = blend32(a[63..32], src_xmm[63..32], m[63..63]);
      let d2 : dword = blend32(a[95..64], src_xmm[95..64], m[95..95]);
      let d3 : dword = blend32(a[127..96], src_xmm[127..96], m[127..127]);
      write_xmm_legacy(xreg, d3 @ d2 @ d1 @ d0)
    },
    // BLENDVPD xmm1, xmm2/m128, <XMM0>
    21 => {
      let a : xmmword = read_xmm(xreg);
      let m : xmmword = read_xmm(0);
      let lo : qword = blend64(a[63..0], src_xmm[63..0], m[63..63]);
      let hi : qword = blend64(a[127..64], src_xmm[127..64], m[127..127]);
      write_xmm_legacy(xreg, hi @ lo)
    },
    _ => raise_UD(),
  }
}

// 0F 3A xx — SSE FP operations (ROUND*, BLEND*, DP*, EXTRACTPS, INSERTPS)
val dispatch_3byte_3a_sse_fp : (byte, Prefixes) -> unit
function dispatch_3byte_3a_sse_fp(opcode, pfx) = {
  let op : range(0, 255) = unsigned(opcode);
  let mp = get_mandatory_prefix(pfx);
  if mp != MP_66 then raise_UD();
  let modrm = fetch_byte();
  let xreg = modrm_xmm_reg(modrm, pfx);
  let rm = decode_rm(modrm, pfx);
  match op {
    // SSE4.1 — round
    8 => {
      let src_xmm = decode_xmm_src(modrm, rm, pfx);
      let imm = fetch_byte();
      let d0 : dword = __f32_round(src_xmm[31..0], imm);
      let d1 : dword = __f32_round(src_xmm[63..32], imm);
      let d2 : dword = __f32_round(src_xmm[95..64], imm);
      let d3 : dword = __f32_round(src_xmm[127..96], imm);
      write_xmm_legacy(xreg, d3 @ d2 @ d1 @ d0)
    },
    9 => {
      let src_xmm = decode_xmm_src(modrm, rm, pfx);
      let imm = fetch_byte();
      let lo : qword = __f64_round(src_xmm[63..0], imm);
      let hi : qword = __f64_round(src_xmm[127..64], imm);
      write_xmm_legacy(xreg, hi @ lo)
    },
    10 => {
      let src_xmm = decode_xmm_src(modrm, rm, pfx);
      let imm = fetch_byte();
      let a : xmmword = read_xmm(xreg);
      let lo : dword = __f32_round(src_xmm[31..0], imm);
      write_xmm_legacy(xreg, a[127..32] @ lo)
    },
    11 => {
      let src_xmm = decode_xmm_src(modrm, rm, pfx);
      let imm = fetch_byte();
      let a : xmmword = read_xmm(xreg);
      let lo : qword = __f64_round(src_xmm[63..0], imm);
      write_xmm_legacy(xreg, a[127..64] @ lo)
    },

    // SSE4.1 — blend
    12 => {
      let src_xmm = decode_xmm_src(modrm, rm, pfx);
      let imm = fetch_byte();
      let a : xmmword = read_xmm(xreg);
      write_xmm_legacy(xreg,
        blend32(a[127..96], src_xmm[127..96], imm[3..3]) @
        blend32(a[95..64],  src_xmm[95..64],  imm[2..2]) @
        blend32(a[63..32],  src_xmm[63..32],  imm[1..1]) @
        blend32(a[31..0],   src_xmm[31..0],   imm[0..0]))
    },
    13 => {
      let src_xmm = decode_xmm_src(modrm, rm, pfx);
      let imm = fetch_byte();
      let a : xmmword = read_xmm(xreg);
      write_xmm_legacy(xreg,
        blend64(a[127..64], src_xmm[127..64], imm[1..1]) @
        blend64(a[63..0],   src_xmm[63..0],   imm[0..0]))
    },

    // EXTRACTPS r/m32, xmm, imm8
    23 => {
      let imm = fetch_byte();
      let v = extract_dword_from_xmm(read_xmm(xreg), imm);
      match rm {
        RM_reg(_) => {
          let dst_reg = modrm_rm_reg(modrm, pfx);
          write_gpr32(dst_reg, v);
        },
        RM_mem(addr) => mem_write32(fixup_addr(addr), v),
      }
    },

    // INSERTPS xmm, xmm/m32, imm8
    33 => {
      let src_xmm = decode_xmm_src(modrm, rm, pfx);
      let imm = fetch_byte();
      exec_insertps(xreg, src_xmm, imm)
    },

    // SSE4.1 — dot product
    64 => {
      let src_xmm = decode_xmm_src(modrm, rm, pfx);
      let imm = fetch_byte();
      let a : xmmword = read_xmm(xreg);
      let zero : dword = 0x00000000;
      let temp0 : dword = if imm[4] == bitone then __f32_mul(a[31..0], src_xmm[31..0]) else zero;
      let temp1 : dword = if imm[5] == bitone then __f32_mul(a[63..32], src_xmm[63..32]) else zero;
      let temp2 : dword = if imm[6] == bitone then __f32_mul(a[95..64], src_xmm[95..64]) else zero;
      let temp3 : dword = if imm[7] == bitone then __f32_mul(a[127..96], src_xmm[127..96]) else zero;
      let sum01 : dword = __f32_add(temp0, temp1);
      let sum23 : dword = __f32_add(temp2, temp3);
      let sum : dword = __f32_add(sum01, sum23);
      write_xmm_legacy(xreg,
        (sum & sign_extend(imm[3..3])) @
        (sum & sign_extend(imm[2..2])) @
        (sum & sign_extend(imm[1..1])) @
        (sum & sign_extend(imm[0..0])))
    },
    65 => {
      let src_xmm = decode_xmm_src(modrm, rm, pfx);
      let imm = fetch_byte();
      let a : xmmword = read_xmm(xreg);
      let zero : qword = 0x0000000000000000;
      let temp0 : qword = if imm[4] == bitone then __f64_mul(a[63..0], src_xmm[63..0]) else zero;
      let temp1 : qword = if imm[5] == bitone then __f64_mul(a[127..64], src_xmm[127..64]) else zero;
      let sum : qword = __f64_add(temp0, temp1);
      write_xmm_legacy(xreg,
        (sum & sign_extend(imm[1..1])) @
        (sum & sign_extend(imm[0..0])))
    },

    _ => raise_UD(),
  }
}

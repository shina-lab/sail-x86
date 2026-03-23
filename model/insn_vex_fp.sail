// x86-64 — VEX FP Instructions (0F map)
//
// Floating-point moves, arithmetic, compare, convert, shuffle, unpack.

// Forward declarations for conversion helpers (defined in insn_evex_fp.sail)
val avx_cvtdq2ps_256 : ymmword -> ymmword
val avx_cvtps2dq_256 : ymmword -> ymmword
val avx_cvttps2dq_256 : ymmword -> ymmword

val dispatch_vex_0f_fp : (range(0, 255), Prefixes) -> unit
function dispatch_vex_0f_fp(op, pfx) = {
  let mp = get_mandatory_prefix(pfx);

  match op {

  // 0F 10: VMOVUPS/VMOVUPD/VMOVSS/VMOVSD (load)
  16 => {
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    match mp {
      // VMOVUPS (vvvv reserved)
      MP_NONE => {
        if pfx.vex_vvvv != 0 then raise_UD();
        if pfx.vex_l then {
          write_ymm(dst, decode_vex_src_ymm(modrm, rm, pfx))
        } else {
          write_xmm(dst, decode_vex_src_xmm(modrm, rm, pfx))
        }
      },
      // VMOVUPD (vvvv reserved)
      MP_66 => {
        if pfx.vex_vvvv != 0 then raise_UD();
        if pfx.vex_l then {
          write_ymm(dst, decode_vex_src_ymm(modrm, rm, pfx))
        } else {
          write_xmm(dst, decode_vex_src_xmm(modrm, rm, pfx))
        }
      },
      // VMOVSS xmm1, xmm2, xmm3 or xmm1, m32
      // Memory form: VEX.vvvv must be 1111b.
      MP_F3 => {
        match rm {
          RM_reg(_) => {
            // reg-reg: merge src2[127:32] with src3[31:0]
            let src2 : xmmword = read_xmm(pfx.vex_vvvv);
            let src3 : xmmword = read_xmm(modrm_xmm_rm(modrm, pfx));
            write_xmm(dst, src2[127..32] @ src3[31..0])
          },
          RM_mem(seg, addr) => {
            if pfx.vex_vvvv != 0 then raise_UD();
            let v : dword = seg_read32(seg, addr);
            write_xmm(dst, zeros(96) @ v)
          },
        }
      },
      // VMOVSD xmm1, xmm2, xmm3 or xmm1, m64
      // Memory form: VEX.vvvv must be 1111b.
      MP_F2 => {
        match rm {
          RM_reg(_) => {
            let src2 : xmmword = read_xmm(pfx.vex_vvvv);
            let src3 : xmmword = read_xmm(modrm_xmm_rm(modrm, pfx));
            write_xmm(dst, src2[127..64] @ src3[63..0])
          },
          RM_mem(seg, addr) => {
            if pfx.vex_vvvv != 0 then raise_UD();
            let v : qword = seg_read64(seg, addr);
            write_xmm(dst, zeros(64) @ v)
          },
        }
      },
    }
  },

  // 0F 11: VMOVUPS/VMOVUPD/VMOVSS/VMOVSD (store)
  17 => {
    let modrm = fetch_byte();
    let src = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    match mp {
      // VMOVUPS (vvvv reserved)
      MP_NONE => {
        if pfx.vex_vvvv != 0 then raise_UD();
        match rm {
          RM_reg(_) => {
            let dst = modrm_xmm_rm(modrm, pfx);
            if pfx.vex_l then {
              write_ymm(dst, read_ymm(src))
            } else {
              write_xmm(dst, read_xmm(src))
            }
          },
          RM_mem(seg, addr) => {
            if pfx.vex_l then {
              seg_write256(seg, addr, read_ymm(src))
            } else {
              seg_write128(seg, addr, read_xmm(src))
            }
          },
        }
      },
      // VMOVUPD (vvvv reserved)
      MP_66 => {
        if pfx.vex_vvvv != 0 then raise_UD();
        match rm {
          RM_reg(_) => {
            let dst = modrm_xmm_rm(modrm, pfx);
            if pfx.vex_l then {
              write_ymm(dst, read_ymm(src))
            } else {
              write_xmm(dst, read_xmm(src))
            }
          },
          RM_mem(seg, addr) => {
            if pfx.vex_l then {
              seg_write256(seg, addr, read_ymm(src))
            } else {
              seg_write128(seg, addr, read_xmm(src))
            }
          },
        }
      },
      // VMOVSS xmm1, xmm2, xmm3 or VMOVSS m32, xmm1
      // Memory form: VEX.vvvv must be 1111b.
      MP_F3 => {
        match rm {
          RM_reg(_) => {
            let dst = modrm_xmm_rm(modrm, pfx);
            let src2 : xmmword = read_xmm(pfx.vex_vvvv);
            let src3 : xmmword = read_xmm(src);
            write_xmm(dst, src2[127..32] @ src3[31..0])
          },
          RM_mem(seg, addr) => {
            if pfx.vex_vvvv != 0 then raise_UD();
            seg_write32(seg, addr, read_xmm(src)[31..0])
          },
        }
      },
      // VMOVSD xmm1, xmm2, xmm3 or VMOVSD m64, xmm1
      // Memory form: VEX.vvvv must be 1111b.
      MP_F2 => {
        match rm {
          RM_reg(_) => {
            let dst = modrm_xmm_rm(modrm, pfx);
            let src2 : xmmword = read_xmm(pfx.vex_vvvv);
            let src3 : xmmword = read_xmm(src);
            write_xmm(dst, src2[127..64] @ src3[63..0])
          },
          RM_mem(seg, addr) => {
            if pfx.vex_vvvv != 0 then raise_UD();
            seg_write64(seg, addr, read_xmm(src)[63..0])
          },
        }
      },
    }
  },

  // 0F 12: VMOVLPS/VMOVHLPS (NP) / VMOVLPD (66) / VMOVSLDUP (F3) / VMOVDDUP (F2)
  18 => {
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    match mp {
      MP_NONE => {
        match rm {
          // VMOVHLPS: dst[63:0] = src2[127:64], dst[127:64] = vvvv[127:64]
          RM_reg(_) => {
            let src1 : xmmword = read_xmm(pfx.vex_vvvv);
            let src2 : xmmword = read_xmm(modrm_xmm_rm(modrm, pfx));
            write_xmm(dst, src1[127..64] @ src2[127..64])
          },
          // VMOVLPS: dst[63:0] = m64, dst[127:64] = vvvv[127:64]
          RM_mem(seg, addr) => {
            let src1 : xmmword = read_xmm(pfx.vex_vvvv);
            let v : qword = seg_read64(seg, addr);
            write_xmm(dst, src1[127..64] @ v)
          },
        }
      },
      // VMOVLPD xmm1, xmm2, m64: DEST[63:0] := SRC2[63:0]; DEST[127:64] := SRC1[127:64]
      MP_66 => {
        match rm {
          RM_mem(seg, addr) => {
            let src1 : xmmword = read_xmm(pfx.vex_vvvv);
            let v : qword = seg_read64(seg, addr);
            write_xmm(dst, src1[127..64] @ v)
          },
          _ => raise_UD(),
        }
      },
      // VMOVSLDUP xmm1, xmm2/m128: duplicate even-indexed floats
      // SDM: DEST = [SRC[95:64], SRC[95:64], SRC[31:0], SRC[31:0]]
      MP_F3 => {
        if pfx.vex_vvvv != 0 then raise_UD();
        if pfx.vex_l then {
          let src : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
          write_ymm(dst, src[223..192] @ src[223..192] @
                         src[159..128] @ src[159..128] @
                         src[95..64] @ src[95..64] @
                         src[31..0] @ src[31..0])
        } else {
          let src : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
          write_xmm(dst, src[95..64] @ src[95..64] @
                         src[31..0] @ src[31..0])
        }
      },
      // VMOVDDUP xmm1, xmm2/m64: duplicate low qword
      // SDM 128: DEST[63:0] := SRC[63:0]; DEST[127:64] := SRC[63:0]
      // SDM 256: DEST[63:0] := SRC[63:0]; DEST[127:64] := SRC[63:0];
      //          DEST[191:128] := SRC[191:128]; DEST[255:192] := SRC[191:128]
      MP_F2 => {
        if pfx.vex_vvvv != 0 then raise_UD();
        if pfx.vex_l then {
          let src : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
          write_ymm(dst, src[191..128] @ src[191..128] @
                         src[63..0] @ src[63..0])
        } else {
          let src : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
          write_xmm(dst, src[63..0] @ src[63..0])
        }
      },
    }
  },

  // 0F 13: VMOVLPS/VMOVLPD m64, xmm (store low 64 bits to memory)
  19 => {
    if pfx.vex_l | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch_byte();
    let src = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    match rm {
      RM_mem(seg, addr) => seg_write64(seg, addr, read_xmm(src)[63..0]),
      RM_reg(_) => raise_UD(),
    }
  },

  // 0F 14: VUNPCKLPS (NP) / VUNPCKLPD (66)
  20 => {
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let src1 : ymmword = read_ymm(pfx.vex_vvvv);
      let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      match mp {
        // VUNPCKLPS ymm1, ymm2, ymm3/m256
        MP_NONE => {
          let lo = src2[63..32] @ src1[63..32] @ src2[31..0] @ src1[31..0];
          let hi = src2[191..160] @ src1[191..160] @ src2[159..128] @ src1[159..128];
          write_ymm(dst, hi @ lo)
        },
        // VUNPCKLPD ymm1, ymm2, ymm3/m256
        MP_66 => {
          let lo = src2[63..0] @ src1[63..0];
          let hi = src2[191..128] @ src1[191..128];
          write_ymm(dst, hi @ lo)
        },
        _ => raise_UD(),
      }
    } else {
      let src1 : xmmword = read_xmm(pfx.vex_vvvv);
      let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
      match mp {
        MP_NONE => write_xmm(dst, src2[63..32] @ src1[63..32] @ src2[31..0] @ src1[31..0]),
        MP_66   => write_xmm(dst, src2[63..0] @ src1[63..0]),
        _ => raise_UD(),
      }
    }
  },

  // 0F 15: VUNPCKHPS (NP) / VUNPCKHPD (66)
  21 => {
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let src1 : ymmword = read_ymm(pfx.vex_vvvv);
      let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      match mp {
        // VUNPCKHPS ymm1, ymm2, ymm3/m256
        MP_NONE => {
          let lo = src2[127..96] @ src1[127..96] @ src2[95..64] @ src1[95..64];
          let hi = src2[255..224] @ src1[255..224] @ src2[223..192] @ src1[223..192];
          write_ymm(dst, hi @ lo)
        },
        // VUNPCKHPD ymm1, ymm2, ymm3/m256
        MP_66 => {
          let lo = src2[127..64] @ src1[127..64];
          let hi = src2[255..192] @ src1[255..192];
          write_ymm(dst, hi @ lo)
        },
        _ => raise_UD(),
      }
    } else {
      let src1 : xmmword = read_xmm(pfx.vex_vvvv);
      let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
      match mp {
        MP_NONE => write_xmm(dst, src2[127..96] @ src1[127..96] @ src2[95..64] @ src1[95..64]),
        MP_66   => write_xmm(dst, src2[127..64] @ src1[127..64]),
        _ => raise_UD(),
      }
    }
  },

  // 0F 16: VMOVHPS/VMOVLHPS (NP) / VMOVHPD (66) / VMOVSHDUP (F3)
  22 => {
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    match mp {
      MP_NONE => {
        match rm {
          // VMOVLHPS: dst[127:64] = src2[63:0], dst[63:0] = vvvv[63:0]
          RM_reg(_) => {
            let src1 : xmmword = read_xmm(pfx.vex_vvvv);
            let src2 : xmmword = read_xmm(modrm_xmm_rm(modrm, pfx));
            write_xmm(dst, src2[63..0] @ src1[63..0])
          },
          // VMOVHPS: dst[63:0] = vvvv[63:0], dst[127:64] = m64
          RM_mem(seg, addr) => {
            let src1 : xmmword = read_xmm(pfx.vex_vvvv);
            let v : qword = seg_read64(seg, addr);
            write_xmm(dst, v @ src1[63..0])
          },
        }
      },
      // VMOVHPD xmm1, xmm2, m64: DEST[63:0] := SRC1[63:0]; DEST[127:64] := SRC2[63:0]
      MP_66 => {
        match rm {
          RM_mem(seg, addr) => {
            let src1 : xmmword = read_xmm(pfx.vex_vvvv);
            let v : qword = seg_read64(seg, addr);
            write_xmm(dst, v @ src1[63..0])
          },
          _ => raise_UD(),
        }
      },
      MP_F2 => raise_UD(),
      // VMOVSHDUP xmm1, xmm2/m128: duplicate odd-indexed floats
      // SDM: DEST = [SRC[127:96], SRC[127:96], SRC[63:32], SRC[63:32]]
      MP_F3 => {
        if pfx.vex_vvvv != 0 then raise_UD();
        if pfx.vex_l then {
          let src : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
          write_ymm(dst, src[255..224] @ src[255..224] @
                         src[191..160] @ src[191..160] @
                         src[127..96] @ src[127..96] @
                         src[63..32] @ src[63..32])
        } else {
          let src : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
          write_xmm(dst, src[127..96] @ src[127..96] @
                         src[63..32] @ src[63..32])
        }
      },
    }
  },

  // 0F 17: VMOVHPS/VMOVHPD m64, xmm (store high 64 bits to memory)
  23 => {
    if pfx.vex_l | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch_byte();
    let src = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    match rm {
      RM_mem(seg, addr) => seg_write64(seg, addr, read_xmm(src)[127..64]),
      RM_reg(_) => raise_UD(),
    }
  },

  // 0F 28: VMOVAPS/VMOVAPD (load)
  // SDM: VEX.vvvv must be 1111b
  40 => {
    if pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    match rm {
      RM_reg(_) => {
        if pfx.vex_l then {
          write_ymm(dst, read_ymm(modrm_xmm_rm(modrm, pfx)));
        } else {
          write_xmm(dst, read_xmm(modrm_xmm_rm(modrm, pfx)));
        }
      },
      RM_mem(seg, addr) => {
        // VMOVAPS/VMOVAPD require alignment: 32 for YMM, 16 for XMM; #GP(0) if unaligned
        if pfx.vex_l then {
          let a = seg_linear(seg, addr, 32);
          if unsigned(a) % 32 != 0 then raise_GP0();
          write_ymm(dst, mem_read256(a))
        } else {
          let a = seg_linear(seg, addr, 16);
          if unsigned(a) % 16 != 0 then raise_GP0();
          write_xmm(dst, mem_read128(a))
        }
      },
    }
  },

  // 0F 29: VMOVAPS/VMOVAPD (store)
  // SDM: VEX.vvvv must be 1111b
  41 => {
    if pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch_byte();
    let src = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    match rm {
      RM_reg(_) => {
        let dst = modrm_xmm_rm(modrm, pfx);
        if pfx.vex_l then {
          write_ymm(dst, read_ymm(src))
        } else {
          write_xmm(dst, read_xmm(src))
        }
      },
      RM_mem(seg, addr) => {
        // VMOVAPS/VMOVAPD require alignment: 32 for YMM, 16 for XMM; #GP(0) if unaligned
        if pfx.vex_l then {
          let a = seg_linear(seg, addr, 32);
          if unsigned(a) % 32 != 0 then raise_GP0();
          mem_write256(a, read_ymm(src))
        } else {
          let a = seg_linear(seg, addr, 16);
          if unsigned(a) % 16 != 0 then raise_GP0();
          mem_write128(a, read_xmm(src))
        }
      },
    }
  },

  // 0F 2A: VCVTSI2SS (F3) / VCVTSI2SD (F2) — int to scalar float
  42 => {
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let src1 : xmmword = read_xmm(pfx.vex_vvvv);
    match mp {
      // VCVTSI2SS xmm1, xmm2, r/m32
      MP_F3 => {
        if pfx.vex_w then {
          let v : qword = match rm { RM_reg(idx) => read_gpr64(idx), RM_mem(seg, addr) => seg_read64(seg, addr) };
          write_xmm(dst, src1[127..32] @ __int64_to_f32(v));
        } else {
          let v : dword = match rm { RM_reg(idx) => read_gpr32(idx), RM_mem(seg, addr) => seg_read32(seg, addr) };
          write_xmm(dst, src1[127..32] @ __int32_to_f32(v));
        }
      },
      // VCVTSI2SD xmm1, xmm2, r/m32
      MP_F2 => {
        if pfx.vex_w then {
          let v : qword = match rm { RM_reg(idx) => read_gpr64(idx), RM_mem(seg, addr) => seg_read64(seg, addr) };
          write_xmm(dst, src1[127..64] @ __int64_to_f64(v));
        } else {
          let v : dword = match rm { RM_reg(idx) => read_gpr32(idx), RM_mem(seg, addr) => seg_read32(seg, addr) };
          write_xmm(dst, src1[127..64] @ __int32_to_f64(v));
        }
      },
      _ => raise_UD(),
    }
  },

  // 0F 2B: VMOVNTPS/VMOVNTPD m, xmm/ymm (non-temporal store; we treat as regular store)
  // SDM: requires alignment (32 for YMM, 16 for XMM); #GP(0) if unaligned.
  43 => {
    if pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch_byte();
    let src = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    match rm {
      RM_mem(seg, addr) => {
        if pfx.vex_l then {
          let a = seg_linear(seg, addr, 32);
          if unsigned(a) % 32 != 0 then raise_GP0();
          let v : ymmword = read_ymm(src);
          mem_write128(a, v[127..0]);
          mem_write128(a + 16, v[255..128])
        } else {
          let a = seg_linear(seg, addr, 16);
          if unsigned(a) % 16 != 0 then raise_GP0();
          mem_write128(a, read_xmm(src))
        }
      },
      RM_reg(_) => raise_UD(),
    }
  },

  // 0F 2C: VCVTTSS2SI (F3) / VCVTTSD2SI (F2) — truncating scalar float to int
  44 => {
    let modrm = fetch_byte();
    let rm = decode_rm(modrm, pfx);
    let dst_gpr = modrm_reg(modrm, pfx);
    match mp {
      // VCVTTSS2SI r32/r64, xmm1/m32
      MP_F3 => {
        let src : dword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[31..0],
          RM_mem(seg, addr) => seg_read32(seg, addr),
        };
        if pfx.vex_w then write_gpr64(dst_gpr, __f32_to_int64_trunc(src))
        else write_gpr32(dst_gpr, __f32_to_int32_trunc(src))
      },
      // VCVTTSD2SI r32/r64, xmm1/m64
      MP_F2 => {
        let src : qword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[63..0],
          RM_mem(seg, addr) => seg_read64(seg, addr),
        };
        if pfx.vex_w then write_gpr64(dst_gpr, __f64_to_int64_trunc(src))
        else write_gpr32(dst_gpr, __f64_to_int32_trunc(src))
      },
      _ => raise_UD(),
    }
  },

  // 0F 2D: VCVTSS2SI (F3) / VCVTSD2SI (F2) — scalar FP to int with rounding
  45 => {
    let modrm = fetch_byte();
    let reg = modrm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    match mp {
      MP_F3 => {
        let src : dword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[31..0],
          RM_mem(seg, addr) => seg_read32(seg, addr),
        };
        if pfx.vex_w then
          write_gpr64(reg, __f32_to_int64(src))
        else
          write_gpr32(reg, __f32_to_int32(src))
      },
      MP_F2 => {
        let src : qword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[63..0],
          RM_mem(seg, addr) => seg_read64(seg, addr),
        };
        if pfx.vex_w then
          write_gpr64(reg, __f64_to_int64(src))
        else
          write_gpr32(reg, __f64_to_int32(src))
      },
      _ => raise_UD(),
    }
  },

  // 0F 2E: VUCOMISS (NP) / VUCOMISD (66) — unordered compare scalars, set EFLAGS
  // SDM: VEX.vvvv must be 1111b
  46 => {
    if pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch_byte();
    let src_reg = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    match mp {
      // VUCOMISS xmm1, xmm2/m32
      MP_NONE => {
        let src : xmmword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(seg, addr) => zero_extend(seg_read32(seg, addr)),
        };
        let a : dword = read_xmm(src_reg)[31..0];
        let b : dword = src[31..0];
        match __compare_ss(a, b) {
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
        let src : xmmword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(seg, addr) => zero_extend(seg_read64(seg, addr)),
        };
        let a : qword = read_xmm(src_reg)[63..0];
        let b : qword = src[63..0];
        match __compare_sd(a, b) {
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

  // 0F 2F: VCOMISS (NP) / VCOMISD (66) — ordered compare scalars, set EFLAGS
  // SDM: VEX.vvvv must be 1111b
  47 => {
    if pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch_byte();
    let src_reg = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    match mp {
      // VCOMISS xmm1, xmm2/m32
      MP_NONE => {
        let src : xmmword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(seg, addr) => zero_extend(seg_read32(seg, addr)),
        };
        let a : dword = read_xmm(src_reg)[31..0];
        let b : dword = src[31..0];
        match __compare_ss(a, b) {
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
        let src : xmmword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(seg, addr) => zero_extend(seg_read64(seg, addr)),
        };
        let a : qword = read_xmm(src_reg)[63..0];
        let b : qword = src[63..0];
        match __compare_sd(a, b) {
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

  // 0F 50: VMOVMSKPS (NP) / VMOVMSKPD (66) — extract sign bits to GPR
  80 => {
    let modrm = fetch_byte();
    let reg = modrm_reg(modrm, pfx);
    let _ = decode_rm(modrm, pfx);
    if pfx.vex_vvvv != 0 then raise_UD();
    match mp {
      MP_NONE => {
        if pfx.vex_l then {
          let src : ymmword = read_ymm(modrm_xmm_rm(modrm, pfx));
          let mask : byte = src[255] @ src[223] @ src[191] @ src[159] @
                            src[127] @ src[95] @ src[63] @ src[31];
          write_gpr32(reg, zero_extend(mask))
        } else {
          let src : xmmword = read_xmm(modrm_xmm_rm(modrm, pfx));
          let mask : bits(4) = src[127] @ src[95] @ src[63] @ src[31];
          write_gpr32(reg, zero_extend(mask))
        }
      },
      MP_66 => {
        if pfx.vex_l then {
          let src : ymmword = read_ymm(modrm_xmm_rm(modrm, pfx));
          let mask : bits(4) = src[255] @ src[191] @ src[127] @ src[63];
          write_gpr32(reg, zero_extend(mask))
        } else {
          let src : xmmword = read_xmm(modrm_xmm_rm(modrm, pfx));
          let mask : bits(2) = src[127] @ src[63];
          write_gpr32(reg, zero_extend(mask))
        }
      },
      _ => raise_UD(),
    }
  },

  // 0F 50-5F: Packed arithmetic (columns 1-15, column 0 handled above)
  // Common pattern: dst = vvvv OP src (3-operand)
  op if 81 <= op & op <= 95 => {
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let col : range(0, 15) = op - 80;

    if pfx.vex_l then {
      // 256-bit YMM path
      let src1 : ymmword = read_ymm(pfx.vex_vvvv);
      let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      match col {
        // VSQRTPS/VSQRTPD (unary, vvvv reserved)
        1 => {
          if pfx.vex_vvvv != 0 then raise_UD();
          match mp {
            MP_NONE => write_ymm(dst, vsqrtps_xmm(src2[255..128]) @ vsqrtps_xmm(src2[127..0])),
            MP_66   => write_ymm(dst, vsqrtpd_xmm(src2[255..128]) @ vsqrtpd_xmm(src2[127..0])),
            _ => raise_UD(),
          }
        },
        // VRSQRTPS (NP only, vvvv reserved, 256-bit)
        2 => {
          if pfx.vex_vvvv != 0 then raise_UD();
          match mp {
            MP_NONE => {
              let hi = __f32_rsqrt(src2[255..224]) @ __f32_rsqrt(src2[223..192]) @
                       __f32_rsqrt(src2[191..160]) @ __f32_rsqrt(src2[159..128]);
              let lo = __f32_rsqrt(src2[127..96]) @ __f32_rsqrt(src2[95..64]) @
                       __f32_rsqrt(src2[63..32])  @ __f32_rsqrt(src2[31..0]);
              write_ymm(dst, hi @ lo)
            },
            _ => raise_UD(),
          }
        },
        // VRCPPS (NP only, vvvv reserved, 256-bit)
        3 => {
          if pfx.vex_vvvv != 0 then raise_UD();
          match mp {
            MP_NONE => {
              let hi = __f32_rcp(src2[255..224]) @ __f32_rcp(src2[223..192]) @
                       __f32_rcp(src2[191..160]) @ __f32_rcp(src2[159..128]);
              let lo = __f32_rcp(src2[127..96]) @ __f32_rcp(src2[95..64]) @
                       __f32_rcp(src2[63..32])  @ __f32_rcp(src2[31..0]);
              write_ymm(dst, hi @ lo)
            },
            _ => raise_UD(),
          }
        },
        // VANDPS/VANDPD
        4 => write_ymm(dst, src1 & src2),
        // VANDNPS/VANDNPD
        5 => write_ymm(dst, ~(src1) & src2),
        // VORPS/VORPD
        6 => write_ymm(dst, src1 | src2),
        // VXORPS/VXORPD
        7 => write_ymm(dst, src1 ^ src2),
        // VADDPS/VADDPD
        8 => match mp {
          MP_NONE => write_ymm(dst, vaddps_xmm(src1[255..128], src2[255..128]) @ vaddps_xmm(src1[127..0], src2[127..0])),
          MP_66   => write_ymm(dst, vaddpd_xmm(src1[255..128], src2[255..128]) @ vaddpd_xmm(src1[127..0], src2[127..0])),
          _ => raise_UD(),
        },
        // VMULPS/VMULPD
        9 => match mp {
          MP_NONE => write_ymm(dst, vmulps_xmm(src1[255..128], src2[255..128]) @ vmulps_xmm(src1[127..0], src2[127..0])),
          MP_66   => write_ymm(dst, vmulpd_xmm(src1[255..128], src2[255..128]) @ vmulpd_xmm(src1[127..0], src2[127..0])),
          _ => raise_UD(),
        },
        // VCVTPS2PD/VCVTPD2PS (256-bit, vvvv reserved)
        10 => {
          if pfx.vex_vvvv != 0 then raise_UD();
          match mp {
            // VCVTPS2PD: 4 floats -> 4 doubles
            MP_NONE => {
              let r3 = __f32_to_f64(src2[127..96]);
              let r2 = __f32_to_f64(src2[95..64]);
              let r1 = __f32_to_f64(src2[63..32]);
              let r0 = __f32_to_f64(src2[31..0]);
              write_ymm(dst, r3 @ r2 @ r1 @ r0)
            },
            // VCVTPD2PS: 4 doubles -> 4 floats (in low 128)
            MP_66 => {
              let r3 = __f64_to_f32(src2[255..192]);
              let r2 = __f64_to_f32(src2[191..128]);
              let r1 = __f64_to_f32(src2[127..64]);
              let r0 = __f64_to_f32(src2[63..0]);
              write_xmm(dst, r3 @ r2 @ r1 @ r0)
            },
            _ => raise_UD(),
          }
        },
        // VCVTDQ2PS/VCVTPS2DQ/VCVTTPS2DQ (256-bit, vvvv reserved)
        // SDM: 8 element-wise conversions on 32-bit lanes, upper zeroed
        11 => {
          if pfx.vex_vvvv != 0 then raise_UD();
          match mp {
            // VCVTDQ2PS ymm1, ymm2/m256
            MP_NONE => write_ymm(dst, avx_cvtdq2ps_256(src2)),
            // VCVTPS2DQ ymm1, ymm2/m256
            MP_66 => write_ymm(dst, avx_cvtps2dq_256(src2)),
            MP_F2 => raise_UD(),
            // VCVTTPS2DQ ymm1, ymm2/m256
            MP_F3 => write_ymm(dst, avx_cvttps2dq_256(src2)),
          }
        },
        // VSUBPS/VSUBPD
        12 => match mp {
          MP_NONE => write_ymm(dst, vsubps_xmm(src1[255..128], src2[255..128]) @ vsubps_xmm(src1[127..0], src2[127..0])),
          MP_66   => write_ymm(dst, vsubpd_xmm(src1[255..128], src2[255..128]) @ vsubpd_xmm(src1[127..0], src2[127..0])),
          _ => raise_UD(),
        },
        // VMINPS/VMINPD
        13 => match mp {
          MP_NONE => write_ymm(dst, vminps_xmm(src1[255..128], src2[255..128]) @ vminps_xmm(src1[127..0], src2[127..0])),
          MP_66   => write_ymm(dst, vminpd_xmm(src1[255..128], src2[255..128]) @ vminpd_xmm(src1[127..0], src2[127..0])),
          _ => raise_UD(),
        },
        // VDIVPS/VDIVPD
        14 => match mp {
          MP_NONE => write_ymm(dst, vdivps_xmm(src1[255..128], src2[255..128]) @ vdivps_xmm(src1[127..0], src2[127..0])),
          MP_66   => write_ymm(dst, vdivpd_xmm(src1[255..128], src2[255..128]) @ vdivpd_xmm(src1[127..0], src2[127..0])),
          _ => raise_UD(),
        },
        // VMAXPS/VMAXPD
        15 => match mp {
          MP_NONE => write_ymm(dst, vmaxps_xmm(src1[255..128], src2[255..128]) @ vmaxps_xmm(src1[127..0], src2[127..0])),
          MP_66   => write_ymm(dst, vmaxpd_xmm(src1[255..128], src2[255..128]) @ vmaxpd_xmm(src1[127..0], src2[127..0])),
          _ => raise_UD(),
        },
        _ => raise_UD(),
      }
    } else {
      // 128-bit XMM path (upper bits zeroed by write_xmm)
      let src1 : xmmword = read_xmm(pfx.vex_vvvv);
      let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
      match col {
        // VSQRTPS/VSQRTPD/VSQRTSS/VSQRTSD
        1 => match mp {
          MP_NONE => { if pfx.vex_vvvv != 0 then raise_UD(); write_xmm(dst, vsqrtps_xmm(src2)) },
          MP_66   => { if pfx.vex_vvvv != 0 then raise_UD(); write_xmm(dst, vsqrtpd_xmm(src2)) },
          MP_F3   => write_xmm(dst, src1[127..32] @ __f32_sqrt(src2[31..0])),
          MP_F2   => write_xmm(dst, src1[127..64] @ __f64_sqrt(src2[63..0])),
        },
        // VRSQRTPS (NP, vvvv reserved) / VRSQRTSS (F3, scalar merge)
        2 => match mp {
          MP_NONE => {
            if pfx.vex_vvvv != 0 then raise_UD();
            write_xmm(dst, __f32_rsqrt(src2[127..96]) @ __f32_rsqrt(src2[95..64]) @
                           __f32_rsqrt(src2[63..32])  @ __f32_rsqrt(src2[31..0]))
          },
          MP_F3 => write_xmm(dst, src1[127..32] @ __f32_rsqrt(src2[31..0])),
          _ => raise_UD(),
        },
        // VRCPPS (NP, vvvv reserved) / VRCPSS (F3, scalar merge)
        3 => match mp {
          MP_NONE => {
            if pfx.vex_vvvv != 0 then raise_UD();
            write_xmm(dst, __f32_rcp(src2[127..96]) @ __f32_rcp(src2[95..64]) @
                           __f32_rcp(src2[63..32])  @ __f32_rcp(src2[31..0]))
          },
          MP_F3 => write_xmm(dst, src1[127..32] @ __f32_rcp(src2[31..0])),
          _ => raise_UD(),
        },
        // VANDPS/VANDPD
        4 => write_xmm(dst, src1 & src2),
        // VANDNPS/VANDNPD
        5 => write_xmm(dst, ~(src1) & src2),
        // VORPS/VORPD
        6 => write_xmm(dst, src1 | src2),
        // VXORPS/VXORPD
        7 => write_xmm(dst, src1 ^ src2),
        // VADDPS/VADDPD/VADDSS/VADDSD
        8 => match mp {
          MP_NONE => write_xmm(dst, vaddps_xmm(src1, src2)),
          MP_66   => write_xmm(dst, vaddpd_xmm(src1, src2)),
          MP_F3   => write_xmm(dst, src1[127..32] @ __f32_add(src1[31..0], src2[31..0])),
          MP_F2   => write_xmm(dst, src1[127..64] @ __f64_add(src1[63..0], src2[63..0])),
        },
        // VMULPS/VMULPD/VMULSS/VMULSD
        9 => match mp {
          MP_NONE => write_xmm(dst, vmulps_xmm(src1, src2)),
          MP_66   => write_xmm(dst, vmulpd_xmm(src1, src2)),
          MP_F3   => write_xmm(dst, src1[127..32] @ __f32_mul(src1[31..0], src2[31..0])),
          MP_F2   => write_xmm(dst, src1[127..64] @ __f64_mul(src1[63..0], src2[63..0])),
        },
        // VCVTDQ2PS/VCVTPS2DQ/VCVTTPS2DQ (unary, vvvv reserved)
        11 => {
          if pfx.vex_vvvv != 0 then raise_UD();
          match mp {
            // VCVTDQ2PS xmm1, xmm2/m128
            MP_NONE => {
              write_xmm(dst, __int32_to_f32(src2[127..96]) @ __int32_to_f32(src2[95..64]) @
                __int32_to_f32(src2[63..32]) @ __int32_to_f32(src2[31..0]))
            },
            // VCVTPS2DQ xmm1, xmm2/m128
            MP_66 => {
              write_xmm(dst, __f32_to_int32(src2[127..96]) @ __f32_to_int32(src2[95..64]) @
                __f32_to_int32(src2[63..32]) @ __f32_to_int32(src2[31..0]))
            },
            MP_F2 => raise_UD(),
            // VCVTTPS2DQ xmm1, xmm2/m128
            MP_F3 => {
              write_xmm(dst, __f32_to_int32_trunc(src2[127..96]) @ __f32_to_int32_trunc(src2[95..64]) @
                __f32_to_int32_trunc(src2[63..32]) @ __f32_to_int32_trunc(src2[31..0]))
            },
          }
        },
        // VCVTPS2PD/VCVTPD2PS/VCVTSS2SD/VCVTSD2SS (128-bit)
        10 => match mp {
          // VCVTPS2PD: 2 floats -> 2 doubles (vvvv reserved)
          MP_NONE => {
            if pfx.vex_vvvv != 0 then raise_UD();
            let r1 = __f32_to_f64(src2[63..32]);
            let r0 = __f32_to_f64(src2[31..0]);
            write_xmm(dst, r1 @ r0)
          },
          // VCVTPD2PS: 2 doubles -> 2 floats (vvvv reserved)
          MP_66 => {
            if pfx.vex_vvvv != 0 then raise_UD();
            let r1 = __f64_to_f32(src2[127..64]);
            let r0 = __f64_to_f32(src2[63..0]);
            write_xmm(dst, zeros(64) @ r1 @ r0)
          },
          // VCVTSS2SD: scalar float -> double
          MP_F3 => {
            write_xmm(dst, src1[127..64] @ __f32_to_f64(src2[31..0]))
          },
          // VCVTSD2SS: scalar double -> float
          MP_F2 => {
            write_xmm(dst, src1[127..32] @ __f64_to_f32(src2[63..0]))
          },
        },
        // VSUBPS/VSUBPD/VSUBSS/VSUBSD
        12 => match mp {
          MP_NONE => write_xmm(dst, vsubps_xmm(src1, src2)),
          MP_66   => write_xmm(dst, vsubpd_xmm(src1, src2)),
          MP_F3   => write_xmm(dst, src1[127..32] @ __f32_sub(src1[31..0], src2[31..0])),
          MP_F2   => write_xmm(dst, src1[127..64] @ __f64_sub(src1[63..0], src2[63..0])),
        },
        // VMINPS/VMINPD/VMINSS/VMINSD
        13 => match mp {
          MP_NONE => write_xmm(dst, vminps_xmm(src1, src2)),
          MP_66   => write_xmm(dst, vminpd_xmm(src1, src2)),
          MP_F3   => write_xmm(dst, src1[127..32] @ __f32_min(src1[31..0], src2[31..0])),
          MP_F2   => write_xmm(dst, src1[127..64] @ __f64_min(src1[63..0], src2[63..0])),
        },
        // VDIVPS/VDIVPD/VDIVSS/VDIVSD
        14 => match mp {
          MP_NONE => write_xmm(dst, vdivps_xmm(src1, src2)),
          MP_66   => write_xmm(dst, vdivpd_xmm(src1, src2)),
          MP_F3   => write_xmm(dst, src1[127..32] @ __f32_div(src1[31..0], src2[31..0])),
          MP_F2   => write_xmm(dst, src1[127..64] @ __f64_div(src1[63..0], src2[63..0])),
        },
        // VMAXPS/VMAXPD/VMAXSS/VMAXSD
        15 => match mp {
          MP_NONE => write_xmm(dst, vmaxps_xmm(src1, src2)),
          MP_66   => write_xmm(dst, vmaxpd_xmm(src1, src2)),
          MP_F3   => write_xmm(dst, src1[127..32] @ __f32_max(src1[31..0], src2[31..0])),
          MP_F2   => write_xmm(dst, src1[127..64] @ __f64_max(src1[63..0], src2[63..0])),
        },
        _ => raise_UD(),
      }
    }
  },

  // 0F C2: VCMPPS/VCMPPD/VCMPSS/VCMPSD imm8
  194 => {
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let imm = fetch_byte();
    let pred : bits(5) = imm[4..0];
    match mp {
      // VCMPPS xmm1/ymm1, xmm2/ymm2, xmm3/ymm3/m128/m256, imm8
      MP_NONE => {
        if pfx.vex_l then {
          let src1 : ymmword = read_ymm(pfx.vex_vvvv);
          let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
          write_ymm(dst, cmp_pred_f32(src1[255..224], src2[255..224], pred) @
                          cmp_pred_f32(src1[223..192], src2[223..192], pred) @
                          cmp_pred_f32(src1[191..160], src2[191..160], pred) @
                          cmp_pred_f32(src1[159..128], src2[159..128], pred) @
                          cmp_pred_f32(src1[127..96],  src2[127..96],  pred) @
                          cmp_pred_f32(src1[95..64],   src2[95..64],   pred) @
                          cmp_pred_f32(src1[63..32],   src2[63..32],   pred) @
                          cmp_pred_f32(src1[31..0],    src2[31..0],    pred))
        } else {
          let src1 : xmmword = read_xmm(pfx.vex_vvvv);
          let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
          write_xmm(dst, cmp_pred_f32(src1[127..96], src2[127..96], pred) @
                          cmp_pred_f32(src1[95..64],  src2[95..64],  pred) @
                          cmp_pred_f32(src1[63..32],  src2[63..32],  pred) @
                          cmp_pred_f32(src1[31..0],   src2[31..0],   pred))
        }
      },
      // VCMPPD xmm1/ymm1, xmm2/ymm2, xmm3/ymm3/m128/m256, imm8
      MP_66 => {
        if pfx.vex_l then {
          let src1 : ymmword = read_ymm(pfx.vex_vvvv);
          let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
          write_ymm(dst, cmp_pred_f64(src1[255..192], src2[255..192], pred) @
                          cmp_pred_f64(src1[191..128], src2[191..128], pred) @
                          cmp_pred_f64(src1[127..64],  src2[127..64],  pred) @
                          cmp_pred_f64(src1[63..0],    src2[63..0],    pred))
        } else {
          let src1 : xmmword = read_xmm(pfx.vex_vvvv);
          let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
          write_xmm(dst, cmp_pred_f64(src1[127..64], src2[127..64], pred) @
                          cmp_pred_f64(src1[63..0],   src2[63..0],   pred))
        }
      },
      // VCMPSS (scalar, VEX.L ignored)
      MP_F3 => {
        let src1 : xmmword = read_xmm(pfx.vex_vvvv);
        let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        write_xmm(dst, src1[127..32] @ cmp_pred_f32(src1[31..0], src2[31..0], pred))
      },
      // VCMPSD (scalar, VEX.L ignored)
      MP_F2 => {
        let src1 : xmmword = read_xmm(pfx.vex_vvvv);
        let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        write_xmm(dst, src1[127..64] @ cmp_pred_f64(src1[63..0], src2[63..0], pred))
      },
    }
  },

  // 0F C6: VSHUFPS (NP) / VSHUFPD (66) imm8
  198 => {
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let imm = fetch_byte();
    match mp {
      // VSHUFPS xmm1/ymm1, xmm2/ymm2, xmm3/ymm3/m128/m256, imm8
      MP_NONE => {
        let s0 : range(0, 3) = unsigned(imm[1..0]);
        let s1 : range(0, 3) = unsigned(imm[3..2]);
        let s2 : range(0, 3) = unsigned(imm[5..4]);
        let s3 : range(0, 3) = unsigned(imm[7..6]);
        if pfx.vex_l then {
          // 256-bit: two independent 128-bit lane shuffles, same imm8
          let src1 : ymmword = read_ymm(pfx.vex_vvvv);
          let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
          // Low lane: r0-r1 from src1[127..0], r2-r3 from src2[127..0]
          let r0 : dword = src1[(32*s0+31) .. (32*s0)];
          let r1 : dword = src1[(32*s1+31) .. (32*s1)];
          let r2 : dword = src2[(32*s2+31) .. (32*s2)];
          let r3 : dword = src2[(32*s3+31) .. (32*s3)];
          // High lane: r4-r5 from src1[255..128], r6-r7 from src2[255..128]
          let r4 : dword = src1[(32*s0+159) .. (32*s0+128)];
          let r5 : dword = src1[(32*s1+159) .. (32*s1+128)];
          let r6 : dword = src2[(32*s2+159) .. (32*s2+128)];
          let r7 : dword = src2[(32*s3+159) .. (32*s3+128)];
          write_ymm(dst, r7 @ r6 @ r5 @ r4 @ r3 @ r2 @ r1 @ r0)
        } else {
          let src1 : xmmword = read_xmm(pfx.vex_vvvv);
          let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
          let r0 : dword = src1[(32*s0+31) .. (32*s0)];
          let r1 : dword = src1[(32*s1+31) .. (32*s1)];
          let r2 : dword = src2[(32*s2+31) .. (32*s2)];
          let r3 : dword = src2[(32*s3+31) .. (32*s3)];
          write_xmm(dst, r3 @ r2 @ r1 @ r0)
        }
      },
      // VSHUFPD xmm1/ymm1, xmm2/ymm2, xmm3/ymm3/m128/m256, imm8
      MP_66 => {
        if pfx.vex_l then {
          // 256-bit: 4 qwords, each selected by one imm8 bit
          let src1 : ymmword = read_ymm(pfx.vex_vvvv);
          let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
          let r0 : qword = blend(src1[63..0],    src1[127..64],  imm[0]);
          let r1 : qword = blend(src2[63..0],    src2[127..64],  imm[1]);
          let r2 : qword = blend(src1[191..128], src1[255..192], imm[2]);
          let r3 : qword = blend(src2[191..128], src2[255..192], imm[3]);
          write_ymm(dst, r3 @ r2 @ r1 @ r0)
        } else {
          let src1 : xmmword = read_xmm(pfx.vex_vvvv);
          let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
          let r0 : qword = blend(src1[63..0], src1[127..64], imm[0]);
          let r1 : qword = blend(src2[63..0], src2[127..64], imm[1]);
          write_xmm(dst, r1 @ r0)
        }
      },
      _ => raise_UD(),
    }
  },

  _ => raise_UD(),
  }
}

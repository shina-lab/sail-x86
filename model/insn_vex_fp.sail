// x86-64 VEX — FP Instructions (0F map)
//
// Floating-point moves, arithmetic, compare, convert, shuffle, unpack.

val dispatch_vex_0f_fp : (range(0, 255), Prefixes) -> ExecutionResult
function dispatch_vex_0f_fp(op, pfx) = {
  let mp = get_mandatory_prefix(pfx);

  match op {

  // 0F 10: VMOVUPS/VMOVUPD/VMOVSS/VMOVSD (load)
  16 => {
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    match mp {
      MP_NONE => // VMOVUPS (vvvv reserved)
        if pfx.vex_vvvv != 0 then { raise_UD() } else if pfx.vex_l then {
          let src = decode_vex_src_ymm(modrm, rm, pfx);
          write_ymm(dst, src);
          Ok()
        } else { let src = decode_vex_src_xmm(modrm, rm, pfx); write_xmm(dst, src); Ok() },
      MP_66 => // VMOVUPD (vvvv reserved)
        if pfx.vex_vvvv != 0 then { raise_UD() } else if pfx.vex_l then {
          let src = decode_vex_src_ymm(modrm, rm, pfx);
          write_ymm(dst, src);
          Ok()
        } else { let src = decode_vex_src_xmm(modrm, rm, pfx); write_xmm(dst, src); Ok() },
      MP_F3 => { // VMOVSS xmm1, xmm2, xmm3 or xmm1, m32
        match rm {
          RM_reg(_) => {
            // reg-reg: merge src2[127:32] with src3[31:0]
            let src2 : xmmword = read_xmm(pfx.vex_vvvv);
            let src3 : xmmword = read_xmm(modrm_xmm_rm(modrm, pfx));
            write_xmm(dst, src2[127..32] @ src3[31..0]);
            Ok()
          },
          RM_mem(addr) => {
            // mem: load 32 bits, zero-extend to 128
            let v : dword = mem_read32(fixup_addr(addr));
            write_xmm(dst, zeros(96) @ v);
            Ok()
          },
        }
      },
      MP_F2 => { // VMOVSD xmm1, xmm2, xmm3 or xmm1, m64
        match rm {
          RM_reg(_) => {
            let src2 : xmmword = read_xmm(pfx.vex_vvvv);
            let src3 : xmmword = read_xmm(modrm_xmm_rm(modrm, pfx));
            write_xmm(dst, src2[127..64] @ src3[63..0]);
            Ok()
          },
          RM_mem(addr) => {
            let v : qword = mem_read64(fixup_addr(addr));
            write_xmm(dst, zeros(64) @ v);
            Ok()
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
      MP_NONE => // VMOVUPS (vvvv reserved)
        if pfx.vex_vvvv != 0 then { raise_UD() } else match rm {
          RM_reg(_) => {
            let dst = modrm_xmm_rm(modrm, pfx);
            if pfx.vex_l then {
              write_ymm(dst, read_ymm(src)); Ok()
            } else {
              write_xmm(dst, read_xmm(src)); Ok()
            }
          },
          RM_mem(addr) => {
            let a = fixup_addr(addr);
            if pfx.vex_l then {
              mem_write256(a, read_ymm(src)); Ok()
            } else {
              mem_write128(a, read_xmm(src)); Ok()
            }
          },
        },
      MP_66 => // VMOVUPD (vvvv reserved)
        if pfx.vex_vvvv != 0 then { raise_UD() } else match rm {
          RM_reg(_) => {
            let dst = modrm_xmm_rm(modrm, pfx);
            if pfx.vex_l then {
              write_ymm(dst, read_ymm(src)); Ok()
            } else {
              write_xmm(dst, read_xmm(src)); Ok()
            }
          },
          RM_mem(addr) => {
            let a = fixup_addr(addr);
            if pfx.vex_l then {
              mem_write256(a, read_ymm(src)); Ok()
            } else {
              mem_write128(a, read_xmm(src)); Ok()
            }
          },
        },
      MP_F3 => { // VMOVSS store
        match rm {
          RM_reg(_) => {
            let dst = modrm_xmm_rm(modrm, pfx);
            let src2 : xmmword = read_xmm(pfx.vex_vvvv);
            let src3 : xmmword = read_xmm(src);
            write_xmm(dst, src2[127..32] @ src3[31..0]);
            Ok()
          },
          RM_mem(addr) => { mem_write32(fixup_addr(addr), read_xmm(src)[31..0]); Ok() },
        }
      },
      MP_F2 => { // VMOVSD store
        match rm {
          RM_reg(_) => {
            let dst = modrm_xmm_rm(modrm, pfx);
            let src2 : xmmword = read_xmm(pfx.vex_vvvv);
            let src3 : xmmword = read_xmm(src);
            write_xmm(dst, src2[127..64] @ src3[63..0]);
            Ok()
          },
          RM_mem(addr) => { mem_write64(fixup_addr(addr), read_xmm(src)[63..0]); Ok() },
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
          RM_reg(_) => { // VMOVHLPS: dst[63:0] = src2[127:64], dst[127:64] = vvvv[127:64]
            let src1 : xmmword = read_xmm(pfx.vex_vvvv);
            let src2 : xmmword = read_xmm(modrm_xmm_rm(modrm, pfx));
            write_xmm(dst, src1[127..64] @ src2[127..64]);
            Ok()
          },
          RM_mem(addr) => { // VMOVLPS: dst[63:0] = m64, dst[127:64] = vvvv[127:64]
            let src1 : xmmword = read_xmm(pfx.vex_vvvv);
            let v : qword = mem_read64(fixup_addr(addr));
            write_xmm(dst, src1[127..64] @ v);
            Ok()
          },
        }
      },
      _ => raise_UD(),
    }
  },

  // 0F 13: VMOVLPS/VMOVLPD m64, xmm (store low 64 bits to memory)
  19 => {
    if pfx.vex_l | pfx.vex_vvvv != 0 then { raise_UD() } else {
      let modrm = fetch_byte();
      let src = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      match rm {
        RM_mem(addr) => { mem_write64(fixup_addr(addr), read_xmm(src)[63..0]); Ok() },
        RM_reg(_) => raise_UD(),
      }
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
        MP_NONE => { // VUNPCKLPS ymm
          let lo = src2[63..32] @ src1[63..32] @ src2[31..0] @ src1[31..0];
          let hi = src2[191..160] @ src1[191..160] @ src2[159..128] @ src1[159..128];
          write_ymm(dst, hi @ lo);
          Ok()
        },
        MP_66 => { // VUNPCKLPD ymm
          let lo = src2[63..0] @ src1[63..0];
          let hi = src2[191..128] @ src1[191..128];
          write_ymm(dst, hi @ lo);
          Ok()
        },
        _ => raise_UD(),
      }
    } else {
      let src1 : xmmword = read_xmm(pfx.vex_vvvv);
      let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
      match mp {
        MP_NONE => { write_xmm(dst, src2[63..32] @ src1[63..32] @ src2[31..0] @ src1[31..0]); Ok() },
        MP_66   => { write_xmm(dst, src2[63..0] @ src1[63..0]); Ok() },
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
        MP_NONE => { // VUNPCKHPS ymm
          let lo = src2[127..96] @ src1[127..96] @ src2[95..64] @ src1[95..64];
          let hi = src2[255..224] @ src1[255..224] @ src2[223..192] @ src1[223..192];
          write_ymm(dst, hi @ lo);
          Ok()
        },
        MP_66 => { // VUNPCKHPD ymm
          let lo = src2[127..64] @ src1[127..64];
          let hi = src2[255..192] @ src1[255..192];
          write_ymm(dst, hi @ lo);
          Ok()
        },
        _ => raise_UD(),
      }
    } else {
      let src1 : xmmword = read_xmm(pfx.vex_vvvv);
      let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
      match mp {
        MP_NONE => { write_xmm(dst, src2[127..96] @ src1[127..96] @ src2[95..64] @ src1[95..64]); Ok() },
        MP_66   => { write_xmm(dst, src2[127..64] @ src1[127..64]); Ok() },
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
          RM_reg(_) => { // VMOVLHPS: dst[127:64] = src2[63:0], dst[63:0] = vvvv[63:0]
            let src1 : xmmword = read_xmm(pfx.vex_vvvv);
            let src2 : xmmword = read_xmm(modrm_xmm_rm(modrm, pfx));
            write_xmm(dst, src2[63..0] @ src1[63..0]);
            Ok()
          },
          RM_mem(addr) => { // VMOVHPS: dst[63:0] = vvvv[63:0], dst[127:64] = m64
            let src1 : xmmword = read_xmm(pfx.vex_vvvv);
            let v : qword = mem_read64(fixup_addr(addr));
            write_xmm(dst, v @ src1[63..0]);
            Ok()
          },
        }
      },
      _ => raise_UD(),
    }
  },

  // 0F 17: VMOVHPS/VMOVHPD m64, xmm (store high 64 bits to memory)
  23 => {
    if pfx.vex_l | pfx.vex_vvvv != 0 then { raise_UD() } else {
      let modrm = fetch_byte();
      let src = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      match rm {
        RM_mem(addr) => { mem_write64(fixup_addr(addr), read_xmm(src)[127..64]); Ok() },
        RM_reg(_) => raise_UD(),
      }
    }
  },

  // 0F 28: VMOVAPS/VMOVAPD (load)
  // SDM: VEX.vvvv must be 1111b
  40 => {
    if pfx.vex_vvvv != 0 then { raise_UD() } else {
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    match rm {
      RM_reg(_) => {
        if pfx.vex_l then {
          write_ymm(dst, read_ymm(modrm_xmm_rm(modrm, pfx)));
        } else {
          write_xmm(dst, read_xmm(modrm_xmm_rm(modrm, pfx)));
        };
        Ok()
      },
      RM_mem(addr) => {
        let a = fixup_addr(addr);
        // VMOVAPS/VMOVAPD require alignment: 32 for YMM, 16 for XMM; #GP(0) if unaligned
        if pfx.vex_l then {
          if unsigned(a) % 32 != 0 then {
            raise_GP0()
          } else {
            write_ymm(dst, mem_read256(a));
            Ok()
          }
        } else {
          if unsigned(a) % 16 != 0 then {
            raise_GP0()
          } else {
            write_xmm(dst, mem_read128(a));
            Ok()
          }
        }
      },
    }
    }
  },

  // 0F 29: VMOVAPS/VMOVAPD (store)
  // SDM: VEX.vvvv must be 1111b
  41 => {
    if pfx.vex_vvvv != 0 then { raise_UD() } else {
    let modrm = fetch_byte();
    let src = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    match rm {
      RM_reg(_) => {
        let dst = modrm_xmm_rm(modrm, pfx);
        if pfx.vex_l then {
          write_ymm(dst, read_ymm(src)); Ok()
        } else {
          write_xmm(dst, read_xmm(src)); Ok()
        }
      },
      RM_mem(addr) => {
        let a = fixup_addr(addr);
        // VMOVAPS/VMOVAPD require alignment: 32 for YMM, 16 for XMM; #GP(0) if unaligned
        if pfx.vex_l then {
          if unsigned(a) % 32 != 0 then {
            raise_GP0()
          } else {
            mem_write256(a, read_ymm(src)); Ok()
          }
        } else {
          if unsigned(a) % 16 != 0 then {
            raise_GP0()
          } else {
            mem_write128(a, read_xmm(src)); Ok()
          }
        }
      },
    }
    }
  },

  // 0F 2A: VCVTSI2SS (F3) / VCVTSI2SD (F2) — int to scalar float
  42 => {
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let src1 : xmmword = read_xmm(pfx.vex_vvvv);
    match mp {
      MP_F3 => { // VCVTSI2SS
        if pfx.vex_w then {
          let v : qword = match rm { RM_reg(idx) => read_gpr64(idx), RM_mem(addr) => mem_read64(fixup_addr(addr)) };
          write_xmm(dst, src1[127..32] @ __int64_to_f32(v));
        } else {
          let v : dword = match rm { RM_reg(idx) => read_gpr32(idx), RM_mem(addr) => mem_read32(fixup_addr(addr)) };
          write_xmm(dst, src1[127..32] @ __int32_to_f32(v));
        };
        Ok()
      },
      MP_F2 => { // VCVTSI2SD
        if pfx.vex_w then {
          let v : qword = match rm { RM_reg(idx) => read_gpr64(idx), RM_mem(addr) => mem_read64(fixup_addr(addr)) };
          write_xmm(dst, src1[127..64] @ __int64_to_f64(v));
        } else {
          let v : dword = match rm { RM_reg(idx) => read_gpr32(idx), RM_mem(addr) => mem_read32(fixup_addr(addr)) };
          write_xmm(dst, src1[127..64] @ __int32_to_f64(v));
        };
        Ok()
      },
      _ => raise_UD(),
    }
  },

  // 0F 2B: VMOVNTPS/VMOVNTPD m, xmm/ymm (non-temporal store; we treat as regular store)
  43 => {
    if pfx.vex_vvvv != 0 then { raise_UD() } else {
      let modrm = fetch_byte();
      let src = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      match rm {
        RM_mem(addr) => {
          let a = fixup_addr(addr);
          if pfx.vex_l then {
            let v : ymmword = read_ymm(src);
            mem_write128(a, v[127..0]);
            mem_write128(a + 16, v[255..128]);
            Ok()
          } else {
            mem_write128(a, read_xmm(src));
            Ok()
          }
        },
        RM_reg(_) => raise_UD(),
      }
    }
  },

  // 0F 2C: VCVTTSS2SI (F3) / VCVTTSD2SI (F2) — truncating scalar float to int
  44 => {
    let modrm = fetch_byte();
    let rm = decode_rm(modrm, pfx);
    let dst_gpr = modrm_reg(modrm, pfx);
    match mp {
      MP_F3 => { // VCVTTSS2SI
        let src : dword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[31..0],
          RM_mem(addr) => mem_read32(fixup_addr(addr)),
        };
        if pfx.vex_w then write_gpr64(dst_gpr, __f32_to_int64_trunc(src))
        else write_gpr32(dst_gpr, __f32_to_int32_trunc(src));
        Ok()
      },
      MP_F2 => { // VCVTTSD2SI
        let src : qword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[63..0],
          RM_mem(addr) => mem_read64(fixup_addr(addr)),
        };
        if pfx.vex_w then write_gpr64(dst_gpr, __f64_to_int64_trunc(src))
        else write_gpr32(dst_gpr, __f64_to_int32_trunc(src));
        Ok()
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
          RM_mem(addr) => mem_read32(fixup_addr(addr)),
        };
        if pfx.vex_w then
          write_gpr64(reg, __f32_to_int64(src))
        else
          write_gpr32(reg, __f32_to_int32(src));
        Ok()
      },
      MP_F2 => {
        let src : qword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[63..0],
          RM_mem(addr) => mem_read64(fixup_addr(addr)),
        };
        if pfx.vex_w then
          write_gpr64(reg, __f64_to_int64(src))
        else
          write_gpr32(reg, __f64_to_int32(src));
        Ok()
      },
      _ => raise_UD(),
    }
  },

  // 0F 2E: VUCOMISS (NP) / VUCOMISD (66) — unordered compare scalars, set EFLAGS
  // SDM: VEX.vvvv must be 1111b
  46 => {
    if pfx.vex_vvvv != 0 then { raise_UD() } else {
    let modrm = fetch_byte();
    let src_reg = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    match mp {
      MP_NONE => { // VUCOMISS
        let src : xmmword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(addr) => zero_extend(mem_read32(fixup_addr(addr))),
        };
        let a : dword = read_xmm(src_reg)[31..0];
        let b : dword = src[31..0];
        match __compare_ss(a, b) {
          FP_UNORDERED => { ZF = bitone;  PF = bitone;  CF = bitone;  },
          FP_GT        => { ZF = bitzero; PF = bitzero; CF = bitzero; },
          FP_LT        => { ZF = bitzero; PF = bitzero; CF = bitone;  },
          FP_EQ        => { ZF = bitone;  PF = bitzero; CF = bitzero; },
        };
        OF = bitzero; SF = bitzero; AF = bitzero;
        Ok()
      },
      MP_66 => { // VUCOMISD
        let src : xmmword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(addr) => zero_extend(mem_read64(fixup_addr(addr))),
        };
        let a : qword = read_xmm(src_reg)[63..0];
        let b : qword = src[63..0];
        match __compare_sd(a, b) {
          FP_UNORDERED => { ZF = bitone;  PF = bitone;  CF = bitone;  },
          FP_GT        => { ZF = bitzero; PF = bitzero; CF = bitzero; },
          FP_LT        => { ZF = bitzero; PF = bitzero; CF = bitone;  },
          FP_EQ        => { ZF = bitone;  PF = bitzero; CF = bitzero; },
        };
        OF = bitzero; SF = bitzero; AF = bitzero;
        Ok()
      },
      _ => raise_UD(),
    }
    }
  },

  // 0F 2F: VCOMISS (NP) / VCOMISD (66) — ordered compare scalars, set EFLAGS
  // SDM: VEX.vvvv must be 1111b
  47 => {
    if pfx.vex_vvvv != 0 then { raise_UD() } else {
    let modrm = fetch_byte();
    let src_reg = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    match mp {
      MP_NONE => { // VCOMISS
        let src : xmmword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(addr) => zero_extend(mem_read32(fixup_addr(addr))),
        };
        let a : dword = read_xmm(src_reg)[31..0];
        let b : dword = src[31..0];
        match __compare_ss(a, b) {
          FP_UNORDERED => { ZF = bitone;  PF = bitone;  CF = bitone;  },
          FP_GT        => { ZF = bitzero; PF = bitzero; CF = bitzero; },
          FP_LT        => { ZF = bitzero; PF = bitzero; CF = bitone;  },
          FP_EQ        => { ZF = bitone;  PF = bitzero; CF = bitzero; },
        };
        OF = bitzero; SF = bitzero; AF = bitzero;
        Ok()
      },
      MP_66 => { // VCOMISD
        let src : xmmword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(addr) => zero_extend(mem_read64(fixup_addr(addr))),
        };
        let a : qword = read_xmm(src_reg)[63..0];
        let b : qword = src[63..0];
        match __compare_sd(a, b) {
          FP_UNORDERED => { ZF = bitone;  PF = bitone;  CF = bitone;  },
          FP_GT        => { ZF = bitzero; PF = bitzero; CF = bitzero; },
          FP_LT        => { ZF = bitzero; PF = bitzero; CF = bitone;  },
          FP_EQ        => { ZF = bitone;  PF = bitzero; CF = bitzero; },
        };
        OF = bitzero; SF = bitzero; AF = bitzero;
        Ok()
      },
      _ => raise_UD(),
    }
    }
  },

  // 0F 50: VMOVMSKPS (NP) / VMOVMSKPD (66) — extract sign bits to GPR
  80 => {
    let modrm = fetch_byte();
    let reg = modrm_reg(modrm, pfx);
    let _ = decode_rm(modrm, pfx);
    if pfx.vex_vvvv != 0 then { raise_UD() } else {
      match mp {
        MP_NONE => {
          if pfx.vex_l then {
            let src : ymmword = read_ymm(modrm_xmm_rm(modrm, pfx));
            let mask : byte = src[255] @ src[223] @ src[191] @ src[159] @
                              src[127] @ src[95] @ src[63] @ src[31];
            write_gpr32(reg, zero_extend(mask));
            Ok()
          } else {
            let src : xmmword = read_xmm(modrm_xmm_rm(modrm, pfx));
            let mask : bits(4) = src[127] @ src[95] @ src[63] @ src[31];
            write_gpr32(reg, zero_extend(mask));
            Ok()
          }
        },
        MP_66 => {
          if pfx.vex_l then {
            let src : ymmword = read_ymm(modrm_xmm_rm(modrm, pfx));
            let mask : bits(4) = src[255] @ src[191] @ src[127] @ src[63];
            write_gpr32(reg, zero_extend(mask));
            Ok()
          } else {
            let src : xmmword = read_xmm(modrm_xmm_rm(modrm, pfx));
            let mask : bits(2) = src[127] @ src[63];
            write_gpr32(reg, zero_extend(mask));
            Ok()
          }
        },
        _ => raise_UD(),
      }
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
        1 => if pfx.vex_vvvv != 0 then { raise_UD() } else match mp { // VSQRTPS/VSQRTPD (unary, vvvv reserved)
          MP_NONE => { write_ymm(dst, vsqrtps_xmm(src2[255..128]) @ vsqrtps_xmm(src2[127..0])); Ok() },
          MP_66   => { write_ymm(dst, vsqrtpd_xmm(src2[255..128]) @ vsqrtpd_xmm(src2[127..0])); Ok() },
          _ => raise_UD(),
        },
        2 => if pfx.vex_vvvv != 0 then { raise_UD() } else match mp { // VRSQRTPS (NP only, vvvv reserved, 256-bit)
          MP_NONE => {
            let hi = __f32_rsqrt(src2[255..224]) @ __f32_rsqrt(src2[223..192]) @
                     __f32_rsqrt(src2[191..160]) @ __f32_rsqrt(src2[159..128]);
            let lo = __f32_rsqrt(src2[127..96]) @ __f32_rsqrt(src2[95..64]) @
                     __f32_rsqrt(src2[63..32])  @ __f32_rsqrt(src2[31..0]);
            write_ymm(dst, hi @ lo); Ok()
          },
          _ => raise_UD(),
        },
        3 => if pfx.vex_vvvv != 0 then { raise_UD() } else match mp { // VRCPPS (NP only, vvvv reserved, 256-bit)
          MP_NONE => {
            let hi = __f32_rcp(src2[255..224]) @ __f32_rcp(src2[223..192]) @
                     __f32_rcp(src2[191..160]) @ __f32_rcp(src2[159..128]);
            let lo = __f32_rcp(src2[127..96]) @ __f32_rcp(src2[95..64]) @
                     __f32_rcp(src2[63..32])  @ __f32_rcp(src2[31..0]);
            write_ymm(dst, hi @ lo); Ok()
          },
          _ => raise_UD(),
        },
        4 => match mp { // VANDPS/VANDPD
          _ => { write_ymm(dst, src1 & src2); Ok() },
        },
        5 => match mp { // VANDNPS/VANDNPD
          _ => { write_ymm(dst, ~(src1) & src2); Ok() },
        },
        6 => match mp { // VORPS/VORPD
          _ => { write_ymm(dst, src1 | src2); Ok() },
        },
        7 => match mp { // VXORPS/VXORPD
          _ => { write_ymm(dst, xor_vec(src1, src2)); Ok() },
        },
        8 => match mp { // VADDPS/VADDPD
          MP_NONE => { write_ymm(dst, vaddps_xmm(src1[255..128], src2[255..128]) @ vaddps_xmm(src1[127..0], src2[127..0])); Ok() },
          MP_66   => { write_ymm(dst, vaddpd_xmm(src1[255..128], src2[255..128]) @ vaddpd_xmm(src1[127..0], src2[127..0])); Ok() },
          _ => raise_UD(),
        },
        9 => match mp { // VMULPS/VMULPD
          MP_NONE => { write_ymm(dst, vmulps_xmm(src1[255..128], src2[255..128]) @ vmulps_xmm(src1[127..0], src2[127..0])); Ok() },
          MP_66   => { write_ymm(dst, vmulpd_xmm(src1[255..128], src2[255..128]) @ vmulpd_xmm(src1[127..0], src2[127..0])); Ok() },
          _ => raise_UD(),
        },
        10 => if pfx.vex_vvvv != 0 then { raise_UD() } else match mp { // VCVTPS2PD/VCVTPD2PS (256-bit, vvvv reserved)
          MP_NONE => { // VCVTPS2PD: 4 floats -> 4 doubles
            let r3 = __f32_to_f64(src2[127..96]);
            let r2 = __f32_to_f64(src2[95..64]);
            let r1 = __f32_to_f64(src2[63..32]);
            let r0 = __f32_to_f64(src2[31..0]);
            write_ymm(dst, r3 @ r2 @ r1 @ r0);
            Ok()
          },
          MP_66 => { // VCVTPD2PS: 4 doubles -> 4 floats (in low 128)
            let r3 = __f64_to_f32(src2[255..192]);
            let r2 = __f64_to_f32(src2[191..128]);
            let r1 = __f64_to_f32(src2[127..64]);
            let r0 = __f64_to_f32(src2[63..0]);
            write_xmm(dst, r3 @ r2 @ r1 @ r0);
            Ok()
          },
          _ => raise_UD(),
        },
        12 => match mp { // VSUBPS/VSUBPD
          MP_NONE => { write_ymm(dst, vsubps_xmm(src1[255..128], src2[255..128]) @ vsubps_xmm(src1[127..0], src2[127..0])); Ok() },
          MP_66   => { write_ymm(dst, vsubpd_xmm(src1[255..128], src2[255..128]) @ vsubpd_xmm(src1[127..0], src2[127..0])); Ok() },
          _ => raise_UD(),
        },
        13 => match mp { // VMINPS/VMINPD
          MP_NONE => { write_ymm(dst, vminps_xmm(src1[255..128], src2[255..128]) @ vminps_xmm(src1[127..0], src2[127..0])); Ok() },
          MP_66   => { write_ymm(dst, vminpd_xmm(src1[255..128], src2[255..128]) @ vminpd_xmm(src1[127..0], src2[127..0])); Ok() },
          _ => raise_UD(),
        },
        14 => match mp { // VDIVPS/VDIVPD
          MP_NONE => { write_ymm(dst, vdivps_xmm(src1[255..128], src2[255..128]) @ vdivps_xmm(src1[127..0], src2[127..0])); Ok() },
          MP_66   => { write_ymm(dst, vdivpd_xmm(src1[255..128], src2[255..128]) @ vdivpd_xmm(src1[127..0], src2[127..0])); Ok() },
          _ => raise_UD(),
        },
        15 => match mp { // VMAXPS/VMAXPD
          MP_NONE => { write_ymm(dst, vmaxps_xmm(src1[255..128], src2[255..128]) @ vmaxps_xmm(src1[127..0], src2[127..0])); Ok() },
          MP_66   => { write_ymm(dst, vmaxpd_xmm(src1[255..128], src2[255..128]) @ vmaxpd_xmm(src1[127..0], src2[127..0])); Ok() },
          _ => raise_UD(),
        },
        _ => raise_UD(),
      }
    } else {
      // 128-bit XMM path (upper bits zeroed by write_xmm)
      let src1 : xmmword = read_xmm(pfx.vex_vvvv);
      let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
      match col {
        1 => match mp { // VSQRTPS/VSQRTPD/VSQRTSS/VSQRTSD
          MP_NONE => if pfx.vex_vvvv != 0 then { raise_UD() } else { write_xmm(dst, vsqrtps_xmm(src2)); Ok() },
          MP_66   => if pfx.vex_vvvv != 0 then { raise_UD() } else { write_xmm(dst, vsqrtpd_xmm(src2)); Ok() },
          MP_F3   => { write_xmm(dst, src1[127..32] @ __f32_sqrt(src2[31..0])); Ok() },
          MP_F2   => { write_xmm(dst, src1[127..64] @ __f64_sqrt(src2[63..0])); Ok() },
        },
        2 => match mp { // VRSQRTPS (NP, vvvv reserved) / VRSQRTSS (F3, scalar merge)
          MP_NONE => if pfx.vex_vvvv != 0 then { raise_UD() } else {
            write_xmm(dst, __f32_rsqrt(src2[127..96]) @ __f32_rsqrt(src2[95..64]) @
                           __f32_rsqrt(src2[63..32])  @ __f32_rsqrt(src2[31..0]));
            Ok()
          },
          MP_F3 => { write_xmm(dst, src1[127..32] @ __f32_rsqrt(src2[31..0])); Ok() },
          _ => raise_UD(),
        },
        3 => match mp { // VRCPPS (NP, vvvv reserved) / VRCPSS (F3, scalar merge)
          MP_NONE => if pfx.vex_vvvv != 0 then { raise_UD() } else {
            write_xmm(dst, __f32_rcp(src2[127..96]) @ __f32_rcp(src2[95..64]) @
                           __f32_rcp(src2[63..32])  @ __f32_rcp(src2[31..0]));
            Ok()
          },
          MP_F3 => { write_xmm(dst, src1[127..32] @ __f32_rcp(src2[31..0])); Ok() },
          _ => raise_UD(),
        },
        4 => match mp { // VANDPS/VANDPD
          _ => { write_xmm(dst, src1 & src2); Ok() },
        },
        5 => match mp { // VANDNPS/VANDNPD
          _ => { write_xmm(dst, ~(src1) & src2); Ok() },
        },
        6 => match mp { // VORPS/VORPD
          _ => { write_xmm(dst, src1 | src2); Ok() },
        },
        7 => match mp { // VXORPS/VXORPD
          _ => { write_xmm(dst, xor_vec(src1, src2)); Ok() },
        },
        8 => match mp { // VADDPS/VADDPD/VADDSS/VADDSD
          MP_NONE => { write_xmm(dst, vaddps_xmm(src1, src2)); Ok() },
          MP_66   => { write_xmm(dst, vaddpd_xmm(src1, src2)); Ok() },
          MP_F3   => { write_xmm(dst, src1[127..32] @ __f32_add(src1[31..0], src2[31..0])); Ok() },
          MP_F2   => { write_xmm(dst, src1[127..64] @ __f64_add(src1[63..0], src2[63..0])); Ok() },
        },
        9 => match mp { // VMULPS/VMULPD/VMULSS/VMULSD
          MP_NONE => { write_xmm(dst, vmulps_xmm(src1, src2)); Ok() },
          MP_66   => { write_xmm(dst, vmulpd_xmm(src1, src2)); Ok() },
          MP_F3   => { write_xmm(dst, src1[127..32] @ __f32_mul(src1[31..0], src2[31..0])); Ok() },
          MP_F2   => { write_xmm(dst, src1[127..64] @ __f64_mul(src1[63..0], src2[63..0])); Ok() },
        },
        11 => if pfx.vex_vvvv != 0 then { raise_UD() } else match mp { // VCVTDQ2PS/VCVTPS2DQ/VCVTTPS2DQ (unary, vvvv reserved)
          MP_NONE => { // VCVTDQ2PS
            write_xmm(dst, __int32_to_f32(src2[127..96]) @ __int32_to_f32(src2[95..64]) @
              __int32_to_f32(src2[63..32]) @ __int32_to_f32(src2[31..0]));
            Ok()
          },
          MP_66 => { // VCVTPS2DQ
            write_xmm(dst, __f32_to_int32(src2[127..96]) @ __f32_to_int32(src2[95..64]) @
              __f32_to_int32(src2[63..32]) @ __f32_to_int32(src2[31..0]));
            Ok()
          },
          MP_F3 => { // VCVTTPS2DQ
            write_xmm(dst, __f32_to_int32_trunc(src2[127..96]) @ __f32_to_int32_trunc(src2[95..64]) @
              __f32_to_int32_trunc(src2[63..32]) @ __f32_to_int32_trunc(src2[31..0]));
            Ok()
          },
          _ => raise_UD(),
        },
        10 => match mp { // VCVTPS2PD/VCVTPD2PS/VCVTSS2SD/VCVTSD2SS (128-bit)
          MP_NONE => // VCVTPS2PD: 2 floats -> 2 doubles (vvvv reserved)
            if pfx.vex_vvvv != 0 then { raise_UD() } else {
            let r1 = __f32_to_f64(src2[63..32]);
            let r0 = __f32_to_f64(src2[31..0]);
            write_xmm(dst, r1 @ r0);
            Ok()
          },
          MP_66 => // VCVTPD2PS: 2 doubles -> 2 floats (vvvv reserved)
            if pfx.vex_vvvv != 0 then { raise_UD() } else {
            let r1 = __f64_to_f32(src2[127..64]);
            let r0 = __f64_to_f32(src2[63..0]);
            write_xmm(dst, zeros(64) @ r1 @ r0);
            Ok()
          },
          MP_F3 => { // VCVTSS2SD: scalar float -> double
            write_xmm(dst, src1[127..64] @ __f32_to_f64(src2[31..0]));
            Ok()
          },
          MP_F2 => { // VCVTSD2SS: scalar double -> float
            write_xmm(dst, src1[127..32] @ __f64_to_f32(src2[63..0]));
            Ok()
          },
        },
        12 => match mp { // VSUBPS/VSUBPD/VSUBSS/VSUBSD
          MP_NONE => { write_xmm(dst, vsubps_xmm(src1, src2)); Ok() },
          MP_66   => { write_xmm(dst, vsubpd_xmm(src1, src2)); Ok() },
          MP_F3   => { write_xmm(dst, src1[127..32] @ __f32_sub(src1[31..0], src2[31..0])); Ok() },
          MP_F2   => { write_xmm(dst, src1[127..64] @ __f64_sub(src1[63..0], src2[63..0])); Ok() },
        },
        13 => match mp { // VMINPS/VMINPD/VMINSS/VMINSD
          MP_NONE => { write_xmm(dst, vminps_xmm(src1, src2)); Ok() },
          MP_66   => { write_xmm(dst, vminpd_xmm(src1, src2)); Ok() },
          MP_F3   => { write_xmm(dst, src1[127..32] @ __f32_min(src1[31..0], src2[31..0])); Ok() },
          MP_F2   => { write_xmm(dst, src1[127..64] @ __f64_min(src1[63..0], src2[63..0])); Ok() },
        },
        14 => match mp { // VDIVPS/VDIVPD/VDIVSS/VDIVSD
          MP_NONE => { write_xmm(dst, vdivps_xmm(src1, src2)); Ok() },
          MP_66   => { write_xmm(dst, vdivpd_xmm(src1, src2)); Ok() },
          MP_F3   => { write_xmm(dst, src1[127..32] @ __f32_div(src1[31..0], src2[31..0])); Ok() },
          MP_F2   => { write_xmm(dst, src1[127..64] @ __f64_div(src1[63..0], src2[63..0])); Ok() },
        },
        15 => match mp { // VMAXPS/VMAXPD/VMAXSS/VMAXSD
          MP_NONE => { write_xmm(dst, vmaxps_xmm(src1, src2)); Ok() },
          MP_66   => { write_xmm(dst, vmaxpd_xmm(src1, src2)); Ok() },
          MP_F3   => { write_xmm(dst, src1[127..32] @ __f32_max(src1[31..0], src2[31..0])); Ok() },
          MP_F2   => { write_xmm(dst, src1[127..64] @ __f64_max(src1[63..0], src2[63..0])); Ok() },
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
    let pred : bits(3) = imm[2..0];
    match mp {
      MP_NONE => { // VCMPPS
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
                          cmp_pred_f32(src1[31..0],    src2[31..0],    pred));
          Ok()
        } else {
          let src1 : xmmword = read_xmm(pfx.vex_vvvv);
          let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
          write_xmm(dst, cmp_pred_f32(src1[127..96], src2[127..96], pred) @
                          cmp_pred_f32(src1[95..64],  src2[95..64],  pred) @
                          cmp_pred_f32(src1[63..32],  src2[63..32],  pred) @
                          cmp_pred_f32(src1[31..0],   src2[31..0],   pred));
          Ok()
        }
      },
      MP_66 => { // VCMPPD
        if pfx.vex_l then {
          let src1 : ymmword = read_ymm(pfx.vex_vvvv);
          let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
          write_ymm(dst, cmp_pred_f64(src1[255..192], src2[255..192], pred) @
                          cmp_pred_f64(src1[191..128], src2[191..128], pred) @
                          cmp_pred_f64(src1[127..64],  src2[127..64],  pred) @
                          cmp_pred_f64(src1[63..0],    src2[63..0],    pred));
          Ok()
        } else {
          let src1 : xmmword = read_xmm(pfx.vex_vvvv);
          let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
          write_xmm(dst, cmp_pred_f64(src1[127..64], src2[127..64], pred) @
                          cmp_pred_f64(src1[63..0],   src2[63..0],   pred));
          Ok()
        }
      },
      MP_F3 => { // VCMPSS (scalar, VEX.L ignored)
        let src1 : xmmword = read_xmm(pfx.vex_vvvv);
        let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        write_xmm(dst, src1[127..32] @ cmp_pred_f32(src1[31..0], src2[31..0], pred));
        Ok()
      },
      MP_F2 => { // VCMPSD (scalar, VEX.L ignored)
        let src1 : xmmword = read_xmm(pfx.vex_vvvv);
        let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        write_xmm(dst, src1[127..64] @ cmp_pred_f64(src1[63..0], src2[63..0], pred));
        Ok()
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
      MP_NONE => { // VSHUFPS
        let s0 : range(0, 3) = unsigned(imm[1..0]);
        let s1 : range(0, 3) = unsigned(imm[3..2]);
        let s2 : range(0, 3) = unsigned(imm[5..4]);
        let s3 : range(0, 3) = unsigned(imm[7..6]);
        if pfx.vex_l then {
          // 256-bit: two independent 128-bit lane shuffles, same imm8
          let src1 : ymmword = read_ymm(pfx.vex_vvvv);
          let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
          // Low lane: select from src1[127..0] and src2[127..0]
          var r0 : dword = zeros(); var r1 : dword = zeros();
          var r2 : dword = zeros(); var r3 : dword = zeros();
          foreach (i from 0 to 3) {
            if i == s0 then r0 = src1[(32*i+31) .. (32*i)];
            if i == s1 then r1 = src1[(32*i+31) .. (32*i)];
            if i == s2 then r2 = src2[(32*i+31) .. (32*i)];
            if i == s3 then r3 = src2[(32*i+31) .. (32*i)];
          };
          // High lane: select from src1[255..128] and src2[255..128]
          var r4 : dword = zeros(); var r5 : dword = zeros();
          var r6 : dword = zeros(); var r7 : dword = zeros();
          foreach (i from 0 to 3) {
            if i == s0 then r4 = src1[(32*i+159) .. (32*i+128)];
            if i == s1 then r5 = src1[(32*i+159) .. (32*i+128)];
            if i == s2 then r6 = src2[(32*i+159) .. (32*i+128)];
            if i == s3 then r7 = src2[(32*i+159) .. (32*i+128)];
          };
          write_ymm(dst, r7 @ r6 @ r5 @ r4 @ r3 @ r2 @ r1 @ r0);
          Ok()
        } else {
          let src1 : xmmword = read_xmm(pfx.vex_vvvv);
          let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
          var r0 : dword = zeros(); var r1 : dword = zeros();
          var r2 : dword = zeros(); var r3 : dword = zeros();
          foreach (i from 0 to 3) {
            if i == s0 then r0 = src1[(32*i+31) .. (32*i)];
            if i == s1 then r1 = src1[(32*i+31) .. (32*i)];
            if i == s2 then r2 = src2[(32*i+31) .. (32*i)];
            if i == s3 then r3 = src2[(32*i+31) .. (32*i)];
          };
          write_xmm(dst, r3 @ r2 @ r1 @ r0);
          Ok()
        }
      },
      MP_66 => { // VSHUFPD
        if pfx.vex_l then {
          // 256-bit: 4 qwords, each selected by one imm8 bit
          let src1 : ymmword = read_ymm(pfx.vex_vvvv);
          let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
          let r0 : qword = if imm[0] == bitone then src1[127..64] else src1[63..0];
          let r1 : qword = if imm[1] == bitone then src2[127..64] else src2[63..0];
          let r2 : qword = if imm[2] == bitone then src1[255..192] else src1[191..128];
          let r3 : qword = if imm[3] == bitone then src2[255..192] else src2[191..128];
          write_ymm(dst, r3 @ r2 @ r1 @ r0);
          Ok()
        } else {
          let src1 : xmmword = read_xmm(pfx.vex_vvvv);
          let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
          let r0 : qword = if imm[0] == bitone then src1[127..64] else src1[63..0];
          let r1 : qword = if imm[1] == bitone then src2[127..64] else src2[63..0];
          write_xmm(dst, r1 @ r0);
          Ok()
        }
      },
      _ => raise_UD(),
    }
  },

  _ => raise_UD(),
  }
}

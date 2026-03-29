// x86-64 — VEX FP Instructions (0F map)
//
// Floating-point moves, arithmetic, compare, convert, shuffle, unpack.

val dispatch_vex_0f_fp : (range(0, 255), Prefixes) -> unit
function dispatch_vex_0f_fp(op, pfx) = {
  let mp = get_mandatory_prefix(pfx);

  match op {

  // 0F 10: VMOVUPS/VMOVUPD/VMOVSS/VMOVSD (load)
  16 => {
    let modrm = fetch(1);
    let dst = modrm_xreg(modrm, pfx);
    let src = modrm_xrm(modrm, pfx);
    match mp {
      // VMOVUPS (NP) / VMOVUPD (66) — vvvv reserved
      MP_NONE => {
        if pfx.vex_vvvv != 0 then raise_UD();
        let vl = vex_vl(pfx);
        write_simd(vl, dst, decode_vex_src(src))
      },
      MP_66 => {
        if pfx.vex_vvvv != 0 then raise_UD();
        let vl = vex_vl(pfx);
        write_simd(vl, dst, decode_vex_src(src))
      },
      // VMOVSS xmm1, xmm2, xmm3 or xmm1, m32
      // Memory form: VEX.vvvv must be 1111b.
      MP_F3 => {
        match src {
          XRM_reg(xi) => {
            // reg-reg: merge src2[127:32] with src3[31:0]
            let src2 : xmmword = read_simd(pfx.vex_vvvv);
            let src3 : xmmword = read_simd(xi);
            write_simd(128, dst, src2[127..32] @ src3[31..0])
          },
          XRM_mem(m) => {
            if pfx.vex_vvvv != 0 then raise_UD();
            let data : dword = v(m);
            write_simd(128, dst, zeros(96) @ data)
          },
        }
      },
      // VMOVSD xmm1, xmm2, xmm3 or xmm1, m64
      // Memory form: VEX.vvvv must be 1111b.
      MP_F2 => {
        match src {
          XRM_reg(xi) => {
            let src2 : xmmword = read_simd(pfx.vex_vvvv);
            let src3 : xmmword = read_simd(xi);
            write_simd(128, dst, src2[127..64] @ src3[63..0])
          },
          XRM_mem(m) => {
            if pfx.vex_vvvv != 0 then raise_UD();
            let data : qword = v(m);
            write_simd(128, dst, zeros(64) @ data)
          },
        }
      },
    }
  },

  // 0F 11: VMOVUPS/VMOVUPD/VMOVSS/VMOVSD (store)
  17 => {
    let modrm = fetch(1);
    let src = modrm_xreg(modrm, pfx);
    let dest = modrm_xrm(modrm, pfx);
    match mp {
      // VMOVUPS (NP) / VMOVUPD (66) — vvvv reserved
      MP_NONE => {
        if pfx.vex_vvvv != 0 then raise_UD();
        let vl = vex_vl(pfx);
        match dest {
          XRM_reg(xi) => write_simd(vl, xi, read_simd(vl, src)),
          XRM_mem(m)  => write_mem(m, read_simd(vl, src)),
        }
      },
      MP_66 => {
        if pfx.vex_vvvv != 0 then raise_UD();
        let vl = vex_vl(pfx);
        match dest {
          XRM_reg(xi) => write_simd(vl, xi, read_simd(vl, src)),
          XRM_mem(m)  => write_mem(m, read_simd(vl, src)),
        }
      },
      // VMOVSS xmm1, xmm2, xmm3 or VMOVSS m32, xmm1
      // Memory form: VEX.vvvv must be 1111b.
      MP_F3 => {
        match dest {
          XRM_reg(xi) => {
            let src2 : xmmword = read_simd(pfx.vex_vvvv);
            let src3 : xmmword = read_simd(src);
            write_simd(128, xi, src2[127..32] @ src3[31..0])
          },
          XRM_mem(m) => {
            if pfx.vex_vvvv != 0 then raise_UD();
            v(m) = read_simd(128, src)[31..0]
          },
        }
      },
      // VMOVSD xmm1, xmm2, xmm3 or VMOVSD m64, xmm1
      // Memory form: VEX.vvvv must be 1111b.
      MP_F2 => {
        match dest {
          XRM_reg(xi) => {
            let src2 : xmmword = read_simd(pfx.vex_vvvv);
            let src3 : xmmword = read_simd(src);
            write_simd(128, xi, src2[127..64] @ src3[63..0])
          },
          XRM_mem(m) => {
            if pfx.vex_vvvv != 0 then raise_UD();
            v(m) = read_simd(128, src)[63..0]
          },
        }
      },
    }
  },

  // 0F 12: VMOVLPS/VMOVHLPS (NP) / VMOVLPD (66) / VMOVSLDUP (F3) / VMOVDDUP (F2)
  18 => {
    let modrm = fetch(1);
    let dst = modrm_xreg(modrm, pfx);
    let src2 = modrm_xrm(modrm, pfx);
    match mp {
      MP_NONE => {
        match src2 {
          // VMOVHLPS: dst[63:0] = src2[127:64], dst[127:64] = vvvv[127:64]
          XRM_reg(xi) => {
            let src1 : xmmword = read_simd(pfx.vex_vvvv);
            let src2 : xmmword = read_simd(xi);
            write_simd(128, dst, src1[127..64] @ src2[127..64])
          },
          // VMOVLPS: dst[63:0] = m64, dst[127:64] = vvvv[127:64]
          XRM_mem(m) => {
            let src1 : xmmword = read_simd(pfx.vex_vvvv);
            let data : qword = v(m);
            write_simd(128, dst, src1[127..64] @ data)
          },
        }
      },
      // VMOVLPD xmm1, xmm2, m64: DEST[63:0] := SRC2[63:0]; DEST[127:64] := SRC1[127:64]
      MP_66 => {
        match src2 {
          XRM_mem(m) => {
            let src1 : xmmword = read_simd(pfx.vex_vvvv);
            let data : qword = v(m);
            write_simd(128, dst, src1[127..64] @ data)
          },
          _ => raise_UD(),
        }
      },
      // VMOVSLDUP: per-lane, duplicate even-indexed dwords [d1,d1,d0,d0]
      MP_F3 => {
        if pfx.vex_vvvv != 0 then raise_UD();
        let vl = vex_vl(pfx);
        let src = decode_vex_src(vl, src2);
        var r : ymmword = zeros();
        foreach (i from 0 to (vl / 64 - 1)) {
          let lo = i * 64;
          r[(lo + 63)..(lo + 32)] = src[(lo + 31)..lo];
          r[(lo + 31)..lo] = src[(lo + 31)..lo]
        };
        write_simd(vl, dst, r[(vl - 1)..0])
      },
      // VMOVDDUP: per-lane, duplicate low qword [q0,q0]
      MP_F2 => {
        if pfx.vex_vvvv != 0 then raise_UD();
        let vl = vex_vl(pfx);
        let src = decode_vex_src(vl, src2);
        var r : ymmword = zeros();
        foreach (i from 0 to (vl / 128 - 1)) {
          let lo = i * 128;
          r[(lo + 127)..(lo + 64)] = src[(lo + 63)..lo];
          r[(lo + 63)..lo] = src[(lo + 63)..lo]
        };
        write_simd(vl, dst, r[(vl - 1)..0])
      },
    }
  },

  // 0F 13: VMOVLPS/VMOVLPD m64, xmm (store low 64 bits to memory)
  19 => {
    if pfx.vex_l | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch(1);
    let src = modrm_xreg(modrm, pfx);
    let dest = modrm_rm(modrm, pfx);
    rm_mem(64, dest) = read_simd(128, src)[63..0]
  },

  // 0F 14: VUNPCKLPS (NP) / VUNPCKLPD (66)
  20 => match mp {
    MP_NONE => vex_exec_unpack(32,  0, pfx),
    MP_66   => vex_exec_unpack(64,  0, pfx),
    _       => raise_UD(),
  },
  // 0F 15: VUNPCKHPS (NP) / VUNPCKHPD (66)
  21 => match mp {
    MP_NONE => vex_exec_unpack(32, 64, pfx),
    MP_66   => vex_exec_unpack(64, 64, pfx),
    _       => raise_UD(),
  },

  // 0F 16: VMOVHPS/VMOVLHPS (NP) / VMOVHPD (66) / VMOVSHDUP (F3)
  22 => {
    let modrm = fetch(1);
    let dst = modrm_xreg(modrm, pfx);
    let src2 = modrm_xrm(modrm, pfx);
    match mp {
      MP_NONE => {
        match src2 {
          // VMOVLHPS: dst[127:64] = src2[63:0], dst[63:0] = vvvv[63:0]
          XRM_reg(xi) => {
            let src1 : xmmword = read_simd(pfx.vex_vvvv);
            let src2 : xmmword = read_simd(xi);
            write_simd(128, dst, src2[63..0] @ src1[63..0])
          },
          // VMOVHPS: dst[63:0] = vvvv[63:0], dst[127:64] = m64
          XRM_mem(m) => {
            let src1 : xmmword = read_simd(pfx.vex_vvvv);
            let data : qword = v(m);
            write_simd(128, dst, data @ src1[63..0])
          },
        }
      },
      // VMOVHPD xmm1, xmm2, m64: DEST[63:0] := SRC1[63:0]; DEST[127:64] := SRC2[63:0]
      MP_66 => {
        match src2 {
          XRM_mem(m) => {
            let src1 : xmmword = read_simd(pfx.vex_vvvv);
            let data : qword = v(m);
            write_simd(128, dst, data @ src1[63..0])
          },
          _ => raise_UD(),
        }
      },
      MP_F2 => raise_UD(),
      // VMOVSHDUP: per-lane, duplicate odd-indexed dwords [d1,d1,d0,d0] from high halves
      MP_F3 => {
        if pfx.vex_vvvv != 0 then raise_UD();
        let vl = vex_vl(pfx);
        let src = decode_vex_src(vl, src2);
        var r : ymmword = zeros();
        foreach (i from 0 to (vl / 64 - 1)) {
          let lo = i * 64;
          r[(lo + 63)..(lo + 32)] = src[(lo + 63)..(lo + 32)];
          r[(lo + 31)..lo] = src[(lo + 63)..(lo + 32)]
        };
        write_simd(vl, dst, r[(vl - 1)..0])
      },
    }
  },

  // 0F 17: VMOVHPS/VMOVHPD m64, xmm (store high 64 bits to memory)
  23 => {
    if pfx.vex_l | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch(1);
    let src = modrm_xreg(modrm, pfx);
    let dest = modrm_rm(modrm, pfx);
    rm_mem(64, dest) = read_simd(128, src)[127..64]
  },

  // 0F 28: VMOVAPS/VMOVAPD (load, vvvv reserved)
  40 => {
    if pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xreg(modrm, pfx);
    let src = modrm_xrm(modrm, pfx);
    let vl = vex_vl(pfx);
    match src {
      XRM_reg(xi) => write_simd(vl, dst, read_simd(vl, xi)),
      XRM_mem(m) => {
        let align : {16, 32} = if pfx.vex_l then 32 else 16;
        if unsigned(seg_linear(m, 0)) % align != 0 then raise_GP0();
        write_simd(vl, dst, read_mem(m))
      },
    }
  },

  // 0F 29: VMOVAPS/VMOVAPD (store, vvvv reserved)
  41 => {
    if pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch(1);
    let src = modrm_xreg(modrm, pfx);
    let dest = modrm_xrm(modrm, pfx);
    let vl = vex_vl(pfx);
    match dest {
      XRM_reg(xi) => write_simd(vl, xi, read_simd(vl, src)),
      XRM_mem(m) => {
        let align : {16, 32} = if pfx.vex_l then 32 else 16;
        if unsigned(seg_linear(m, 0)) % align != 0 then raise_GP0();
        write_mem(m, read_simd(vl, src))
      },
    }
  },

  // 0F 2A: VCVTSI2SS (F3) / VCVTSI2SD (F2) — int to scalar float
  42 => {
    let modrm = fetch(1);
    let dst = modrm_xreg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    let src1 : xmmword = read_simd(pfx.vex_vvvv);
    match mp {
      // VCVTSI2SS xmm1, xmm2, r/m32
      MP_F3 => {
        if pfx.vex_w then {
          let x : qword = v(src);
          write_simd(128, dst, src1[127..32] @ __int64_to_f32(x));
        } else {
          let x : dword = v(src);
          write_simd(128, dst, src1[127..32] @ __int32_to_f32(x));
        }
      },
      // VCVTSI2SD xmm1, xmm2, r/m32
      MP_F2 => {
        if pfx.vex_w then {
          let x : qword = v(src);
          write_simd(128, dst, src1[127..64] @ __int64_to_f64(x));
        } else {
          let x : dword = v(src);
          write_simd(128, dst, src1[127..64] @ __int32_to_f64(x));
        }
      },
      _ => raise_UD(),
    }
  },

  // 0F 2B: VMOVNTPS/VMOVNTPD m, xmm/ymm (non-temporal store; we treat as regular store)
  // SDM: requires alignment (32 for YMM, 16 for XMM); #GP(0) if unaligned.
  43 => {
    if pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch(1);
    let src = modrm_xreg(modrm, pfx);
    let dest = modrm_xrm(modrm, pfx);
    match dest {
      XRM_mem(m) => {
        if pfx.vex_l then {
          if unsigned(seg_linear(m, 0)) % 32 != 0 then raise_GP0();
          write_mem(m, read_simd(256, src))
        } else {
          if unsigned(seg_linear(m, 0)) % 16 != 0 then raise_GP0();
          write_mem(m, read_simd(128, src))
        }
      },
      XRM_reg(_) => raise_UD(),
    }
  },

  // 0F 2C: VCVTTSS2SI (F3) / VCVTTSD2SI (F2) — truncating scalar float to int
  44 => {
    let modrm = fetch(1);
    let src2 = modrm_xrm(modrm, pfx);
    let dst_gpr = modrm_reg(modrm, pfx);
    match mp {
      // VCVTTSS2SI r32/r64, xmm1/m32
      MP_F3 => {
        let src : dword = match src2 {
          XRM_reg(xi) => read_simd(128, xi)[31..0],
          XRM_mem(m)  => v(m),
        };
        if pfx.vex_w then v(dst_gpr) = __f32_to_int64_trunc(src)
        else v(dst_gpr) = __f32_to_int32_trunc(src)
      },
      // VCVTTSD2SI r32/r64, xmm1/m64
      MP_F2 => {
        let src : qword = match src2 {
          XRM_reg(xi) => read_simd(128, xi)[63..0],
          XRM_mem(m)  => v(m),
        };
        if pfx.vex_w then v(dst_gpr) = __f64_to_int64_trunc(src)
        else v(dst_gpr) = __f64_to_int32_trunc(src)
      },
      _ => raise_UD(),
    }
  },

  // 0F 2D: VCVTSS2SI (F3) / VCVTSD2SI (F2) — scalar FP to int with rounding
  45 => {
    let modrm = fetch(1);
    let reg = modrm_reg(modrm, pfx);
    let src2 = modrm_xrm(modrm, pfx);
    match mp {
      MP_F3 => {
        let src : dword = match src2 {
          XRM_reg(xi) => read_simd(128, xi)[31..0],
          XRM_mem(m)  => v(m),
        };
        if pfx.vex_w then
          v(reg) = __f32_to_int64(src)
        else
          v(reg) = __f32_to_int32(src)
      },
      MP_F2 => {
        let src : qword = match src2 {
          XRM_reg(xi) => read_simd(128, xi)[63..0],
          XRM_mem(m)  => v(m),
        };
        if pfx.vex_w then
          v(reg) = __f64_to_int64(src)
        else
          v(reg) = __f64_to_int32(src)
      },
      _ => raise_UD(),
    }
  },

  // 0F 2E: VUCOMISS (NP) / VUCOMISD (66) — unordered compare scalars, set EFLAGS
  // SDM: VEX.vvvv must be 1111b
  46 => {
    if pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch(1);
    let src_reg = modrm_xreg(modrm, pfx);
    let src2 = modrm_xrm(modrm, pfx);
    match mp {
      // VUCOMISS xmm1, xmm2/m32
      MP_NONE => {
        let src : xmmword = match src2 {
          XRM_reg(xi) => read_simd(xi),
          XRM_mem(m)  => zero_extend(v(32, m)),
        };
        let a : dword = read_simd(128, src_reg)[31..0];
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
        let src : xmmword = match src2 {
          XRM_reg(xi) => read_simd(xi),
          XRM_mem(m)  => zero_extend(v(64, m)),
        };
        let a : qword = read_simd(128, src_reg)[63..0];
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

  // 0F 2F: VCOMISS (NP) / VCOMISD (66) — ordered compare scalars, set EFLAGS
  // SDM: VEX.vvvv must be 1111b
  47 => {
    if pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch(1);
    let src_reg = modrm_xreg(modrm, pfx);
    let src2 = modrm_xrm(modrm, pfx);
    match mp {
      // VCOMISS xmm1, xmm2/m32
      MP_NONE => {
        let src : xmmword = match src2 {
          XRM_reg(xi) => read_simd(xi),
          XRM_mem(m)  => zero_extend(v(32, m)),
        };
        let a : dword = read_simd(128, src_reg)[31..0];
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
        let src : xmmword = match src2 {
          XRM_reg(xi) => read_simd(xi),
          XRM_mem(m)  => zero_extend(v(64, m)),
        };
        let a : qword = read_simd(128, src_reg)[63..0];
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

  // 0F 50: VMOVMSKPS (NP) / VMOVMSKPD (66) — extract sign bits to GPR
  80 => {
    let modrm = fetch(1);
    let reg = modrm_reg(modrm, pfx);
    let xi = xrm_reg(modrm_xrm(modrm, pfx));
    if pfx.vex_vvvv != 0 then raise_UD();
    match mp {
      MP_NONE => {
        if pfx.vex_l then {
          let src : ymmword = read_simd(xi);
          let mask : byte = src[255] @ src[223] @ src[191] @ src[159] @
                            src[127] @ src[95] @ src[63] @ src[31];
          v(reg) = zero_extend(32, mask)
        } else {
          let src : xmmword = read_simd(xi);
          let mask : bits(4) = src[127] @ src[95] @ src[63] @ src[31];
          v(reg) = zero_extend(32, mask)
        }
      },
      MP_66 => {
        if pfx.vex_l then {
          let src : ymmword = read_simd(xi);
          let mask : bits(4) = src[255] @ src[191] @ src[127] @ src[63];
          v(reg) = zero_extend(32, mask)
        } else {
          let src : xmmword = read_simd(xi);
          let mask : bits(2) = src[127] @ src[63];
          v(reg) = zero_extend(32, mask)
        }
      },
      _ => raise_UD(),
    }
  },

  // 0F 50-5F: Packed arithmetic (columns 1-15, column 0 handled above)
  // Common pattern: dst = vvvv OP src (3-operand)
  // Packed variants (NP/66) support 128/256-bit via VEX.L; scalar variants (F3/F2) are 128-bit only.
  op if 81 <= op & op <= 95 => {
    let modrm = fetch(1);
    let dst = modrm_xreg(modrm, pfx);
    let src = modrm_xrm(modrm, pfx);
    let col : range(0, 15) = op - 80;
    let vl = vex_vl(pfx);
    // Read at full vector length; scalar ops only access low bits
    let src1 : ymmword = read_simd(256, pfx.vex_vvvv);
    let src2 : ymmword = decode_vex_src(256, src);
    match col {
      // VSQRTPS/VSQRTPD/VSQRTSS/VSQRTSD
      1 => match mp {
        MP_NONE => { if pfx.vex_vvvv != 0 then raise_UD(); write_simd(vl, dst, packed_unop(PU_FSqrt, 32, src2[(vl-1)..0])) },
        MP_66   => { if pfx.vex_vvvv != 0 then raise_UD(); write_simd(vl, dst, packed_unop(PU_FSqrt, 64, src2[(vl-1)..0])) },
        MP_F3   => write_simd(128, dst, src1[127..32] @ fp_sqrt(src2[31..0])),
        MP_F2   => write_simd(128, dst, src1[127..64] @ fp_sqrt(src2[63..0])),
      },
      // VRSQRTPS (NP) / VRSQRTSS (F3)
      2 => match mp {
        MP_NONE => { if pfx.vex_vvvv != 0 then raise_UD(); write_simd(vl, dst, packed_unop(PU_FRsqrt, 32, src2[(vl-1)..0])) },
        MP_F3   => write_simd(128, dst, src1[127..32] @ fp_rsqrt(src2[31..0])),
        _       => raise_UD(),
      },
      // VRCPPS (NP) / VRCPSS (F3)
      3 => match mp {
        MP_NONE => { if pfx.vex_vvvv != 0 then raise_UD(); write_simd(vl, dst, packed_unop(PU_FRcp, 32, src2[(vl-1)..0])) },
        MP_F3   => write_simd(128, dst, src1[127..32] @ fp_rcp(src2[31..0])),
        _       => raise_UD(),
      },
      // VANDPS/VANDPD
      4 => write_simd(vl, dst, src1[(vl-1)..0] & src2[(vl-1)..0]),
      // VANDNPS/VANDNPD
      5 => write_simd(vl, dst, ~(src1[(vl-1)..0]) & src2[(vl-1)..0]),
      // VORPS/VORPD
      6 => write_simd(vl, dst, src1[(vl-1)..0] | src2[(vl-1)..0]),
      // VXORPS/VXORPD
      7 => write_simd(vl, dst, src1[(vl-1)..0] ^ src2[(vl-1)..0]),
      // VADDPS/VADDPD/VADDSS/VADDSD
      8 => match mp {
        MP_NONE => write_simd(vl, dst, packed_binop(PB_FAdd, 32, src1[(vl-1)..0], src2[(vl-1)..0])),
        MP_66   => write_simd(vl, dst, packed_binop(PB_FAdd, 64, src1[(vl-1)..0], src2[(vl-1)..0])),
        MP_F3   => write_simd(128, dst, src1[127..32] @ fp_add(src1[31..0], src2[31..0])),
        MP_F2   => write_simd(128, dst, src1[127..64] @ fp_add(src1[63..0], src2[63..0])),
      },
      // VMULPS/VMULPD/VMULSS/VMULSD
      9 => match mp {
        MP_NONE => write_simd(vl, dst, packed_binop(PB_FMul, 32, src1[(vl-1)..0], src2[(vl-1)..0])),
        MP_66   => write_simd(vl, dst, packed_binop(PB_FMul, 64, src1[(vl-1)..0], src2[(vl-1)..0])),
        MP_F3   => write_simd(128, dst, src1[127..32] @ fp_mul(src1[31..0], src2[31..0])),
        MP_F2   => write_simd(128, dst, src1[127..64] @ fp_mul(src1[63..0], src2[63..0])),
      },
      // VCVTPS2PD/VCVTPD2PS/VCVTSS2SD/VCVTSD2SS
      10 => match mp {
        // VCVTPS2PD: N floats -> N doubles (vvvv reserved)
        MP_NONE => {
          if pfx.vex_vvvv != 0 then raise_UD();
          var r : ymmword = zeros();
          let n : {2, 4} = if pfx.vex_l then 4 else 2;
          foreach (i from 0 to (n - 1)) {
            r[(i * 64 + 63)..(i * 64)] = __f32_to_f64(src2[(i * 32 + 31)..(i * 32)])
          };
          write_simd(vl, dst, r[(vl - 1)..0])
        },
        // VCVTPD2PS: N doubles -> N floats (vvvv reserved)
        MP_66 => {
          if pfx.vex_vvvv != 0 then raise_UD();
          let n : {2, 4} = if pfx.vex_l then 4 else 2;
          var r : xmmword = zeros();
          foreach (i from 0 to (n - 1)) {
            r[(i * 32 + 31)..(i * 32)] = __f64_to_f32(src2[(i * 64 + 63)..(i * 64)])
          };
          write_simd(128, dst, r)
        },
        // VCVTSS2SD: scalar float -> double
        MP_F3 => write_simd(128, dst, src1[127..64] @ __f32_to_f64(src2[31..0])),
        // VCVTSD2SS: scalar double -> float
        MP_F2 => write_simd(128, dst, src1[127..32] @ __f64_to_f32(src2[63..0])),
      },
      // VCVTDQ2PS/VCVTPS2DQ/VCVTTPS2DQ
      11 => {
        if pfx.vex_vvvv != 0 then raise_UD();
        match mp {
          MP_NONE => write_simd(vl, dst, packed_unop(PU_CvtDQ2PS,  32, src2[(vl-1)..0])),
          MP_66   => write_simd(vl, dst, packed_unop(PU_CvtPS2DQ,  32, src2[(vl-1)..0])),
          MP_F3   => write_simd(vl, dst, packed_unop(PU_CvtTPS2DQ, 32, src2[(vl-1)..0])),
          _       => raise_UD(),
        }
      },
      // VSUBPS/VSUBPD/VSUBSS/VSUBSD
      12 => match mp {
        MP_NONE => write_simd(vl, dst, packed_binop(PB_FSub, 32, src1[(vl-1)..0], src2[(vl-1)..0])),
        MP_66   => write_simd(vl, dst, packed_binop(PB_FSub, 64, src1[(vl-1)..0], src2[(vl-1)..0])),
        MP_F3   => write_simd(128, dst, src1[127..32] @ fp_sub(src1[31..0], src2[31..0])),
        MP_F2   => write_simd(128, dst, src1[127..64] @ fp_sub(src1[63..0], src2[63..0])),
      },
      // VMINPS/VMINPD/VMINSS/VMINSD
      13 => match mp {
        MP_NONE => write_simd(vl, dst, packed_binop(PB_FMin, 32, src1[(vl-1)..0], src2[(vl-1)..0])),
        MP_66   => write_simd(vl, dst, packed_binop(PB_FMin, 64, src1[(vl-1)..0], src2[(vl-1)..0])),
        MP_F3   => write_simd(128, dst, src1[127..32] @ fp_min(src1[31..0], src2[31..0])),
        MP_F2   => write_simd(128, dst, src1[127..64] @ fp_min(src1[63..0], src2[63..0])),
      },
      // VDIVPS/VDIVPD/VDIVSS/VDIVSD
      14 => match mp {
        MP_NONE => write_simd(vl, dst, packed_binop(PB_FDiv, 32, src1[(vl-1)..0], src2[(vl-1)..0])),
        MP_66   => write_simd(vl, dst, packed_binop(PB_FDiv, 64, src1[(vl-1)..0], src2[(vl-1)..0])),
        MP_F3   => write_simd(128, dst, src1[127..32] @ fp_div(src1[31..0], src2[31..0])),
        MP_F2   => write_simd(128, dst, src1[127..64] @ fp_div(src1[63..0], src2[63..0])),
      },
      // VMAXPS/VMAXPD/VMAXSS/VMAXSD
      15 => match mp {
        MP_NONE => write_simd(vl, dst, packed_binop(PB_FMax, 32, src1[(vl-1)..0], src2[(vl-1)..0])),
        MP_66   => write_simd(vl, dst, packed_binop(PB_FMax, 64, src1[(vl-1)..0], src2[(vl-1)..0])),
        MP_F3   => write_simd(128, dst, src1[127..32] @ fp_max(src1[31..0], src2[31..0])),
        MP_F2   => write_simd(128, dst, src1[127..64] @ fp_max(src1[63..0], src2[63..0])),
      },
      _ => raise_UD(),
    }
  },

  // 0F C2: VCMPPS/VCMPPD/VCMPSS/VCMPSD imm8
  194 => {
    let modrm = fetch(1);
    let dst = modrm_xreg(modrm, pfx);
    let src = modrm_xrm(modrm, pfx);
    let imm = fetch(1);
    let pred : bits(5) = imm[4..0];
    match mp {
      // VCMPPS xmm1/ymm1, xmm2/ymm2, xmm3/ymm3/m128/m256, imm8
      MP_NONE => {
        let vl = vex_vl(pfx);
        write_simd(vl, dst, packed_cmp_pred(32, read_simd(vl, pfx.vex_vvvv), decode_vex_src(src), pred))
      },
      // VCMPPD xmm1/ymm1, xmm2/ymm2, xmm3/ymm3/m128/m256, imm8
      MP_66 => {
        let vl = vex_vl(pfx);
        write_simd(vl, dst, packed_cmp_pred(64, read_simd(vl, pfx.vex_vvvv), decode_vex_src(src), pred))
      },
      // VCMPSS (scalar, VEX.L ignored)
      MP_F3 => {
        let src1 : xmmword = read_simd(pfx.vex_vvvv);
        let src2 : xmmword = decode_vex_src(128, src);
        write_simd(128, dst, src1[127..32] @ cmp_pred(src1[31..0], src2[31..0], pred))
      },
      // VCMPSD (scalar, VEX.L ignored)
      MP_F2 => {
        let src1 : xmmword = read_simd(pfx.vex_vvvv);
        let src2 : xmmword = decode_vex_src(128, src);
        write_simd(128, dst, src1[127..64] @ cmp_pred(src1[63..0], src2[63..0], pred))
      },
    }
  },

  // 0F C6: VSHUFPS (NP) / VSHUFPD (66) imm8
  198 => {
    let modrm = fetch(1);
    let dst = modrm_xreg(modrm, pfx);
    let src = modrm_xrm(modrm, pfx);
    let imm = fetch(1);
    match mp {
      // VSHUFPS xmm1/ymm1, xmm2/ymm2, xmm3/ymm3/m128/m256, imm8
      MP_NONE => {
        let s0 : range(0, 3) = unsigned(imm[1..0]);
        let s1 : range(0, 3) = unsigned(imm[3..2]);
        let s2 : range(0, 3) = unsigned(imm[5..4]);
        let s3 : range(0, 3) = unsigned(imm[7..6]);
        if pfx.vex_l then {
          // 256-bit: two independent 128-bit lane shuffles, same imm8
          let src1 : ymmword = read_simd(pfx.vex_vvvv);
          let src2 : ymmword = decode_vex_src(256, src);
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
          write_simd(256, dst, r7 @ r6 @ r5 @ r4 @ r3 @ r2 @ r1 @ r0)
        } else {
          let src1 : xmmword = read_simd(pfx.vex_vvvv);
          let src2 : xmmword = decode_vex_src(128, src);
          let r0 : dword = src1[(32*s0+31) .. (32*s0)];
          let r1 : dword = src1[(32*s1+31) .. (32*s1)];
          let r2 : dword = src2[(32*s2+31) .. (32*s2)];
          let r3 : dword = src2[(32*s3+31) .. (32*s3)];
          write_simd(128, dst, r3 @ r2 @ r1 @ r0)
        }
      },
      // VSHUFPD xmm1/ymm1, xmm2/ymm2, xmm3/ymm3/m128/m256, imm8
      MP_66 => {
        if pfx.vex_l then {
          // 256-bit: 4 qwords, each selected by one imm8 bit
          let src1 : ymmword = read_simd(pfx.vex_vvvv);
          let src2 : ymmword = decode_vex_src(256, src);
          let r0 : qword = blend(src1[63..0],    src1[127..64],  imm[0]);
          let r1 : qword = blend(src2[63..0],    src2[127..64],  imm[1]);
          let r2 : qword = blend(src1[191..128], src1[255..192], imm[2]);
          let r3 : qword = blend(src2[191..128], src2[255..192], imm[3]);
          write_simd(256, dst, r3 @ r2 @ r1 @ r0)
        } else {
          let src1 : xmmword = read_simd(pfx.vex_vvvv);
          let src2 : xmmword = decode_vex_src(128, src);
          let r0 : qword = blend(src1[63..0], src1[127..64], imm[0]);
          let r1 : qword = blend(src2[63..0], src2[127..64], imm[1]);
          write_simd(128, dst, r1 @ r0)
        }
      },
      _ => raise_UD(),
    }
  },

  _ => raise_UD(),
  }
}

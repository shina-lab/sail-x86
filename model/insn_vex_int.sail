// x86-64 — VEX Integer Instructions (0F map)
//
// Integer moves, arithmetic, logical, compare, shuffle, insert/extract,
// mask register ops, VZEROUPPER/VZEROALL.

val dispatch_vex_0f_int : (range(0, 255), Prefixes) -> unit
function dispatch_vex_0f_int(op, pfx) = {
  let mp = get_mandatory_prefix(pfx);

  match op {

  // 0F 41: KANDW k1, k2, k3 (NP, W0)
  65 => {
    let modrm = fetch_byte();
    let k1 : range(0, 7) = unsigned(modrm[5..3]);
    let k2 : range(0, 7) = pfx.vex_vvvv % 8;
    let k3 : range(0, 7) = unsigned(modrm[2..0]);
    let result : qword = read_kreg(k2) & read_kreg(k3);
    write_kreg(k1, zero_extend(result[15..0]))
  },

  // 0F 42: KANDNW k1, k2, k3 (NP, W0)
  66 => {
    let modrm = fetch_byte();
    let k1 : range(0, 7) = unsigned(modrm[5..3]);
    let k2 : range(0, 7) = pfx.vex_vvvv % 8;
    let k3 : range(0, 7) = unsigned(modrm[2..0]);
    let result : qword = ~(read_kreg(k2)) & read_kreg(k3);
    write_kreg(k1, zero_extend(result[15..0]))
  },

  // 0F 44: KNOTW k1, k2 (NP, W0)
  68 => {
    let modrm = fetch_byte();
    let k1 : range(0, 7) = unsigned(modrm[5..3]);
    let k2 : range(0, 7) = unsigned(modrm[2..0]);
    write_kreg(k1, zero_extend(~(read_kreg(k2)[15..0])))
  },

  // 0F 45: KORW k1, k2, k3 (NP, W0)
  69 => {
    let modrm = fetch_byte();
    let k1 : range(0, 7) = unsigned(modrm[5..3]);
    let k2 : range(0, 7) = pfx.vex_vvvv % 8;
    let k3 : range(0, 7) = unsigned(modrm[2..0]);
    let result : qword = read_kreg(k2) | read_kreg(k3);
    write_kreg(k1, zero_extend(result[15..0]))
  },

  // 0F 46: KXNORW k1, k2, k3 (NP, W0)
  70 => {
    let modrm = fetch_byte();
    let k1 : range(0, 7) = unsigned(modrm[5..3]);
    let k2 : range(0, 7) = pfx.vex_vvvv % 8;
    let k3 : range(0, 7) = unsigned(modrm[2..0]);
    let result : qword = ~(xor_vec(read_kreg(k2), read_kreg(k3)));
    write_kreg(k1, zero_extend(result[15..0]))
  },

  // 0F 47: KXORW k1, k2, k3 (NP, W0)
  71 => {
    let modrm = fetch_byte();
    let k1 : range(0, 7) = unsigned(modrm[5..3]);
    let k2 : range(0, 7) = pfx.vex_vvvv % 8;
    let k3 : range(0, 7) = unsigned(modrm[2..0]);
    let result : qword = xor_vec(read_kreg(k2), read_kreg(k3));
    write_kreg(k1, zero_extend(result[15..0]))
  },

  // 0F 4A: KADDW k1, k2, k3 (NP, W0)
  74 => {
    let modrm = fetch_byte();
    let k1 : range(0, 7) = unsigned(modrm[5..3]);
    let k2 : range(0, 7) = pfx.vex_vvvv % 8;
    let k3 : range(0, 7) = unsigned(modrm[2..0]);
    let sum : bits(16) = read_kreg(k2)[15..0] + read_kreg(k3)[15..0];
    write_kreg(k1, zero_extend(sum))
  },

  // 0F 4B: KUNPCKBW / KUNPCKWD
  75 => {
    let modrm = fetch_byte();
    let k1 : range(0, 7) = unsigned(modrm[5..3]);
    let k2 : range(0, 7) = pfx.vex_vvvv % 8;
    let k3 : range(0, 7) = unsigned(modrm[2..0]);
    match mp {
      MP_66 => {
        // KUNPCKBW k1, k2, k3 (66, W0) — byte → word
        let result : bits(16) = read_kreg(k2)[7..0] @ read_kreg(k3)[7..0];
        write_kreg(k1, zero_extend(result))
      },
      MP_NONE => {
        // KUNPCKWD k1, k2, k3 (NP, W0) — word → dword
        let result : bits(32) = read_kreg(k2)[15..0] @ read_kreg(k3)[15..0];
        write_kreg(k1, zero_extend(result))
      },
      _ => raise_UD()
    }
  },

  // 0F 60: VPUNPCKLBW (66 prefix)
  96 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let s1 : ymmword = read_ymm(pfx.vex_vvvv);
      let s2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      write_ymm(dst, vex_punpcklbw_128(s1[255..128], s2[255..128]) @ vex_punpcklbw_128(s1[127..0], s2[127..0]))
    } else {
      write_xmm(dst, vex_punpcklbw_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)))
    }
  },

  // 0F 61: VPUNPCKLWD (66 prefix)
  97 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let s1 : ymmword = read_ymm(pfx.vex_vvvv);
      let s2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      write_ymm(dst, vex_punpcklwd_128(s1[255..128], s2[255..128]) @ vex_punpcklwd_128(s1[127..0], s2[127..0]))
    } else {
      write_xmm(dst, vex_punpcklwd_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)))
    }
  },

  // 0F 62: VPUNPCKLDQ (66 prefix)
  98 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let s1 : ymmword = read_ymm(pfx.vex_vvvv);
      let s2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      write_ymm(dst, vex_punpckldq_128(s1[255..128], s2[255..128]) @ vex_punpckldq_128(s1[127..0], s2[127..0]))
    } else {
      write_xmm(dst, vex_punpckldq_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)))
    }
  },

  // 0F 63: VPACKSSWB (66 prefix)
  99 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let s1 : ymmword = read_ymm(pfx.vex_vvvv);
      let s2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      write_ymm(dst, vex_packsswb_128(s1[255..128], s2[255..128]) @ vex_packsswb_128(s1[127..0], s2[127..0]))
    } else {
      write_xmm(dst, vex_packsswb_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)))
    }
  },

  // 0F 64: VPCMPGTB (66 prefix)
  100 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let s1 : ymmword = read_ymm(pfx.vex_vvvv);
      let s2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      write_ymm(dst, vex_pcmpgtb_128(s1[255..128], s2[255..128]) @ vex_pcmpgtb_128(s1[127..0], s2[127..0]))
    } else {
      write_xmm(dst, vex_pcmpgtb_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)))
    }
  },

  // 0F 65: VPCMPGTW (66 prefix)
  101 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let s1 : ymmword = read_ymm(pfx.vex_vvvv);
      let s2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      write_ymm(dst, vex_pcmpgtw_128(s1[255..128], s2[255..128]) @ vex_pcmpgtw_128(s1[127..0], s2[127..0]))
    } else {
      write_xmm(dst, vex_pcmpgtw_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)))
    }
  },

  // 0F 66: VPCMPGTD (66 prefix)
  102 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let s1 : ymmword = read_ymm(pfx.vex_vvvv);
      let s2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      write_ymm(dst, vex_pcmpgtd_128(s1[255..128], s2[255..128]) @ vex_pcmpgtd_128(s1[127..0], s2[127..0]))
    } else {
      write_xmm(dst, vex_pcmpgtd_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)))
    }
  },

  // 0F 67: VPACKUSWB (66 prefix)
  103 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let s1 : ymmword = read_ymm(pfx.vex_vvvv);
      let s2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      write_ymm(dst, vex_packuswb_128(s1[255..128], s2[255..128]) @ vex_packuswb_128(s1[127..0], s2[127..0]))
    } else {
      write_xmm(dst, vex_packuswb_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)))
    }
  },

  // 0F 68: VPUNPCKHBW (66 prefix)
  104 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let s1 : ymmword = read_ymm(pfx.vex_vvvv);
      let s2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      write_ymm(dst, vex_punpckhbw_128(s1[255..128], s2[255..128]) @ vex_punpckhbw_128(s1[127..0], s2[127..0]))
    } else {
      write_xmm(dst, vex_punpckhbw_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)))
    }
  },

  // 0F 69: VPUNPCKHWD (66 prefix)
  105 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let s1 : ymmword = read_ymm(pfx.vex_vvvv);
      let s2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      write_ymm(dst, vex_punpckhwd_128(s1[255..128], s2[255..128]) @ vex_punpckhwd_128(s1[127..0], s2[127..0]))
    } else {
      write_xmm(dst, vex_punpckhwd_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)))
    }
  },

  // 0F 6A: VPUNPCKHDQ (66 prefix)
  106 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let s1 : ymmword = read_ymm(pfx.vex_vvvv);
      let s2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      write_ymm(dst, vex_punpckhdq_128(s1[255..128], s2[255..128]) @ vex_punpckhdq_128(s1[127..0], s2[127..0]))
    } else {
      write_xmm(dst, vex_punpckhdq_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)))
    }
  },

  // 0F 6B: VPACKSSDW (66 prefix)
  107 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let s1 : ymmword = read_ymm(pfx.vex_vvvv);
      let s2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      write_ymm(dst, vex_packssdw_128(s1[255..128], s2[255..128]) @ vex_packssdw_128(s1[127..0], s2[127..0]))
    } else {
      write_xmm(dst, vex_packssdw_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)))
    }
  },

  // 0F 6C: VPUNPCKLQDQ (66 prefix)
  108 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let s1 : ymmword = read_ymm(pfx.vex_vvvv);
      let s2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      write_ymm(dst, vex_punpcklqdq_128(s1[255..128], s2[255..128]) @ vex_punpcklqdq_128(s1[127..0], s2[127..0]))
    } else {
      write_xmm(dst, vex_punpcklqdq_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)))
    }
  },

  // 0F 6D: VPUNPCKHQDQ (66 prefix)
  109 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let s1 : ymmword = read_ymm(pfx.vex_vvvv);
      let s2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      write_ymm(dst, vex_punpckhqdq_128(s1[255..128], s2[255..128]) @ vex_punpckhqdq_128(s1[127..0], s2[127..0]))
    } else {
      write_xmm(dst, vex_punpckhqdq_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)))
    }
  },

  // 0F 6E: VMOVD/VMOVQ gpr/mem -> xmm (66 prefix)
  // SDM: VEX.vvvv must be 1111b
  110 => {
    if mp != MP_66 | pfx.vex_l then raise_UD();
    if pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_w then {
      // VMOVQ xmm, r/m64
      let v : qword = match rm {
        RM_reg(idx) => read_gpr64(idx),
        RM_mem(addr) => mem_read64(fixup_addr(addr)),
      };
      write_xmm(dst, zero_extend(v))
    } else {
      // VMOVD xmm, r/m32
      let v : dword = match rm {
        RM_reg(idx) => read_gpr32(idx),
        RM_mem(addr) => mem_read32(fixup_addr(addr)),
      };
      write_xmm(dst, zero_extend(v))
    }
  },

  // 0F 6F: VMOVDQA/VMOVDQU (load)
  // SDM: VEX.vvvv must be 1111b
  111 => {
    if pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    match mp {
      // VMOVDQA xmm1/ymm1, xmm2/ymm2/m128/m256
      // Requires alignment: 32 for YMM, 16 for XMM; #GP(0) if unaligned.
      MP_66 => match rm {
        RM_reg(_) =>
          if pfx.vex_l then write_ymm(dst, read_ymm(modrm_xmm_rm(modrm, pfx)))
          else write_xmm(dst, read_xmm(modrm_xmm_rm(modrm, pfx))),
        RM_mem(addr) => {
          let a = fixup_addr(addr);
          if pfx.vex_l then {
            if unsigned(a) % 32 != 0 then raise_GP0();
            write_ymm(dst, mem_read256(a))
          } else {
            if unsigned(a) % 16 != 0 then raise_GP0();
            write_xmm(dst, mem_read128(a))
          }
        },
      },
      // VMOVDQU xmm1/ymm1, xmm2/ymm2/m128/m256
      MP_F3 =>
        if pfx.vex_l then {
          write_ymm(dst, decode_vex_src_ymm(modrm, rm, pfx))
        } else {
          write_xmm(dst, decode_vex_src_xmm(modrm, rm, pfx))
        },
      _ => raise_UD(),
    }
  },

  // 0F 70: VPSHUFD xmm/ymm, xmm/ymm/m, imm8 (66 prefix)
  // SDM: VEX.vvvv must be 1111b. 256-bit shuffles each 128-bit lane independently.
  112 => {
    if mp != MP_66 then raise_UD();
    if pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let src : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      let imm = fetch_byte();
      // Shuffle low 128-bit lane
      let lo : xmmword = src[127..0];
      let l0 : dword = match unsigned(imm[1..0]) {
        0 => lo[31..0], 1 => lo[63..32], 2 => lo[95..64], _ => lo[127..96],
      };
      let l1 : dword = match unsigned(imm[3..2]) {
        0 => lo[31..0], 1 => lo[63..32], 2 => lo[95..64], _ => lo[127..96],
      };
      let l2 : dword = match unsigned(imm[5..4]) {
        0 => lo[31..0], 1 => lo[63..32], 2 => lo[95..64], _ => lo[127..96],
      };
      let l3 : dword = match unsigned(imm[7..6]) {
        0 => lo[31..0], 1 => lo[63..32], 2 => lo[95..64], _ => lo[127..96],
      };
      // Shuffle high 128-bit lane
      let hi : xmmword = src[255..128];
      let h0 : dword = match unsigned(imm[1..0]) {
        0 => hi[31..0], 1 => hi[63..32], 2 => hi[95..64], _ => hi[127..96],
      };
      let h1 : dword = match unsigned(imm[3..2]) {
        0 => hi[31..0], 1 => hi[63..32], 2 => hi[95..64], _ => hi[127..96],
      };
      let h2 : dword = match unsigned(imm[5..4]) {
        0 => hi[31..0], 1 => hi[63..32], 2 => hi[95..64], _ => hi[127..96],
      };
      let h3 : dword = match unsigned(imm[7..6]) {
        0 => hi[31..0], 1 => hi[63..32], 2 => hi[95..64], _ => hi[127..96],
      };
      write_ymm(dst, (h3 @ h2 @ h1 @ h0) @ (l3 @ l2 @ l1 @ l0))
    } else {
      let src : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
      let imm = fetch_byte();
      let d0 : dword = match unsigned(imm[1..0]) {
        0 => src[31..0], 1 => src[63..32], 2 => src[95..64], _ => src[127..96],
      };
      let d1 : dword = match unsigned(imm[3..2]) {
        0 => src[31..0], 1 => src[63..32], 2 => src[95..64], _ => src[127..96],
      };
      let d2 : dword = match unsigned(imm[5..4]) {
        0 => src[31..0], 1 => src[63..32], 2 => src[95..64], _ => src[127..96],
      };
      let d3 : dword = match unsigned(imm[7..6]) {
        0 => src[31..0], 1 => src[63..32], 2 => src[95..64], _ => src[127..96],
      };
      write_xmm(dst, d3 @ d2 @ d1 @ d0)
    }
  },

  // 0F 71: Group 12 — VPSRLW/VPSRAW/VPSLLW imm8 (66 prefix)
  // VEX: modrm.rm = src, vvvv = dst
  113 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let reg_field : range(0, 7) = unsigned(modrm[5..3]);
    let _ = decode_rm(modrm, pfx);
    let src_idx = modrm_xmm_rm(modrm, pfx);
    let dst = pfx.vex_vvvv;
    let imm = fetch_byte();
    let c : int = unsigned(imm);
    if pfx.vex_l then {
      let a : ymmword = read_ymm(src_idx);
      match reg_field {
        2 => write_ymm(dst, vex_psrlw_128(a[255..128], c) @ vex_psrlw_128(a[127..0], c)),
        4 => write_ymm(dst, vex_psraw_128(a[255..128], c) @ vex_psraw_128(a[127..0], c)),
        6 => write_ymm(dst, vex_psllw_128(a[255..128], c) @ vex_psllw_128(a[127..0], c)),
        _ => raise_UD(),
      }
    } else {
      let a : xmmword = read_xmm(src_idx);
      match reg_field {
        2 => write_xmm(dst, vex_psrlw_128(a, c)),
        4 => write_xmm(dst, vex_psraw_128(a, c)),
        6 => write_xmm(dst, vex_psllw_128(a, c)),
        _ => raise_UD(),
      }
    }
  },

  // 0F 72: Group 13 — VPSRLD/VPSRAD/VPSLLD imm8 (66 prefix)
  114 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let reg_field : range(0, 7) = unsigned(modrm[5..3]);
    let _ = decode_rm(modrm, pfx);
    let src_idx = modrm_xmm_rm(modrm, pfx);
    let dst = pfx.vex_vvvv;
    let imm = fetch_byte();
    let c : int = unsigned(imm);
    if pfx.vex_l then {
      let a : ymmword = read_ymm(src_idx);
      match reg_field {
        2 => write_ymm(dst, vex_psrld_128(a[255..128], c) @ vex_psrld_128(a[127..0], c)),
        4 => write_ymm(dst, vex_psrad_128(a[255..128], c) @ vex_psrad_128(a[127..0], c)),
        6 => write_ymm(dst, vex_pslld_128(a[255..128], c) @ vex_pslld_128(a[127..0], c)),
        _ => raise_UD(),
      }
    } else {
      let a : xmmword = read_xmm(src_idx);
      match reg_field {
        2 => write_xmm(dst, vex_psrld_128(a, c)),
        4 => write_xmm(dst, vex_psrad_128(a, c)),
        6 => write_xmm(dst, vex_pslld_128(a, c)),
        _ => raise_UD(),
      }
    }
  },

  // 0F 73: Group 14 — VPSRLQ/VPSRLDQ/VPSLLQ/VPSLLDQ imm8 (66 prefix)
  115 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let reg_field : range(0, 7) = unsigned(modrm[5..3]);
    let _ = decode_rm(modrm, pfx);
    let src_idx = modrm_xmm_rm(modrm, pfx);
    let dst = pfx.vex_vvvv;
    let imm = fetch_byte();
    let c : range(0, 255) = unsigned(imm);
    if pfx.vex_l then {
      let a : ymmword = read_ymm(src_idx);
      let lo : xmmword = a[127..0];
      let hi : xmmword = a[255..128];
      match reg_field {
        2 => {
          // VPSRLQ
          let ci : int = c;
          write_ymm(dst, vex_psrlq_128(hi, ci) @ vex_psrlq_128(lo, ci))
        },
        3 => {
          // VPSRLDQ: byte shift right per 128-bit lane
          write_ymm(dst, (hi >> (c * 8)) @ (lo >> (c * 8)))
        },
        6 => {
          // VPSLLQ
          let ci : int = c;
          write_ymm(dst, vex_psllq_128(hi, ci) @ vex_psllq_128(lo, ci))
        },
        7 => {
          // VPSLLDQ: byte shift left per 128-bit lane
          write_ymm(dst, (hi << (c * 8)) @ (lo << (c * 8)))
        },
        _ => raise_UD(),
      }
    } else {
      let a : xmmword = read_xmm(src_idx);
      match reg_field {
        2 => write_xmm(dst, vex_psrlq_128(a, c)),
        3 => write_xmm(dst, a >> (c * 8)),
        6 => write_xmm(dst, vex_psllq_128(a, c)),
        7 => write_xmm(dst, a << (c * 8)),
        _ => raise_UD(),
      }
    }
  },

  // 0F 74: VPCMPEQB (66 prefix)
  116 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let s1 : ymmword = read_ymm(pfx.vex_vvvv);
      let s2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      write_ymm(dst, vex_pcmpeqb_128(s1[255..128], s2[255..128]) @ vex_pcmpeqb_128(s1[127..0], s2[127..0]))
    } else {
      write_xmm(dst, vex_pcmpeqb_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)))
    }
  },

  // 0F 75: VPCMPEQW (66 prefix)
  117 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let s1 : ymmword = read_ymm(pfx.vex_vvvv);
      let s2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      write_ymm(dst, vex_pcmpeqw_128(s1[255..128], s2[255..128]) @ vex_pcmpeqw_128(s1[127..0], s2[127..0]))
    } else {
      write_xmm(dst, vex_pcmpeqw_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)))
    }
  },

  // 0F 76: VPCMPEQD xmm/ymm (66 prefix)
  118 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let src1 : ymmword = read_ymm(pfx.vex_vvvv);
      let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      write_ymm(dst,
        cmp_eq32(src1[255..224], src2[255..224]) @ cmp_eq32(src1[223..192], src2[223..192]) @
        cmp_eq32(src1[191..160], src2[191..160]) @ cmp_eq32(src1[159..128], src2[159..128]) @
        cmp_eq32(src1[127..96], src2[127..96])   @ cmp_eq32(src1[95..64], src2[95..64]) @
        cmp_eq32(src1[63..32], src2[63..32])     @ cmp_eq32(src1[31..0], src2[31..0]))
    } else {
      let src1 : xmmword = read_xmm(pfx.vex_vvvv);
      let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
      write_xmm(dst,
        cmp_eq32(src1[127..96], src2[127..96]) @ cmp_eq32(src1[95..64], src2[95..64]) @
        cmp_eq32(src1[63..32], src2[63..32])   @ cmp_eq32(src1[31..0], src2[31..0]))
    }
  },

  // 0F 77: VZEROUPPER (VEX.128) / VZEROALL (VEX.256)
  // SDM: VEX.vvvv must be 1111b
  119 => {
    if pfx.vex_vvvv != 0 then raise_UD();
    if pfx.vex_l then {
      // VZEROALL: zero ZMM0-ZMM15 entirely (in 64-bit mode)
      foreach (i from 0 to 15) {
        ZMM[i] = zeros()
      }
    } else {
      // VZEROUPPER: zero upper bits (255:128) of ZMM0-ZMM15
      foreach (i from 0 to 15) {
        var r : zmmword = ZMM[i];
        r[511..128] = zeros();
        ZMM[i] = r
      }
    }
  },

  // 0F 7C: VHADDPS (F2) / VHADDPD (66)
  124 => {
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    match mp {
      MP_F2 => {
        if pfx.vex_l then {
          let a : ymmword = read_ymm(pfx.vex_vvvv);
          let b : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
          // Lane 1 (upper 128): same pattern
          let d7 : dword = __f32_add(b[223..192], b[255..224]);
          let d6 : dword = __f32_add(b[159..128], b[191..160]);
          let d5 : dword = __f32_add(a[223..192], a[255..224]);
          let d4 : dword = __f32_add(a[159..128], a[191..160]);
          // Lane 0 (lower 128)
          let d3 : dword = __f32_add(b[95..64], b[127..96]);
          let d2 : dword = __f32_add(b[31..0], b[63..32]);
          let d1 : dword = __f32_add(a[95..64], a[127..96]);
          let d0 : dword = __f32_add(a[31..0], a[63..32]);
          write_ymm(dst, d7 @ d6 @ d5 @ d4 @ d3 @ d2 @ d1 @ d0)
        } else {
          let a : xmmword = read_xmm(pfx.vex_vvvv);
          let b : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
          let d3 : dword = __f32_add(b[95..64], b[127..96]);
          let d2 : dword = __f32_add(b[31..0], b[63..32]);
          let d1 : dword = __f32_add(a[95..64], a[127..96]);
          let d0 : dword = __f32_add(a[31..0], a[63..32]);
          write_xmm(dst, d3 @ d2 @ d1 @ d0)
        }
      },
      MP_66 => {
        if pfx.vex_l then {
          let a : ymmword = read_ymm(pfx.vex_vvvv);
          let b : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
          // Lane 1
          let q3 : qword = __f64_add(b[191..128], b[255..192]);
          let q2 : qword = __f64_add(a[191..128], a[255..192]);
          // Lane 0
          let q1 : qword = __f64_add(b[63..0], b[127..64]);
          let q0 : qword = __f64_add(a[63..0], a[127..64]);
          write_ymm(dst, q3 @ q2 @ q1 @ q0)
        } else {
          let a : xmmword = read_xmm(pfx.vex_vvvv);
          let b : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
          let q1 : qword = __f64_add(b[63..0], b[127..64]);
          let q0 : qword = __f64_add(a[63..0], a[127..64]);
          write_xmm(dst, q1 @ q0)
        }
      },
      _ => raise_UD(),
    }
  },

  // 0F 7D: VHSUBPS (F2) / VHSUBPD (66)
  125 => {
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    match mp {
      MP_F2 => {
        if pfx.vex_l then {
          let a : ymmword = read_ymm(pfx.vex_vvvv);
          let b : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
          let d7 : dword = __f32_sub(b[223..192], b[255..224]);
          let d6 : dword = __f32_sub(b[159..128], b[191..160]);
          let d5 : dword = __f32_sub(a[223..192], a[255..224]);
          let d4 : dword = __f32_sub(a[159..128], a[191..160]);
          let d3 : dword = __f32_sub(b[95..64], b[127..96]);
          let d2 : dword = __f32_sub(b[31..0], b[63..32]);
          let d1 : dword = __f32_sub(a[95..64], a[127..96]);
          let d0 : dword = __f32_sub(a[31..0], a[63..32]);
          write_ymm(dst, d7 @ d6 @ d5 @ d4 @ d3 @ d2 @ d1 @ d0)
        } else {
          let a : xmmword = read_xmm(pfx.vex_vvvv);
          let b : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
          let d3 : dword = __f32_sub(b[95..64], b[127..96]);
          let d2 : dword = __f32_sub(b[31..0], b[63..32]);
          let d1 : dword = __f32_sub(a[95..64], a[127..96]);
          let d0 : dword = __f32_sub(a[31..0], a[63..32]);
          write_xmm(dst, d3 @ d2 @ d1 @ d0)
        }
      },
      MP_66 => {
        if pfx.vex_l then {
          let a : ymmword = read_ymm(pfx.vex_vvvv);
          let b : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
          let q3 : qword = __f64_sub(b[191..128], b[255..192]);
          let q2 : qword = __f64_sub(a[191..128], a[255..192]);
          let q1 : qword = __f64_sub(b[63..0], b[127..64]);
          let q0 : qword = __f64_sub(a[63..0], a[127..64]);
          write_ymm(dst, q3 @ q2 @ q1 @ q0)
        } else {
          let a : xmmword = read_xmm(pfx.vex_vvvv);
          let b : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
          let q1 : qword = __f64_sub(b[63..0], b[127..64]);
          let q0 : qword = __f64_sub(a[63..0], a[127..64]);
          write_xmm(dst, q1 @ q0)
        }
      },
      _ => raise_UD(),
    }
  },

  // 0F 7E: VMOVD/VMOVQ xmm -> gpr/mem (66 prefix) / VMOVQ xmm,xmm/m64 (F3 prefix)
  // SDM: VEX.128 only, VEX.vvvv must be 1111b
  126 => {
    if pfx.vex_vvvv != 0 | pfx.vex_l then raise_UD();
    let modrm = fetch_byte();
    let rm = decode_rm(modrm, pfx);
    match mp {
      MP_66 => {
        // VMOVD/VMOVQ xmm -> r/m
        let src = read_xmm(modrm_xmm_reg(modrm, pfx));
        if pfx.vex_w then {
          match rm {
            RM_reg(idx) => write_gpr64(idx, src[63..0]),
            RM_mem(addr) => mem_write64(fixup_addr(addr), src[63..0]),
          };
        } else {
          match rm {
            RM_reg(idx) => write_gpr32(idx, src[31..0]),
            RM_mem(addr) => mem_write32(fixup_addr(addr), src[31..0]),
          };
        }
      },
      MP_F3 => {
        // VMOVQ xmm1, xmm2/m64
        let dst = modrm_xmm_reg(modrm, pfx);
        match rm {
          RM_reg(_) => {
            let src = read_xmm(modrm_xmm_rm(modrm, pfx));
            write_xmm(dst, zero_extend(src[63..0]))
          },
          RM_mem(addr) => {
            let v : qword = mem_read64(fixup_addr(addr));
            write_xmm(dst, zero_extend(v))
          },
        }
      },
      _ => raise_UD(),
    }
  },

  // 0F 7F: VMOVDQA/VMOVDQU (store)
  // SDM: VEX.vvvv must be 1111b
  // VMOVDQA (66): requires alignment; VMOVDQU (F3): unaligned OK.
  127 => {
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
      RM_mem(addr) => {
        let a = fixup_addr(addr);
        if mp == MP_66 then {
          if pfx.vex_l then {
            if unsigned(a) % 32 != 0 then raise_GP0();
          } else {
            if unsigned(a) % 16 != 0 then raise_GP0();
          }
        };
        if pfx.vex_l then {
          mem_write256(a, read_ymm(src))
        } else {
          mem_write128(a, read_xmm(src))
        }
      },
    }
  },

  // 0F 90: KMOVW k1, k/m16 (NP, W0) — load k-register from k/memory
  144 => {
    let modrm = fetch_byte();
    let k1 : range(0, 7) = unsigned(modrm[5..3]);
    let rm = decode_rm(modrm, pfx);
    match mp {
      MP_NONE => {
        let v : bits(16) = match rm {
          RM_reg(idx) => {
            let k_src : range(0, 7) = idx % 8;
            read_kreg(k_src)[15..0]
          },
          RM_mem(addr) => mem_read16(fixup_addr(addr)),
        };
        write_kreg(k1, zero_extend(v))
      },
      _ => raise_UD(),
    }
  },

  // 0F 91: KMOVW k/m16, k1 (NP, W0) — store k-register to memory
  145 => {
    let modrm = fetch_byte();
    let k1 : range(0, 7) = unsigned(modrm[5..3]);
    let rm = decode_rm(modrm, pfx);
    match mp {
      MP_NONE => {
        match rm {
          RM_mem(addr) => {
            mem_write16(fixup_addr(addr), read_kreg(k1)[15..0])
          },
          RM_reg(_) => raise_UD(),
        }
      },
      _ => raise_UD(),
    }
  },

  // 0F 92: KMOVW r32 -> k (NP, W0) / KMOVB/D/Q variants
  146 => {
    let modrm = fetch_byte();
    let k1 : range(0, 7) = unsigned(modrm[5..3]);
    let rm = decode_rm(modrm, pfx);
    match mp {
      // KMOVW: r/m16 -> k
      MP_NONE => {
        let v : dword = match rm {
          RM_reg(idx) => read_gpr32(idx),
          RM_mem(addr) => zero_extend(mem_read16(fixup_addr(addr))),
        };
        write_kreg(k1, zero_extend(v[15..0]))
      },
      _ => raise_UD(),
    }
  },

  // 0F 93: KMOVW k -> r32 (NP, W0) / KMOVD k -> r32 (F2, W0)
  147 => {
    let modrm = fetch_byte();
    let dst_gpr = modrm_reg(modrm, pfx);
    let k1 : range(0, 7) = unsigned(modrm[2..0]);
    match mp {
      // KMOVW r32, k1
      MP_NONE => {
        write_gpr32(dst_gpr, zero_extend(read_kreg(k1)[15..0]))
      },
      // KMOVD r32, k1
      MP_F2 => {
        write_gpr32(dst_gpr, read_kreg(k1)[31..0])
      },
      _ => raise_UD(),
    }
  },

  // 0F 98: KORTESTW k1, k2 (NP, W0) — set ZF if k1|k2==0, CF if k1|k2==all-ones
  152 => {
    let modrm = fetch_byte();
    let k1 : range(0, 7) = unsigned(modrm[5..3]);
    let k2 : range(0, 7) = unsigned(modrm[2..0]);
    let v1 : bits(16) = read_kreg(k1)[15..0];
    let v2 : bits(16) = read_kreg(k2)[15..0];
    let result : bits(16) = v1 | v2;
    ZF = (~(or_reduce_16(result)))[0];
    CF = (~(or_reduce_16(~(result))))[0];
    SF = bitzero;
    OF = bitzero;
    PF = bitzero;
    AF = bitzero
  },

  // 0F 99: KTESTW k1, k2 (NP, W0) — set ZF if k1&k2==0, CF if (~k1)&k2==0
  153 => {
    let modrm = fetch_byte();
    let k1 : range(0, 7) = unsigned(modrm[5..3]);
    let k2 : range(0, 7) = unsigned(modrm[2..0]);
    let v1 : bits(16) = read_kreg(k1)[15..0];
    let v2 : bits(16) = read_kreg(k2)[15..0];
    ZF = (~(or_reduce_16(v1 & v2)))[0];
    CF = (~(or_reduce_16(~(v1) & v2)))[0];
    SF = bitzero;
    OF = bitzero;
    PF = bitzero;
    AF = bitzero
  },

  // 0F C4: VPINSRW xmm, xmm, r32/m16, imm8 (66 prefix, VEX.128 only)
  196 => {
    if mp != MP_66 | pfx.vex_l then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let src1 : xmmword = read_xmm(pfx.vex_vvvv);
    let v : word = match rm {
      RM_reg(idx) => read_gpr32(idx)[15..0],
      RM_mem(addr) => mem_read16(fixup_addr(addr)),
    };
    let imm = fetch_byte();
    let sel : range(0, 7) = unsigned(imm[2..0]);
    var result : xmmword = src1;
    result[(16 * sel + 15) .. (16 * sel)] = v;
    write_xmm(dst, result)
  },

  // 0F C5: VPEXTRW r32, xmm, imm8 (66 prefix, VEX.128 only)
  197 => {
    if mp != MP_66 | pfx.vex_l then raise_UD();
    let modrm = fetch_byte();
    let dst_gpr = modrm_reg(modrm, pfx);
    let src : xmmword = read_xmm(modrm_xmm_rm(modrm, pfx));
    let imm = fetch_byte();
    let sel : range(0, 7) = unsigned(imm[2..0]);
    let result : word = src[(16 * sel + 15) .. (16 * sel)];
    write_gpr32(dst_gpr, zero_extend(result))
  },

  // 0F D0: VADDSUBPS (F2) / VADDSUBPD (66) — alternating sub/add
  208 => {
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    match mp {
      MP_F2 => {
        if pfx.vex_l then {
          let a : ymmword = read_ymm(pfx.vex_vvvv);
          let b : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
          let r : ymmword =
            __f32_add(a[255..224], b[255..224]) @
            __f32_sub(a[223..192], b[223..192]) @
            __f32_add(a[191..160], b[191..160]) @
            __f32_sub(a[159..128], b[159..128]) @
            __f32_add(a[127..96], b[127..96]) @
            __f32_sub(a[95..64], b[95..64]) @
            __f32_add(a[63..32], b[63..32]) @
            __f32_sub(a[31..0], b[31..0]);
          write_ymm(dst, r)
        } else {
          let a : xmmword = read_xmm(pfx.vex_vvvv);
          let b : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
          let r : xmmword =
            __f32_add(a[127..96], b[127..96]) @
            __f32_sub(a[95..64], b[95..64]) @
            __f32_add(a[63..32], b[63..32]) @
            __f32_sub(a[31..0], b[31..0]);
          write_xmm(dst, r)
        }
      },
      MP_66 => {
        if pfx.vex_l then {
          let a : ymmword = read_ymm(pfx.vex_vvvv);
          let b : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
          let r : ymmword =
            __f64_add(a[255..192], b[255..192]) @
            __f64_sub(a[191..128], b[191..128]) @
            __f64_add(a[127..64], b[127..64]) @
            __f64_sub(a[63..0], b[63..0]);
          write_ymm(dst, r)
        } else {
          let a : xmmword = read_xmm(pfx.vex_vvvv);
          let b : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
          let r : xmmword =
            __f64_add(a[127..64], b[127..64]) @
            __f64_sub(a[63..0], b[63..0]);
          write_xmm(dst, r)
        }
      },
      _ => raise_UD(),
    }
  },

  // 0F D1: VPSRLW xmm/ymm, xmm/ymm, xmm/m128 (66 prefix) — shift by xmm count
  209 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let cnt_xmm : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
    let c : int = unsigned(cnt_xmm[63..0]);
    if pfx.vex_l then {
      let s1 : ymmword = read_ymm(pfx.vex_vvvv);
      write_ymm(dst, vex_psrlw_128(s1[255..128], c) @ vex_psrlw_128(s1[127..0], c))
    } else {
      write_xmm(dst, vex_psrlw_128(read_xmm(pfx.vex_vvvv), c))
    }
  },

  // 0F D2: VPSRLD xmm/ymm, xmm/ymm, xmm/m128 (66 prefix)
  210 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let cnt_xmm : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
    let c : int = unsigned(cnt_xmm[63..0]);
    if pfx.vex_l then {
      let s1 : ymmword = read_ymm(pfx.vex_vvvv);
      write_ymm(dst, vex_psrld_128(s1[255..128], c) @ vex_psrld_128(s1[127..0], c))
    } else {
      write_xmm(dst, vex_psrld_128(read_xmm(pfx.vex_vvvv), c))
    }
  },

  // 0F D3: VPSRLQ xmm/ymm, xmm/ymm, xmm/m128 (66 prefix)
  211 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let cnt_xmm : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
    let c : int = unsigned(cnt_xmm[63..0]);
    if pfx.vex_l then {
      let s1 : ymmword = read_ymm(pfx.vex_vvvv);
      write_ymm(dst, vex_psrlq_128(s1[255..128], c) @ vex_psrlq_128(s1[127..0], c))
    } else {
      write_xmm(dst, vex_psrlq_128(read_xmm(pfx.vex_vvvv), c))
    }
  },

  // 0F D4: VPADDQ (66 prefix)
  212 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let src1 : ymmword = read_ymm(pfx.vex_vvvv);
      let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      write_ymm(dst, avx_paddq_128(src1[255..128], src2[255..128]) @ avx_paddq_128(src1[127..0], src2[127..0]))
    } else {
      let src1 : xmmword = read_xmm(pfx.vex_vvvv);
      let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
      write_xmm(dst, avx_paddq_128(src1, src2))
    }
  },

  // 0F D5: VPMULLW xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  213 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      write_ymm(dst, vex_pmullw_256(read_ymm(pfx.vex_vvvv), decode_vex_src_ymm(modrm, rm, pfx)))
    } else {
      write_xmm(dst, vex_pmullw_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)))
    }
  },

  // 0F D6: VMOVQ xmm1/m64, xmm2 (66 prefix, VEX.128 only)
  // SDM: VEX.vvvv must be 1111b, VEX.L must be 0
  214 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    if pfx.vex_l then raise_UD();
    let modrm = fetch_byte();
    let src_xmm = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let v : qword = read_xmm(src_xmm)[63..0];
    match rm {
      RM_reg(_) => {
        write_xmm(modrm_xmm_rm(modrm, pfx), zero_extend(v))
      },
      RM_mem(addr) => mem_write64(fixup_addr(addr), v),
    }
  },

  // 0F D7: VPMOVMSKB r32, xmm/ymm (66 prefix) — extract byte sign bits to GPR
  215 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch_byte();
    let reg = modrm_reg(modrm, pfx);
    let _ = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let src : ymmword = read_ymm(modrm_xmm_rm(modrm, pfx));
      var mask : bits(32) = zeros();
      foreach (i from 0 to 31) {
        mask[i] = src[(i * 8 + 7)]
      };
      write_gpr64(reg, zero_extend(mask))
    } else {
      let src : xmmword = read_xmm(modrm_xmm_rm(modrm, pfx));
      let mask : word = src[127] @ src[119] @ src[111] @ src[103] @
                        src[95]  @ src[87]  @ src[79]  @ src[71] @
                        src[63]  @ src[55]  @ src[47]  @ src[39] @
                        src[31]  @ src[23]  @ src[15]  @ src[7];
      write_gpr32(reg, zero_extend(mask))
    }
  },

  // 0F D8: VPSUBUSB (66 prefix)
  216 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let s1 : ymmword = read_ymm(pfx.vex_vvvv);
      let s2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      write_ymm(dst, vex_psubusb_128(s1[255..128], s2[255..128]) @ vex_psubusb_128(s1[127..0], s2[127..0]))
    } else {
      write_xmm(dst, vex_psubusb_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)))
    }
  },

  // 0F D9: VPSUBUSW (66 prefix)
  217 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let s1 : ymmword = read_ymm(pfx.vex_vvvv);
      let s2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      write_ymm(dst, vex_psubusw_128(s1[255..128], s2[255..128]) @ vex_psubusw_128(s1[127..0], s2[127..0]))
    } else {
      write_xmm(dst, vex_psubusw_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)))
    }
  },

  // 0F DA: VPMINUB (66 prefix)
  218 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let s1 : ymmword = read_ymm(pfx.vex_vvvv);
      let s2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      write_ymm(dst, vex_pminub_128(s1[255..128], s2[255..128]) @ vex_pminub_128(s1[127..0], s2[127..0]))
    } else {
      write_xmm(dst, vex_pminub_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)))
    }
  },

  // 0F DB: VPAND (66 prefix)
  219 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      write_ymm(dst, read_ymm(pfx.vex_vvvv) & decode_vex_src_ymm(modrm, rm, pfx))
    } else {
      write_xmm(dst, read_xmm(pfx.vex_vvvv) & decode_vex_src_xmm(modrm, rm, pfx))
    }
  },

  // 0F DC: VPADDUSB (66 prefix)
  220 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let s1 : ymmword = read_ymm(pfx.vex_vvvv);
      let s2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      write_ymm(dst, vex_paddusb_128(s1[255..128], s2[255..128]) @ vex_paddusb_128(s1[127..0], s2[127..0]))
    } else {
      write_xmm(dst, vex_paddusb_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)))
    }
  },

  // 0F DD: VPADDUSW (66 prefix)
  221 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let s1 : ymmword = read_ymm(pfx.vex_vvvv);
      let s2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      write_ymm(dst, vex_paddusw_128(s1[255..128], s2[255..128]) @ vex_paddusw_128(s1[127..0], s2[127..0]))
    } else {
      write_xmm(dst, vex_paddusw_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)))
    }
  },

  // 0F DE: VPMAXUB (66 prefix)
  222 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let s1 : ymmword = read_ymm(pfx.vex_vvvv);
      let s2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      write_ymm(dst, vex_pmaxub_128(s1[255..128], s2[255..128]) @ vex_pmaxub_128(s1[127..0], s2[127..0]))
    } else {
      write_xmm(dst, vex_pmaxub_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)))
    }
  },

  // 0F DF: VPANDN (66 prefix)
  223 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      write_ymm(dst, ~(read_ymm(pfx.vex_vvvv)) & decode_vex_src_ymm(modrm, rm, pfx))
    } else {
      write_xmm(dst, ~(read_xmm(pfx.vex_vvvv)) & decode_vex_src_xmm(modrm, rm, pfx))
    }
  },

  // 0F E0: VPAVGB xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  224 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      write_ymm(dst, vex_pavgb_256(read_ymm(pfx.vex_vvvv), decode_vex_src_ymm(modrm, rm, pfx)))
    } else {
      write_xmm(dst, vex_pavgb_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)))
    }
  },

  // 0F E1: VPSRAW xmm/ymm, xmm/ymm, xmm/m128 (66 prefix) — shift by xmm count
  225 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let cnt_xmm : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
    let c : int = unsigned(cnt_xmm[63..0]);
    if pfx.vex_l then {
      let s1 : ymmword = read_ymm(pfx.vex_vvvv);
      write_ymm(dst, vex_psraw_128(s1[255..128], c) @ vex_psraw_128(s1[127..0], c))
    } else {
      write_xmm(dst, vex_psraw_128(read_xmm(pfx.vex_vvvv), c))
    }
  },

  // 0F E2: VPSRAD xmm/ymm, xmm/ymm, xmm/m128 (66 prefix)
  226 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let cnt_xmm : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
    let c : int = unsigned(cnt_xmm[63..0]);
    if pfx.vex_l then {
      let s1 : ymmword = read_ymm(pfx.vex_vvvv);
      write_ymm(dst, vex_psrad_128(s1[255..128], c) @ vex_psrad_128(s1[127..0], c))
    } else {
      write_xmm(dst, vex_psrad_128(read_xmm(pfx.vex_vvvv), c))
    }
  },

  // 0F E3: VPAVGW xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  227 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      write_ymm(dst, vex_pavgw_256(read_ymm(pfx.vex_vvvv), decode_vex_src_ymm(modrm, rm, pfx)))
    } else {
      write_xmm(dst, vex_pavgw_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)))
    }
  },

  // 0F E4: VPMULHUW xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  228 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      write_ymm(dst, vex_pmulhuw_256(read_ymm(pfx.vex_vvvv), decode_vex_src_ymm(modrm, rm, pfx)))
    } else {
      write_xmm(dst, vex_pmulhuw_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)))
    }
  },

  // 0F E5: VPMULHW xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  229 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      write_ymm(dst, vex_pmulhw_256(read_ymm(pfx.vex_vvvv), decode_vex_src_ymm(modrm, rm, pfx)))
    } else {
      write_xmm(dst, vex_pmulhw_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)))
    }
  },

  // 0F E6: VCVTDQ2PD (F3) / VCVTPD2DQ (F2) / VCVTTPD2DQ (66)
  230 => {
    if pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    match mp {
      // VCVTDQ2PD: 2/4 dword ints -> 2/4 doubles
      MP_F3 => {
        if pfx.vex_l then {
          let src : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
          let r3 = __int32_to_f64(src[127..96]);
          let r2 = __int32_to_f64(src[95..64]);
          let r1 = __int32_to_f64(src[63..32]);
          let r0 = __int32_to_f64(src[31..0]);
          write_ymm(dst, r3 @ r2 @ r1 @ r0)
        } else {
          let src : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
          write_xmm(dst, __int32_to_f64(src[63..32]) @ __int32_to_f64(src[31..0]))
        }
      },
      // VCVTPD2DQ: 2/4 doubles -> 2/4 dword ints (rounding)
      MP_F2 => {
        if pfx.vex_l then {
          let src : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
          let r : xmmword = __f64_to_int32(src[255..192]) @ __f64_to_int32(src[191..128]) @
                            __f64_to_int32(src[127..64])  @ __f64_to_int32(src[63..0]);
          write_xmm(dst, r)
        } else {
          let src : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
          write_xmm(dst, zeros(64) @ __f64_to_int32(src[127..64]) @ __f64_to_int32(src[63..0]))
        }
      },
      // VCVTTPD2DQ: 2/4 doubles -> 2/4 dword ints (truncating)
      MP_66 => {
        if pfx.vex_l then {
          let src : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
          let r : xmmword = __f64_to_int32_trunc(src[255..192]) @ __f64_to_int32_trunc(src[191..128]) @
                            __f64_to_int32_trunc(src[127..64])  @ __f64_to_int32_trunc(src[63..0]);
          write_xmm(dst, r)
        } else {
          let src : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
          write_xmm(dst, zeros(64) @ __f64_to_int32_trunc(src[127..64]) @ __f64_to_int32_trunc(src[63..0]))
        }
      },
      _ => raise_UD(),
    }
  },

  // 0F E7: VMOVNTDQ m128/m256, xmm/ymm (66 prefix) — non-temporal store
  // SDM: requires alignment (32 for YMM, 16 for XMM); #GP(0) if unaligned.
  231 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch_byte();
    let src = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    match rm {
      RM_mem(addr) => {
        let a = fixup_addr(addr);
        if pfx.vex_l then {
          if unsigned(a) % 32 != 0 then raise_GP0();
          let v : ymmword = read_ymm(src);
          mem_write128(a, v[127..0]);
          mem_write128(a + 16, v[255..128])
        } else {
          if unsigned(a) % 16 != 0 then raise_GP0();
          mem_write128(a, read_xmm(src))
        }
      },
      RM_reg(_) => raise_UD(),
    }
  },

  // 0F E8: VPSUBSB (66 prefix)
  232 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let s1 : ymmword = read_ymm(pfx.vex_vvvv);
      let s2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      write_ymm(dst, vex_psubsb_128(s1[255..128], s2[255..128]) @ vex_psubsb_128(s1[127..0], s2[127..0]))
    } else {
      write_xmm(dst, vex_psubsb_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)))
    }
  },

  // 0F E9: VPSUBSW (66 prefix)
  233 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let s1 : ymmword = read_ymm(pfx.vex_vvvv);
      let s2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      write_ymm(dst, vex_psubsw_128(s1[255..128], s2[255..128]) @ vex_psubsw_128(s1[127..0], s2[127..0]))
    } else {
      write_xmm(dst, vex_psubsw_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)))
    }
  },

  // 0F EA: VPMINSW (66 prefix)
  234 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let s1 : ymmword = read_ymm(pfx.vex_vvvv);
      let s2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      write_ymm(dst, vex_pminsw_128(s1[255..128], s2[255..128]) @ vex_pminsw_128(s1[127..0], s2[127..0]))
    } else {
      write_xmm(dst, vex_pminsw_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)))
    }
  },

  // 0F EB: VPOR (66 prefix)
  235 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      write_ymm(dst, read_ymm(pfx.vex_vvvv) | decode_vex_src_ymm(modrm, rm, pfx))
    } else {
      write_xmm(dst, read_xmm(pfx.vex_vvvv) | decode_vex_src_xmm(modrm, rm, pfx))
    }
  },

  // 0F EC: VPADDSB (66 prefix)
  236 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let s1 : ymmword = read_ymm(pfx.vex_vvvv);
      let s2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      write_ymm(dst, vex_paddsb_128(s1[255..128], s2[255..128]) @ vex_paddsb_128(s1[127..0], s2[127..0]))
    } else {
      write_xmm(dst, vex_paddsb_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)))
    }
  },

  // 0F ED: VPADDSW (66 prefix)
  237 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let s1 : ymmword = read_ymm(pfx.vex_vvvv);
      let s2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      write_ymm(dst, vex_paddsw_128(s1[255..128], s2[255..128]) @ vex_paddsw_128(s1[127..0], s2[127..0]))
    } else {
      write_xmm(dst, vex_paddsw_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)))
    }
  },

  // 0F EE: VPMAXSW xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  238 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let src1 : ymmword = read_ymm(pfx.vex_vvvv);
      let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      var result : ymmword = zeros();
      foreach (i from 0 to 15) {
        let a : bits(16) = src1[(i * 16 + 15) .. (i * 16)];
        let b : bits(16) = src2[(i * 16 + 15) .. (i * 16)];
        result[(i * 16 + 15) .. (i * 16)] = max_s16(a, b)
      };
      write_ymm(dst, result)
    } else {
      let src1 : xmmword = read_xmm(pfx.vex_vvvv);
      let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
      var result : xmmword = zeros();
      foreach (i from 0 to 7) {
        let a : bits(16) = src1[(i * 16 + 15) .. (i * 16)];
        let b : bits(16) = src2[(i * 16 + 15) .. (i * 16)];
        result[(i * 16 + 15) .. (i * 16)] = max_s16(a, b)
      };
      write_xmm(dst, result)
    }
  },

  // 0F EF: VPXOR (66 prefix)
  239 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let src1_reg = pfx.vex_vvvv;
    if pfx.vex_l then {
      let src1 : ymmword = read_ymm(src1_reg);
      let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      write_ymm(dst, xor_vec(src1, src2))
    } else {
      let src1 : xmmword = read_xmm(src1_reg);
      let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
      write_xmm(dst, xor_vec(src1, src2))
    }
  },

  // 0F F0: VLDDQU xmm/ymm, m128/m256 (F2 prefix) — unaligned load
  240 => {
    if mp != MP_F2 | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    match rm {
      RM_mem(addr) => {
        let a = fixup_addr(addr);
        if pfx.vex_l then {
          let lo : xmmword = mem_read128(a);
          let hi : xmmword = mem_read128(a + 16);
          write_ymm(dst, hi @ lo)
        } else {
          write_xmm(dst, mem_read128(a))
        }
      },
      RM_reg(_) => raise_UD(),
    }
  },

  // 0F F1: VPSLLW xmm/ymm, xmm/ymm, xmm/m128 (66 prefix) — shift by xmm count
  241 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let cnt_xmm : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
    let c : int = unsigned(cnt_xmm[63..0]);
    if pfx.vex_l then {
      let s1 : ymmword = read_ymm(pfx.vex_vvvv);
      write_ymm(dst, vex_psllw_128(s1[255..128], c) @ vex_psllw_128(s1[127..0], c))
    } else {
      write_xmm(dst, vex_psllw_128(read_xmm(pfx.vex_vvvv), c))
    }
  },

  // 0F F2: VPSLLD xmm/ymm, xmm/ymm, xmm/m128 (66 prefix)
  242 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let cnt_xmm : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
    let c : int = unsigned(cnt_xmm[63..0]);
    if pfx.vex_l then {
      let s1 : ymmword = read_ymm(pfx.vex_vvvv);
      write_ymm(dst, vex_pslld_128(s1[255..128], c) @ vex_pslld_128(s1[127..0], c))
    } else {
      write_xmm(dst, vex_pslld_128(read_xmm(pfx.vex_vvvv), c))
    }
  },

  // 0F F3: VPSLLQ xmm/ymm, xmm/ymm, xmm/m128 (66 prefix)
  243 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let cnt_xmm : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
    let c : int = unsigned(cnt_xmm[63..0]);
    if pfx.vex_l then {
      let s1 : ymmword = read_ymm(pfx.vex_vvvv);
      write_ymm(dst, vex_psllq_128(s1[255..128], c) @ vex_psllq_128(s1[127..0], c))
    } else {
      write_xmm(dst, vex_psllq_128(read_xmm(pfx.vex_vvvv), c))
    }
  },

  // 0F F4: VPMULUDQ xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  244 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      write_ymm(dst, vex_pmuludq_256(read_ymm(pfx.vex_vvvv), decode_vex_src_ymm(modrm, rm, pfx)))
    } else {
      write_xmm(dst, vex_pmuludq_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)))
    }
  },

  // 0F F5: VPMADDWD xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  245 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      write_ymm(dst, vex_pmaddwd_256(read_ymm(pfx.vex_vvvv), decode_vex_src_ymm(modrm, rm, pfx)))
    } else {
      write_xmm(dst, vex_pmaddwd_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)))
    }
  },

  // 0F F6: VPSADBW xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  246 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      write_ymm(dst, vex_psadbw_256(read_ymm(pfx.vex_vvvv), decode_vex_src_ymm(modrm, rm, pfx)))
    } else {
      write_xmm(dst, vex_psadbw_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)))
    }
  },

  // 0F F7: VMASKMOVDQU xmm, xmm (66 prefix, vvvv must be 1111b, VEX.L=0)
  247 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 | pfx.vex_l then raise_UD();
    let modrm = fetch_byte();
    let src = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    match rm {
      RM_reg(_) => {
        let data : xmmword = read_xmm(src);
        let mask : xmmword = read_xmm(modrm_xmm_rm(modrm, pfx));
        let addr : bits(64) = read_gpr64(7); // RDI
        foreach (i from 0 to 15) {
          if mask[(i * 8 + 7)] == bitone then
            mem_write(addr + to_bits(64, i), 1, data[(i * 8 + 7) .. (i * 8)])
        }
      },
      RM_mem(_) => raise_UD(),
    }
  },

  // 0F F8: VPSUBB (66 prefix)
  248 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let src1 : ymmword = read_ymm(pfx.vex_vvvv);
      let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      write_ymm(dst, avx_psubb_128(src1[255..128], src2[255..128]) @ avx_psubb_128(src1[127..0], src2[127..0]))
    } else {
      let src1 : xmmword = read_xmm(pfx.vex_vvvv);
      let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
      write_xmm(dst, avx_psubb_128(src1, src2))
    }
  },

  // 0F F9: VPSUBW (66 prefix)
  249 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let src1 : ymmword = read_ymm(pfx.vex_vvvv);
      let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      write_ymm(dst, avx_psubw_128(src1[255..128], src2[255..128]) @ avx_psubw_128(src1[127..0], src2[127..0]))
    } else {
      write_xmm(dst, avx_psubw_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)))
    }
  },

  // 0F FA: VPSUBD (66 prefix)
  250 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let src1 : ymmword = read_ymm(pfx.vex_vvvv);
      let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      write_ymm(dst, avx_psubd_128(src1[255..128], src2[255..128]) @ avx_psubd_128(src1[127..0], src2[127..0]))
    } else {
      write_xmm(dst, avx_psubd_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)))
    }
  },

  // 0F FB: VPSUBQ (66 prefix)
  251 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let src1 : ymmword = read_ymm(pfx.vex_vvvv);
      let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      write_ymm(dst, avx_psubq_128(src1[255..128], src2[255..128]) @ avx_psubq_128(src1[127..0], src2[127..0]))
    } else {
      write_xmm(dst, avx_psubq_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)))
    }
  },

  // 0F FC: VPADDB (66 prefix)
  252 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let src1 : ymmword = read_ymm(pfx.vex_vvvv);
      let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      write_ymm(dst, avx_paddb_128(src1[255..128], src2[255..128]) @ avx_paddb_128(src1[127..0], src2[127..0]))
    } else {
      let src1 : xmmword = read_xmm(pfx.vex_vvvv);
      let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
      write_xmm(dst, avx_paddb_128(src1, src2))
    }
  },

  // 0F FD: VPADDW (66 prefix)
  253 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let src1 : ymmword = read_ymm(pfx.vex_vvvv);
      let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      write_ymm(dst, avx_paddw_128(src1[255..128], src2[255..128]) @ avx_paddw_128(src1[127..0], src2[127..0]))
    } else {
      let src1 : xmmword = read_xmm(pfx.vex_vvvv);
      let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
      write_xmm(dst, avx_paddw_128(src1, src2))
    }
  },

  // 0F FE: VPADDD (66 prefix)
  254 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let src1 : ymmword = read_ymm(pfx.vex_vvvv);
      let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      write_ymm(dst, avx_paddd_128(src1[255..128], src2[255..128]) @ avx_paddd_128(src1[127..0], src2[127..0]))
    } else {
      let src1 : xmmword = read_xmm(pfx.vex_vvvv);
      let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
      write_xmm(dst, avx_paddd_128(src1, src2))
    }
  },

  _ => raise_UD(),
  }
}

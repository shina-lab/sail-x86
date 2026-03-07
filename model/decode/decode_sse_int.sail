// x86-64 Decoder — 2-Byte Opcode Map: SSE Integer Operations
//
// SSE/SSE2 packed integer arithmetic, logical, shift, pack/unpack, compare.

val dispatch_2byte_sse_int : (range(0, 255), Prefixes) -> ExecutionResult
function dispatch_2byte_sse_int(op, pfx) = {
  match op {
    // 0F 60-6B: PUNPCK*/PACKSSWB/PCMPGT*/PUNPCK*/PACKSSDW/PCMPEQ*
    op if 96 <= op & op <= 107 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        raise_UD()
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(addr) => mem_read128(addr),
        };
        let sub_op : range(0, 15) = op - 96;
        match sub_op {
          0 => exec_punpcklbw(xreg, src_xmm),   // 0F 60
          1 => exec_punpcklwd(xreg, src_xmm),   // 0F 61
          2 => exec_punpckldq(xreg, src_xmm),   // 0F 62
          4 => exec_pcmpgtb(xreg, src_xmm),     // 0F 64
          5 => exec_pcmpgtw(xreg, src_xmm),     // 0F 65
          6 => exec_pcmpgtd(xreg, src_xmm),     // 0F 66
          8 => exec_punpckhbw(xreg, src_xmm),   // 0F 68
          9 => exec_punpckhwd(xreg, src_xmm),   // 0F 69
          10 => exec_punpckhdq(xreg, src_xmm),  // 0F 6A
          3 => exec_packsswb(xreg, src_xmm),     // 0F 63
          7 => exec_packuswb(xreg, src_xmm),     // 0F 67
          11 => exec_packssdw(xreg, src_xmm),     // 0F 6B
          _ => raise_UD(),
        }
      }
    },
    // 0F 6C: PUNPCKLQDQ
    108 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        raise_UD()
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(addr) => mem_read128(addr),
        };
        exec_punpcklqdq(xreg, src_xmm)
      }
    },
    // 0F 6D: PUNPCKHQDQ
    109 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        raise_UD()
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(addr) => mem_read128(addr),
        };
        exec_punpckhqdq(xreg, src_xmm)
      }
    },
    // 0F 6E: MOVD/MOVQ xmm, r/m32 (or r/m64 with REX.W)
    110 => {
      let modrm = fetch_byte();
      let xreg = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.rex_w then {
        // MOVQ xmm, r/m64
        let v : qword = match rm {
          RM_reg(idx) => read_gpr64(idx),
          RM_mem(addr) => mem_read64(addr),
        };
        write_xmm_legacy(xreg, zero_extend(v));
        Ok()
      } else {
        // MOVD xmm, r/m32
        let v : dword = match rm {
          RM_reg(idx) => read_gpr32(idx),
          RM_mem(addr) => mem_read32(addr),
        };
        write_xmm_legacy(xreg, zero_extend(v));
        Ok()
      }
    },
    // 0F 6F: MOVDQA/MOVDQU xmm, xmm/m128
    111 => {
      let mp = get_mandatory_prefix(pfx);
      let modrm = fetch_byte();
      let xreg = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      match rm {
        RM_reg(_) => {
          match mp {
            MP_66 => exec_movdqa(xreg, read_xmm(modrm_xmm_rm(modrm, pfx))),
            MP_F3 => exec_movdqu(xreg, read_xmm(modrm_xmm_rm(modrm, pfx))),
            _     => raise_UD(),
          }
        },
        RM_mem(addr) => {
          write_xmm(xreg, mem_read128(addr));
          Ok()
        },
      }
    },
    // 0F 70: PSHUFD/PSHUFHW/PSHUFLW
    112 => {
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
        MP_66 => exec_pshufd(xreg, src_xmm, imm),
        MP_F3 => exec_pshufhw(xreg, src_xmm, imm),
        MP_F2 => exec_pshuflw(xreg, src_xmm, imm),
        _     => raise_UD(),
      }
    },
    // 0F 71: Group 12 — PSRLW/PSRAW/PSLLW imm8 (66 prefix)
    113 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        raise_UD()
      } else {
        let modrm = fetch_byte();
        let reg_field : range(0, 7) = unsigned(modrm[5..3]);
        let _ = decode_rm(modrm, pfx);
        let xreg = modrm_xmm_rm(modrm, pfx);
        let imm = fetch_byte();
        if reg_field == 2 then exec_psrlw_imm(xreg, imm)
        else if reg_field == 4 then exec_psraw_imm(xreg, imm)
        else if reg_field == 6 then exec_psllw_imm(xreg, imm)
        else raise_UD()
      }
    },
    // 0F 72: Group 13 — PSRLD/PSRAD/PSLLD imm8 (66 prefix)
    114 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        raise_UD()
      } else {
        let modrm = fetch_byte();
        let reg_field : range(0, 7) = unsigned(modrm[5..3]);
        let _ = decode_rm(modrm, pfx);
        let xreg = modrm_xmm_rm(modrm, pfx);
        let imm = fetch_byte();
        if reg_field == 2 then exec_psrld_imm(xreg, imm)
        else if reg_field == 4 then exec_psrad_imm(xreg, imm)
        else if reg_field == 6 then exec_pslld_imm(xreg, imm)
        else raise_UD()
      }
    },
    // 0F 73: Group 14 — PSRLQ/PSRLDQ/PSLLQ/PSLLDQ imm8 (66 prefix)
    115 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        raise_UD()
      } else {
        let modrm = fetch_byte();
        let reg_field : range(0, 7) = unsigned(modrm[5..3]);
        let _ = decode_rm(modrm, pfx);
        let xreg = modrm_xmm_rm(modrm, pfx);
        let imm = fetch_byte();
        if reg_field == 2 then exec_psrlq_imm(xreg, imm)
        else if reg_field == 3 then exec_psrldq(xreg, imm)
        else if reg_field == 6 then exec_psllq_imm(xreg, imm)
        else if reg_field == 7 then exec_pslldq(xreg, imm)
        else raise_UD()
      }
    },
    // 0F 74-76: PCMPEQB/PCMPEQW/PCMPEQD (66 prefix)
    op if 116 <= op & op <= 118 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        raise_UD()
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(addr) => mem_read128(addr),
        };
        match op {
          116 => exec_pcmpeqb(xreg, src_xmm),
          117 => exec_pcmpeqw(xreg, src_xmm),
          _   => exec_pcmpeqd(xreg, src_xmm),
        }
      }
    },
    // 0F 7E: MOVD/MOVQ r/m32, xmm (or r/m64 with REX.W) / MOVQ xmm,xmm/m64
    126 => {
      let mp = get_mandatory_prefix(pfx);
      let modrm = fetch_byte();
      let rm = decode_rm(modrm, pfx);
      match mp {
        MP_66 => {
          // MOVD/MOVQ r/m, xmm
          let src_xmm = modrm_xmm_reg(modrm, pfx);
          let v = read_xmm(src_xmm);
          if pfx.rex_w then {
            match rm {
              RM_reg(idx) => write_gpr64(idx, v[63..0]),
              RM_mem(addr) => mem_write64(addr, v[63..0]),
            };
          } else {
            match rm {
              RM_reg(idx) => write_gpr32(idx, v[31..0]),
              RM_mem(addr) => mem_write32(addr, v[31..0]),
            };
          };
          Ok()
        },
        MP_F3 => {
          // MOVQ xmm1, xmm2/m64
          let xreg = modrm_xmm_reg(modrm, pfx);
          match rm {
            RM_reg(_) => {
              let src = read_xmm(modrm_xmm_rm(modrm, pfx));
              write_xmm_legacy(xreg, zero_extend(src[63..0]));
              Ok()
            },
            RM_mem(addr) => {
              let v : xmmword = zero_extend(mem_read64(addr));
              write_xmm(xreg, v);
              Ok()
            },
          }
        },
        _ => raise_UD(),
      }
    },
    // 0F 7F: MOVDQA/MOVDQU xmm/m128, xmm
    127 => {
      let mp = get_mandatory_prefix(pfx);
      let modrm = fetch_byte();
      let xreg = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      match rm {
        RM_reg(_) => {
          let dst_xmm = modrm_xmm_rm(modrm, pfx);
          match mp {
            MP_66 => exec_movdqa(dst_xmm, read_xmm(xreg)),
            MP_F3 => exec_movdqu(dst_xmm, read_xmm(xreg)),
            _     => raise_UD(),
          }
        },
        RM_mem(addr) => {
          mem_write128(addr, read_xmm(xreg));
          Ok()
        },
      }
    },
    // 0F D7: PMOVMSKB r, xmm (66 prefix)
    215 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        raise_UD()
      } else {
        let modrm = fetch_byte();
        let reg = modrm_reg(modrm, pfx);
        let _ = decode_rm(modrm, pfx);
        let src_xmm : xmmword = read_xmm(modrm_xmm_rm(modrm, pfx));
        exec_pmovmskb(reg, src_xmm)
      }
    },
    // 0F DB: PAND xmm, xmm/m128 (66 prefix)
    219 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        raise_UD()
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(addr) => mem_read128(addr),
        };
        exec_pand_xmm(xreg, src_xmm)
      }
    },
    // 0F DF: PANDN xmm, xmm/m128 (66 prefix)
    223 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        raise_UD()
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(addr) => mem_read128(addr),
        };
        exec_pandn(xreg, src_xmm)
      }
    },
    // 0F E5: PMULLW xmm, xmm/m128 (66 prefix)
    229 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        raise_UD()
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(addr) => mem_read128(addr),
        };
        exec_pmullw(xreg, src_xmm)
      }
    },
    // 0F EB: POR xmm, xmm/m128 (66 prefix)
    235 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        raise_UD()
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(addr) => mem_read128(addr),
        };
        exec_por(xreg, src_xmm)
      }
    },
    // 0F EF: PXOR xmm, xmm/m128 (66 prefix)
    239 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        raise_UD()
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(addr) => mem_read128(addr),
        };
        exec_pxor_xmm(xreg, src_xmm)
      }
    },
    // 0F D4: PADDQ (66 prefix)
    212 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        raise_UD()
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(addr) => mem_read128(addr),
        };
        exec_paddq(xreg, src_xmm)
      }
    },
    // 0F F4: PMULUDQ (66 prefix)
    244 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        raise_UD()
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(addr) => mem_read128(addr),
        };
        exec_pmuludq(xreg, src_xmm)
      }
    },
    // 0F F8: PSUBB (66 prefix)
    248 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        raise_UD()
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(addr) => mem_read128(addr),
        };
        exec_psubb(xreg, src_xmm)
      }
    },
    // 0F F9: PSUBW (66 prefix)
    249 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        raise_UD()
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(addr) => mem_read128(addr),
        };
        exec_psubw(xreg, src_xmm)
      }
    },
    // 0F FA: PSUBD (66 prefix)
    250 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        raise_UD()
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(addr) => mem_read128(addr),
        };
        exec_psubd(xreg, src_xmm)
      }
    },
    // 0F FB: PSUBQ (66 prefix)
    251 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        raise_UD()
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(addr) => mem_read128(addr),
        };
        exec_psubq(xreg, src_xmm)
      }
    },
    // 0F FC: PADDB (66 prefix)
    252 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        raise_UD()
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(addr) => mem_read128(addr),
        };
        exec_paddb_xmm(xreg, src_xmm)
      }
    },
    // 0F FD: PADDW (66 prefix)
    253 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        raise_UD()
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(addr) => mem_read128(addr),
        };
        exec_paddw(xreg, src_xmm)
      }
    },
    // 0F FE: PADDD (66 prefix)
    254 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        raise_UD()
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(addr) => mem_read128(addr),
        };
        exec_paddd(xreg, src_xmm)
      }
    },
    // 0F E0: PAVGB (66 prefix)
    224 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        raise_UD()
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(addr) => mem_read128(addr),
        };
        exec_pavgb(xreg, src_xmm)
      }
    },
    // 0F DA: PMINUB (66 prefix)
    218 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        raise_UD()
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(addr) => mem_read128(addr),
        };
        exec_pminub(xreg, src_xmm)
      }
    },
    // 0F DE: PMAXUB (66 prefix)
    222 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        raise_UD()
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(addr) => mem_read128(addr),
        };
        exec_pmaxub(xreg, src_xmm)
      }
    },
    // 0F F6: PSADBW (66 prefix)
    246 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        raise_UD()
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(addr) => mem_read128(addr),
        };
        exec_psadbw(xreg, src_xmm)
      }
    },
    // 0F E7: MOVNTDQ m128, xmm (66 prefix) / MOVNTQ m64, mm (no prefix)
    231 => {
      let mp = get_mandatory_prefix(pfx);
      let modrm = fetch_byte();
      let xreg = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      match rm {
        RM_mem(addr) => {
          if mp == MP_66 then {
            mem_write128(addr, read_xmm(xreg));
            Ok()
          } else {
            raise_UD()
          }
        },
        RM_reg(_) => raise_UD(),
      }
    },
    // 0F C4: PINSRW xmm, r32/m16, imm8 (66 prefix)
    196 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        raise_UD()
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let v : word = match rm {
          RM_reg(idx) => read_gpr16(idx),
          RM_mem(addr) => mem_read16(addr),
        };
        let imm = fetch_byte();
        exec_pinsrw(xreg, v, imm)
      }
    },
    // 0F C5: PEXTRW r32, xmm, imm8 (66 prefix)
    197 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        raise_UD()
      } else {
        let modrm = fetch_byte();
        let reg = modrm_reg(modrm, pfx);
        let _ = decode_rm(modrm, pfx);
        let src_xmm : xmmword = read_xmm(modrm_xmm_rm(modrm, pfx));
        let imm = fetch_byte();
        exec_pextrw(reg, src_xmm, imm)
      }
    },
    // 0F D1: PSRLW xmm, xmm/m128 (66 prefix)
    209 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        raise_UD()
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, rm, pfx);
        exec_psrlw_xmm(xreg, src_xmm)
      }
    },
    // 0F D2: PSRLD xmm, xmm/m128 (66 prefix)
    210 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        raise_UD()
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, rm, pfx);
        exec_psrld_xmm(xreg, src_xmm)
      }
    },
    // 0F D3: PSRLQ xmm, xmm/m128 (66 prefix)
    211 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        raise_UD()
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, rm, pfx);
        exec_psrlq_xmm(xreg, src_xmm)
      }
    },
    // 0F D5: PMULHW (66 prefix)
    213 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        raise_UD()
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, rm, pfx);
        exec_pmulhw(xreg, src_xmm)
      }
    },
    // 0F D8: PSUBUSB (66 prefix)
    216 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        raise_UD()
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, rm, pfx);
        exec_psubusb(xreg, src_xmm)
      }
    },
    // 0F D9: PSUBUSW (66 prefix)
    217 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        raise_UD()
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, rm, pfx);
        exec_psubusw(xreg, src_xmm)
      }
    },
    // 0F DC: PADDUSB (66 prefix)
    220 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        raise_UD()
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, rm, pfx);
        exec_paddusb(xreg, src_xmm)
      }
    },
    // 0F DD: PADDUSW (66 prefix)
    221 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        raise_UD()
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, rm, pfx);
        exec_paddusw(xreg, src_xmm)
      }
    },
    // 0F E1: PSRAW xmm, xmm/m128 (66 prefix)
    225 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        raise_UD()
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, rm, pfx);
        exec_psraw_xmm(xreg, src_xmm)
      }
    },
    // 0F E2: PSRAD xmm, xmm/m128 (66 prefix)
    226 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        raise_UD()
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, rm, pfx);
        exec_psrad_xmm(xreg, src_xmm)
      }
    },
    // 0F E3: PAVGW (66 prefix)
    227 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        raise_UD()
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, rm, pfx);
        exec_pavgw(xreg, src_xmm)
      }
    },
    // 0F E4: PMULHUW (66 prefix)
    228 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        raise_UD()
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, rm, pfx);
        exec_pmulhuw(xreg, src_xmm)
      }
    },
    // 0F E8: PSUBSB (66 prefix)
    232 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        raise_UD()
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, rm, pfx);
        exec_psubsb(xreg, src_xmm)
      }
    },
    // 0F E9: PSUBSW (66 prefix)
    233 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        raise_UD()
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, rm, pfx);
        exec_psubsw(xreg, src_xmm)
      }
    },
    // 0F EC: PADDSB (66 prefix)
    236 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        raise_UD()
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, rm, pfx);
        exec_paddsb(xreg, src_xmm)
      }
    },
    // 0F ED: PADDSW (66 prefix)
    237 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        raise_UD()
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, rm, pfx);
        exec_paddsw(xreg, src_xmm)
      }
    },
    // 0F F0: LDDQU xmm, m128 (F2 prefix)
    240 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_F2 then {
        raise_UD()
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        match rm {
          RM_mem(addr) => {
            write_xmm(xreg, mem_read128(addr));
            Ok()
          },
          RM_reg(_) => raise_UD(),
        }
      }
    },
    // 0F F1: PSLLW xmm, xmm/m128 (66 prefix)
    241 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        raise_UD()
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, rm, pfx);
        exec_psllw_xmm(xreg, src_xmm)
      }
    },
    // 0F F2: PSLLD xmm, xmm/m128 (66 prefix)
    242 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        raise_UD()
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, rm, pfx);
        exec_pslld_xmm(xreg, src_xmm)
      }
    },
    // 0F F3: PSLLQ xmm, xmm/m128 (66 prefix)
    243 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        raise_UD()
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, rm, pfx);
        exec_psllq_xmm(xreg, src_xmm)
      }
    },
    // 0F F5: PMADDWD (66 prefix)
    245 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        raise_UD()
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, rm, pfx);
        exec_pmaddwd(xreg, src_xmm)
      }
    },
    // 0F F7: MASKMOVDQU xmm, xmm (66 prefix)
    247 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        raise_UD()
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let _ = decode_rm(modrm, pfx);
        let src_xmm : xmmword = read_xmm(modrm_xmm_rm(modrm, pfx));
        let addr = read_gpr64(RDI);
        exec_maskmovdqu(read_xmm(xreg), src_xmm, addr)
      }
    },
    // 0F EE: PMAXSW (66 prefix)
    238 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        raise_UD()
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, rm, pfx);
        exec_pmaxsw(xreg, src_xmm)
      }
    },
    // 0F EA: PMINSW (66 prefix)
    234 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        raise_UD()
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, rm, pfx);
        exec_pminsw(xreg, src_xmm)
      }
    },
    _ => raise_UD(),
  }
}

// =========================================================================
// 3-Byte Opcode Map: SSE Integer Operations
// =========================================================================

val blend_byte : (byte, byte, bit) -> byte
function blend_byte(a, b, sel) = if sel == bitone then b else a

// 0F 38 xx — SSE integer operations (SSSE3, SSE4.1, SSE4.2, AES-NI)
val dispatch_3byte_38_sse_int : (byte, Prefixes) -> ExecutionResult
function dispatch_3byte_38_sse_int(opcode, pfx) = {
  let op : range(0, 255) = unsigned(opcode);
  let mp = get_mandatory_prefix(pfx);
  if mp != MP_66 then {
    raise_UD()
  } else {
    let modrm = fetch_byte();
    let xreg = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let src_xmm : xmmword = decode_xmm_src(modrm, rm, pfx);
    match op {
      // SSSE3
      0  => exec_pshufb(xreg, src_xmm),
      1  => exec_phaddw(xreg, src_xmm),
      2  => exec_phaddd(xreg, src_xmm),
      3  => exec_phaddsw(xreg, src_xmm),
      4  => exec_pmaddubsw(xreg, src_xmm),
      5  => exec_phsubw(xreg, src_xmm),
      6  => exec_phsubd(xreg, src_xmm),
      7  => exec_phsubsw(xreg, src_xmm),
      8  => exec_psignb(xreg, src_xmm),
      9  => exec_psignw(xreg, src_xmm),
      10 => exec_psignd(xreg, src_xmm),
      11 => exec_pmulhrsw(xreg, src_xmm),

      // SSE4.1 — PBLENDVB (implicit XMM0 mask)
      16 => {
        let a : xmmword = read_xmm(xreg);
        let m : xmmword = read_xmm(0);
        let r0  : byte = blend_byte(a[7..0],     src_xmm[7..0],     m[7]);
        let r1  : byte = blend_byte(a[15..8],    src_xmm[15..8],    m[15]);
        let r2  : byte = blend_byte(a[23..16],   src_xmm[23..16],   m[23]);
        let r3  : byte = blend_byte(a[31..24],   src_xmm[31..24],   m[31]);
        let r4  : byte = blend_byte(a[39..32],   src_xmm[39..32],   m[39]);
        let r5  : byte = blend_byte(a[47..40],   src_xmm[47..40],   m[47]);
        let r6  : byte = blend_byte(a[55..48],   src_xmm[55..48],   m[55]);
        let r7  : byte = blend_byte(a[63..56],   src_xmm[63..56],   m[63]);
        let r8  : byte = blend_byte(a[71..64],   src_xmm[71..64],   m[71]);
        let r9  : byte = blend_byte(a[79..72],   src_xmm[79..72],   m[79]);
        let r10 : byte = blend_byte(a[87..80],   src_xmm[87..80],   m[87]);
        let r11 : byte = blend_byte(a[95..88],   src_xmm[95..88],   m[95]);
        let r12 : byte = blend_byte(a[103..96],  src_xmm[103..96],  m[103]);
        let r13 : byte = blend_byte(a[111..104], src_xmm[111..104], m[111]);
        let r14 : byte = blend_byte(a[119..112], src_xmm[119..112], m[119]);
        let r15 : byte = blend_byte(a[127..120], src_xmm[127..120], m[127]);
        write_xmm_legacy(xreg, r15 @ r14 @ r13 @ r12 @ r11 @ r10 @ r9 @ r8 @ r7 @ r6 @ r5 @ r4 @ r3 @ r2 @ r1 @ r0);
        Ok()
      },

      // SSE4.1 — PTEST
      23 => exec_ptest(read_xmm(xreg), src_xmm),

      // SSSE3
      28 => exec_pabsb(xreg, src_xmm),
      29 => exec_pabsw(xreg, src_xmm),
      30 => exec_pabsd(xreg, src_xmm),

      // SSE4.1 — sign/zero extend
      32 => exec_pmovsxbw(xreg, src_xmm),
      33 => exec_pmovsxbd(xreg, src_xmm),
      34 => exec_pmovsxbq(xreg, src_xmm),
      35 => exec_pmovsxwd(xreg, src_xmm),
      36 => exec_pmovsxwq(xreg, src_xmm),
      37 => exec_pmovsxdq(xreg, src_xmm),

      // SSE4.1
      40 => exec_pmuldq(xreg, src_xmm),
      41 => exec_pcmpeqq(xreg, src_xmm),
      42 => {
        // MOVNTDQA xmm, m128
        match rm {
          RM_mem(addr) => {
            write_xmm_legacy(xreg, mem_read128(addr));
            Ok()
          },
          RM_reg(_) => raise_UD(),
        }
      },
      43 => exec_packusdw(xreg, src_xmm),

      // SSE4.1 — zero extend
      48 => exec_pmovzxbw(xreg, src_xmm),
      49 => exec_pmovzxbd(xreg, src_xmm),
      50 => exec_pmovzxbq(xreg, src_xmm),
      51 => exec_pmovzxwd(xreg, src_xmm),
      52 => exec_pmovzxwq(xreg, src_xmm),
      53 => exec_pmovzxdq(xreg, src_xmm),

      // SSE4.2
      55 => exec_pcmpgtq(xreg, src_xmm),

      // SSE4.1 — min/max
      56 => exec_pminsb(xreg, src_xmm),
      57 => exec_pminsd(xreg, src_xmm),
      58 => exec_pminuw(xreg, src_xmm),
      59 => exec_pminud(xreg, src_xmm),
      60 => exec_pmaxsb(xreg, src_xmm),
      61 => exec_pmaxsd(xreg, src_xmm),
      62 => exec_pmaxuw(xreg, src_xmm),
      63 => exec_pmaxud(xreg, src_xmm),

      // SSE4.1
      64 => exec_pmulld(xreg, src_xmm),
      65 => exec_phminposuw(xreg, src_xmm),

      // AES-NI
      219 => exec_aesimc(xreg, src_xmm),
      220 => exec_aesenc(xreg, src_xmm),
      221 => exec_aesdec(xreg, src_xmm),
      222 => exec_aesenclast(xreg, src_xmm),
      223 => exec_aesdeclast(xreg, src_xmm),

      _ => raise_UD(),
    }
  }
}

// 0F 3A xx — SSE integer operations (PBLENDW, PALIGNR, PEXTR*, PINSR*,
//            MPSADBW, PCLMULQDQ, PCMPxSTRx, AESKEYGENASSIST)
val dispatch_3byte_3a_sse_int : (byte, Prefixes) -> ExecutionResult
function dispatch_3byte_3a_sse_int(opcode, pfx) = {
  let op : range(0, 255) = unsigned(opcode);
  let mp = get_mandatory_prefix(pfx);
  if mp != MP_66 then {
    raise_UD()
  } else {
    let modrm = fetch_byte();
    let xreg = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    match op {
      // SSE4.1 — PBLENDW
      14 => {
        let src_xmm = decode_xmm_src(modrm, rm, pfx);
        let imm = fetch_byte();
        exec_pblendw(xreg, src_xmm, imm)
      },

      // SSSE3 — PALIGNR
      15 => {
        let src_xmm = decode_xmm_src(modrm, rm, pfx);
        let imm = fetch_byte();
        exec_palignr(xreg, src_xmm, imm)
      },

      // SSE4.1 — PEXTRB r/m8, xmm, imm8
      20 => {
        let imm = fetch_byte();
        let v = extract_byte_from_xmm(read_xmm(xreg), imm);
        match rm {
          RM_reg(_) => {
            let dst_reg = modrm_rm_reg(modrm, pfx);
            write_gpr32(dst_reg, zero_extend(v));
          },
          RM_mem(addr) => mem_write8(fixup_addr(addr), v),
        };
        Ok()
      },

      // SSE4.1 — PEXTRD/PEXTRQ r/m, xmm, imm8
      22 => {
        let imm = fetch_byte();
        let src = read_xmm(xreg);
        match rm {
          RM_reg(_) => {
            let dst_reg = modrm_rm_reg(modrm, pfx);
            if pfx.rex_w then write_gpr64(dst_reg, extract_qword_from_xmm(src, imm))
            else write_gpr32(dst_reg, extract_dword_from_xmm(src, imm))
          },
          RM_mem(addr) => {
            let a = fixup_addr(addr);
            if pfx.rex_w then mem_write64(a, extract_qword_from_xmm(src, imm))
            else mem_write32(a, extract_dword_from_xmm(src, imm))
          },
        };
        Ok()
      },

      // SSE4.1 — PINSRB xmm, r/m8, imm8
      32 => {
        let imm = fetch_byte();
        let v : byte = match rm {
          RM_reg(idx) => read_gpr8l(idx),
          RM_mem(addr) => mem_read8(addr),
        };
        exec_pinsrb(xreg, v, imm)
      },

      // SSE4.1 — PINSRD/PINSRQ xmm, r/m, imm8
      34 => {
        let imm = fetch_byte();
        if pfx.rex_w then {
          let v : qword = match rm {
            RM_reg(idx) => read_gpr64(idx),
            RM_mem(addr) => mem_read64(addr),
          };
          exec_pinsrq(xreg, v, imm)
        } else {
          let v : dword = match rm {
            RM_reg(idx) => read_gpr32(idx),
            RM_mem(addr) => mem_read32(addr),
          };
          exec_pinsrd(xreg, v, imm)
        }
      },

      // SSE4.1 — MPSADBW
      66 => {
        let src_xmm = decode_xmm_src(modrm, rm, pfx);
        let imm = fetch_byte();
        exec_mpsadbw(xreg, src_xmm, imm)
      },

      // PCLMULQDQ
      68 => {
        let src_xmm = decode_xmm_src(modrm, rm, pfx);
        let imm = fetch_byte();
        exec_pclmulqdq(xreg, src_xmm, imm)
      },

      // SSE4.2 — string compare
      96 => {
        let src_xmm = decode_xmm_src(modrm, rm, pfx);
        let imm = fetch_byte();
        exec_pcmpestrm(xreg, src_xmm, imm)
      },
      97 => {
        let src_xmm = decode_xmm_src(modrm, rm, pfx);
        let imm = fetch_byte();
        exec_pcmpestri(xreg, src_xmm, imm)
      },
      98 => {
        let src_xmm = decode_xmm_src(modrm, rm, pfx);
        let imm = fetch_byte();
        exec_pcmpistrm(xreg, src_xmm, imm)
      },
      99 => {
        let src_xmm = decode_xmm_src(modrm, rm, pfx);
        let imm = fetch_byte();
        exec_pcmpistri(xreg, src_xmm, imm)
      },

      // AES-NI — AESKEYGENASSIST
      223 => {
        let src_xmm = decode_xmm_src(modrm, rm, pfx);
        let imm = fetch_byte();
        exec_aeskeygenassist(xreg, src_xmm, imm)
      },

      _ => raise_UD(),
    }
  }
}

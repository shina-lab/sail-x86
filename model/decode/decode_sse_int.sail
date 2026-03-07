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

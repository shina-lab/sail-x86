// x86-64 Decoder — 2-Byte Opcode Map (0F xx) Dispatch
//
// Phase 2: CMOVcc, SETcc, Jcc rel32, MOVZX/SX, BSF/BSR, CMPXCHG, BT*,
// SHLD/SHRD, IMUL 2-op, BSWAP, XADD, etc.

// External system functions
val __syscall : (qword, qword) -> ExecutionResult
val __fxsave : qword -> ExecutionResult
val __fxsave64 : qword -> ExecutionResult
val __fxrstor : qword -> ExecutionResult
val __fxrstor64 : qword -> ExecutionResult

val dispatch_opcode_2byte : (byte, Prefixes) -> ExecutionResult
function dispatch_opcode_2byte(opcode, pfx) = {
  let op : range(0, 255) = unsigned(opcode);
  match op {

    // 0F 05: SYSCALL
    5 => __syscall(RIP, read_rflags()),

    // 0F 1F: Multi-byte NOP r/m (prefetch hint)
    31 => {
      let modrm = fetch_byte();
      let _ = decode_rm(modrm, pfx);  // consume ModR/M + SIB + disp
      exec_nop()
    },

    // 0F 01: Group 7 (privileged/system instructions)
    1 => {
      let modrm = fetch_byte();
      let modrm_val : range(0, 255) = unsigned(modrm);
      match modrm_val {
        // 0F 01 D0: XGETBV
        208 => {
          let ecx_val : dword = read_gpr32(RCX);
          if ecx_val == 0x00000000 then {
            write_gpr32(RAX, 0x00000007);
            write_gpr32(RDX, 0x00000000);
            Ok(())
          } else raise_GP0()
        },
        _ => raise_UD(),
      }
    },

    // 0F 0B: UD2
    11 => {
      raise_UD()
    },

    // 0F 18-1E: Prefetch hints / multi-byte NOPs
    // These all consume ModR/M and do nothing.
    op if 24 <= op & op <= 30 => {
      let modrm = fetch_byte();
      let _ = decode_rm(modrm, pfx);
      exec_nop()
    },

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
              write_xmm(xreg, mem_read128(addr));
              Ok(())
            },
          }
        },
        MP_66 => {
          // MOVUPD xmm1, xmm2/m128
          match rm {
            RM_reg(_) => exec_movupd_load(xreg, read_xmm(modrm_xmm_rm(modrm, pfx))),
            RM_mem(addr) => {
              write_xmm(xreg, mem_read128(addr));
              Ok(())
            },
          }
        },
        MP_F3 => {
          // MOVSS xmm1, xmm2/m32
          match rm {
            RM_reg(_) => exec_movss_xmm(xreg, read_xmm(modrm_xmm_rm(modrm, pfx))),
            RM_mem(addr) => {
              let v : xmmword = zero_extend(mem_read32(addr));
              write_xmm(xreg, v);
              Ok(())
            },
          }
        },
        MP_F2 => {
          // MOVSD xmm1, xmm2/m64
          match rm {
            RM_reg(_) => exec_movsd_xmm(xreg, read_xmm(modrm_xmm_rm(modrm, pfx))),
            RM_mem(addr) => {
              let v : xmmword = zero_extend(mem_read64(addr));
              write_xmm(xreg, v);
              Ok(())
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
              mem_write128(addr, read_xmm(xreg));
              Ok(())
            },
          }
        },
        MP_66 => {
          // MOVUPD xmm2/m128, xmm1
          match rm {
            RM_reg(_) => exec_movupd_load(modrm_xmm_rm(modrm, pfx), read_xmm(xreg)),
            RM_mem(addr) => {
              mem_write128(addr, read_xmm(xreg));
              Ok(())
            },
          }
        },
        MP_F3 => {
          // MOVSS m32, xmm1
          match rm {
            RM_reg(_) => exec_movss_xmm(modrm_xmm_rm(modrm, pfx), read_xmm(xreg)),
            RM_mem(addr) => {
              let v = read_xmm(xreg);
              mem_write32(addr, v[31..0]);
              Ok(())
            },
          }
        },
        MP_F2 => {
          // MOVSD m64, xmm1
          match rm {
            RM_reg(_) => exec_movsd_xmm(modrm_xmm_rm(modrm, pfx), read_xmm(xreg)),
            RM_mem(addr) => {
              let v = read_xmm(xreg);
              mem_write64(addr, v[63..0]);
              Ok(())
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
              write_xmm_legacy(xreg, high @ src[127..64]); Ok(())
            },
            RM_mem(addr) => {
              var xmm : xmmword = read_xmm(xreg);
              xmm[63..0] = mem_read64(addr);
              write_xmm_legacy(xreg, xmm); Ok(())
            },
          }
        },
        MP_66 => {
          // MOVLPD xmm, m64
          match rm {
            RM_mem(addr) => {
              var xmm : xmmword = read_xmm(xreg);
              xmm[63..0] = mem_read64(addr);
              write_xmm_legacy(xreg, xmm); Ok(())
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
              write_xmm_legacy(xreg, s[63..0] @ s[63..0]); Ok(())
            },
            RM_mem(addr) => {
              let lo = mem_read64(addr);
              write_xmm(xreg, lo @ lo);
              Ok(())
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
          mem_write64(addr, v[63..0]);
          Ok(())
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
        MP_NONE => exec_unpcklps(xreg, src),
        MP_66   => exec_unpcklpd(xreg, src),
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
        MP_NONE => exec_unpckhps(xreg, src),
        MP_66   => exec_unpckhpd(xreg, src),
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
              write_xmm_legacy(xreg, src[63..0] @ low); Ok(())
            },
            RM_mem(addr) => {
              var xmm : xmmword = read_xmm(xreg);
              xmm[127..64] = mem_read64(addr);
              write_xmm_legacy(xreg, xmm); Ok(())
            },
          }
        },
        MP_66 => {
          match rm {
            RM_mem(addr) => {
              var xmm : xmmword = read_xmm(xreg);
              xmm[127..64] = mem_read64(addr);
              write_xmm_legacy(xreg, xmm); Ok(())
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
          mem_write64(addr, v[127..64]);
          Ok(())
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
          write_xmm(xreg, mem_read128(addr));
          Ok(())
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
          mem_write128(addr, read_xmm(xreg));
          Ok(())
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
          write_xmm_legacy(xreg, xmm);
          Ok(())
        },
        MP_F2 => {
          let result : qword = match os {
            OS64 => __int64_to_f64(src_val),
            _    => __int32_to_f64(src_val[31..0]),
          };
          var xmm : xmmword = read_xmm(xreg);
          xmm[63..0] = result;
          write_xmm_legacy(xreg, xmm);
          Ok(())
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
          };
          Ok(())
        },
        MP_F2 => {
          match os {
            OS64 => write_gpr64(reg, __f64_to_int64_trunc(src_xmm[63..0])),
            _    => write_gpr32(reg, __f64_to_int32_trunc(src_xmm[63..0])),
          };
          Ok(())
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
          };
          Ok(())
        },
        MP_F2 => {
          match os {
            OS64 => write_gpr64(reg, __f64_to_int64(src_xmm[63..0])),
            _    => write_gpr32(reg, __f64_to_int32(src_xmm[63..0])),
          };
          Ok(())
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
        MP_NONE => exec_ucomiss(xreg, src_xmm),
        MP_66   => exec_ucomisd(xreg, src_xmm),
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
        MP_NONE => exec_comiss(xreg, src_xmm),
        MP_66   => exec_comisd(xreg, src_xmm),
        _       => raise_UD(),
      }
    },

    // 0F 31: RDTSC
    49 => {
      let tsc : qword = __rdtsc();
      write_gpr32(RAX, tsc[31..0]);
      write_gpr32(RDX, tsc[63..32]);
      Ok(())
    },

    // 0F 40-4F: CMOVcc r, r/m
    op if 64 <= op & op <= 79 => {
      let cc : cc_idx = op - 64;
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if eval_cc(cc) then {
        let v = read_rm_val(rm, os, pfx.has_rex);
        write_gpr(reg, os, v);
      };
      Ok(())
    },

    // 0F 80-8F: Jcc rel32 (f64)
    op if 128 <= op & op <= 143 => {
      let cc : cc_idx = op - 128;
      let offset = fetch_rel32();
      exec_jcc(cc, offset)
    },

    // 0F 90-9F: SETcc r/m8
    op if 144 <= op & op <= 159 => {
      let cc : cc_idx = op - 144;
      let modrm = fetch_byte();
      let rm = decode_rm(modrm, pfx);
      let v : qword = if eval_cc(cc) then 0x0000000000000001 else zeros();
      write_rm_val(rm, OS8, pfx.has_rex, v);
      Ok(())
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
          write_gpr32(reg, zero_extend(mask)); Ok(())
        },
        MP_66 => {
          let mask : bits(2) = src_xmm[127] @ src_xmm[63];
          write_gpr32(reg, zero_extend(mask)); Ok(())
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
        1 => { // 0F 51: SQRT
          match mp {
            MP_NONE => exec_sqrtps(xreg, src_xmm),
            MP_66   => exec_sqrtpd(xreg, src_xmm),
            MP_F3   => exec_sqrtss(xreg, src_xmm),
            MP_F2   => exec_sqrtsd(xreg, src_xmm),
          }
        },
        4 => { // 0F 54: ANDPS/ANDPD
          match mp {
            MP_NONE => exec_andps(xreg, src_xmm),
            MP_66   => exec_andpd(xreg, src_xmm),
            _       => raise_UD(),
          }
        },
        5 => { // 0F 55: ANDNPS/ANDNPD
          match mp {
            MP_NONE => exec_andnps(xreg, src_xmm),
            MP_66   => exec_andnpd(xreg, src_xmm),
            _       => raise_UD(),
          }
        },
        6 => { // 0F 56: ORPS/ORPD
          match mp {
            MP_NONE => exec_orps(xreg, src_xmm),
            MP_66   => exec_orpd(xreg, src_xmm),
            _       => raise_UD(),
          }
        },
        7 => { // 0F 57: XORPS/XORPD
          match mp {
            MP_NONE => exec_xorps(xreg, src_xmm),
            MP_66   => exec_xorpd(xreg, src_xmm),
            _       => raise_UD(),
          }
        },
        8 => { // 0F 58: ADD
          match mp {
            MP_NONE => exec_addps(xreg, src_xmm),
            MP_66   => exec_addpd(xreg, src_xmm),
            MP_F3   => exec_addss(xreg, src_xmm),
            MP_F2   => exec_addsd(xreg, src_xmm),
          }
        },
        9 => { // 0F 59: MUL
          match mp {
            MP_NONE => exec_mulps(xreg, src_xmm),
            MP_66   => exec_mulpd(xreg, src_xmm),
            MP_F3   => exec_mulss(xreg, src_xmm),
            MP_F2   => exec_mulsd(xreg, src_xmm),
          }
        },
        10 => { // 0F 5A: CVTPS2PD/CVTPD2PS/CVTSS2SD/CVTSD2SS
          match mp {
            MP_NONE => {
              let r : xmmword = __f32_to_f64(src_xmm[63..32]) @ __f32_to_f64(src_xmm[31..0]);
              write_xmm_legacy(xreg, r); Ok(())
            },
            MP_66 => {
              let r : xmmword = zeros(64) @ __f64_to_f32(src_xmm[127..64]) @ __f64_to_f32(src_xmm[63..0]);
              write_xmm_legacy(xreg, r); Ok(())
            },
            MP_F3 => {
              let result : qword = __f32_to_f64(src_xmm[31..0]);
              var xmm : xmmword = read_xmm(xreg);
              xmm[63..0] = result;
              write_xmm_legacy(xreg, xmm); Ok(())
            },
            MP_F2 => {
              let result : dword = __f64_to_f32(src_xmm[63..0]);
              var xmm : xmmword = read_xmm(xreg);
              xmm[31..0] = result;
              write_xmm_legacy(xreg, xmm); Ok(())
            },
          }
        },
        11 => { // 0F 5B: CVTDQ2PS/CVTPS2DQ/CVTTPS2DQ
          match mp {
            MP_NONE => {
              let r : xmmword = __int32_to_f32(src_xmm[127..96]) @ __int32_to_f32(src_xmm[95..64]) @
                __int32_to_f32(src_xmm[63..32]) @ __int32_to_f32(src_xmm[31..0]);
              write_xmm_legacy(xreg, r); Ok(())
            },
            MP_66 => {
              let r : xmmword = __f32_to_int32(src_xmm[127..96]) @ __f32_to_int32(src_xmm[95..64]) @
                __f32_to_int32(src_xmm[63..32]) @ __f32_to_int32(src_xmm[31..0]);
              write_xmm_legacy(xreg, r); Ok(())
            },
            MP_F3 => {
              let r : xmmword = __f32_to_int32_trunc(src_xmm[127..96]) @ __f32_to_int32_trunc(src_xmm[95..64]) @
                __f32_to_int32_trunc(src_xmm[63..32]) @ __f32_to_int32_trunc(src_xmm[31..0]);
              write_xmm_legacy(xreg, r); Ok(())
            },
            _       => raise_UD(),
          }
        },
        12 => { // 0F 5C: SUB
          match mp {
            MP_NONE => exec_subps(xreg, src_xmm),
            MP_66   => exec_subpd(xreg, src_xmm),
            MP_F3   => exec_subss(xreg, src_xmm),
            MP_F2   => exec_subsd(xreg, src_xmm),
          }
        },
        13 => { // 0F 5D: MIN
          match mp {
            MP_NONE => exec_minps(xreg, src_xmm),
            MP_66   => exec_minpd(xreg, src_xmm),
            MP_F3   => exec_minss(xreg, src_xmm),
            MP_F2   => exec_minsd(xreg, src_xmm),
          }
        },
        14 => { // 0F 5E: DIV
          match mp {
            MP_NONE => exec_divps(xreg, src_xmm),
            MP_66   => exec_divpd(xreg, src_xmm),
            MP_F3   => exec_divss(xreg, src_xmm),
            MP_F2   => exec_divsd(xreg, src_xmm),
          }
        },
        15 => { // 0F 5F: MAX
          match mp {
            MP_NONE => exec_maxps(xreg, src_xmm),
            MP_66   => exec_maxpd(xreg, src_xmm),
            MP_F3   => exec_maxss(xreg, src_xmm),
            MP_F2   => exec_maxsd(xreg, src_xmm),
          }
        },
        2 => { // 0F 52: RSQRTPS/RSQRTSS
          match mp {
            MP_NONE => exec_rsqrtps(xreg, src_xmm),
            MP_F3   => exec_rsqrtss(xreg, src_xmm),
            _       => raise_UD(),
          }
        },
        3 => { // 0F 53: RCPPS/RCPSS
          match mp {
            MP_NONE => exec_rcpps(xreg, src_xmm),
            MP_F3   => exec_rcpss(xreg, src_xmm),
            _       => raise_UD(),
          }
        },
        _ => raise_UD(),
      }
    },

    // 0F 60-6B: PUNPCK*/PACKSSWB/PCMPGT*/PUNPCK*/PACKSSDW/PCMPEQ*
    op if 96 <= op & op <= 107 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then raise_UD()
      else {
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
      if mp != MP_66 then raise_UD()
      else {
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
      if mp != MP_66 then raise_UD()
      else {
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
        write_xmm_legacy(xreg, zero_extend(v)); Ok(())
      } else {
        // MOVD xmm, r/m32
        let v : dword = match rm {
          RM_reg(idx) => read_gpr32(idx),
          RM_mem(addr) => mem_read32(addr),
        };
        write_xmm_legacy(xreg, zero_extend(v)); Ok(())
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
          Ok(())
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
      if mp != MP_66 then raise_UD()
      else {
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
      if mp != MP_66 then raise_UD()
      else {
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
      if mp != MP_66 then raise_UD()
      else {
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
      if mp != MP_66 then raise_UD()
      else {
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
          Ok(())
        },
        MP_F3 => {
          // MOVQ xmm1, xmm2/m64
          let xreg = modrm_xmm_reg(modrm, pfx);
          match rm {
            RM_reg(_) => {
              let src = read_xmm(modrm_xmm_rm(modrm, pfx));
              write_xmm_legacy(xreg, zero_extend(src[63..0])); Ok(())
            },
            RM_mem(addr) => {
              let v : xmmword = zero_extend(mem_read64(addr));
              write_xmm(xreg, v);
              Ok(())
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
          Ok(())
        },
      }
    },

    // 0F AE: Group 15 — LDMXCSR/STMXCSR/LFENCE/MFENCE/SFENCE
    174 => {
      let modrm = fetch_byte();
      let reg_field : range(0, 7) = unsigned(modrm[5..3]);
      let rm = decode_rm(modrm, pfx);
      if reg_field == 0 then {
        // /0: FXSAVE m512byte
        match rm {
          RM_mem(addr) => {
            if pfx.rex_w then __fxsave64(fixup_addr(addr))
            else __fxsave(fixup_addr(addr))
          },
          RM_reg(_) => raise_UD(),
        }
      } else if reg_field == 1 then {
        // /1: FXRSTOR m512byte
        match rm {
          RM_mem(addr) => {
            if pfx.rex_w then __fxrstor64(fixup_addr(addr))
            else __fxrstor(fixup_addr(addr))
          },
          RM_reg(_) => raise_UD(),
        }
      } else if reg_field == 2 then {
        // /2: LDMXCSR m32
        match rm {
          RM_mem(addr) => { __ldmxcsr(mem_read32(addr)); Ok(()) },
          RM_reg(_) => raise_UD(),
        }
      } else if reg_field == 3 then {
        // /3: STMXCSR m32
        match rm {
          RM_mem(addr) => {
            mem_write32(addr, exec_stmxcsr());
            Ok(())
          },
          RM_reg(_) => raise_UD(),
        }
      } else if reg_field == 5 then {
        // /5 mod=11: LFENCE
        Ok(())
      } else if reg_field == 6 then {
        // /6 mod=11: MFENCE
        Ok(())
      } else if reg_field == 7 then {
        // /7 mod=11: SFENCE
        Ok(())
      } else raise_UD()
    },

    // 0F A2: CPUID
    162 => {
      let leaf : dword = read_gpr32(RAX);
      let subleaf : dword = read_gpr32(RCX);
      let (out_eax, out_ebx, out_ecx, out_edx) = __cpuid(leaf, subleaf);
      write_gpr32(RAX, out_eax);
      write_gpr32(RBX, out_ebx);
      write_gpr32(RCX, out_ecx);
      write_gpr32(RDX, out_edx);
      Ok(())
    },

    // 0F A3: BT r/m, r
    163 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = read_rm_val(rm, os, pfx.has_rex);
      let bit_idx = read_gpr(reg, os);
      let bit_num : range(0, 63) = match os {
        OS16 => unsigned(bit_idx[3..0]),
        OS32 => unsigned(bit_idx[4..0]),
        OS64 => unsigned(bit_idx[5..0]),
        _    => unsigned(bit_idx[4..0]),
      };
      CF = v[bit_num];
      Ok(())
    },

    // 0F A4: SHLD r/m, r, imm8
    164 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let count = fetch_byte();
      let dst_val = read_rm_val(rm, os, pfx.has_rex);
      let src_val = read_gpr(reg, os);
      let (result, new_val) = exec_shld(dst_val, src_val, count, os);
      write_rm_val(rm, os, pfx.has_rex, new_val);
      result
    },

    // 0F A5: SHLD r/m, r, CL
    165 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let count = read_gpr8l(RCX);
      let dst_val = read_rm_val(rm, os, pfx.has_rex);
      let src_val = read_gpr(reg, os);
      let (result, new_val) = exec_shld(dst_val, src_val, count, os);
      write_rm_val(rm, os, pfx.has_rex, new_val);
      result
    },

    // 0F AB: BTS r/m, r
    171 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = read_rm_val(rm, os, pfx.has_rex);
      let bit_idx = read_gpr(reg, os);
      let bit_num : range(0, 63) = match os {
        OS16 => unsigned(bit_idx[3..0]),
        OS32 => unsigned(bit_idx[4..0]),
        OS64 => unsigned(bit_idx[5..0]),
        _    => unsigned(bit_idx[4..0]),
      };
      CF = v[bit_num];
      var result : qword = v;
      result[bit_num] = bitone;
      write_rm_val(rm, os, pfx.has_rex, result);
      Ok(())
    },

    // 0F AC: SHRD r/m, r, imm8
    172 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let count = fetch_byte();
      let dst_val = read_rm_val(rm, os, pfx.has_rex);
      let src_val = read_gpr(reg, os);
      let (result, new_val) = exec_shrd(dst_val, src_val, count, os);
      write_rm_val(rm, os, pfx.has_rex, new_val);
      result
    },

    // 0F AD: SHRD r/m, r, CL
    173 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let count = read_gpr8l(RCX);
      let dst_val = read_rm_val(rm, os, pfx.has_rex);
      let src_val = read_gpr(reg, os);
      let (result, new_val) = exec_shrd(dst_val, src_val, count, os);
      write_rm_val(rm, os, pfx.has_rex, new_val);
      result
    },

    // 0F AF: IMUL r, r/m (2-operand)
    175 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let a = read_gpr(reg, os);
      let b = read_rm_val(rm, os, pfx.has_rex);
      let product : int = match os {
        OS8  => signed(a[7..0]) * signed(b[7..0]),
        OS16 => signed(a[15..0]) * signed(b[15..0]),
        OS32 => signed(a[31..0]) * signed(b[31..0]),
        OS64 => signed(a) * signed(b),
      };
      let result : qword = to_bits_truncate(product);
      let truncated : bool = match os {
        OS8  => product != signed(result[7..0]),
        OS16 => product != signed(result[15..0]),
        OS32 => product != signed(result[31..0]),
        OS64 => product != signed(result),
      };
      CF = if truncated then bitone else bitzero;
      OF = CF;
      write_gpr(reg, os, result);
      Ok(())
    },

    // 0F B3: BTR r/m, r
    179 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = read_rm_val(rm, os, pfx.has_rex);
      let bit_idx = read_gpr(reg, os);
      let bit_num : range(0, 63) = match os {
        OS16 => unsigned(bit_idx[3..0]),
        OS32 => unsigned(bit_idx[4..0]),
        OS64 => unsigned(bit_idx[5..0]),
        _    => unsigned(bit_idx[4..0]),
      };
      CF = v[bit_num];
      var result : qword = v;
      result[bit_num] = bitzero;
      write_rm_val(rm, os, pfx.has_rex, result);
      Ok(())
    },

    // 0F B0: CMPXCHG r/m8, r8
    176 => {
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let dest = read_rm_val(rm, OS8, pfx.has_rex);
      let acc : qword = zero_extend(read_gpr8l(RAX));
      let src : qword = zero_extend(read_byte_reg(reg, pfx.has_rex));
      let cmp_result = acc - dest;
      update_flags_sub(cmp_result[7..0], acc[7..0], dest[7..0]);
      if ZF == bitone then {
        write_rm_val(rm, OS8, pfx.has_rex, src);
      } else {
        write_gpr8l(RAX, dest[7..0]);
      };
      Ok(())
    },

    // 0F B1: CMPXCHG r/m, r
    177 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let dest = read_rm_val(rm, os, pfx.has_rex);
      let acc = read_gpr(RAX, os);
      let src = read_gpr(reg, os);
      let cmp_result = acc - dest;
      match os {
        OS8  => update_flags_sub(cmp_result[7..0], acc[7..0], dest[7..0]),
        OS16 => update_flags_sub(cmp_result[15..0], acc[15..0], dest[15..0]),
        OS32 => update_flags_sub(cmp_result[31..0], acc[31..0], dest[31..0]),
        OS64 => update_flags_sub(cmp_result, acc, dest),
      };
      if ZF == bitone then {
        write_rm_val(rm, os, pfx.has_rex, src);
      } else {
        write_gpr(RAX, os, dest);
      };
      Ok(())
    },

    // 0F B6: MOVZX r, r/m8
    182 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = read_rm_val(rm, OS8, pfx.has_rex);
      write_gpr(reg, os, v);  // already zero-extended in read_rm_val
      Ok(())
    },

    // 0F B7: MOVZX r, r/m16
    183 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = read_rm_val(rm, OS16, pfx.has_rex);
      write_gpr(reg, os, v);
      Ok(())
    },

    // 0F BA: Group 8 — BT/BTS/BTR/BTC r/m, imm8
    186 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg_field : range(0, 7) = unsigned(modrm[5..3]);
      let rm = decode_rm(modrm, pfx);
      let imm = fetch_byte();
      let v = read_rm_val(rm, os, pfx.has_rex);
      let bit_num : range(0, 63) = match os {
        OS16 => unsigned(imm[3..0]),
        OS32 => unsigned(imm[4..0]),
        OS64 => unsigned(imm[5..0]),
        _    => unsigned(imm[4..0]),
      };
      CF = v[bit_num];
      if reg_field == 4 then {
        // BT — just test, no modification
        Ok(())
      } else if reg_field == 5 then {
        // BTS — set bit
        var result : qword = v;
        result[bit_num] = bitone;
        write_rm_val(rm, os, pfx.has_rex, result);
        Ok(())
      } else if reg_field == 6 then {
        // BTR — reset bit
        var result : qword = v;
        result[bit_num] = bitzero;
        write_rm_val(rm, os, pfx.has_rex, result);
        Ok(())
      } else if reg_field == 7 then {
        // BTC — complement bit
        var result : qword = v;
        result[bit_num] = if v[bit_num] == bitone then bitzero else bitone;
        write_rm_val(rm, os, pfx.has_rex, result);
        Ok(())
      } else raise_UD()
    },

    // 0F BB: BTC r/m, r
    187 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = read_rm_val(rm, os, pfx.has_rex);
      let bit_idx = read_gpr(reg, os);
      let bit_num : range(0, 63) = match os {
        OS16 => unsigned(bit_idx[3..0]),
        OS32 => unsigned(bit_idx[4..0]),
        OS64 => unsigned(bit_idx[5..0]),
        _    => unsigned(bit_idx[4..0]),
      };
      CF = v[bit_num];
      var result : qword = v;
      result[bit_num] = if v[bit_num] == bitone then bitzero else bitone;
      write_rm_val(rm, os, pfx.has_rex, result);
      Ok(())
    },

    // 0F BC: BSF r, r/m (or TZCNT with F3 prefix)
    188 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.has_rep then {
        // TZCNT
        let src = modrm_rm_reg(modrm, pfx);
        let src_val : qword = read_gpr(src, os);
        let os_bits : {8, 16, 32, 64} = operand_size_bits(os);
        let is_zero : bool = match os {
          OS8  => src_val[7..0] == zeros(),
          OS16 => src_val[15..0] == zeros(),
          OS32 => src_val[31..0] == zeros(),
          OS64 => src_val == zeros(),
        };
        let count : int = if is_zero then os_bits
                          else bsf64(src_val, 0);
        write_gpr(reg, os, to_bits_truncate(count));
        CF = if is_zero then bitone else bitzero;
        ZF = if count == 0 then bitone else bitzero;
        Ok(())
      } else {
        // BSF
        let src_val = read_rm_val(rm, os, pfx.has_rex);
        let is_zero : bool = match os {
          OS8  => src_val[7..0] == zeros(),
          OS16 => src_val[15..0] == zeros(),
          OS32 => src_val[31..0] == zeros(),
          OS64 => src_val == zeros(),
        };
        if is_zero then {
          ZF = bitone;
        } else {
          ZF = bitzero;
          let idx : range(0, 63) = bsf64(src_val, 0);
          write_gpr(reg, os, to_bits_truncate(idx));
        };
        Ok(())
      }
    },

    // 0F BD: BSR r, r/m (or LZCNT with F3 prefix)
    189 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.has_rep then {
        // LZCNT
        let src = modrm_rm_reg(modrm, pfx);
        let src_val : qword = read_gpr(src, os);
        let os_bits : {8, 16, 32, 64} = operand_size_bits(os);
        let count : range(0, 64) = match os {
          OS8  => lzcnt64(zero_extend(src_val[7..0]), 7),
          OS16 => lzcnt64(zero_extend(src_val[15..0]), 15),
          OS32 => lzcnt64(zero_extend(src_val[31..0]), 31),
          OS64 => lzcnt64(src_val, 63),
        };
        write_gpr(reg, os, to_bits_truncate(count));
        CF = if count == os_bits then bitone else bitzero;
        ZF = if count == 0 then bitone else bitzero;
        Ok(())
      } else {
        // BSR
        let src_val = read_rm_val(rm, os, pfx.has_rex);
        let is_zero : bool = match os {
          OS8  => src_val[7..0] == zeros(),
          OS16 => src_val[15..0] == zeros(),
          OS32 => src_val[31..0] == zeros(),
          OS64 => src_val == zeros(),
        };
        if is_zero then {
          ZF = bitone;
        } else {
          ZF = bitzero;
          let top : range(0, 63) = match os {
            OS8  => 7,
            OS16 => 15,
            OS32 => 31,
            OS64 => 63,
          };
          let idx : range(0, 63) = bsr64(src_val, top);
          write_gpr(reg, os, to_bits_truncate(idx));
        };
        Ok(())
      }
    },

    // 0F BE: MOVSX r, r/m8
    190 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = read_rm_val(rm, OS8, pfx.has_rex);
      let sx : qword = sign_extend(v[7..0]);
      write_gpr(reg, os, sx);
      Ok(())
    },

    // 0F BF: MOVSX r, r/m16
    191 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = read_rm_val(rm, OS16, pfx.has_rex);
      let sx : qword = sign_extend(v[15..0]);
      write_gpr(reg, os, sx);
      Ok(())
    },

    // 0F C0: XADD r/m8, r8
    192 => {
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      match rm {
        RM_reg(dst) => exec_xadd(dst, reg, OS8),
        RM_mem(addr) => {
          // Memory operand: read, exchange, add, write back
          let mem_val : qword = zero_extend(mem_read8(addr));
          let reg_val : qword = zero_extend(read_byte_reg(reg, pfx.has_rex));
          let sum : qword = mem_val + reg_val;
          update_flags_add(sum[7..0], mem_val[7..0], reg_val[7..0]);
          write_byte_reg(reg, pfx.has_rex, mem_val[7..0]);
          mem_write8(addr, sum[7..0]);
          Ok(())
        },
      }
    },

    // 0F C1: XADD r/m, r
    193 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      match rm {
        RM_reg(dst) => exec_xadd(dst, reg, os),
        RM_mem(_) => {
          let mem_val = read_rm_val(rm, os, pfx.has_rex);
          let reg_val = read_gpr(reg, os);
          let sum = mem_val + reg_val;
          match os {
            OS8  => update_flags_add(sum[7..0], mem_val[7..0], reg_val[7..0]),
            OS16 => update_flags_add(sum[15..0], mem_val[15..0], reg_val[15..0]),
            OS32 => update_flags_add(sum[31..0], mem_val[31..0], reg_val[31..0]),
            OS64 => update_flags_add(sum, mem_val, reg_val),
          };
          write_gpr(reg, os, mem_val);
          write_rm_val(rm, os, pfx.has_rex, sum);
          Ok(())
        },
      }
    },

    // 0F B8: POPCNT r, r/m (F3 prefix)
    184 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_F3 then raise_UD()
      else {
        let os = get_operand_size(pfx);
        let modrm = fetch_byte();
        let reg = modrm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_val = read_rm_val(rm, os, pfx.has_rex);
        let count : range(0, 64) = match os {
          OS8  => popcount8(src_val[7..0]),
          OS16 => popcount16(src_val[15..0]),
          OS32 => popcount32(src_val[31..0]),
          OS64 => popcount64(src_val),
        };
        OF = bitzero; SF = bitzero; AF = bitzero; CF = bitzero; PF = bitzero;
        ZF = if count == 0 then bitone else bitzero;
        write_gpr(reg, os, to_bits_truncate(count));
        Ok(())
      }
    },

    // 0F C3: MOVNTI m32/64, r
    195 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      match rm {
        RM_mem(addr) => {
          let v = read_gpr(reg, os);
          match os {
            OS32 => mem_write32(addr, v[31..0]),
            OS64 => mem_write64(addr, v),
            _    => mem_write32(addr, v[31..0]),
          };
          Ok(())
        },
        RM_reg(_) => raise_UD(),
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
        MP_NONE => exec_shufps(xreg, src_xmm, imm),
        MP_66   => exec_shufpd(xreg, src_xmm, imm),
        _       => raise_UD(),
      }
    },

    // 0F C7 /1: CMPXCHG8B/CMPXCHG16B m64/m128
    199 => {
      let modrm = fetch_byte();
      let reg_field : range(0, 7) = unsigned(modrm[5..3]);
      let rm = decode_rm(modrm, pfx);
      if reg_field == 1 then {
        match rm {
          RM_mem(addr) => {
            if pfx.rex_w then {
              let mem_lo : qword = mem_read64(addr);
              let mem_hi : qword = mem_read64(addr + 0x0000000000000008);
              if read_gpr64(RAX) == mem_lo & read_gpr64(RDX) == mem_hi then {
                ZF = bitone;
                mem_write64(addr, read_gpr64(RBX));
                mem_write64(addr + 0x0000000000000008, read_gpr64(RCX));
              } else {
                ZF = bitzero;
                write_gpr64(RAX, mem_lo);
                write_gpr64(RDX, mem_hi);
              };
              Ok(())
            } else {
              let mem_lo : dword = mem_read32(addr);
              let mem_hi : dword = mem_read32(addr + 0x0000000000000004);
              if read_gpr32(RAX) == mem_lo & read_gpr32(RDX) == mem_hi then {
                ZF = bitone;
                mem_write32(addr, read_gpr32(RBX));
                mem_write32(addr + 0x0000000000000004, read_gpr32(RCX));
              } else {
                ZF = bitzero;
                write_gpr32(RAX, mem_lo);
                write_gpr32(RDX, mem_hi);
              };
              Ok(())
            }
          },
          RM_reg(_) => raise_UD(),
        }
      } else raise_UD()
    },

    // 0F C8-CF: BSWAP r32/r64 (register in opcode)
    op if 200 <= op & op <= 207 => {
      let reg_field : range(0, 7) = op - 200;
      let reg = extend_reg(reg_field, pfx.rex_b);
      let os = get_operand_size(pfx);
      match os {
        OS32 => {
          let v : dword = read_gpr32(reg);
          write_gpr32(reg, v[7..0] @ v[15..8] @ v[23..16] @ v[31..24])
        },
        OS64 => {
          let v : qword = read_gpr64(reg);
          write_gpr64(reg, v[7..0] @ v[15..8] @ v[23..16] @ v[31..24] @
                           v[39..32] @ v[47..40] @ v[55..48] @ v[63..56])
        },
        _ => (),
      };
      Ok(())
    },

    // 0F D6: MOVQ xmm/m64, xmm (66 prefix)
    214 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then raise_UD()
      else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let v = read_xmm(xreg);
        match rm {
          RM_reg(_) => {
            let dst_xmm = modrm_xmm_rm(modrm, pfx);
            write_xmm(dst_xmm, zero_extend(v[63..0]));
            Ok(())
          },
          RM_mem(addr) => {
            mem_write64(addr, v[63..0]);
            Ok(())
          },
        }
      }
    },

    // 0F D7: PMOVMSKB r, xmm (66 prefix)
    215 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then raise_UD()
      else {
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
      if mp != MP_66 then raise_UD()
      else {
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
      if mp != MP_66 then raise_UD()
      else {
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
      if mp != MP_66 then raise_UD()
      else {
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
          write_xmm_legacy(xreg, r); Ok(())
        },
        MP_F2 => {
          let r : xmmword = zeros(64) @ __f64_to_int32(src_xmm[127..64]) @ __f64_to_int32(src_xmm[63..0]);
          write_xmm_legacy(xreg, r); Ok(())
        },
        MP_66 => {
          let lo : dword = __f64_to_int32_trunc(src_xmm[63..0]);
          let hi : dword = __f64_to_int32_trunc(src_xmm[127..64]);
          let r : xmmword = zeros(64) @ hi @ lo;
          write_xmm_legacy(xreg, r); Ok(())
        },
        _       => raise_UD(),
      }
    },

    // 0F EB: POR xmm, xmm/m128 (66 prefix)
    235 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then raise_UD()
      else {
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
      if mp != MP_66 then raise_UD()
      else {
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
      if mp != MP_66 then raise_UD()
      else {
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
      if mp != MP_66 then raise_UD()
      else {
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
      if mp != MP_66 then raise_UD()
      else {
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
      if mp != MP_66 then raise_UD()
      else {
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
      if mp != MP_66 then raise_UD()
      else {
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
      if mp != MP_66 then raise_UD()
      else {
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
      if mp != MP_66 then raise_UD()
      else {
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
      if mp != MP_66 then raise_UD()
      else {
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
      if mp != MP_66 then raise_UD()
      else {
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
      if mp != MP_66 then raise_UD()
      else {
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
      if mp != MP_66 then raise_UD()
      else {
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
      if mp != MP_66 then raise_UD()
      else {
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
      if mp != MP_66 then raise_UD()
      else {
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
            Ok(())
          } else raise_UD()
        },
        RM_reg(_) => raise_UD(),
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
            MP_NONE => { mem_write128(addr, read_xmm(xreg)); Ok(()) },
            MP_66   => { mem_write128(addr, read_xmm(xreg)); Ok(()) },
            _       => raise_UD(),
          }
        },
        RM_reg(_) => raise_UD(),
      }
    },

    // 0F 38: 3-byte escape (SSSE3/SSE4/AES-NI)
    56 => {
      let opcode3 = fetch_byte();
      dispatch_opcode_3byte_38(opcode3, pfx)
    },

    // 0F 3A: 3-byte escape (SSE4/AES-NI with imm8)
    58 => {
      let opcode3 = fetch_byte();
      dispatch_opcode_3byte_3a(opcode3, pfx)
    },

    // 0F 77: EMMS
    119 => Ok(()),

    // 0F 7C: HADDPS/HADDPD
    124 => {
      let mp = get_mandatory_prefix(pfx);
      let modrm = fetch_byte();
      let xreg = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src_xmm : xmmword = decode_xmm_src(modrm, rm, pfx);
      match mp {
        MP_F2   => exec_haddps(xreg, src_xmm),
        MP_66   => exec_haddpd(xreg, src_xmm),
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
        MP_F2   => exec_hsubps(xreg, src_xmm),
        MP_66   => exec_hsubpd(xreg, src_xmm),
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
        MP_NONE => exec_cmpps(xreg, src_xmm, imm),
        MP_66   => exec_cmppd(xreg, src_xmm, imm),
        MP_F3   => exec_cmpss2(xreg, src_xmm, imm),
        MP_F2   => exec_cmpsd2(xreg, src_xmm, imm),
      }
    },

    // 0F C4: PINSRW xmm, r32/m16, imm8 (66 prefix)
    196 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then raise_UD()
      else {
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
      if mp != MP_66 then raise_UD()
      else {
        let modrm = fetch_byte();
        let reg = modrm_reg(modrm, pfx);
        let _ = decode_rm(modrm, pfx);
        let src_xmm : xmmword = read_xmm(modrm_xmm_rm(modrm, pfx));
        let imm = fetch_byte();
        exec_pextrw(reg, src_xmm, imm)
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
        MP_F2   => exec_addsubps(xreg, src_xmm),
        MP_66   => exec_addsubpd(xreg, src_xmm),
        _       => raise_UD(),
      }
    },

    // 0F D1: PSRLW xmm, xmm/m128 (66 prefix)
    209 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then raise_UD()
      else {
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
      if mp != MP_66 then raise_UD()
      else {
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
      if mp != MP_66 then raise_UD()
      else {
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
      if mp != MP_66 then raise_UD()
      else {
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
      if mp != MP_66 then raise_UD()
      else {
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
      if mp != MP_66 then raise_UD()
      else {
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
      if mp != MP_66 then raise_UD()
      else {
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
      if mp != MP_66 then raise_UD()
      else {
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
      if mp != MP_66 then raise_UD()
      else {
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
      if mp != MP_66 then raise_UD()
      else {
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
      if mp != MP_66 then raise_UD()
      else {
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
      if mp != MP_66 then raise_UD()
      else {
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
      if mp != MP_66 then raise_UD()
      else {
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
      if mp != MP_66 then raise_UD()
      else {
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
      if mp != MP_66 then raise_UD()
      else {
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
      if mp != MP_66 then raise_UD()
      else {
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
      if mp != MP_F2 then raise_UD()
      else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        match rm {
          RM_mem(addr) => {
            write_xmm(xreg, mem_read128(addr));
            Ok(())
          },
          RM_reg(_) => raise_UD(),
        }
      }
    },

    // 0F F1: PSLLW xmm, xmm/m128 (66 prefix)
    241 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then raise_UD()
      else {
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
      if mp != MP_66 then raise_UD()
      else {
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
      if mp != MP_66 then raise_UD()
      else {
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
      if mp != MP_66 then raise_UD()
      else {
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
      if mp != MP_66 then raise_UD()
      else {
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
      if mp != MP_66 then raise_UD()
      else {
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
      if mp != MP_66 then raise_UD()
      else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, rm, pfx);
        exec_pminsw(xreg, src_xmm)
      }
    },

    // 0F E3: PAVGW (66 prefix) — handled above

    // 0F F9: NOP (F3 prefix = PAUSE) already handled

    // Unhandled 2-byte opcode -> #UD
    _ => raise_UD(),
  }
}

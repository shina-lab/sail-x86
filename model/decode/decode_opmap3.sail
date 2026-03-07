// x86-64 Decoder — 3-Byte Opcode Maps (0F 38 xx and 0F 3A xx)
//
// SSSE3, SSE4.1, SSE4.2, AES-NI, and related extensions.

// Helper: decode XMM src operand value (read from register or memory).
val decode_xmm_src : (byte, RM, Prefixes) -> xmmword
function decode_xmm_src(modrm, rm, pfx) = match rm {
  RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
  RM_mem(addr) => mem_read128(addr),
}

// =========================================================================
// 0F 38 xx — SSSE3 / SSE4.1 / SSE4.2 / AES-NI
// =========================================================================

val dispatch_opcode_3byte_38 : (byte, Prefixes) -> ExecutionResult
function dispatch_opcode_3byte_38(opcode, pfx) = {
  let op : range(0, 255) = unsigned(opcode);
  let mp = get_mandatory_prefix(pfx);

  // 0F 38 F6: ADCX (66) / ADOX (F3) — GPR operations, handle before XMM dispatch
  if op == 246 then {
    let os = get_operand_size(pfx);
    let modrm = fetch_byte();
    let reg = modrm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let src_val = read_rm_val(rm, os, pfx.has_rex);
    if mp == MP_66 then {
      let a : qword = read_gpr(reg, os);
      let c : int = if CF == bitone then 1 else 0;
      let result : qword = a + src_val + zero_extend(CF);
      match os {
        OS32 => CF = bool_to_bit(unsigned(result[31..0]) != unsigned(a[31..0]) + unsigned(src_val[31..0]) + c),
        OS64 => CF = bool_to_bit(unsigned(result) != unsigned(a) + unsigned(src_val) + c),
        _ => (),
      };
      write_gpr(reg, os, result);
      Ok()
    } else if mp == MP_F3 then {
      let a : qword = read_gpr(reg, os);
      let c : int = if OF == bitone then 1 else 0;
      let result : qword = a + src_val + zero_extend(OF);
      match os {
        OS32 => OF = bool_to_bit(unsigned(result[31..0]) != unsigned(a[31..0]) + unsigned(src_val[31..0]) + c),
        OS64 => OF = bool_to_bit(unsigned(result) != unsigned(a) + unsigned(src_val) + c),
        _ => (),
      };
      write_gpr(reg, os, result);
      Ok()
    }
    else raise_UD()
  } else if mp != MP_66 then raise_UD()
  else {
    // 66-prefixed 0F 38 opcodes (XMM operations)
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

      // SSE4.1 — blend with implicit XMM0 mask
      16 => exec_pblendvb(xreg, src_xmm, read_xmm(0)),
      20 => exec_blendvps(xreg, src_xmm, read_xmm(0)),
      21 => exec_blendvpd(xreg, src_xmm, read_xmm(0)),

      // SSE4.1
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

      // SSE4.2
      55 => exec_pcmpgtq(xreg, src_xmm),

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

// =========================================================================
// 0F 3A xx — SSE4.1 / SSE4.2 / AES-NI (all with imm8)
// =========================================================================

val dispatch_opcode_3byte_3a : (byte, Prefixes) -> ExecutionResult
function dispatch_opcode_3byte_3a(opcode, pfx) = {
  let op : range(0, 255) = unsigned(opcode);
  let mp = get_mandatory_prefix(pfx);
  if mp != MP_66 then raise_UD()
  else {
    let modrm = fetch_byte();
    let xreg = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    match op {
      // SSE4.1 — round
      8 => {
        let src_xmm = decode_xmm_src(modrm, rm, pfx);
        let imm = fetch_byte();
        exec_roundps(xreg, src_xmm, imm)
      },
      9 => {
        let src_xmm = decode_xmm_src(modrm, rm, pfx);
        let imm = fetch_byte();
        exec_roundpd(xreg, src_xmm, imm)
      },
      10 => {
        let src_xmm = decode_xmm_src(modrm, rm, pfx);
        let imm = fetch_byte();
        exec_roundss(xreg, src_xmm, imm)
      },
      11 => {
        let src_xmm = decode_xmm_src(modrm, rm, pfx);
        let imm = fetch_byte();
        exec_roundsd(xreg, src_xmm, imm)
      },

      // SSE4.1 — blend
      12 => {
        let src_xmm = decode_xmm_src(modrm, rm, pfx);
        let imm = fetch_byte();
        exec_blendps(xreg, src_xmm, imm)
      },
      13 => {
        let src_xmm = decode_xmm_src(modrm, rm, pfx);
        let imm = fetch_byte();
        exec_blendpd(xreg, src_xmm, imm)
      },
      14 => {
        let src_xmm = decode_xmm_src(modrm, rm, pfx);
        let imm = fetch_byte();
        exec_pblendw(xreg, src_xmm, imm)
      },

      // SSSE3 — palignr
      15 => {
        let src_xmm = decode_xmm_src(modrm, rm, pfx);
        let imm = fetch_byte();
        exec_palignr(xreg, src_xmm, imm)
      },

      // SSE4.1 — extract/insert byte/dword
      20 => {
        // PEXTRB r/m8, xmm, imm8
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
      22 => {
        // PEXTRD/PEXTRQ r/m, xmm, imm8
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
      23 => {
        // EXTRACTPS r/m32, xmm, imm8
        let imm = fetch_byte();
        let v = extract_dword_from_xmm(read_xmm(xreg), imm);
        match rm {
          RM_reg(_) => {
            let dst_reg = modrm_rm_reg(modrm, pfx);
            write_gpr32(dst_reg, v);
          },
          RM_mem(addr) => mem_write32(fixup_addr(addr), v),
        };
        Ok()
      },

      32 => {
        // PINSRB xmm, r/m8, imm8
        let imm = fetch_byte();
        let v : byte = match rm {
          RM_reg(idx) => read_gpr8l(idx),
          RM_mem(addr) => mem_read8(addr),
        };
        exec_pinsrb(xreg, v, imm)
      },
      33 => {
        // INSERTPS xmm, xmm/m32, imm8
        let src_xmm = decode_xmm_src(modrm, rm, pfx);
        let imm = fetch_byte();
        exec_insertps(xreg, src_xmm, imm)
      },
      34 => {
        // PINSRD/PINSRQ xmm, r/m, imm8
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

      // SSE4.1 — dot product
      64 => {
        let src_xmm = decode_xmm_src(modrm, rm, pfx);
        let imm = fetch_byte();
        exec_dpps(xreg, src_xmm, imm)
      },
      65 => {
        let src_xmm = decode_xmm_src(modrm, rm, pfx);
        let imm = fetch_byte();
        exec_dppd(xreg, src_xmm, imm)
      },

      // SSE4.1 — mpsadbw
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

      // AES-NI
      223 => {
        let src_xmm = decode_xmm_src(modrm, rm, pfx);
        let imm = fetch_byte();
        exec_aeskeygenassist(xreg, src_xmm, imm)
      },

      _ => raise_UD(),
    }
  }
}

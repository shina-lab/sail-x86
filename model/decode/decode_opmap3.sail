// x86-64 Decoder — 3-Byte Opcode Maps (0F 38 xx and 0F 3A xx)
//
// SSSE3, SSE4.1, SSE4.2, AES-NI, and related extensions.

val __f64_round : (qword, byte) -> qword
val __f32_round : (dword, byte) -> dword

val blend_byte : (byte, byte, bit) -> byte
function blend_byte(a, b, sel) = if sel == bitone then b else a

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
      16 => {
        // PBLENDVB
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
      20 => {
        // BLENDVPS
        let a : xmmword = read_xmm(xreg);
        let m : xmmword = read_xmm(0);
        let d0 : dword = if m[31] == bitone then src_xmm[31..0] else a[31..0];
        let d1 : dword = if m[63] == bitone then src_xmm[63..32] else a[63..32];
        let d2 : dword = if m[95] == bitone then src_xmm[95..64] else a[95..64];
        let d3 : dword = if m[127] == bitone then src_xmm[127..96] else a[127..96];
        write_xmm_legacy(xreg, d3 @ d2 @ d1 @ d0);
        Ok()
      },
      21 => {
        // BLENDVPD
        let a : xmmword = read_xmm(xreg);
        let m : xmmword = read_xmm(0);
        let lo : qword = if m[63] == bitone then src_xmm[63..0] else a[63..0];
        let hi : qword = if m[127] == bitone then src_xmm[127..64] else a[127..64];
        write_xmm_legacy(xreg, hi @ lo);
        Ok()
      },

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
          let d0 : dword = __f32_round(src_xmm[31..0], imm);
          let d1 : dword = __f32_round(src_xmm[63..32], imm);
          let d2 : dword = __f32_round(src_xmm[95..64], imm);
          let d3 : dword = __f32_round(src_xmm[127..96], imm);
          write_xmm_legacy(xreg, d3 @ d2 @ d1 @ d0);
          Ok()
      },
      9 => {
        let src_xmm = decode_xmm_src(modrm, rm, pfx);
        let imm = fetch_byte();
          let lo : qword = __f64_round(src_xmm[63..0], imm);
          let hi : qword = __f64_round(src_xmm[127..64], imm);
          write_xmm_legacy(xreg, hi @ lo);
          Ok()
      },
      10 => {
        let src_xmm = decode_xmm_src(modrm, rm, pfx);
        let imm = fetch_byte();
          let a : xmmword = read_xmm(xreg);
          let lo : dword = __f32_round(src_xmm[31..0], imm);
          write_xmm_legacy(xreg, a[127..32] @ lo);
          Ok()
      },
      11 => {
        let src_xmm = decode_xmm_src(modrm, rm, pfx);
        let imm = fetch_byte();
          let a : xmmword = read_xmm(xreg);
          let lo : qword = __f64_round(src_xmm[63..0], imm);
          write_xmm_legacy(xreg, a[127..64] @ lo);
          Ok()
      },

      // SSE4.1 — blend
      12 => {
        let src_xmm = decode_xmm_src(modrm, rm, pfx);
        let imm = fetch_byte();
          let a : xmmword = read_xmm(xreg);
          let d0 : dword = if imm[0] == bitone then src_xmm[31..0] else a[31..0];
          let d1 : dword = if imm[1] == bitone then src_xmm[63..32] else a[63..32];
          let d2 : dword = if imm[2] == bitone then src_xmm[95..64] else a[95..64];
          let d3 : dword = if imm[3] == bitone then src_xmm[127..96] else a[127..96];
          write_xmm_legacy(xreg, d3 @ d2 @ d1 @ d0);
          Ok()
      },
      13 => {
        let src_xmm = decode_xmm_src(modrm, rm, pfx);
        let imm = fetch_byte();
          let a : xmmword = read_xmm(xreg);
          let lo : qword = if imm[0] == bitone then src_xmm[63..0] else a[63..0];
          let hi : qword = if imm[1] == bitone then src_xmm[127..64] else a[127..64];
          write_xmm_legacy(xreg, hi @ lo);
          Ok()
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
          let a : xmmword = read_xmm(xreg);
          let zero : dword = 0x00000000;
          let temp0 : dword = if imm[4] == bitone then __f32_mul(a[31..0], src_xmm[31..0]) else zero;
          let temp1 : dword = if imm[5] == bitone then __f32_mul(a[63..32], src_xmm[63..32]) else zero;
          let temp2 : dword = if imm[6] == bitone then __f32_mul(a[95..64], src_xmm[95..64]) else zero;
          let temp3 : dword = if imm[7] == bitone then __f32_mul(a[127..96], src_xmm[127..96]) else zero;
          let sum01 : dword = __f32_add(temp0, temp1);
          let sum23 : dword = __f32_add(temp2, temp3);
          let sum : dword = __f32_add(sum01, sum23);
          let d0 : dword = if imm[0] == bitone then sum else zero;
          let d1 : dword = if imm[1] == bitone then sum else zero;
          let d2 : dword = if imm[2] == bitone then sum else zero;
          let d3 : dword = if imm[3] == bitone then sum else zero;
          write_xmm_legacy(xreg, d3 @ d2 @ d1 @ d0);
          Ok()
      },
      65 => {
        let src_xmm = decode_xmm_src(modrm, rm, pfx);
        let imm = fetch_byte();
          let a : xmmword = read_xmm(xreg);
          let zero : qword = 0x0000000000000000;
          let temp0 : qword = if imm[4] == bitone then __f64_mul(a[63..0], src_xmm[63..0]) else zero;
          let temp1 : qword = if imm[5] == bitone then __f64_mul(a[127..64], src_xmm[127..64]) else zero;
          let sum : qword = __f64_add(temp0, temp1);
          let lo : qword = if imm[0] == bitone then sum else zero;
          let hi : qword = if imm[1] == bitone then sum else zero;
          write_xmm_legacy(xreg, hi @ lo);
          Ok()
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

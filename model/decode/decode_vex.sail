// x86-64 Decoder — VEX Prefix Decoding and Dispatch
//
// Handles 2-byte VEX (C5h) and 3-byte VEX (C4h) prefixes.
// In 64-bit mode, C4/C5 are always VEX prefixes (LES/LDS are invalid).
//
// VEX replaces REX + mandatory prefix + opcode escape bytes.
// 2-byte VEX (C5): [C5] [R̄.vvvv.L.pp]       — implies map 0F
// 3-byte VEX (C4): [C4] [R̄.X̄.B̄.mmmmm] [W.vvvv.L.pp]

// Decode a 2-byte VEX prefix (C5 already consumed, byte1 is the payload).
// Returns (Prefixes, opcode_map) where opcode_map is always 1 (0F).
val decode_vex2 : byte -> (Prefixes, range(0, 31))
function decode_vex2(byte1) = {
  let pfx = {default_prefixes() with
    vex_present = true,
    // R̄ is bit 7 (inverted)
    rex_r = not_bool(byte1[7] == bitone),
    // vvvv is bits 6:3 (inverted)
    vex_vvvv = 15 - unsigned(byte1[6..3]),
    // L is bit 2
    vex_l = byte1[2] == bitone,
    // pp is bits 1:0 — map to mandatory prefix flags
    has_opsize = byte1[1..0] == 0b01,
    has_rep    = byte1[1..0] == 0b10,
    has_repne  = byte1[1..0] == 0b11,
    has_rex = true, // VEX implies REX-like behavior
  };
  (pfx, 1) // map = 0F
}

// Decode a 3-byte VEX prefix (C4 already consumed, byte1 and byte2 follow).
val decode_vex3 : (byte, byte) -> (Prefixes, range(0, 31))
function decode_vex3(byte1, byte2) = {
  let mmmmm : range(0, 31) = unsigned(byte1[4..0]);
  let pfx = {default_prefixes() with
    vex_present = true,
    // R̄, X̄, B̄ are bits 7, 6, 5 of byte1 (inverted)
    rex_r = not_bool(byte1[7] == bitone),
    rex_x = not_bool(byte1[6] == bitone),
    rex_b = not_bool(byte1[5] == bitone),
    // W is bit 7 of byte2
    vex_w = byte2[7] == bitone,
    rex_w = byte2[7] == bitone,
    // vvvv is bits 6:3 of byte2 (inverted)
    vex_vvvv = 15 - unsigned(byte2[6..3]),
    // L is bit 2 of byte2
    vex_l = byte2[2] == bitone,
    // pp is bits 1:0 of byte2
    has_opsize = byte2[1..0] == 0b01,
    has_rep    = byte2[1..0] == 0b10,
    has_repne  = byte2[1..0] == 0b11,
    has_rex = true,
  };
  (pfx, mmmmm)
}

// Helper: decode VEX XMM/YMM source from ModR/M r/m field.
// Returns (xmm_value, ymm_value, is_memory, effective_addr).
// For register operands, reads the register. For memory, loads from memory.
val decode_vex_src_xmm : (byte, RM, Prefixes) -> xmmword
function decode_vex_src_xmm(modrm, rm, pfx) = match rm {
  RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
  RM_mem(addr) => mem_read128(fixup_addr(addr)),
}

val decode_vex_src_ymm : (byte, RM, Prefixes) -> ymmword
function decode_vex_src_ymm(modrm, rm, pfx) = match rm {
  RM_reg(_) => read_ymm(modrm_xmm_rm(modrm, pfx)),
  RM_mem(addr) => mem_read256(fixup_addr(addr)),
}

// =========================================================================
// VEX 0F map dispatch (AVX versions of SSE instructions)
// =========================================================================

val dispatch_vex_0f : (byte, Prefixes) -> ExecutionResult
function dispatch_vex_0f(opcode, pfx) = {
  let op : range(0, 255) = unsigned(opcode);
  let mp = get_mandatory_prefix(pfx);

  match op {

  // 0F 10: VMOVUPS/VMOVUPD/VMOVSS/VMOVSD (load)
  16 => {
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    match mp {
      MP_NONE => // VMOVUPS
        if pfx.vex_l then {
          let src = decode_vex_src_ymm(modrm, rm, pfx);
          write_ymm(dst, src);
          Ok()
        } else {
          let src = decode_vex_src_xmm(modrm, rm, pfx);
          write_xmm(dst, src);
          Ok()
        },
      MP_66 => // VMOVUPD
        if pfx.vex_l then {
          let src = decode_vex_src_ymm(modrm, rm, pfx);
          write_ymm(dst, src);
          Ok()
        } else {
          let src = decode_vex_src_xmm(modrm, rm, pfx);
          write_xmm(dst, src);
          Ok()
        },
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
      MP_NONE => // VMOVUPS
        match rm {
          RM_reg(_) => {
            let dst = modrm_xmm_rm(modrm, pfx);
            if pfx.vex_l then {
              write_ymm(dst, read_ymm(src));
              Ok()
            }
            else {
              write_xmm(dst, read_xmm(src));
              Ok()
            }
          },
          RM_mem(addr) => {
            let a = fixup_addr(addr);
            if pfx.vex_l then {
              mem_write256(a, read_ymm(src));
              Ok()
            }
            else {
              mem_write128(a, read_xmm(src));
              Ok()
            }
          },
        },
      MP_66 => // VMOVUPD
        match rm {
          RM_reg(_) => {
            let dst = modrm_xmm_rm(modrm, pfx);
            if pfx.vex_l then {
              write_ymm(dst, read_ymm(src));
              Ok()
            }
            else {
              write_xmm(dst, read_xmm(src));
              Ok()
            }
          },
          RM_mem(addr) => {
            let a = fixup_addr(addr);
            if pfx.vex_l then {
              mem_write256(a, read_ymm(src));
              Ok()
            }
            else {
              mem_write128(a, read_xmm(src));
              Ok()
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
          RM_mem(addr) => {
            mem_write32(fixup_addr(addr), read_xmm(src)[31..0]);
            Ok()
          },
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
          RM_mem(addr) => {
            mem_write64(fixup_addr(addr), read_xmm(src)[63..0]);
            Ok()
          },
        }
      },
    }
  },

  // 0F 28: VMOVAPS/VMOVAPD (load)
  40 => {
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let src = decode_vex_src_ymm(modrm, rm, pfx);
      write_ymm(dst, src);
      Ok()
    } else {
      let src = decode_vex_src_xmm(modrm, rm, pfx);
      write_xmm(dst, src);
      Ok()
    }
  },

  // 0F 29: VMOVAPS/VMOVAPD (store)
  41 => {
    let modrm = fetch_byte();
    let src = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    match rm {
      RM_reg(_) => {
        let dst = modrm_xmm_rm(modrm, pfx);
        if pfx.vex_l then {
          write_ymm(dst, read_ymm(src));
          Ok()
        }
        else {
          write_xmm(dst, read_xmm(src));
          Ok()
        }
      },
      RM_mem(addr) => {
        let a = fixup_addr(addr);
        if pfx.vex_l then {
          mem_write256(a, read_ymm(src));
          Ok()
        }
        else {
          mem_write128(a, read_xmm(src));
          Ok()
        }
      },
    }
  },

  // 0F 50-5F: Packed arithmetic
  // Common pattern: dst = vvvv OP src (3-operand)
  op if 80 <= op & op <= 95 => {
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let col : range(0, 15) = op - 80;

    if pfx.vex_l then {
      // 256-bit YMM path
      let src1 : ymmword = read_ymm(pfx.vex_vvvv);
      let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      match col {
        1 => match mp { // VSQRTPS/VSQRTPD (unary)
          MP_NONE => {
            write_ymm(dst, vsqrtps_ymm(src2));
            Ok()
          },
          MP_66   => {
            write_ymm(dst, vsqrtpd_ymm(src2));
            Ok()
          },
          _ => raise_UD(),
        },
        4 => match mp { // VANDPS/VANDPD
          _ => {
            write_ymm(dst, src1 & src2);
            Ok()
          },
        },
        5 => match mp { // VANDNPS/VANDNPD
          _ => {
            write_ymm(dst, ~(src1) & src2);
            Ok()
          },
        },
        6 => match mp { // VORPS/VORPD
          _ => {
            write_ymm(dst, src1 | src2);
            Ok()
          },
        },
        7 => match mp { // VXORPS/VXORPD
          _ => {
            write_ymm(dst, xor_vec(src1, src2));
            Ok()
          },
        },
        8 => match mp { // VADDPS/VADDPD
          MP_NONE => {
            write_ymm(dst, vaddps_ymm(src1, src2));
            Ok()
          },
          MP_66   => {
            write_ymm(dst, vaddpd_ymm(src1, src2));
            Ok()
          },
          _ => raise_UD(),
        },
        9 => match mp { // VMULPS/VMULPD
          MP_NONE => {
            write_ymm(dst, vmulps_ymm(src1, src2));
            Ok()
          },
          MP_66   => {
            write_ymm(dst, vmulpd_ymm(src1, src2));
            Ok()
          },
          _ => raise_UD(),
        },
        12 => match mp { // VSUBPS/VSUBPD
          MP_NONE => {
            write_ymm(dst, vsubps_ymm(src1, src2));
            Ok()
          },
          MP_66   => {
            write_ymm(dst, vsubpd_ymm(src1, src2));
            Ok()
          },
          _ => raise_UD(),
        },
        13 => match mp { // VMINPS/VMINPD
          MP_NONE => {
            write_ymm(dst, vminps_ymm(src1, src2));
            Ok()
          },
          MP_66   => {
            write_ymm(dst, vminpd_ymm(src1, src2));
            Ok()
          },
          _ => raise_UD(),
        },
        14 => match mp { // VDIVPS/VDIVPD
          MP_NONE => {
            write_ymm(dst, vdivps_ymm(src1, src2));
            Ok()
          },
          MP_66   => {
            write_ymm(dst, vdivpd_ymm(src1, src2));
            Ok()
          },
          _ => raise_UD(),
        },
        15 => match mp { // VMAXPS/VMAXPD
          MP_NONE => {
            write_ymm(dst, vmaxps_ymm(src1, src2));
            Ok()
          },
          MP_66   => {
            write_ymm(dst, vmaxpd_ymm(src1, src2));
            Ok()
          },
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
          MP_NONE => {
            write_xmm(dst, vsqrtps_xmm(src2));
            Ok()
          },
          MP_66   => {
            write_xmm(dst, vsqrtpd_xmm(src2));
            Ok()
          },
          MP_F3   => {
            write_xmm(dst, src1[127..32] @ __f32_sqrt(src2[31..0]));
            Ok()
          },
          MP_F2   => {
            write_xmm(dst, src1[127..64] @ __f64_sqrt(src2[63..0]));
            Ok()
          },
        },
        4 => match mp { // VANDPS/VANDPD
          _ => {
            write_xmm(dst, src1 & src2);
            Ok()
          },
        },
        5 => match mp { // VANDNPS/VANDNPD
          _ => {
            write_xmm(dst, ~(src1) & src2);
            Ok()
          },
        },
        6 => match mp { // VORPS/VORPD
          _ => {
            write_xmm(dst, src1 | src2);
            Ok()
          },
        },
        7 => match mp { // VXORPS/VXORPD
          _ => {
            write_xmm(dst, xor_vec(src1, src2));
            Ok()
          },
        },
        8 => match mp { // VADDPS/VADDPD/VADDSS/VADDSD
          MP_NONE => {
            write_xmm(dst, vaddps_xmm(src1, src2));
            Ok()
          },
          MP_66   => {
            write_xmm(dst, vaddpd_xmm(src1, src2));
            Ok()
          },
          MP_F3   => {
            write_xmm(dst, src1[127..32] @ __f32_add(src1[31..0], src2[31..0]));
            Ok()
          },
          MP_F2   => {
            write_xmm(dst, src1[127..64] @ __f64_add(src1[63..0], src2[63..0]));
            Ok()
          },
        },
        9 => match mp { // VMULPS/VMULPD/VMULSS/VMULSD
          MP_NONE => {
            write_xmm(dst, vmulps_xmm(src1, src2));
            Ok()
          },
          MP_66   => {
            write_xmm(dst, vmulpd_xmm(src1, src2));
            Ok()
          },
          MP_F3   => {
            write_xmm(dst, src1[127..32] @ __f32_mul(src1[31..0], src2[31..0]));
            Ok()
          },
          MP_F2   => {
            write_xmm(dst, src1[127..64] @ __f64_mul(src1[63..0], src2[63..0]));
            Ok()
          },
        },
        12 => match mp { // VSUBPS/VSUBPD/VSUBSS/VSUBSD
          MP_NONE => {
            write_xmm(dst, vsubps_xmm(src1, src2));
            Ok()
          },
          MP_66   => {
            write_xmm(dst, vsubpd_xmm(src1, src2));
            Ok()
          },
          MP_F3   => {
            write_xmm(dst, src1[127..32] @ __f32_sub(src1[31..0], src2[31..0]));
            Ok()
          },
          MP_F2   => {
            write_xmm(dst, src1[127..64] @ __f64_sub(src1[63..0], src2[63..0]));
            Ok()
          },
        },
        13 => match mp { // VMINPS/VMINPD/VMINSS/VMINSD
          MP_NONE => {
            write_xmm(dst, vminps_xmm(src1, src2));
            Ok()
          },
          MP_66   => {
            write_xmm(dst, vminpd_xmm(src1, src2));
            Ok()
          },
          MP_F3   => {
            write_xmm(dst, src1[127..32] @ __f32_min(src1[31..0], src2[31..0]));
            Ok()
          },
          MP_F2   => {
            write_xmm(dst, src1[127..64] @ __f64_min(src1[63..0], src2[63..0]));
            Ok()
          },
        },
        14 => match mp { // VDIVPS/VDIVPD/VDIVSS/VDIVSD
          MP_NONE => {
            write_xmm(dst, vdivps_xmm(src1, src2));
            Ok()
          },
          MP_66   => {
            write_xmm(dst, vdivpd_xmm(src1, src2));
            Ok()
          },
          MP_F3   => {
            write_xmm(dst, src1[127..32] @ __f32_div(src1[31..0], src2[31..0]));
            Ok()
          },
          MP_F2   => {
            write_xmm(dst, src1[127..64] @ __f64_div(src1[63..0], src2[63..0]));
            Ok()
          },
        },
        15 => match mp { // VMAXPS/VMAXPD/VMAXSS/VMAXSD
          MP_NONE => {
            write_xmm(dst, vmaxps_xmm(src1, src2));
            Ok()
          },
          MP_66   => {
            write_xmm(dst, vmaxpd_xmm(src1, src2));
            Ok()
          },
          MP_F3   => {
            write_xmm(dst, src1[127..32] @ __f32_max(src1[31..0], src2[31..0]));
            Ok()
          },
          MP_F2   => {
            write_xmm(dst, src1[127..64] @ __f64_max(src1[63..0], src2[63..0]));
            Ok()
          },
        },
        _ => raise_UD(),
      }
    }
  },

  // 0F 6E: VMOVD/VMOVQ gpr/mem -> xmm (66 prefix)
  // SDM: VEX.vvvv must be 1111b
  110 => {
    if mp != MP_66 then raise_UD()
    else if pfx.vex_vvvv != 0 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_w then {
        // VMOVQ xmm, r/m64
        let v : qword = match rm {
          RM_reg(idx) => read_gpr64(idx),
          RM_mem(addr) => mem_read64(fixup_addr(addr)),
        };
        write_xmm(dst, zero_extend(v));
        Ok()
      } else {
        // VMOVD xmm, r/m32
        let v : dword = match rm {
          RM_reg(idx) => read_gpr32(idx),
          RM_mem(addr) => mem_read32(fixup_addr(addr)),
        };
        write_xmm(dst, zero_extend(v));
        Ok()
      }
    }
  },

  // 0F 6F: VMOVDQA/VMOVDQU (load)
  111 => {
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    match mp {
      MP_66 => // VMOVDQA
        if pfx.vex_l then {
          write_ymm(dst, decode_vex_src_ymm(modrm, rm, pfx));
          Ok()
        } else {
          write_xmm(dst, decode_vex_src_xmm(modrm, rm, pfx));
          Ok()
        },
      MP_F3 => // VMOVDQU
        if pfx.vex_l then {
          write_ymm(dst, decode_vex_src_ymm(modrm, rm, pfx));
          Ok()
        } else {
          write_xmm(dst, decode_vex_src_xmm(modrm, rm, pfx));
          Ok()
        },
      _ => raise_UD(),
    }
  },

  // 0F 7E: VMOVD/VMOVQ xmm -> gpr/mem (66 prefix) / VMOVQ xmm,xmm/m64 (F3 prefix)
  // SDM: VEX.vvvv must be 1111b
  126 => {
    if pfx.vex_vvvv != 0 then raise_UD()
    else {
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
        };
        Ok()
      },
      MP_F3 => {
        // VMOVQ xmm1, xmm2/m64
        let dst = modrm_xmm_reg(modrm, pfx);
        match rm {
          RM_reg(_) => {
            let src = read_xmm(modrm_xmm_rm(modrm, pfx));
            write_xmm(dst, zero_extend(src[63..0]));
            Ok()
          },
          RM_mem(addr) => {
            let v : qword = mem_read64(fixup_addr(addr));
            write_xmm(dst, zero_extend(v));
            Ok()
          },
        }
      },
      _ => raise_UD(),
    }
    }
  },

  // 0F 7F: VMOVDQA/VMOVDQU (store)
  127 => {
    let modrm = fetch_byte();
    let src = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    match rm {
      RM_reg(_) => {
        let dst = modrm_xmm_rm(modrm, pfx);
        if pfx.vex_l then {
          write_ymm(dst, read_ymm(src));
          Ok()
        }
        else {
          write_xmm(dst, read_xmm(src));
          Ok()
        }
      },
      RM_mem(addr) => {
        let a = fixup_addr(addr);
        if pfx.vex_l then {
          mem_write256(a, read_ymm(src));
          Ok()
        }
        else {
          mem_write128(a, read_xmm(src));
          Ok()
        }
      },
    }
  },

  // 0F 70: VPSHUFD xmm/ymm, xmm/ymm/m, imm8 (66 prefix)
  // SDM: VEX.vvvv must be 1111b. 256-bit shuffles each 128-bit lane independently.
  112 => {
    if mp != MP_66 then raise_UD()
    else if pfx.vex_vvvv != 0 then raise_UD()
    else {
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
        write_ymm(dst, (h3 @ h2 @ h1 @ h0) @ (l3 @ l2 @ l1 @ l0));
        Ok()
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
        write_xmm(dst, d3 @ d2 @ d1 @ d0);
        Ok()
      }
    }
  },

  // 0F 76: VPCMPEQD xmm/ymm (66 prefix)
  118 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let src1 : ymmword = read_ymm(pfx.vex_vvvv);
        let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        let r7 : dword = if src1[255..224] == src2[255..224] then ones() else zeros();
        let r6 : dword = if src1[223..192] == src2[223..192] then ones() else zeros();
        let r5 : dword = if src1[191..160] == src2[191..160] then ones() else zeros();
        let r4 : dword = if src1[159..128] == src2[159..128] then ones() else zeros();
        let r3 : dword = if src1[127..96]  == src2[127..96]  then ones() else zeros();
        let r2 : dword = if src1[95..64]   == src2[95..64]   then ones() else zeros();
        let r1 : dword = if src1[63..32]   == src2[63..32]   then ones() else zeros();
        let r0 : dword = if src1[31..0]    == src2[31..0]    then ones() else zeros();
        write_ymm(dst, r7 @ r6 @ r5 @ r4 @ r3 @ r2 @ r1 @ r0);
        Ok()
      } else {
        let src1 : xmmword = read_xmm(pfx.vex_vvvv);
        let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        let r3 : dword = if src1[127..96] == src2[127..96] then ones() else zeros();
        let r2 : dword = if src1[95..64]  == src2[95..64]  then ones() else zeros();
        let r1 : dword = if src1[63..32]  == src2[63..32]  then ones() else zeros();
        let r0 : dword = if src1[31..0]   == src2[31..0]   then ones() else zeros();
        write_xmm(dst, r3 @ r2 @ r1 @ r0);
        Ok()
      }
    }
  },

  // 0F 77: VZEROUPPER (VEX.128) / VZEROALL (VEX.256)
  119 => {
    if pfx.vex_l then {
      // VZEROALL: zero ZMM0-ZMM15 entirely (in 64-bit mode)
      foreach (i from 0 to 15) {
        ZMM[i] = zeros()
      };
      Ok()
    } else {
      // VZEROUPPER: zero upper bits (255:128) of ZMM0-ZMM15
      foreach (i from 0 to 15) {
        var r : zmmword = ZMM[i];
        r[511..128] = zeros();
        ZMM[i] = r
      };
      Ok()
    }
  },

  // 0F EF: VPXOR (66 prefix)
  239 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src1_reg = pfx.vex_vvvv;
      if pfx.vex_l then {
        let src1 : ymmword = read_ymm(src1_reg);
        let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, xor_vec(src1, src2));
        Ok()
      } else {
        let src1 : xmmword = read_xmm(src1_reg);
        let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        write_xmm(dst, xor_vec(src1, src2));
        Ok()
      }
    }
  },

  // 0F DB: VPAND (66 prefix)
  219 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        write_ymm(dst, read_ymm(pfx.vex_vvvv) & decode_vex_src_ymm(modrm, rm, pfx));
        Ok()
      } else {
        write_xmm(dst, read_xmm(pfx.vex_vvvv) & decode_vex_src_xmm(modrm, rm, pfx));
        Ok()
      }
    }
  },

  // 0F DF: VPANDN (66 prefix)
  223 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        write_ymm(dst, ~(read_ymm(pfx.vex_vvvv)) & decode_vex_src_ymm(modrm, rm, pfx));
        Ok()
      } else {
        write_xmm(dst, ~(read_xmm(pfx.vex_vvvv)) & decode_vex_src_xmm(modrm, rm, pfx));
        Ok()
      }
    }
  },

  // 0F EB: VPOR (66 prefix)
  235 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        write_ymm(dst, read_ymm(pfx.vex_vvvv) | decode_vex_src_ymm(modrm, rm, pfx));
        Ok()
      } else {
        write_xmm(dst, read_xmm(pfx.vex_vvvv) | decode_vex_src_xmm(modrm, rm, pfx));
        Ok()
      }
    }
  },

  // 0F FC: VPADDB (66 prefix)
  252 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let src1 : ymmword = read_ymm(pfx.vex_vvvv);
        let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, avx_paddb_256(src1, src2));
        Ok()
      } else {
        let src1 : xmmword = read_xmm(pfx.vex_vvvv);
        let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        write_xmm(dst, avx_paddb_128(src1, src2));
        Ok()
      }
    }
  },

  // 0F FD: VPADDW (66 prefix)
  253 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let src1 : ymmword = read_ymm(pfx.vex_vvvv);
        let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, avx_paddw_256(src1, src2));
        Ok()
      } else {
        let src1 : xmmword = read_xmm(pfx.vex_vvvv);
        let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        write_xmm(dst, avx_paddw_128(src1, src2));
        Ok()
      }
    }
  },

  // 0F FE: VPADDD (66 prefix)
  254 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let src1 : ymmword = read_ymm(pfx.vex_vvvv);
        let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, avx_paddd_256(src1, src2));
        Ok()
      } else {
        let src1 : xmmword = read_xmm(pfx.vex_vvvv);
        let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        write_xmm(dst, avx_paddd_128(src1, src2));
        Ok()
      }
    }
  },

  // 0F D4: VPADDQ (66 prefix)
  212 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let src1 : ymmword = read_ymm(pfx.vex_vvvv);
        let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, avx_paddq_256(src1, src2));
        Ok()
      } else {
        let src1 : xmmword = read_xmm(pfx.vex_vvvv);
        let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        write_xmm(dst, avx_paddq_128(src1, src2));
        Ok()
      }
    }
  },

  // 0F F8: VPSUBB (66 prefix)
  248 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let src1 : ymmword = read_ymm(pfx.vex_vvvv);
        let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, avx_psubb_256(src1, src2));
        Ok()
      } else {
        let src1 : xmmword = read_xmm(pfx.vex_vvvv);
        let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        write_xmm(dst, avx_psubb_128(src1, src2));
        Ok()
      }
    }
  },

  // 0F F9: VPSUBW (66 prefix)
  249 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        write_ymm(dst, avx_psubw_256(read_ymm(pfx.vex_vvvv), decode_vex_src_ymm(modrm, rm, pfx)));
        Ok()
      } else {
        write_xmm(dst, avx_psubw_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)));
        Ok()
      }
    }
  },

  // 0F FA: VPSUBD (66 prefix)
  250 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        write_ymm(dst, avx_psubd_256(read_ymm(pfx.vex_vvvv), decode_vex_src_ymm(modrm, rm, pfx)));
        Ok()
      } else {
        write_xmm(dst, avx_psubd_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)));
        Ok()
      }
    }
  },

  // 0F FB: VPSUBQ (66 prefix)
  251 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        write_ymm(dst, avx_psubq_256(read_ymm(pfx.vex_vvvv), decode_vex_src_ymm(modrm, rm, pfx)));
        Ok()
      } else {
        write_xmm(dst, avx_psubq_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)));
        Ok()
      }
    }
  },

  _ => raise_UD(),
  }
}

// =========================================================================
// VEX 0F38 map dispatch
// =========================================================================

val dispatch_vex_0f38 : (byte, Prefixes) -> ExecutionResult
function dispatch_vex_0f38(opcode, pfx) = {
  let op : range(0, 255) = unsigned(opcode);
  let mp = get_mandatory_prefix(pfx);

  match op {

  // 0F38 18: VBROADCASTSS xmm1, xmm2/m32 (VEX.128/256)
  24 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let val32 : dword = match rm {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[31..0],
        RM_mem(addr) => mem_read32(fixup_addr(addr)),
      };
      if pfx.vex_l then {
        // 256-bit: broadcast to 8 dwords
        write_ymm(dst, val32 @ val32 @ val32 @ val32 @
                       val32 @ val32 @ val32 @ val32);
        Ok()
      } else {
        // 128-bit: broadcast to 4 dwords
        write_xmm(dst, val32 @ val32 @ val32 @ val32);
        Ok()
      }
    }
  },

  // 0F38 19: VBROADCASTSD ymm1, xmm2/m64 (VEX.256 only)
  // SDM: VEX.128 form #UDs
  25 => {
    if mp != MP_66 then raise_UD()
    else if not_bool(pfx.vex_l) then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let val64 : qword = match rm {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[63..0],
        RM_mem(addr) => mem_read64(fixup_addr(addr)),
      };
      write_ymm(dst, val64 @ val64 @ val64 @ val64);
      Ok()
    }
  },

  // 0F38 1A: VBROADCASTF128 ymm1, m128 (VEX.256 only)
  26 => {
    if mp != MP_66 then raise_UD()
    else if not_bool(pfx.vex_l) then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      match rm {
        RM_reg(_) => raise_UD(), // memory-only
        RM_mem(addr) => {
          let v : xmmword = mem_read128(fixup_addr(addr));
          write_ymm(dst, v @ v);
          Ok()
        },
      }
    }
  },

  _ => raise_UD(),
  }
}

// =========================================================================
// VEX 0F3A map dispatch
// =========================================================================

val dispatch_vex_0f3a : (byte, Prefixes) -> ExecutionResult
function dispatch_vex_0f3a(opcode, pfx) = {
  let op : range(0, 255) = unsigned(opcode);
  let mp = get_mandatory_prefix(pfx);

  match op {

  // 0F3A 18: VINSERTF128 ymm1, ymm2, xmm3/m128, imm8
  24 => {
    if mp != MP_66 then raise_UD()
    else if not_bool(pfx.vex_l) then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src1 : ymmword = read_ymm(pfx.vex_vvvv);
      let src2 : xmmword = match rm {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
        RM_mem(addr) => mem_read128(fixup_addr(addr)),
      };
      let imm = fetch_byte();
      // imm8[0] selects which 128-bit lane to replace
      if imm[0] == bitzero then
        write_ymm(dst, src1[255..128] @ src2)
      else
        write_ymm(dst, src2 @ src1[127..0]);
      Ok()
    }
  },

  // 0F3A 19: VEXTRACTF128 xmm1/m128, ymm2, imm8
  25 => {
    if mp != MP_66 then raise_UD()
    else if not_bool(pfx.vex_l) then raise_UD()
    else {
      let modrm = fetch_byte();
      let src = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src_ymm : ymmword = read_ymm(src);
      let imm = fetch_byte();
      let extracted : xmmword =
        if imm[0] == bitzero then src_ymm[127..0]
        else src_ymm[255..128];
      match rm {
        RM_reg(_) => {
          write_xmm(modrm_xmm_rm(modrm, pfx), extracted);
          Ok()
        },
        RM_mem(addr) => {
          mem_write128(fixup_addr(addr), extracted);
          Ok()
        },
      }
    }
  },

  _ => raise_UD(),
  }
}

// =========================================================================
// Top-level VEX dispatch — called from 1-byte opcode map for C4/C5.
// Must come after dispatch_vex_0f/0f38/0f3a definitions.
// =========================================================================

val dispatch_vex : byte -> ExecutionResult
function dispatch_vex(first_byte) = {
  let (pfx, map) : (Prefixes, range(0, 31)) =
    if first_byte == 0xC5 then {
      let b1 = fetch_byte();
      decode_vex2(b1)
    } else {
      // C4 = 3-byte VEX
      let b1 = fetch_byte();
      let b2 = fetch_byte();
      decode_vex3(b1, b2)
    };

  let opcode = fetch_byte();

  match map {
    1 => dispatch_vex_0f(opcode, pfx),
    2 => dispatch_vex_0f38(opcode, pfx),
    3 => dispatch_vex_0f3a(opcode, pfx),
    _ => raise_UD(),
  }
}

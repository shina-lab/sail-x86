// x86-64 — MMX Operations
//
// MMX instructions operate on MM0-MM7 (64-bit registers aliasing the low
// 64 bits of x87 ST(0)-ST(7) by physical index). All MMX instructions
// set TOP=0 and all x87 tags to valid via mmx_touch().
//
// MMX opcodes share the 0F xx space with SSE2. Without a 66/F2/F3
// mandatory prefix the instruction is MMX; with 66 it's SSE2/SSE.

// Helper: read 64-bit MMX source from modrm r/m field
val mmx_read_rm : (byte, RM) -> qword
function mmx_read_rm(modrm, src) = {
  match src {
    RM_reg(_, _) => read_mm(modrm_mm_rm(modrm)),
    RM_mem(seg, offset) => seg_read(seg, offset),
  }
}

// =========================================================================
// MMX dispatch — handles all 0F xx opcodes when mandatory prefix is NONE
// =========================================================================

function dispatch_mmx(op, pfx) = {
  match op {
    // 0F 60: PUNPCKLBW mm, mm/m32
    96 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_reg(modrm);
      let src = decode_rm(modrm, pfx);
      let s : qword = mmx_read_rm(modrm, src);
      let d : qword = read_mm(dst);
      write_mm(dst, s[31..24] @ d[31..24] @ s[23..16] @ d[23..16] @
                     s[15..8]  @ d[15..8]  @ s[7..0]   @ d[7..0]);
      mmx_touch()
    },

    // 0F 61: PUNPCKLWD mm, mm/m32
    97 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_reg(modrm);
      let src = decode_rm(modrm, pfx);
      let s : qword = mmx_read_rm(modrm, src);
      let d : qword = read_mm(dst);
      write_mm(dst, s[31..16] @ d[31..16] @ s[15..0] @ d[15..0]);
      mmx_touch()
    },

    // 0F 62: PUNPCKLDQ mm, mm/m32
    98 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_reg(modrm);
      let src = decode_rm(modrm, pfx);
      let s : qword = mmx_read_rm(modrm, src);
      let d : qword = read_mm(dst);
      write_mm(dst, s[31..0] @ d[31..0]);
      mmx_touch()
    },

    // 0F 63: PACKSSWB mm, mm/m64
    99 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_reg(modrm);
      let src = decode_rm(modrm, pfx);
      let s : qword = mmx_read_rm(modrm, src);
      let d : qword = read_mm(dst);
      write_mm(dst, sat_s8(s[63..48]) @ sat_s8(s[47..32]) @
                     sat_s8(s[31..16]) @ sat_s8(s[15..0]) @
                     sat_s8(d[63..48]) @ sat_s8(d[47..32]) @
                     sat_s8(d[31..16]) @ sat_s8(d[15..0]));
      mmx_touch()
    },

    // 0F 64: PCMPGTB mm, mm/m64
    100 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_reg(modrm);
      let src = decode_rm(modrm, pfx);
      let s : qword = mmx_read_rm(modrm, src);
      let d : qword = read_mm(dst);
      write_mm(dst, cmp_gt(d[63..56], s[63..56]) @ cmp_gt(d[55..48], s[55..48]) @
                     cmp_gt(d[47..40], s[47..40]) @ cmp_gt(d[39..32], s[39..32]) @
                     cmp_gt(d[31..24], s[31..24]) @ cmp_gt(d[23..16], s[23..16]) @
                     cmp_gt(d[15..8],  s[15..8])  @ cmp_gt(d[7..0],   s[7..0]));
      mmx_touch()
    },

    // 0F 65: PCMPGTW mm, mm/m64
    101 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_reg(modrm);
      let src = decode_rm(modrm, pfx);
      let s : qword = mmx_read_rm(modrm, src);
      let d : qword = read_mm(dst);
      write_mm(dst, cmp_gt(d[63..48], s[63..48]) @ cmp_gt(d[47..32], s[47..32]) @
                     cmp_gt(d[31..16], s[31..16]) @ cmp_gt(d[15..0],  s[15..0]));
      mmx_touch()
    },

    // 0F 66: PCMPGTD mm, mm/m64
    102 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_reg(modrm);
      let src = decode_rm(modrm, pfx);
      let s : qword = mmx_read_rm(modrm, src);
      let d : qword = read_mm(dst);
      write_mm(dst, cmp_gt(d[63..32], s[63..32]) @ cmp_gt(d[31..0], s[31..0]));
      mmx_touch()
    },

    // 0F 67: PACKUSWB mm, mm/m64
    103 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_reg(modrm);
      let src = decode_rm(modrm, pfx);
      let s : qword = mmx_read_rm(modrm, src);
      let d : qword = read_mm(dst);
      write_mm(dst, sat_su8(s[63..48]) @ sat_su8(s[47..32]) @
                     sat_su8(s[31..16]) @ sat_su8(s[15..0]) @
                     sat_su8(d[63..48]) @ sat_su8(d[47..32]) @
                     sat_su8(d[31..16]) @ sat_su8(d[15..0]));
      mmx_touch()
    },

    // 0F 68: PUNPCKHBW mm, mm/m64
    104 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_reg(modrm);
      let src = decode_rm(modrm, pfx);
      let s : qword = mmx_read_rm(modrm, src);
      let d : qword = read_mm(dst);
      write_mm(dst, s[63..56] @ d[63..56] @ s[55..48] @ d[55..48] @
                     s[47..40] @ d[47..40] @ s[39..32] @ d[39..32]);
      mmx_touch()
    },

    // 0F 69: PUNPCKHWD mm, mm/m64
    105 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_reg(modrm);
      let src = decode_rm(modrm, pfx);
      let s : qword = mmx_read_rm(modrm, src);
      let d : qword = read_mm(dst);
      write_mm(dst, s[63..48] @ d[63..48] @ s[47..32] @ d[47..32]);
      mmx_touch()
    },

    // 0F 6A: PUNPCKHDQ mm, mm/m64
    106 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_reg(modrm);
      let src = decode_rm(modrm, pfx);
      let s : qword = mmx_read_rm(modrm, src);
      let d : qword = read_mm(dst);
      write_mm(dst, s[63..32] @ d[63..32]);
      mmx_touch()
    },

    // 0F 6B: PACKSSDW mm, mm/m64
    107 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_reg(modrm);
      let src = decode_rm(modrm, pfx);
      let s : qword = mmx_read_rm(modrm, src);
      let d : qword = read_mm(dst);
      write_mm(dst, sat_s16(s[63..32]) @ sat_s16(s[31..0]) @
                     sat_s16(d[63..32]) @ sat_s16(d[31..0]));
      mmx_touch()
    },

    // 0F 6E: MOVD mm, r/m32 (or MOVQ mm, r/m64 with REX.W)
    110 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_reg(modrm);
      let src = decode_rm(modrm, pfx);
      match (src, pfx.rex_w) {
        (RM_reg(idx, _), true)   => write_mm(dst, reg(64, idx)),
        (RM_mem(seg, offset), true)  => write_mm(dst, seg_read(seg, offset)),
        (RM_reg(idx, _), false)  => write_mm(dst, zero_extend(reg(32, idx))),
        (RM_mem(seg, offset), false) => write_mm(dst, zero_extend(seg_read(4,seg, offset))),
      };
      mmx_touch()
    },

    // 0F 6F: MOVQ mm, mm/m64
    111 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_reg(modrm);
      let src = decode_rm(modrm, pfx);
      let v : qword = mmx_read_rm(modrm, src);
      write_mm(dst, v);
      mmx_touch()
    },

    // 0F 70: PSHUFW mm, mm/m64, imm8
    112 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_reg(modrm);
      let src = decode_rm(modrm, pfx);
      let src : qword = mmx_read_rm(modrm, src);
      let imm = fetch_byte();
      let w0 : word = match unsigned(imm[1..0]) {
        0 => src[15..0], 1 => src[31..16], 2 => src[47..32], 3 => src[63..48],
      };
      let w1 : word = match unsigned(imm[3..2]) {
        0 => src[15..0], 1 => src[31..16], 2 => src[47..32], 3 => src[63..48],
      };
      let w2 : word = match unsigned(imm[5..4]) {
        0 => src[15..0], 1 => src[31..16], 2 => src[47..32], 3 => src[63..48],
      };
      let w3 : word = match unsigned(imm[7..6]) {
        0 => src[15..0], 1 => src[31..16], 2 => src[47..32], 3 => src[63..48],
      };
      write_mm(dst, w3 @ w2 @ w1 @ w0);
      mmx_touch()
    },

    // 0F 71: Group 12 — PSRLW/PSRAW/PSLLW mm, imm8
    113 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_rm(modrm);
      let imm = fetch_byte();
      let c : nat = unsigned(imm);
      let d : qword = read_mm(dst);
      let reg_field : range(0, 7) = unsigned(modrm[5..3]);
      match reg_field {
        2 => {
          write_mm(dst, (d[63..48] >> c) @ (d[47..32] >> c) @
                         (d[31..16] >> c) @ (d[15..0] >> c));
          mmx_touch()
        },
        4 => {
          write_mm(dst, (d[63..48] >>> c) @ (d[47..32] >>> c) @
                         (d[31..16] >>> c) @ (d[15..0] >>> c));
          mmx_touch()
        },
        6 => {
          write_mm(dst, (d[63..48] << c) @ (d[47..32] << c) @
                         (d[31..16] << c) @ (d[15..0] << c));
          mmx_touch()
        },
        _ => raise_UD(),
      }
    },

    // 0F 72: Group 13 — PSRLD/PSRAD/PSLLD mm, imm8
    114 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_rm(modrm);
      let imm = fetch_byte();
      let c : nat = unsigned(imm);
      let d : qword = read_mm(dst);
      let reg_field : range(0, 7) = unsigned(modrm[5..3]);
      match reg_field {
        2 => {
          write_mm(dst, (d[63..32] >> c) @ (d[31..0] >> c));
          mmx_touch()
        },
        4 => {
          write_mm(dst, (d[63..32] >>> c) @ (d[31..0] >>> c));
          mmx_touch()
        },
        6 => {
          write_mm(dst, (d[63..32] << c) @ (d[31..0] << c));
          mmx_touch()
        },
        _ => raise_UD(),
      }
    },

    // 0F 73: Group 14 — PSRLQ/PSLLQ mm, imm8
    115 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_rm(modrm);
      let imm = fetch_byte();
      let c : nat = unsigned(imm);
      let d : qword = read_mm(dst);
      let reg_field : range(0, 7) = unsigned(modrm[5..3]);
      match reg_field {
        2 => {
          write_mm(dst, (d >> c));
          mmx_touch()
        },
        6 => {
          write_mm(dst, (d << c));
          mmx_touch()
        },
        _ => raise_UD(),
      }
    },

    // 0F 74: PCMPEQB mm, mm/m64
    116 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_reg(modrm);
      let src = decode_rm(modrm, pfx);
      let s : qword = mmx_read_rm(modrm, src);
      let d : qword = read_mm(dst);
      write_mm(dst, cmp_eq(d[63..56], s[63..56]) @ cmp_eq(d[55..48], s[55..48]) @
                     cmp_eq(d[47..40], s[47..40]) @ cmp_eq(d[39..32], s[39..32]) @
                     cmp_eq(d[31..24], s[31..24]) @ cmp_eq(d[23..16], s[23..16]) @
                     cmp_eq(d[15..8],  s[15..8])  @ cmp_eq(d[7..0],   s[7..0]));
      mmx_touch()
    },

    // 0F 75: PCMPEQW mm, mm/m64
    117 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_reg(modrm);
      let src = decode_rm(modrm, pfx);
      let s : qword = mmx_read_rm(modrm, src);
      let d : qword = read_mm(dst);
      write_mm(dst, cmp_eq(d[63..48], s[63..48]) @ cmp_eq(d[47..32], s[47..32]) @
                     cmp_eq(d[31..16], s[31..16]) @ cmp_eq(d[15..0], s[15..0]));
      mmx_touch()
    },

    // 0F 76: PCMPEQD mm, mm/m64
    118 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_reg(modrm);
      let src = decode_rm(modrm, pfx);
      let s : qword = mmx_read_rm(modrm, src);
      let d : qword = read_mm(dst);
      write_mm(dst, cmp_eq(d[63..32], s[63..32]) @ cmp_eq(d[31..0], s[31..0]));
      mmx_touch()
    },

    // 0F 7E: MOVD r/m32, mm (or MOVQ r/m64, mm with REX.W)
    126 => {
      let modrm = fetch_byte();
      let src = modrm_mm_reg(modrm);
      let dest = decode_rm(modrm, pfx);
      let v : qword = read_mm(src);
      match (dest, pfx.rex_w) {
        (RM_reg(idx, _), true)   => reg(idx) = v,
        (RM_mem(seg, offset), true)  => seg_write(seg, offset, v),
        (RM_reg(idx, _), false)  => reg(idx) = v[31..0],
        (RM_mem(seg, offset), false) => seg_write(4, seg, offset, v[31..0]),
      };
      mmx_touch()
    },

    // 0F 7F: MOVQ mm/m64, mm
    127 => {
      let modrm = fetch_byte();
      let src = modrm_mm_reg(modrm);
      let dest = decode_rm(modrm, pfx);
      let v : qword = read_mm(src);
      match dest {
        RM_reg(_, _) => write_mm(modrm_mm_rm(modrm), v),
        RM_mem(seg, offset) => seg_write(seg, offset, v),
      };
      mmx_touch()
    },

    // 0F C4: PINSRW mm, r32/m16, imm8
    196 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_reg(modrm);
      let src = decode_rm(modrm, pfx);
      let w : word = match src {
        RM_reg(idx, _) => reg(32, idx)[15..0],
        RM_mem(seg, offset) => seg_read(seg, offset),
      };
      let imm = fetch_byte();
      let sel : range(0, 3) = unsigned(imm[1..0]);
      var d : qword = read_mm(dst);
      let lo = sel * 16;
      d[(lo + 15) .. lo] = w;
      write_mm(dst, d);
      mmx_touch()
    },

    // 0F C5: PEXTRW r32, mm, imm8
    197 => {
      let modrm = fetch_byte();
      let dst_gpr = modrm_reg(modrm, pfx);
      let src = modrm_mm_rm(modrm);
      let imm = fetch_byte();
      let sel : range(0, 3) = unsigned(imm[1..0]);
      let v : qword = read_mm(src);
      let lo = sel * 16;
      let w : word = v[(lo + 15) .. lo];
      reg(32, dst_gpr) = zero_extend(w);
      mmx_touch()
    },

    // 0F D1: PSRLW mm, mm/m64
    209 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_reg(modrm);
      let src = decode_rm(modrm, pfx);
      let c : nat = unsigned(mmx_read_rm(modrm, src));
      let d : qword = read_mm(dst);
      write_mm(dst, (d[63..48] >> c) @ (d[47..32] >> c) @
                     (d[31..16] >> c) @ (d[15..0] >> c));
      mmx_touch()
    },

    // 0F D2: PSRLD mm, mm/m64
    210 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_reg(modrm);
      let src = decode_rm(modrm, pfx);
      let c : nat = unsigned(mmx_read_rm(modrm, src));
      let d : qword = read_mm(dst);
      write_mm(dst, (d[63..32] >> c) @ (d[31..0] >> c));
      mmx_touch()
    },

    // 0F D3: PSRLQ mm, mm/m64
    211 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_reg(modrm);
      let src = decode_rm(modrm, pfx);
      let c : nat = unsigned(mmx_read_rm(modrm, src));
      let d : qword = read_mm(dst);
      write_mm(dst, (d >> c));
      mmx_touch()
    },

    // 0F D4: PADDQ mm, mm/m64
    212 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_reg(modrm);
      let src = decode_rm(modrm, pfx);
      let s : qword = mmx_read_rm(modrm, src);
      let d : qword = read_mm(dst);
      write_mm(dst, d + s);
      mmx_touch()
    },

    // 0F D5: PMULLW mm, mm/m64
    213 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_reg(modrm);
      let src = decode_rm(modrm, pfx);
      let s : qword = mmx_read_rm(modrm, src);
      let d : qword = read_mm(dst);
      write_mm(dst, mul_lo(d[63..48], s[63..48]) @ mul_lo(d[47..32], s[47..32]) @
                     mul_lo(d[31..16], s[31..16]) @ mul_lo(d[15..0],  s[15..0]));
      mmx_touch()
    },

    // 0F D7: PMOVMSKB r32, mm
    215 => {
      let modrm = fetch_byte();
      let dst_gpr = modrm_reg(modrm, pfx);
      let src = modrm_mm_rm(modrm);
      let v : qword = read_mm(src);
      let mask : byte =
        v[63] @ v[55] @ v[47] @ v[39] @
        v[31] @ v[23] @ v[15] @ v[7];
      reg(32, dst_gpr) = zero_extend(mask);
      mmx_touch()
    },

    // 0F D8: PSUBUSB mm, mm/m64
    216 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_reg(modrm);
      let src = decode_rm(modrm, pfx);
      let s : qword = mmx_read_rm(modrm, src);
      let d : qword = read_mm(dst);
      write_mm(dst, sat_sub_u(d[63..56], s[63..56]) @ sat_sub_u(d[55..48], s[55..48]) @
                     sat_sub_u(d[47..40], s[47..40]) @ sat_sub_u(d[39..32], s[39..32]) @
                     sat_sub_u(d[31..24], s[31..24]) @ sat_sub_u(d[23..16], s[23..16]) @
                     sat_sub_u(d[15..8],  s[15..8])  @ sat_sub_u(d[7..0],   s[7..0]));
      mmx_touch()
    },

    // 0F D9: PSUBUSW mm, mm/m64
    217 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_reg(modrm);
      let src = decode_rm(modrm, pfx);
      let s : qword = mmx_read_rm(modrm, src);
      let d : qword = read_mm(dst);
      write_mm(dst, sat_sub_u(d[63..48], s[63..48]) @ sat_sub_u(d[47..32], s[47..32]) @
                     sat_sub_u(d[31..16], s[31..16]) @ sat_sub_u(d[15..0],  s[15..0]));
      mmx_touch()
    },

    // 0F DA: PMINUB mm, mm/m64
    218 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_reg(modrm);
      let src = decode_rm(modrm, pfx);
      let s : qword = mmx_read_rm(modrm, src);
      let d : qword = read_mm(dst);
      write_mm(dst, min_u(d[63..56], s[63..56]) @ min_u(d[55..48], s[55..48]) @
                     min_u(d[47..40], s[47..40]) @ min_u(d[39..32], s[39..32]) @
                     min_u(d[31..24], s[31..24]) @ min_u(d[23..16], s[23..16]) @
                     min_u(d[15..8],  s[15..8])  @ min_u(d[7..0],   s[7..0]));
      mmx_touch()
    },

    // 0F DB: PAND mm, mm/m64
    219 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_reg(modrm);
      let src = decode_rm(modrm, pfx);
      let s : qword = mmx_read_rm(modrm, src);
      write_mm(dst, read_mm(dst) & s);
      mmx_touch()
    },

    // 0F DC: PADDUSB mm, mm/m64
    220 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_reg(modrm);
      let src = decode_rm(modrm, pfx);
      let s : qword = mmx_read_rm(modrm, src);
      let d : qword = read_mm(dst);
      write_mm(dst, sat_add_u(d[63..56], s[63..56]) @ sat_add_u(d[55..48], s[55..48]) @
                     sat_add_u(d[47..40], s[47..40]) @ sat_add_u(d[39..32], s[39..32]) @
                     sat_add_u(d[31..24], s[31..24]) @ sat_add_u(d[23..16], s[23..16]) @
                     sat_add_u(d[15..8],  s[15..8])  @ sat_add_u(d[7..0],   s[7..0]));
      mmx_touch()
    },

    // 0F DD: PADDUSW mm, mm/m64
    221 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_reg(modrm);
      let src = decode_rm(modrm, pfx);
      let s : qword = mmx_read_rm(modrm, src);
      let d : qword = read_mm(dst);
      write_mm(dst, sat_add_u(d[63..48], s[63..48]) @ sat_add_u(d[47..32], s[47..32]) @
                     sat_add_u(d[31..16], s[31..16]) @ sat_add_u(d[15..0],  s[15..0]));
      mmx_touch()
    },

    // 0F DE: PMAXUB mm, mm/m64
    222 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_reg(modrm);
      let src = decode_rm(modrm, pfx);
      let s : qword = mmx_read_rm(modrm, src);
      let d : qword = read_mm(dst);
      write_mm(dst, max_u(d[63..56], s[63..56]) @ max_u(d[55..48], s[55..48]) @
                     max_u(d[47..40], s[47..40]) @ max_u(d[39..32], s[39..32]) @
                     max_u(d[31..24], s[31..24]) @ max_u(d[23..16], s[23..16]) @
                     max_u(d[15..8],  s[15..8])  @ max_u(d[7..0],   s[7..0]));
      mmx_touch()
    },

    // 0F DF: PANDN mm, mm/m64
    223 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_reg(modrm);
      let src = decode_rm(modrm, pfx);
      let s : qword = mmx_read_rm(modrm, src);
      write_mm(dst, ~(read_mm(dst)) & s);
      mmx_touch()
    },

    // 0F E0: PAVGB mm, mm/m64
    224 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_reg(modrm);
      let src = decode_rm(modrm, pfx);
      let s : qword = mmx_read_rm(modrm, src);
      let d : qword = read_mm(dst);
      write_mm(dst, avg(d[63..56], s[63..56]) @ avg(d[55..48], s[55..48]) @
                     avg(d[47..40], s[47..40]) @ avg(d[39..32], s[39..32]) @
                     avg(d[31..24], s[31..24]) @ avg(d[23..16], s[23..16]) @
                     avg(d[15..8],  s[15..8])  @ avg(d[7..0],   s[7..0]));
      mmx_touch()
    },

    // 0F E1: PSRAW mm, mm/m64
    225 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_reg(modrm);
      let src = decode_rm(modrm, pfx);
      let c : nat = unsigned(mmx_read_rm(modrm, src));
      let d : qword = read_mm(dst);
      write_mm(dst, (d[63..48] >>> c) @ (d[47..32] >>> c) @
                     (d[31..16] >>> c) @ (d[15..0] >>> c));
      mmx_touch()
    },

    // 0F E2: PSRAD mm, mm/m64
    226 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_reg(modrm);
      let src = decode_rm(modrm, pfx);
      let c : nat = unsigned(mmx_read_rm(modrm, src));
      let d : qword = read_mm(dst);
      write_mm(dst, (d[63..32] >>> c) @ (d[31..0] >>> c));
      mmx_touch()
    },

    // 0F E3: PAVGW mm, mm/m64
    227 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_reg(modrm);
      let src = decode_rm(modrm, pfx);
      let s : qword = mmx_read_rm(modrm, src);
      let d : qword = read_mm(dst);
      write_mm(dst, avg(d[63..48], s[63..48]) @ avg(d[47..32], s[47..32]) @
                     avg(d[31..16], s[31..16]) @ avg(d[15..0],  s[15..0]));
      mmx_touch()
    },

    // 0F E4: PMULHUW mm, mm/m64
    228 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_reg(modrm);
      let src = decode_rm(modrm, pfx);
      let s : qword = mmx_read_rm(modrm, src);
      let d : qword = read_mm(dst);
      write_mm(dst, mul_hi16u(d[63..48], s[63..48]) @ mul_hi16u(d[47..32], s[47..32]) @
                     mul_hi16u(d[31..16], s[31..16]) @ mul_hi16u(d[15..0],  s[15..0]));
      mmx_touch()
    },

    // 0F E5: PMULHW mm, mm/m64
    229 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_reg(modrm);
      let src = decode_rm(modrm, pfx);
      let s : qword = mmx_read_rm(modrm, src);
      let d : qword = read_mm(dst);
      write_mm(dst, mul_hi16s(d[63..48], s[63..48]) @ mul_hi16s(d[47..32], s[47..32]) @
                     mul_hi16s(d[31..16], s[31..16]) @ mul_hi16s(d[15..0],  s[15..0]));
      mmx_touch()
    },

    // 0F E7: MOVNTQ m64, mm
    231 => {
      let modrm = fetch_byte();
      let src = modrm_mm_reg(modrm);
      let dest = decode_rm(modrm, pfx);
      write_mem_rm(dest, read_mm(src)); mmx_touch()
    },

    // 0F E8: PSUBSB mm, mm/m64
    232 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_reg(modrm);
      let src = decode_rm(modrm, pfx);
      let s : qword = mmx_read_rm(modrm, src);
      let d : qword = read_mm(dst);
      write_mm(dst, sat_sub_s(d[63..56], s[63..56]) @ sat_sub_s(d[55..48], s[55..48]) @
                     sat_sub_s(d[47..40], s[47..40]) @ sat_sub_s(d[39..32], s[39..32]) @
                     sat_sub_s(d[31..24], s[31..24]) @ sat_sub_s(d[23..16], s[23..16]) @
                     sat_sub_s(d[15..8],  s[15..8])  @ sat_sub_s(d[7..0],   s[7..0]));
      mmx_touch()
    },

    // 0F E9: PSUBSW mm, mm/m64
    233 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_reg(modrm);
      let src = decode_rm(modrm, pfx);
      let s : qword = mmx_read_rm(modrm, src);
      let d : qword = read_mm(dst);
      write_mm(dst, sat_sub_s(d[63..48], s[63..48]) @ sat_sub_s(d[47..32], s[47..32]) @
                     sat_sub_s(d[31..16], s[31..16]) @ sat_sub_s(d[15..0],  s[15..0]));
      mmx_touch()
    },

    // 0F EA: PMINSW mm, mm/m64
    234 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_reg(modrm);
      let src = decode_rm(modrm, pfx);
      let s : qword = mmx_read_rm(modrm, src);
      let d : qword = read_mm(dst);
      write_mm(dst, min_s(d[63..48], s[63..48]) @ min_s(d[47..32], s[47..32]) @
                     min_s(d[31..16], s[31..16]) @ min_s(d[15..0],  s[15..0]));
      mmx_touch()
    },

    // 0F EB: POR mm, mm/m64
    235 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_reg(modrm);
      let src = decode_rm(modrm, pfx);
      let s : qword = mmx_read_rm(modrm, src);
      write_mm(dst, read_mm(dst) | s);
      mmx_touch()
    },

    // 0F EC: PADDSB mm, mm/m64
    236 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_reg(modrm);
      let src = decode_rm(modrm, pfx);
      let s : qword = mmx_read_rm(modrm, src);
      let d : qword = read_mm(dst);
      write_mm(dst, sat_add_s(d[63..56], s[63..56]) @ sat_add_s(d[55..48], s[55..48]) @
                     sat_add_s(d[47..40], s[47..40]) @ sat_add_s(d[39..32], s[39..32]) @
                     sat_add_s(d[31..24], s[31..24]) @ sat_add_s(d[23..16], s[23..16]) @
                     sat_add_s(d[15..8],  s[15..8])  @ sat_add_s(d[7..0],   s[7..0]));
      mmx_touch()
    },

    // 0F ED: PADDSW mm, mm/m64
    237 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_reg(modrm);
      let src = decode_rm(modrm, pfx);
      let s : qword = mmx_read_rm(modrm, src);
      let d : qword = read_mm(dst);
      write_mm(dst, sat_add_s(d[63..48], s[63..48]) @ sat_add_s(d[47..32], s[47..32]) @
                     sat_add_s(d[31..16], s[31..16]) @ sat_add_s(d[15..0],  s[15..0]));
      mmx_touch()
    },

    // 0F EE: PMAXSW mm, mm/m64
    238 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_reg(modrm);
      let src = decode_rm(modrm, pfx);
      let s : qword = mmx_read_rm(modrm, src);
      let d : qword = read_mm(dst);
      write_mm(dst, max_s(d[63..48], s[63..48]) @ max_s(d[47..32], s[47..32]) @
                     max_s(d[31..16], s[31..16]) @ max_s(d[15..0],  s[15..0]));
      mmx_touch()
    },

    // 0F EF: PXOR mm, mm/m64
    239 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_reg(modrm);
      let src = decode_rm(modrm, pfx);
      let s : qword = mmx_read_rm(modrm, src);
      write_mm(dst, read_mm(dst) ^ s);
      mmx_touch()
    },

    // 0F F1: PSLLW mm, mm/m64
    241 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_reg(modrm);
      let src = decode_rm(modrm, pfx);
      let c : nat = unsigned(mmx_read_rm(modrm, src));
      let d : qword = read_mm(dst);
      write_mm(dst, (d[63..48] << c) @ (d[47..32] << c) @
                     (d[31..16] << c) @ (d[15..0] << c));
      mmx_touch()
    },

    // 0F F2: PSLLD mm, mm/m64
    242 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_reg(modrm);
      let src = decode_rm(modrm, pfx);
      let c : nat = unsigned(mmx_read_rm(modrm, src));
      let d : qword = read_mm(dst);
      write_mm(dst, (d[63..32] << c) @ (d[31..0] << c));
      mmx_touch()
    },

    // 0F F3: PSLLQ mm, mm/m64
    243 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_reg(modrm);
      let src = decode_rm(modrm, pfx);
      let c : nat = unsigned(mmx_read_rm(modrm, src));
      let d : qword = read_mm(dst);
      write_mm(dst, (d << c));
      mmx_touch()
    },

    // 0F F4: PMULUDQ mm, mm/m64
    244 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_reg(modrm);
      let src = decode_rm(modrm, pfx);
      let s : qword = mmx_read_rm(modrm, src);
      let d : qword = read_mm(dst);
      let result : qword = to_bits_truncate(unsigned(d[31..0]) * unsigned(s[31..0]));
      write_mm(dst, result);
      mmx_touch()
    },

    // 0F F5: PMADDWD mm, mm/m64
    245 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_reg(modrm);
      let src = decode_rm(modrm, pfx);
      let s : qword = mmx_read_rm(modrm, src);
      let d : qword = read_mm(dst);
      let d1 : dword = to_bits_truncate(signed(d[63..48]) * signed(s[63..48]) + signed(d[47..32]) * signed(s[47..32]));
      let d0 : dword = to_bits_truncate(signed(d[31..16]) * signed(s[31..16]) + signed(d[15..0]) * signed(s[15..0]));
      write_mm(dst, d1 @ d0);
      mmx_touch()
    },

    // 0F F6: PSADBW mm, mm/m64
    246 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_reg(modrm);
      let src = decode_rm(modrm, pfx);
      let s : qword = mmx_read_rm(modrm, src);
      let d : qword = read_mm(dst);
      let sum : int =
        abs_diff8(d[63..56], s[63..56]) + abs_diff8(d[55..48], s[55..48]) +
        abs_diff8(d[47..40], s[47..40]) + abs_diff8(d[39..32], s[39..32]) +
        abs_diff8(d[31..24], s[31..24]) + abs_diff8(d[23..16], s[23..16]) +
        abs_diff8(d[15..8],  s[15..8])  + abs_diff8(d[7..0],   s[7..0]);
      write_mm(dst, zero_extend(to_bits_truncate(16, sum)));
      mmx_touch()
    },

    // 0F F7: MASKMOVQ mm, mm
    247 => {
      let modrm = fetch_byte();
      let src = modrm_mm_reg(modrm);
      let mask_reg = modrm_mm_rm(modrm);
      let src2 = decode_rm(modrm, pfx);
      match src2 {
        RM_reg(_, _) => {
          let data : qword = read_mm(src);
          let mask : qword = read_mm(mask_reg);
          let addr : qword = reg(7);  // RDI
          foreach (i from 0 to 7) {
            let base = i * 8;
            if mask[base + 7] == 0b1 then {
              let b : byte = data[(base + 7) .. base];
              mem_write(addr + zero_extend(to_bits(64, i)), b)
            }
          };
          mmx_touch()
        },
        RM_mem(_, _) => raise_UD(),
      }
    },

    // 0F F8: PSUBB mm, mm/m64
    248 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_reg(modrm);
      let src = decode_rm(modrm, pfx);
      let s : qword = mmx_read_rm(modrm, src);
      let d : qword = read_mm(dst);
      write_mm(dst, (d[63..56] - s[63..56]) @ (d[55..48] - s[55..48]) @
                     (d[47..40] - s[47..40]) @ (d[39..32] - s[39..32]) @
                     (d[31..24] - s[31..24]) @ (d[23..16] - s[23..16]) @
                     (d[15..8]  - s[15..8])  @ (d[7..0]   - s[7..0]));
      mmx_touch()
    },

    // 0F F9: PSUBW mm, mm/m64
    249 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_reg(modrm);
      let src = decode_rm(modrm, pfx);
      let s : qword = mmx_read_rm(modrm, src);
      let d : qword = read_mm(dst);
      write_mm(dst, (d[63..48] - s[63..48]) @ (d[47..32] - s[47..32]) @
                     (d[31..16] - s[31..16]) @ (d[15..0]  - s[15..0]));
      mmx_touch()
    },

    // 0F FA: PSUBD mm, mm/m64
    250 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_reg(modrm);
      let src = decode_rm(modrm, pfx);
      let s : qword = mmx_read_rm(modrm, src);
      let d : qword = read_mm(dst);
      write_mm(dst, (d[63..32] - s[63..32]) @ (d[31..0] - s[31..0]));
      mmx_touch()
    },

    // 0F FB: PSUBQ mm, mm/m64
    251 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_reg(modrm);
      let src = decode_rm(modrm, pfx);
      let s : qword = mmx_read_rm(modrm, src);
      let d : qword = read_mm(dst);
      write_mm(dst, d - s);
      mmx_touch()
    },

    // 0F FC: PADDB mm, mm/m64
    252 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_reg(modrm);
      let src = decode_rm(modrm, pfx);
      let s : qword = mmx_read_rm(modrm, src);
      let d : qword = read_mm(dst);
      write_mm(dst, (d[63..56] + s[63..56]) @ (d[55..48] + s[55..48]) @
                     (d[47..40] + s[47..40]) @ (d[39..32] + s[39..32]) @
                     (d[31..24] + s[31..24]) @ (d[23..16] + s[23..16]) @
                     (d[15..8]  + s[15..8])  @ (d[7..0]   + s[7..0]));
      mmx_touch()
    },

    // 0F FD: PADDW mm, mm/m64
    253 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_reg(modrm);
      let src = decode_rm(modrm, pfx);
      let s : qword = mmx_read_rm(modrm, src);
      let d : qword = read_mm(dst);
      write_mm(dst, (d[63..48] + s[63..48]) @ (d[47..32] + s[47..32]) @
                     (d[31..16] + s[31..16]) @ (d[15..0]  + s[15..0]));
      mmx_touch()
    },

    // 0F FE: PADDD mm, mm/m64
    254 => {
      let modrm = fetch_byte();
      let dst = modrm_mm_reg(modrm);
      let src = decode_rm(modrm, pfx);
      let s : qword = mmx_read_rm(modrm, src);
      let d : qword = read_mm(dst);
      write_mm(dst, (d[63..32] + s[63..32]) @ (d[31..0] + s[31..0]));
      mmx_touch()
    },

    _ => raise_UD(),
  }
}

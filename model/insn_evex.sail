// x86-64 Decoder — EVEX Prefix Decoding and Dispatch
//
// Handles 4-byte EVEX prefix (62h) for AVX-512 instructions.
//
// EVEX format:
//   Byte 0: 62h (already consumed by caller)
//   Byte 1 (P0): [R̄][X̄][B̄][R'̄][0][mm]   (mm: opcode map)
//   Byte 2 (P1): [W][v̄v̄v̄v̄][1][pp]        (pp: mandatory prefix)
//   Byte 3 (P2): [z][L'L][b][V'̄][aaa]     (masking, length, broadcast)
//
// Register encoding (5 bits = 32 registers):
//   reg field:  EVEX.R' : EVEX.R : modrm.reg  (destination)
//   vvvvv:      EVEX.V' : EVEX.vvvv           (source 2)
//   r/m field:  EVEX.X : EVEX.B : modrm.rm    (source, reg only; for mem B extends base)

// Decode EVEX prefix (62h already consumed). Reads 3 payload bytes.
// Returns (Prefixes, opcode_map) where map is mm field (1=0F, 2=0F38, 3=0F3A).
val decode_evex : unit -> (Prefixes, range(0, 3))
function decode_evex() = {
  let p0 = fetch_byte();
  let p1 = fetch_byte();
  let p2 = fetch_byte();

  let mm : range(0, 3) = unsigned(p0[1..0]);
  let pfx = {default_prefixes() with
    evex_present = true,
    has_rex = true,
    // P0: R̄, X̄, B̄ (inverted), R'̄ (inverted)
    rex_r  = not_bool(p0[7] == bitone),
    rex_x  = not_bool(p0[6] == bitone),
    rex_b  = not_bool(p0[5] == bitone),
    evex_rr = not_bool(p0[4] == bitone),
    // P1: W, vvvv (inverted), pp
    rex_w  = p1[7] == bitone,
    vex_w  = p1[7] == bitone,
    evex_vvvvv = {
      let vprime : range(0, 1) = if p2[3] == bitone then 0 else 1;
      let vvvv : range(0, 15) = unsigned(~(p1[6..3]));
      vprime * 16 + vvvv
    },
    // pp → mandatory prefix flags
    has_opsize = p1[1..0] == 0b01,
    has_rep    = p1[1..0] == 0b10,
    has_repne  = p1[1..0] == 0b11,
    // P2: z, L'L, b, V', aaa
    evex_z   = p2[7] == bitone,
    evex_ll  = unsigned(p2[6..5]),
    evex_b   = p2[4] == bitone,
    evex_aaa = unsigned(p2[2..0]),
    // Also populate VEX fields for compatibility
    vex_present = true,
  };
  (pfx, mm)
}

// Compute 5-bit destination register index from EVEX R' : R : modrm.reg
val evex_reg_idx : (byte, Prefixes) -> simd_idx
function evex_reg_idx(modrm, pfx) = {
  let base : range(0, 7) = unsigned(modrm[5..3]);
  let r_ext : range(0, 1) = if pfx.rex_r then 1 else 0;
  let rr_ext : range(0, 1) = if pfx.evex_rr then 1 else 0;
  // 5-bit index: R' : R : reg[2:0]
  rr_ext * 16 + r_ext * 8 + base
}

// Compute 5-bit r/m register index (for register operands only).
// For memory operands, B extends the base register (4 bits, not 5).
val evex_rm_reg_idx : (byte, Prefixes) -> simd_idx
function evex_rm_reg_idx(modrm, pfx) = {
  let base : range(0, 7) = unsigned(modrm[2..0]);
  let b_ext : range(0, 1) = if pfx.rex_b then 1 else 0;
  let x_ext : range(0, 1) = if pfx.rex_x then 1 else 0;
  // 5-bit index: X : B : rm[2:0]
  x_ext * 16 + b_ext * 8 + base
}

// Get the effective opmask value for writemask application.
// aaa=0 means no masking (all bits set). Otherwise read the mask register.
val evex_get_mask16 : Prefixes -> word
function evex_get_mask16(pfx) =
  if pfx.evex_aaa == 0 then ones()
  else read_kreg(pfx.evex_aaa)[15..0]

val evex_get_mask8 : Prefixes -> byte
function evex_get_mask8(pfx) =
  if pfx.evex_aaa == 0 then ones()
  else read_kreg(pfx.evex_aaa)[7..0]

// Read ZMM source from r/m field: register or memory.
val evex_src_zmm : (byte, RM, Prefixes) -> zmmword
function evex_src_zmm(modrm, rm, pfx) = match rm {
  RM_reg(_) => read_zmm(evex_rm_reg_idx(modrm, pfx)),
  RM_mem(addr) => mem_read512(fixup_addr(addr)),
}

val evex_src_ymm : (byte, RM, Prefixes) -> ymmword
function evex_src_ymm(modrm, rm, pfx) = match rm {
  RM_reg(_) => read_ymm(evex_rm_reg_idx(modrm, pfx)),
  RM_mem(addr) => mem_read256(fixup_addr(addr)),
}

val evex_src_xmm : (byte, RM, Prefixes) -> xmmword
function evex_src_xmm(modrm, rm, pfx) = match rm {
  RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx)),
  RM_mem(addr) => mem_read128(fixup_addr(addr)),
}

// Read a 32-bit value from r/m for broadcast.
val evex_src_m32 : (byte, RM, Prefixes) -> dword
function evex_src_m32(modrm, rm, pfx) = match rm {
  RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
  RM_mem(addr) => mem_read32(fixup_addr(addr)),
}

// Read a 64-bit value from r/m for broadcast.
val evex_src_m64 : (byte, RM, Prefixes) -> qword
function evex_src_m64(modrm, rm, pfx) = match rm {
  RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
  RM_mem(addr) => mem_read64(fixup_addr(addr)),
}

// =========================================================================
// EVEX 0F map dispatch (AVX-512 versions of SSE/AVX instructions)
// =========================================================================

val dispatch_evex_0f : (byte, Prefixes) -> ExecutionResult
function dispatch_evex_0f(opcode, pfx) = {
  let op : range(0, 255) = unsigned(opcode);
  let mp = get_mandatory_prefix(pfx);

  match op {

  // 0F 10: VMOVUPS/VMOVUPD (EVEX load)
  16 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
    match mp {
      MP_NONE => { // VMOVUPS
        match pfx.evex_ll {
          2 => {
            let src : zmmword = if pfx.evex_b & is_mem
              then broadcast_f32_zmm(evex_src_m32(modrm, rm, pfx))
              else evex_src_zmm(modrm, rm, pfx);
            let masked = apply_writemask_ps_zmm(src, read_zmm(dst), evex_get_mask16(pfx), pfx.evex_z);
            write_zmm(dst, masked); Ok(())
          },
          1 => {
            let src = evex_src_ymm(modrm, rm, pfx);
            write_ymm(dst, src); Ok(())
          },
          _ => {
            let src = evex_src_xmm(modrm, rm, pfx);
            write_xmm(dst, src); Ok(())
          },
        }
      },
      MP_66 => { // VMOVUPD
        match pfx.evex_ll {
          2 => {
            let src : zmmword = if pfx.evex_b & is_mem
              then broadcast_f64_zmm(evex_src_m64(modrm, rm, pfx))
              else evex_src_zmm(modrm, rm, pfx);
            let masked = apply_writemask_pd_zmm(src, read_zmm(dst), evex_get_mask8(pfx), pfx.evex_z);
            write_zmm(dst, masked); Ok(())
          },
          1 => {
            let src = evex_src_ymm(modrm, rm, pfx);
            write_ymm(dst, src); Ok(())
          },
          _ => {
            let src = evex_src_xmm(modrm, rm, pfx);
            write_xmm(dst, src); Ok(())
          },
        }
      },
      _ => raise_UD(),
    }
  },

  // 0F 11: VMOVUPS/VMOVUPD (EVEX store)
  17 => {
    let modrm = fetch_byte();
    let src = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    match mp {
      MP_NONE => // VMOVUPS store
        match rm {
          RM_reg(_) => {
            let dst = evex_rm_reg_idx(modrm, pfx);
            match pfx.evex_ll {
              2 => {
                let masked = apply_writemask_ps_zmm(read_zmm(src), read_zmm(dst), evex_get_mask16(pfx), pfx.evex_z);
                write_zmm(dst, masked); Ok(())
              },
              1 => { write_ymm(dst, read_ymm(src)); Ok(()) },
              _ => { write_xmm(dst, read_xmm(src)); Ok(()) },
            }
          },
          RM_mem(addr) => {
            let a = fixup_addr(addr);
            match pfx.evex_ll {
              2 => { mem_write512(a, read_zmm(src)); Ok(()) },
              1 => { mem_write256(a, read_ymm(src)); Ok(()) },
              _ => { mem_write128(a, read_xmm(src)); Ok(()) },
            }
          },
        },
      MP_66 => // VMOVUPD store
        match rm {
          RM_reg(_) => {
            let dst = evex_rm_reg_idx(modrm, pfx);
            match pfx.evex_ll {
              2 => {
                let masked = apply_writemask_pd_zmm(read_zmm(src), read_zmm(dst), evex_get_mask8(pfx), pfx.evex_z);
                write_zmm(dst, masked); Ok(())
              },
              1 => { write_ymm(dst, read_ymm(src)); Ok(()) },
              _ => { write_xmm(dst, read_xmm(src)); Ok(()) },
            }
          },
          RM_mem(addr) => {
            let a = fixup_addr(addr);
            match pfx.evex_ll {
              2 => { mem_write512(a, read_zmm(src)); Ok(()) },
              1 => { mem_write256(a, read_ymm(src)); Ok(()) },
              _ => { mem_write128(a, read_xmm(src)); Ok(()) },
            }
          },
        },
      _ => raise_UD(),
    }
  },

  // 0F 12: VMOVLPS (NP,mem) / VMOVHLPS (NP,reg) / VMOVLPD (66,mem) / VMOVSLDUP (F3) / VMOVDDUP (F2)
  18 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    match mp {
      MP_NONE => { // VMOVLPS (mem) or VMOVHLPS (reg) — XMM only
        if pfx.evex_ll != 0 then raise_UD()
        else {
          let rm = decode_rm_evex(modrm, pfx, 8);
          match rm {
            RM_reg(_) => { // VMOVHLPS xmm1, xmm2, xmm3
              let src1 = read_xmm(pfx.evex_vvvvv);
              let src2 = read_xmm(evex_rm_reg_idx(modrm, pfx));
              let result : xmmword = src1[127..64] @ src2[127..64];
              write_xmm(dst, result); Ok(())
            },
            RM_mem(addr) => { // VMOVLPS xmm2, xmm1, m64
              let src1 = read_xmm(pfx.evex_vvvvv);
              let m64val = mem_read64(fixup_addr(addr));
              let result : xmmword = src1[127..64] @ m64val;
              write_xmm(dst, result); Ok(())
            },
          }
        }
      },
      MP_66 => { // VMOVLPD xmm2, xmm1, m64 — XMM only
        if pfx.evex_ll != 0 then raise_UD()
        else {
          let rm = decode_rm_evex(modrm, pfx, 8);
          match rm {
            RM_reg(_) => raise_UD(),
            RM_mem(addr) => {
              let src1 = read_xmm(pfx.evex_vvvvv);
              let m64val = mem_read64(fixup_addr(addr));
              let result : xmmword = src1[127..64] @ m64val;
              write_xmm(dst, result); Ok(())
            },
          }
        }
      },
      MP_F3 => { // VMOVSLDUP
        let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_movsldup_512(evex_src_zmm(modrm, rm, pfx))); Ok(()) },
          1 => { write_ymm(dst, avx_movsldup_256(evex_src_ymm(modrm, rm, pfx))); Ok(()) },
          _ => { write_xmm(dst, avx_movsldup_128(evex_src_xmm(modrm, rm, pfx))); Ok(()) },
        }
      },
      MP_F2 => { // VMOVDDUP
        let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_movddup_512(evex_src_zmm(modrm, rm, pfx))); Ok(()) },
          1 => { write_ymm(dst, avx_movddup_256(evex_src_ymm(modrm, rm, pfx))); Ok(()) },
          _ => {
            // 128-bit MOVDDUP: source is xmm or m64
            let src : xmmword = match rm {
              RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx)),
              RM_mem(addr) => {
                let v = mem_read64(fixup_addr(addr));
                v @ v
              },
            };
            write_xmm(dst, avx_movddup_128(src)); Ok(())
          },
        }
      },
    }
  },

  // 0F 13: VMOVLPS (NP,store) / VMOVLPD (66,store) — XMM only, m64
  19 => {
    let modrm = fetch_byte();
    if pfx.evex_ll != 0 then raise_UD()
    else {
      let rm = decode_rm_evex(modrm, pfx, 8);
      match rm {
        RM_reg(_) => raise_UD(),
        RM_mem(addr) => {
          let src = read_xmm(evex_reg_idx(modrm, pfx));
          mem_write64(fixup_addr(addr), src[63..0]); Ok(())
        },
      }
    }
  },

  // 0F 14: VUNPCKLPS (NP,W0) / VUNPCKLPD (66,W1)
  20 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
    let src1_idx = pfx.evex_vvvvv;
    match mp {
      MP_NONE => { // VUNPCKLPS (W0)
        match pfx.evex_ll {
          2 => {
            let src1 = read_zmm(src1_idx);
            let src2 : zmmword = if pfx.evex_b & is_mem
              then broadcast_f32_zmm(evex_src_m32(modrm, rm, pfx))
              else evex_src_zmm(modrm, rm, pfx);
            write_zmm(dst, avx_unpcklps_512(src1, src2)); Ok(())
          },
          1 => {
            let src1 = read_ymm(src1_idx);
            let src2 = evex_src_ymm(modrm, rm, pfx);
            write_ymm(dst, avx_unpcklps_256(src1, src2)); Ok(())
          },
          _ => {
            let src1 = read_xmm(src1_idx);
            let src2 = evex_src_xmm(modrm, rm, pfx);
            write_xmm(dst, avx_unpcklps_128(src1, src2)); Ok(())
          },
        }
      },
      MP_66 => { // VUNPCKLPD (W1)
        match pfx.evex_ll {
          2 => {
            let src1 = read_zmm(src1_idx);
            let src2 : zmmword = if pfx.evex_b & is_mem
              then broadcast_f64_zmm(evex_src_m64(modrm, rm, pfx))
              else evex_src_zmm(modrm, rm, pfx);
            write_zmm(dst, avx_unpcklpd_512(src1, src2)); Ok(())
          },
          1 => {
            let src1 = read_ymm(src1_idx);
            let src2 = evex_src_ymm(modrm, rm, pfx);
            write_ymm(dst, avx_unpcklpd_256(src1, src2)); Ok(())
          },
          _ => {
            let src1 = read_xmm(src1_idx);
            let src2 = evex_src_xmm(modrm, rm, pfx);
            write_xmm(dst, avx_unpcklpd_128(src1, src2)); Ok(())
          },
        }
      },
      _ => raise_UD(),
    }
  },

  // 0F 15: VUNPCKHPS (NP,W0) / VUNPCKHPD (66,W1)
  21 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
    let src1_idx = pfx.evex_vvvvv;
    match mp {
      MP_NONE => { // VUNPCKHPS (W0)
        match pfx.evex_ll {
          2 => {
            let src1 = read_zmm(src1_idx);
            let src2 : zmmword = if pfx.evex_b & is_mem
              then broadcast_f32_zmm(evex_src_m32(modrm, rm, pfx))
              else evex_src_zmm(modrm, rm, pfx);
            write_zmm(dst, avx_unpckhps_512(src1, src2)); Ok(())
          },
          1 => {
            let src1 = read_ymm(src1_idx);
            let src2 = evex_src_ymm(modrm, rm, pfx);
            write_ymm(dst, avx_unpckhps_256(src1, src2)); Ok(())
          },
          _ => {
            let src1 = read_xmm(src1_idx);
            let src2 = evex_src_xmm(modrm, rm, pfx);
            write_xmm(dst, avx_unpckhps_128(src1, src2)); Ok(())
          },
        }
      },
      MP_66 => { // VUNPCKHPD (W1)
        match pfx.evex_ll {
          2 => {
            let src1 = read_zmm(src1_idx);
            let src2 : zmmword = if pfx.evex_b & is_mem
              then broadcast_f64_zmm(evex_src_m64(modrm, rm, pfx))
              else evex_src_zmm(modrm, rm, pfx);
            write_zmm(dst, avx_unpckhpd_512(src1, src2)); Ok(())
          },
          1 => {
            let src1 = read_ymm(src1_idx);
            let src2 = evex_src_ymm(modrm, rm, pfx);
            write_ymm(dst, avx_unpckhpd_256(src1, src2)); Ok(())
          },
          _ => {
            let src1 = read_xmm(src1_idx);
            let src2 = evex_src_xmm(modrm, rm, pfx);
            write_xmm(dst, avx_unpckhpd_128(src1, src2)); Ok(())
          },
        }
      },
      _ => raise_UD(),
    }
  },

  // 0F 16: VMOVHPS (NP,mem) / VMOVLHPS (NP,reg) / VMOVHPD (66,mem) / VMOVSHDUP (F3)
  22 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    match mp {
      MP_NONE => { // VMOVHPS (mem) or VMOVLHPS (reg) — XMM only
        if pfx.evex_ll != 0 then raise_UD()
        else {
          let rm = decode_rm_evex(modrm, pfx, 8);
          match rm {
            RM_reg(_) => { // VMOVLHPS xmm1, xmm2, xmm3
              let src1 = read_xmm(pfx.evex_vvvvv);
              let src2 = read_xmm(evex_rm_reg_idx(modrm, pfx));
              let result : xmmword = src2[63..0] @ src1[63..0];
              write_xmm(dst, result); Ok(())
            },
            RM_mem(addr) => { // VMOVHPS xmm2, xmm1, m64
              let src1 = read_xmm(pfx.evex_vvvvv);
              let m64val = mem_read64(fixup_addr(addr));
              let result : xmmword = m64val @ src1[63..0];
              write_xmm(dst, result); Ok(())
            },
          }
        }
      },
      MP_66 => { // VMOVHPD xmm2, xmm1, m64 — XMM only
        if pfx.evex_ll != 0 then raise_UD()
        else {
          let rm = decode_rm_evex(modrm, pfx, 8);
          match rm {
            RM_reg(_) => raise_UD(),
            RM_mem(addr) => {
              let src1 = read_xmm(pfx.evex_vvvvv);
              let m64val = mem_read64(fixup_addr(addr));
              let result : xmmword = m64val @ src1[63..0];
              write_xmm(dst, result); Ok(())
            },
          }
        }
      },
      MP_F3 => { // VMOVSHDUP
        let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_movshdup_512(evex_src_zmm(modrm, rm, pfx))); Ok(()) },
          1 => { write_ymm(dst, avx_movshdup_256(evex_src_ymm(modrm, rm, pfx))); Ok(()) },
          _ => { write_xmm(dst, avx_movshdup_128(evex_src_xmm(modrm, rm, pfx))); Ok(()) },
        }
      },
      _ => raise_UD(),
    }
  },

  // 0F 17: VMOVHPS (NP,store) / VMOVHPD (66,store) — XMM only, m64
  23 => {
    let modrm = fetch_byte();
    if pfx.evex_ll != 0 then raise_UD()
    else {
      let rm = decode_rm_evex(modrm, pfx, 8);
      match rm {
        RM_reg(_) => raise_UD(),
        RM_mem(addr) => {
          let src = read_xmm(evex_reg_idx(modrm, pfx));
          mem_write64(fixup_addr(addr), src[127..64]); Ok(())
        },
      }
    }
  },

  // 0F 28: VMOVAPS/VMOVAPD (EVEX load)
  40 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    match pfx.evex_ll {
      2 => {
        let src = evex_src_zmm(modrm, rm, pfx);
        let mask_val = if mp == MP_66 then evex_get_mask8(pfx) @ evex_get_mask8(pfx) else evex_get_mask16(pfx);
        if mp == MP_66 then {
          let masked = apply_writemask_pd_zmm(src, read_zmm(dst), evex_get_mask8(pfx), pfx.evex_z);
          write_zmm(dst, masked); Ok(())
        } else {
          let masked = apply_writemask_ps_zmm(src, read_zmm(dst), evex_get_mask16(pfx), pfx.evex_z);
          write_zmm(dst, masked); Ok(())
        }
      },
      1 => { write_ymm(dst, evex_src_ymm(modrm, rm, pfx)); Ok(()) },
      _ => { write_xmm(dst, evex_src_xmm(modrm, rm, pfx)); Ok(()) },
    }
  },

  // 0F 29: VMOVAPS/VMOVAPD (EVEX store)
  41 => {
    let modrm = fetch_byte();
    let src = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    match rm {
      RM_reg(_) => {
        let dst = evex_rm_reg_idx(modrm, pfx);
        match pfx.evex_ll {
          2 => { write_zmm(dst, read_zmm(src)); Ok(()) },
          1 => { write_ymm(dst, read_ymm(src)); Ok(()) },
          _ => { write_xmm(dst, read_xmm(src)); Ok(()) },
        }
      },
      RM_mem(addr) => {
        let a = fixup_addr(addr);
        match pfx.evex_ll {
          2 => { mem_write512(a, read_zmm(src)); Ok(()) },
          1 => { mem_write256(a, read_ymm(src)); Ok(()) },
          _ => { mem_write128(a, read_xmm(src)); Ok(()) },
        }
      },
    }
  },

  // 0F 2A: VCVTSI2SS (F3) / VCVTSI2SD (F2) — scalar, GPR/mem to XMM
  42 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
    let os : OperandSize = if pfx.rex_w then OS64 else OS32;
    let src_val : qword = match rm {
      RM_reg(_) => read_gpr(modrm_rm_reg(modrm, pfx), os),
      RM_mem(addr) => match os {
        OS64 => mem_read64(fixup_addr(addr)),
        _    => zero_extend(mem_read32(fixup_addr(addr))),
      },
    };
    let src1 = read_xmm(pfx.evex_vvvvv);
    match mp {
      MP_F3 => { // VCVTSI2SS
        let result : dword = match os {
          OS64 => __int64_to_f32(src_val),
          _    => __int32_to_f32(src_val[31..0]),
        };
        var xmm : xmmword = src1;
        xmm[31..0] = result;
        write_xmm(dst, xmm); Ok(())
      },
      MP_F2 => { // VCVTSI2SD
        let result : qword = match os {
          OS64 => __int64_to_f64(src_val),
          _    => __int32_to_f64(src_val[31..0]),
        };
        var xmm : xmmword = src1;
        xmm[63..0] = result;
        write_xmm(dst, xmm); Ok(())
      },
      _ => raise_UD(),
    }
  },

  // 0F 2B: VMOVNTPS (NP) / VMOVNTPD (66) — non-temporal store
  43 => {
    let modrm = fetch_byte();
    let src = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    match rm {
      RM_reg(_) => raise_UD(),
      RM_mem(addr) => {
        let a = fixup_addr(addr);
        match pfx.evex_ll {
          2 => { mem_write512(a, read_zmm(src)); Ok(()) },
          1 => { mem_write256(a, read_ymm(src)); Ok(()) },
          _ => { mem_write128(a, read_xmm(src)); Ok(()) },
        }
      },
    }
  },

  // 0F 2C: VCVTTSS2SI (F3) / VCVTTSD2SI (F2) — scalar, XMM/mem to GPR (truncate)
  44 => {
    let modrm = fetch_byte();
    let dst_gpr = modrm_reg(modrm, pfx);
    let os : OperandSize = if pfx.rex_w then OS64 else OS32;
    match mp {
      MP_F3 => { // VCVTTSS2SI
        let rm = decode_rm_evex(modrm, pfx, 4);
        let src_f32 : dword = match rm {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
          RM_mem(addr) => mem_read32(fixup_addr(addr)),
        };
        match os {
          OS64 => write_gpr(dst_gpr, OS64, __f32_to_int64_trunc(src_f32)),
          _    => write_gpr(dst_gpr, OS32, zero_extend(__f32_to_int32_trunc(src_f32))),
        };
        Ok(())
      },
      MP_F2 => { // VCVTTSD2SI
        let rm = decode_rm_evex(modrm, pfx, 8);
        let src_f64 : qword = match rm {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
          RM_mem(addr) => mem_read64(fixup_addr(addr)),
        };
        match os {
          OS64 => write_gpr(dst_gpr, OS64, __f64_to_int64_trunc(src_f64)),
          _    => write_gpr(dst_gpr, OS32, zero_extend(__f64_to_int32_trunc(src_f64))),
        };
        Ok(())
      },
      _ => raise_UD(),
    }
  },

  // 0F 2D: VCVTSS2SI (F3) / VCVTSD2SI (F2) — scalar, XMM/mem to GPR (round)
  45 => {
    let modrm = fetch_byte();
    let dst_gpr = modrm_reg(modrm, pfx);
    let os : OperandSize = if pfx.rex_w then OS64 else OS32;
    match mp {
      MP_F3 => { // VCVTSS2SI
        let rm = decode_rm_evex(modrm, pfx, 4);
        let src_f32 : dword = match rm {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
          RM_mem(addr) => mem_read32(fixup_addr(addr)),
        };
        match os {
          OS64 => write_gpr(dst_gpr, OS64, __f32_to_int64(src_f32)),
          _    => write_gpr(dst_gpr, OS32, zero_extend(__f32_to_int32(src_f32))),
        };
        Ok(())
      },
      MP_F2 => { // VCVTSD2SI
        let rm = decode_rm_evex(modrm, pfx, 8);
        let src_f64 : qword = match rm {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
          RM_mem(addr) => mem_read64(fixup_addr(addr)),
        };
        match os {
          OS64 => write_gpr(dst_gpr, OS64, __f64_to_int64(src_f64)),
          _    => write_gpr(dst_gpr, OS32, zero_extend(__f64_to_int32(src_f64))),
        };
        Ok(())
      },
      _ => raise_UD(),
    }
  },

  // 0F 2E: VUCOMISS (NP,W0) / VUCOMISD (66,W1) — compare scalars, set EFLAGS
  46 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    match mp {
      MP_NONE => { // VUCOMISS
        let rm = decode_rm_evex(modrm, pfx, 4);
        let src : xmmword = match rm {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx)),
          RM_mem(addr) => zero_extend(mem_read32(fixup_addr(addr))),
        };
        let a : dword = read_xmm(dst)[31..0];
        let b : dword = src[31..0];
        match __compare_ss(a, b) {
          FP_UNORDERED => { ZF = bitone;  PF = bitone;  CF = bitone;  },
          FP_GT        => { ZF = bitzero; PF = bitzero; CF = bitzero; },
          FP_LT        => { ZF = bitzero; PF = bitzero; CF = bitone;  },
          FP_EQ        => { ZF = bitone;  PF = bitzero; CF = bitzero; },
        };
        OF = bitzero; SF = bitzero; AF = bitzero;
        Ok(())
      },
      MP_66 => { // VUCOMISD
        let rm = decode_rm_evex(modrm, pfx, 8);
        let src : xmmword = match rm {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx)),
          RM_mem(addr) => zero_extend(mem_read64(fixup_addr(addr))),
        };
        let a : qword = read_xmm(dst)[63..0];
        let b : qword = src[63..0];
        match __compare_sd(a, b) {
          FP_UNORDERED => { ZF = bitone;  PF = bitone;  CF = bitone;  },
          FP_GT        => { ZF = bitzero; PF = bitzero; CF = bitzero; },
          FP_LT        => { ZF = bitzero; PF = bitzero; CF = bitone;  },
          FP_EQ        => { ZF = bitone;  PF = bitzero; CF = bitzero; },
        };
        OF = bitzero; SF = bitzero; AF = bitzero;
        Ok(())
      },
      _ => raise_UD(),
    }
  },

  // 0F 2F: VCOMISS (NP,W0) / VCOMISD (66,W1) — ordered compare scalars, set EFLAGS
  47 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    match mp {
      MP_NONE => { // VCOMISS
        let rm = decode_rm_evex(modrm, pfx, 4);
        let src : xmmword = match rm {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx)),
          RM_mem(addr) => zero_extend(mem_read32(fixup_addr(addr))),
        };
        let a : dword = read_xmm(dst)[31..0];
        let b : dword = src[31..0];
        match __compare_ss(a, b) {
          FP_UNORDERED => { ZF = bitone;  PF = bitone;  CF = bitone;  },
          FP_GT        => { ZF = bitzero; PF = bitzero; CF = bitzero; },
          FP_LT        => { ZF = bitzero; PF = bitzero; CF = bitone;  },
          FP_EQ        => { ZF = bitone;  PF = bitzero; CF = bitzero; },
        };
        OF = bitzero; SF = bitzero; AF = bitzero;
        Ok(())
      },
      MP_66 => { // VCOMISD
        let rm = decode_rm_evex(modrm, pfx, 8);
        let src : xmmword = match rm {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx)),
          RM_mem(addr) => zero_extend(mem_read64(fixup_addr(addr))),
        };
        let a : qword = read_xmm(dst)[63..0];
        let b : qword = src[63..0];
        match __compare_sd(a, b) {
          FP_UNORDERED => { ZF = bitone;  PF = bitone;  CF = bitone;  },
          FP_GT        => { ZF = bitzero; PF = bitzero; CF = bitzero; },
          FP_LT        => { ZF = bitzero; PF = bitzero; CF = bitone;  },
          FP_EQ        => { ZF = bitone;  PF = bitzero; CF = bitzero; },
        };
        OF = bitzero; SF = bitzero; AF = bitzero;
        Ok(())
      },
      _ => raise_UD(),
    }
  },

  // 0F 58: VADDPS/VADDPD (EVEX, 512-bit)
  88 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
    match mp {
      MP_NONE => { // VADDPS
        match pfx.evex_ll {
          2 => {
            let src1 : zmmword = read_zmm(pfx.evex_vvvvv);
            let src2 : zmmword = if pfx.evex_b & is_mem
              then broadcast_f32_zmm(evex_src_m32(modrm, rm, pfx))
              else evex_src_zmm(modrm, rm, pfx);
            let result = vaddps_zmm(src1, src2);
            let masked = apply_writemask_ps_zmm(result, read_zmm(dst), evex_get_mask16(pfx), pfx.evex_z);
            write_zmm(dst, masked); Ok(())
          },
          1 => {
            let src1 = read_ymm(pfx.evex_vvvvv);
            let src2 = evex_src_ymm(modrm, rm, pfx);
            write_ymm(dst, vaddps_ymm(src1, src2)); Ok(())
          },
          _ => {
            let src1 = read_xmm(pfx.evex_vvvvv);
            let src2 = evex_src_xmm(modrm, rm, pfx);
            write_xmm(dst, vaddps_xmm(src1, src2)); Ok(())
          },
        }
      },
      MP_66 => { // VADDPD
        match pfx.evex_ll {
          2 => {
            let src1 : zmmword = read_zmm(pfx.evex_vvvvv);
            let src2 : zmmword = if pfx.evex_b & is_mem
              then broadcast_f64_zmm(evex_src_m64(modrm, rm, pfx))
              else evex_src_zmm(modrm, rm, pfx);
            let result = vaddpd_zmm(src1, src2);
            let masked = apply_writemask_pd_zmm(result, read_zmm(dst), evex_get_mask8(pfx), pfx.evex_z);
            write_zmm(dst, masked); Ok(())
          },
          1 => {
            let src1 = read_ymm(pfx.evex_vvvvv);
            let src2 = evex_src_ymm(modrm, rm, pfx);
            write_ymm(dst, vaddpd_ymm(src1, src2)); Ok(())
          },
          _ => {
            let src1 = read_xmm(pfx.evex_vvvvv);
            let src2 = evex_src_xmm(modrm, rm, pfx);
            write_xmm(dst, vaddpd_xmm(src1, src2)); Ok(())
          },
        }
      },
      _ => raise_UD(),
    }
  },

  // 0F 59: VMULPS/VMULPD (EVEX)
  89 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
    match mp {
      MP_NONE => match pfx.evex_ll {
        2 => {
          let src1 : zmmword = read_zmm(pfx.evex_vvvvv);
          let src2 : zmmword = if pfx.evex_b & is_mem
            then broadcast_f32_zmm(evex_src_m32(modrm, rm, pfx))
            else evex_src_zmm(modrm, rm, pfx);
          let result = vmulps_zmm(src1, src2);
          let masked = apply_writemask_ps_zmm(result, read_zmm(dst), evex_get_mask16(pfx), pfx.evex_z);
          write_zmm(dst, masked); Ok(())
        },
        1 => { write_ymm(dst, vmulps_ymm(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, vmulps_xmm(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      },
      MP_66 => match pfx.evex_ll {
        2 => {
          let src1 : zmmword = read_zmm(pfx.evex_vvvvv);
          let src2 : zmmword = if pfx.evex_b & is_mem
            then broadcast_f64_zmm(evex_src_m64(modrm, rm, pfx))
            else evex_src_zmm(modrm, rm, pfx);
          let result = vmulpd_zmm(src1, src2);
          let masked = apply_writemask_pd_zmm(result, read_zmm(dst), evex_get_mask8(pfx), pfx.evex_z);
          write_zmm(dst, masked); Ok(())
        },
        1 => { write_ymm(dst, vmulpd_ymm(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, vmulpd_xmm(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      },
      _ => raise_UD(),
    }
  },

  // 0F 5A: VCVTPS2PD (NP,W0) / VCVTPD2PS (66,W1) / VCVTSS2SD (F3) / VCVTSD2SS (F2)
  90 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    match mp {
      MP_NONE => { // VCVTPS2PD: f32→f64, source is half-width
        match pfx.evex_ll {
          2 => { // ZMM: 8 f32 (YMM) → 8 f64 (ZMM)
            let rm = decode_rm_evex(modrm, pfx, 32);
            let src = evex_src_ymm(modrm, rm, pfx);
            write_zmm(dst, avx_cvtps2pd_8(src)); Ok(())
          },
          1 => { // YMM: 4 f32 (XMM) → 4 f64 (YMM)
            let rm = decode_rm_evex(modrm, pfx, 16);
            let src = evex_src_xmm(modrm, rm, pfx);
            write_ymm(dst, avx_cvtps2pd_4(src)); Ok(())
          },
          _ => { // XMM: 2 f32 (m64/xmm low) → 2 f64 (XMM)
            let rm = decode_rm_evex(modrm, pfx, 8);
            let src : qword = match rm {
              RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
              RM_mem(addr) => mem_read64(fixup_addr(addr)),
            };
            write_xmm(dst, avx_cvtps2pd_2(src)); Ok(())
          },
        }
      },
      MP_66 => { // VCVTPD2PS: f64→f32, result is half-width
        match pfx.evex_ll {
          2 => { // ZMM→YMM: 8 f64 → 8 f32
            let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
            let src = evex_src_zmm(modrm, rm, pfx);
            write_ymm(dst, avx_cvtpd2ps_8(src)); Ok(())
          },
          1 => { // YMM→XMM: 4 f64 → 4 f32
            let rm = decode_rm_evex(modrm, pfx, 32);
            let src = evex_src_ymm(modrm, rm, pfx);
            write_xmm(dst, avx_cvtpd2ps_4(src)); Ok(())
          },
          _ => { // XMM→XMM low: 2 f64 → 2 f32
            let rm = decode_rm_evex(modrm, pfx, 16);
            let src = evex_src_xmm(modrm, rm, pfx);
            let result : qword = avx_cvtpd2ps_2(src);
            write_xmm(dst, zeros(64) @ result); Ok(())
          },
        }
      },
      MP_F3 => { // VCVTSS2SD: scalar f32→f64
        let rm = decode_rm_evex(modrm, pfx, 4);
        let src1 = read_xmm(pfx.evex_vvvvv);
        let src_f32 : dword = match rm {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
          RM_mem(addr) => mem_read32(fixup_addr(addr)),
        };
        var result : xmmword = src1;
        result[63..0] = __f32_to_f64(src_f32);
        write_xmm(dst, result); Ok(())
      },
      MP_F2 => { // VCVTSD2SS: scalar f64→f32
        let rm = decode_rm_evex(modrm, pfx, 8);
        let src1 = read_xmm(pfx.evex_vvvvv);
        let src_f64 : qword = match rm {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
          RM_mem(addr) => mem_read64(fixup_addr(addr)),
        };
        var result : xmmword = src1;
        result[31..0] = __f64_to_f32(src_f64);
        write_xmm(dst, result); Ok(())
      },
    }
  },

  // 0F 5B: VCVTDQ2PS (NP,W0) / VCVTPS2DQ (66,W0) / VCVTTPS2DQ (F3,W0)
  91 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    match mp {
      MP_NONE => { // VCVTDQ2PS
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_cvtdq2ps_512(evex_src_zmm(modrm, rm, pfx))); Ok(()) },
          1 => { write_ymm(dst, avx_cvtdq2ps_256(evex_src_ymm(modrm, rm, pfx))); Ok(()) },
          _ => { write_xmm(dst, avx_cvtdq2ps_128(evex_src_xmm(modrm, rm, pfx))); Ok(()) },
        }
      },
      MP_66 => { // VCVTPS2DQ
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_cvtps2dq_512(evex_src_zmm(modrm, rm, pfx))); Ok(()) },
          1 => { write_ymm(dst, avx_cvtps2dq_256(evex_src_ymm(modrm, rm, pfx))); Ok(()) },
          _ => { write_xmm(dst, avx_cvtps2dq_128(evex_src_xmm(modrm, rm, pfx))); Ok(()) },
        }
      },
      MP_F3 => { // VCVTTPS2DQ
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_cvttps2dq_512(evex_src_zmm(modrm, rm, pfx))); Ok(()) },
          1 => { write_ymm(dst, avx_cvttps2dq_256(evex_src_ymm(modrm, rm, pfx))); Ok(()) },
          _ => { write_xmm(dst, avx_cvttps2dq_128(evex_src_xmm(modrm, rm, pfx))); Ok(()) },
        }
      },
      _ => raise_UD(),
    }
  },

  // 0F 5C: VSUBPS/VSUBPD (EVEX)
  92 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
    match mp {
      MP_NONE => match pfx.evex_ll {
        2 => {
          let src1 : zmmword = read_zmm(pfx.evex_vvvvv);
          let src2 : zmmword = if pfx.evex_b & is_mem
            then broadcast_f32_zmm(evex_src_m32(modrm, rm, pfx))
            else evex_src_zmm(modrm, rm, pfx);
          let result = vsubps_zmm(src1, src2);
          let masked = apply_writemask_ps_zmm(result, read_zmm(dst), evex_get_mask16(pfx), pfx.evex_z);
          write_zmm(dst, masked); Ok(())
        },
        1 => { write_ymm(dst, vsubps_ymm(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, vsubps_xmm(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      },
      MP_66 => match pfx.evex_ll {
        2 => {
          let src1 : zmmword = read_zmm(pfx.evex_vvvvv);
          let src2 : zmmword = if pfx.evex_b & is_mem
            then broadcast_f64_zmm(evex_src_m64(modrm, rm, pfx))
            else evex_src_zmm(modrm, rm, pfx);
          let result = vsubpd_zmm(src1, src2);
          let masked = apply_writemask_pd_zmm(result, read_zmm(dst), evex_get_mask8(pfx), pfx.evex_z);
          write_zmm(dst, masked); Ok(())
        },
        1 => { write_ymm(dst, vsubpd_ymm(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, vsubpd_xmm(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      },
      _ => raise_UD(),
    }
  },

  // 0F 57: VXORPS / 0F 54: VANDPS / 0F 55: VANDNPS / 0F 56: VORPS (EVEX bitwise)
  op if 84 <= op & op <= 87 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    match pfx.evex_ll {
      2 => {
        let src1 : zmmword = read_zmm(pfx.evex_vvvvv);
        let src2 : zmmword = evex_src_zmm(modrm, rm, pfx);
        let result : zmmword = match op {
          84 => src1 & src2,
          85 => ~(src1) & src2,
          86 => src1 | src2,
          _  => xor_vec(src1, src2),
        };
        write_zmm(dst, result); Ok(())
      },
      1 => {
        let src1 : ymmword = read_ymm(pfx.evex_vvvvv);
        let src2 : ymmword = evex_src_ymm(modrm, rm, pfx);
        let result : ymmword = match op {
          84 => src1 & src2,
          85 => ~(src1) & src2,
          86 => src1 | src2,
          _  => xor_vec(src1, src2),
        };
        write_ymm(dst, result); Ok(())
      },
      _ => {
        let src1 : xmmword = read_xmm(pfx.evex_vvvvv);
        let src2 : xmmword = evex_src_xmm(modrm, rm, pfx);
        let result : xmmword = match op {
          84 => src1 & src2,
          85 => ~(src1) & src2,
          86 => src1 | src2,
          _  => xor_vec(src1, src2),
        };
        write_xmm(dst, result); Ok(())
      },
    }
  },

  // 0F 78: VCVTTPS2UDQ (NP,W0) / VCVTTPD2UDQ (NP,W1) / VCVTTSS2USI (F3) / VCVTTSD2USI (F2)
  //        / VCVTTPS2UQQ (66,W0) / VCVTTPD2UQQ (66,W1)
  120 => {
    let modrm = fetch_byte();
    match mp {
      MP_NONE => { // NP,W0=VCVTTPS2UDQ, NP,W1=VCVTTPD2UDQ
        let dst = evex_reg_idx(modrm, pfx);
        let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
        if pfx.rex_w then { // VCVTTPD2UDQ: f64→u32 trunc (narrowing)
          match pfx.evex_ll {
            2 => {
              let src = evex_src_zmm(modrm, rm, pfx);
              write_ymm(dst, avx_cvttpd2udq_8(src)); Ok(())
            },
            1 => {
              let src = evex_src_ymm(modrm, rm, pfx);
              write_xmm(dst, avx_cvttpd2udq_4(src)); Ok(())
            },
            _ => {
              let src = evex_src_xmm(modrm, rm, pfx);
              write_xmm(dst, zero_extend(avx_cvttpd2udq_2(src))); Ok(())
            },
          }
        } else { // VCVTTPS2UDQ: f32→u32 trunc
          match pfx.evex_ll {
            2 => { write_zmm(dst, avx_cvttps2udq_512(evex_src_zmm(modrm, rm, pfx))); Ok(()) },
            1 => { write_ymm(dst, avx_cvttps2udq_256(evex_src_ymm(modrm, rm, pfx))); Ok(()) },
            _ => { write_xmm(dst, avx_cvttps2udq_128(evex_src_xmm(modrm, rm, pfx))); Ok(()) },
          }
        }
      },
      MP_F3 => { // VCVTTSS2USI: scalar f32→unsigned GPR trunc
        let dst_gpr = modrm_rm_reg(modrm, pfx);
        let rm2 = decode_rm_evex(modrm, pfx, 4);
        let src_f32 : dword = match rm2 {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
          RM_mem(addr) => mem_read32(fixup_addr(addr)),
        };
        let os = if pfx.rex_w then OS64 else OS32;
        match os {
          OS64 => write_gpr(dst_gpr, OS64, __f32_to_uint64_trunc(src_f32)),
          _    => write_gpr(dst_gpr, OS32, zero_extend(__f32_to_uint32_trunc(src_f32))),
        };
        Ok(())
      },
      MP_F2 => { // VCVTTSD2USI: scalar f64→unsigned GPR trunc
        let dst_gpr = modrm_rm_reg(modrm, pfx);
        let rm2 = decode_rm_evex(modrm, pfx, 8);
        let src_f64 : qword = match rm2 {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
          RM_mem(addr) => mem_read64(fixup_addr(addr)),
        };
        let os = if pfx.rex_w then OS64 else OS32;
        match os {
          OS64 => write_gpr(dst_gpr, OS64, __f64_to_uint64_trunc(src_f64)),
          _    => write_gpr(dst_gpr, OS32, zero_extend(__f64_to_uint32_trunc(src_f64))),
        };
        Ok(())
      },
      MP_66 => { // VCVTTPS2UQQ (W0) / VCVTTPD2UQQ (W1)
        let dst = evex_reg_idx(modrm, pfx);
        let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
        if pfx.rex_w then { // VCVTTPD2UQQ: f64→u64 trunc
          match pfx.evex_ll {
            2 => { write_zmm(dst, avx_cvttpd2uqq_512(evex_src_zmm(modrm, rm, pfx))); Ok(()) },
            1 => { write_ymm(dst, avx_cvttpd2uqq_256(evex_src_ymm(modrm, rm, pfx))); Ok(()) },
            _ => { write_xmm(dst, avx_cvttpd2uqq_128(evex_src_xmm(modrm, rm, pfx))); Ok(()) },
          }
        } else { // VCVTTPS2UQQ: f32→u64 trunc (widening)
          match pfx.evex_ll {
            2 => { write_zmm(dst, avx_cvttps2uqq_8(evex_src_ymm(modrm, rm, pfx))); Ok(()) },
            1 => { write_ymm(dst, avx_cvttps2uqq_4(evex_src_xmm(modrm, rm, pfx))); Ok(()) },
            _ => { write_xmm(dst, avx_cvttps2uqq_2(evex_src_xmm(modrm, rm, pfx)[63..0])); Ok(()) },
          }
        }
      },
    }
  },

  // 0F 79: VCVTPS2UDQ (NP,W0) / VCVTPD2UDQ (NP,W1) / VCVTSS2USI (F3) / VCVTSD2USI (F2)
  //        / VCVTPS2UQQ (66,W0) / VCVTPD2UQQ (66,W1)
  121 => {
    let modrm = fetch_byte();
    match mp {
      MP_NONE => { // NP,W0=VCVTPS2UDQ, NP,W1=VCVTPD2UDQ
        let dst = evex_reg_idx(modrm, pfx);
        let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
        if pfx.rex_w then { // VCVTPD2UDQ: f64→u32 round (narrowing)
          match pfx.evex_ll {
            2 => { write_ymm(dst, avx_cvtpd2udq_8(evex_src_zmm(modrm, rm, pfx))); Ok(()) },
            1 => { write_xmm(dst, avx_cvtpd2udq_4(evex_src_ymm(modrm, rm, pfx))); Ok(()) },
            _ => { write_xmm(dst, zero_extend(avx_cvtpd2udq_2(evex_src_xmm(modrm, rm, pfx)))); Ok(()) },
          }
        } else { // VCVTPS2UDQ: f32→u32 round
          match pfx.evex_ll {
            2 => { write_zmm(dst, avx_cvtps2udq_512(evex_src_zmm(modrm, rm, pfx))); Ok(()) },
            1 => { write_ymm(dst, avx_cvtps2udq_256(evex_src_ymm(modrm, rm, pfx))); Ok(()) },
            _ => { write_xmm(dst, avx_cvtps2udq_128(evex_src_xmm(modrm, rm, pfx))); Ok(()) },
          }
        }
      },
      MP_F3 => { // VCVTSS2USI: scalar f32→unsigned GPR round
        let dst_gpr = modrm_rm_reg(modrm, pfx);
        let rm2 = decode_rm_evex(modrm, pfx, 4);
        let src_f32 : dword = match rm2 {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
          RM_mem(addr) => mem_read32(fixup_addr(addr)),
        };
        let os = if pfx.rex_w then OS64 else OS32;
        match os {
          OS64 => write_gpr(dst_gpr, OS64, __f32_to_uint64(src_f32)),
          _    => write_gpr(dst_gpr, OS32, zero_extend(__f32_to_uint32(src_f32))),
        };
        Ok(())
      },
      MP_F2 => { // VCVTSD2USI: scalar f64→unsigned GPR round
        let dst_gpr = modrm_rm_reg(modrm, pfx);
        let rm2 = decode_rm_evex(modrm, pfx, 8);
        let src_f64 : qword = match rm2 {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
          RM_mem(addr) => mem_read64(fixup_addr(addr)),
        };
        let os = if pfx.rex_w then OS64 else OS32;
        match os {
          OS64 => write_gpr(dst_gpr, OS64, __f64_to_uint64(src_f64)),
          _    => write_gpr(dst_gpr, OS32, zero_extend(__f64_to_uint32(src_f64))),
        };
        Ok(())
      },
      MP_66 => { // VCVTPS2UQQ (W0) / VCVTPD2UQQ (W1)
        let dst = evex_reg_idx(modrm, pfx);
        let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
        if pfx.rex_w then { // VCVTPD2UQQ: f64→u64 round
          match pfx.evex_ll {
            2 => { write_zmm(dst, avx_cvtpd2uqq_512(evex_src_zmm(modrm, rm, pfx))); Ok(()) },
            1 => { write_ymm(dst, avx_cvtpd2uqq_256(evex_src_ymm(modrm, rm, pfx))); Ok(()) },
            _ => { write_xmm(dst, avx_cvtpd2uqq_128(evex_src_xmm(modrm, rm, pfx))); Ok(()) },
          }
        } else { // VCVTPS2UQQ: f32→u64 round (widening)
          match pfx.evex_ll {
            2 => { write_zmm(dst, avx_cvtps2uqq_8(evex_src_ymm(modrm, rm, pfx))); Ok(()) },
            1 => { write_ymm(dst, avx_cvtps2uqq_4(evex_src_xmm(modrm, rm, pfx))); Ok(()) },
            _ => { write_xmm(dst, avx_cvtps2uqq_2(evex_src_xmm(modrm, rm, pfx)[63..0])); Ok(()) },
          }
        }
      },
    }
  },

  // 0F 7A: VCVTTPS2QQ (66,W0) / VCVTTPD2QQ (66,W1) / VCVTUDQ2PS (F2,W0) / VCVTUQQ2PS (F2,W1)
  //        / VCVTUDQ2PD (F3,W0) / VCVTUQQ2PD (F3,W1)
  122 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    match mp {
      MP_66 => { // VCVTTPS2QQ (W0) / VCVTTPD2QQ (W1)
        if pfx.rex_w then { // VCVTTPD2QQ: f64→i64 trunc
          match pfx.evex_ll {
            2 => { write_zmm(dst, avx_cvttpd2qq_512(evex_src_zmm(modrm, rm, pfx))); Ok(()) },
            1 => { write_ymm(dst, avx_cvttpd2qq_256(evex_src_ymm(modrm, rm, pfx))); Ok(()) },
            _ => { write_xmm(dst, avx_cvttpd2qq_128(evex_src_xmm(modrm, rm, pfx))); Ok(()) },
          }
        } else { // VCVTTPS2QQ: f32→i64 trunc (widening)
          match pfx.evex_ll {
            2 => { write_zmm(dst, avx_cvttps2qq_8(evex_src_ymm(modrm, rm, pfx))); Ok(()) },
            1 => { write_ymm(dst, avx_cvttps2qq_4(evex_src_xmm(modrm, rm, pfx))); Ok(()) },
            _ => { write_xmm(dst, avx_cvttps2qq_2(evex_src_xmm(modrm, rm, pfx)[63..0])); Ok(()) },
          }
        }
      },
      MP_F2 => { // VCVTUDQ2PS (W0) / VCVTUQQ2PS (W1)
        if pfx.rex_w then { // VCVTUQQ2PS: u64→f32 (narrowing)
          match pfx.evex_ll {
            2 => { write_ymm(dst, avx_cvtuqq2ps_8(evex_src_zmm(modrm, rm, pfx))); Ok(()) },
            1 => { write_xmm(dst, avx_cvtuqq2ps_4(evex_src_ymm(modrm, rm, pfx))); Ok(()) },
            _ => { write_xmm(dst, zero_extend(avx_cvtuqq2ps_2(evex_src_xmm(modrm, rm, pfx)))); Ok(()) },
          }
        } else { // VCVTUDQ2PS: u32→f32
          match pfx.evex_ll {
            2 => { write_zmm(dst, avx_cvtudq2ps_512(evex_src_zmm(modrm, rm, pfx))); Ok(()) },
            1 => { write_ymm(dst, avx_cvtudq2ps_256(evex_src_ymm(modrm, rm, pfx))); Ok(()) },
            _ => { write_xmm(dst, avx_cvtudq2ps_128(evex_src_xmm(modrm, rm, pfx))); Ok(()) },
          }
        }
      },
      MP_F3 => { // VCVTUDQ2PD (W0) / VCVTUQQ2PD (W1)
        if pfx.rex_w then { // VCVTUQQ2PD: u64→f64
          match pfx.evex_ll {
            2 => { write_zmm(dst, avx_cvtuqq2pd_512(evex_src_zmm(modrm, rm, pfx))); Ok(()) },
            1 => { write_ymm(dst, avx_cvtuqq2pd_256(evex_src_ymm(modrm, rm, pfx))); Ok(()) },
            _ => { write_xmm(dst, avx_cvtuqq2pd_128(evex_src_xmm(modrm, rm, pfx))); Ok(()) },
          }
        } else { // VCVTUDQ2PD: u32→f64 (widening)
          match pfx.evex_ll {
            2 => { write_zmm(dst, avx_cvtudq2pd_8(evex_src_ymm(modrm, rm, pfx))); Ok(()) },
            1 => { write_ymm(dst, avx_cvtudq2pd_4(evex_src_xmm(modrm, rm, pfx))); Ok(()) },
            _ => { write_xmm(dst, avx_cvtudq2pd_2(evex_src_xmm(modrm, rm, pfx)[63..0])); Ok(()) },
          }
        }
      },
      _ => raise_UD(),
    }
  },

  // 0F 7B: VCVTPS2QQ (66,W0) / VCVTPD2QQ (66,W1) / VCVTUSI2SS (F3) / VCVTUSI2SD (F2)
  123 => {
    let modrm = fetch_byte();
    match mp {
      MP_66 => { // VCVTPS2QQ (W0) / VCVTPD2QQ (W1)
        let dst = evex_reg_idx(modrm, pfx);
        let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
        if pfx.rex_w then { // VCVTPD2QQ: f64→i64 round
          match pfx.evex_ll {
            2 => { write_zmm(dst, avx_cvtpd2qq_512(evex_src_zmm(modrm, rm, pfx))); Ok(()) },
            1 => { write_ymm(dst, avx_cvtpd2qq_256(evex_src_ymm(modrm, rm, pfx))); Ok(()) },
            _ => { write_xmm(dst, avx_cvtpd2qq_128(evex_src_xmm(modrm, rm, pfx))); Ok(()) },
          }
        } else { // VCVTPS2QQ: f32→i64 round (widening)
          match pfx.evex_ll {
            2 => { write_zmm(dst, avx_cvtps2qq_8(evex_src_ymm(modrm, rm, pfx))); Ok(()) },
            1 => { write_ymm(dst, avx_cvtps2qq_4(evex_src_xmm(modrm, rm, pfx))); Ok(()) },
            _ => { write_xmm(dst, avx_cvtps2qq_2(evex_src_xmm(modrm, rm, pfx)[63..0])); Ok(()) },
          }
        }
      },
      MP_F3 => { // VCVTUSI2SS: scalar u32/u64→f32
        let dst_xmm = evex_reg_idx(modrm, pfx);
        let rm2 = decode_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
        let src1 = read_xmm(pfx.evex_vvvvv);
        let result_f32 : dword = if pfx.rex_w then {
          let v : qword = match rm2 {
            RM_reg(_) => read_gpr64(modrm_rm_reg(modrm, pfx)),
            RM_mem(addr) => mem_read64(fixup_addr(addr)),
          };
          __uint64_to_f32(v)
        } else {
          let v : dword = match rm2 {
            RM_reg(_) => read_gpr32(modrm_rm_reg(modrm, pfx)),
            RM_mem(addr) => mem_read32(fixup_addr(addr)),
          };
          __uint32_to_f32(v)
        };
        var dst_val = src1;
        dst_val[31..0] = result_f32;
        write_xmm(dst_xmm, dst_val);
        Ok(())
      },
      MP_F2 => { // VCVTUSI2SD: scalar u32/u64→f64
        let dst_xmm = evex_reg_idx(modrm, pfx);
        let rm2 = decode_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
        let src1 = read_xmm(pfx.evex_vvvvv);
        let result_f64 : qword = if pfx.rex_w then {
          let v : qword = match rm2 {
            RM_reg(_) => read_gpr64(modrm_rm_reg(modrm, pfx)),
            RM_mem(addr) => mem_read64(fixup_addr(addr)),
          };
          __uint64_to_f64(v)
        } else {
          let v : dword = match rm2 {
            RM_reg(_) => read_gpr32(modrm_rm_reg(modrm, pfx)),
            RM_mem(addr) => mem_read32(fixup_addr(addr)),
          };
          __uint32_to_f64(v)
        };
        var dst_val = src1;
        dst_val[63..0] = result_f64;
        write_xmm(dst_xmm, dst_val);
        Ok(())
      },
      _ => raise_UD(),
    }
  },

  // 0F 6F: VMOVDQA32/VMOVDQA64/VMOVDQU32/VMOVDQU64 (EVEX load)
  111 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    match pfx.evex_ll {
      2 => { write_zmm(dst, evex_src_zmm(modrm, rm, pfx)); Ok(()) },
      1 => { write_ymm(dst, evex_src_ymm(modrm, rm, pfx)); Ok(()) },
      _ => { write_xmm(dst, evex_src_xmm(modrm, rm, pfx)); Ok(()) },
    }
  },

  // 0F 7F: VMOVDQA32/VMOVDQA64/VMOVDQU32/VMOVDQU64 (EVEX store)
  127 => {
    let modrm = fetch_byte();
    let src = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    match rm {
      RM_reg(_) => {
        let dst = evex_rm_reg_idx(modrm, pfx);
        match pfx.evex_ll {
          2 => { write_zmm(dst, read_zmm(src)); Ok(()) },
          1 => { write_ymm(dst, read_ymm(src)); Ok(()) },
          _ => { write_xmm(dst, read_xmm(src)); Ok(()) },
        }
      },
      RM_mem(addr) => {
        let a = fixup_addr(addr);
        match pfx.evex_ll {
          2 => { mem_write512(a, read_zmm(src)); Ok(()) },
          1 => { mem_write256(a, read_ymm(src)); Ok(()) },
          _ => { mem_write128(a, read_xmm(src)); Ok(()) },
        }
      },
    }
  },

  // 0F EF: VPXORD/VPXORQ (EVEX, 66 prefix)
  239 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, xor_vec(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, xor_vec(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, xor_vec(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F DB: VPANDD/VPANDQ (EVEX, 66 prefix)
  219 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, read_zmm(pfx.evex_vvvvv) & evex_src_zmm(modrm, rm, pfx)); Ok(()) },
        1 => { write_ymm(dst, read_ymm(pfx.evex_vvvvv) & evex_src_ymm(modrm, rm, pfx)); Ok(()) },
        _ => { write_xmm(dst, read_xmm(pfx.evex_vvvvv) & evex_src_xmm(modrm, rm, pfx)); Ok(()) },
      }
    }
  },

  // 0F EB: VPORD/VPORQ (EVEX, 66 prefix)
  235 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, read_zmm(pfx.evex_vvvvv) | evex_src_zmm(modrm, rm, pfx)); Ok(()) },
        1 => { write_ymm(dst, read_ymm(pfx.evex_vvvvv) | evex_src_ymm(modrm, rm, pfx)); Ok(()) },
        _ => { write_xmm(dst, read_xmm(pfx.evex_vvvvv) | evex_src_xmm(modrm, rm, pfx)); Ok(()) },
      }
    }
  },

  // 0F FE: VPADDD (EVEX, 66 prefix)
  254 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => {
          let result = avx_paddd_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx));
          let masked = apply_writemask_ps_zmm(result, read_zmm(dst), evex_get_mask16(pfx), pfx.evex_z);
          write_zmm(dst, masked); Ok(())
        },
        1 => { write_ymm(dst, avx_paddd_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_paddd_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F FA: VPSUBD (EVEX, 66 prefix)
  250 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => {
          let result = avx_psubd_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx));
          let masked = apply_writemask_ps_zmm(result, read_zmm(dst), evex_get_mask16(pfx), pfx.evex_z);
          write_zmm(dst, masked); Ok(())
        },
        1 => { write_ymm(dst, avx_psubd_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_psubd_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F D4: VPADDQ (EVEX, 66 prefix)
  212 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => {
          let result = avx_paddq_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx));
          let masked = apply_writemask_pd_zmm(result, read_zmm(dst), evex_get_mask8(pfx), pfx.evex_z);
          write_zmm(dst, masked); Ok(())
        },
        1 => { write_ymm(dst, avx_paddq_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_paddq_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F FB: VPSUBQ (EVEX, 66 prefix)
  251 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => {
          let result = avx_psubq_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx));
          let masked = apply_writemask_pd_zmm(result, read_zmm(dst), evex_get_mask8(pfx), pfx.evex_z);
          write_zmm(dst, masked); Ok(())
        },
        1 => { write_ymm(dst, avx_psubq_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_psubq_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F 6E: VMOVD (66, W=0) / VMOVQ (66, W=1) — load from GPR/mem to XMM
  110 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      if pfx.rex_w then {
        // VMOVQ: load qword into XMM, zero upper (EVEX zeros full 512 bits)
        let rm = decode_rm_evex(modrm, pfx, 8);
        let v : qword = match rm {
          RM_reg(_) => read_gpr64(modrm_rm_reg(modrm, pfx)),
          RM_mem(addr) => mem_read64(fixup_addr(addr)),
        };
        write_zmm(dst, zero_extend(v));
        Ok(())
      } else {
        // VMOVD: load dword into XMM, zero upper (EVEX zeros full 512 bits)
        let rm = decode_rm_evex(modrm, pfx, 4);
        let v : dword = match rm {
          RM_reg(_) => read_gpr32(modrm_rm_reg(modrm, pfx)),
          RM_mem(addr) => mem_read32(fixup_addr(addr)),
        };
        write_zmm(dst, zero_extend(v));
        Ok(())
      }
    }
  },

  // 0F 74: VPCMPEQB → kmask (66, EVEX)
  116 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst_k : range(0, 7) = unsigned(modrm[5..3]);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => {
          let src1 = read_zmm(pfx.evex_vvvvv);
          let src2 = evex_src_zmm(modrm, rm, pfx);
          let mask = avx_pcmpeqb_mask_512(src1, src2);
          let k_mask : qword = if pfx.evex_aaa == 0 then mask else mask & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask); Ok(())
        },
        1 => {
          let src1 = read_ymm(pfx.evex_vvvvv);
          let src2 = evex_src_ymm(modrm, rm, pfx);
          let mask : dword = avx_pcmpeqb_mask_256(src1, src2);
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask); Ok(())
        },
        _ => {
          let src1 = read_xmm(pfx.evex_vvvvv);
          let src2 = evex_src_xmm(modrm, rm, pfx);
          let mask : word = avx_pcmpeqb_mask_128(src1, src2);
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask); Ok(())
        },
      }
    }
  },

  // 0F 76: VPCMPEQD → kmask (66, EVEX)
  118 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst_k : range(0, 7) = unsigned(modrm[5..3]);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => {
          let src1 = read_zmm(pfx.evex_vvvvv);
          let src2 = evex_src_zmm(modrm, rm, pfx);
          let mask : word = avx_pcmpeqd_mask_512(src1, src2);
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask); Ok(())
        },
        1 => {
          let src1 = read_ymm(pfx.evex_vvvvv);
          let src2 = evex_src_ymm(modrm, rm, pfx);
          let mask : byte = avx_pcmpeqd_mask_256(src1, src2);
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask); Ok(())
        },
        _ => {
          let src1 = read_xmm(pfx.evex_vvvvv);
          let src2 = evex_src_xmm(modrm, rm, pfx);
          let mask : byte = avx_pcmpeqd_mask_128(src1, src2);
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask); Ok(())
        },
      }
    }
  },

  // 0F 7E: VMOVD (66, W=0) / VMOVQ (66, W=1) — store from XMM to GPR/mem
  126 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let src = evex_reg_idx(modrm, pfx);
      if pfx.rex_w then {
        let rm = decode_rm_evex(modrm, pfx, 8);
        let v : qword = read_xmm(src)[63..0];
        match rm {
          RM_reg(_) => { write_gpr64(modrm_rm_reg(modrm, pfx), v); Ok(()) },
          RM_mem(addr) => { mem_write64(fixup_addr(addr), v); Ok(()) },
        }
      } else {
        let rm = decode_rm_evex(modrm, pfx, 4);
        let v : dword = read_xmm(src)[31..0];
        match rm {
          RM_reg(_) => { write_gpr32(modrm_rm_reg(modrm, pfx), v); Ok(()) },
          RM_mem(addr) => { mem_write32(fixup_addr(addr), v); Ok(()) },
        }
      }
    }
  },

  // 0F DA: VPMINUB (66, EVEX)
  218 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_pminub_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_pminub_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_pminub_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F E7: VMOVNTDQ (66, EVEX) — non-temporal store (we just do a regular store)
  231 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let src = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match rm {
        RM_mem(addr) => {
          let a = fixup_addr(addr);
          match pfx.evex_ll {
            2 => { mem_write512(a, read_zmm(src)); Ok(()) },
            1 => { mem_write256(a, read_ymm(src)); Ok(()) },
            _ => { mem_write128(a, read_xmm(src)); Ok(()) },
          }
        },
        _ => raise_UD(), // VMOVNTDQ requires memory destination
      }
    }
  },

  // 0F F8: VPSUBB (66, EVEX)
  248 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_psubb_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_psubb_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_psubb_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F FC: VPADDB (66, EVEX)
  252 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_paddb_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_paddb_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_paddb_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F DF: VPANDND (66,W0) / VPANDNQ (66,W1)
  223 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, ~(read_zmm(pfx.evex_vvvvv)) & evex_src_zmm(modrm, rm, pfx)); Ok(()) },
        1 => { write_ymm(dst, ~(read_ymm(pfx.evex_vvvvv)) & evex_src_ymm(modrm, rm, pfx)); Ok(()) },
        _ => { write_xmm(dst, ~(read_xmm(pfx.evex_vvvvv)) & evex_src_xmm(modrm, rm, pfx)); Ok(()) },
      }
    }
  },

  // 0F FD: VPADDW (66, EVEX) [BW]
  253 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_paddw_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_paddw_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_paddw_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F F9: VPSUBW (66, EVEX) [BW]
  249 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_psubw_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_psubw_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_psubw_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F EC: VPADDSB (66, EVEX) [BW]
  236 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_paddsb_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_paddsb_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_paddsb_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F ED: VPADDSW (66, EVEX) [BW]
  237 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_paddsw_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_paddsw_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_paddsw_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F E8: VPSUBSB (66, EVEX) [BW]
  232 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_psubsb_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_psubsb_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_psubsb_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F E9: VPSUBSW (66, EVEX) [BW]
  233 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_psubsw_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_psubsw_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_psubsw_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F DC: VPADDUSB (66, EVEX) [BW]
  220 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_paddusb_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_paddusb_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_paddusb_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F DD: VPADDUSW (66, EVEX) [BW]
  221 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_paddusw_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_paddusw_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_paddusw_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F D8: VPSUBUSB (66, EVEX) [BW]
  216 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_psubusb_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_psubusb_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_psubusb_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F D9: VPSUBUSW (66, EVEX) [BW]
  217 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_psubusw_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_psubusw_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_psubusw_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F D5: VPMULLW (66, EVEX) [BW]
  213 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_pmullw_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_pmullw_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_pmullw_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F E4: VPMULHUW (66, EVEX) [BW]
  228 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_pmulhuw_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_pmulhuw_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_pmulhuw_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F E5: VPMULHW (66, EVEX) [BW]
  229 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_pmulhw_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_pmulhw_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_pmulhw_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F DE: VPMAXUB (66, EVEX) [BW]
  222 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_pmaxub_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_pmaxub_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_pmaxub_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F EA: VPMINSW (66, EVEX) [BW]
  234 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_pminsw_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_pminsw_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_pminsw_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F EE: VPMAXSW (66, EVEX) [BW]
  238 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_pmaxsw_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_pmaxsw_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_pmaxsw_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F E0: VPAVGB (66, EVEX) [BW]
  224 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_pavgb_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_pavgb_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_pavgb_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F E3: VPAVGW (66, EVEX) [BW]
  227 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_pavgw_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_pavgw_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_pavgw_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F F4: VPMULUDQ (66, EVEX) [F]
  244 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_pmuludq_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_pmuludq_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_pmuludq_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F F5: VPMADDWD (66, EVEX) [BW]
  245 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_pmaddwd_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_pmaddwd_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_pmaddwd_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F F6: VPSADBW (66, EVEX) [BW] — no writemask
  246 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_psadbw_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_psadbw_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_psadbw_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F 64: VPCMPGTB → kmask (66, EVEX) [BW]
  100 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst_k : range(0, 7) = unsigned(modrm[5..3]);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => {
          let mask = avx_pcmpgtb_mask_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx));
          let k_mask : qword = if pfx.evex_aaa == 0 then mask else mask & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask); Ok(())
        },
        1 => {
          let mask : dword = avx_pcmpgtb_mask_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx));
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask); Ok(())
        },
        _ => {
          let mask : word = avx_pcmpgtb_mask_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx));
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask); Ok(())
        },
      }
    }
  },

  // 0F 65: VPCMPGTW → kmask (66, EVEX) [BW]
  101 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst_k : range(0, 7) = unsigned(modrm[5..3]);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => {
          let mask : dword = avx_pcmpgtw_mask_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx));
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask); Ok(())
        },
        1 => {
          let mask : word = avx_pcmpgtw_mask_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx));
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask); Ok(())
        },
        _ => {
          let mask : byte = avx_pcmpgtw_mask_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx));
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask); Ok(())
        },
      }
    }
  },

  // 0F 66: VPCMPGTD → kmask (66, EVEX) [F]
  102 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst_k : range(0, 7) = unsigned(modrm[5..3]);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => {
          let mask : word = avx_pcmpgtd_mask_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx));
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask); Ok(())
        },
        1 => {
          let mask : byte = avx_pcmpgtd_mask_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx));
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask); Ok(())
        },
        _ => {
          let mask : byte = avx_pcmpgtd_mask_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx));
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask); Ok(())
        },
      }
    }
  },

  // 0F 75: VPCMPEQW → kmask (66, EVEX) [BW]
  117 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst_k : range(0, 7) = unsigned(modrm[5..3]);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => {
          let mask : dword = avx_pcmpeqw_mask_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx));
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask); Ok(())
        },
        1 => {
          let mask : word = avx_pcmpeqw_mask_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx));
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask); Ok(())
        },
        _ => {
          let mask : byte = avx_pcmpeqw_mask_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx));
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask); Ok(())
        },
      }
    }
  },

  // 0F 51: VSQRTPS (NP) / VSQRTPD (66)
  81 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    match mp {
      MP_NONE => match pfx.evex_ll {
        2 => { write_zmm(dst, vsqrtps_zmm(evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, vsqrtps_ymm(evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, vsqrtps_xmm(evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      },
      MP_66 => match pfx.evex_ll {
        2 => { write_zmm(dst, vsqrtpd_zmm(evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, vsqrtpd_ymm(evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, vsqrtpd_xmm(evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      },
      _ => raise_UD(),
    }
  },

  // 0F 5D: VMINPS (NP) / VMINPD (66)
  93 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    match mp {
      MP_NONE => match pfx.evex_ll {
        2 => { write_zmm(dst, vminps_zmm(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, vminps_ymm(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, vminps_xmm(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      },
      MP_66 => match pfx.evex_ll {
        2 => { write_zmm(dst, vminpd_zmm(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, vminpd_ymm(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, vminpd_xmm(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      },
      _ => raise_UD(),
    }
  },

  // 0F 5E: VDIVPS (NP) / VDIVPD (66)
  94 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    match mp {
      MP_NONE => match pfx.evex_ll {
        2 => { write_zmm(dst, vdivps_zmm(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, vdivps_ymm(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, vdivps_xmm(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      },
      MP_66 => match pfx.evex_ll {
        2 => { write_zmm(dst, vdivpd_zmm(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, vdivpd_ymm(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, vdivpd_xmm(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      },
      _ => raise_UD(),
    }
  },

  // 0F 5F: VMAXPS (NP) / VMAXPD (66)
  95 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    match mp {
      MP_NONE => match pfx.evex_ll {
        2 => { write_zmm(dst, vmaxps_zmm(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, vmaxps_ymm(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, vmaxps_xmm(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      },
      MP_66 => match pfx.evex_ll {
        2 => { write_zmm(dst, vmaxpd_zmm(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, vmaxpd_ymm(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, vmaxpd_xmm(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      },
      _ => raise_UD(),
    }
  },

  // 0F 60: VPUNPCKLBW (66, EVEX) [BW]
  96 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_punpcklbw_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_punpcklbw_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_punpcklbw_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F 61: VPUNPCKLWD (66, EVEX) [BW]
  97 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_punpcklwd_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_punpcklwd_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_punpcklwd_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F 62: VPUNPCKLDQ (66, EVEX) [F]
  98 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_punpckldq_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_punpckldq_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_punpckldq_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F 63: VPACKSSWB (66, EVEX) [BW]
  99 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_packsswb_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_packsswb_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_packsswb_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F 67: VPACKUSWB (66, EVEX) [BW]
  103 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_packuswb_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_packuswb_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_packuswb_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F 68: VPUNPCKHBW (66, EVEX) [BW]
  104 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_punpckhbw_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_punpckhbw_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_punpckhbw_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F 69: VPUNPCKHWD (66, EVEX) [BW]
  105 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_punpckhwd_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_punpckhwd_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_punpckhwd_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F 6A: VPUNPCKHDQ (66, EVEX) [F]
  106 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_punpckhdq_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_punpckhdq_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_punpckhdq_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F 6B: VPACKSSDW (66, EVEX) [BW]
  107 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_packssdw_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_packssdw_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_packssdw_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F 6C: VPUNPCKLQDQ (66, EVEX) [F]
  108 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_punpcklqdq_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_punpcklqdq_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_punpcklqdq_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F 6D: VPUNPCKHQDQ (66, EVEX) [F]
  109 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_punpckhqdq_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_punpckhqdq_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_punpckhqdq_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F 70: VPSHUFD (66) / VPSHUFHW (F3) / VPSHUFLW (F2)
  112 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let imm = fetch_byte();
    match mp {
      MP_66 => match pfx.evex_ll { // VPSHUFD
        2 => { write_zmm(dst, avx_pshufd_512(evex_src_zmm(modrm, rm, pfx), imm)); Ok(()) },
        1 => { write_ymm(dst, avx_pshufd_256(evex_src_ymm(modrm, rm, pfx), imm)); Ok(()) },
        _ => { write_xmm(dst, avx_pshufd_128(evex_src_xmm(modrm, rm, pfx), imm)); Ok(()) },
      },
      MP_F3 => match pfx.evex_ll { // VPSHUFHW
        2 => { write_zmm(dst, avx_pshufhw_512(evex_src_zmm(modrm, rm, pfx), imm)); Ok(()) },
        1 => { write_ymm(dst, avx_pshufhw_256(evex_src_ymm(modrm, rm, pfx), imm)); Ok(()) },
        _ => { write_xmm(dst, avx_pshufhw_128(evex_src_xmm(modrm, rm, pfx), imm)); Ok(()) },
      },
      MP_F2 => match pfx.evex_ll { // VPSHUFLW
        2 => { write_zmm(dst, avx_pshuflw_512(evex_src_zmm(modrm, rm, pfx), imm)); Ok(()) },
        1 => { write_ymm(dst, avx_pshuflw_256(evex_src_ymm(modrm, rm, pfx), imm)); Ok(()) },
        _ => { write_xmm(dst, avx_pshuflw_128(evex_src_xmm(modrm, rm, pfx), imm)); Ok(()) },
      },
      _ => raise_UD(),
    }
  },

  // 0F 71: Group 12 — shift word by imm8 (66, EVEX)
  // /2=VPSRLW, /4=VPSRAW, /6=VPSLLW
  113 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let digit : range(0, 7) = unsigned(modrm[5..3]);
      let src = evex_rm_reg_idx(modrm, pfx);
      let dst = pfx.evex_vvvvv;
      let imm = fetch_byte();
      let count : range(0, 255) = unsigned(imm);
      match digit {
        2 => match pfx.evex_ll { // VPSRLW imm
          2 => { write_zmm(dst, avx_psrlw_imm_512(read_zmm(src), count)); Ok(()) },
          1 => { write_ymm(dst, avx_psrlw_imm_256(read_ymm(src), count)); Ok(()) },
          _ => { write_xmm(dst, avx_psrlw_imm_128(read_xmm(src), count)); Ok(()) },
        },
        4 => match pfx.evex_ll { // VPSRAW imm
          2 => { write_zmm(dst, avx_psraw_imm_512(read_zmm(src), count)); Ok(()) },
          1 => { write_ymm(dst, avx_psraw_imm_256(read_ymm(src), count)); Ok(()) },
          _ => { write_xmm(dst, avx_psraw_imm_128(read_xmm(src), count)); Ok(()) },
        },
        6 => match pfx.evex_ll { // VPSLLW imm
          2 => { write_zmm(dst, avx_psllw_imm_512(read_zmm(src), count)); Ok(()) },
          1 => { write_ymm(dst, avx_psllw_imm_256(read_ymm(src), count)); Ok(()) },
          _ => { write_xmm(dst, avx_psllw_imm_128(read_xmm(src), count)); Ok(()) },
        },
        _ => raise_UD(),
      }
    }
  },

  // 0F 72: Group 13 — shift dword/qword by imm8 (66, EVEX)
  // /2=VPSRLD(W0)/VPSRLQ(W1), /4=VPSRAD(W0)/VPSRAQ(W1), /6=VPSLLD(W0)/VPSLLQ(W1)
  114 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let digit : range(0, 7) = unsigned(modrm[5..3]);
      let src = evex_rm_reg_idx(modrm, pfx);
      let dst = pfx.evex_vvvvv;
      let imm = fetch_byte();
      let count : range(0, 255) = unsigned(imm);
      if pfx.rex_w then {
        // W=1: qword operations
        match digit {
          2 => match pfx.evex_ll { // VPSRLQ imm
            2 => { write_zmm(dst, avx_psrlq_imm_512(read_zmm(src), count)); Ok(()) },
            1 => { write_ymm(dst, avx_psrlq_imm_256(read_ymm(src), count)); Ok(()) },
            _ => { write_xmm(dst, avx_psrlq_imm_128(read_xmm(src), count)); Ok(()) },
          },
          4 => match pfx.evex_ll { // VPSRAQ imm
            2 => { write_zmm(dst, avx_psraq_imm_512(read_zmm(src), count)); Ok(()) },
            1 => { write_ymm(dst, avx_psraq_imm_256(read_ymm(src), count)); Ok(()) },
            _ => { write_xmm(dst, avx_psraq_imm_128(read_xmm(src), count)); Ok(()) },
          },
          6 => match pfx.evex_ll { // VPSLLQ imm
            2 => { write_zmm(dst, avx_psllq_imm_512(read_zmm(src), count)); Ok(()) },
            1 => { write_ymm(dst, avx_psllq_imm_256(read_ymm(src), count)); Ok(()) },
            _ => { write_xmm(dst, avx_psllq_imm_128(read_xmm(src), count)); Ok(()) },
          },
          _ => raise_UD(),
        }
      } else {
        // W=0: dword operations
        match digit {
          2 => match pfx.evex_ll { // VPSRLD imm
            2 => { write_zmm(dst, avx_psrld_imm_512(read_zmm(src), count)); Ok(()) },
            1 => { write_ymm(dst, avx_psrld_imm_256(read_ymm(src), count)); Ok(()) },
            _ => { write_xmm(dst, avx_psrld_imm_128(read_xmm(src), count)); Ok(()) },
          },
          4 => match pfx.evex_ll { // VPSRAD imm
            2 => { write_zmm(dst, avx_psrad_imm_512(read_zmm(src), count)); Ok(()) },
            1 => { write_ymm(dst, avx_psrad_imm_256(read_ymm(src), count)); Ok(()) },
            _ => { write_xmm(dst, avx_psrad_imm_128(read_xmm(src), count)); Ok(()) },
          },
          6 => match pfx.evex_ll { // VPSLLD imm
            2 => { write_zmm(dst, avx_pslld_imm_512(read_zmm(src), count)); Ok(()) },
            1 => { write_ymm(dst, avx_pslld_imm_256(read_ymm(src), count)); Ok(()) },
            _ => { write_xmm(dst, avx_pslld_imm_128(read_xmm(src), count)); Ok(()) },
          },
          _ => raise_UD(),
        }
      }
    }
  },

  // 0F 73: Group 14 — shift qword/dq by imm8 (66, EVEX)
  // /2=VPSRLQ(W1), /3=VPSRLDQ, /6=VPSLLQ(W1), /7=VPSLLDQ
  115 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let digit : range(0, 7) = unsigned(modrm[5..3]);
      let src = evex_rm_reg_idx(modrm, pfx);
      let dst = pfx.evex_vvvvv;
      let imm = fetch_byte();
      let count : range(0, 255) = unsigned(imm);
      match digit {
        2 => match pfx.evex_ll { // VPSRLQ imm (W=1)
          2 => { write_zmm(dst, avx_psrlq_imm_512(read_zmm(src), count)); Ok(()) },
          1 => { write_ymm(dst, avx_psrlq_imm_256(read_ymm(src), count)); Ok(()) },
          _ => { write_xmm(dst, avx_psrlq_imm_128(read_xmm(src), count)); Ok(()) },
        },
        3 => match pfx.evex_ll { // VPSRLDQ imm
          2 => { write_zmm(dst, avx_psrldq_512(read_zmm(src), count)); Ok(()) },
          1 => { write_ymm(dst, avx_psrldq_256(read_ymm(src), count)); Ok(()) },
          _ => { write_xmm(dst, avx_psrldq_128(read_xmm(src), count)); Ok(()) },
        },
        6 => match pfx.evex_ll { // VPSLLQ imm (W=1)
          2 => { write_zmm(dst, avx_psllq_imm_512(read_zmm(src), count)); Ok(()) },
          1 => { write_ymm(dst, avx_psllq_imm_256(read_ymm(src), count)); Ok(()) },
          _ => { write_xmm(dst, avx_psllq_imm_128(read_xmm(src), count)); Ok(()) },
        },
        7 => match pfx.evex_ll { // VPSLLDQ imm
          2 => { write_zmm(dst, avx_pslldq_512(read_zmm(src), count)); Ok(()) },
          1 => { write_ymm(dst, avx_pslldq_256(read_ymm(src), count)); Ok(()) },
          _ => { write_xmm(dst, avx_pslldq_128(read_xmm(src), count)); Ok(()) },
        },
        _ => raise_UD(),
      }
    }
  },

  // 0F C4: VPINSRW (66) — insert word from r32/m16 into XMM [BW]
  196 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src1 = read_xmm(pfx.evex_vvvvv);
      let word_val : bits(16) = match rm {
        RM_reg(_) => read_gpr32(modrm_rm_reg(modrm, pfx))[15..0],
        RM_mem(addr) => mem_read16(fixup_addr(addr)),
      };
      let imm = fetch_byte();
      let sel : range(0, 7) = unsigned(imm[2..0]);
      var result = src1;
      let lo : range(0, 112) = sel * 16;
      result[(lo + 15)..lo] = word_val;
      write_xmm(dst, result);
      Ok(())
    }
  },

  // 0F C5: VPEXTRW (66) — extract word from XMM to r32 [BW]
  197 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let src_xmm = read_xmm(evex_rm_reg_idx(modrm, pfx));
      let dst_gpr = modrm_reg(modrm, pfx);
      let imm = fetch_byte();
      let sel : range(0, 7) = unsigned(imm[2..0]);
      let lo : range(0, 112) = sel * 16;
      let word_val : bits(16) = src_xmm[(lo + 15)..lo];
      write_gpr(dst_gpr, OS64, zero_extend(word_val));
      Ok(())
    }
  },

  // 0F C2: VCMPPS (NP,W0) / VCMPPD (66,W1) / VCMPSS (F3) / VCMPSD (F2) → kmask
  194 => {
    let modrm = fetch_byte();
    let dst_k : range(0, 7) = evex_reg_idx(modrm, pfx) % 8;
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
    let src1_idx = pfx.evex_vvvvv;
    match mp {
      MP_NONE => { // VCMPPS → k
        let imm = fetch_byte();
        let pred : range(0, 31) = unsigned(imm[4..0]);
        match pfx.evex_ll {
          2 => {
            let src1 = read_zmm(src1_idx);
            let src2 : zmmword = if pfx.evex_b & is_mem
              then broadcast_f32_zmm(evex_src_m32(modrm, rm, pfx))
              else evex_src_zmm(modrm, rm, pfx);
            let result = avx_vcmpps_kmask_512(src1, src2, pred);
            write_kreg(dst_k, zero_extend(result)); Ok(())
          },
          1 => {
            let src1 = read_ymm(src1_idx);
            let src2 = evex_src_ymm(modrm, rm, pfx);
            let r = avx_vcmpps_kmask_128(src1[255..128], src2[255..128], pred) @
                    avx_vcmpps_kmask_128(src1[127..0], src2[127..0], pred);
            write_kreg(dst_k, zero_extend(r)); Ok(())
          },
          _ => {
            let src1 = read_xmm(src1_idx);
            let src2 = evex_src_xmm(modrm, rm, pfx);
            let r = avx_vcmpps_kmask_128(src1, src2, pred);
            write_kreg(dst_k, zero_extend(r)); Ok(())
          },
        }
      },
      MP_66 => { // VCMPPD → k
        let imm = fetch_byte();
        let pred : range(0, 31) = unsigned(imm[4..0]);
        match pfx.evex_ll {
          2 => {
            let src1 = read_zmm(src1_idx);
            let src2 : zmmword = if pfx.evex_b & is_mem
              then broadcast_f64_zmm(evex_src_m64(modrm, rm, pfx))
              else evex_src_zmm(modrm, rm, pfx);
            let result = avx_vcmppd_kmask_512(src1, src2, pred);
            write_kreg(dst_k, zero_extend(result)); Ok(())
          },
          1 => {
            let src1 = read_ymm(src1_idx);
            let src2 = evex_src_ymm(modrm, rm, pfx);
            let r = avx_vcmppd_kmask_128(src1[255..128], src2[255..128], pred) @
                    avx_vcmppd_kmask_128(src1[127..0], src2[127..0], pred);
            write_kreg(dst_k, zero_extend(r)); Ok(())
          },
          _ => {
            let src1 = read_xmm(src1_idx);
            let src2 = evex_src_xmm(modrm, rm, pfx);
            let r = avx_vcmppd_kmask_128(src1, src2, pred);
            write_kreg(dst_k, zero_extend(r)); Ok(())
          },
        }
      },
      MP_F3 => { // VCMPSS → k (scalar, bit 0 only)
        let rm2 = decode_rm_evex(modrm, pfx, 4);
        let imm = fetch_byte();
        let pred : range(0, 31) = unsigned(imm[4..0]);
        let src1_f32 = read_xmm(src1_idx)[31..0];
        let src2_f32 : dword = match rm2 {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
          RM_mem(addr) => mem_read32(fixup_addr(addr)),
        };
        let bit : bits(1) = if cmp_pred5_f32(src1_f32, src2_f32, pred) then 0b1 else 0b0;
        write_kreg(dst_k, zero_extend(bit)); Ok(())
      },
      MP_F2 => { // VCMPSD → k (scalar, bit 0 only)
        let rm2 = decode_rm_evex(modrm, pfx, 8);
        let imm = fetch_byte();
        let pred : range(0, 31) = unsigned(imm[4..0]);
        let src1_f64 = read_xmm(src1_idx)[63..0];
        let src2_f64 : qword = match rm2 {
          RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
          RM_mem(addr) => mem_read64(fixup_addr(addr)),
        };
        let bit : bits(1) = if cmp_pred5_f64(src1_f64, src2_f64, pred) then 0b1 else 0b0;
        write_kreg(dst_k, zero_extend(bit)); Ok(())
      },
    }
  },

  // 0F C6: VSHUFPS (NP,W0) / VSHUFPD (66,W1)
  198 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
    let src1_idx = pfx.evex_vvvvv;
    let imm = fetch_byte();
    match mp {
      MP_NONE => { // VSHUFPS
        match pfx.evex_ll {
          2 => {
            let src1 = read_zmm(src1_idx);
            let src2 : zmmword = if pfx.evex_b & is_mem
              then broadcast_f32_zmm(evex_src_m32(modrm, rm, pfx))
              else evex_src_zmm(modrm, rm, pfx);
            write_zmm(dst, avx_shufps_512(src1, src2, imm)); Ok(())
          },
          1 => {
            let src1 = read_ymm(src1_idx);
            let src2 = evex_src_ymm(modrm, rm, pfx);
            write_ymm(dst, avx_shufps_256(src1, src2, imm)); Ok(())
          },
          _ => {
            let src1 = read_xmm(src1_idx);
            let src2 = evex_src_xmm(modrm, rm, pfx);
            write_xmm(dst, avx_shufps_128(src1, src2, imm)); Ok(())
          },
        }
      },
      MP_66 => { // VSHUFPD
        match pfx.evex_ll {
          2 => {
            let src1 = read_zmm(src1_idx);
            let src2 : zmmword = if pfx.evex_b & is_mem
              then broadcast_f64_zmm(evex_src_m64(modrm, rm, pfx))
              else evex_src_zmm(modrm, rm, pfx);
            write_zmm(dst, avx_shufpd_512(src1, src2, imm)); Ok(())
          },
          1 => {
            let src1 = read_ymm(src1_idx);
            let src2 = evex_src_ymm(modrm, rm, pfx);
            write_ymm(dst, avx_shufpd_256(src1, src2, imm)); Ok(())
          },
          _ => {
            let src1 = read_xmm(src1_idx);
            let src2 = evex_src_xmm(modrm, rm, pfx);
            write_xmm(dst, avx_shufpd_128(src1, src2, imm)); Ok(())
          },
        }
      },
      _ => raise_UD(),
    }
  },

  // 0F D6: VMOVQ store (66,W1) — store low qword of XMM to XMM/m64
  214 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let src_xmm = read_xmm(evex_reg_idx(modrm, pfx));
      let rm = decode_rm_evex(modrm, pfx, 8);
      let qval : qword = src_xmm[63..0];
      match rm {
        RM_reg(_) => {
          let dst = evex_rm_reg_idx(modrm, pfx);
          write_xmm(dst, zero_extend(qval))
        },
        RM_mem(addr) => mem_write64(fixup_addr(addr), qval),
      };
      Ok(())
    }
  },

  // 0F E6: VCVTDQ2PD (F3,W0) / VCVTPD2DQ (F2,W1) / VCVTTPD2DQ (66,W1) / VCVTQQ2PD (F3,W1)
  230 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    match mp {
      MP_F3 => {
        if pfx.rex_w then { // VCVTQQ2PD: i64→f64
          match pfx.evex_ll {
            2 => { write_zmm(dst, avx_cvtqq2pd_512(evex_src_zmm(modrm, rm, pfx))); Ok(()) },
            1 => { write_ymm(dst, avx_cvtqq2pd_256(evex_src_ymm(modrm, rm, pfx))); Ok(()) },
            _ => { write_xmm(dst, avx_cvtqq2pd_128(evex_src_xmm(modrm, rm, pfx))); Ok(()) },
          }
        } else { // VCVTDQ2PD: i32→f64 (widening)
          match pfx.evex_ll {
            2 => { write_zmm(dst, avx_cvtdq2pd_8(evex_src_ymm(modrm, rm, pfx))); Ok(()) },
            1 => { write_ymm(dst, avx_cvtdq2pd_4(evex_src_xmm(modrm, rm, pfx))); Ok(()) },
            _ => { write_xmm(dst, avx_cvtdq2pd_2(evex_src_xmm(modrm, rm, pfx)[63..0])); Ok(()) },
          }
        }
      },
      MP_F2 => { // VCVTPD2DQ: f64→i32 (round, narrowing) — W1
        match pfx.evex_ll {
          2 => { write_ymm(dst, avx_cvtpd2dq_8(evex_src_zmm(modrm, rm, pfx))); Ok(()) },
          1 => { write_xmm(dst, avx_cvtpd2dq_4(evex_src_ymm(modrm, rm, pfx))); Ok(()) },
          _ => { write_xmm(dst, zero_extend(avx_cvtpd2dq_2(evex_src_xmm(modrm, rm, pfx)))); Ok(()) },
        }
      },
      MP_66 => { // VCVTTPD2DQ: f64→i32 (truncate, narrowing) — W1
        match pfx.evex_ll {
          2 => { write_ymm(dst, avx_cvttpd2dq_8(evex_src_zmm(modrm, rm, pfx))); Ok(()) },
          1 => { write_xmm(dst, avx_cvttpd2dq_4(evex_src_ymm(modrm, rm, pfx))); Ok(()) },
          _ => { write_xmm(dst, zero_extend(avx_cvttpd2dq_2(evex_src_xmm(modrm, rm, pfx)))); Ok(()) },
        }
      },
      _ => raise_UD(),
    }
  },

  // 0F D1: VPSRLW by xmm (66, EVEX) [BW]
  209 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, 16);
      let count_xmm : xmmword = evex_src_xmm(modrm, rm, pfx);
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_psrlw_xmm_512(read_zmm(pfx.evex_vvvvv), count_xmm)); Ok(()) },
        1 => { write_ymm(dst, avx_psrlw_xmm_256(read_ymm(pfx.evex_vvvvv), count_xmm)); Ok(()) },
        _ => { write_xmm(dst, avx_psrlw_xmm_128(read_xmm(pfx.evex_vvvvv), count_xmm)); Ok(()) },
      }
    }
  },

  // 0F D2: VPSRLD by xmm (66, EVEX) [F]
  210 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, 16);
      let count_xmm : xmmword = evex_src_xmm(modrm, rm, pfx);
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_psrld_xmm_512(read_zmm(pfx.evex_vvvvv), count_xmm)); Ok(()) },
        1 => { write_ymm(dst, avx_psrld_xmm_256(read_ymm(pfx.evex_vvvvv), count_xmm)); Ok(()) },
        _ => { write_xmm(dst, avx_psrld_xmm_128(read_xmm(pfx.evex_vvvvv), count_xmm)); Ok(()) },
      }
    }
  },

  // 0F D3: VPSRLQ by xmm (66, EVEX) [F]
  211 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, 16);
      let count_xmm : xmmword = evex_src_xmm(modrm, rm, pfx);
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_psrlq_xmm_512(read_zmm(pfx.evex_vvvvv), count_xmm)); Ok(()) },
        1 => { write_ymm(dst, avx_psrlq_xmm_256(read_ymm(pfx.evex_vvvvv), count_xmm)); Ok(()) },
        _ => { write_xmm(dst, avx_psrlq_xmm_128(read_xmm(pfx.evex_vvvvv), count_xmm)); Ok(()) },
      }
    }
  },

  // 0F E1: VPSRAW by xmm (66, EVEX) [BW]
  225 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, 16);
      let count_xmm : xmmword = evex_src_xmm(modrm, rm, pfx);
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_psraw_xmm_512(read_zmm(pfx.evex_vvvvv), count_xmm)); Ok(()) },
        1 => { write_ymm(dst, avx_psraw_xmm_256(read_ymm(pfx.evex_vvvvv), count_xmm)); Ok(()) },
        _ => { write_xmm(dst, avx_psraw_xmm_128(read_xmm(pfx.evex_vvvvv), count_xmm)); Ok(()) },
      }
    }
  },

  // 0F E2: VPSRAD (66,W0) / VPSRAQ (66,W1) by xmm (EVEX)
  226 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, 16);
      let count_xmm : xmmword = evex_src_xmm(modrm, rm, pfx);
      if pfx.rex_w then {
        // VPSRAQ
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_psraq_xmm_512(read_zmm(pfx.evex_vvvvv), count_xmm)); Ok(()) },
          1 => { write_ymm(dst, avx_psraq_xmm_256(read_ymm(pfx.evex_vvvvv), count_xmm)); Ok(()) },
          _ => { write_xmm(dst, avx_psraq_xmm_128(read_xmm(pfx.evex_vvvvv), count_xmm)); Ok(()) },
        }
      } else {
        // VPSRAD
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_psrad_xmm_512(read_zmm(pfx.evex_vvvvv), count_xmm)); Ok(()) },
          1 => { write_ymm(dst, avx_psrad_xmm_256(read_ymm(pfx.evex_vvvvv), count_xmm)); Ok(()) },
          _ => { write_xmm(dst, avx_psrad_xmm_128(read_xmm(pfx.evex_vvvvv), count_xmm)); Ok(()) },
        }
      }
    }
  },

  // 0F F1: VPSLLW by xmm (66, EVEX) [BW]
  241 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, 16);
      let count_xmm : xmmword = evex_src_xmm(modrm, rm, pfx);
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_psllw_xmm_512(read_zmm(pfx.evex_vvvvv), count_xmm)); Ok(()) },
        1 => { write_ymm(dst, avx_psllw_xmm_256(read_ymm(pfx.evex_vvvvv), count_xmm)); Ok(()) },
        _ => { write_xmm(dst, avx_psllw_xmm_128(read_xmm(pfx.evex_vvvvv), count_xmm)); Ok(()) },
      }
    }
  },

  // 0F F2: VPSLLD by xmm (66, EVEX) [F]
  242 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, 16);
      let count_xmm : xmmword = evex_src_xmm(modrm, rm, pfx);
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_pslld_xmm_512(read_zmm(pfx.evex_vvvvv), count_xmm)); Ok(()) },
        1 => { write_ymm(dst, avx_pslld_xmm_256(read_ymm(pfx.evex_vvvvv), count_xmm)); Ok(()) },
        _ => { write_xmm(dst, avx_pslld_xmm_128(read_xmm(pfx.evex_vvvvv), count_xmm)); Ok(()) },
      }
    }
  },

  // 0F F3: VPSLLQ by xmm (66, EVEX) [F]
  243 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, 16);
      let count_xmm : xmmword = evex_src_xmm(modrm, rm, pfx);
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_psllq_xmm_512(read_zmm(pfx.evex_vvvvv), count_xmm)); Ok(()) },
        1 => { write_ymm(dst, avx_psllq_xmm_256(read_ymm(pfx.evex_vvvvv), count_xmm)); Ok(()) },
        _ => { write_xmm(dst, avx_psllq_xmm_128(read_xmm(pfx.evex_vvvvv), count_xmm)); Ok(()) },
      }
    }
  },

  _ => raise_UD(),
  }
}

// =========================================================================
// EVEX 0F38 map dispatch
// =========================================================================

val dispatch_evex_0f38 : (byte, Prefixes) -> ExecutionResult
function dispatch_evex_0f38(opcode, pfx) = {
  let op : range(0, 255) = unsigned(opcode);
  let mp = get_mandatory_prefix(pfx);

  match op {

  // 0F38 18: VBROADCASTSS (66 prefix, W=0)
  24 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      // Tuple1 Scalar: disp_n = 4 for dword
      let rm = decode_rm_evex(modrm, pfx, 4);
      let elem : dword = match rm {
        RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
        RM_mem(addr) => mem_read32(fixup_addr(addr)),
      };
      match pfx.evex_ll {
        2 => { write_zmm(dst, broadcast_f32_zmm(elem)); Ok(()) },
        1 => { write_ymm(dst, broadcast_f32_ymm(elem)); Ok(()) },
        _ => { write_xmm(dst, broadcast_f32_xmm(elem)); Ok(()) },
      }
    }
  },

  // 0F38 19: VBROADCASTSD (66 prefix, W=1)
  25 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      // Tuple1 Scalar: disp_n = 8 for qword
      let rm = decode_rm_evex(modrm, pfx, 8);
      let elem : qword = match rm {
        RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
        RM_mem(addr) => mem_read64(fixup_addr(addr)),
      };
      match pfx.evex_ll {
        2 => { write_zmm(dst, broadcast_f64_zmm(elem)); Ok(()) },
        1 => { write_ymm(dst, broadcast_f64_ymm(elem)); Ok(()) },
        _ => { write_xmm(dst, elem @ elem); Ok(()) },
      }
    }
  },

  // 0F38 7B: VPBROADCASTW (66,W0) [BW] — from GPR
  123 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let elem : word = read_gpr32(modrm_rm_reg(modrm, pfx))[15..0];
      let w : dword = elem @ elem;
      let q : qword = w @ w;
      let x : xmmword = q @ q;
      match pfx.evex_ll {
        2 => { write_zmm(dst, x @ x @ x @ x); Ok(()) },
        1 => { write_ymm(dst, x @ x); Ok(()) },
        _ => { write_xmm(dst, x); Ok(()) },
      }
    }
  },

  // 0F38 7C: VPBROADCASTD (66 prefix, W=0)
  124 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, 4);
      let elem : dword = match rm {
        RM_reg(_) => {
          // Source is a GPR (r/m field selects GPR, not XMM)
          let gpr_idx = modrm_rm_reg(modrm, pfx);
          read_gpr32(gpr_idx)
        },
        RM_mem(addr) => mem_read32(fixup_addr(addr)),
      };
      match pfx.evex_ll {
        2 => { write_zmm(dst, broadcast_f32_zmm(elem)); Ok(()) },
        1 => { write_ymm(dst, broadcast_f32_ymm(elem)); Ok(()) },
        _ => { write_xmm(dst, broadcast_f32_xmm(elem)); Ok(()) },
      }
    }
  },

  // 0F38 58: VPBROADCASTD (66,W0) [F] — from XMM/mem
  88 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, 4);
      let elem : dword = match rm {
        RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
        RM_mem(addr) => mem_read32(fixup_addr(addr)),
      };
      match pfx.evex_ll {
        2 => { write_zmm(dst, broadcast_f32_zmm(elem)); Ok(()) },
        1 => { write_ymm(dst, broadcast_f32_ymm(elem)); Ok(()) },
        _ => { write_xmm(dst, broadcast_f32_xmm(elem)); Ok(()) },
      }
    }
  },

  // 0F38 59: VPBROADCASTQ (66,W1) [F] — from XMM/mem
  89 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, 8);
      let elem : qword = match rm {
        RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
        RM_mem(addr) => mem_read64(fixup_addr(addr)),
      };
      match pfx.evex_ll {
        2 => { write_zmm(dst, broadcast_f64_zmm(elem)); Ok(()) },
        1 => { write_ymm(dst, broadcast_f64_ymm(elem)); Ok(()) },
        _ => { write_xmm(dst, elem @ elem); Ok(()) },
      }
    }
  },

  // 0F38 78: VPBROADCASTB (66,W0) [BW] — from XMM/mem
  120 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, 4);
      let elem : byte = match rm {
        RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[7..0],
        RM_mem(addr) => mem_read8(fixup_addr(addr)),
      };
      match pfx.evex_ll {
        2 => { write_zmm(dst, broadcast_byte_zmm(elem)); Ok(()) },
        1 => { write_ymm(dst, broadcast_byte_ymm(elem)); Ok(()) },
        _ => { write_xmm(dst, broadcast_byte_xmm(elem)); Ok(()) },
      }
    }
  },

  // 0F38 79: VPBROADCASTW (66,W0) [BW] — from XMM/mem
  121 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, 4);
      let elem : word = match rm {
        RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[15..0],
        RM_mem(addr) => mem_read16(fixup_addr(addr)),
      };
      let w : dword = elem @ elem;
      let q : qword = w @ w;
      let x : xmmword = q @ q;
      match pfx.evex_ll {
        2 => { write_zmm(dst, x @ x @ x @ x); Ok(()) },
        1 => { write_ymm(dst, x @ x); Ok(()) },
        _ => { write_xmm(dst, x); Ok(()) },
      }
    }
  },

  // 0F38 1A: VBROADCASTF32X4 (66,W0) / VBROADCASTF64X2 (66,W1) [F]
  26 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, 16);
      match rm {
        RM_reg(_) => raise_UD(),
        RM_mem(addr) => {
          let src : xmmword = mem_read128(fixup_addr(addr));
          match pfx.evex_ll {
            2 => { write_zmm(dst, src @ src @ src @ src); Ok(()) },
            _ => { write_ymm(dst, src @ src); Ok(()) },
          }
        },
      }
    }
  },

  // 0F38 1B: VBROADCASTF32X8 (66,W0) / VBROADCASTF64X4 (66,W1) [F] (512-bit only)
  27 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, 32);
      match rm {
        RM_reg(_) => raise_UD(),
        RM_mem(addr) => { let src : ymmword = mem_read256(fixup_addr(addr)); write_zmm(dst, src @ src); Ok(()) },
      }
    }
  },

  // 0F38 5A: VBROADCASTI32X4 (66,W0) / VBROADCASTI64X2 (66,W1) [F]
  90 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, 16);
      match rm {
        RM_reg(_) => raise_UD(),
        RM_mem(addr) => {
          let src : xmmword = mem_read128(fixup_addr(addr));
          match pfx.evex_ll {
            2 => { write_zmm(dst, src @ src @ src @ src); Ok(()) },
            _ => { write_ymm(dst, src @ src); Ok(()) },
          }
        },
      }
    }
  },

  // 0F38 5B: VBROADCASTI32X8 (66,W0) / VBROADCASTI64X4 (66,W1) [F] (512-bit only)
  91 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, 32);
      match rm {
        RM_reg(_) => raise_UD(),
        RM_mem(addr) => { let src : ymmword = mem_read256(fixup_addr(addr)); write_zmm(dst, src @ src); Ok(()) },
      }
    }
  },

  // 0F38 26: VPTESTMB (66, W=0) / VPTESTNMB (F3, W=0)
  38 => {
    let modrm = fetch_byte();
    let dst_k : range(0, 7) = unsigned(modrm[5..3]);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_negate = mp == MP_F3;
    if mp != MP_66 & mp != MP_F3 then raise_UD()
    else match pfx.evex_ll {
      2 => {
        let src1 = read_zmm(pfx.evex_vvvvv);
        let src2 = evex_src_zmm(modrm, rm, pfx);
        let mask : qword = if is_negate then avx_ptestnmb_512(src1, src2) else avx_ptestmb_512(src1, src2);
        let k_mask : qword = if pfx.evex_aaa == 0 then mask else mask & read_kreg(pfx.evex_aaa);
        write_kreg(dst_k, k_mask); Ok(())
      },
      1 => {
        let src1 = read_ymm(pfx.evex_vvvvv);
        let src2 = evex_src_ymm(modrm, rm, pfx);
        let mask : dword = if is_negate then avx_ptestnmb_256(src1, src2) else avx_ptestmb_256(src1, src2);
        let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
        write_kreg(dst_k, k_mask); Ok(())
      },
      _ => {
        let src1 = read_xmm(pfx.evex_vvvvv);
        let src2 = evex_src_xmm(modrm, rm, pfx);
        let mask : word = if is_negate then avx_ptestnmb_128(src1, src2) else avx_ptestmb_128(src1, src2);
        let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
        write_kreg(dst_k, k_mask); Ok(())
      },
    }
  },

  // 0F38 27: VPTESTMD (66, W=0) / VPTESTNMD (F3, W=0)
  39 => {
    let modrm = fetch_byte();
    let dst_k : range(0, 7) = unsigned(modrm[5..3]);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_negate = mp == MP_F3;
    if mp != MP_66 & mp != MP_F3 then raise_UD()
    else match pfx.evex_ll {
      2 => {
        let src1 = read_zmm(pfx.evex_vvvvv);
        let src2 = evex_src_zmm(modrm, rm, pfx);
        let mask : word = if is_negate then avx_ptestnmd_512(src1, src2) else avx_ptestmd_512(src1, src2);
        let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
        write_kreg(dst_k, k_mask); Ok(())
      },
      1 => {
        let src1 = read_ymm(pfx.evex_vvvvv);
        let src2 = evex_src_ymm(modrm, rm, pfx);
        let mask : byte = if is_negate then avx_ptestnmd_256(src1, src2) else avx_ptestmd_256(src1, src2);
        let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
        write_kreg(dst_k, k_mask); Ok(())
      },
      _ => raise_UD(),
    }
  },

  // 0F38 29: VPCMPEQQ (66,W1) [F] / VPMOVB2M (F3,W0) / VPMOVW2M (F3,W1) [BW]
  41 => {
    if mp == MP_F3 then {
      // VPMOVB2M (W0) / VPMOVW2M (W1): vector -> mask register
      let modrm = fetch_byte();
      let dst_k : kreg_idx = unsigned(modrm[5..3]);
      let src_idx = evex_rm_reg_idx(modrm, pfx);
      if pfx.rex_w then {
        // VPMOVW2M
        match pfx.evex_ll {
          2 => { write_kreg(dst_k, avx_vpmovw2m_512(read_zmm(src_idx))); Ok(()) },
          1 => { write_kreg(dst_k, avx_vpmovw2m_256(read_ymm(src_idx))); Ok(()) },
          _ => { write_kreg(dst_k, avx_vpmovw2m_128(read_xmm(src_idx))); Ok(()) },
        }
      } else {
        // VPMOVB2M
        match pfx.evex_ll {
          2 => { write_kreg(dst_k, avx_vpmovb2m_512(read_zmm(src_idx))); Ok(()) },
          1 => { write_kreg(dst_k, avx_vpmovb2m_256(read_ymm(src_idx))); Ok(()) },
          _ => { write_kreg(dst_k, avx_vpmovb2m_128(read_xmm(src_idx))); Ok(()) },
        }
      }
    } else if mp == MP_66 then {
      let modrm = fetch_byte();
      let dst_k : range(0, 7) = unsigned(modrm[5..3]);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => {
          let src1 = read_zmm(pfx.evex_vvvvv);
          let src2 = evex_src_zmm(modrm, rm, pfx);
          var mask : byte = 0x00;
          foreach (i from 0 to 7) {
            let lo : range(0, 448) = i * 64;
            if src1[(lo + 63)..lo] == src2[(lo + 63)..lo] then mask = mask | to_bits(8, pow2(i));
          };
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask); Ok(())
        },
        1 => {
          let src1 = read_ymm(pfx.evex_vvvvv);
          let src2 = evex_src_ymm(modrm, rm, pfx);
          var mask : byte = 0x00;
          foreach (i from 0 to 3) {
            let lo : range(0, 192) = i * 64;
            if src1[(lo + 63)..lo] == src2[(lo + 63)..lo] then mask = mask | to_bits(8, pow2(i));
          };
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask); Ok(())
        },
        _ => raise_UD(),
      }
    } else raise_UD()
  },

  // 0F38 37: VPCMPGTQ (66,W1) [F]
  55 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst_k : range(0, 7) = unsigned(modrm[5..3]);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => {
          let src1 = read_zmm(pfx.evex_vvvvv);
          let src2 = evex_src_zmm(modrm, rm, pfx);
          var mask : byte = 0x00;
          foreach (i from 0 to 7) {
            let lo : range(0, 448) = i * 64;
            if signed(src1[(lo + 63)..lo]) > signed(src2[(lo + 63)..lo]) then mask = mask | to_bits(8, pow2(i));
          };
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask); Ok(())
        },
        1 => {
          let src1 = read_ymm(pfx.evex_vvvvv);
          let src2 = evex_src_ymm(modrm, rm, pfx);
          var mask : byte = 0x00;
          foreach (i from 0 to 3) {
            let lo : range(0, 192) = i * 64;
            if signed(src1[(lo + 63)..lo]) > signed(src2[(lo + 63)..lo]) then mask = mask | to_bits(8, pow2(i));
          };
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask); Ok(())
        },
        _ => raise_UD(),
      }
    }
  },

  // 0F38 38: VPMINSB (66) [BW] / VPMOVM2D (F3,W0) / VPMOVM2Q (F3,W1) [DQ]
  56 => {
    if mp == MP_66 then {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let src1_idx = pfx.evex_vvvvv;
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_pminsb_512(read_zmm(src1_idx), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_pminsb_256(read_ymm(src1_idx), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_pminsb_128(read_xmm(src1_idx), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    } else if mp == MP_F3 then {
      // VPMOVM2D (W0) / VPMOVM2Q (W1): mask register -> vector
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let k_idx : kreg_idx = unsigned(modrm[2..0]);
      let k_val = read_kreg(k_idx);
      if pfx.rex_w then {
        // VPMOVM2Q
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_vpmovm2q_512(k_val)); Ok(()) },
          1 => { write_ymm(dst, avx_vpmovm2q_256(k_val)); Ok(()) },
          _ => { write_xmm(dst, avx_vpmovm2q_128(k_val)); Ok(()) },
        }
      } else {
        // VPMOVM2D
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_vpmovm2d_512(k_val)); Ok(()) },
          1 => { write_ymm(dst, avx_vpmovm2d_256(k_val)); Ok(()) },
          _ => { write_xmm(dst, avx_vpmovm2d_128(k_val)); Ok(()) },
        }
      }
    } else raise_UD()
  },

  // 0F38 39: VPMINSD (66,W0) / VPMINSQ (66,W1) [F] / VPMOVD2M (F3,W0) / VPMOVQ2M (F3,W1) [DQ]
  57 => {
    if mp == MP_66 then {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let src1_idx = pfx.evex_vvvvv;
      if pfx.rex_w then { // VPMINSQ
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_pminsq_512(read_zmm(src1_idx), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
          1 => { write_ymm(dst, avx_pminsq_256(read_ymm(src1_idx), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
          _ => { write_xmm(dst, avx_pminsq_128(read_xmm(src1_idx), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
        }
      } else { // VPMINSD
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_pminsd_512(read_zmm(src1_idx), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
          1 => { write_ymm(dst, avx_pminsd_256(read_ymm(src1_idx), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
          _ => { write_xmm(dst, avx_pminsd_128(read_xmm(src1_idx), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
        }
      }
    } else if mp == MP_F3 then {
      // VPMOVD2M (W0) / VPMOVQ2M (W1): vector -> mask register
      let modrm = fetch_byte();
      let dst_k : kreg_idx = unsigned(modrm[5..3]);
      let src_idx = evex_rm_reg_idx(modrm, pfx);
      if pfx.rex_w then {
        // VPMOVQ2M
        match pfx.evex_ll {
          2 => { write_kreg(dst_k, avx_vpmovq2m_512(read_zmm(src_idx))); Ok(()) },
          1 => { write_kreg(dst_k, avx_vpmovq2m_256(read_ymm(src_idx))); Ok(()) },
          _ => { write_kreg(dst_k, avx_vpmovq2m_128(read_xmm(src_idx))); Ok(()) },
        }
      } else {
        // VPMOVD2M
        match pfx.evex_ll {
          2 => { write_kreg(dst_k, avx_vpmovd2m_512(read_zmm(src_idx))); Ok(()) },
          1 => { write_kreg(dst_k, avx_vpmovd2m_256(read_ymm(src_idx))); Ok(()) },
          _ => { write_kreg(dst_k, avx_vpmovd2m_128(read_xmm(src_idx))); Ok(()) },
        }
      }
    } else raise_UD()
  },

  // 0F38 3A: VPBROADCASTMW2D (F3,W0) [CD]
  58 => {
    if mp == MP_F3 then {
      if not_bool(pfx.rex_w) then {
        // VPBROADCASTMW2D: broadcast low word of k-register to all dword elements
        let modrm = fetch_byte();
        let dst = evex_reg_idx(modrm, pfx);
        let k_idx : kreg_idx = unsigned(modrm[2..0]);
        let k_val = read_kreg(k_idx);
        let w : word = k_val[15..0];
        let d : dword = zero_extend(w);
        match pfx.evex_ll {
          2 => { write_zmm(dst, d @ d @ d @ d @ d @ d @ d @ d @ d @ d @ d @ d @ d @ d @ d @ d); Ok(()) },
          1 => { write_ymm(dst, d @ d @ d @ d @ d @ d @ d @ d); Ok(()) },
          _ => { write_xmm(dst, d @ d @ d @ d); Ok(()) },
        }
      } else raise_UD()
    } else raise_UD()
  },

  // 0F38 3B: VPMINUD (66, W=0)
  59 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_pminud_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_pminud_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_pminud_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F38 2B: VPACKUSDW (66,W0) [BW]
  43 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let src1_idx = pfx.evex_vvvvv;
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_packusdw_512(read_zmm(src1_idx), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_packusdw_256(read_ymm(src1_idx), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_packusdw_128(read_xmm(src1_idx), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F38 3C: VPMAXSB (66) [BW]
  60 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let src1_idx = pfx.evex_vvvvv;
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_pmaxsb_512(read_zmm(src1_idx), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_pmaxsb_256(read_ymm(src1_idx), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_pmaxsb_128(read_xmm(src1_idx), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F38 3D: VPMAXSD (66,W0) / VPMAXSQ (66,W1) [F]
  61 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let src1_idx = pfx.evex_vvvvv;
      if pfx.rex_w then { // VPMAXSQ
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_pmaxsq_512(read_zmm(src1_idx), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
          1 => { write_ymm(dst, avx_pmaxsq_256(read_ymm(src1_idx), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
          _ => { write_xmm(dst, avx_pmaxsq_128(read_xmm(src1_idx), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
        }
      } else { // VPMAXSD
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_pmaxsd_512(read_zmm(src1_idx), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
          1 => { write_ymm(dst, avx_pmaxsd_256(read_ymm(src1_idx), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
          _ => { write_xmm(dst, avx_pmaxsd_128(read_xmm(src1_idx), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
        }
      }
    }
  },

  // 0F38 3E: VPMAXUW (66) [BW]
  62 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let src1_idx = pfx.evex_vvvvv;
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_pmaxuw_512(read_zmm(src1_idx), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_pmaxuw_256(read_ymm(src1_idx), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_pmaxuw_128(read_xmm(src1_idx), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F38 3F: VPMAXUD (66,W0) / VPMAXUQ (66,W1) [F]
  63 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let src1_idx = pfx.evex_vvvvv;
      if pfx.rex_w then { // VPMAXUQ
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_pmaxuq_512(read_zmm(src1_idx), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
          1 => { write_ymm(dst, avx_pmaxuq_256(read_ymm(src1_idx), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
          _ => { write_xmm(dst, avx_pmaxuq_128(read_xmm(src1_idx), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
        }
      } else { // VPMAXUD
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_pmaxud_512(read_zmm(src1_idx), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
          1 => { write_ymm(dst, avx_pmaxud_256(read_ymm(src1_idx), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
          _ => { write_xmm(dst, avx_pmaxud_128(read_xmm(src1_idx), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
        }
      }
    }
  },

  // 0F38 7A: VPBROADCASTB from GPR (66, W=0)
  // r/m field selects a GPR (mod=11 always for this opcode)
  122 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let elem : byte = read_gpr32(modrm_rm_reg(modrm, pfx))[7..0];
      match pfx.evex_ll {
        2 => { write_zmm(dst, broadcast_byte_zmm(elem)); Ok(()) },
        1 => { write_ymm(dst, broadcast_byte_ymm(elem)); Ok(()) },
        _ => { write_xmm(dst, broadcast_byte_xmm(elem)); Ok(()) },
      }
    }
  },

  // 0F38 0C: VPERMILPS (66,W0) — register control [F]
  12 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let src1_idx = pfx.evex_vvvvv;
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_vpermilps_512(read_zmm(src1_idx), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_vpermilps_256(read_ymm(src1_idx), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_vpermilps_128(read_xmm(src1_idx), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F38 0D: VPERMILPD (66,W1) — register control [F]
  13 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let src1_idx = pfx.evex_vvvvv;
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_vpermilpd_512(read_zmm(src1_idx), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_vpermilpd_256(read_ymm(src1_idx), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_vpermilpd_128(read_xmm(src1_idx), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F38 16: VPERMPS (66,W0) / VPERMPD (66,W1) [F]
  22 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let idx_reg = pfx.evex_vvvvv;
      if pfx.rex_w then { // VPERMPD
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_vpermpd_512(evex_src_zmm(modrm, rm, pfx), read_zmm(idx_reg))); Ok(()) },
          _ => { write_ymm(dst, avx_vpermpd_256(evex_src_ymm(modrm, rm, pfx), read_ymm(idx_reg))); Ok(()) },
        }
      } else { // VPERMPS
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_vpermps_512(evex_src_zmm(modrm, rm, pfx), read_zmm(idx_reg))); Ok(()) },
          _ => { write_ymm(dst, avx_vpermps_256(evex_src_ymm(modrm, rm, pfx), read_ymm(idx_reg))); Ok(()) },
        }
      }
    }
  },

  // 0F38 36: VPERMD (66,W0) / VPERMQ (66,W1) [F]
  54 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let idx_reg = pfx.evex_vvvvv;
      if pfx.rex_w then { // VPERMQ
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_vpermq_512(evex_src_zmm(modrm, rm, pfx), read_zmm(idx_reg))); Ok(()) },
          _ => { write_ymm(dst, avx_vpermq_256(evex_src_ymm(modrm, rm, pfx), read_ymm(idx_reg))); Ok(()) },
        }
      } else { // VPERMD
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_vpermd_512(evex_src_zmm(modrm, rm, pfx), read_zmm(idx_reg))); Ok(()) },
          _ => { write_ymm(dst, avx_vpermd_256(evex_src_ymm(modrm, rm, pfx), read_ymm(idx_reg))); Ok(()) },
        }
      }
    }
  },

  // 0F38 00: VPSHUFB (66) [BW]
  0 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let src1_idx = pfx.evex_vvvvv;
      match pfx.evex_ll {
        2 => {
          write_zmm(dst, avx_pshufb_512(read_zmm(src1_idx), evex_src_zmm(modrm, rm, pfx))); Ok(())
        },
        1 => {
          write_ymm(dst, avx_pshufb_256(read_ymm(src1_idx), evex_src_ymm(modrm, rm, pfx))); Ok(())
        },
        _ => {
          write_xmm(dst, avx_pshufb_128(read_xmm(src1_idx), evex_src_xmm(modrm, rm, pfx))); Ok(())
        },
      }
    }
  },

  // 0F38 04: VPMADDUBSW (66) [BW]
  4 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let src1_idx = pfx.evex_vvvvv;
      match pfx.evex_ll {
        2 => {
          write_zmm(dst, avx_pmaddubsw_512(read_zmm(src1_idx), evex_src_zmm(modrm, rm, pfx))); Ok(())
        },
        1 => {
          write_ymm(dst, avx_pmaddubsw_256(read_ymm(src1_idx), evex_src_ymm(modrm, rm, pfx))); Ok(())
        },
        _ => {
          write_xmm(dst, avx_pmaddubsw_128(read_xmm(src1_idx), evex_src_xmm(modrm, rm, pfx))); Ok(())
        },
      }
    }
  },

  // 0F38 0B: VPMULHRSW (66) [BW]
  11 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let src1_idx = pfx.evex_vvvvv;
      match pfx.evex_ll {
        2 => {
          write_zmm(dst, avx_pmulhrsw_512(read_zmm(src1_idx), evex_src_zmm(modrm, rm, pfx))); Ok(())
        },
        1 => {
          write_ymm(dst, avx_pmulhrsw_256(read_ymm(src1_idx), evex_src_ymm(modrm, rm, pfx))); Ok(())
        },
        _ => {
          write_xmm(dst, avx_pmulhrsw_128(read_xmm(src1_idx), evex_src_xmm(modrm, rm, pfx))); Ok(())
        },
      }
    }
  },

  // 0F38 28: VPMULDQ (66,W1) [F] / VPMOVM2B (F3,W0) / VPMOVM2W (F3,W1) [BW]
  40 => {
    if mp == MP_66 then {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let src1_idx = pfx.evex_vvvvv;
      match pfx.evex_ll {
        2 => {
          write_zmm(dst, avx_pmuldq_512(read_zmm(src1_idx), evex_src_zmm(modrm, rm, pfx))); Ok(())
        },
        1 => {
          write_ymm(dst, avx_pmuldq_256(read_ymm(src1_idx), evex_src_ymm(modrm, rm, pfx))); Ok(())
        },
        _ => {
          write_xmm(dst, avx_pmuldq_128(read_xmm(src1_idx), evex_src_xmm(modrm, rm, pfx))); Ok(())
        },
      }
    } else if mp == MP_F3 then {
      // VPMOVM2B (W0) / VPMOVM2W (W1): mask register -> vector
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let k_idx : kreg_idx = unsigned(modrm[2..0]);
      let k_val = read_kreg(k_idx);
      if pfx.rex_w then {
        // VPMOVM2W
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_vpmovm2w_512(k_val)); Ok(()) },
          1 => { write_ymm(dst, avx_vpmovm2w_256(k_val)); Ok(()) },
          _ => { write_xmm(dst, avx_vpmovm2w_128(k_val)); Ok(()) },
        }
      } else {
        // VPMOVM2B
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_vpmovm2b_512(k_val)); Ok(()) },
          1 => { write_ymm(dst, avx_vpmovm2b_256(k_val)); Ok(()) },
          _ => { write_xmm(dst, avx_vpmovm2b_128(k_val)); Ok(()) },
        }
      }
    } else raise_UD()
  },

  // 0F38 40: VPMULLD (66,W0) / VPMULLQ (66,W1) [F/DQ]
  64 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let src1_idx = pfx.evex_vvvvv;
      if pfx.rex_w then { // VPMULLQ
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_pmullq_512(read_zmm(src1_idx), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
          1 => { write_ymm(dst, avx_pmullq_256(read_ymm(src1_idx), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
          _ => { write_xmm(dst, avx_pmullq_128(read_xmm(src1_idx), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
        }
      } else { // VPMULLD
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_pmulld_512(read_zmm(src1_idx), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
          1 => { write_ymm(dst, avx_pmulld_256(read_ymm(src1_idx), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
          _ => { write_xmm(dst, avx_pmulld_128(read_xmm(src1_idx), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
        }
      }
    }
  },

  // 0F38 1C: VPABSB (66) [BW]
  28 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_pabsb_512(evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_pabsb_256(evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_pabsb_128(evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F38 1D: VPABSW (66) [BW]
  29 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_pabsw_512(evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_pabsw_256(evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_pabsw_128(evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F38 1E: VPABSD (66,W0) [F]
  30 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_pabsd_512(evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_pabsd_256(evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_pabsd_128(evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F38 1F: VPABSQ (66,W1) [F]
  31 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_pabsq_512(evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_pabsq_256(evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_pabsq_128(evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F38 10: VPSRLVW (66,W1) [BW] / VPMOVUSWB (F3) [BW]
  16 => {
    let modrm = fetch_byte();
    if mp == MP_66 then {
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let src1_idx = pfx.evex_vvvvv;
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_psrlvw_512(read_zmm(src1_idx), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_psrlvw_256(read_ymm(src1_idx), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_psrlvw_128(read_xmm(src1_idx), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    } else if mp == MP_F3 then {
      // VPMOVUSWB: src=reg, dst=r/m (narrowing: word->byte)
      let src = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => { let res = avx_pmovuswb_512(read_zmm(src));
               let rm = decode_rm_evex(modrm, pfx, 32);
               match rm { RM_reg(_) => { write_ymm(evex_rm_reg_idx(modrm, pfx), res); Ok(()) },
                           RM_mem(addr) => { mem_write256(fixup_addr(addr), res); Ok(()) } } },
        1 => { let res = avx_pmovuswb_256(read_ymm(src));
               let rm = decode_rm_evex(modrm, pfx, 16);
               match rm { RM_reg(_) => { write_xmm(evex_rm_reg_idx(modrm, pfx), res); Ok(()) },
                           RM_mem(addr) => { mem_write128(fixup_addr(addr), res); Ok(()) } } },
        _ => { let res = avx_pmovuswb_128(read_xmm(src));
               let rm = decode_rm_evex(modrm, pfx, 8);
               match rm { RM_reg(_) => { write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)); Ok(()) },
                           RM_mem(addr) => { mem_write64(fixup_addr(addr), res); Ok(()) } } },
      }
    } else raise_UD()
  },

  // 0F38 11: VPSRAVW (66,W1) [BW] / VPMOVUSDB (F3) [F]
  17 => {
    let modrm = fetch_byte();
    if mp == MP_66 then {
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let src1_idx = pfx.evex_vvvvv;
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_psravw_512(read_zmm(src1_idx), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_psravw_256(read_ymm(src1_idx), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_psravw_128(read_xmm(src1_idx), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    } else if mp == MP_F3 then {
      // VPMOVUSDB: src=reg, dst=r/m (narrowing: dword->byte)
      let src = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => { let res = avx_pmovusdb_512(read_zmm(src));
               let rm = decode_rm_evex(modrm, pfx, 16);
               match rm { RM_reg(_) => { write_xmm(evex_rm_reg_idx(modrm, pfx), res); Ok(()) },
                           RM_mem(addr) => { mem_write128(fixup_addr(addr), res); Ok(()) } } },
        1 => { let res = avx_pmovusdb_256(read_ymm(src));
               let rm = decode_rm_evex(modrm, pfx, 8);
               match rm { RM_reg(_) => { write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)); Ok(()) },
                           RM_mem(addr) => { mem_write64(fixup_addr(addr), res); Ok(()) } } },
        _ => { let res = avx_pmovusdb_128(read_xmm(src));
               let rm = decode_rm_evex(modrm, pfx, 4);
               match rm { RM_reg(_) => { write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)); Ok(()) },
                           RM_mem(addr) => { mem_write32(fixup_addr(addr), res); Ok(()) } } },
      }
    } else raise_UD()
  },

  // 0F38 12: VPSLLVW (66,W1) [BW] / VPMOVUSQB (F3) [F]
  18 => {
    let modrm = fetch_byte();
    if mp == MP_66 then {
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let src1_idx = pfx.evex_vvvvv;
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_psllvw_512(read_zmm(src1_idx), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_psllvw_256(read_ymm(src1_idx), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_psllvw_128(read_xmm(src1_idx), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    } else if mp == MP_F3 then {
      // VPMOVUSQB: src=reg, dst=r/m (narrowing: qword->byte)
      let src = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => { let res = avx_pmovusqb_512(read_zmm(src));
               let rm = decode_rm_evex(modrm, pfx, 8);
               match rm { RM_reg(_) => { write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)); Ok(()) },
                           RM_mem(addr) => { mem_write64(fixup_addr(addr), res); Ok(()) } } },
        1 => { let res = avx_pmovusqb_256(read_ymm(src));
               let rm = decode_rm_evex(modrm, pfx, 4);
               match rm { RM_reg(_) => { write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)); Ok(()) },
                           RM_mem(addr) => { mem_write32(fixup_addr(addr), res); Ok(()) } } },
        _ => { let res = avx_pmovusqb_128(read_xmm(src));
               let rm = decode_rm(modrm, pfx);
               match rm { RM_reg(_) => { write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)); Ok(()) },
                           RM_mem(addr) => { mem_write16(fixup_addr(addr), res); Ok(()) } } },
      }
    } else raise_UD()
  },

  // 0F38 13: VCVTPH2PS (66,W0) [F] / VPMOVUSDW (F3) [F]
  19 => {
    if mp == MP_66 then {
      // VCVTPH2PS: convert packed FP16 (half width) to FP32
      if pfx.rex_w then raise_UD()
      else {
        let modrm = fetch_byte();
        let dst = evex_reg_idx(modrm, pfx);
        match pfx.evex_ll {
          2 => { let rm = decode_rm_evex(modrm, pfx, 32);
                 let src = evex_src_ymm(modrm, rm, pfx);
                 write_zmm(dst, avx_vcvtph2ps_512(src)); Ok(()) },
          1 => { let rm = decode_rm_evex(modrm, pfx, 16);
                 let src_x = evex_src_xmm(modrm, rm, pfx);
                 write_ymm(dst, avx_vcvtph2ps_256(src_x)); Ok(()) },
          _ => { let rm = decode_rm_evex(modrm, pfx, 8);
                 let src_q = evex_src_xmm(modrm, rm, pfx);
                 write_xmm(dst, avx_vcvtph2ps_128(src_q[63..0])); Ok(()) },
        }
      }
    } else if mp == MP_F3 then {
      let modrm = fetch_byte();
      let src = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => { let res = avx_pmovusdw_512(read_zmm(src));
               let rm = decode_rm_evex(modrm, pfx, 32);
               match rm { RM_reg(_) => { write_ymm(evex_rm_reg_idx(modrm, pfx), res); Ok(()) },
                           RM_mem(addr) => { mem_write256(fixup_addr(addr), res); Ok(()) } } },
        1 => { let res = avx_pmovusdw_256(read_ymm(src));
               let rm = decode_rm_evex(modrm, pfx, 16);
               match rm { RM_reg(_) => { write_xmm(evex_rm_reg_idx(modrm, pfx), res); Ok(()) },
                           RM_mem(addr) => { mem_write128(fixup_addr(addr), res); Ok(()) } } },
        _ => { let res = avx_pmovusdw_128(read_xmm(src));
               let rm = decode_rm_evex(modrm, pfx, 8);
               match rm { RM_reg(_) => { write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)); Ok(()) },
                           RM_mem(addr) => { mem_write64(fixup_addr(addr), res); Ok(()) } } },
      }
    } else raise_UD()
  },

  // 0F38 14: VPRORVD (66,W0) / VPRORVQ (66,W1) [F] / VPMOVUSQW (F3) [F]
  20 => {
    let modrm = fetch_byte();
    if mp == MP_66 then {
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let src1_idx = pfx.evex_vvvvv;
      if pfx.rex_w then { // VPRORVQ
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_prorvq_512(read_zmm(src1_idx), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
          1 => { write_ymm(dst, avx_prorvq_256(read_ymm(src1_idx), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
          _ => { write_xmm(dst, avx_prorvq_128(read_xmm(src1_idx), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
        }
      } else { // VPRORVD
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_prorvd_512(read_zmm(src1_idx), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
          1 => { write_ymm(dst, avx_prorvd_256(read_ymm(src1_idx), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
          _ => { write_xmm(dst, avx_prorvd_128(read_xmm(src1_idx), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
        }
      }
    } else if mp == MP_F3 then {
      // VPMOVUSQW: src=reg, dst=r/m (narrowing: qword->word)
      let src = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => { let res = avx_pmovusqw_512(read_zmm(src));
               let rm = decode_rm_evex(modrm, pfx, 16);
               match rm { RM_reg(_) => { write_xmm(evex_rm_reg_idx(modrm, pfx), res); Ok(()) },
                           RM_mem(addr) => { mem_write128(fixup_addr(addr), res); Ok(()) } } },
        1 => { let res = avx_pmovusqw_256(read_ymm(src));
               let rm = decode_rm_evex(modrm, pfx, 8);
               match rm { RM_reg(_) => { write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)); Ok(()) },
                           RM_mem(addr) => { mem_write64(fixup_addr(addr), res); Ok(()) } } },
        _ => { let res = avx_pmovusqw_128(read_xmm(src));
               let rm = decode_rm_evex(modrm, pfx, 4);
               match rm { RM_reg(_) => { write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)); Ok(()) },
                           RM_mem(addr) => { mem_write32(fixup_addr(addr), res); Ok(()) } } },
      }
    } else raise_UD()
  },

  // 0F38 15: VPROLVD (66,W0) / VPROLVQ (66,W1) [F] / VPMOVUSQD (F3) [F]
  21 => {
    let modrm = fetch_byte();
    if mp == MP_66 then {
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let src1_idx = pfx.evex_vvvvv;
      if pfx.rex_w then { // VPROLVQ
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_prolvq_512(read_zmm(src1_idx), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
          1 => { write_ymm(dst, avx_prolvq_256(read_ymm(src1_idx), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
          _ => { write_xmm(dst, avx_prolvq_128(read_xmm(src1_idx), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
        }
      } else { // VPROLVD
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_prolvd_512(read_zmm(src1_idx), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
          1 => { write_ymm(dst, avx_prolvd_256(read_ymm(src1_idx), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
          _ => { write_xmm(dst, avx_prolvd_128(read_xmm(src1_idx), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
        }
      }
    } else if mp == MP_F3 then {
      // VPMOVUSQD: src=reg, dst=r/m (narrowing: qword->dword)
      let src = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => { let res = avx_pmovusqd_512(read_zmm(src));
               let rm = decode_rm_evex(modrm, pfx, 32);
               match rm { RM_reg(_) => { write_ymm(evex_rm_reg_idx(modrm, pfx), res); Ok(()) },
                           RM_mem(addr) => { mem_write256(fixup_addr(addr), res); Ok(()) } } },
        1 => { let res = avx_pmovusqd_256(read_ymm(src));
               let rm = decode_rm_evex(modrm, pfx, 16);
               match rm { RM_reg(_) => { write_xmm(evex_rm_reg_idx(modrm, pfx), res); Ok(()) },
                           RM_mem(addr) => { mem_write128(fixup_addr(addr), res); Ok(()) } } },
        _ => { let res = avx_pmovusqd_128(read_xmm(src));
               let rm = decode_rm_evex(modrm, pfx, 8);
               match rm { RM_reg(_) => { write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)); Ok(()) },
                           RM_mem(addr) => { mem_write64(fixup_addr(addr), res); Ok(()) } } },
      }
    } else raise_UD()
  },

  // 0F38 20: VPMOVSXBW (66) [BW] / VPMOVSWB (F3) [BW]
  32 => {
    let modrm = fetch_byte();
    if mp == MP_66 then {
      let dst = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => {
          let rm = decode_rm_evex(modrm, pfx, 32);
          let src : ymmword = match rm {
            RM_reg(_) => read_ymm(evex_rm_reg_idx(modrm, pfx)),
            RM_mem(addr) => mem_read256(fixup_addr(addr)),
          };
          write_zmm(dst, avx_pmovsxbw_512(src)); Ok(())
        },
        1 => {
          let rm = decode_rm_evex(modrm, pfx, 16);
          let src : xmmword = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx)),
            RM_mem(addr) => mem_read128(fixup_addr(addr)),
          };
          write_ymm(dst, avx_pmovsxbw_256(src)); Ok(())
        },
        _ => {
          let rm = decode_rm_evex(modrm, pfx, 8);
          let src : qword = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
            RM_mem(addr) => mem_read64(fixup_addr(addr)),
          };
          write_xmm(dst, avx_pmovsxbw_128(src)); Ok(())
        },
      }
    } else if mp == MP_F3 then {
      // VPMOVSWB: src=reg, dst=r/m (narrowing: word->byte, signed saturation)
      let src = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => { let res = avx_pmovswb_512(read_zmm(src));
               let rm = decode_rm_evex(modrm, pfx, 32);
               match rm { RM_reg(_) => { write_ymm(evex_rm_reg_idx(modrm, pfx), res); Ok(()) },
                           RM_mem(addr) => { mem_write256(fixup_addr(addr), res); Ok(()) } } },
        1 => { let res = avx_pmovswb_256(read_ymm(src));
               let rm = decode_rm_evex(modrm, pfx, 16);
               match rm { RM_reg(_) => { write_xmm(evex_rm_reg_idx(modrm, pfx), res); Ok(()) },
                           RM_mem(addr) => { mem_write128(fixup_addr(addr), res); Ok(()) } } },
        _ => { let res = avx_pmovswb_128(read_xmm(src));
               let rm = decode_rm_evex(modrm, pfx, 8);
               match rm { RM_reg(_) => { write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)); Ok(()) },
                           RM_mem(addr) => { mem_write64(fixup_addr(addr), res); Ok(()) } } },
      }
    } else raise_UD()
  },

  // 0F38 21: VPMOVSXBD (66) [F] / VPMOVSDB (F3) [F]
  33 => {
    let modrm = fetch_byte();
    if mp == MP_66 then {
      let dst = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => {
          let rm = decode_rm_evex(modrm, pfx, 16);
          let src : xmmword = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx)),
            RM_mem(addr) => mem_read128(fixup_addr(addr)),
          };
          write_zmm(dst, avx_pmovsxbd_512(src)); Ok(())
        },
        1 => {
          let rm = decode_rm_evex(modrm, pfx, 8);
          let src : qword = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
            RM_mem(addr) => mem_read64(fixup_addr(addr)),
          };
          write_ymm(dst, avx_pmovsxbd_256(src)); Ok(())
        },
        _ => {
          let rm = decode_rm_evex(modrm, pfx, 4);
          let src : dword = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
            RM_mem(addr) => mem_read32(fixup_addr(addr)),
          };
          write_xmm(dst, avx_pmovsxbd_128(src)); Ok(())
        },
      }
    } else if mp == MP_F3 then {
      // VPMOVSDB: src=reg, dst=r/m (narrowing: dword->byte, signed saturation)
      let src = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => { let res = avx_pmovsdb_512(read_zmm(src));
               let rm = decode_rm_evex(modrm, pfx, 16);
               match rm { RM_reg(_) => { write_xmm(evex_rm_reg_idx(modrm, pfx), res); Ok(()) },
                           RM_mem(addr) => { mem_write128(fixup_addr(addr), res); Ok(()) } } },
        1 => { let res = avx_pmovsdb_256(read_ymm(src));
               let rm = decode_rm_evex(modrm, pfx, 8);
               match rm { RM_reg(_) => { write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)); Ok(()) },
                           RM_mem(addr) => { mem_write64(fixup_addr(addr), res); Ok(()) } } },
        _ => { let res = avx_pmovsdb_128(read_xmm(src));
               let rm = decode_rm_evex(modrm, pfx, 4);
               match rm { RM_reg(_) => { write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)); Ok(()) },
                           RM_mem(addr) => { mem_write32(fixup_addr(addr), res); Ok(()) } } },
      }
    } else raise_UD()
  },

  // 0F38 22: VPMOVSXBQ (66) [F] / VPMOVSQB (F3) [F]
  34 => {
    let modrm = fetch_byte();
    if mp == MP_66 then {
      let dst = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => {
          let rm = decode_rm_evex(modrm, pfx, 8);
          let src : qword = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
            RM_mem(addr) => mem_read64(fixup_addr(addr)),
          };
          write_zmm(dst, avx_pmovsxbq_512(src)); Ok(())
        },
        1 => {
          let rm = decode_rm_evex(modrm, pfx, 4);
          let src : dword = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
            RM_mem(addr) => mem_read32(fixup_addr(addr)),
          };
          write_ymm(dst, avx_pmovsxbq_256(src)); Ok(())
        },
        _ => {
          // disp_n=2 is below decode_rm_evex minimum, use decode_rm
          let rm = decode_rm(modrm, pfx);
          let src : word = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[15..0],
            RM_mem(addr) => mem_read16(fixup_addr(addr)),
          };
          write_xmm(dst, avx_pmovsxbq_128(src)); Ok(())
        },
      }
    } else if mp == MP_F3 then {
      // VPMOVSQB: src=reg, dst=r/m (narrowing: qword->byte, signed saturation)
      let src = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => { let res = avx_pmovsqb_512(read_zmm(src));
               let rm = decode_rm_evex(modrm, pfx, 8);
               match rm { RM_reg(_) => { write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)); Ok(()) },
                           RM_mem(addr) => { mem_write64(fixup_addr(addr), res); Ok(()) } } },
        1 => { let res = avx_pmovsqb_256(read_ymm(src));
               let rm = decode_rm_evex(modrm, pfx, 4);
               match rm { RM_reg(_) => { write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)); Ok(()) },
                           RM_mem(addr) => { mem_write32(fixup_addr(addr), res); Ok(()) } } },
        _ => { let res = avx_pmovsqb_128(read_xmm(src));
               let rm = decode_rm(modrm, pfx);
               match rm { RM_reg(_) => { write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)); Ok(()) },
                           RM_mem(addr) => { mem_write16(fixup_addr(addr), res); Ok(()) } } },
      }
    } else raise_UD()
  },

  // 0F38 23: VPMOVSXWD (66) [F] / VPMOVSDW (F3) [F]
  35 => {
    let modrm = fetch_byte();
    if mp == MP_66 then {
      let dst = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => {
          let rm = decode_rm_evex(modrm, pfx, 32);
          let src : ymmword = match rm {
            RM_reg(_) => read_ymm(evex_rm_reg_idx(modrm, pfx)),
            RM_mem(addr) => mem_read256(fixup_addr(addr)),
          };
          write_zmm(dst, avx_pmovsxwd_512(src)); Ok(())
        },
        1 => {
          let rm = decode_rm_evex(modrm, pfx, 16);
          let src : xmmword = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx)),
            RM_mem(addr) => mem_read128(fixup_addr(addr)),
          };
          write_ymm(dst, avx_pmovsxwd_256(src)); Ok(())
        },
        _ => {
          let rm = decode_rm_evex(modrm, pfx, 8);
          let src : qword = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
            RM_mem(addr) => mem_read64(fixup_addr(addr)),
          };
          write_xmm(dst, avx_pmovsxwd_128(src)); Ok(())
        },
      }
    } else if mp == MP_F3 then {
      // VPMOVSDW: src=reg, dst=r/m (narrowing: dword->word, signed saturation)
      let src = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => { let res = avx_pmovsdw_512(read_zmm(src));
               let rm = decode_rm_evex(modrm, pfx, 32);
               match rm { RM_reg(_) => { write_ymm(evex_rm_reg_idx(modrm, pfx), res); Ok(()) },
                           RM_mem(addr) => { mem_write256(fixup_addr(addr), res); Ok(()) } } },
        1 => { let res = avx_pmovsdw_256(read_ymm(src));
               let rm = decode_rm_evex(modrm, pfx, 16);
               match rm { RM_reg(_) => { write_xmm(evex_rm_reg_idx(modrm, pfx), res); Ok(()) },
                           RM_mem(addr) => { mem_write128(fixup_addr(addr), res); Ok(()) } } },
        _ => { let res = avx_pmovsdw_128(read_xmm(src));
               let rm = decode_rm_evex(modrm, pfx, 8);
               match rm { RM_reg(_) => { write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)); Ok(()) },
                           RM_mem(addr) => { mem_write64(fixup_addr(addr), res); Ok(()) } } },
      }
    } else raise_UD()
  },

  // 0F38 24: VPMOVSXWQ (66) [F] / VPMOVSQW (F3) [F]
  36 => {
    let modrm = fetch_byte();
    if mp == MP_66 then {
      let dst = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => {
          let rm = decode_rm_evex(modrm, pfx, 16);
          let src : xmmword = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx)),
            RM_mem(addr) => mem_read128(fixup_addr(addr)),
          };
          write_zmm(dst, avx_pmovsxwq_512(src)); Ok(())
        },
        1 => {
          let rm = decode_rm_evex(modrm, pfx, 8);
          let src : qword = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
            RM_mem(addr) => mem_read64(fixup_addr(addr)),
          };
          write_ymm(dst, avx_pmovsxwq_256(src)); Ok(())
        },
        _ => {
          let rm = decode_rm_evex(modrm, pfx, 4);
          let src : dword = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
            RM_mem(addr) => mem_read32(fixup_addr(addr)),
          };
          write_xmm(dst, avx_pmovsxwq_128(src)); Ok(())
        },
      }
    } else if mp == MP_F3 then {
      // VPMOVSQW: src=reg, dst=r/m (narrowing: qword->word, signed saturation)
      let src = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => { let res = avx_pmovsqw_512(read_zmm(src));
               let rm = decode_rm_evex(modrm, pfx, 16);
               match rm { RM_reg(_) => { write_xmm(evex_rm_reg_idx(modrm, pfx), res); Ok(()) },
                           RM_mem(addr) => { mem_write128(fixup_addr(addr), res); Ok(()) } } },
        1 => { let res = avx_pmovsqw_256(read_ymm(src));
               let rm = decode_rm_evex(modrm, pfx, 8);
               match rm { RM_reg(_) => { write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)); Ok(()) },
                           RM_mem(addr) => { mem_write64(fixup_addr(addr), res); Ok(()) } } },
        _ => { let res = avx_pmovsqw_128(read_xmm(src));
               let rm = decode_rm_evex(modrm, pfx, 4);
               match rm { RM_reg(_) => { write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)); Ok(()) },
                           RM_mem(addr) => { mem_write32(fixup_addr(addr), res); Ok(()) } } },
      }
    } else raise_UD()
  },

  // 0F38 25: VPMOVSXDQ (66) [F] / VPMOVSQD (F3) [F]
  37 => {
    let modrm = fetch_byte();
    if mp == MP_66 then {
      let dst = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => {
          let rm = decode_rm_evex(modrm, pfx, 32);
          let src : ymmword = match rm {
            RM_reg(_) => read_ymm(evex_rm_reg_idx(modrm, pfx)),
            RM_mem(addr) => mem_read256(fixup_addr(addr)),
          };
          write_zmm(dst, avx_pmovsxdq_512(src)); Ok(())
        },
        1 => {
          let rm = decode_rm_evex(modrm, pfx, 16);
          let src : xmmword = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx)),
            RM_mem(addr) => mem_read128(fixup_addr(addr)),
          };
          write_ymm(dst, avx_pmovsxdq_256(src)); Ok(())
        },
        _ => {
          let rm = decode_rm_evex(modrm, pfx, 8);
          let src : qword = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
            RM_mem(addr) => mem_read64(fixup_addr(addr)),
          };
          write_xmm(dst, avx_pmovsxdq_128(src)); Ok(())
        },
      }
    } else if mp == MP_F3 then {
      // VPMOVSQD: src=reg, dst=r/m (narrowing: qword->dword, signed saturation)
      let src = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => { let res = avx_pmovsqd_512(read_zmm(src));
               let rm = decode_rm_evex(modrm, pfx, 32);
               match rm { RM_reg(_) => { write_ymm(evex_rm_reg_idx(modrm, pfx), res); Ok(()) },
                           RM_mem(addr) => { mem_write256(fixup_addr(addr), res); Ok(()) } } },
        1 => { let res = avx_pmovsqd_256(read_ymm(src));
               let rm = decode_rm_evex(modrm, pfx, 16);
               match rm { RM_reg(_) => { write_xmm(evex_rm_reg_idx(modrm, pfx), res); Ok(()) },
                           RM_mem(addr) => { mem_write128(fixup_addr(addr), res); Ok(()) } } },
        _ => { let res = avx_pmovsqd_128(read_xmm(src));
               let rm = decode_rm_evex(modrm, pfx, 8);
               match rm { RM_reg(_) => { write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)); Ok(()) },
                           RM_mem(addr) => { mem_write64(fixup_addr(addr), res); Ok(()) } } },
      }
    } else raise_UD()
  },

  // 0F38 30: VPMOVZXBW (66) [BW] / VPMOVWB (F3) [BW]
  48 => {
    let modrm = fetch_byte();
    if mp == MP_66 then {
      let dst = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => {
          let rm = decode_rm_evex(modrm, pfx, 32);
          let src : ymmword = match rm {
            RM_reg(_) => read_ymm(evex_rm_reg_idx(modrm, pfx)),
            RM_mem(addr) => mem_read256(fixup_addr(addr)),
          };
          write_zmm(dst, avx_pmovzxbw_512(src)); Ok(())
        },
        1 => {
          let rm = decode_rm_evex(modrm, pfx, 16);
          let src : xmmword = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx)),
            RM_mem(addr) => mem_read128(fixup_addr(addr)),
          };
          write_ymm(dst, avx_pmovzxbw_256(src)); Ok(())
        },
        _ => {
          let rm = decode_rm_evex(modrm, pfx, 8);
          let src : qword = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
            RM_mem(addr) => mem_read64(fixup_addr(addr)),
          };
          write_xmm(dst, avx_pmovzxbw_128(src)); Ok(())
        },
      }
    } else if mp == MP_F3 then {
      // VPMOVWB: src=reg, dst=r/m (narrowing: word->byte, truncation)
      let src = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => { let res = avx_pmovwb_512(read_zmm(src));
               let rm = decode_rm_evex(modrm, pfx, 32);
               match rm { RM_reg(_) => { write_ymm(evex_rm_reg_idx(modrm, pfx), res); Ok(()) },
                           RM_mem(addr) => { mem_write256(fixup_addr(addr), res); Ok(()) } } },
        1 => { let res = avx_pmovwb_256(read_ymm(src));
               let rm = decode_rm_evex(modrm, pfx, 16);
               match rm { RM_reg(_) => { write_xmm(evex_rm_reg_idx(modrm, pfx), res); Ok(()) },
                           RM_mem(addr) => { mem_write128(fixup_addr(addr), res); Ok(()) } } },
        _ => { let res = avx_pmovwb_128(read_xmm(src));
               let rm = decode_rm_evex(modrm, pfx, 8);
               match rm { RM_reg(_) => { write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)); Ok(()) },
                           RM_mem(addr) => { mem_write64(fixup_addr(addr), res); Ok(()) } } },
      }
    } else raise_UD()
  },

  // 0F38 31: VPMOVZXBD (66) [F] / VPMOVDB (F3) [F]
  49 => {
    let modrm = fetch_byte();
    if mp == MP_66 then {
      let dst = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => {
          let rm = decode_rm_evex(modrm, pfx, 16);
          let src : xmmword = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx)),
            RM_mem(addr) => mem_read128(fixup_addr(addr)),
          };
          write_zmm(dst, avx_pmovzxbd_512(src)); Ok(())
        },
        1 => {
          let rm = decode_rm_evex(modrm, pfx, 8);
          let src : qword = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
            RM_mem(addr) => mem_read64(fixup_addr(addr)),
          };
          write_ymm(dst, avx_pmovzxbd_256(src)); Ok(())
        },
        _ => {
          let rm = decode_rm_evex(modrm, pfx, 4);
          let src : dword = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
            RM_mem(addr) => mem_read32(fixup_addr(addr)),
          };
          write_xmm(dst, avx_pmovzxbd_128(src)); Ok(())
        },
      }
    } else if mp == MP_F3 then {
      // VPMOVDB: src=reg, dst=r/m (narrowing: dword->byte, truncation)
      let src = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => { let res = avx_pmovdb_512(read_zmm(src));
               let rm = decode_rm_evex(modrm, pfx, 16);
               match rm { RM_reg(_) => { write_xmm(evex_rm_reg_idx(modrm, pfx), res); Ok(()) },
                           RM_mem(addr) => { mem_write128(fixup_addr(addr), res); Ok(()) } } },
        1 => { let res = avx_pmovdb_256(read_ymm(src));
               let rm = decode_rm_evex(modrm, pfx, 8);
               match rm { RM_reg(_) => { write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)); Ok(()) },
                           RM_mem(addr) => { mem_write64(fixup_addr(addr), res); Ok(()) } } },
        _ => { let res = avx_pmovdb_128(read_xmm(src));
               let rm = decode_rm_evex(modrm, pfx, 4);
               match rm { RM_reg(_) => { write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)); Ok(()) },
                           RM_mem(addr) => { mem_write32(fixup_addr(addr), res); Ok(()) } } },
      }
    } else raise_UD()
  },

  // 0F38 32: VPMOVZXBQ (66) [F] / VPMOVQB (F3) [F]
  50 => {
    let modrm = fetch_byte();
    if mp == MP_66 then {
      let dst = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => {
          let rm = decode_rm_evex(modrm, pfx, 8);
          let src : qword = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
            RM_mem(addr) => mem_read64(fixup_addr(addr)),
          };
          write_zmm(dst, avx_pmovzxbq_512(src)); Ok(())
        },
        1 => {
          let rm = decode_rm_evex(modrm, pfx, 4);
          let src : dword = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
            RM_mem(addr) => mem_read32(fixup_addr(addr)),
          };
          write_ymm(dst, avx_pmovzxbq_256(src)); Ok(())
        },
        _ => {
          let rm = decode_rm(modrm, pfx);
          let src : word = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[15..0],
            RM_mem(addr) => mem_read16(fixup_addr(addr)),
          };
          write_xmm(dst, avx_pmovzxbq_128(src)); Ok(())
        },
      }
    } else if mp == MP_F3 then {
      // VPMOVQB: src=reg, dst=r/m (narrowing: qword->byte, truncation)
      let src = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => { let res = avx_pmovqb_512(read_zmm(src));
               let rm = decode_rm_evex(modrm, pfx, 8);
               match rm { RM_reg(_) => { write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)); Ok(()) },
                           RM_mem(addr) => { mem_write64(fixup_addr(addr), res); Ok(()) } } },
        1 => { let res = avx_pmovqb_256(read_ymm(src));
               let rm = decode_rm_evex(modrm, pfx, 4);
               match rm { RM_reg(_) => { write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)); Ok(()) },
                           RM_mem(addr) => { mem_write32(fixup_addr(addr), res); Ok(()) } } },
        _ => { let res = avx_pmovqb_128(read_xmm(src));
               let rm = decode_rm(modrm, pfx);
               match rm { RM_reg(_) => { write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)); Ok(()) },
                           RM_mem(addr) => { mem_write16(fixup_addr(addr), res); Ok(()) } } },
      }
    } else raise_UD()
  },

  // 0F38 33: VPMOVZXWD (66) [F] / VPMOVDW (F3) [F]
  51 => {
    let modrm = fetch_byte();
    if mp == MP_66 then {
      let dst = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => {
          let rm = decode_rm_evex(modrm, pfx, 32);
          let src : ymmword = match rm {
            RM_reg(_) => read_ymm(evex_rm_reg_idx(modrm, pfx)),
            RM_mem(addr) => mem_read256(fixup_addr(addr)),
          };
          write_zmm(dst, avx_pmovzxwd_512(src)); Ok(())
        },
        1 => {
          let rm = decode_rm_evex(modrm, pfx, 16);
          let src : xmmword = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx)),
            RM_mem(addr) => mem_read128(fixup_addr(addr)),
          };
          write_ymm(dst, avx_pmovzxwd_256(src)); Ok(())
        },
        _ => {
          let rm = decode_rm_evex(modrm, pfx, 8);
          let src : qword = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
            RM_mem(addr) => mem_read64(fixup_addr(addr)),
          };
          write_xmm(dst, avx_pmovzxwd_128(src)); Ok(())
        },
      }
    } else if mp == MP_F3 then {
      // VPMOVDW: src=reg, dst=r/m (narrowing: dword->word, truncation)
      let src = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => { let res = avx_pmovdw_512(read_zmm(src));
               let rm = decode_rm_evex(modrm, pfx, 32);
               match rm { RM_reg(_) => { write_ymm(evex_rm_reg_idx(modrm, pfx), res); Ok(()) },
                           RM_mem(addr) => { mem_write256(fixup_addr(addr), res); Ok(()) } } },
        1 => { let res = avx_pmovdw_256(read_ymm(src));
               let rm = decode_rm_evex(modrm, pfx, 16);
               match rm { RM_reg(_) => { write_xmm(evex_rm_reg_idx(modrm, pfx), res); Ok(()) },
                           RM_mem(addr) => { mem_write128(fixup_addr(addr), res); Ok(()) } } },
        _ => { let res = avx_pmovdw_128(read_xmm(src));
               let rm = decode_rm_evex(modrm, pfx, 8);
               match rm { RM_reg(_) => { write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)); Ok(()) },
                           RM_mem(addr) => { mem_write64(fixup_addr(addr), res); Ok(()) } } },
      }
    } else raise_UD()
  },

  // 0F38 34: VPMOVZXWQ (66) [F] / VPMOVQW (F3) [F]
  52 => {
    let modrm = fetch_byte();
    if mp == MP_66 then {
      let dst = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => {
          let rm = decode_rm_evex(modrm, pfx, 16);
          let src : xmmword = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx)),
            RM_mem(addr) => mem_read128(fixup_addr(addr)),
          };
          write_zmm(dst, avx_pmovzxwq_512(src)); Ok(())
        },
        1 => {
          let rm = decode_rm_evex(modrm, pfx, 8);
          let src : qword = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
            RM_mem(addr) => mem_read64(fixup_addr(addr)),
          };
          write_ymm(dst, avx_pmovzxwq_256(src)); Ok(())
        },
        _ => {
          let rm = decode_rm_evex(modrm, pfx, 4);
          let src : dword = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
            RM_mem(addr) => mem_read32(fixup_addr(addr)),
          };
          write_xmm(dst, avx_pmovzxwq_128(src)); Ok(())
        },
      }
    } else if mp == MP_F3 then {
      // VPMOVQW: src=reg, dst=r/m (narrowing: qword->word, truncation)
      let src = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => { let res = avx_pmovqw_512(read_zmm(src));
               let rm = decode_rm_evex(modrm, pfx, 16);
               match rm { RM_reg(_) => { write_xmm(evex_rm_reg_idx(modrm, pfx), res); Ok(()) },
                           RM_mem(addr) => { mem_write128(fixup_addr(addr), res); Ok(()) } } },
        1 => { let res = avx_pmovqw_256(read_ymm(src));
               let rm = decode_rm_evex(modrm, pfx, 8);
               match rm { RM_reg(_) => { write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)); Ok(()) },
                           RM_mem(addr) => { mem_write64(fixup_addr(addr), res); Ok(()) } } },
        _ => { let res = avx_pmovqw_128(read_xmm(src));
               let rm = decode_rm_evex(modrm, pfx, 4);
               match rm { RM_reg(_) => { write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)); Ok(()) },
                           RM_mem(addr) => { mem_write32(fixup_addr(addr), res); Ok(()) } } },
      }
    } else raise_UD()
  },

  // 0F38 45: VPSRLVD (66,W0) / VPSRLVQ (66,W1) [F]
  69 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let src1_idx = pfx.evex_vvvvv;
      if pfx.rex_w then { // VPSRLVQ
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_psrlvq_512(read_zmm(src1_idx), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
          1 => { write_ymm(dst, avx_psrlvq_256(read_ymm(src1_idx), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
          _ => { write_xmm(dst, avx_psrlvq_128(read_xmm(src1_idx), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
        }
      } else { // VPSRLVD
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_psrlvd_512(read_zmm(src1_idx), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
          1 => { write_ymm(dst, avx_psrlvd_256(read_ymm(src1_idx), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
          _ => { write_xmm(dst, avx_psrlvd_128(read_xmm(src1_idx), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
        }
      }
    }
  },

  // 0F38 46: VPSRAVD (66,W0) / VPSRAVQ (66,W1) [F]
  70 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let src1_idx = pfx.evex_vvvvv;
      if pfx.rex_w then { // VPSRAVQ
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_psravq_512(read_zmm(src1_idx), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
          1 => { write_ymm(dst, avx_psravq_256(read_ymm(src1_idx), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
          _ => { write_xmm(dst, avx_psravq_128(read_xmm(src1_idx), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
        }
      } else { // VPSRAVD
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_psravd_512(read_zmm(src1_idx), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
          1 => { write_ymm(dst, avx_psravd_256(read_ymm(src1_idx), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
          _ => { write_xmm(dst, avx_psravd_128(read_xmm(src1_idx), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
        }
      }
    }
  },

  // 0F38 47: VPSLLVD (66,W0) / VPSLLVQ (66,W1) [F]
  71 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let src1_idx = pfx.evex_vvvvv;
      if pfx.rex_w then { // VPSLLVQ
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_psllvq_512(read_zmm(src1_idx), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
          1 => { write_ymm(dst, avx_psllvq_256(read_ymm(src1_idx), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
          _ => { write_xmm(dst, avx_psllvq_128(read_xmm(src1_idx), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
        }
      } else { // VPSLLVD
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_psllvd_512(read_zmm(src1_idx), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
          1 => { write_ymm(dst, avx_psllvd_256(read_ymm(src1_idx), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
          _ => { write_xmm(dst, avx_psllvd_128(read_xmm(src1_idx), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
        }
      }
    }
  },

  // 0F38 76: VPERMI2D (66,W0) / VPERMI2Q (66,W1) [F]
  118 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let src1_idx = pfx.evex_vvvvv;
      if pfx.rex_w then { // VPERMI2Q
        match pfx.evex_ll {
          2 => { let idx = read_zmm(dst); write_zmm(dst, avx_vperm2_q_512(read_zmm(src1_idx), evex_src_zmm(modrm, rm, pfx), idx)); Ok(()) },
          1 => { let idx = read_ymm(dst); write_ymm(dst, avx_vperm2_q_256(read_ymm(src1_idx), evex_src_ymm(modrm, rm, pfx), idx)); Ok(()) },
          _ => { let idx = read_xmm(dst); write_xmm(dst, avx_vperm2_q_128(read_xmm(src1_idx), evex_src_xmm(modrm, rm, pfx), idx)); Ok(()) },
        }
      } else { // VPERMI2D
        match pfx.evex_ll {
          2 => { let idx = read_zmm(dst); write_zmm(dst, avx_vperm2_d_512(read_zmm(src1_idx), evex_src_zmm(modrm, rm, pfx), idx)); Ok(()) },
          1 => { let idx = read_ymm(dst); write_ymm(dst, avx_vperm2_d_256(read_ymm(src1_idx), evex_src_ymm(modrm, rm, pfx), idx)); Ok(()) },
          _ => { let idx = read_xmm(dst); write_xmm(dst, avx_vperm2_d_128(read_xmm(src1_idx), evex_src_xmm(modrm, rm, pfx), idx)); Ok(()) },
        }
      }
    }
  },

  // 0F38 77: VPERMI2PS (66,W0) / VPERMI2PD (66,W1) [F]
  119 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let src1_idx = pfx.evex_vvvvv;
      if pfx.rex_w then { // VPERMI2PD (same as Q)
        match pfx.evex_ll {
          2 => { let idx = read_zmm(dst); write_zmm(dst, avx_vperm2_q_512(read_zmm(src1_idx), evex_src_zmm(modrm, rm, pfx), idx)); Ok(()) },
          1 => { let idx = read_ymm(dst); write_ymm(dst, avx_vperm2_q_256(read_ymm(src1_idx), evex_src_ymm(modrm, rm, pfx), idx)); Ok(()) },
          _ => { let idx = read_xmm(dst); write_xmm(dst, avx_vperm2_q_128(read_xmm(src1_idx), evex_src_xmm(modrm, rm, pfx), idx)); Ok(()) },
        }
      } else { // VPERMI2PS (same as D)
        match pfx.evex_ll {
          2 => { let idx = read_zmm(dst); write_zmm(dst, avx_vperm2_d_512(read_zmm(src1_idx), evex_src_zmm(modrm, rm, pfx), idx)); Ok(()) },
          1 => { let idx = read_ymm(dst); write_ymm(dst, avx_vperm2_d_256(read_ymm(src1_idx), evex_src_ymm(modrm, rm, pfx), idx)); Ok(()) },
          _ => { let idx = read_xmm(dst); write_xmm(dst, avx_vperm2_d_128(read_xmm(src1_idx), evex_src_xmm(modrm, rm, pfx), idx)); Ok(()) },
        }
      }
    }
  },

  // 0F38 7E: VPERMT2D (66,W0) / VPERMT2Q (66,W1) [F]
  126 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let idx_reg = pfx.evex_vvvvv;
      if pfx.rex_w then { // VPERMT2Q
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_vperm2_q_512(read_zmm(dst), evex_src_zmm(modrm, rm, pfx), read_zmm(idx_reg))); Ok(()) },
          1 => { write_ymm(dst, avx_vperm2_q_256(read_ymm(dst), evex_src_ymm(modrm, rm, pfx), read_ymm(idx_reg))); Ok(()) },
          _ => { write_xmm(dst, avx_vperm2_q_128(read_xmm(dst), evex_src_xmm(modrm, rm, pfx), read_xmm(idx_reg))); Ok(()) },
        }
      } else { // VPERMT2D
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_vperm2_d_512(read_zmm(dst), evex_src_zmm(modrm, rm, pfx), read_zmm(idx_reg))); Ok(()) },
          1 => { write_ymm(dst, avx_vperm2_d_256(read_ymm(dst), evex_src_ymm(modrm, rm, pfx), read_ymm(idx_reg))); Ok(()) },
          _ => { write_xmm(dst, avx_vperm2_d_128(read_xmm(dst), evex_src_xmm(modrm, rm, pfx), read_xmm(idx_reg))); Ok(()) },
        }
      }
    }
  },

  // 0F38 7F: VPERMT2PS (66,W0) / VPERMT2PD (66,W1) [F]
  127 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let idx_reg = pfx.evex_vvvvv;
      if pfx.rex_w then { // VPERMT2PD
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_vperm2_q_512(read_zmm(dst), evex_src_zmm(modrm, rm, pfx), read_zmm(idx_reg))); Ok(()) },
          1 => { write_ymm(dst, avx_vperm2_q_256(read_ymm(dst), evex_src_ymm(modrm, rm, pfx), read_ymm(idx_reg))); Ok(()) },
          _ => { write_xmm(dst, avx_vperm2_q_128(read_xmm(dst), evex_src_xmm(modrm, rm, pfx), read_xmm(idx_reg))); Ok(()) },
        }
      } else { // VPERMT2PS
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_vperm2_d_512(read_zmm(dst), evex_src_zmm(modrm, rm, pfx), read_zmm(idx_reg))); Ok(()) },
          1 => { write_ymm(dst, avx_vperm2_d_256(read_ymm(dst), evex_src_ymm(modrm, rm, pfx), read_ymm(idx_reg))); Ok(()) },
          _ => { write_xmm(dst, avx_vperm2_d_128(read_xmm(dst), evex_src_xmm(modrm, rm, pfx), read_xmm(idx_reg))); Ok(()) },
        }
      }
    }
  },

  // 0F38 35: VPMOVZXDQ (66) [F] / VPMOVQD (F3) [F]
  53 => {
    let modrm = fetch_byte();
    if mp == MP_66 then {
      let dst = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => {
          let rm = decode_rm_evex(modrm, pfx, 32);
          let src : ymmword = match rm {
            RM_reg(_) => read_ymm(evex_rm_reg_idx(modrm, pfx)),
            RM_mem(addr) => mem_read256(fixup_addr(addr)),
          };
          write_zmm(dst, avx_pmovzxdq_512(src)); Ok(())
        },
        1 => {
          let rm = decode_rm_evex(modrm, pfx, 16);
          let src : xmmword = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx)),
            RM_mem(addr) => mem_read128(fixup_addr(addr)),
          };
          write_ymm(dst, avx_pmovzxdq_256(src)); Ok(())
        },
        _ => {
          let rm = decode_rm_evex(modrm, pfx, 8);
          let src : qword = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
            RM_mem(addr) => mem_read64(fixup_addr(addr)),
          };
          write_xmm(dst, avx_pmovzxdq_128(src)); Ok(())
        },
      }
    } else if mp == MP_F3 then {
      // VPMOVQD: src=reg, dst=r/m (narrowing: qword->dword, truncation)
      let src = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => { let res = avx_pmovqd_512(read_zmm(src));
               let rm = decode_rm_evex(modrm, pfx, 32);
               match rm { RM_reg(_) => { write_ymm(evex_rm_reg_idx(modrm, pfx), res); Ok(()) },
                           RM_mem(addr) => { mem_write256(fixup_addr(addr), res); Ok(()) } } },
        1 => { let res = avx_pmovqd_256(read_ymm(src));
               let rm = decode_rm_evex(modrm, pfx, 16);
               match rm { RM_reg(_) => { write_xmm(evex_rm_reg_idx(modrm, pfx), res); Ok(()) },
                           RM_mem(addr) => { mem_write128(fixup_addr(addr), res); Ok(()) } } },
        _ => { let res = avx_pmovqd_128(read_xmm(src));
               let rm = decode_rm_evex(modrm, pfx, 8);
               match rm { RM_reg(_) => { write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)); Ok(()) },
                           RM_mem(addr) => { mem_write64(fixup_addr(addr), res); Ok(()) } } },
      }
    } else raise_UD()
  },

  // 0F38 7D: VPERMT2W (66,W1) [BW] / VPERMT2B (66,W0) [VBMI]
  125 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let idx_reg = pfx.evex_vvvvv;
      if pfx.rex_w then { // VPERMT2W
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_vperm2_w_512(read_zmm(dst), evex_src_zmm(modrm, rm, pfx), read_zmm(idx_reg))); Ok(()) },
          1 => { write_ymm(dst, avx_vperm2_w_256(read_ymm(dst), evex_src_ymm(modrm, rm, pfx), read_ymm(idx_reg))); Ok(()) },
          _ => { write_xmm(dst, avx_vperm2_w_128(read_xmm(dst), evex_src_xmm(modrm, rm, pfx), read_xmm(idx_reg))); Ok(()) },
        }
      } else { // VPERMT2B
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_vperm2_b_512(read_zmm(dst), evex_src_zmm(modrm, rm, pfx), read_zmm(idx_reg))); Ok(()) },
          1 => { write_ymm(dst, avx_vperm2_b_256(read_ymm(dst), evex_src_ymm(modrm, rm, pfx), read_ymm(idx_reg))); Ok(()) },
          _ => { write_xmm(dst, avx_vperm2_b_128(read_xmm(dst), evex_src_xmm(modrm, rm, pfx), read_xmm(idx_reg))); Ok(()) },
        }
      }
    }
  },

  // 0F38 62: VPEXPANDB (66,W0) / VPEXPANDW (66,W1) [VBMI2]
  98 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, 1);
      if pfx.rex_w then { // VPEXPANDW
        // Simplified: just load source and write to dst (no masking for now)
        match pfx.evex_ll {
          2 => { write_zmm(dst, evex_src_zmm(modrm, rm, pfx)); Ok(()) },
          1 => { write_ymm(dst, evex_src_ymm(modrm, rm, pfx)); Ok(()) },
          _ => { write_xmm(dst, evex_src_xmm(modrm, rm, pfx)); Ok(()) },
        }
      } else { // VPEXPANDB
        match pfx.evex_ll {
          2 => { write_zmm(dst, evex_src_zmm(modrm, rm, pfx)); Ok(()) },
          1 => { write_ymm(dst, evex_src_ymm(modrm, rm, pfx)); Ok(()) },
          _ => { write_xmm(dst, evex_src_xmm(modrm, rm, pfx)); Ok(()) },
        }
      }
    }
  },

  // 0F38 63: VPCOMPRESSB (66,W0) / VPCOMPRESSW (66,W1) [VBMI2]
  99 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let src = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, 1);
      // Simplified: just store source to rm
      match rm {
        RM_reg(_) => {
          match pfx.evex_ll {
            2 => { write_zmm(evex_rm_reg_idx(modrm, pfx), read_zmm(src)); Ok(()) },
            1 => { write_ymm(evex_rm_reg_idx(modrm, pfx), read_ymm(src)); Ok(()) },
            _ => { write_xmm(evex_rm_reg_idx(modrm, pfx), read_xmm(src)); Ok(()) },
          }
        },
        RM_mem(addr) => {
          match pfx.evex_ll {
            2 => { mem_write512(fixup_addr(addr), read_zmm(src)); Ok(()) },
            1 => { mem_write256(fixup_addr(addr), read_ymm(src)); Ok(()) },
            _ => { mem_write128(fixup_addr(addr), read_xmm(src)); Ok(()) },
          }
        },
      }
    }
  },

  // 0F38 70: VPSHLDVW (66, W=1) [VBMI2]
  112 => {
    if mp != MP_66 | not_bool(pfx.rex_w) then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_vpshldvw_512(read_zmm(dst), read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_vpshldvw_256(read_ymm(dst), read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_vpshldvw_128(read_xmm(dst), read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F38 71: VPSHLDVD (66, W=0) / VPSHLDVQ (66, W=1) [VBMI2]
  113 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      if pfx.rex_w then {
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_vpshldvq_512(read_zmm(dst), read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
          1 => { write_ymm(dst, avx_vpshldvq_256(read_ymm(dst), read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
          _ => { write_xmm(dst, avx_vpshldvq_128(read_xmm(dst), read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
        }
      } else {
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_vpshldvd_512(read_zmm(dst), read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
          1 => { write_ymm(dst, avx_vpshldvd_256(read_ymm(dst), read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
          _ => { write_xmm(dst, avx_vpshldvd_128(read_xmm(dst), read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
        }
      }
    }
  },

  // 0F38 72: VPSHRDVW (66, W=1) [VBMI2]
  114 => {
    if mp != MP_66 | not_bool(pfx.rex_w) then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_vpshrdvw_512(read_zmm(dst), read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_vpshrdvw_256(read_ymm(dst), read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_vpshrdvw_128(read_xmm(dst), read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F38 73: VPSHRDVD (66, W=0) / VPSHRDVQ (66, W=1) [VBMI2]
  115 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      if pfx.rex_w then {
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_vpshrdvq_512(read_zmm(dst), read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
          1 => { write_ymm(dst, avx_vpshrdvq_256(read_ymm(dst), read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
          _ => { write_xmm(dst, avx_vpshrdvq_128(read_xmm(dst), read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
        }
      } else {
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_vpshrdvd_512(read_zmm(dst), read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
          1 => { write_ymm(dst, avx_vpshrdvd_256(read_ymm(dst), read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
          _ => { write_xmm(dst, avx_vpshrdvd_128(read_xmm(dst), read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
        }
      }
    }
  },

  // 0F38 83: VPMULTISHIFTQB (66,W1) [VBMI]
  131 => {
    if mp != MP_66 | not_bool(pfx.rex_w) then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_vpmultishiftqb_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_vpmultishiftqb_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_vpmultishiftqb_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F38 8D: VPERMW (66,W1) [BW] / VPERMB (66,W0) [VBMI]
  141 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let ctrl = read_zmm(pfx.evex_vvvvv);
      if pfx.rex_w then { // VPERMW
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_vpermw_512(evex_src_zmm(modrm, rm, pfx), ctrl)); Ok(()) },
          1 => { write_ymm(dst, avx_vpermw_256(evex_src_ymm(modrm, rm, pfx), read_ymm(pfx.evex_vvvvv))); Ok(()) },
          _ => { write_xmm(dst, avx_vpermw_128(evex_src_xmm(modrm, rm, pfx), read_xmm(pfx.evex_vvvvv))); Ok(()) },
        }
      } else { // VPERMB
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_vpermb_512(evex_src_zmm(modrm, rm, pfx), ctrl)); Ok(()) },
          1 => { write_ymm(dst, avx_vpermb_256(evex_src_ymm(modrm, rm, pfx), read_ymm(pfx.evex_vvvvv))); Ok(()) },
          _ => { write_xmm(dst, avx_vpermb_128(evex_src_xmm(modrm, rm, pfx), read_xmm(pfx.evex_vvvvv))); Ok(()) },
        }
      }
    }
  },

  // 0F38 2A: VMOVNTDQA (66) [F] / VPBROADCASTMB2Q (F3,W1) [CD]
  42 => {
    if mp == MP_66 then {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, evex_src_zmm(modrm, rm, pfx)); Ok(()) },
        1 => { write_ymm(dst, evex_src_ymm(modrm, rm, pfx)); Ok(()) },
        _ => { write_xmm(dst, evex_src_xmm(modrm, rm, pfx)); Ok(()) },
      }
    } else if mp == MP_F3 then {
      if pfx.rex_w then {
        // VPBROADCASTMB2Q: broadcast low byte of k-register to all qword elements
        let modrm = fetch_byte();
        let dst = evex_reg_idx(modrm, pfx);
        let k_idx : kreg_idx = unsigned(modrm[2..0]);
        let k_val = read_kreg(k_idx);
        let b : byte = k_val[7..0];
        let q : qword = zero_extend(b);
        match pfx.evex_ll {
          2 => { write_zmm(dst, q @ q @ q @ q @ q @ q @ q @ q); Ok(()) },
          1 => { write_ymm(dst, q @ q @ q @ q); Ok(()) },
          _ => { write_xmm(dst, q @ q); Ok(()) },
        }
      } else raise_UD()
    } else raise_UD()
  },

  // 0F38 8F: VPSHUFBITQMB (66,W0) [BITALG]
  143 => {
    if mp != MP_66 | pfx.rex_w then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst_k : range(0, 7) = unsigned(modrm[5..3]);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { let r = avx_vpshufbitqmb_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx));
               write_kreg(dst_k, r); Ok(()) },
        1 => { let r = avx_vpshufbitqmb_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx));
               write_kreg(dst_k, zero_extend(r)); Ok(()) },
        _ => { let r = avx_vpshufbitqmb_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx));
               write_kreg(dst_k, zero_extend(r)); Ok(()) },
      }
    }
  },

  // =====================================================================
  // Gather (0x90-0x93) — VSIB addressing
  // =====================================================================

  // 0F38 90: VPGATHERDD (66,W0) / VPGATHERDQ (66,W1) [F]
  144 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let vsib = decode_vsib_evex(modrm, pfx, 4);
      if pfx.rex_w then { // VPGATHERDQ: dword indices, qword elements
        match pfx.evex_ll {
          2 => exec_gather_d64_512(dst, vsib, pfx.evex_aaa),
          1 => exec_gather_d64_256(dst, vsib, pfx.evex_aaa),
          _ => exec_gather_d64_128(dst, vsib, pfx.evex_aaa),
        }
      } else { // VPGATHERDD: dword indices, dword elements
        match pfx.evex_ll {
          2 => exec_gather_d32_512(dst, vsib, pfx.evex_aaa),
          1 => exec_gather_d32_256(dst, vsib, pfx.evex_aaa),
          _ => exec_gather_d32_128(dst, vsib, pfx.evex_aaa),
        }
      }
    }
  },

  // 0F38 91: VPGATHERQD (66,W0) / VPGATHERQQ (66,W1) [F]
  145 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let vsib = decode_vsib_evex(modrm, pfx, 4);
      if pfx.rex_w then { // VPGATHERQQ: qword indices, qword elements
        match pfx.evex_ll {
          2 => exec_gather_q64_512(dst, vsib, pfx.evex_aaa),
          1 => exec_gather_q64_256(dst, vsib, pfx.evex_aaa),
          _ => exec_gather_q64_128(dst, vsib, pfx.evex_aaa),
        }
      } else { // VPGATHERQD: qword indices, dword elements
        match pfx.evex_ll {
          2 => exec_gather_q32_512(dst, vsib, pfx.evex_aaa),
          1 => exec_gather_q32_256(dst, vsib, pfx.evex_aaa),
          _ => exec_gather_q32_128(dst, vsib, pfx.evex_aaa),
        }
      }
    }
  },

  // 0F38 92: VGATHERDPS (66,W0) / VGATHERDPD (66,W1) [F]
  146 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let vsib = decode_vsib_evex(modrm, pfx, 4);
      if pfx.rex_w then { // VGATHERDPD: dword indices, f64 elements
        match pfx.evex_ll {
          2 => exec_gather_d64_512(dst, vsib, pfx.evex_aaa),
          1 => exec_gather_d64_256(dst, vsib, pfx.evex_aaa),
          _ => exec_gather_d64_128(dst, vsib, pfx.evex_aaa),
        }
      } else { // VGATHERDPS: dword indices, f32 elements
        match pfx.evex_ll {
          2 => exec_gather_d32_512(dst, vsib, pfx.evex_aaa),
          1 => exec_gather_d32_256(dst, vsib, pfx.evex_aaa),
          _ => exec_gather_d32_128(dst, vsib, pfx.evex_aaa),
        }
      }
    }
  },

  // 0F38 93: VGATHERQPS (66,W0) / VGATHERQPD (66,W1) [F]
  147 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let vsib = decode_vsib_evex(modrm, pfx, 4);
      if pfx.rex_w then { // VGATHERQPD: qword indices, f64 elements
        match pfx.evex_ll {
          2 => exec_gather_q64_512(dst, vsib, pfx.evex_aaa),
          1 => exec_gather_q64_256(dst, vsib, pfx.evex_aaa),
          _ => exec_gather_q64_128(dst, vsib, pfx.evex_aaa),
        }
      } else { // VGATHERQPS: qword indices, f32 elements
        match pfx.evex_ll {
          2 => exec_gather_q32_512(dst, vsib, pfx.evex_aaa),
          1 => exec_gather_q32_256(dst, vsib, pfx.evex_aaa),
          _ => exec_gather_q32_128(dst, vsib, pfx.evex_aaa),
        }
      }
    }
  },

  // =====================================================================
  // FMA 132 forms (0x96-0x9F)
  // =====================================================================

  // 0F38 96: VFMADDSUB132PS (66,W0) / VFMADDSUB132PD (66,W1) [F]
  150 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let v = pfx.evex_vvvvv;
      if pfx.rex_w then match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fmaddsub_pd_512(read_zmm(dst), evex_src_zmm(modrm, rm, pfx), read_zmm(v))); Ok(()) },
        1 => { write_ymm(dst, avx_fmaddsub_pd_256(read_ymm(dst), evex_src_ymm(modrm, rm, pfx), read_ymm(v))); Ok(()) },
        _ => { write_xmm(dst, avx_fmaddsub_pd_128(read_xmm(dst), evex_src_xmm(modrm, rm, pfx), read_xmm(v))); Ok(()) },
      } else match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fmaddsub_ps_512(read_zmm(dst), evex_src_zmm(modrm, rm, pfx), read_zmm(v))); Ok(()) },
        1 => { write_ymm(dst, avx_fmaddsub_ps_256(read_ymm(dst), evex_src_ymm(modrm, rm, pfx), read_ymm(v))); Ok(()) },
        _ => { write_xmm(dst, avx_fmaddsub_ps_128(read_xmm(dst), evex_src_xmm(modrm, rm, pfx), read_xmm(v))); Ok(()) },
      }
    }
  },

  // 0F38 97: VFMSUBADD132PS (66,W0) / VFMSUBADD132PD (66,W1) [F]
  151 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let v = pfx.evex_vvvvv;
      if pfx.rex_w then match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fmsubadd_pd_512(read_zmm(dst), evex_src_zmm(modrm, rm, pfx), read_zmm(v))); Ok(()) },
        1 => { write_ymm(dst, avx_fmsubadd_pd_256(read_ymm(dst), evex_src_ymm(modrm, rm, pfx), read_ymm(v))); Ok(()) },
        _ => { write_xmm(dst, avx_fmsubadd_pd_128(read_xmm(dst), evex_src_xmm(modrm, rm, pfx), read_xmm(v))); Ok(()) },
      } else match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fmsubadd_ps_512(read_zmm(dst), evex_src_zmm(modrm, rm, pfx), read_zmm(v))); Ok(()) },
        1 => { write_ymm(dst, avx_fmsubadd_ps_256(read_ymm(dst), evex_src_ymm(modrm, rm, pfx), read_ymm(v))); Ok(()) },
        _ => { write_xmm(dst, avx_fmsubadd_ps_128(read_xmm(dst), evex_src_xmm(modrm, rm, pfx), read_xmm(v))); Ok(()) },
      }
    }
  },

  // 0F38 98: VFMADD132PS (66,W0) / VFMADD132PD (66,W1) [F]
  152 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let v = pfx.evex_vvvvv;
      if pfx.rex_w then match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fmadd_pd_512(read_zmm(dst), evex_src_zmm(modrm, rm, pfx), read_zmm(v))); Ok(()) },
        1 => { write_ymm(dst, avx_fmadd_pd_256(read_ymm(dst), evex_src_ymm(modrm, rm, pfx), read_ymm(v))); Ok(()) },
        _ => { write_xmm(dst, avx_fmadd_pd_128(read_xmm(dst), evex_src_xmm(modrm, rm, pfx), read_xmm(v))); Ok(()) },
      } else match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fmadd_ps_512(read_zmm(dst), evex_src_zmm(modrm, rm, pfx), read_zmm(v))); Ok(()) },
        1 => { write_ymm(dst, avx_fmadd_ps_256(read_ymm(dst), evex_src_ymm(modrm, rm, pfx), read_ymm(v))); Ok(()) },
        _ => { write_xmm(dst, avx_fmadd_ps_128(read_xmm(dst), evex_src_xmm(modrm, rm, pfx), read_xmm(v))); Ok(()) },
      }
    }
  },

  // 0F38 99: VFMADD132SS (66,W0) / VFMADD132SD (66,W1) [F]
  153 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
      let src2 = read_xmm(pfx.evex_vvvvv);
      let src3 = evex_src_xmm(modrm, rm, pfx);
      if pfx.rex_w then exec_vfmadd132sd(dst, src2, src3)
      else exec_vfmadd132ss(dst, src2, src3)
    }
  },

  // 0F38 9A: VFMSUB132PS (66,W0) / VFMSUB132PD (66,W1) [F]
  154 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let v = pfx.evex_vvvvv;
      if pfx.rex_w then match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fmsub_pd_512(read_zmm(dst), evex_src_zmm(modrm, rm, pfx), read_zmm(v))); Ok(()) },
        1 => { write_ymm(dst, avx_fmsub_pd_256(read_ymm(dst), evex_src_ymm(modrm, rm, pfx), read_ymm(v))); Ok(()) },
        _ => { write_xmm(dst, avx_fmsub_pd_128(read_xmm(dst), evex_src_xmm(modrm, rm, pfx), read_xmm(v))); Ok(()) },
      } else match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fmsub_ps_512(read_zmm(dst), evex_src_zmm(modrm, rm, pfx), read_zmm(v))); Ok(()) },
        1 => { write_ymm(dst, avx_fmsub_ps_256(read_ymm(dst), evex_src_ymm(modrm, rm, pfx), read_ymm(v))); Ok(()) },
        _ => { write_xmm(dst, avx_fmsub_ps_128(read_xmm(dst), evex_src_xmm(modrm, rm, pfx), read_xmm(v))); Ok(()) },
      }
    }
  },

  // 0F38 9B: VFMSUB132SS (66,W0) / VFMSUB132SD (66,W1) [F]
  155 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
      let src2 = read_xmm(pfx.evex_vvvvv);
      let src3 = evex_src_xmm(modrm, rm, pfx);
      if pfx.rex_w then exec_vfmsub132sd(dst, src2, src3)
      else exec_vfmsub132ss(dst, src2, src3)
    }
  },

  // 0F38 9C: VFNMADD132PS (66,W0) / VFNMADD132PD (66,W1) [F]
  156 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let v = pfx.evex_vvvvv;
      if pfx.rex_w then match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fnmadd_pd_512(read_zmm(dst), evex_src_zmm(modrm, rm, pfx), read_zmm(v))); Ok(()) },
        1 => { write_ymm(dst, avx_fnmadd_pd_256(read_ymm(dst), evex_src_ymm(modrm, rm, pfx), read_ymm(v))); Ok(()) },
        _ => { write_xmm(dst, avx_fnmadd_pd_128(read_xmm(dst), evex_src_xmm(modrm, rm, pfx), read_xmm(v))); Ok(()) },
      } else match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fnmadd_ps_512(read_zmm(dst), evex_src_zmm(modrm, rm, pfx), read_zmm(v))); Ok(()) },
        1 => { write_ymm(dst, avx_fnmadd_ps_256(read_ymm(dst), evex_src_ymm(modrm, rm, pfx), read_ymm(v))); Ok(()) },
        _ => { write_xmm(dst, avx_fnmadd_ps_128(read_xmm(dst), evex_src_xmm(modrm, rm, pfx), read_xmm(v))); Ok(()) },
      }
    }
  },

  // 0F38 9D: VFNMADD132SS (66,W0) / VFNMADD132SD (66,W1) [F]
  157 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
      let src2 = read_xmm(pfx.evex_vvvvv);
      let src3 = evex_src_xmm(modrm, rm, pfx);
      if pfx.rex_w then exec_vfnmadd132sd(dst, src2, src3)
      else exec_vfnmadd132ss(dst, src2, src3)
    }
  },

  // 0F38 9E: VFNMSUB132PS (66,W0) / VFNMSUB132PD (66,W1) [F]
  158 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let v = pfx.evex_vvvvv;
      if pfx.rex_w then match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fnmsub_pd_512(read_zmm(dst), evex_src_zmm(modrm, rm, pfx), read_zmm(v))); Ok(()) },
        1 => { write_ymm(dst, avx_fnmsub_pd_256(read_ymm(dst), evex_src_ymm(modrm, rm, pfx), read_ymm(v))); Ok(()) },
        _ => { write_xmm(dst, avx_fnmsub_pd_128(read_xmm(dst), evex_src_xmm(modrm, rm, pfx), read_xmm(v))); Ok(()) },
      } else match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fnmsub_ps_512(read_zmm(dst), evex_src_zmm(modrm, rm, pfx), read_zmm(v))); Ok(()) },
        1 => { write_ymm(dst, avx_fnmsub_ps_256(read_ymm(dst), evex_src_ymm(modrm, rm, pfx), read_ymm(v))); Ok(()) },
        _ => { write_xmm(dst, avx_fnmsub_ps_128(read_xmm(dst), evex_src_xmm(modrm, rm, pfx), read_xmm(v))); Ok(()) },
      }
    }
  },

  // 0F38 9F: VFNMSUB132SS (66,W0) / VFNMSUB132SD (66,W1) [F]
  159 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
      let src2 = read_xmm(pfx.evex_vvvvv);
      let src3 = evex_src_xmm(modrm, rm, pfx);
      if pfx.rex_w then exec_vfnmsub132sd(dst, src2, src3)
      else exec_vfnmsub132ss(dst, src2, src3)
    }
  },

  // =====================================================================
  // Scatter (0xA0-0xA3) — VSIB addressing
  // =====================================================================

  // 0F38 A0: VPSCATTERDD (66,W0) / VPSCATTERDQ (66,W1) [F]
  160 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let src = evex_reg_idx(modrm, pfx);
      let vsib = decode_vsib_evex(modrm, pfx, 4);
      if pfx.rex_w then {
        match pfx.evex_ll {
          2 => exec_scatter_d64_512(src, vsib, pfx.evex_aaa),
          1 => exec_scatter_d64_256(src, vsib, pfx.evex_aaa),
          _ => exec_scatter_d64_128(src, vsib, pfx.evex_aaa),
        }
      } else {
        match pfx.evex_ll {
          2 => exec_scatter_d32_512(src, vsib, pfx.evex_aaa),
          1 => exec_scatter_d32_256(src, vsib, pfx.evex_aaa),
          _ => exec_scatter_d32_128(src, vsib, pfx.evex_aaa),
        }
      }
    }
  },

  // 0F38 A1: VPSCATTERQD (66,W0) / VPSCATTERQQ (66,W1) [F]
  161 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let src = evex_reg_idx(modrm, pfx);
      let vsib = decode_vsib_evex(modrm, pfx, 4);
      if pfx.rex_w then {
        match pfx.evex_ll {
          2 => exec_scatter_q64_512(src, vsib, pfx.evex_aaa),
          1 => exec_scatter_q64_256(src, vsib, pfx.evex_aaa),
          _ => exec_scatter_q64_128(src, vsib, pfx.evex_aaa),
        }
      } else {
        match pfx.evex_ll {
          2 => exec_scatter_q32_512(src, vsib, pfx.evex_aaa),
          1 => exec_scatter_q32_256(src, vsib, pfx.evex_aaa),
          _ => exec_scatter_q32_128(src, vsib, pfx.evex_aaa),
        }
      }
    }
  },

  // 0F38 A2: VSCATTERDPS (66,W0) / VSCATTERDPD (66,W1) [F]
  162 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let src = evex_reg_idx(modrm, pfx);
      let vsib = decode_vsib_evex(modrm, pfx, 4);
      if pfx.rex_w then {
        match pfx.evex_ll {
          2 => exec_scatter_d64_512(src, vsib, pfx.evex_aaa),
          1 => exec_scatter_d64_256(src, vsib, pfx.evex_aaa),
          _ => exec_scatter_d64_128(src, vsib, pfx.evex_aaa),
        }
      } else {
        match pfx.evex_ll {
          2 => exec_scatter_d32_512(src, vsib, pfx.evex_aaa),
          1 => exec_scatter_d32_256(src, vsib, pfx.evex_aaa),
          _ => exec_scatter_d32_128(src, vsib, pfx.evex_aaa),
        }
      }
    }
  },

  // 0F38 A3: VSCATTERQPS (66,W0) / VSCATTERQPD (66,W1) [F]
  163 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let src = evex_reg_idx(modrm, pfx);
      let vsib = decode_vsib_evex(modrm, pfx, 4);
      if pfx.rex_w then {
        match pfx.evex_ll {
          2 => exec_scatter_q64_512(src, vsib, pfx.evex_aaa),
          1 => exec_scatter_q64_256(src, vsib, pfx.evex_aaa),
          _ => exec_scatter_q64_128(src, vsib, pfx.evex_aaa),
        }
      } else {
        match pfx.evex_ll {
          2 => exec_scatter_q32_512(src, vsib, pfx.evex_aaa),
          1 => exec_scatter_q32_256(src, vsib, pfx.evex_aaa),
          _ => exec_scatter_q32_128(src, vsib, pfx.evex_aaa),
        }
      }
    }
  },

  // =====================================================================
  // FMA 213 forms (0xA6-0xAF)
  // =====================================================================

  // 0F38 A6: VFMADDSUB213PS (66,W0) / VFMADDSUB213PD (66,W1) [F]
  166 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let v = pfx.evex_vvvvv;
      if pfx.rex_w then match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fmaddsub_pd_512(read_zmm(v), read_zmm(dst), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_fmaddsub_pd_256(read_ymm(v), read_ymm(dst), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_fmaddsub_pd_128(read_xmm(v), read_xmm(dst), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      } else match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fmaddsub_ps_512(read_zmm(v), read_zmm(dst), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_fmaddsub_ps_256(read_ymm(v), read_ymm(dst), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_fmaddsub_ps_128(read_xmm(v), read_xmm(dst), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F38 A7: VFMSUBADD213PS (66,W0) / VFMSUBADD213PD (66,W1) [F]
  167 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let v = pfx.evex_vvvvv;
      if pfx.rex_w then match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fmsubadd_pd_512(read_zmm(v), read_zmm(dst), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_fmsubadd_pd_256(read_ymm(v), read_ymm(dst), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_fmsubadd_pd_128(read_xmm(v), read_xmm(dst), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      } else match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fmsubadd_ps_512(read_zmm(v), read_zmm(dst), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_fmsubadd_ps_256(read_ymm(v), read_ymm(dst), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_fmsubadd_ps_128(read_xmm(v), read_xmm(dst), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F38 A8: VFMADD213PS (66,W0) / VFMADD213PD (66,W1) [F]
  168 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let v = pfx.evex_vvvvv;
      if pfx.rex_w then match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fmadd_pd_512(read_zmm(v), read_zmm(dst), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_fmadd_pd_256(read_ymm(v), read_ymm(dst), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_fmadd_pd_128(read_xmm(v), read_xmm(dst), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      } else match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fmadd_ps_512(read_zmm(v), read_zmm(dst), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_fmadd_ps_256(read_ymm(v), read_ymm(dst), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_fmadd_ps_128(read_xmm(v), read_xmm(dst), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F38 A9: VFMADD213SS (66,W0) / VFMADD213SD (66,W1) [F]
  169 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
      let src2 = read_xmm(pfx.evex_vvvvv);
      let src3 = evex_src_xmm(modrm, rm, pfx);
      if pfx.rex_w then exec_vfmadd213sd(dst, src2, src3)
      else exec_vfmadd213ss(dst, src2, src3)
    }
  },

  // 0F38 AA: VFMSUB213PS (66,W0) / VFMSUB213PD (66,W1) [F]
  170 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let v = pfx.evex_vvvvv;
      if pfx.rex_w then match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fmsub_pd_512(read_zmm(v), read_zmm(dst), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_fmsub_pd_256(read_ymm(v), read_ymm(dst), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_fmsub_pd_128(read_xmm(v), read_xmm(dst), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      } else match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fmsub_ps_512(read_zmm(v), read_zmm(dst), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_fmsub_ps_256(read_ymm(v), read_ymm(dst), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_fmsub_ps_128(read_xmm(v), read_xmm(dst), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F38 AB: VFMSUB213SS (66,W0) / VFMSUB213SD (66,W1) [F]
  171 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
      let src2 = read_xmm(pfx.evex_vvvvv);
      let src3 = evex_src_xmm(modrm, rm, pfx);
      if pfx.rex_w then exec_vfmsub213sd(dst, src2, src3)
      else exec_vfmsub213ss(dst, src2, src3)
    }
  },

  // 0F38 AC: VFNMADD213PS (66,W0) / VFNMADD213PD (66,W1) [F]
  172 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let v = pfx.evex_vvvvv;
      if pfx.rex_w then match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fnmadd_pd_512(read_zmm(v), read_zmm(dst), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_fnmadd_pd_256(read_ymm(v), read_ymm(dst), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_fnmadd_pd_128(read_xmm(v), read_xmm(dst), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      } else match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fnmadd_ps_512(read_zmm(v), read_zmm(dst), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_fnmadd_ps_256(read_ymm(v), read_ymm(dst), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_fnmadd_ps_128(read_xmm(v), read_xmm(dst), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F38 AD: VFNMADD213SS (66,W0) / VFNMADD213SD (66,W1) [F]
  173 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
      let src2 = read_xmm(pfx.evex_vvvvv);
      let src3 = evex_src_xmm(modrm, rm, pfx);
      if pfx.rex_w then exec_vfnmadd213sd(dst, src2, src3)
      else exec_vfnmadd213ss(dst, src2, src3)
    }
  },

  // 0F38 AE: VFNMSUB213PS (66,W0) / VFNMSUB213PD (66,W1) [F]
  174 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let v = pfx.evex_vvvvv;
      if pfx.rex_w then match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fnmsub_pd_512(read_zmm(v), read_zmm(dst), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_fnmsub_pd_256(read_ymm(v), read_ymm(dst), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_fnmsub_pd_128(read_xmm(v), read_xmm(dst), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      } else match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fnmsub_ps_512(read_zmm(v), read_zmm(dst), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_fnmsub_ps_256(read_ymm(v), read_ymm(dst), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_fnmsub_ps_128(read_xmm(v), read_xmm(dst), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F38 AF: VFNMSUB213SS (66,W0) / VFNMSUB213SD (66,W1) [F]
  175 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
      let src2 = read_xmm(pfx.evex_vvvvv);
      let src3 = evex_src_xmm(modrm, rm, pfx);
      if pfx.rex_w then exec_vfnmsub213sd(dst, src2, src3)
      else exec_vfnmsub213ss(dst, src2, src3)
    }
  },

  // 0F38 B4: VPMADD52LUQ (66,W1) [IFMA]
  180 => {
    if mp != MP_66 | not_bool(pfx.rex_w) then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_vpmadd52luq_512(read_zmm(dst), read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_vpmadd52luq_256(read_ymm(dst), read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_vpmadd52luq_128(read_xmm(dst), read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F38 B5: VPMADD52HUQ (66,W1) [IFMA]
  181 => {
    if mp != MP_66 | not_bool(pfx.rex_w) then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_vpmadd52huq_512(read_zmm(dst), read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_vpmadd52huq_256(read_ymm(dst), read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_vpmadd52huq_128(read_xmm(dst), read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // =====================================================================
  // FMA 231 forms (0xB6-0xBF)
  // =====================================================================

  // 0F38 B6: VFMADDSUB231PS (66,W0) / VFMADDSUB231PD (66,W1) [F]
  182 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let v = pfx.evex_vvvvv;
      if pfx.rex_w then match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fmaddsub_pd_512(read_zmm(v), evex_src_zmm(modrm, rm, pfx), read_zmm(dst))); Ok(()) },
        1 => { write_ymm(dst, avx_fmaddsub_pd_256(read_ymm(v), evex_src_ymm(modrm, rm, pfx), read_ymm(dst))); Ok(()) },
        _ => { write_xmm(dst, avx_fmaddsub_pd_128(read_xmm(v), evex_src_xmm(modrm, rm, pfx), read_xmm(dst))); Ok(()) },
      } else match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fmaddsub_ps_512(read_zmm(v), evex_src_zmm(modrm, rm, pfx), read_zmm(dst))); Ok(()) },
        1 => { write_ymm(dst, avx_fmaddsub_ps_256(read_ymm(v), evex_src_ymm(modrm, rm, pfx), read_ymm(dst))); Ok(()) },
        _ => { write_xmm(dst, avx_fmaddsub_ps_128(read_xmm(v), evex_src_xmm(modrm, rm, pfx), read_xmm(dst))); Ok(()) },
      }
    }
  },

  // 0F38 B7: VFMSUBADD231PS (66,W0) / VFMSUBADD231PD (66,W1) [F]
  183 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let v = pfx.evex_vvvvv;
      if pfx.rex_w then match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fmsubadd_pd_512(read_zmm(v), evex_src_zmm(modrm, rm, pfx), read_zmm(dst))); Ok(()) },
        1 => { write_ymm(dst, avx_fmsubadd_pd_256(read_ymm(v), evex_src_ymm(modrm, rm, pfx), read_ymm(dst))); Ok(()) },
        _ => { write_xmm(dst, avx_fmsubadd_pd_128(read_xmm(v), evex_src_xmm(modrm, rm, pfx), read_xmm(dst))); Ok(()) },
      } else match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fmsubadd_ps_512(read_zmm(v), evex_src_zmm(modrm, rm, pfx), read_zmm(dst))); Ok(()) },
        1 => { write_ymm(dst, avx_fmsubadd_ps_256(read_ymm(v), evex_src_ymm(modrm, rm, pfx), read_ymm(dst))); Ok(()) },
        _ => { write_xmm(dst, avx_fmsubadd_ps_128(read_xmm(v), evex_src_xmm(modrm, rm, pfx), read_xmm(dst))); Ok(()) },
      }
    }
  },

  // 0F38 B8: VFMADD231PS (66,W0) / VFMADD231PD (66,W1) [F]
  184 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let v = pfx.evex_vvvvv;
      if pfx.rex_w then match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fmadd_pd_512(read_zmm(v), evex_src_zmm(modrm, rm, pfx), read_zmm(dst))); Ok(()) },
        1 => { write_ymm(dst, avx_fmadd_pd_256(read_ymm(v), evex_src_ymm(modrm, rm, pfx), read_ymm(dst))); Ok(()) },
        _ => { write_xmm(dst, avx_fmadd_pd_128(read_xmm(v), evex_src_xmm(modrm, rm, pfx), read_xmm(dst))); Ok(()) },
      } else match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fmadd_ps_512(read_zmm(v), evex_src_zmm(modrm, rm, pfx), read_zmm(dst))); Ok(()) },
        1 => { write_ymm(dst, avx_fmadd_ps_256(read_ymm(v), evex_src_ymm(modrm, rm, pfx), read_ymm(dst))); Ok(()) },
        _ => { write_xmm(dst, avx_fmadd_ps_128(read_xmm(v), evex_src_xmm(modrm, rm, pfx), read_xmm(dst))); Ok(()) },
      }
    }
  },

  // 0F38 B9: VFMADD231SS (66,W0) / VFMADD231SD (66,W1) [F]
  185 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
      let src2 = read_xmm(pfx.evex_vvvvv);
      let src3 = evex_src_xmm(modrm, rm, pfx);
      if pfx.rex_w then exec_vfmadd231sd(dst, src2, src3)
      else exec_vfmadd231ss(dst, src2, src3)
    }
  },

  // 0F38 BA: VFMSUB231PS (66,W0) / VFMSUB231PD (66,W1) [F]
  186 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let v = pfx.evex_vvvvv;
      if pfx.rex_w then match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fmsub_pd_512(read_zmm(v), evex_src_zmm(modrm, rm, pfx), read_zmm(dst))); Ok(()) },
        1 => { write_ymm(dst, avx_fmsub_pd_256(read_ymm(v), evex_src_ymm(modrm, rm, pfx), read_ymm(dst))); Ok(()) },
        _ => { write_xmm(dst, avx_fmsub_pd_128(read_xmm(v), evex_src_xmm(modrm, rm, pfx), read_xmm(dst))); Ok(()) },
      } else match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fmsub_ps_512(read_zmm(v), evex_src_zmm(modrm, rm, pfx), read_zmm(dst))); Ok(()) },
        1 => { write_ymm(dst, avx_fmsub_ps_256(read_ymm(v), evex_src_ymm(modrm, rm, pfx), read_ymm(dst))); Ok(()) },
        _ => { write_xmm(dst, avx_fmsub_ps_128(read_xmm(v), evex_src_xmm(modrm, rm, pfx), read_xmm(dst))); Ok(()) },
      }
    }
  },

  // 0F38 BB: VFMSUB231SS (66,W0) / VFMSUB231SD (66,W1) [F]
  187 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
      let src2 = read_xmm(pfx.evex_vvvvv);
      let src3 = evex_src_xmm(modrm, rm, pfx);
      if pfx.rex_w then exec_vfmsub231sd(dst, src2, src3)
      else exec_vfmsub231ss(dst, src2, src3)
    }
  },

  // 0F38 BC: VFNMADD231PS (66,W0) / VFNMADD231PD (66,W1) [F]
  188 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let v = pfx.evex_vvvvv;
      if pfx.rex_w then match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fnmadd_pd_512(read_zmm(v), evex_src_zmm(modrm, rm, pfx), read_zmm(dst))); Ok(()) },
        1 => { write_ymm(dst, avx_fnmadd_pd_256(read_ymm(v), evex_src_ymm(modrm, rm, pfx), read_ymm(dst))); Ok(()) },
        _ => { write_xmm(dst, avx_fnmadd_pd_128(read_xmm(v), evex_src_xmm(modrm, rm, pfx), read_xmm(dst))); Ok(()) },
      } else match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fnmadd_ps_512(read_zmm(v), evex_src_zmm(modrm, rm, pfx), read_zmm(dst))); Ok(()) },
        1 => { write_ymm(dst, avx_fnmadd_ps_256(read_ymm(v), evex_src_ymm(modrm, rm, pfx), read_ymm(dst))); Ok(()) },
        _ => { write_xmm(dst, avx_fnmadd_ps_128(read_xmm(v), evex_src_xmm(modrm, rm, pfx), read_xmm(dst))); Ok(()) },
      }
    }
  },

  // 0F38 BD: VFNMADD231SS (66,W0) / VFNMADD231SD (66,W1) [F]
  189 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
      let src2 = read_xmm(pfx.evex_vvvvv);
      let src3 = evex_src_xmm(modrm, rm, pfx);
      if pfx.rex_w then exec_vfnmadd231sd(dst, src2, src3)
      else exec_vfnmadd231ss(dst, src2, src3)
    }
  },

  // 0F38 BE: VFNMSUB231PS (66,W0) / VFNMSUB231PD (66,W1) [F]
  190 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let v = pfx.evex_vvvvv;
      if pfx.rex_w then match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fnmsub_pd_512(read_zmm(v), evex_src_zmm(modrm, rm, pfx), read_zmm(dst))); Ok(()) },
        1 => { write_ymm(dst, avx_fnmsub_pd_256(read_ymm(v), evex_src_ymm(modrm, rm, pfx), read_ymm(dst))); Ok(()) },
        _ => { write_xmm(dst, avx_fnmsub_pd_128(read_xmm(v), evex_src_xmm(modrm, rm, pfx), read_xmm(dst))); Ok(()) },
      } else match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fnmsub_ps_512(read_zmm(v), evex_src_zmm(modrm, rm, pfx), read_zmm(dst))); Ok(()) },
        1 => { write_ymm(dst, avx_fnmsub_ps_256(read_ymm(v), evex_src_ymm(modrm, rm, pfx), read_ymm(dst))); Ok(()) },
        _ => { write_xmm(dst, avx_fnmsub_ps_128(read_xmm(v), evex_src_xmm(modrm, rm, pfx), read_xmm(dst))); Ok(()) },
      }
    }
  },

  // 0F38 BF: VFNMSUB231SS (66,W0) / VFNMSUB231SD (66,W1) [F]
  191 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
      let src2 = read_xmm(pfx.evex_vvvvv);
      let src3 = evex_src_xmm(modrm, rm, pfx);
      if pfx.rex_w then exec_vfnmsub231sd(dst, src2, src3)
      else exec_vfnmsub231ss(dst, src2, src3)
    }
  },

  // 0F38 2C: VSCALEFPS (66,W0) / VSCALEFPD (66,W1) [F]
  44 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
      if pfx.rex_w then {
        // VSCALEFPD
        match pfx.evex_ll {
          2 => {
            let src1 : zmmword = read_zmm(pfx.evex_vvvvv);
            let src2 : zmmword = if pfx.evex_b & is_mem
              then broadcast_f64_zmm(evex_src_m64(modrm, rm, pfx))
              else evex_src_zmm(modrm, rm, pfx);
            write_zmm(dst, vscalefpd_zmm(src1, src2)); Ok(())
          },
          1 => { write_ymm(dst, vscalefpd_ymm(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
          _ => { write_xmm(dst, vscalefpd_xmm(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
        }
      } else {
        // VSCALEFPS
        match pfx.evex_ll {
          2 => {
            let src1 : zmmword = read_zmm(pfx.evex_vvvvv);
            let src2 : zmmword = if pfx.evex_b & is_mem
              then broadcast_f32_zmm(evex_src_m32(modrm, rm, pfx))
              else evex_src_zmm(modrm, rm, pfx);
            write_zmm(dst, vscalefps_zmm(src1, src2)); Ok(())
          },
          1 => { write_ymm(dst, vscalefps_ymm(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
          _ => { write_xmm(dst, vscalefps_xmm(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
        }
      }
    }
  },

  // 0F38 2D: VSCALEFSS (66,W0) / VSCALEFSD (66,W1) [T1S]
  45 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
      let src1 = read_xmm(pfx.evex_vvvvv);
      let src2 = evex_src_xmm(modrm, rm, pfx);
      if pfx.rex_w then {
        // VSCALEFSD
        let r = __f64_scalef(src1[63..0], src2[63..0]);
        write_xmm(dst, src1[127..64] @ r); Ok(())
      } else {
        // VSCALEFSS
        let r = __f32_scalef(src1[31..0], src2[31..0]);
        write_xmm(dst, src1[127..32] @ r); Ok(())
      }
    }
  },

  // 0F38 42: VGETEXPPS (66,W0) / VGETEXPPD (66,W1) [F]
  66 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
      if pfx.rex_w then {
        // VGETEXPPD
        match pfx.evex_ll {
          2 => {
            let src : zmmword = if pfx.evex_b & is_mem
              then broadcast_f64_zmm(evex_src_m64(modrm, rm, pfx))
              else evex_src_zmm(modrm, rm, pfx);
            write_zmm(dst, vgetexppd_zmm(src)); Ok(())
          },
          1 => { write_ymm(dst, vgetexppd_ymm(evex_src_ymm(modrm, rm, pfx))); Ok(()) },
          _ => { write_xmm(dst, vgetexppd_xmm(evex_src_xmm(modrm, rm, pfx))); Ok(()) },
        }
      } else {
        // VGETEXPPS
        match pfx.evex_ll {
          2 => {
            let src : zmmword = if pfx.evex_b & is_mem
              then broadcast_f32_zmm(evex_src_m32(modrm, rm, pfx))
              else evex_src_zmm(modrm, rm, pfx);
            write_zmm(dst, vgetexpps_zmm(src)); Ok(())
          },
          1 => { write_ymm(dst, vgetexpps_ymm(evex_src_ymm(modrm, rm, pfx))); Ok(()) },
          _ => { write_xmm(dst, vgetexpps_xmm(evex_src_xmm(modrm, rm, pfx))); Ok(()) },
        }
      }
    }
  },

  // 0F38 43: VGETEXPSS (66,W0) / VGETEXPSD (66,W1) [T1S]
  67 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
      let src1 = read_xmm(pfx.evex_vvvvv);
      let src2 = evex_src_xmm(modrm, rm, pfx);
      if pfx.rex_w then {
        // VGETEXPSD
        let r = __f64_getexp(src2[63..0]);
        write_xmm(dst, src1[127..64] @ r); Ok(())
      } else {
        // VGETEXPSS
        let r = __f32_getexp(src2[31..0]);
        write_xmm(dst, src1[127..32] @ r); Ok(())
      }
    }
  },

  // 0F38 4C: VRCP14PS (66,W0) / VRCP14PD (66,W1) [F]
  76 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
      if pfx.rex_w then {
        // VRCP14PD
        match pfx.evex_ll {
          2 => {
            let src : zmmword = if pfx.evex_b & is_mem
              then broadcast_f64_zmm(evex_src_m64(modrm, rm, pfx))
              else evex_src_zmm(modrm, rm, pfx);
            write_zmm(dst, vrcp14pd_zmm(src)); Ok(())
          },
          1 => { write_ymm(dst, vrcp14pd_ymm(evex_src_ymm(modrm, rm, pfx))); Ok(()) },
          _ => { write_xmm(dst, vrcp14pd_xmm(evex_src_xmm(modrm, rm, pfx))); Ok(()) },
        }
      } else {
        // VRCP14PS
        match pfx.evex_ll {
          2 => {
            let src : zmmword = if pfx.evex_b & is_mem
              then broadcast_f32_zmm(evex_src_m32(modrm, rm, pfx))
              else evex_src_zmm(modrm, rm, pfx);
            write_zmm(dst, vrcp14ps_zmm(src)); Ok(())
          },
          1 => { write_ymm(dst, vrcp14ps_ymm(evex_src_ymm(modrm, rm, pfx))); Ok(()) },
          _ => { write_xmm(dst, vrcp14ps_xmm(evex_src_xmm(modrm, rm, pfx))); Ok(()) },
        }
      }
    }
  },

  // 0F38 4D: VRCP14SS (66,W0) / VRCP14SD (66,W1) [T1S]
  77 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
      let src1 = read_xmm(pfx.evex_vvvvv);
      let src2 = evex_src_xmm(modrm, rm, pfx);
      if pfx.rex_w then {
        // VRCP14SD
        let r = __f64_rcp14(src2[63..0]);
        write_xmm(dst, src1[127..64] @ r); Ok(())
      } else {
        // VRCP14SS
        let r = __f32_rcp14(src2[31..0]);
        write_xmm(dst, src1[127..32] @ r); Ok(())
      }
    }
  },

  // 0F38 4E: VRSQRT14PS (66,W0) / VRSQRT14PD (66,W1) [F]
  78 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
      if pfx.rex_w then {
        // VRSQRT14PD
        match pfx.evex_ll {
          2 => {
            let src : zmmword = if pfx.evex_b & is_mem
              then broadcast_f64_zmm(evex_src_m64(modrm, rm, pfx))
              else evex_src_zmm(modrm, rm, pfx);
            write_zmm(dst, vrsqrt14pd_zmm(src)); Ok(())
          },
          1 => { write_ymm(dst, vrsqrt14pd_ymm(evex_src_ymm(modrm, rm, pfx))); Ok(()) },
          _ => { write_xmm(dst, vrsqrt14pd_xmm(evex_src_xmm(modrm, rm, pfx))); Ok(()) },
        }
      } else {
        // VRSQRT14PS
        match pfx.evex_ll {
          2 => {
            let src : zmmword = if pfx.evex_b & is_mem
              then broadcast_f32_zmm(evex_src_m32(modrm, rm, pfx))
              else evex_src_zmm(modrm, rm, pfx);
            write_zmm(dst, vrsqrt14ps_zmm(src)); Ok(())
          },
          1 => { write_ymm(dst, vrsqrt14ps_ymm(evex_src_ymm(modrm, rm, pfx))); Ok(()) },
          _ => { write_xmm(dst, vrsqrt14ps_xmm(evex_src_xmm(modrm, rm, pfx))); Ok(()) },
        }
      }
    }
  },

  // 0F38 4F: VRSQRT14SS (66,W0) / VRSQRT14SD (66,W1) [T1S]
  79 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
      let src1 = read_xmm(pfx.evex_vvvvv);
      let src2 = evex_src_xmm(modrm, rm, pfx);
      if pfx.rex_w then {
        // VRSQRT14SD
        let r = __f64_rsqrt14(src2[63..0]);
        write_xmm(dst, src1[127..64] @ r); Ok(())
      } else {
        // VRSQRT14SS
        let r = __f32_rsqrt14(src2[31..0]);
        write_xmm(dst, src1[127..32] @ r); Ok(())
      }
    }
  },

  // 0F38 2A: VPBROADCASTMB2Q (F3, W=1) [CD] — also VMOVNTDQA (66)
  42 => {
    if mp == MP_F3 & pfx.rex_w then {
      // VPBROADCASTMB2Q: broadcast low byte of kmask to all qword elements
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let src_k : range(0, 7) = unsigned(modrm[2..0]);
      let k_byte : byte = read_kreg(src_k)[7..0];
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_vpbroadcastmb2q_512(k_byte)); Ok(()) },
        1 => { write_ymm(dst, avx_vpbroadcastmb2q_256(k_byte)); Ok(()) },
        _ => { write_xmm(dst, avx_vpbroadcastmb2q_128(k_byte)); Ok(()) },
      }
    } else if mp == MP_66 then {
      // VMOVNTDQA (already handled if present, otherwise fallthrough)
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, evex_src_zmm(modrm, rm, pfx)); Ok(()) },
        1 => { write_ymm(dst, evex_src_ymm(modrm, rm, pfx)); Ok(()) },
        _ => { write_xmm(dst, evex_src_xmm(modrm, rm, pfx)); Ok(()) },
      }
    } else raise_UD()
  },

  // 0F38 3A: VPBROADCASTMW2D (F3, W=0) [CD]
  58 => {
    if mp == MP_F3 & not_bool(pfx.rex_w) then {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let src_k : range(0, 7) = unsigned(modrm[2..0]);
      let k_word : word = read_kreg(src_k)[15..0];
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_vpbroadcastmw2d_512(k_word)); Ok(()) },
        1 => { write_ymm(dst, avx_vpbroadcastmw2d_256(k_word)); Ok(()) },
        _ => { write_xmm(dst, avx_vpbroadcastmw2d_128(k_word)); Ok(()) },
      }
    } else raise_UD()
  },

  // 0F38 44: VPLZCNTD (66, W=0) / VPLZCNTQ (66, W=1) [CD]
  68 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      if pfx.rex_w then {
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_vplzcntq_512(evex_src_zmm(modrm, rm, pfx))); Ok(()) },
          1 => { write_ymm(dst, avx_vplzcntq_256(evex_src_ymm(modrm, rm, pfx))); Ok(()) },
          _ => { write_xmm(dst, avx_vplzcntq_128(evex_src_xmm(modrm, rm, pfx))); Ok(()) },
        }
      } else {
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_vplzcntd_512(evex_src_zmm(modrm, rm, pfx))); Ok(()) },
          1 => { write_ymm(dst, avx_vplzcntd_256(evex_src_ymm(modrm, rm, pfx))); Ok(()) },
          _ => { write_xmm(dst, avx_vplzcntd_128(evex_src_xmm(modrm, rm, pfx))); Ok(()) },
        }
      }
    }
  },

  // 0F38 50: VPDPBUSD (66) [VNNI]
  80 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_vpdpbusd_512(read_zmm(dst), read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_vpdpbusd_256(read_ymm(dst), read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_vpdpbusd_128(read_xmm(dst), read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F38 51: VPDPBUSDS (66) [VNNI]
  81 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_vpdpbusds_512(read_zmm(dst), read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_vpdpbusds_256(read_ymm(dst), read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_vpdpbusds_128(read_xmm(dst), read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F38 52: VPDPWSSD (66) [VNNI]
  82 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_vpdpwssd_512(read_zmm(dst), read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_vpdpwssd_256(read_ymm(dst), read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_vpdpwssd_128(read_xmm(dst), read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F38 53: VPDPWSSDS (66) [VNNI]
  83 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_vpdpwssds_512(read_zmm(dst), read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_vpdpwssds_256(read_ymm(dst), read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_vpdpwssds_128(read_xmm(dst), read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F38 54: VPOPCNTB (66, W=0) / VPOPCNTW (66, W=1) [BITALG]
  84 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      if pfx.rex_w then {
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_vpopcntw_512(evex_src_zmm(modrm, rm, pfx))); Ok(()) },
          1 => { write_ymm(dst, avx_vpopcntw_256(evex_src_ymm(modrm, rm, pfx))); Ok(()) },
          _ => { write_xmm(dst, avx_vpopcntw_128(evex_src_xmm(modrm, rm, pfx))); Ok(()) },
        }
      } else {
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_vpopcntb_512(evex_src_zmm(modrm, rm, pfx))); Ok(()) },
          1 => { write_ymm(dst, avx_vpopcntb_256(evex_src_ymm(modrm, rm, pfx))); Ok(()) },
          _ => { write_xmm(dst, avx_vpopcntb_128(evex_src_xmm(modrm, rm, pfx))); Ok(()) },
        }
      }
    }
  },

  // 0F38 55: VPOPCNTD (66, W=0) / VPOPCNTQ (66, W=1) [VPOPCNTDQ]
  85 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      if pfx.rex_w then {
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_vpopcntq_512(evex_src_zmm(modrm, rm, pfx))); Ok(()) },
          1 => { write_ymm(dst, avx_vpopcntq_256(evex_src_ymm(modrm, rm, pfx))); Ok(()) },
          _ => { write_xmm(dst, avx_vpopcntq_128(evex_src_xmm(modrm, rm, pfx))); Ok(()) },
        }
      } else {
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_vpopcntd_512(evex_src_zmm(modrm, rm, pfx))); Ok(()) },
          1 => { write_ymm(dst, avx_vpopcntd_256(evex_src_ymm(modrm, rm, pfx))); Ok(()) },
          _ => { write_xmm(dst, avx_vpopcntd_128(evex_src_xmm(modrm, rm, pfx))); Ok(()) },
        }
      }
    }
  },

  // 0F38 C4: VPCONFLICTD (66, W=0) / VPCONFLICTQ (66, W=1) [CD]
  196 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      if pfx.rex_w then {
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_vpconflictq_512(evex_src_zmm(modrm, rm, pfx))); Ok(()) },
          1 => { write_ymm(dst, avx_vpconflictq_256(evex_src_ymm(modrm, rm, pfx))); Ok(()) },
          _ => { write_xmm(dst, avx_vpconflictq_128(evex_src_xmm(modrm, rm, pfx))); Ok(()) },
        }
      } else {
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_vpconflictd_512(evex_src_zmm(modrm, rm, pfx))); Ok(()) },
          1 => { write_ymm(dst, avx_vpconflictd_256(evex_src_ymm(modrm, rm, pfx))); Ok(()) },
          _ => { write_xmm(dst, avx_vpconflictd_128(evex_src_xmm(modrm, rm, pfx))); Ok(()) },
        }
      }
    }
  },

  // 0F38 88: VEXPANDPS (66, W=0) / VEXPANDPD (66, W=1) [F]
  136 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
      let k : qword = if pfx.evex_aaa == 0 then ones() else read_kreg(pfx.evex_aaa);
      if pfx.rex_w then {
        // VEXPANDPD
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_vexpandpd_512(evex_src_zmm(modrm, rm, pfx), k[7..0])); Ok(()) },
          1 => { write_ymm(dst, avx_vexpandpd_256(evex_src_ymm(modrm, rm, pfx), k[7..0])); Ok(()) },
          _ => { write_xmm(dst, avx_vexpandpd_128(evex_src_xmm(modrm, rm, pfx), k[7..0])); Ok(()) },
        }
      } else {
        // VEXPANDPS
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_vexpandps_512(evex_src_zmm(modrm, rm, pfx), k[15..0])); Ok(()) },
          1 => { write_ymm(dst, avx_vexpandps_256(evex_src_ymm(modrm, rm, pfx), k[7..0])); Ok(()) },
          _ => { write_xmm(dst, avx_vexpandps_128(evex_src_xmm(modrm, rm, pfx), k[7..0])); Ok(()) },
        }
      }
    }
  },

  // 0F38 89: VPEXPANDD (66, W=0) / VPEXPANDQ (66, W=1) [F]
  137 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
      let k : qword = if pfx.evex_aaa == 0 then ones() else read_kreg(pfx.evex_aaa);
      if pfx.rex_w then {
        // VPEXPANDQ — same as VEXPANDPD (qword elements)
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_vexpandpd_512(evex_src_zmm(modrm, rm, pfx), k[7..0])); Ok(()) },
          1 => { write_ymm(dst, avx_vexpandpd_256(evex_src_ymm(modrm, rm, pfx), k[7..0])); Ok(()) },
          _ => { write_xmm(dst, avx_vexpandpd_128(evex_src_xmm(modrm, rm, pfx), k[7..0])); Ok(()) },
        }
      } else {
        // VPEXPANDD — same as VEXPANDPS (dword elements)
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_vexpandps_512(evex_src_zmm(modrm, rm, pfx), k[15..0])); Ok(()) },
          1 => { write_ymm(dst, avx_vexpandps_256(evex_src_ymm(modrm, rm, pfx), k[7..0])); Ok(()) },
          _ => { write_xmm(dst, avx_vexpandps_128(evex_src_xmm(modrm, rm, pfx), k[7..0])); Ok(()) },
        }
      }
    }
  },

  // 0F38 8A: VCOMPRESSPS (66, W=0) / VCOMPRESSPD (66, W=1) [F]
  // SDM: reg=src, r/m=dst (register form only for now)
  138 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let src = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
      let k : qword = if pfx.evex_aaa == 0 then ones() else read_kreg(pfx.evex_aaa);
      let dst_reg = evex_rm_reg_idx(modrm, pfx);
      if pfx.rex_w then {
        match pfx.evex_ll {
          2 => { write_zmm(dst_reg, avx_vcompresspd_512(read_zmm(src), k[7..0])); Ok(()) },
          1 => { write_ymm(dst_reg, avx_vcompresspd_256(read_ymm(src), k[7..0])); Ok(()) },
          _ => { write_xmm(dst_reg, avx_vcompresspd_128(read_xmm(src), k[7..0])); Ok(()) },
        }
      } else {
        match pfx.evex_ll {
          2 => { write_zmm(dst_reg, avx_vcompressps_512(read_zmm(src), k[15..0])); Ok(()) },
          1 => { write_ymm(dst_reg, avx_vcompressps_256(read_ymm(src), k[7..0])); Ok(()) },
          _ => { write_xmm(dst_reg, avx_vcompressps_128(read_xmm(src), k[7..0])); Ok(()) },
        }
      }
    }
  },

  // 0F38 8B: VPCOMPRESSD (66, W=0) / VPCOMPRESSQ (66, W=1) [F]
  139 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let src = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
      let k : qword = if pfx.evex_aaa == 0 then ones() else read_kreg(pfx.evex_aaa);
      let dst_reg = evex_rm_reg_idx(modrm, pfx);
      if pfx.rex_w then {
        match pfx.evex_ll {
          2 => { write_zmm(dst_reg, avx_vcompresspd_512(read_zmm(src), k[7..0])); Ok(()) },
          1 => { write_ymm(dst_reg, avx_vcompresspd_256(read_ymm(src), k[7..0])); Ok(()) },
          _ => { write_xmm(dst_reg, avx_vcompresspd_128(read_xmm(src), k[7..0])); Ok(()) },
        }
      } else {
        match pfx.evex_ll {
          2 => { write_zmm(dst_reg, avx_vcompressps_512(read_zmm(src), k[15..0])); Ok(()) },
          1 => { write_ymm(dst_reg, avx_vcompressps_256(read_ymm(src), k[7..0])); Ok(()) },
          _ => { write_xmm(dst_reg, avx_vcompressps_128(read_xmm(src), k[7..0])); Ok(()) },
        }
      }
    }
  },

  // 0F38 C6: VGATHERPF0DPS/DPD, VGATHERPF1DPS/DPD (66) [PF]
  // Gather prefetch — architectural NOP (just compute VSIB addresses and discard)
  198 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let reg_field : range(0, 7) = unsigned(modrm[5..3]);
      // reg=1: PF0, reg=2: PF1; VSIB addressing
      if (reg_field != 1 & reg_field != 2) then raise_UD()
      else {
        let disp_n : range(4, 64) = if pfx.rex_w then 8 else 4;
        let _ = decode_vsib_evex(modrm, pfx, disp_n);
        Ok(())
      }
    }
  },

  // 0F38 C7: VGATHERPF0QPS/QPD, VGATHERPF1QPS/QPD (66) [PF]
  // Gather prefetch (qword index) — architectural NOP
  199 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let reg_field : range(0, 7) = unsigned(modrm[5..3]);
      if (reg_field != 1 & reg_field != 2) then raise_UD()
      else {
        let disp_n : range(4, 64) = if pfx.rex_w then 8 else 4;
        let _ = decode_vsib_evex(modrm, pfx, disp_n);
        Ok(())
      }
    }
  },

  // 0F38 C8: VEXP2PS (66,W0) / VEXP2PD (66,W1) [ER] — 512-bit only
  200 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      if pfx.rex_w then {
        write_zmm(dst, avx_vexp2pd_512(evex_src_zmm(modrm, rm, pfx))); Ok(())
      } else {
        write_zmm(dst, avx_vexp2ps_512(evex_src_zmm(modrm, rm, pfx))); Ok(())
      }
    }
  },

  // 0F38 CA: VRCP28PS (66,W0) / VRCP28PD (66,W1) [ER] — 512-bit only
  202 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      if pfx.rex_w then {
        write_zmm(dst, avx_vrcp28pd_512(evex_src_zmm(modrm, rm, pfx))); Ok(())
      } else {
        write_zmm(dst, avx_vrcp28ps_512(evex_src_zmm(modrm, rm, pfx))); Ok(())
      }
    }
  },

  // 0F38 CB: VRCP28SS (66,W0) / VRCP28SD (66,W1) [ER] — scalar
  203 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
      let src1 = read_zmm(pfx.evex_vvvvv);
      if pfx.rex_w then {
        let src2 = evex_src_xmm(modrm, rm, pfx);
        write_zmm(dst, src1[511..64] @ __f64_rcp28(src2[63..0])); Ok(())
      } else {
        let src2 = evex_src_xmm(modrm, rm, pfx);
        write_zmm(dst, src1[511..32] @ __f32_rcp28(src2[31..0])); Ok(())
      }
    }
  },

  // 0F38 CC: VRSQRT28PS (66,W0) / VRSQRT28PD (66,W1) [ER] — 512-bit only
  204 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      if pfx.rex_w then {
        write_zmm(dst, avx_vrsqrt28pd_512(evex_src_zmm(modrm, rm, pfx))); Ok(())
      } else {
        write_zmm(dst, avx_vrsqrt28ps_512(evex_src_zmm(modrm, rm, pfx))); Ok(())
      }
    }
  },

  // 0F38 CD: VRSQRT28SS (66,W0) / VRSQRT28SD (66,W1) [ER] — scalar
  205 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
      let src1 = read_zmm(pfx.evex_vvvvv);
      if pfx.rex_w then {
        let src2 = evex_src_xmm(modrm, rm, pfx);
        write_zmm(dst, src1[511..64] @ __f64_rsqrt28(src2[63..0])); Ok(())
      } else {
        let src2 = evex_src_xmm(modrm, rm, pfx);
        write_zmm(dst, src1[511..32] @ __f32_rsqrt28(src2[31..0])); Ok(())
      }
    }
  },

  // 0F38 CF: VGF2P8MULB (66,W0) [GFNI]
  207 => {
    if mp != MP_66 | pfx.rex_w then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_gf2p8mulb_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_gf2p8mulb_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_gf2p8mulb_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  _ => raise_UD(),
  }
}

// =========================================================================
// EVEX 0F3A map dispatch
// =========================================================================

val dispatch_evex_0f3a : (byte, Prefixes) -> ExecutionResult
function dispatch_evex_0f3a(opcode, pfx) = {
  let op : range(0, 255) = unsigned(opcode);
  let mp = get_mandatory_prefix(pfx);

  match op {

  // 0F3A 00: VPERMQ (66, W=1) — imm8-controlled qword permute (256/512)
  0 => {
    if mp != MP_66 | not_bool(pfx.vex_w) then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let imm = fetch_byte();
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_vpermq_imm_512(evex_src_zmm(modrm, rm, pfx), imm)); Ok(()) },
        1 => { write_ymm(dst, avx_vpermq_imm_256(evex_src_ymm(modrm, rm, pfx), imm)); Ok(()) },
        _ => raise_UD(),
      }
    }
  },

  // 0F3A 01: VPERMPD (66, W=1) — imm8-controlled qword permute for FP doubles (256/512)
  1 => {
    if mp != MP_66 | not_bool(pfx.vex_w) then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let imm = fetch_byte();
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_vpermq_imm_512(evex_src_zmm(modrm, rm, pfx), imm)); Ok(()) },
        1 => { write_ymm(dst, avx_vpermq_imm_256(evex_src_ymm(modrm, rm, pfx), imm)); Ok(()) },
        _ => raise_UD(),
      }
    }
  },

  // 0F3A 03: VALIGND (66, W=0) / VALIGNQ (66, W=1)
  3 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let imm = fetch_byte();
      if pfx.vex_w then {
        // VALIGNQ
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_valignq_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx), imm)); Ok(()) },
          1 => { write_ymm(dst, avx_valignq_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx), imm)); Ok(()) },
          _ => { write_xmm(dst, avx_valignq_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx), imm)); Ok(()) },
        }
      } else {
        // VALIGND
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_valignd_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx), imm)); Ok(()) },
          1 => { write_ymm(dst, avx_valignd_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx), imm)); Ok(()) },
          _ => { write_xmm(dst, avx_valignd_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx), imm)); Ok(()) },
        }
      }
    }
  },

  // 0F3A 04: VPERMILPS (66, W=0) — imm8-controlled in-lane dword permute
  4 => {
    if mp != MP_66 | pfx.vex_w then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let imm = fetch_byte();
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_vpermilps_imm_512(evex_src_zmm(modrm, rm, pfx), imm)); Ok(()) },
        1 => { write_ymm(dst, avx_vpermilps_imm_256(evex_src_ymm(modrm, rm, pfx), imm)); Ok(()) },
        _ => { write_xmm(dst, avx_vpermilps_imm_128(evex_src_xmm(modrm, rm, pfx), imm)); Ok(()) },
      }
    }
  },

  // 0F3A 05: VPERMILPD (66, W=1) — imm8-controlled in-lane qword permute
  5 => {
    if mp != MP_66 | not_bool(pfx.vex_w) then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let imm = fetch_byte();
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_vpermilpd_imm_512(evex_src_zmm(modrm, rm, pfx), imm)); Ok(()) },
        1 => { write_ymm(dst, avx_vpermilpd_imm_256(evex_src_ymm(modrm, rm, pfx), imm)); Ok(()) },
        _ => { write_xmm(dst, avx_vpermilpd_imm_128(evex_src_xmm(modrm, rm, pfx), imm)); Ok(()) },
      }
    }
  },

  // 0F3A 0F: VPALIGNR (66) — byte-align concatenation per 128-bit lane
  15 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let imm = fetch_byte();
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_palignr_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx), imm)); Ok(()) },
        1 => { write_ymm(dst, avx_palignr_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx), imm)); Ok(()) },
        _ => { write_xmm(dst, avx_palignr_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx), imm)); Ok(()) },
      }
    }
  },

  // 0F3A 14: VPEXTRB (66) — extract byte from XMM to GPR/mem
  20 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let src = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, 1);
      let imm = fetch_byte();
      let sel : range(0, 15) = unsigned(imm[3..0]);
      let src_xmm = read_xmm(src);
      let lo : range(0, 120) = sel * 8;
      let extracted_byte : byte = src_xmm[(lo + 7)..lo];
      match rm {
        RM_reg(_) => {
          write_gpr32(modrm_rm_reg(modrm, pfx), zero_extend(extracted_byte));
          Ok(())
        },
        RM_mem(addr) => {
          mem_write8(fixup_addr(addr), extracted_byte);
          Ok(())
        },
      }
    }
  },

  // 0F3A 15: VPEXTRW (66) — extract word from XMM to GPR/mem
  21 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let src = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, 2);
      let imm = fetch_byte();
      let sel : range(0, 7) = unsigned(imm[2..0]);
      let src_xmm = read_xmm(src);
      let lo : range(0, 112) = sel * 16;
      let extracted_word : word = src_xmm[(lo + 15)..lo];
      match rm {
        RM_reg(_) => {
          write_gpr32(modrm_rm_reg(modrm, pfx), zero_extend(extracted_word));
          Ok(())
        },
        RM_mem(addr) => {
          mem_write16(fixup_addr(addr), extracted_word);
          Ok(())
        },
      }
    }
  },

  // 0F3A 16: VPEXTRD (66, W=0) / VPEXTRQ (66, W=1) — extract dword/qword from XMM
  22 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let src = evex_reg_idx(modrm, pfx);
      let src_xmm = read_xmm(src);
      if pfx.vex_w then {
        // VPEXTRQ: imm8[0] selects qword
        let rm = decode_rm_evex(modrm, pfx, 8);
        let imm = fetch_byte();
        let sel : range(0, 1) = unsigned(imm[0..0]);
        let lo : range(0, 64) = sel * 64;
        let extracted : qword = src_xmm[(lo + 63)..lo];
        match rm {
          RM_reg(_) => {
            write_gpr64(modrm_rm_reg(modrm, pfx), extracted);
            Ok(())
          },
          RM_mem(addr) => {
            mem_write64(fixup_addr(addr), extracted);
            Ok(())
          },
        }
      } else {
        // VPEXTRD: imm8[1:0] selects dword
        let rm = decode_rm_evex(modrm, pfx, 4);
        let imm = fetch_byte();
        let sel : range(0, 3) = unsigned(imm[1..0]);
        let lo : range(0, 96) = sel * 32;
        let extracted : dword = src_xmm[(lo + 31)..lo];
        match rm {
          RM_reg(_) => {
            write_gpr32(modrm_rm_reg(modrm, pfx), extracted);
            Ok(())
          },
          RM_mem(addr) => {
            mem_write32(fixup_addr(addr), extracted);
            Ok(())
          },
        }
      }
    }
  },

  // 0F3A 17: VEXTRACTPS (66) — extract single-precision FP from XMM to GPR/mem32
  23 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let src = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, 4);
      let imm = fetch_byte();
      let sel : range(0, 3) = unsigned(imm[1..0]);
      let src_xmm = read_xmm(src);
      let lo : range(0, 96) = sel * 32;
      let extracted : dword = src_xmm[(lo + 31)..lo];
      match rm {
        RM_reg(_) => {
          write_gpr32(modrm_rm_reg(modrm, pfx), extracted);
          Ok(())
        },
        RM_mem(addr) => {
          mem_write32(fixup_addr(addr), extracted);
          Ok(())
        },
      }
    }
  },

  // 0F3A 18: VINSERTF32X4 (66, W=0) / VINSERTF64X2 (66, W=1) — insert 128-bit into 256/512
  24 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, 16);
      let src2 : xmmword = evex_src_xmm(modrm, rm, pfx);
      let imm = fetch_byte();
      match pfx.evex_ll {
        2 => {
          // 512-bit: imm8[1:0] selects which 128-bit lane
          var result = read_zmm(pfx.evex_vvvvv);
          let sel : range(0, 3) = unsigned(imm[1..0]);
          match sel {
            0 => result[127..0] = src2,
            1 => result[255..128] = src2,
            2 => result[383..256] = src2,
            _ => result[511..384] = src2,
          };
          write_zmm(dst, result); Ok(())
        },
        1 => {
          // 256-bit: imm8[0] selects which 128-bit lane
          var result = read_ymm(pfx.evex_vvvvv);
          if imm[0] == bitzero then result[127..0] = src2
          else result[255..128] = src2;
          write_ymm(dst, result); Ok(())
        },
        _ => raise_UD(),
      }
    }
  },

  // 0F3A 19: VEXTRACTF32X4 (66, W=0) / VEXTRACTF64X2 (66, W=1) — extract 128-bit from 256/512
  25 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let src = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, 16);
      let imm = fetch_byte();
      match pfx.evex_ll {
        2 => {
          let src_zmm = read_zmm(src);
          let sel : range(0, 3) = unsigned(imm[1..0]);
          let extracted : xmmword = match sel {
            0 => src_zmm[127..0],
            1 => src_zmm[255..128],
            2 => src_zmm[383..256],
            _ => src_zmm[511..384],
          };
          match rm {
            RM_reg(_) => { write_xmm(evex_rm_reg_idx(modrm, pfx), extracted); Ok(()) },
            RM_mem(addr) => { mem_write128(fixup_addr(addr), extracted); Ok(()) },
          }
        },
        1 => {
          let src_ymm = read_ymm(src);
          let extracted : xmmword = if imm[0] == bitzero then src_ymm[127..0] else src_ymm[255..128];
          match rm {
            RM_reg(_) => { write_xmm(evex_rm_reg_idx(modrm, pfx), extracted); Ok(()) },
            RM_mem(addr) => { mem_write128(fixup_addr(addr), extracted); Ok(()) },
          }
        },
        _ => raise_UD(),
      }
    }
  },

  // 0F3A 1A: VINSERTF32X8 (66, W=0) / VINSERTF64X4 (66, W=1) — insert 256-bit into 512
  26 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, 32);
      let src2 : ymmword = evex_src_ymm(modrm, rm, pfx);
      let imm = fetch_byte();
      match pfx.evex_ll {
        2 => {
          // 512-bit only: imm8[0] selects which 256-bit half
          var result = read_zmm(pfx.evex_vvvvv);
          if imm[0] == bitzero then result[255..0] = src2
          else result[511..256] = src2;
          write_zmm(dst, result); Ok(())
        },
        _ => raise_UD(),
      }
    }
  },

  // 0F3A 1B: VEXTRACTF32X8 (66, W=0) / VEXTRACTF64X4 (66, W=1) — extract 256-bit from 512
  27 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let src = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, 32);
      let imm = fetch_byte();
      match pfx.evex_ll {
        2 => {
          let src_zmm = read_zmm(src);
          let extracted : ymmword = if imm[0] == bitzero then src_zmm[255..0] else src_zmm[511..256];
          match rm {
            RM_reg(_) => { write_ymm(evex_rm_reg_idx(modrm, pfx), extracted); Ok(()) },
            RM_mem(addr) => { mem_write256(fixup_addr(addr), extracted); Ok(()) },
          }
        },
        _ => raise_UD(),
      }
    }
  },

  // 0F3A 1D: VCVTPS2PH (66, W=0) — convert FP32 to FP16 with imm8 rounding
  29 => {
    if mp != MP_66 | pfx.rex_w then raise_UD()
    else {
      let modrm = fetch_byte();
      let src = evex_reg_idx(modrm, pfx);
      let _imm = fetch_byte(); // rounding control (ignored for now, using truncation)
      match pfx.evex_ll {
        2 => { let res = avx_vcvtps2ph_512(read_zmm(src));
               let rm = decode_rm_evex(modrm, pfx, 32);
               match rm { RM_reg(_) => { write_ymm(evex_rm_reg_idx(modrm, pfx), res); Ok(()) },
                           RM_mem(addr) => { mem_write256(fixup_addr(addr), res); Ok(()) } } },
        1 => { let res = avx_vcvtps2ph_256(read_ymm(src));
               let rm = decode_rm_evex(modrm, pfx, 16);
               match rm { RM_reg(_) => { write_xmm(evex_rm_reg_idx(modrm, pfx), res); Ok(()) },
                           RM_mem(addr) => { mem_write128(fixup_addr(addr), res); Ok(()) } } },
        _ => { let res = avx_vcvtps2ph_128(read_xmm(src));
               let rm = decode_rm_evex(modrm, pfx, 8);
               match rm { RM_reg(_) => { write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)); Ok(()) },
                           RM_mem(addr) => { mem_write64(fixup_addr(addr), res); Ok(()) } } },
      }
    }
  },

  // 0F3A 1F: VPCMPUD (66, W=0) — unsigned dword compare → kmask
  31 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst_k : range(0, 7) = unsigned(modrm[5..3]);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let imm = fetch_byte();
      let pred : range(0, 7) = unsigned(imm[2..0]);
      match pfx.evex_ll {
        2 => {
          let mask : word = avx_pcmpud_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx), pred);
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask); Ok(())
        },
        1 => {
          let mask : byte = avx_pcmpud_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx), pred);
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask); Ok(())
        },
        _ => {
          let mask : byte = avx_pcmpud_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx), pred);
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask); Ok(())
        },
      }
    }
  },

  // 0F3A 25: VPTERNLOGD (66, W=0) / VPTERNLOGQ (66, W=1)
  37 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let imm = fetch_byte();
      match pfx.evex_ll {
        2 => {
          let a = read_zmm(dst);
          let b = read_zmm(pfx.evex_vvvvv);
          let c = evex_src_zmm(modrm, rm, pfx);
          write_zmm(dst, vpternlog_512(a, b, c, imm)); Ok(())
        },
        1 => {
          let a = read_ymm(dst);
          let b = read_ymm(pfx.evex_vvvvv);
          let c = evex_src_ymm(modrm, rm, pfx);
          write_ymm(dst, vpternlog_256(a, b, c, imm)); Ok(())
        },
        _ => {
          let a = read_xmm(dst);
          let b = read_xmm(pfx.evex_vvvvv);
          let c = evex_src_xmm(modrm, rm, pfx);
          write_xmm(dst, vpternlog_128(a, b, c, imm)); Ok(())
        },
      }
    }
  },

  // 0F3A 20: VPINSRB (66) — insert byte from GPR/mem into XMM
  32 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, 1);
      let byte_val : byte = match rm {
        RM_reg(_) => read_gpr32(modrm_rm_reg(modrm, pfx))[7..0],
        RM_mem(addr) => mem_read8(fixup_addr(addr)),
      };
      let imm = fetch_byte();
      let sel : range(0, 15) = unsigned(imm[3..0]);
      var result = read_xmm(pfx.evex_vvvvv);
      let lo : range(0, 120) = sel * 8;
      result[(lo + 7)..lo] = byte_val;
      write_xmm(dst, result);
      Ok(())
    }
  },

  // 0F3A 21: VINSERTPS (66, W=0) — insert single-precision from XMM/mem into XMM
  33 => {
    if mp != MP_66 | pfx.vex_w then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, 4);
      let imm = fetch_byte();
      // For register source: imm8[7:6] selects which float from src
      // For memory source: always reads a single 32-bit float
      let src_float : dword = match rm {
        RM_reg(_) => {
          let src_xmm = read_xmm(evex_rm_reg_idx(modrm, pfx));
          let count_s : range(0, 3) = unsigned(imm[7..6]);
          let slo : range(0, 96) = count_s * 32;
          src_xmm[(slo + 31)..slo]
        },
        RM_mem(addr) => mem_read32(fixup_addr(addr)),
      };
      // imm8[5:4] selects destination float position
      let count_d : range(0, 3) = unsigned(imm[5..4]);
      let dlo : range(0, 96) = count_d * 32;
      var result = read_xmm(pfx.evex_vvvvv);
      result[(dlo + 31)..dlo] = src_float;
      // imm8[3:0] = zero mask for each float
      if imm[0] == bitone then result[31..0] = zeros();
      if imm[1] == bitone then result[63..32] = zeros();
      if imm[2] == bitone then result[95..64] = zeros();
      if imm[3] == bitone then result[127..96] = zeros();
      write_xmm(dst, result);
      Ok(())
    }
  },

  // 0F3A 22: VPINSRD (66, W=0) / VPINSRQ (66, W=1) — insert dword/qword from GPR/mem into XMM
  34 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      if pfx.vex_w then {
        // VPINSRQ: imm8[0] selects qword position
        let rm = decode_rm_evex(modrm, pfx, 8);
        let qword_val : qword = match rm {
          RM_reg(_) => read_gpr64(modrm_rm_reg(modrm, pfx)),
          RM_mem(addr) => mem_read64(fixup_addr(addr)),
        };
        let imm = fetch_byte();
        let sel : range(0, 1) = unsigned(imm[0..0]);
        var result = read_xmm(pfx.evex_vvvvv);
        let lo : range(0, 64) = sel * 64;
        result[(lo + 63)..lo] = qword_val;
        write_xmm(dst, result);
        Ok(())
      } else {
        // VPINSRD: imm8[1:0] selects dword position
        let rm = decode_rm_evex(modrm, pfx, 4);
        let dword_val : dword = match rm {
          RM_reg(_) => read_gpr32(modrm_rm_reg(modrm, pfx)),
          RM_mem(addr) => mem_read32(fixup_addr(addr)),
        };
        let imm = fetch_byte();
        let sel : range(0, 3) = unsigned(imm[1..0]);
        var result = read_xmm(pfx.evex_vvvvv);
        let lo : range(0, 96) = sel * 32;
        result[(lo + 31)..lo] = dword_val;
        write_xmm(dst, result);
        Ok(())
      }
    }
  },

  // 0F3A 38: VINSERTI32X4 (66, W=0) / VINSERTI64X2 (66, W=1) — insert 128-bit (integer) into 256/512
  56 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, 16);
      let src2 : xmmword = evex_src_xmm(modrm, rm, pfx);
      let imm = fetch_byte();
      match pfx.evex_ll {
        2 => {
          var result = read_zmm(pfx.evex_vvvvv);
          let sel : range(0, 3) = unsigned(imm[1..0]);
          match sel {
            0 => result[127..0] = src2,
            1 => result[255..128] = src2,
            2 => result[383..256] = src2,
            _ => result[511..384] = src2,
          };
          write_zmm(dst, result); Ok(())
        },
        1 => {
          var result = read_ymm(pfx.evex_vvvvv);
          if imm[0] == bitzero then result[127..0] = src2
          else result[255..128] = src2;
          write_ymm(dst, result); Ok(())
        },
        _ => raise_UD(),
      }
    }
  },

  // 0F3A 39: VEXTRACTI32X4 (66, W=0) / VEXTRACTI64X2 (66, W=1) — extract 128-bit from 256/512
  57 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let src = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, 16);
      let imm = fetch_byte();
      match pfx.evex_ll {
        2 => {
          let src_zmm = read_zmm(src);
          let sel : range(0, 3) = unsigned(imm[1..0]);
          let extracted : xmmword = match sel {
            0 => src_zmm[127..0],
            1 => src_zmm[255..128],
            2 => src_zmm[383..256],
            _ => src_zmm[511..384],
          };
          match rm {
            RM_reg(_) => { write_xmm(evex_rm_reg_idx(modrm, pfx), extracted); Ok(()) },
            RM_mem(addr) => { mem_write128(fixup_addr(addr), extracted); Ok(()) },
          }
        },
        1 => {
          let src_ymm = read_ymm(src);
          let extracted : xmmword = if imm[0] == bitzero then src_ymm[127..0] else src_ymm[255..128];
          match rm {
            RM_reg(_) => { write_xmm(evex_rm_reg_idx(modrm, pfx), extracted); Ok(()) },
            RM_mem(addr) => { mem_write128(fixup_addr(addr), extracted); Ok(()) },
          }
        },
        _ => raise_UD(),
      }
    }
  },

  // 0F3A 3A: VINSERTI32X8 (66, W=0) / VINSERTI64X4 (66, W=1) — insert 256-bit into 512
  58 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, 32);
      let src2 : ymmword = evex_src_ymm(modrm, rm, pfx);
      let imm = fetch_byte();
      match pfx.evex_ll {
        2 => {
          var result = read_zmm(pfx.evex_vvvvv);
          if imm[0] == bitzero then result[255..0] = src2
          else result[511..256] = src2;
          write_zmm(dst, result); Ok(())
        },
        _ => raise_UD(),
      }
    }
  },

  // 0F3A 3B: VEXTRACTI32X8 (66, W=0) / VEXTRACTI64X4 (66, W=1) — extract 256-bit from 512
  59 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let src = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, 32);
      let imm = fetch_byte();
      match pfx.evex_ll {
        2 => {
          let src_zmm = read_zmm(src);
          let extracted : ymmword = if imm[0] == bitzero then src_zmm[255..0] else src_zmm[511..256];
          match rm {
            RM_reg(_) => { write_ymm(evex_rm_reg_idx(modrm, pfx), extracted); Ok(()) },
            RM_mem(addr) => { mem_write256(fixup_addr(addr), extracted); Ok(()) },
          }
        },
        _ => raise_UD(),
      }
    }
  },

  // 0F3A 3E: VPCMPUB (66, W=0) — unsigned byte compare → kmask
  62 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst_k : range(0, 7) = unsigned(modrm[5..3]);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let imm = fetch_byte();
      let pred : range(0, 7) = unsigned(imm[2..0]);
      match pfx.evex_ll {
        2 => {
          let mask = avx_pcmpub_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx), pred);
          let k_mask : qword = if pfx.evex_aaa == 0 then mask else mask & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask); Ok(())
        },
        1 => {
          let mask : dword = avx_pcmpub_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx), pred);
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask); Ok(())
        },
        _ => {
          let mask : word = avx_pcmpub_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx), pred);
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask); Ok(())
        },
      }
    }
  },

  // 0F3A 3F: VPCMPB (66, W=0) — signed byte compare → kmask
  63 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst_k : range(0, 7) = unsigned(modrm[5..3]);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let imm = fetch_byte();
      let pred : range(0, 7) = unsigned(imm[2..0]);
      match pfx.evex_ll {
        2 => {
          let mask = avx_pcmpb_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx), pred);
          let k_mask : qword = if pfx.evex_aaa == 0 then mask else mask & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask); Ok(())
        },
        1 => {
          let mask : dword = avx_pcmpb_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx), pred);
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask); Ok(())
        },
        _ => {
          let mask : word = avx_pcmpb_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx), pred);
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask); Ok(())
        },
      }
    }
  },

  // 0F3A 08: VRNDSCALEPS (66, W=0) — round packed single-precision
  8 => {
    if mp != MP_66 | pfx.vex_w then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let imm = fetch_byte();
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_vrndscaleps_512(evex_src_zmm(modrm, rm, pfx), imm)); Ok(()) },
        1 => { write_ymm(dst, avx_vrndscaleps_256(evex_src_ymm(modrm, rm, pfx), imm)); Ok(()) },
        _ => { write_xmm(dst, avx_vrndscaleps_128(evex_src_xmm(modrm, rm, pfx), imm)); Ok(()) },
      }
    }
  },

  // 0F3A 09: VRNDSCALEPD (66, W=1) — round packed double-precision
  9 => {
    if mp != MP_66 | not_bool(pfx.vex_w) then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let imm = fetch_byte();
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_vrndscalepd_512(evex_src_zmm(modrm, rm, pfx), imm)); Ok(()) },
        1 => { write_ymm(dst, avx_vrndscalepd_256(evex_src_ymm(modrm, rm, pfx), imm)); Ok(()) },
        _ => { write_xmm(dst, avx_vrndscalepd_128(evex_src_xmm(modrm, rm, pfx), imm)); Ok(()) },
      }
    }
  },

  // 0F3A 0A: VRNDSCALESS (66, W=0) — round scalar single-precision
  10 => {
    if mp != MP_66 | pfx.vex_w then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, 4);
      let imm = fetch_byte();
      let src1 = read_xmm(pfx.evex_vvvvv);
      let src2 = evex_src_xmm(modrm, rm, pfx);
      let r = __f32_rndscale(src2[31..0], imm);
      write_xmm(dst, src1[127..32] @ r); Ok(())
    }
  },

  // 0F3A 0B: VRNDSCALESD (66, W=1) — round scalar double-precision
  11 => {
    if mp != MP_66 | not_bool(pfx.vex_w) then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, 8);
      let imm = fetch_byte();
      let src1 = read_xmm(pfx.evex_vvvvv);
      let src2 = evex_src_xmm(modrm, rm, pfx);
      let r = __f64_rndscale(src2[63..0], imm);
      write_xmm(dst, src1[127..64] @ r); Ok(())
    }
  },

  // 0F3A 23: VSHUFF32X4 (66, W=0) / VSHUFF64X2 (66, W=1) — shuffle 128-bit lanes (FP)
  35 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let imm = fetch_byte();
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_shuf_f32x4_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx), imm)); Ok(()) },
        1 => { write_ymm(dst, avx_shuf_f32x4_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx), imm)); Ok(()) },
        _ => raise_UD(),
      }
    }
  },

  // 0F3A 26: VGETMANTPS (66, W=0) / VGETMANTPD (66, W=1) — extract mantissa packed
  38 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let imm = fetch_byte();
      if pfx.vex_w then {
        // VGETMANTPD
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_vgetmantpd_512(evex_src_zmm(modrm, rm, pfx), imm)); Ok(()) },
          1 => { write_ymm(dst, avx_vgetmantpd_256(evex_src_ymm(modrm, rm, pfx), imm)); Ok(()) },
          _ => { write_xmm(dst, avx_vgetmantpd_128(evex_src_xmm(modrm, rm, pfx), imm)); Ok(()) },
        }
      } else {
        // VGETMANTPS
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_vgetmantps_512(evex_src_zmm(modrm, rm, pfx), imm)); Ok(()) },
          1 => { write_ymm(dst, avx_vgetmantps_256(evex_src_ymm(modrm, rm, pfx), imm)); Ok(()) },
          _ => { write_xmm(dst, avx_vgetmantps_128(evex_src_xmm(modrm, rm, pfx), imm)); Ok(()) },
        }
      }
    }
  },

  // 0F3A 27: VGETMANTSS (66, W=0) / VGETMANTSD (66, W=1) — extract mantissa scalar
  39 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, if pfx.vex_w then 8 else 4);
      let imm = fetch_byte();
      let src1 = read_xmm(pfx.evex_vvvvv);
      let src2 = evex_src_xmm(modrm, rm, pfx);
      if pfx.vex_w then {
        let r = __f64_getmant(src2[63..0], imm);
        write_xmm(dst, src1[127..64] @ r); Ok(())
      } else {
        let r = __f32_getmant(src2[31..0], imm);
        write_xmm(dst, src1[127..32] @ r); Ok(())
      }
    }
  },

  // 0F3A 42: VDBPSADBW (66, W=0) — double block packed sum of absolute differences
  66 => {
    if mp != MP_66 | pfx.vex_w then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let imm = fetch_byte();
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_vdbpsadbw_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx), imm)); Ok(()) },
        1 => { write_ymm(dst, avx_vdbpsadbw_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx), imm)); Ok(()) },
        _ => { write_xmm(dst, avx_vdbpsadbw_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx), imm)); Ok(()) },
      }
    }
  },

  // 0F3A 43: VSHUFI32X4 (66, W=0) / VSHUFI64X2 (66, W=1) — shuffle 128-bit lanes (integer)
  67 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let imm = fetch_byte();
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_shuf_f32x4_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx), imm)); Ok(()) },
        1 => { write_ymm(dst, avx_shuf_f32x4_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx), imm)); Ok(()) },
        _ => raise_UD(),
      }
    }
  },

  // 0F3A 44: VPCLMULQDQ (66) — carry-less multiply per 128-bit lane [VPCLMULQDQ]
  68 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let imm = fetch_byte();
      let src1_idx = pfx.evex_vvvvv;
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_vpclmulqdq_512(read_zmm(src1_idx), evex_src_zmm(modrm, rm, pfx), imm)); Ok(()) },
        1 => { write_ymm(dst, avx_vpclmulqdq_256(read_ymm(src1_idx), evex_src_ymm(modrm, rm, pfx), imm)); Ok(()) },
        _ => { write_xmm(dst, avx_vpclmulqdq_128(read_xmm(src1_idx), evex_src_xmm(modrm, rm, pfx), imm)); Ok(()) },
      }
    }
  },

  // 0F3A 50: VRANGEPS (66, W=0) / VRANGEPD (66, W=1) — range restriction packed [DQ]
  80 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let imm = fetch_byte();
      if pfx.vex_w then {
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_vrangepd_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx), imm)); Ok(()) },
          1 => { write_ymm(dst, avx_vrangepd_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx), imm)); Ok(()) },
          _ => { write_xmm(dst, avx_vrangepd_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx), imm)); Ok(()) },
        }
      } else {
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_vrangeps_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx), imm)); Ok(()) },
          1 => { write_ymm(dst, avx_vrangeps_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx), imm)); Ok(()) },
          _ => { write_xmm(dst, avx_vrangeps_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx), imm)); Ok(()) },
        }
      }
    }
  },

  // 0F3A 54: VFIXUPIMMPS (66, W=0) / VFIXUPIMMPD (66, W=1) — fixup packed
  84 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let imm = fetch_byte();
      if pfx.vex_w then {
        // VFIXUPIMMPD
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_vfixupimmpd_512(read_zmm(dst), read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx), imm)); Ok(()) },
          1 => { write_ymm(dst, avx_vfixupimmpd_256(read_ymm(dst), read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx), imm)); Ok(()) },
          _ => { write_xmm(dst, avx_vfixupimmpd_128(read_xmm(dst), read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx), imm)); Ok(()) },
        }
      } else {
        // VFIXUPIMMPS
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_vfixupimmps_512(read_zmm(dst), read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx), imm)); Ok(()) },
          1 => { write_ymm(dst, avx_vfixupimmps_256(read_ymm(dst), read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx), imm)); Ok(()) },
          _ => { write_xmm(dst, avx_vfixupimmps_128(read_xmm(dst), read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx), imm)); Ok(()) },
        }
      }
    }
  },

  // 0F3A 55: VFIXUPIMMSS (66, W=0) / VFIXUPIMMSD (66, W=1) — fixup scalar
  85 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, if pfx.vex_w then 8 else 4);
      let imm = fetch_byte();
      let src1 = read_xmm(pfx.evex_vvvvv);
      let src2 = evex_src_xmm(modrm, rm, pfx);
      let dst_xmm = read_xmm(dst);
      if pfx.vex_w then {
        // VFIXUPIMMSD
        let r = __f64_fixupimm(dst_xmm[63..0], src1[63..0], src2[63..0], imm);
        write_xmm(dst, src1[127..64] @ r); Ok(())
      } else {
        // VFIXUPIMMSS
        let r = __f32_fixupimm(dst_xmm[31..0], src1[31..0], src2[31..0], imm);
        write_xmm(dst, src1[127..32] @ r); Ok(())
      }
    }
  },

  // 0F3A 56: VREDUCEPS (66, W=0) / VREDUCEPD (66, W=1) — reduce packed
  86 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let imm = fetch_byte();
      if pfx.vex_w then {
        // VREDUCEPD
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_vreducepd_512(evex_src_zmm(modrm, rm, pfx), imm)); Ok(()) },
          1 => { write_ymm(dst, avx_vreducepd_256(evex_src_ymm(modrm, rm, pfx), imm)); Ok(()) },
          _ => { write_xmm(dst, avx_vreducepd_128(evex_src_xmm(modrm, rm, pfx), imm)); Ok(()) },
        }
      } else {
        // VREDUCEPS
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_vreduceps_512(evex_src_zmm(modrm, rm, pfx), imm)); Ok(()) },
          1 => { write_ymm(dst, avx_vreduceps_256(evex_src_ymm(modrm, rm, pfx), imm)); Ok(()) },
          _ => { write_xmm(dst, avx_vreduceps_128(evex_src_xmm(modrm, rm, pfx), imm)); Ok(()) },
        }
      }
    }
  },

  // 0F3A 57: VREDUCESS (66, W=0) / VREDUCESD (66, W=1) — reduce scalar
  87 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, if pfx.vex_w then 8 else 4);
      let imm = fetch_byte();
      let src1 = read_xmm(pfx.evex_vvvvv);
      let src2 = evex_src_xmm(modrm, rm, pfx);
      if pfx.vex_w then {
        let r = __f64_reduce(src2[63..0], imm);
        write_xmm(dst, src1[127..64] @ r); Ok(())
      } else {
        let r = __f32_reduce(src2[31..0], imm);
        write_xmm(dst, src1[127..32] @ r); Ok(())
      }
    }
  },

  // 0F3A 66: VFPCLASSPS (66, W=0) / VFPCLASSPD (66, W=1) — classify packed → kmask [DQ]
  102 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst_k : range(0, 7) = unsigned(modrm[5..3]);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let imm = fetch_byte();
      if pfx.vex_w then {
        // VFPCLASSPD
        match pfx.evex_ll {
          2 => {
            let mask : byte = avx_vfpclasspd_512(evex_src_zmm(modrm, rm, pfx), imm);
            let k_val : qword = zero_extend(mask);
            let k_mask : qword = if pfx.evex_aaa == 0 then k_val else k_val & read_kreg(pfx.evex_aaa);
            write_kreg(dst_k, k_mask); Ok(())
          },
          1 => {
            let mask : byte = avx_vfpclasspd_256(evex_src_ymm(modrm, rm, pfx), imm);
            let k_val : qword = zero_extend(mask);
            let k_mask : qword = if pfx.evex_aaa == 0 then k_val else k_val & read_kreg(pfx.evex_aaa);
            write_kreg(dst_k, k_mask); Ok(())
          },
          _ => {
            let mask : byte = avx_vfpclasspd_128(evex_src_xmm(modrm, rm, pfx), imm);
            let k_val : qword = zero_extend(mask);
            let k_mask : qword = if pfx.evex_aaa == 0 then k_val else k_val & read_kreg(pfx.evex_aaa);
            write_kreg(dst_k, k_mask); Ok(())
          },
        }
      } else {
        // VFPCLASSPS
        match pfx.evex_ll {
          2 => {
            let mask : word = avx_vfpclassps_512(evex_src_zmm(modrm, rm, pfx), imm);
            let k_val : qword = zero_extend(mask);
            let k_mask : qword = if pfx.evex_aaa == 0 then k_val else k_val & read_kreg(pfx.evex_aaa);
            write_kreg(dst_k, k_mask); Ok(())
          },
          1 => {
            let mask : byte = avx_vfpclassps_256(evex_src_ymm(modrm, rm, pfx), imm);
            let k_val : qword = zero_extend(mask);
            let k_mask : qword = if pfx.evex_aaa == 0 then k_val else k_val & read_kreg(pfx.evex_aaa);
            write_kreg(dst_k, k_mask); Ok(())
          },
          _ => {
            let mask : byte = avx_vfpclassps_128(evex_src_xmm(modrm, rm, pfx), imm);
            let k_val : qword = zero_extend(mask);
            let k_mask : qword = if pfx.evex_aaa == 0 then k_val else k_val & read_kreg(pfx.evex_aaa);
            write_kreg(dst_k, k_mask); Ok(())
          },
        }
      }
    }
  },

  // 0F3A 67: VFPCLASSSS (66, W=0) / VFPCLASSSD (66, W=1) — classify scalar → kmask [DQ]
  103 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst_k : range(0, 7) = unsigned(modrm[5..3]);
      let rm = decode_rm_evex(modrm, pfx, if pfx.vex_w then 8 else 4);
      let imm = fetch_byte();
      let src = evex_src_xmm(modrm, rm, pfx);
      if pfx.vex_w then {
        let result : bool = avx_fpclass_f64(src[63..0], imm);
        let k_val : qword = if result then zero_extend(0b1 : bits(1)) else zeros();
        let k_mask : qword = if pfx.evex_aaa == 0 then k_val else k_val & read_kreg(pfx.evex_aaa);
        write_kreg(dst_k, k_mask); Ok(())
      } else {
        let result : bool = avx_fpclass_f32(src[31..0], imm);
        let k_val : qword = if result then zero_extend(0b1 : bits(1)) else zeros();
        let k_mask : qword = if pfx.evex_aaa == 0 then k_val else k_val & read_kreg(pfx.evex_aaa);
        write_kreg(dst_k, k_mask); Ok(())
      }
    }
  },

  // 0F3A CE: VGF2P8AFFINEQB (66,W1) [GFNI]
  206 => {
    if mp != MP_66 | not_bool(pfx.rex_w) then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let imm = fetch_byte();
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_gf2p8affineqb_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx), imm)); Ok(()) },
        1 => { write_ymm(dst, avx_gf2p8affineqb_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx), imm)); Ok(()) },
        _ => { write_xmm(dst, avx_gf2p8affineqb_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx), imm)); Ok(()) },
      }
    }
  },

  // 0F3A CF: VGF2P8AFFINEINVQB (66,W1) [GFNI]
  207 => {
    if mp != MP_66 | not_bool(pfx.rex_w) then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let imm = fetch_byte();
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_gf2p8affineinvqb_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx), imm)); Ok(()) },
        1 => { write_ymm(dst, avx_gf2p8affineinvqb_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx), imm)); Ok(()) },
        _ => { write_xmm(dst, avx_gf2p8affineinvqb_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx), imm)); Ok(()) },
      }
    }
  },

  // 0F3A 70: VPSHLDW (66, W=1) [VBMI2]
  112 => {
    if mp != MP_66 | not_bool(pfx.rex_w) then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let imm = fetch_byte();
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_vpshldw_imm_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx), imm)); Ok(()) },
        1 => { write_ymm(dst, avx_vpshldw_imm_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx), imm)); Ok(()) },
        _ => { write_xmm(dst, avx_vpshldw_imm_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx), imm)); Ok(()) },
      }
    }
  },

  // 0F3A 71: VPSHLDD (66, W=0) / VPSHLDQ (66, W=1) [VBMI2]
  113 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let imm = fetch_byte();
      if pfx.rex_w then {
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_vpshldq_imm_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx), imm)); Ok(()) },
          1 => { write_ymm(dst, avx_vpshldq_imm_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx), imm)); Ok(()) },
          _ => { write_xmm(dst, avx_vpshldq_imm_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx), imm)); Ok(()) },
        }
      } else {
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_vpshldd_imm_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx), imm)); Ok(()) },
          1 => { write_ymm(dst, avx_vpshldd_imm_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx), imm)); Ok(()) },
          _ => { write_xmm(dst, avx_vpshldd_imm_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx), imm)); Ok(()) },
        }
      }
    }
  },

  // 0F3A 72: VPSHRDW (66, W=1) [VBMI2]
  114 => {
    if mp != MP_66 | not_bool(pfx.rex_w) then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let imm = fetch_byte();
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_vpshrdw_imm_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx), imm)); Ok(()) },
        1 => { write_ymm(dst, avx_vpshrdw_imm_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx), imm)); Ok(()) },
        _ => { write_xmm(dst, avx_vpshrdw_imm_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx), imm)); Ok(()) },
      }
    }
  },

  // 0F3A 73: VPSHRDD (66, W=0) / VPSHRDQ (66, W=1) [VBMI2]
  115 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let imm = fetch_byte();
      if pfx.rex_w then {
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_vpshrdq_imm_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx), imm)); Ok(()) },
          1 => { write_ymm(dst, avx_vpshrdq_imm_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx), imm)); Ok(()) },
          _ => { write_xmm(dst, avx_vpshrdq_imm_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx), imm)); Ok(()) },
        }
      } else {
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_vpshrdd_imm_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx), imm)); Ok(()) },
          1 => { write_ymm(dst, avx_vpshrdd_imm_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx), imm)); Ok(()) },
          _ => { write_xmm(dst, avx_vpshrdd_imm_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx), imm)); Ok(()) },
        }
      }
    }
  },

  // 0F3A C2: VCMPPH (NP,W0) / VCMPSH (F3,W0) [FP16]
  194 => {
    if pfx.rex_w then raise_UD()
    else match mp {
      MP_NONE => {
        // VCMPPH: packed FP16 compare → kmask
        let modrm = fetch_byte();
        let k_idx : range(0, 7) = evex_reg_idx(modrm, pfx) % 8;
        let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
        match pfx.evex_ll {
          2 => {
            let src1 = read_zmm(pfx.evex_vvvvv);
            let src2 = evex_src_zmm(modrm, rm, pfx);
            let pred_byte = fetch_byte();
            let pred : range(0, 31) = unsigned(pred_byte[4..0]);
            let result = avx_vcmpph_kmask_512(src1, src2, pred);
            write_kreg(k_idx, zero_extend(result));
            Ok(())
          },
          1 => {
            let src1 = read_ymm(pfx.evex_vvvvv);
            let src2 = evex_src_ymm(modrm, rm, pfx);
            let pred_byte = fetch_byte();
            let pred : range(0, 31) = unsigned(pred_byte[4..0]);
            let r = avx_vcmpph_kmask_256(src1, src2, pred);
            write_kreg(k_idx, zero_extend(r));
            Ok(())
          },
          _ => {
            let src1 = read_xmm(pfx.evex_vvvvv);
            let src2 = evex_src_xmm(modrm, rm, pfx);
            let pred_byte = fetch_byte();
            let pred : range(0, 31) = unsigned(pred_byte[4..0]);
            let r = avx_vcmpph_kmask_128(src1, src2, pred);
            write_kreg(k_idx, zero_extend(r));
            Ok(())
          },
        }
      },
      MP_F3 => {
        // VCMPSH: scalar FP16 compare → kmask bit 0
        let modrm = fetch_byte();
        let k_idx : range(0, 7) = evex_reg_idx(modrm, pfx) % 8;
        let rm = decode_rm_evex(modrm, pfx, 2);
        let src1 = read_xmm(pfx.evex_vvvvv);
        let src2 = evex_src_xmm(modrm, rm, pfx);
        let pred_byte = fetch_byte();
        let pred : range(0, 31) = unsigned(pred_byte[4..0]);
        let bit : bool = cmp_pred5_f16(src1[15..0], src2[15..0], pred);
        write_kreg(k_idx, if bit then 0x0000000000000001 else 0x0000000000000000);
        Ok(())
      },
      _ => raise_UD(),
    }
  },

  _ => raise_UD(),
  }
}

// =========================================================================
// Top-level EVEX dispatch — called from 1-byte opcode map for 62h.
// =========================================================================

val dispatch_evex : unit -> ExecutionResult
function dispatch_evex() = {
  let (pfx, map) = decode_evex();
  let opcode = fetch_byte();
  match map {
    1 => dispatch_evex_0f(opcode, pfx),
    2 => dispatch_evex_0f38(opcode, pfx),
    3 => dispatch_evex_0f3a(opcode, pfx),
    _ => raise_UD(),
  }
}

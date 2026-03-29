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
    RM_reg(_) => x87_ST[unsigned(modrm[2..0])][63..0],
    RM_mem(m) => v(m),
  }
}

// MMX dispatch helpers — absorb common modrm + read + write + touch pattern
val mmx_exec_binop : (PackedBinOp, {8, 16, 32, 64}, Prefixes) -> unit
function mmx_exec_binop(op, eb, pfx) = {
  let modrm = fetch(1);
  let dst = unsigned(modrm[5..3]);
  let src = modrm_rm(modrm, pfx);
  x87_ST[dst] = ones(16) @ (packed_binop(op, eb, x87_ST[dst][63..0], mmx_read_rm(modrm, src)))
}

val mmx_exec_shift : (PackedShiftOp, {16, 32, 64}, Prefixes) -> unit
function mmx_exec_shift(op, eb, pfx) = {
  let modrm = fetch(1);
  let dst = unsigned(modrm[5..3]);
  let src = modrm_rm(modrm, pfx);
  let c : nat = unsigned(mmx_read_rm(modrm, src)[63..0]);
  x87_ST[dst] = ones(16) @ (packed_uniform_shift(op, eb, x87_ST[dst][63..0], c))
}

// =========================================================================
// MMX dispatch — handles all 0F xx opcodes when mandatory prefix is NONE
// =========================================================================

function dispatch_mmx(op, pfx) = {
  match op {
    // 0F 60-62: PUNPCKLBW/WD/DQ mm, mm/m32
    // MMX unpack low: interleave low elements from d and s
    op if 96 <= op & op <= 98 => {
      let modrm = fetch(1);
      let dst = unsigned(modrm[5..3]);
      let s : qword = mmx_read_rm(modrm, modrm_rm(modrm, pfx));
      let d : qword = x87_ST[dst][63..0];
      let eb : {8, 16, 32} = match op { 96 => 8, 97 => 16, _ => 32 };
      let n = 32 / eb;
      var r : qword = zeros();
      foreach (i from 0 to (n - 1)) {
        let src_lo = i * eb;
        let dst_lo = i * 2 * eb;
        r[(dst_lo + eb - 1)..dst_lo] = d[(src_lo + eb - 1)..src_lo];
        r[(dst_lo + 2 * eb - 1)..(dst_lo + eb)] = s[(src_lo + eb - 1)..src_lo]
      };
      x87_ST[dst] = ones(16) @ (r)
    },

    // 0F 63: PACKSSWB mm, mm/m64
    99 => {
      let modrm = fetch(1);
      let dst = unsigned(modrm[5..3]);
      let s : qword = mmx_read_rm(modrm, modrm_rm(modrm, pfx));
      let d : qword = x87_ST[dst][63..0];
      var r : qword = zeros();
      foreach (i from 0 to 3) {
        r[(i * 8 + 7)..(i * 8)] = sat_s(8, d[(i * 16 + 15)..(i * 16)]);
        r[(i * 8 + 39)..(i * 8 + 32)] = sat_s(8, s[(i * 16 + 15)..(i * 16)])
      };
      x87_ST[dst] = ones(16) @ (r)
    },

    // 0F 64-66: PCMPGTB/W/D mm, mm/m64
    100 => mmx_exec_binop(PB_CmpGt,  8, pfx),
    101 => mmx_exec_binop(PB_CmpGt, 16, pfx),
    102 => mmx_exec_binop(PB_CmpGt, 32, pfx),

    // 0F 67: PACKUSWB mm, mm/m64
    103 => {
      let modrm = fetch(1);
      let dst = unsigned(modrm[5..3]);
      let s : qword = mmx_read_rm(modrm, modrm_rm(modrm, pfx));
      let d : qword = x87_ST[dst][63..0];
      var r : qword = zeros();
      foreach (i from 0 to 3) {
        r[(i * 8 + 7)..(i * 8)] = sat_su(8, d[(i * 16 + 15)..(i * 16)]);
        r[(i * 8 + 39)..(i * 8 + 32)] = sat_su(8, s[(i * 16 + 15)..(i * 16)])
      };
      x87_ST[dst] = ones(16) @ (r)
    },

    // 0F 68-6A: PUNPCKHBW/WD/DQ mm, mm/m64
    // MMX unpack high: interleave high elements from d and s
    op if 104 <= op & op <= 106 => {
      let modrm = fetch(1);
      let dst = unsigned(modrm[5..3]);
      let s : qword = mmx_read_rm(modrm, modrm_rm(modrm, pfx));
      let d : qword = x87_ST[dst][63..0];
      let eb : {8, 16, 32} = match op { 104 => 8, 105 => 16, _ => 32 };
      let n = 32 / eb;
      var r : qword = zeros();
      foreach (i from 0 to (n - 1)) {
        let src_lo = 32 + i * eb;
        let dst_lo = i * 2 * eb;
        r[(dst_lo + eb - 1)..dst_lo] = d[(src_lo + eb - 1)..src_lo];
        r[(dst_lo + 2 * eb - 1)..(dst_lo + eb)] = s[(src_lo + eb - 1)..src_lo]
      };
      x87_ST[dst] = ones(16) @ (r)
    },

    // 0F 6B: PACKSSDW mm, mm/m64
    107 => {
      let modrm = fetch(1);
      let dst = unsigned(modrm[5..3]);
      let s : qword = mmx_read_rm(modrm, modrm_rm(modrm, pfx));
      let d : qword = x87_ST[dst][63..0];
      x87_ST[dst] = ones(16) @ (sat_s(16, s[63..32]) @ sat_s(16, s[31..0]) @
                     sat_s(16, d[63..32]) @ sat_s(16, d[31..0]))
    },

    // 0F 6E: MOVD mm, r/m32 (or MOVQ mm, r/m64 with REX.W)
    110 => {
      let modrm = fetch(1);
      let dst = unsigned(modrm[5..3]);
      let src = modrm_rm(modrm, pfx);
      let os : {32, 64} = if pfx.rex_w then 64 else 32;
      x87_ST[dst] = ones(16) @ (zero_extend(v(os, src)) : qword)
    },

    // 0F 6F: MOVQ mm, mm/m64
    111 => {
      let modrm = fetch(1);
      let dst = unsigned(modrm[5..3]);
      let src = modrm_rm(modrm, pfx);
      x87_ST[dst] = ones(16) @ (mmx_read_rm(modrm, src))
    },

    // 0F 70: PSHUFW mm, mm/m64, imm8
    112 => {
      let modrm = fetch(1);
      let dst = unsigned(modrm[5..3]);
      let src = modrm_rm(modrm, pfx);
      let src : qword = mmx_read_rm(modrm, src);
      let imm = fetch(1);
      let w0 : word = (src >> (unsigned(imm[1..0]) * 16))[15..0];
      let w1 : word = (src >> (unsigned(imm[3..2]) * 16))[15..0];
      let w2 : word = (src >> (unsigned(imm[5..4]) * 16))[15..0];
      let w3 : word = (src >> (unsigned(imm[7..6]) * 16))[15..0];
      x87_ST[dst] = ones(16) @ (w3 @ w2 @ w1 @ w0)
    },

    // 0F 71-73: Group 12/13/14 — shift mm, imm8
    op if 113 <= op & op <= 115 => {
      let modrm = fetch(1);
      let dst = unsigned(modrm[2..0]);
      let c : nat = unsigned(fetch(1));
      let d : qword = x87_ST[dst][63..0];
      match (op, unsigned(modrm[5..3])) {
        (113, 2) => x87_ST[dst] = ones(16) @ (packed_uniform_shift(PS_Srl, 16, d, c)),
        (113, 4) => x87_ST[dst] = ones(16) @ (packed_uniform_shift(PS_Sra, 16, d, c)),
        (113, 6) => x87_ST[dst] = ones(16) @ (packed_uniform_shift(PS_Sll, 16, d, c)),
        (114, 2) => x87_ST[dst] = ones(16) @ (packed_uniform_shift(PS_Srl, 32, d, c)),
        (114, 4) => x87_ST[dst] = ones(16) @ (packed_uniform_shift(PS_Sra, 32, d, c)),
        (114, 6) => x87_ST[dst] = ones(16) @ (packed_uniform_shift(PS_Sll, 32, d, c)),
        (_, 2)   => x87_ST[dst] = ones(16) @ (packed_uniform_shift(PS_Srl, 64, d, c)),
        (_, 6)   => x87_ST[dst] = ones(16) @ (packed_uniform_shift(PS_Sll, 64, d, c)),
        _        => raise_UD(),
      }
    },

    // 0F 74-76: PCMPEQB/W/D mm, mm/m64
    116 => mmx_exec_binop(PB_CmpEq,  8, pfx),
    117 => mmx_exec_binop(PB_CmpEq, 16, pfx),
    118 => mmx_exec_binop(PB_CmpEq, 32, pfx),

    // 0F 7E: MOVD r/m32, mm (or MOVQ r/m64, mm with REX.W)
    126 => {
      let modrm = fetch(1);
      let src = unsigned(modrm[5..3]);
      let dest = modrm_rm(modrm, pfx);
      let x : qword = x87_ST[src][63..0];
      let os : {32, 64} = if pfx.rex_w then 64 else 32;
      v(dest) = x[os - 1 .. 0]
    },

    // 0F 7F: MOVQ mm/m64, mm
    127 => {
      let modrm = fetch(1);
      let src = unsigned(modrm[5..3]);
      let dest = modrm_rm(modrm, pfx);
      let x : qword = x87_ST[src][63..0];
      match dest {
        RM_reg(_) => x87_ST[unsigned(modrm[2..0])] = ones(16) @ (x),
        RM_mem(m) => v(m) = x,
      }
    },

    // 0F C4: PINSRW mm, r32/m16, imm8
    196 => {
      let modrm = fetch(1);
      let dst = unsigned(modrm[5..3]);
      let src = modrm_rm(modrm, pfx);
      let imm = fetch(1);
      let sel : range(0, 3) = unsigned(imm[1..0]);
      var d : qword = x87_ST[dst][63..0];
      let lo = sel * 16;
      d[(lo + 15) .. lo] = v(src);
      x87_ST[dst] = ones(16) @ (d)
    },

    // 0F C5: PEXTRW r32, mm, imm8
    197 => {
      let modrm = fetch(1);
      let dst_gpr = modrm_reg(modrm, pfx);
      let src = unsigned(modrm[2..0]);
      let imm = fetch(1);
      let sel : range(0, 3) = unsigned(imm[1..0]);
      let x : qword = x87_ST[src][63..0];
      let lo = sel * 16;
      let w : word = x[(lo + 15) .. lo];
      v(dst_gpr) = zero_extend(32, w)
    },

    // 0F D1-D3: PSRLW/D/Q mm, mm/m64
    209 => mmx_exec_shift(PS_Srl, 16, pfx),
    210 => mmx_exec_shift(PS_Srl, 32, pfx),
    211 => mmx_exec_shift(PS_Srl, 64, pfx),

    // 0F D4: PADDQ mm, mm/m64
    212 => mmx_exec_binop(PB_Add, 64, pfx),

    // 0F D5: PMULLW mm, mm/m64
    213 => mmx_exec_binop(PB_MulLow, 16, pfx),

    // 0F D7: PMOVMSKB r32, mm
    215 => {
      let modrm = fetch(1);
      let dst_gpr = modrm_reg(modrm, pfx);
      let x : qword = x87_ST[unsigned(modrm[2..0])][63..0];
      var mask : byte = zeros();
      foreach (i from 0 to 7) { mask[i] = x[i * 8 + 7] };
      v(dst_gpr) = zero_extend(32, mask)
    },

    // 0F D8-D9: PSUBUSB/W mm, mm/m64
    216 => mmx_exec_binop(PB_SatSubU,  8, pfx),
    217 => mmx_exec_binop(PB_SatSubU, 16, pfx),

    // 0F DA: PMINUB mm, mm/m64
    218 => mmx_exec_binop(PB_MinU, 8, pfx),

    // 0F DB: PAND mm, mm/m64
    219 => {
      let modrm = fetch(1);
      let dst = unsigned(modrm[5..3]);
      x87_ST[dst] = ones(16) @ (x87_ST[dst][63..0] & mmx_read_rm(modrm, modrm_rm(modrm, pfx)))
    },

    // 0F DC-DD: PADDUSB/W mm, mm/m64
    220 => mmx_exec_binop(PB_SatAddU,  8, pfx),
    221 => mmx_exec_binop(PB_SatAddU, 16, pfx),

    // 0F DE: PMAXUB mm, mm/m64
    222 => mmx_exec_binop(PB_MaxU, 8, pfx),

    // 0F DF: PANDN mm, mm/m64
    223 => {
      let modrm = fetch(1);
      let dst = unsigned(modrm[5..3]);
      x87_ST[dst] = ones(16) @ (~(x87_ST[dst][63..0]) & mmx_read_rm(modrm, modrm_rm(modrm, pfx)))
    },

    // 0F E0: PAVGB mm, mm/m64
    224 => mmx_exec_binop(PB_Avg, 8, pfx),

    // 0F E1-E2: PSRAW/D mm, mm/m64
    225 => mmx_exec_shift(PS_Sra, 16, pfx),
    226 => mmx_exec_shift(PS_Sra, 32, pfx),

    // 0F E3: PAVGW mm, mm/m64
    227 => mmx_exec_binop(PB_Avg, 16, pfx),

    // 0F E4: PMULHUW mm, mm/m64
    228 => mmx_exec_binop(PB_MulHighU, 16, pfx),

    // 0F E5: PMULHW mm, mm/m64
    229 => mmx_exec_binop(PB_MulHighS, 16, pfx),

    // 0F E7: MOVNTQ m64, mm
    231 => {
      let modrm = fetch(1);
      let src = unsigned(modrm[5..3]);
      let dest = modrm_rm(modrm, pfx);
      rm_mem(dest) = x87_ST[src][63..0]
    },

    // 0F E8-E9: PSUBSB/W mm, mm/m64
    232 => mmx_exec_binop(PB_SatSubS,  8, pfx),
    233 => mmx_exec_binop(PB_SatSubS, 16, pfx),

    // 0F EA: PMINSW mm, mm/m64
    234 => mmx_exec_binop(PB_MinS, 16, pfx),

    // 0F EB: POR mm, mm/m64
    235 => {
      let modrm = fetch(1);
      let dst = unsigned(modrm[5..3]);
      x87_ST[dst] = ones(16) @ (x87_ST[dst][63..0] | mmx_read_rm(modrm, modrm_rm(modrm, pfx)))
    },

    // 0F EC-ED: PADDSB/W mm, mm/m64
    236 => mmx_exec_binop(PB_SatAddS,  8, pfx),
    237 => mmx_exec_binop(PB_SatAddS, 16, pfx),

    // 0F EE: PMAXSW mm, mm/m64
    238 => mmx_exec_binop(PB_MaxS, 16, pfx),

    // 0F EF: PXOR mm, mm/m64
    239 => {
      let modrm = fetch(1);
      let dst = unsigned(modrm[5..3]);
      x87_ST[dst] = ones(16) @ (x87_ST[dst][63..0] ^ mmx_read_rm(modrm, modrm_rm(modrm, pfx)))
    },

    // 0F F1-F3: PSLLW/D/Q mm, mm/m64
    241 => mmx_exec_shift(PS_Sll, 16, pfx),
    242 => mmx_exec_shift(PS_Sll, 32, pfx),
    243 => mmx_exec_shift(PS_Sll, 64, pfx),

    // 0F F4: PMULUDQ mm, mm/m64
    244 => mmx_exec_binop(PB_Pmuludq, 64, pfx),

    // 0F F5: PMADDWD mm, mm/m64
    245 => mmx_exec_binop(PB_Pmaddwd, 32, pfx),

    // 0F F6: PSADBW mm, mm/m64
    246 => mmx_exec_binop(PB_Psadbw, 64, pfx),

    // 0F F7: MASKMOVQ mm, mm
    247 => {
      let modrm = fetch(1);
      let src = unsigned(modrm[5..3]);
      let mask_reg = unsigned(modrm[2..0]);
      let src2 = modrm_rm(modrm, pfx);
      match src2 {
        RM_reg(_) => {
          let data : qword = x87_ST[src][63..0];
          let mask : qword = x87_ST[mask_reg][63..0];
          let addr : qword = v(7);  // RDI
          foreach (i from 0 to 7) {
            let base = i * 8;
            if mask[base + 7] == 0b1 then {
              let b : byte = data[(base + 7) .. base];
              write_mem(addr + zero_extend(to_bits(64, i)), b)
            }
          }
        },
        RM_mem(_) => raise_UD(),
      }
    },

    // 0F F8-FB: PSUBB/W/D/Q mm, mm/m64
    248 => mmx_exec_binop(PB_Sub,  8, pfx),
    249 => mmx_exec_binop(PB_Sub, 16, pfx),
    250 => mmx_exec_binop(PB_Sub, 32, pfx),
    251 => mmx_exec_binop(PB_Sub, 64, pfx),

    // 0F FC-FE: PADDB/W/D mm, mm/m64
    252 => mmx_exec_binop(PB_Add,  8, pfx),
    253 => mmx_exec_binop(PB_Add, 16, pfx),
    254 => mmx_exec_binop(PB_Add, 32, pfx),

    _ => raise_UD(),
  };

  mmx_touch()
}

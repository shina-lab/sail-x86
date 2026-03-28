// x86-64 — VEX Integer Instructions (0F map)
//
// Integer moves, arithmetic, logical, compare, shuffle, insert/extract,
// mask register ops, VZEROUPPER/VZEROALL.

// K-register width mask: NP+W0=W(16), 66+W0=B(8), NP+W1=Q(64), 66+W1=D(32)
val kreg_width_mask : (MandatoryPrefix, bool) -> qword
function kreg_width_mask(mp, w) = match (mp, w) {
  (MP_NONE, false) => 0x000000000000FFFF,  // W: 16 bits
  (MP_66,   false) => 0x00000000000000FF,  // B: 8 bits
  (MP_NONE, true)  => 0xFFFFFFFFFFFFFFFF,  // Q: 64 bits
  (MP_66,   true)  => 0x00000000FFFFFFFF,  // D: 32 bits
  (_, _)           => 0x000000000000FFFF,  // default: W
}

val dispatch_vex_0f_int : (range(0, 255), Prefixes) -> unit
function dispatch_vex_0f_int(op, pfx) = {
  let mp = get_mandatory_prefix(pfx);

  match op {

  // 0F 41-47,4A: K-register binary ops {AND,ANDN,OR,XNOR,XOR,ADD}
  // All share same decode: k1=modrm.reg, k2=vvvv, k3=modrm.rm
  op if (65 <= op & op <= 66) | (68 <= op & op <= 71) | op == 74 => {
    let modrm = fetch(1);
    let k1 : range(0, 7) = unsigned(modrm[5..3]);
    let k2 : qword = read_kreg(pfx.vex_vvvv % 8);
    let k3 : qword = read_kreg(unsigned(modrm[2..0]));
    let mask : qword = kreg_width_mask(mp, pfx.vex_w);
    let result : qword = match op {
      65 => k2 & k3,           // KAND
      66 => ~(k2) & k3,       // KANDN
      68 => ~(k3) & mask,     // KNOT (unary: only uses k3=modrm.rm)
      69 => k2 | k3,           // KOR
      70 => ~(k2 ^ k3),       // KXNOR
      71 => k2 ^ k3,           // KXOR
      _  => k2 + k3,           // KADD (op==74)
    };
    write_kreg(k1, result & mask)
  },

  // 0F 4B: KUNPCKBW (66,W0) / KUNPCKWD (NP,W0) / KUNPCKDQ (NP,W1)
  75 => {
    let modrm = fetch(1);
    let k1 : range(0, 7) = unsigned(modrm[5..3]);
    let k2 : range(0, 7) = pfx.vex_vvvv % 8;
    let k3 : range(0, 7) = unsigned(modrm[2..0]);
    if mp == MP_66 & ~(pfx.vex_w) then {
      // KUNPCKBW: byte → word
      let result : bits(16) = read_kreg(k2)[7..0] @ read_kreg(k3)[7..0];
      write_kreg(k1, zero_extend(result))
    } else if mp == MP_NONE & ~(pfx.vex_w) then {
      // KUNPCKWD: word → dword
      let result : bits(32) = read_kreg(k2)[15..0] @ read_kreg(k3)[15..0];
      write_kreg(k1, zero_extend(result))
    } else if mp == MP_NONE & pfx.vex_w then {
      // KUNPCKDQ: dword → qword
      let result : qword = read_kreg(k2)[31..0] @ read_kreg(k3)[31..0];
      write_kreg(k1, result)
    } else {
      raise_UD()
    }
  },

  // 0F 60-62: VPUNPCKLBW/WD/DQ (66 prefix)
  96  => { if mp != MP_66 then raise_UD(); vex_exec_unpack( 8, 0, pfx) },
  97  => { if mp != MP_66 then raise_UD(); vex_exec_unpack(16, 0, pfx) },
  98  => { if mp != MP_66 then raise_UD(); vex_exec_unpack(32, 0, pfx) },
  // 0F 63: VPACKSSWB (66 prefix)
  99  => { if mp != MP_66 then raise_UD(); vex_exec_pack(PN_SatS, 16, 8, pfx) },
  // 0F 64-66: VPCMPGTB/W/D (66 prefix)
  100 => { if mp != MP_66 then raise_UD(); vex_exec_binop(PB_CmpGt,  8, pfx) },
  101 => { if mp != MP_66 then raise_UD(); vex_exec_binop(PB_CmpGt, 16, pfx) },
  102 => { if mp != MP_66 then raise_UD(); vex_exec_binop(PB_CmpGt, 32, pfx) },
  // 0F 67: VPACKUSWB (66 prefix)
  103 => { if mp != MP_66 then raise_UD(); vex_exec_pack(PN_SatSU, 16, 8, pfx) },
  // 0F 68-6A: VPUNPCKHBW/WD/DQ (66 prefix)
  104 => { if mp != MP_66 then raise_UD(); vex_exec_unpack( 8, 64, pfx) },
  105 => { if mp != MP_66 then raise_UD(); vex_exec_unpack(16, 64, pfx) },
  106 => { if mp != MP_66 then raise_UD(); vex_exec_unpack(32, 64, pfx) },
  // 0F 6B: VPACKSSDW (66 prefix)
  107 => { if mp != MP_66 then raise_UD(); vex_exec_pack(PN_SatS, 32, 16, pfx) },
  // 0F 6C-6D: VPUNPCKLQDQ/VPUNPCKHQDQ (66 prefix)
  108 => { if mp != MP_66 then raise_UD(); vex_exec_unpack(64,  0, pfx) },
  109 => { if mp != MP_66 then raise_UD(); vex_exec_unpack(64, 64, pfx) },

  // 0F 6E: VMOVD/VMOVQ gpr/mem -> xmm (66 prefix)
  // SDM: VEX.vvvv must be 1111b
  110 => {
    if mp != MP_66 | pfx.vex_l then raise_UD();
    if pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    if pfx.vex_w then {
      // VMOVQ xmm, r/m64
      let x : qword = v(src);
      write_simd(128, dst, zero_extend(x))
    } else {
      // VMOVD xmm, r/m32
      let x : dword = v(src);
      write_simd(128, dst, zero_extend(x))
    }
  },

  // 0F 6F: VMOVDQA/VMOVDQU (load)
  // SDM: VEX.vvvv must be 1111b
  111 => {
    if pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    match mp {
      // VMOVDQA xmm1/ymm1, xmm2/ymm2/m128/m256
      // Requires alignment: 32 for YMM, 16 for XMM; #GP(0) if unaligned.
      MP_66 => match src {
        RM_reg(_) =>
          if pfx.vex_l then write_simd(256, dst, read_simd(256, modrm_xmm_rm(modrm, pfx)))
          else write_simd(128, dst, read_simd(modrm_xmm_rm(modrm, pfx))),
        RM_mem(m) => {
          if pfx.vex_l then {
            let a = seg_linear(m, 32);
            if unsigned(a) % 32 != 0 then raise_GP0();
            write_simd(256, dst, read_mem(a))
          } else {
            let a = seg_linear(m, 16);
            if unsigned(a) % 16 != 0 then raise_GP0();
            write_simd(128, dst, read_mem(a))
          }
        },
      },
      // VMOVDQU xmm1/ymm1, xmm2/ymm2/m128/m256
      MP_F3 =>
        if pfx.vex_l then {
          write_simd(256, dst, decode_vex_src(256, modrm, src, pfx))
        } else {
          write_simd(128, dst, decode_vex_src(128, modrm, src, pfx))
        },
      _ => raise_UD(),
    }
  },

  // 0F 70: VPSHUFD xmm/ymm, xmm/ymm/m, imm8 (66 prefix)
  // SDM: VEX.vvvv must be 1111b. 256-bit shuffles each 128-bit lane independently.
  112 => {
    if mp != MP_66 then raise_UD();
    if pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    let vl = vex_vl(pfx);
    let s = decode_vex_src(vl, modrm, src, pfx);
    let imm = fetch(1);
    write_simd(vl, dst, packed_lane_imm_op(PLI_Pshufd, s, imm))
  },

  // 0F 71: Group 12 — VPSRLW/VPSRAW/VPSLLW imm8 (66 prefix)
  // VEX: modrm.rm = src, vvvv = dst
  113 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let reg_field : range(0, 7) = unsigned(modrm[5..3]);
    let _ = modrm_rm(modrm, pfx);
    let src_idx = modrm_xmm_rm(modrm, pfx);
    let dst = pfx.vex_vvvv;
    let c : nat = unsigned(fetch(1));
    let vl = vex_vl(pfx);
    let a = read_simd(vl, src_idx);
    match reg_field {
      2 => write_simd(vl, dst, packed_uniform_shift(PS_Srl, 16, a, c)),
      4 => write_simd(vl, dst, packed_uniform_shift(PS_Sra, 16, a, c)),
      6 => write_simd(vl, dst, packed_uniform_shift(PS_Sll, 16, a, c)),
      _ => raise_UD(),
    }
  },

  // 0F 72: Group 13 — VPSRLD/VPSRAD/VPSLLD imm8 (66 prefix)
  114 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let reg_field : range(0, 7) = unsigned(modrm[5..3]);
    let _ = modrm_rm(modrm, pfx);
    let src_idx = modrm_xmm_rm(modrm, pfx);
    let dst = pfx.vex_vvvv;
    let c : nat = unsigned(fetch(1));
    let vl = vex_vl(pfx);
    let a = read_simd(vl, src_idx);
    match reg_field {
      2 => write_simd(vl, dst, packed_uniform_shift(PS_Srl, 32, a, c)),
      4 => write_simd(vl, dst, packed_uniform_shift(PS_Sra, 32, a, c)),
      6 => write_simd(vl, dst, packed_uniform_shift(PS_Sll, 32, a, c)),
      _ => raise_UD(),
    }
  },

  // 0F 73: Group 14 — VPSRLQ/VPSRLDQ/VPSLLQ/VPSLLDQ imm8 (66 prefix)
  115 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let reg_field : range(0, 7) = unsigned(modrm[5..3]);
    let _ = modrm_rm(modrm, pfx);
    let src_idx = modrm_xmm_rm(modrm, pfx);
    let dst = pfx.vex_vvvv;
    let c : range(0, 255) = unsigned(fetch(1));
    let vl = vex_vl(pfx);
    match reg_field {
      2 => write_simd(vl, dst, packed_uniform_shift(PS_Srl, 64, read_simd(vl, src_idx), c)),
      6 => write_simd(vl, dst, packed_uniform_shift(PS_Sll, 64, read_simd(vl, src_idx), c)),
      // VPSRLDQ: byte shift right per 128-bit lane
      3 => write_simd(vl, dst, packed_uniform_shift(PS_Srl, 128, read_simd(vl, src_idx), c * 8)),
      // VPSLLDQ: byte shift left per 128-bit lane
      7 => write_simd(vl, dst, packed_uniform_shift(PS_Sll, 128, read_simd(vl, src_idx), c * 8)),
      _ => raise_UD(),
    }
  },

  // 0F 74: VPCMPEQB (66 prefix)
  116 => { if mp != MP_66 then raise_UD(); vex_exec_binop(PB_CmpEq, 8, pfx) },
  // 0F 75: VPCMPEQW (66 prefix)
  117 => { if mp != MP_66 then raise_UD(); vex_exec_binop(PB_CmpEq, 16, pfx) },
  // 0F 76: VPCMPEQD xmm/ymm (66 prefix)
  118 => { if mp != MP_66 then raise_UD(); vex_exec_binop(PB_CmpEq, 32, pfx) },

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
  124 => match mp {
    MP_F2 => vex_exec_binop(PB_HorizFAddS, 128, pfx),
    MP_66 => vex_exec_binop(PB_HorizFAddD, 128, pfx),
    _     => raise_UD(),
  },
  // 0F 7D: VHSUBPS (F2) / VHSUBPD (66)
  125 => match mp {
    MP_F2 => vex_exec_binop(PB_HorizFSubS, 128, pfx),
    MP_66 => vex_exec_binop(PB_HorizFSubD, 128, pfx),
    _     => raise_UD(),
  },

  // 0F 7E: VMOVD/VMOVQ xmm -> gpr/mem (66 prefix) / VMOVQ xmm,xmm/m64 (F3 prefix)
  // SDM: VEX.128 only, VEX.vvvv must be 1111b
  126 => {
    if pfx.vex_vvvv != 0 | pfx.vex_l then raise_UD();
    let modrm = fetch(1);
    let src2 = modrm_rm(modrm, pfx);
    match mp {
      MP_66 => {
        // VMOVD/VMOVQ xmm -> r/m
        let src : xmmword = read_simd(modrm_xmm_reg(modrm, pfx));
        match (src2, pfx.vex_w) {
          (RM_reg(r), true)  => v(r) = src[63..0],
          (RM_reg(r), false) => v(r) = src[31..0],
          (RM_mem(m), true)  => v(m) = src[63..0],
          (RM_mem(m), false) => v(m) = src[31..0],
        }
      },
      MP_F3 => {
        // VMOVQ xmm1, xmm2/m64
        let dst = modrm_xmm_reg(modrm, pfx);
        match src2 {
          RM_reg(_) => {
            let src : xmmword = read_simd(modrm_xmm_rm(modrm, pfx));
            write_simd(128, dst, zero_extend(src[63..0]))
          },
          RM_mem(m) => {
            let data : qword = v(m);
            write_simd(128, dst, zero_extend(data))
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
    let modrm = fetch(1);
    let src = modrm_xmm_reg(modrm, pfx);
    let dest = modrm_rm(modrm, pfx);
    match dest {
      RM_reg(_) => {
        let dst = modrm_xmm_rm(modrm, pfx);
        if pfx.vex_l then {
          write_simd(256, dst, read_simd(256, src))
        } else {
          write_simd(128, dst, read_simd(128, src))
        }
      },
      RM_mem(m) => {
        if mp == MP_66 then {
          let a = seg_linear(m, if pfx.vex_l then 32 else 16);
          if pfx.vex_l then {
            if unsigned(a) % 32 != 0 then raise_GP0();
          } else {
            if unsigned(a) % 16 != 0 then raise_GP0();
          }
        };
        if pfx.vex_l then {
          write_mem(m,read_simd(256, src))
        } else {
          write_mem(m, read_simd(128, src))
        }
      },
    }
  },

  // 0F 90: KMOVW k1, k/m16 (NP, W0) — load k-register from k/memory
  144 => {
    // 0F 90: KMOV{W,B,D,Q} k1, k/m — load k-register
    // NP+W0=W(16), 66+W0=B(8), NP+W1=Q(64), 66+W1=D(32)
    let modrm = fetch(1);
    let k1 : range(0, 7) = unsigned(modrm[5..3]);
    let src = modrm_rm(modrm, pfx);
    let mask : qword = kreg_width_mask(mp, pfx.vex_w);
    match src {
      RM_reg(r) => {
        let k_src : range(0, 7) = r.gpr_idx % 8;
        write_kreg(k1, read_kreg(k_src) & mask)
      },
      RM_mem(m) => {
        match (mp, pfx.vex_w) {
          (MP_NONE, true) => write_kreg(k1, v(m)),                          // KMOVQ
          (_,       true) => write_kreg(k1, zero_extend(read_mem(32, m))),  // KMOVD
          (MP_66,  false) => write_kreg(k1, zero_extend(read_mem(8, m))),   // KMOVB
          (_,      false) => write_kreg(k1, zero_extend(read_mem(16, m))),  // KMOVW
        }
      },
    }
  },

  // 0F 91: KMOV{W,B,D,Q} k/m, k1 — store k-register to memory
  145 => {
    let modrm = fetch(1);
    let k1 : range(0, 7) = unsigned(modrm[5..3]);
    let src = modrm_rm(modrm, pfx);
    match src {
      RM_mem(m) => {
        match (mp, pfx.vex_w) {
          (MP_NONE, true) => v(m) = read_kreg(k1),         // KMOVQ
          (_,       true) => v(m) = read_kreg(k1)[31..0],  // KMOVD
          (MP_66,  false) => v(m) = read_kreg(k1)[7..0],   // KMOVB
          (_,      false) => v(m) = read_kreg(k1)[15..0],  // KMOVW
        }
      },
      _ => raise_UD(),
    }
  },

  // 0F 92: KMOV{W,B} r32→k (NP/66,W0) / KMOV{D,Q} r32/r64→k (F2,W0/W1)
  146 => {
    let modrm = fetch(1);
    let k1 : range(0, 7) = unsigned(modrm[5..3]);
    let src = modrm_rm(modrm, pfx);
    match src {
      RM_reg(r) => {
        if mp == MP_F2 then {
          if pfx.vex_w then write_kreg(k1, v(64, r))                   // KMOVQ
          else write_kreg(k1, zero_extend(v(32, r)))                   // KMOVD
        } else if mp == MP_66 then {
          write_kreg(k1, zero_extend(v(32, r)[7..0]))                  // KMOVB
        } else {
          write_kreg(k1, zero_extend(v(32, r)[15..0]))                 // KMOVW
        }
      },
      _ => raise_UD(),
    }
  },

  // 0F 93: KMOV{W,B} k→r32 (NP/66,W0) / KMOV{D,Q} k→r32/r64 (F2,W0/W1)
  147 => {
    let modrm = fetch(1);
    let dst_gpr = modrm_reg(modrm, pfx);
    let k1 : range(0, 7) = unsigned(modrm[2..0]);
    if mp == MP_F2 then {
      if pfx.vex_w then v(dst_gpr) = read_kreg(k1)                       // KMOVQ
      else v(dst_gpr) = read_kreg(k1)[31..0]                             // KMOVD
    } else if mp == MP_66 then {
      v(dst_gpr) = zero_extend(32, read_kreg(k1)[7..0])                  // KMOVB
    } else {
      v(dst_gpr) = zero_extend(32, read_kreg(k1)[15..0])                 // KMOVW
    }
  },

  // 0F 98: KORTEST{W,B,D,Q} k1, k2 — ZF if k1|k2==0, CF if k1|k2==all-ones
  152 => {
    let modrm = fetch(1);
    let k1 : range(0, 7) = unsigned(modrm[5..3]);
    let k2 : range(0, 7) = unsigned(modrm[2..0]);
    let mask : qword = kreg_width_mask(mp, pfx.vex_w);
    let v1 : qword = read_kreg(k1) & mask;
    let v2 : qword = read_kreg(k2) & mask;
    let result : qword = v1 | v2;
    ZF = is_zero(result);
    CF = is_zero(result ^ mask);
    SF = 0b0;
    OF = 0b0;
    PF = 0b0;
    AF = 0b0
  },

  // 0F 99: KTEST{W,B,D,Q} k1, k2 — ZF if k1&k2==0, CF if (~k1)&k2==0
  153 => {
    let modrm = fetch(1);
    let k1 : range(0, 7) = unsigned(modrm[5..3]);
    let k2 : range(0, 7) = unsigned(modrm[2..0]);
    let mask : qword = kreg_width_mask(mp, pfx.vex_w);
    let v1 : qword = read_kreg(k1) & mask;
    let v2 : qword = read_kreg(k2) & mask;
    ZF = is_zero(v1 & v2);
    CF = is_zero(~(v1) & v2 & mask);
    SF = 0b0;
    OF = 0b0;
    PF = 0b0;
    AF = 0b0
  },

  // 0F C4: VPINSRW xmm, xmm, r32/m16, imm8 (66 prefix, VEX.128 only)
  196 => {
    if mp != MP_66 | pfx.vex_l then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    let src1 : xmmword = read_simd(pfx.vex_vvvv);
    let x : word = match src {
      RM_reg(r) => v(32, r)[15..0],
      RM_mem(m) => v(m),
    };
    let imm = fetch(1);
    let sel : range(0, 7) = unsigned(imm[2..0]);
    var result : xmmword = src1;
    result[(16 * sel + 15) .. (16 * sel)] = x;
    write_simd(128, dst, result)
  },

  // 0F C5: VPEXTRW r32, xmm, imm8 (66 prefix, VEX.128 only)
  197 => {
    if mp != MP_66 | pfx.vex_l then raise_UD();
    let modrm = fetch(1);
    let dst_gpr = modrm_reg(modrm, pfx);
    let src : xmmword = read_simd(modrm_xmm_rm(modrm, pfx));
    let imm = fetch(1);
    let sel : range(0, 7) = unsigned(imm[2..0]);
    let result : word = src[(16 * sel + 15) .. (16 * sel)];
    v(dst_gpr) = zero_extend(32, result)
  },

  // 0F D0: VADDSUBPS (F2) / VADDSUBPD (66) — alternating sub/add
  208 => match mp {
    MP_F2 => vex_exec_binop(PB_FAddSubS, 128, pfx),
    MP_66 => vex_exec_binop(PB_FAddSubD, 128, pfx),
    _     => raise_UD(),
  },

  // 0F D1: VPSRLW xmm/ymm, xmm/ymm, xmm/m128 (66 prefix) — shift by xmm count
  209 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1); let dst = modrm_xmm_reg(modrm, pfx); let src = modrm_rm(modrm, pfx);
    let c : nat = unsigned(decode_vex_src(128, modrm, src, pfx)[63..0]);
    let vl = vex_vl(pfx);
    write_simd(vl, dst, packed_uniform_shift(PS_Srl, 16, read_simd(vl, pfx.vex_vvvv), c))
  },
  // 0F D2: VPSRLD xmm/ymm, xmm/ymm, xmm/m128 (66 prefix)
  210 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1); let dst = modrm_xmm_reg(modrm, pfx); let src = modrm_rm(modrm, pfx);
    let c : nat = unsigned(decode_vex_src(128, modrm, src, pfx)[63..0]);
    let vl = vex_vl(pfx);
    write_simd(vl, dst, packed_uniform_shift(PS_Srl, 32, read_simd(vl, pfx.vex_vvvv), c))
  },
  // 0F D3: VPSRLQ xmm/ymm, xmm/ymm, xmm/m128 (66 prefix)
  211 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1); let dst = modrm_xmm_reg(modrm, pfx); let src = modrm_rm(modrm, pfx);
    let c : nat = unsigned(decode_vex_src(128, modrm, src, pfx)[63..0]);
    let vl = vex_vl(pfx);
    write_simd(vl, dst, packed_uniform_shift(PS_Srl, 64, read_simd(vl, pfx.vex_vvvv), c))
  },

  // 0F D4: VPADDQ (66 prefix)
  212 => { if mp != MP_66 then raise_UD(); vex_exec_binop(PB_Add, 64, pfx) },
  // 0F D5: VPMULLW xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  213 => { if mp != MP_66 then raise_UD(); vex_exec_binop(PB_MulLow, 16, pfx) },

  // 0F D6: VMOVQ xmm1/m64, xmm2 (66 prefix, VEX.128 only)
  // SDM: VEX.vvvv must be 1111b, VEX.L must be 0
  214 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    if pfx.vex_l then raise_UD();
    let modrm = fetch(1);
    let src_xmm = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    let x : qword = read_simd(128, src_xmm)[63..0];
    match src {
      RM_reg(_) => {
        write_simd(128, modrm_xmm_rm(modrm, pfx), zero_extend(x))
      },
      RM_mem(m) => write_mem(m,x),
    }
  },

  // 0F D7: VPMOVMSKB r32, xmm/ymm (66 prefix) — extract byte sign bits to GPR
  215 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch(1);
    let reg = modrm_reg(modrm, pfx);
    let _ = modrm_rm(modrm, pfx);
    if pfx.vex_l then {
      let src : ymmword = read_simd(modrm_xmm_rm(modrm, pfx));
      var mask : bits(32) = zeros();
      foreach (i from 0 to 31) {
        mask[i] = src[(i * 8 + 7)]
      };
      v(reg) = zero_extend(64, mask)
    } else {
      let src : xmmword = read_simd(modrm_xmm_rm(modrm, pfx));
      let mask : word = src[127] @ src[119] @ src[111] @ src[103] @
                        src[95]  @ src[87]  @ src[79]  @ src[71] @
                        src[63]  @ src[55]  @ src[47]  @ src[39] @
                        src[31]  @ src[23]  @ src[15]  @ src[7];
      v(reg) = zero_extend(32, mask)
    }
  },

  // 0F D8: VPSUBUSB (66 prefix)
  216 => { if mp != MP_66 then raise_UD(); vex_exec_binop(PB_SatSubU, 8, pfx) },
  // 0F D9: VPSUBUSW (66 prefix)
  217 => { if mp != MP_66 then raise_UD(); vex_exec_binop(PB_SatSubU, 16, pfx) },
  // 0F DA: VPMINUB (66 prefix)
  218 => { if mp != MP_66 then raise_UD(); vex_exec_binop(PB_MinU, 8, pfx) },

  // 0F DB: VPAND (66 prefix)
  219 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    if pfx.vex_l then {
      write_simd(256, dst, read_simd(256, pfx.vex_vvvv) & decode_vex_src(256, modrm, src, pfx))
    } else {
      write_simd(128, dst, read_simd(pfx.vex_vvvv) & decode_vex_src(128, modrm, src, pfx))
    }
  },

  // 0F DC: VPADDUSB (66 prefix)
  220 => { if mp != MP_66 then raise_UD(); vex_exec_binop(PB_SatAddU, 8, pfx) },
  // 0F DD: VPADDUSW (66 prefix)
  221 => { if mp != MP_66 then raise_UD(); vex_exec_binop(PB_SatAddU, 16, pfx) },
  // 0F DE: VPMAXUB (66 prefix)
  222 => { if mp != MP_66 then raise_UD(); vex_exec_binop(PB_MaxU, 8, pfx) },

  // 0F DF: VPANDN (66 prefix)
  223 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    if pfx.vex_l then {
      write_simd(256, dst, ~(read_simd(256, pfx.vex_vvvv)) & decode_vex_src(256, modrm, src, pfx))
    } else {
      write_simd(128, dst, ~(read_simd(pfx.vex_vvvv)) & decode_vex_src(128, modrm, src, pfx))
    }
  },

  // 0F E0: VPAVGB xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  224 => { if mp != MP_66 then raise_UD(); vex_exec_binop(PB_Avg, 8, pfx) },

  // 0F E1: VPSRAW xmm/ymm, xmm/ymm, xmm/m128 (66 prefix) — shift by xmm count
  225 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1); let dst = modrm_xmm_reg(modrm, pfx); let src = modrm_rm(modrm, pfx);
    let c : nat = unsigned(decode_vex_src(128, modrm, src, pfx)[63..0]);
    let vl = vex_vl(pfx);
    write_simd(vl, dst, packed_uniform_shift(PS_Sra, 16, read_simd(vl, pfx.vex_vvvv), c))
  },
  // 0F E2: VPSRAD xmm/ymm, xmm/ymm, xmm/m128 (66 prefix)
  226 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1); let dst = modrm_xmm_reg(modrm, pfx); let src = modrm_rm(modrm, pfx);
    let c : nat = unsigned(decode_vex_src(128, modrm, src, pfx)[63..0]);
    let vl = vex_vl(pfx);
    write_simd(vl, dst, packed_uniform_shift(PS_Sra, 32, read_simd(vl, pfx.vex_vvvv), c))
  },

  // 0F E3: VPAVGW xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  227 => { if mp != MP_66 then raise_UD(); vex_exec_binop(PB_Avg, 16, pfx) },
  // 0F E4: VPMULHUW xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  228 => { if mp != MP_66 then raise_UD(); vex_exec_binop(PB_MulHighU, 16, pfx) },
  // 0F E5: VPMULHW xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  229 => { if mp != MP_66 then raise_UD(); vex_exec_binop(PB_MulHighS, 16, pfx) },

  // 0F E6: VCVTDQ2PD (F3) / VCVTPD2DQ (F2) / VCVTTPD2DQ (66)
  230 => {
    if pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src2 = modrm_rm(modrm, pfx);
    match mp {
      // VCVTDQ2PD: 2/4 dword ints -> 2/4 doubles
      MP_F3 => {
        if pfx.vex_l then {
          let src : xmmword = decode_vex_src(128, modrm, src2, pfx);
          let r3 = __int32_to_f64(src[127..96]);
          let r2 = __int32_to_f64(src[95..64]);
          let r1 = __int32_to_f64(src[63..32]);
          let r0 = __int32_to_f64(src[31..0]);
          write_simd(256, dst, r3 @ r2 @ r1 @ r0)
        } else {
          let src : xmmword = decode_vex_src(128, modrm, src2, pfx);
          write_simd(128, dst, __int32_to_f64(src[63..32]) @ __int32_to_f64(src[31..0]))
        }
      },
      // VCVTPD2DQ: 2/4 doubles -> 2/4 dword ints (rounding)
      MP_F2 => {
        if pfx.vex_l then {
          let src : ymmword = decode_vex_src(256, modrm, src2, pfx);
          let r : xmmword = __f64_to_int32(src[255..192]) @ __f64_to_int32(src[191..128]) @
                            __f64_to_int32(src[127..64])  @ __f64_to_int32(src[63..0]);
          write_simd(128, dst, r)
        } else {
          let src : xmmword = decode_vex_src(128, modrm, src2, pfx);
          write_simd(128, dst, zeros(64) @ __f64_to_int32(src[127..64]) @ __f64_to_int32(src[63..0]))
        }
      },
      // VCVTTPD2DQ: 2/4 doubles -> 2/4 dword ints (truncating)
      MP_66 => {
        if pfx.vex_l then {
          let src : ymmword = decode_vex_src(256, modrm, src2, pfx);
          let r : xmmword = __f64_to_int32_trunc(src[255..192]) @ __f64_to_int32_trunc(src[191..128]) @
                            __f64_to_int32_trunc(src[127..64])  @ __f64_to_int32_trunc(src[63..0]);
          write_simd(128, dst, r)
        } else {
          let src : xmmword = decode_vex_src(128, modrm, src2, pfx);
          write_simd(128, dst, zeros(64) @ __f64_to_int32_trunc(src[127..64]) @ __f64_to_int32_trunc(src[63..0]))
        }
      },
      _ => raise_UD(),
    }
  },

  // 0F E7: VMOVNTDQ m128/m256, xmm/ymm (66 prefix) — non-temporal store
  // SDM: requires alignment (32 for YMM, 16 for XMM); #GP(0) if unaligned.
  231 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch(1);
    let src = modrm_xmm_reg(modrm, pfx);
    let dest = modrm_rm(modrm, pfx);
    match dest {
      RM_mem(m) => {
        if pfx.vex_l then {
          let a = seg_linear(m, 32);
          if unsigned(a) % 32 != 0 then raise_GP0();
          let x : ymmword = read_simd(src);
          write_mem(128, a, x[127..0]);
          write_mem(128, a + 16, x[255..128])
        } else {
          let a = seg_linear(m, 16);
          if unsigned(a) % 16 != 0 then raise_GP0();
          write_mem(a, read_simd(128, src))
        }
      },
      RM_reg(_) => raise_UD(),
    }
  },

  // 0F E8: VPSUBSB (66 prefix)
  232 => { if mp != MP_66 then raise_UD(); vex_exec_binop(PB_SatSubS, 8, pfx) },
  // 0F E9: VPSUBSW (66 prefix)
  233 => { if mp != MP_66 then raise_UD(); vex_exec_binop(PB_SatSubS, 16, pfx) },
  // 0F EA: VPMINSW (66 prefix)
  234 => { if mp != MP_66 then raise_UD(); vex_exec_binop(PB_MinS, 16, pfx) },

  // 0F EB: VPOR (66 prefix)
  235 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    if pfx.vex_l then {
      write_simd(256, dst, read_simd(256, pfx.vex_vvvv) | decode_vex_src(256, modrm, src, pfx))
    } else {
      write_simd(128, dst, read_simd(pfx.vex_vvvv) | decode_vex_src(128, modrm, src, pfx))
    }
  },

  // 0F EC: VPADDSB (66 prefix)
  236 => { if mp != MP_66 then raise_UD(); vex_exec_binop(PB_SatAddS, 8, pfx) },
  // 0F ED: VPADDSW (66 prefix)
  237 => { if mp != MP_66 then raise_UD(); vex_exec_binop(PB_SatAddS, 16, pfx) },
  // 0F EE: VPMAXSW xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  238 => { if mp != MP_66 then raise_UD(); vex_exec_binop(PB_MaxS, 16, pfx) },

  // 0F EF: VPXOR (66 prefix)
  239 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    let src1_reg = pfx.vex_vvvv;
    if pfx.vex_l then {
      let src1 : ymmword = read_simd(src1_reg);
      let src2 : ymmword = decode_vex_src(256, modrm, src, pfx);
      write_simd(256, dst, src1 ^ src2)
    } else {
      let src1 : xmmword = read_simd(src1_reg);
      let src2 : xmmword = decode_vex_src(128, modrm, src, pfx);
      write_simd(128, dst, src1 ^ src2)
    }
  },

  // 0F F0: VLDDQU xmm/ymm, m128/m256 (F2 prefix) — unaligned load
  240 => {
    if mp != MP_F2 | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    match src {
      RM_mem(m) => {
        let a = seg_linear(m, if pfx.vex_l then 32 else 16);
        if pfx.vex_l then {
          let lo : xmmword = read_mem(a);
          let hi : xmmword = read_mem(a + 16);
          write_simd(256, dst, hi @ lo)
        } else {
          write_simd(128, dst, read_mem(a))
        }
      },
      RM_reg(_) => raise_UD(),
    }
  },

  // 0F F1: VPSLLW xmm/ymm, xmm/ymm, xmm/m128 (66 prefix) — shift by xmm count
  241 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1); let dst = modrm_xmm_reg(modrm, pfx); let src = modrm_rm(modrm, pfx);
    let c : nat = unsigned(decode_vex_src(128, modrm, src, pfx)[63..0]);
    let vl = vex_vl(pfx);
    write_simd(vl, dst, packed_uniform_shift(PS_Sll, 16, read_simd(vl, pfx.vex_vvvv), c))
  },
  // 0F F2: VPSLLD xmm/ymm, xmm/ymm, xmm/m128 (66 prefix)
  242 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1); let dst = modrm_xmm_reg(modrm, pfx); let src = modrm_rm(modrm, pfx);
    let c : nat = unsigned(decode_vex_src(128, modrm, src, pfx)[63..0]);
    let vl = vex_vl(pfx);
    write_simd(vl, dst, packed_uniform_shift(PS_Sll, 32, read_simd(vl, pfx.vex_vvvv), c))
  },
  // 0F F3: VPSLLQ xmm/ymm, xmm/ymm, xmm/m128 (66 prefix)
  243 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1); let dst = modrm_xmm_reg(modrm, pfx); let src = modrm_rm(modrm, pfx);
    let c : nat = unsigned(decode_vex_src(128, modrm, src, pfx)[63..0]);
    let vl = vex_vl(pfx);
    write_simd(vl, dst, packed_uniform_shift(PS_Sll, 64, read_simd(vl, pfx.vex_vvvv), c))
  },

  // 0F F4: VPMULUDQ xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  244 => { if mp != MP_66 then raise_UD(); vex_exec_binop(PB_Pmuludq, 64, pfx) },
  // 0F F5: VPMADDWD xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  245 => { if mp != MP_66 then raise_UD(); vex_exec_binop(PB_Pmaddwd, 32, pfx) },
  // 0F F6: VPSADBW xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  246 => { if mp != MP_66 then raise_UD(); vex_exec_binop(PB_Psadbw, 64, pfx) },

  // 0F F7: VMASKMOVDQU xmm, xmm (66 prefix, vvvv must be 1111b, VEX.L=0)
  247 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 | pfx.vex_l then raise_UD();
    let modrm = fetch(1);
    let src = modrm_xmm_reg(modrm, pfx);
    let dest = modrm_rm(modrm, pfx);
    match dest {
      RM_reg(_) => {
        let data : xmmword = read_simd(src);
        let mask : xmmword = read_simd(modrm_xmm_rm(modrm, pfx));
        let addr : bits(64) = v(7); // RDI
        foreach (i from 0 to 15) {
          if mask[(i * 8 + 7)] == 0b1 then
            write_mem(8, addr + to_bits(64, i), data[(i * 8 + 7) .. (i * 8)])
        }
      },
      RM_mem(_) => raise_UD(),
    }
  },

  // 0F F8: VPSUBB (66 prefix)
  248 => { if mp != MP_66 then raise_UD(); vex_exec_binop(PB_Sub, 8, pfx) },
  // 0F F9: VPSUBW (66 prefix)
  249 => { if mp != MP_66 then raise_UD(); vex_exec_binop(PB_Sub, 16, pfx) },
  // 0F FA: VPSUBD (66 prefix)
  250 => { if mp != MP_66 then raise_UD(); vex_exec_binop(PB_Sub, 32, pfx) },
  // 0F FB: VPSUBQ (66 prefix)
  251 => { if mp != MP_66 then raise_UD(); vex_exec_binop(PB_Sub, 64, pfx) },
  // 0F FC: VPADDB (66 prefix)
  252 => { if mp != MP_66 then raise_UD(); vex_exec_binop(PB_Add, 8, pfx) },
  // 0F FD: VPADDW (66 prefix)
  253 => { if mp != MP_66 then raise_UD(); vex_exec_binop(PB_Add, 16, pfx) },
  // 0F FE: VPADDD (66 prefix)
  254 => { if mp != MP_66 then raise_UD(); vex_exec_binop(PB_Add, 32, pfx) },

  _ => raise_UD(),
  }
}

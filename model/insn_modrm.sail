// x86-64 — ModR/M and SIB Decoding
//
// Decodes the ModR/M byte, optional SIB byte, and displacement to
// produce either a register operand or an effective memory address.
//
// In 64-bit mode:
//   - mod=00, r/m=101 => [RIP + disp32]
//   - r/m=100 (with mod!=11) => SIB byte follows
//   - SIB base=101 with mod=00 => disp32 only (no base register)

// Decode SIB byte and compute effective address.
// Returns the memory address.
val decode_sib : (byte, range(0, 2), Prefixes) -> qword
function decode_sib(sib, modbits, pfx) = {
  let scale : range(0, 3) = unsigned(sib[7..6]);

  // Base and index registers (extended by REX.B / REX.X)
  let base_idx : gpr_idx = unsigned(pfx.rex_b @ sib[2..0]);
  let index_idx : gpr_idx = unsigned(pfx.rex_x @ sib[5..3]);

  // Compute base component
  let base_val : qword =
    if sib[2..0] == 0b101 & modbits == 0 then {
      // mod=00, base=101: no base register, disp32 follows
      sign_extend(fetch(4))
    } else if sib[2..0] == 0b101 & modbits == 1 then {
      // mod=01, base=101: [RBP/R13] + disp8
      v(64, base_idx) + sign_extend(fetch(1))
    } else if sib[2..0] == 0b101 & modbits == 2 then {
      // mod=10, base=101: [RBP/R13] + disp32
      v(64, base_idx) + sign_extend(fetch(4))
    } else {
      // Normal base register with displacement handled by caller
      if modbits == 0 then
        v(64, base_idx)
      else if modbits == 1 then {
        v(64, base_idx) + sign_extend(fetch(1))
      } else {
        v(64, base_idx) + sign_extend(fetch(4))
      }
    };

  // Compute index component: index=100 (RSP without REX.X) means no index
  let index_val : qword =
    if sib[5..3] == 0b100 & pfx.rex_x == 0b0 then {
      0x0000000000000000
    } else {
      let idx_reg = v(64, index_idx);
      match scale {
        0 => idx_reg,
        1 => idx_reg << 1,
        2 => idx_reg << 2,
        3 => idx_reg << 3,
      }
    };

  base_val + index_val
}

// Apply segment base to a memory address (SDM Vol.3A §3.4).
// Linear address = segment base + effective address.
// If there's an explicit segment override prefix, use that segment;
// otherwise use the default segment (DS for most, SS for BP/SP-based).
// Resolve the effective segment for a memory operand, considering
// any explicit segment override prefix and the default segment.
val resolve_seg : (Prefixes, segreg_idx) -> segreg_idx
function resolve_seg(pfx, default_seg) = match pfx.seg_override {
  Some(s) => s,
  None()  => default_seg,
}

// Legacy compatibility: apply_segment still used by moffs paths.
// Returns the linear address (segment base + effective address).
// Limit checking is NOT done here — callers must use seg_linear for that.
val apply_segment : (qword, Prefixes, segreg_idx) -> qword
function apply_segment(addr, pfx, default_seg) = {
  let seg = resolve_seg(pfx, default_seg);
  addr + get_seg_base(seg)
}

// Compute EVEX compressed displacement scale factor for "Full" tuple type.
// Without broadcast: N = vector size in bytes. With broadcast: N = element size.
val evex_full_disp_n : Prefixes -> range(4, 64)
function evex_full_disp_n(pfx) =
  if pfx.evex_b then
    (if pfx.vex_w then 8 else 4)
  else match pfx.evex_ll {
    0 => 16,
    1 => 32,
    2 => 64,
    3 => raise_UD(),
  }

// Decode SIB with EVEX compressed disp8.
val decode_sib_evex : (byte, range(0, 2), Prefixes, range(1, 64)) -> qword
function decode_sib_evex(sib, modbits, pfx, disp_n) = {
  let scale : range(0, 3) = unsigned(sib[7..6]);

  let base_idx : gpr_idx = unsigned(pfx.rex_b @ sib[2..0]);
  let index_idx : gpr_idx = unsigned(pfx.rex_x @ sib[5..3]);

  let base_val : qword =
    if sib[2..0] == 0b101 & modbits == 0 then {
      sign_extend(fetch(4))
    } else if sib[2..0] == 0b101 & modbits == 1 then {
      let d8 : byte = fetch(1);
      let scaled_disp : qword = get_slice_int(64, signed(d8) * disp_n, 0);
      v(64, base_idx) + scaled_disp
    } else if sib[2..0] == 0b101 & modbits == 2 then {
      v(64, base_idx) + sign_extend(fetch(4))
    } else {
      if modbits == 0 then
        v(64, base_idx)
      else if modbits == 1 then {
        let d8 : byte = fetch(1);
        let scaled_disp : qword = get_slice_int(64, signed(d8) * disp_n, 0);
        v(64, base_idx) + scaled_disp
      } else {
        v(64, base_idx) + sign_extend(fetch(4))
      }
    };

  let index_val : qword =
    if sib[5..3] == 0b100 & pfx.rex_x == 0b0 then {
      0x0000000000000000
    } else {
      let idx_reg = v(64, index_idx);
      match scale {
        0 => idx_reg,
        1 => idx_reg << 1,
        2 => idx_reg << 2,
        3 => idx_reg << 3,
      }
    };

  base_val + index_val
}

// Decode VSIB for gather/scatter instructions.
// Returns base address (GPR + displacement) and vector index register + scale.
// The SIB byte's index field references a vector register (extended by EVEX.V'/X).
val decode_vsib_evex : (byte, Prefixes, range(1, 64)) -> VSIB
function decode_vsib_evex(modrm, pfx, disp_n) = {
  let modbits : range(0, 3) = unsigned(modrm[7..6]);
  // VSIB always has rm=100 (SIB present), mod != 11
  let sib : byte = fetch(1);
  let scale : range(0, 3) = unsigned(sib[7..6]);

  // Base register uses EVEX.B extension (same as normal SIB)
  let base_idx : gpr_idx = unsigned(pfx.rex_b @ sib[2..0]);

  // Index is a vector register: {EVEX.V', EVEX.X, SIB.index[2:0]} = 5-bit simd_idx
  let vidx : simd_idx = unsigned(pfx.evex_rr @ pfx.rex_x @ sib[5..3]);

  let base_val : qword =
    if sib[2..0] == 0b101 & modbits == 0 then {
      sign_extend(fetch(4))
    } else if modbits == 0 then {
      v(64, base_idx)
    } else if modbits == 1 then {
      let d8 : byte = fetch(1);
      let scaled_disp : qword = get_slice_int(64, signed(d8) * disp_n, 0);
      v(64, base_idx) + scaled_disp
    } else {
      v(64, base_idx) + sign_extend(fetch(4))
    };

  struct { vsib_base = base_val, vsib_vidx = vidx, vsib_scale = scale }
}

// Decode ModR/M with EVEX compressed disp8. disp_n is the scale factor.
val modrm_rm_evex : (byte, Prefixes, range(1, 64)) -> RM
function modrm_rm_evex(modrm, pfx, disp_n) = {
  let modbits : range(0, 3) = unsigned(modrm[7..6]);
  let rm_raw : bits(3) = modrm[2..0];

  if modbits == 3 then {
    RM_reg(struct { gpr_idx = unsigned(pfx.rex_b @ rm_raw), has_rex = pfx.has_rex })
  } else if modbits == 0 & rm_raw == 0b101 then {
    let disp : qword = sign_extend(fetch(4));
    if cur_mode == LongMode then {
      // RIP-relative: [RIP + disp32] (no compression for disp32)
      rip_rel_pending = true;
      rip_rel_disp = disp;
      let ea : qword = decode_pos + disp;
      let ad_keep : qword = sign_extend(~(pfx.has_adsize));
      let ea : qword = ea & (ad_keep | 0x00000000FFFFFFFF);
      RM_mem(struct { seg = resolve_seg(pfx, DS), addr = ea })
    } else {
      // Compat/protected mode: [disp32] absolute
      let ea : qword = disp & 0x00000000FFFFFFFF;
      RM_mem(struct { seg = resolve_seg(pfx, DS), addr = ea })
    }
  } else {
    let asz = get_address_size(pfx);
    var default_seg : segreg_idx = DS;
    let addr : qword =
      if rm_raw == 0b100 then {
        let sib : byte = fetch(1);
        if (sib[2..0] == 0b100 | sib[2..0] == 0b101) & ~(sib[2..0] == 0b101 & modbits == 0) then
          default_seg = SS;
        decode_sib_evex(sib, modbits, pfx, disp_n)
      } else if modbits == 0 then {
        v(64, unsigned(pfx.rex_b @ rm_raw))
      } else {
        if rm_raw == 0b101 then default_seg = SS;
        if modbits == 1 then {
          // disp8 * N
          let d8 : byte = fetch(1);
          let scaled_disp : qword = get_slice_int(64, signed(d8) * disp_n, 0);
          v(64, unsigned(pfx.rex_b @ rm_raw)) + scaled_disp
        } else {
          // disp32 (no compression)
          v(64, unsigned(pfx.rex_b @ rm_raw)) + sign_extend(fetch(4))
        }
      };
    let addr : qword = match asz {
      16 => addr & 0x000000000000FFFF,
      32 => addr & 0x00000000FFFFFFFF,
      64 => addr,
    };
    RM_mem(struct { seg = resolve_seg(pfx, default_seg), addr = addr })
  }
}

// Decode ModR/M with 16-bit addressing (SDM Vol.2 Table 2-1).
// No SIB byte, no REX extension. Register pairs for effective address:
//   rm=0: [BX+SI], 1: [BX+DI], 2: [BP+SI], 3: [BP+DI],
//   4: [SI], 5: [DI], 6: [disp16] (mod=00) or [BP], 7: [BX]
// Default segment: BP-based → SS, others → DS.
val modrm_rm_16 : (byte, Prefixes) -> RM
function modrm_rm_16(modrm, pfx) = {
  let modbits : range(0, 3) = unsigned(modrm[7..6]);
  let rm_raw : range(0, 7) = unsigned(modrm[2..0]);

  if modbits == 3 then {
    RM_reg(struct { gpr_idx = unsigned(modrm[2..0]), has_rex = false })
  } else {
    // Compute base address from register pair
    let base : word = match rm_raw {
      0 => v(16, RBX) + v(16, RSI),
      1 => v(16, RBX) + v(16, RDI),
      2 => v(16, RBP) + v(16, RSI),
      3 => v(16, RBP) + v(16, RDI),
      4 => v(16, RSI),
      5 => v(16, RDI),
      6 => if modbits == 0 then 0x0000 else v(16, RBP),
      7 => v(16, RBX),
    };
    // Add displacement
    let ea : word = if modbits == 0 & rm_raw == 6 then {
      // mod=00, rm=110: [disp16] absolute
      fetch(2)
    } else if modbits == 0 then {
      base
    } else if modbits == 1 then {
      // + sign-extended disp8
      base + sign_extend(fetch(1))
    } else {
      // modbits == 2: + disp16
      base + fetch(2)
    };
    // Default segment: BP-based → SS, others → DS
    let default_seg : segreg_idx =
      if rm_raw == 2 | rm_raw == 3 then SS          // [BP+SI], [BP+DI]
      else if rm_raw == 6 & modbits != 0 then SS    // [BP]+disp
      else DS;
    RM_mem(struct { seg = resolve_seg(pfx, default_seg), addr = zero_extend(ea) })
  }
}

// Decode ModR/M byte and return the r/m operand (register or memory address).
// The reg field is decoded separately by the caller via modrm_reg().
// The modrm byte has already been fetched by the caller.
val modrm_rm : (byte, Prefixes) -> RM
function modrm_rm(modrm, pfx) = {
  // 16-bit addressing uses a completely different table (SDM Table 2-1)
  if get_address_size(pfx) == 16 then {
    return modrm_rm_16(modrm, pfx)
  };

  let modbits : range(0, 3) = unsigned(modrm[7..6]);
  let rm_raw : bits(3) = modrm[2..0];

  if modbits == 3 then {
    // Register direct — no segment override
    RM_reg(struct { gpr_idx = unsigned(pfx.rex_b @ rm_raw), has_rex = pfx.has_rex })
  } else if modbits == 0 & rm_raw == 0b101 then {
    let disp : qword = sign_extend(fetch(4));
    if cur_mode == LongMode then {
      // RIP-relative: [RIP + disp32]
      // With 67h prefix, uses EIP + disp32 (truncated to 32 bits).
      // If the instruction has trailing bytes (imm8/imm32),
      // fixup_addr() will adjust by the delta at use time.
      rip_rel_pending = true;
      rip_rel_disp = disp;
      let ea : qword = decode_pos + disp;
      let ad_keep : qword = sign_extend(~(pfx.has_adsize));
      let ea : qword = ea & (ad_keep | 0x00000000FFFFFFFF);
      RM_mem(struct { seg = resolve_seg(pfx, DS), addr = ea })
    } else {
      // Compat/protected mode: [disp32] absolute (no RIP-relative)
      let ea : qword = disp & 0x00000000FFFFFFFF;
      RM_mem(struct { seg = resolve_seg(pfx, DS), addr = ea })
    }
  } else {
    // Memory operand — compute address then apply segment
    let asz = get_address_size(pfx);
    // Default segment: BP/SP-based → SS, otherwise → DS (SDM Vol.1 Table 3-5)
    var default_seg : segreg_idx = DS;
    let addr : qword =
      if rm_raw == 0b100 then {
        // SIB byte follows
        let sib : byte = fetch(1);
        // SIB base = BP(5) or SP(4) → SS default
        if (sib[2..0] == 0b100 | sib[2..0] == 0b101) & ~(sib[2..0] == 0b101 & modbits == 0) then
          default_seg = SS;
        decode_sib(sib, modbits, pfx)
      } else if modbits == 0 then {
        // [reg] no displacement
        v(64, unsigned(pfx.rex_b @ rm_raw))
      } else {
        // rm_raw = 101 is EBP/RBP → SS default
        if rm_raw == 0b101 then default_seg = SS;
        if modbits == 1 then {
          // [reg] + disp8
          v(64, unsigned(pfx.rex_b @ rm_raw)) + sign_extend(fetch(1))
        } else {
          // modbits == 2: [reg] + disp32
          v(64, unsigned(pfx.rex_b @ rm_raw)) + sign_extend(fetch(4))
        }
      };
    // Truncate address based on address size
    let addr : qword = match asz {
      16 => addr & 0x000000000000FFFF,
      32 => addr & 0x00000000FFFFFFFF,
      64 => addr,
    };
    RM_mem(struct { seg = resolve_seg(pfx, default_seg), addr = addr })
  }
}

// Fetch and decode ModR/M byte, returning GPRRef reg and RM operand.
val fetch_modrm : Prefixes -> (GPRRef, RM)
function fetch_modrm(pfx) = {
  let modrm : byte = fetch(1);
  (modrm_reg(modrm, pfx), modrm_rm(modrm, pfx))
}

// Fetch and decode ModR/M byte, returning raw reg field and RM operand.
// Use for group opcodes and segment register instructions.
val fetch_modrm_raw : Prefixes -> (range(0, 7), RM)
function fetch_modrm_raw(pfx) = {
  let modrm : byte = fetch(1);
  let reg_field : range(0, 7) = unsigned(modrm[5..3]);
  (reg_field, modrm_rm(modrm, pfx))
}

// Helper: decode XMM src operand value (read from register or memory).
// Enforces 16-byte alignment for memory operands (legacy SSE default).
val decode_xmm_src : (byte, RM, Prefixes) -> xmmword
function decode_xmm_src(modrm, src, pfx) = match src {
  RM_reg(_) => read_simd(modrm_xmm_rm(modrm, pfx)),
  RM_mem(m) => { check_alignment(m, 16); read_mem(m) },
}

// Unaligned variant: no alignment check (for MOVDQU, PCMPxSTRx, etc.).
val decode_xmm_src_u : (byte, RM, Prefixes) -> xmmword
function decode_xmm_src_u(modrm, src, pfx) = match src {
  RM_reg(_) => read_simd(modrm_xmm_rm(modrm, pfx)),
  RM_mem(m) => read_mem(m),
}

// SSE FP source: scalar reads 32/64 bits, packed reads 128 bits.
// F3 (SS) → 32-bit memory read; F2 (SD) → 64-bit; NP/66 (PS/PD) → 128-bit.
// Packed path enforces 16-byte alignment; scalar paths do not.
val decode_sse_fp_src : (byte, RM, Prefixes, MandatoryPrefix) -> xmmword
function decode_sse_fp_src(modrm, src, pfx, mp) = match src {
  RM_reg(_) => read_simd(modrm_xmm_rm(modrm, pfx)),
  RM_mem(m) => match mp {
    MP_F3 => zero_extend(read_mem(32, m)),
    MP_F2 => zero_extend(read_mem(64, m)),
    _     => { check_alignment(m, 16); read_mem(m) },
  },
}

// Scalar FP source: reads low 'eb bits from XMM register or 'eb bits from memory.
val decode_scalar_src : forall 'eb, 'eb in {32, 64}. (implicit('eb), byte, RM, Prefixes) -> bits('eb)
function decode_scalar_src(eb, modrm, src, pfx) = match src {
  RM_reg(_) => read_simd(128, modrm_xmm_rm(modrm, pfx))[('eb - 1) .. 0],
  RM_mem(m) => read_mem(m),
}

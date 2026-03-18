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
  let index_raw : range(0, 7) = unsigned(sib[5..3]);
  let base_raw : range(0, 7) = unsigned(sib[2..0]);

  // Base register (extended by REX.B)
  let base_idx : gpr_idx = extend_reg(base_raw, pfx.rex_b);

  // Index register (extended by REX.X)
  let index_idx : gpr_idx = extend_reg(index_raw, pfx.rex_x);

  // Compute base component
  let base_val : qword =
    if base_raw == 5 & modbits == 0 then {
      // mod=00, base=101: no base register, disp32 follows
      let b0 = fetch_byte();
      let b1 = fetch_byte();
      let b2 = fetch_byte();
      let b3 = fetch_byte();
      sign_extend(b3 @ b2 @ b1 @ b0)
    } else if base_raw == 5 & modbits == 1 then {
      // mod=01, base=101: [RBP/R13] + disp8
      let d8 = fetch_byte();
      read_gpr64(base_idx) + sign_extend(d8)
    } else if base_raw == 5 & modbits == 2 then {
      // mod=10, base=101: [RBP/R13] + disp32
      let b0 = fetch_byte();
      let b1 = fetch_byte();
      let b2 = fetch_byte();
      let b3 = fetch_byte();
      read_gpr64(base_idx) + sign_extend(b3 @ b2 @ b1 @ b0)
    } else {
      // Normal base register with displacement handled by caller
      if modbits == 0 then
        read_gpr64(base_idx)
      else if modbits == 1 then {
        let d8 = fetch_byte();
        read_gpr64(base_idx) + sign_extend(d8)
      } else {
        let b0 = fetch_byte();
        let b1 = fetch_byte();
        let b2 = fetch_byte();
        let b3 = fetch_byte();
        read_gpr64(base_idx) + sign_extend(b3 @ b2 @ b1 @ b0)
      }
    };

  // Compute index component: index=100 (RSP without REX.X) means no index
  let index_val : qword =
    if index_raw == 4 & pfx.rex_x == bitzero then {
      0x0000000000000000
    } else {
      let idx_reg = read_gpr64(index_idx);
      match scale {
        0 => idx_reg,
        1 => idx_reg << 1,
        2 => idx_reg << 2,
        3 => idx_reg << 3,
      }
    };

  base_val + index_val
}

// Apply segment override to a memory address.
// In 64-bit mode, only FS and GS have non-zero bases.
val apply_segment : (qword, Prefixes) -> qword
function apply_segment(addr, pfx) = match pfx.seg_override {
  Some(seg) => if seg == FS then addr + FS_BASE
               else if seg == GS then addr + GS_BASE
               else addr,
  None() => addr,
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
  }

// Decode SIB with EVEX compressed disp8.
val decode_sib_evex : (byte, range(0, 2), Prefixes, range(1, 64)) -> qword
function decode_sib_evex(sib, modbits, pfx, disp_n) = {
  let scale : range(0, 3) = unsigned(sib[7..6]);
  let index_raw : range(0, 7) = unsigned(sib[5..3]);
  let base_raw : range(0, 7) = unsigned(sib[2..0]);

  let base_idx : gpr_idx = extend_reg(base_raw, pfx.rex_b);
  let index_idx : gpr_idx = extend_reg(index_raw, pfx.rex_x);

  let base_val : qword =
    if base_raw == 5 & modbits == 0 then {
      let b0 = fetch_byte();
      let b1 = fetch_byte();
      let b2 = fetch_byte();
      let b3 = fetch_byte();
      sign_extend(b3 @ b2 @ b1 @ b0)
    } else if base_raw == 5 & modbits == 1 then {
      let d8 = fetch_byte();
      let scaled_disp : qword = get_slice_int(64, signed(d8) * disp_n, 0);
      read_gpr64(base_idx) + scaled_disp
    } else if base_raw == 5 & modbits == 2 then {
      let b0 = fetch_byte();
      let b1 = fetch_byte();
      let b2 = fetch_byte();
      let b3 = fetch_byte();
      read_gpr64(base_idx) + sign_extend(b3 @ b2 @ b1 @ b0)
    } else {
      if modbits == 0 then
        read_gpr64(base_idx)
      else if modbits == 1 then {
        let d8 = fetch_byte();
        let scaled_disp : qword = get_slice_int(64, signed(d8) * disp_n, 0);
        read_gpr64(base_idx) + scaled_disp
      } else {
        let b0 = fetch_byte();
        let b1 = fetch_byte();
        let b2 = fetch_byte();
        let b3 = fetch_byte();
        read_gpr64(base_idx) + sign_extend(b3 @ b2 @ b1 @ b0)
      }
    };

  let index_val : qword =
    if index_raw == 4 & pfx.rex_x == bitzero then {
      0x0000000000000000
    } else {
      let idx_reg = read_gpr64(index_idx);
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
  let sib = fetch_byte();
  let scale : range(0, 3) = unsigned(sib[7..6]);
  let index_raw : range(0, 7) = unsigned(sib[5..3]);
  let base_raw : range(0, 7) = unsigned(sib[2..0]);

  // Base register uses EVEX.B extension (same as normal SIB)
  let base_idx : gpr_idx = extend_reg(base_raw, pfx.rex_b);

  // Index is a vector register: {EVEX.V', EVEX.X, SIB.index[2:0]} = 5-bit simd_idx
  // EVEX.V' is the inverted V' bit stored in evex byte3[3]
  // For VSIB, the index register is {V', X, index[2:0]}
  let rr_bit : bits(1) = zero_extend(pfx.evex_rr);
  let x_bit : bits(1) = zero_extend(pfx.rex_x);
  let vidx : simd_idx = unsigned(rr_bit @ x_bit @ sib[5..3]);

  let base_val : qword =
    if base_raw == 5 & modbits == 0 then {
      let b0 = fetch_byte();
      let b1 = fetch_byte();
      let b2 = fetch_byte();
      let b3 = fetch_byte();
      sign_extend(b3 @ b2 @ b1 @ b0)
    } else if modbits == 0 then {
      read_gpr64(base_idx)
    } else if modbits == 1 then {
      let d8 = fetch_byte();
      let scaled_disp : qword = get_slice_int(64, signed(d8) * disp_n, 0);
      read_gpr64(base_idx) + scaled_disp
    } else {
      let b0 = fetch_byte();
      let b1 = fetch_byte();
      let b2 = fetch_byte();
      let b3 = fetch_byte();
      read_gpr64(base_idx) + sign_extend(b3 @ b2 @ b1 @ b0)
    };

  struct { vsib_base = base_val, vsib_vidx = vidx, vsib_scale = scale }
}

// Decode ModR/M with EVEX compressed disp8. disp_n is the scale factor.
val decode_rm_evex : (byte, Prefixes, range(1, 64)) -> RM
function decode_rm_evex(modrm, pfx, disp_n) = {
  let modbits : range(0, 3) = unsigned(modrm[7..6]);
  let rm_raw : range(0, 7) = unsigned(modrm[2..0]);

  if modbits == 3 then {
    RM_reg(extend_reg(rm_raw, pfx.rex_b))
  } else if modbits == 0 & rm_raw == 5 then {
    // RIP-relative: [RIP + disp32] (no compression for disp32)
    let b0 = fetch_byte();
    let b1 = fetch_byte();
    let b2 = fetch_byte();
    let b3 = fetch_byte();
    let disp : qword = sign_extend(b3 @ b2 @ b1 @ b0);
    rip_rel_pending = true;
    rip_rel_disp = disp;
    let ea : qword = decode_pos + disp;
    let ad_keep : qword = zeros() - zero_extend(~(pfx.has_adsize));
    let ea : qword = ea & (ad_keep | 0x00000000FFFFFFFF);
    RM_mem(apply_segment(ea, pfx))
  } else {
    let addr : qword =
      if rm_raw == 4 then {
        let sib = fetch_byte();
        decode_sib_evex(sib, modbits, pfx, disp_n)
      } else if modbits == 0 then {
        read_gpr64(extend_reg(rm_raw, pfx.rex_b))
      } else if modbits == 1 then {
        // disp8 * N
        let d8 = fetch_byte();
        let scaled_disp : qword = get_slice_int(64, signed(d8) * disp_n, 0);
        read_gpr64(extend_reg(rm_raw, pfx.rex_b)) + scaled_disp
      } else {
        // disp32 (no compression)
        let b0 = fetch_byte();
        let b1 = fetch_byte();
        let b2 = fetch_byte();
        let b3 = fetch_byte();
        read_gpr64(extend_reg(rm_raw, pfx.rex_b)) + sign_extend(b3 @ b2 @ b1 @ b0)
      };
    let ad_keep : qword = zeros() - zero_extend(~(pfx.has_adsize));
    let addr : qword = addr & (ad_keep | 0x00000000FFFFFFFF);
    RM_mem(apply_segment(addr, pfx))
  }
}

// Decode ModR/M byte and return the r/m operand (register or memory address).
// The reg field is decoded separately by the caller via modrm_reg().
// The modrm byte has already been fetched by the caller.
val decode_rm : (byte, Prefixes) -> RM
function decode_rm(modrm, pfx) = {
  let modbits : range(0, 3) = unsigned(modrm[7..6]);
  let rm_raw : range(0, 7) = unsigned(modrm[2..0]);

  if modbits == 3 then {
    // Register direct — no segment override
    RM_reg(extend_reg(rm_raw, pfx.rex_b))
  } else if modbits == 0 & rm_raw == 5 then {
    // RIP-relative: [RIP + disp32]
    // With 67h prefix in 64-bit mode, uses EIP + disp32 (truncated to 32 bits).
    // Compute preliminary address using current decode_pos.
    // If the instruction has trailing bytes (imm8/imm32),
    // fixup_addr() will adjust by the delta at use time.
    let b0 = fetch_byte();
    let b1 = fetch_byte();
    let b2 = fetch_byte();
    let b3 = fetch_byte();
    let disp : qword = sign_extend(b3 @ b2 @ b1 @ b0);
    rip_rel_pending = true;
    rip_rel_disp = disp;
    let ea : qword = decode_pos + disp;
    // 67h prefix: truncate effective address to 32 bits, zero-extended
    let ad_keep : qword = zeros() - zero_extend(~(pfx.has_adsize));
    let ea : qword = ea & (ad_keep | 0x00000000FFFFFFFF);
    RM_mem(apply_segment(ea, pfx))
  } else {
    // Memory operand — compute address then apply segment override
    let addr : qword =
      if rm_raw == 4 then {
        // SIB byte follows
        let sib = fetch_byte();
        decode_sib(sib, modbits, pfx)
      } else if modbits == 0 then {
        // [reg] no displacement
        read_gpr64(extend_reg(rm_raw, pfx.rex_b))
      } else if modbits == 1 then {
        // [reg] + disp8
        let d8 = fetch_byte();
        read_gpr64(extend_reg(rm_raw, pfx.rex_b)) + sign_extend(d8)
      } else {
        // modbits == 2: [reg] + disp32
        let b0 = fetch_byte();
        let b1 = fetch_byte();
        let b2 = fetch_byte();
        let b3 = fetch_byte();
        read_gpr64(extend_reg(rm_raw, pfx.rex_b)) + sign_extend(b3 @ b2 @ b1 @ b0)
      };
    // 67h prefix: truncate effective address to 32 bits, zero-extended
    let ad_keep : qword = zeros() - zero_extend(~(pfx.has_adsize));
    let addr : qword = addr & (ad_keep | 0x00000000FFFFFFFF);
    RM_mem(apply_segment(addr, pfx))
  }
}

// Helper: decode XMM src operand value (read from register or memory).
val decode_xmm_src : (byte, RM, Prefixes) -> xmmword
function decode_xmm_src(modrm, rm, pfx) = match rm {
  RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
  RM_mem(addr) => mem_read128(addr),
}

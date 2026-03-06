// x86-64 Decoder — ModR/M and SIB Decoding
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
    if index_raw == 4 & not_bool(pfx.rex_x) then
      0x0000000000000000
    else {
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
    RM_mem(apply_segment(decode_pos + disp, pfx))
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
    RM_mem(apply_segment(addr, pfx))
  }
}

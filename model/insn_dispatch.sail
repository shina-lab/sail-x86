// x86-64 — Opcode Dispatch
//
// Central dispatch for 1-byte, 2-byte (0F xx), and 3-byte (0F 38/3A xx)
// opcode maps. Routes to category-specific handlers.

val __software_interrupt : byte -> unit

// XCHG — Exchange Register/Memory with Register

val exec_xchg_reg_reg : (gpr_idx, gpr_idx, OperandSize) -> unit
function exec_xchg_reg_reg(a, b, os) = {
  let va : qword = read_gpr(a, os);
  let vb : qword = read_gpr(b, os);
  write_gpr(a, os, vb);
  write_gpr(b, os, va)
}

// IN — Input from Port

val __port_in8  : word -> byte
val __port_in16 : word -> word
val __port_in32 : word -> dword

val exec_in : (word, OperandSize) -> unit
function exec_in(port, os) = {
  match os {
    OS8  => write_gpr8l(RAX, __port_in8(port)),
    OS16 => write_gpr16(RAX, __port_in16(port)),
    OS32 => write_gpr32(RAX, __port_in32(port)),
    OS64 => (),
  }
}

// OUT — Output to Port

val __port_out8  : (word, byte)  -> unit
val __port_out16 : (word, word) -> unit
val __port_out32 : (word, dword) -> unit

val exec_out : (word, OperandSize) -> unit
function exec_out(port, os) = {
  match os {
    OS8  => __port_out8(port, read_gpr8l(RAX)),
    OS16 => __port_out16(port, read_gpr16(RAX)),
    OS32 => __port_out32(port, read_gpr32(RAX)),
    OS64 => (),
  }
}

// JMP near relative: RIP := decode_pos + sign-extended offset

// POP — Pop a Value from the Stack

val exec_pop_reg : (gpr_idx, OperandSize) -> unit
function exec_pop_reg(dst, os) = {
  match os {
    OS8 => (),
    OS16 => write_gpr16(dst, pop16()),
    OS32 => if cur_mode == LongMode then write_gpr32(dst, pop64()[31..0])
            else write_gpr32(dst, pop32()),
    OS64 => write_gpr64(dst, pop64()),
  }
}

// LOOP/LOOPcc — Loop According to ECX Counter

enum LoopVariant = { LOOP_always, LOOP_e, LOOP_ne }

val exec_loop : (byte, LoopVariant, AddressSize) -> unit
function exec_loop(rel8, variant, asz) = {
  match asz {
    AS64 => write_gpr64(RCX, read_gpr64(RCX) - 1),
    AS32 => write_gpr32(RCX, read_gpr32(RCX) - 1),
    AS16 => write_gpr16(RCX, read_gpr16(RCX) - 1),
  };
  let count_nonzero : bool = match asz {
    AS64 => read_gpr64(RCX) != zeros(),
    AS32 => read_gpr32(RCX) != zeros(),
    AS16 => read_gpr16(RCX) != zeros(),
  };
  let take_branch : bool = match variant {
    LOOP_always => count_nonzero,
    LOOP_e      => if count_nonzero then ZF == bitone else false,
    LOOP_ne     => if count_nonzero then ZF == bitzero else false,
  };
  if take_branch then {
    let os = if cur_mode == LongMode then OS64
             else if get_cs_db() == bitone then OS32
             else OS16;
    next_rip = Some(truncate_rip(decode_pos + sign_extend(rel8), os));
  }
}

// Map rows 00-3F to ALU operation. Each operation occupies 8 opcodes.
val opcode_to_alu : range(0, 63) -> ALUOp
function opcode_to_alu(op) = {
  let row : range(0, 7) = unsigned(to_bits_truncate(3, op / 8));
  match row {
    0 => ALU_ADD,
    1 => ALU_OR,
    2 => ALU_ADC,
    3 => ALU_SBB,
    4 => ALU_AND,
    5 => ALU_SUB,
    6 => ALU_XOR,
    7 => ALU_CMP,
  }
}


// ALU dispatch for opcodes 00-3F (columns 0-5).
val dispatch_alu_opcode : (range(0, 63), Prefixes) -> unit
function dispatch_alu_opcode(op, pfx) = {
  let alu_op = opcode_to_alu(op);
  let col : range(0, 7) = op % 8;
  // LOCK is only valid on columns 0-1 (r/m destination), not CMP, and only with memory
  if pfx.has_lock & col >= 2 then raise_UD();
  match col {
    // OP r/m8, r8
    0 => {
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      check_lock_rm(pfx, rm, alu_op == ALU_CMP);
      exec_alu_rm_reg_byte(alu_op, rm, reg, pfx)
    },
    // OP r/m, r (word/dword/qword)
    1 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      check_lock_rm(pfx, rm, alu_op == ALU_CMP);
      exec_alu_rm_reg(alu_op, rm, reg, os, pfx)
    },
    // OP r8, r/m8
    2 => {
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      exec_alu_reg_rm_byte(alu_op, reg, rm, pfx)
    },
    // OP r, r/m (word/dword/qword)
    3 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      exec_alu_reg_rm(alu_op, reg, rm, os, pfx)
    },
    // OP AL, imm8
    4 => {
      let imm : qword = zero_extend(fetch_byte());
      exec_alu_acc_imm(alu_op, imm, OS8, pfx)
    },
    // OP rAX, imm (Iz: 16 or 32 bit, sign-extended)
    5 => {
      let os = get_operand_size(pfx);
      let imm = fetch_imm_z(os);
      exec_alu_acc_imm(alu_op, imm, os, pfx)
    },
    _ => raise_UD(),  // unreachable
  }
}

// =========================================================================
// String Operations (MOVS, STOS, LODS, SCAS, CMPS, INS, OUTS, REP)
// =========================================================================

// INS — Input from port DX to ES:[RDI]
val exec_ins : (OperandSize, AddressSize) -> unit
function exec_ins(os, asz) = {
  let port : word = read_gpr16(RDX);
  let off : qword = read_index_dst(asz);
  // INS destination is always ES:DI (not overridable).
  let sz = operand_size_bits(os) / 8;
  let lin = seg_linear(ES, off, sz);
  match os {
    OS8  => mem_write8(lin, __port_in8(port)),
    OS16 => mem_write16(lin, __port_in16(port)),
    OS32 => mem_write32(lin, __port_in32(port)),
    OS64 => (),
  };
  let delta : qword = match os {
    OS8  => 0x0000000000000001,
    OS16 => 0x0000000000000002,
    OS32 => 0x0000000000000004,
    OS64 => 0x0000000000000008,
  };
  if DF == bitzero then
    write_index_dst(asz, off + delta)
  else
    write_index_dst(asz, off - delta)
}

// OUTS — Output from DS:[RSI] to port DX
// SDM Vol.2B §OUTS: Source is DS:(E)SI, DS segment may be overridden.
val exec_outs : (OperandSize, AddressSize, Prefixes) -> unit
function exec_outs(os, asz, pfx) = {
  let port : word = read_gpr16(RDX);
  let off : qword = read_index_src(asz);
  let src_seg : segreg_idx = match pfx.seg_override {
    Some(s) => s,
    None()  => DS,
  };
  let sz = operand_size_bits(os) / 8;
  let lin = seg_linear(src_seg, off, sz);
  match os {
    OS8  => __port_out8(port, mem_read8(lin)),
    OS16 => __port_out16(port, mem_read16(lin)),
    OS32 => __port_out32(port, mem_read32(lin)),
    OS64 => (),
  };
  let delta : qword = match os {
    OS8  => 0x0000000000000001,
    OS16 => 0x0000000000000002,
    OS32 => 0x0000000000000004,
    OS64 => 0x0000000000000008,
  };
  if DF == bitzero then
    write_index_src(asz, off + delta)
  else
    write_index_src(asz, off - delta)
}

val exec_movs : (OperandSize, AddressSize, Prefixes) -> unit
function exec_movs(os, asz, pfx) = {
  let src_off : qword = read_index_src(asz);
  let dst_off : qword = read_index_dst(asz);
  // MOVS source is DS:SI (overridable), destination is always ES:DI.
  let src_seg : segreg_idx = match pfx.seg_override {
    Some(s) => s,
    None()  => DS,
  };
  let sz = operand_size_bits(os) / 8;
  let src_lin = seg_linear(src_seg, src_off, sz);
  let dst_lin = seg_linear(ES, dst_off, sz);
  match os {
    OS8  => mem_write8(dst_lin, mem_read8(src_lin)),
    OS16 => mem_write16(dst_lin, mem_read16(src_lin)),
    OS32 => mem_write32(dst_lin, mem_read32(src_lin)),
    OS64 => mem_write64(dst_lin, mem_read64(src_lin)),
  };
  let delta : qword = match os {
    OS8  => 0x0000000000000001,
    OS16 => 0x0000000000000002,
    OS32 => 0x0000000000000004,
    OS64 => 0x0000000000000008,
  };
  if DF == bitzero then {
    write_index_src(asz, src_off + delta);
    write_index_dst(asz, dst_off + delta);
  } else {
    write_index_src(asz, src_off - delta);
    write_index_dst(asz, dst_off - delta);
  }
}

val exec_stos : (OperandSize, AddressSize) -> unit
function exec_stos(os, asz) = {
  let off : qword = read_index_dst(asz);
  // STOS destination is always ES:DI (not overridable).
  let sz = operand_size_bits(os) / 8;
  let lin = seg_linear(ES, off, sz);
  match os {
    OS8  => mem_write8(lin, read_gpr8l(RAX)),
    OS16 => mem_write16(lin, read_gpr16(RAX)),
    OS32 => mem_write32(lin, read_gpr32(RAX)),
    OS64 => mem_write64(lin, read_gpr64(RAX)),
  };
  let delta : qword = match os {
    OS8  => 0x0000000000000001,
    OS16 => 0x0000000000000002,
    OS32 => 0x0000000000000004,
    OS64 => 0x0000000000000008,
  };
  if DF == bitzero then
    write_index_dst(asz, off + delta)
  else
    write_index_dst(asz, off - delta)
}

val exec_lods : (OperandSize, AddressSize, Prefixes) -> unit
function exec_lods(os, asz, pfx) = {
  let off : qword = read_index_src(asz);
  // LODS source is DS:SI (overridable).
  let src_seg : segreg_idx = match pfx.seg_override {
    Some(s) => s,
    None()  => DS,
  };
  let sz = operand_size_bits(os) / 8;
  let lin = seg_linear(src_seg, off, sz);
  match os {
    OS8  => write_gpr8l(RAX, mem_read8(lin)),
    OS16 => write_gpr16(RAX, mem_read16(lin)),
    OS32 => write_gpr32(RAX, mem_read32(lin)),
    OS64 => write_gpr64(RAX, mem_read64(lin)),
  };
  let delta : qword = match os {
    OS8  => 0x0000000000000001,
    OS16 => 0x0000000000000002,
    OS32 => 0x0000000000000004,
    OS64 => 0x0000000000000008,
  };
  if DF == bitzero then
    write_index_src(asz, off + delta)
  else
    write_index_src(asz, off - delta)
}

val exec_scas : (OperandSize, AddressSize) -> unit
function exec_scas(os, asz) = {
  let off : qword = read_index_dst(asz);
  // SCAS destination is always ES:DI (not overridable).
  let sz = operand_size_bits(os) / 8;
  let lin = seg_linear(ES, off, sz);
  match os {
    OS8 => {
      let a : byte = read_gpr8l(RAX);
      let b : byte = mem_read8(lin);
      update_flags_sub(a - b, a, b);
    },
    OS16 => {
      let a : word = read_gpr16(RAX);
      let b : word = mem_read16(lin);
      update_flags_sub(a - b, a, b);
    },
    OS32 => {
      let a : dword = read_gpr32(RAX);
      let b : dword = mem_read32(lin);
      update_flags_sub(a - b, a, b);
    },
    OS64 => {
      let a : qword = read_gpr64(RAX);
      let b : qword = mem_read64(lin);
      update_flags_sub(a - b, a, b);
    },
  };
  let delta : qword = match os {
    OS8  => 0x0000000000000001,
    OS16 => 0x0000000000000002,
    OS32 => 0x0000000000000004,
    OS64 => 0x0000000000000008,
  };
  if DF == bitzero then
    write_index_dst(asz, off + delta)
  else
    write_index_dst(asz, off - delta)
}

val exec_cmps : (OperandSize, AddressSize, Prefixes) -> unit
function exec_cmps(os, asz, pfx) = {
  let src_off : qword = read_index_src(asz);
  let dst_off : qword = read_index_dst(asz);
  // CMPS source is DS:SI (overridable), destination is ES:DI.
  let src_seg : segreg_idx = match pfx.seg_override {
    Some(s) => s,
    None()  => DS,
  };
  let sz = operand_size_bits(os) / 8;
  let src_lin = seg_linear(src_seg, src_off, sz);
  let dst_lin = seg_linear(ES, dst_off, sz);
  match os {
    OS8 => {
      let a : byte = mem_read8(src_lin);
      let b : byte = mem_read8(dst_lin);
      update_flags_sub(a - b, a, b);
    },
    OS16 => {
      let a : word = mem_read16(src_lin);
      let b : word = mem_read16(dst_lin);
      update_flags_sub(a - b, a, b);
    },
    OS32 => {
      let a : dword = mem_read32(src_lin);
      let b : dword = mem_read32(dst_lin);
      update_flags_sub(a - b, a, b);
    },
    OS64 => {
      let a : qword = mem_read64(src_lin);
      let b : qword = mem_read64(dst_lin);
      update_flags_sub(a - b, a, b);
    },
  };
  let delta : qword = match os {
    OS8  => 0x0000000000000001,
    OS16 => 0x0000000000000002,
    OS32 => 0x0000000000000004,
    OS64 => 0x0000000000000008,
  };
  if DF == bitzero then {
    write_index_src(asz, src_off + delta);
    write_index_dst(asz, dst_off + delta);
  } else {
    write_index_src(asz, src_off - delta);
    write_index_dst(asz, dst_off - delta);
  }
}

enum RepPrefix = { REP_none, REP_rep, REP_repe, REP_repne }

enum StringOp = { STR_movs, STR_stos, STR_lods, STR_cmps, STR_scas, STR_ins, STR_outs }

val exec_rep : (RepPrefix, StringOp, OperandSize, AddressSize, Prefixes) -> unit
function exec_rep(prefix, op, os, asz, pfx) = {
  var done : bool = false;
  while ~(done) do {
    if read_count_reg(asz) == zeros() then {
      done = true
    } else {
      match op {
        STR_movs => exec_movs(os, asz, pfx),
        STR_stos => exec_stos(os, asz),
        STR_lods => exec_lods(os, asz, pfx),
        STR_cmps => exec_cmps(os, asz, pfx),
        STR_scas => exec_scas(os, asz),
        STR_ins  => exec_ins(os, asz),
        STR_outs => exec_outs(os, asz, pfx),
      };
      let cnt = read_count_reg(asz);
      write_count_reg(asz, cnt - 1);
      if read_count_reg(asz) == zeros() then
        done = true
      else match prefix {
        REP_repe  => if ZF == bitzero then done = true,
        REP_repne => if ZF == bitone then done = true,
        _         => (),
      };
    };
  }
}

// =========================================================================
// 2-Byte Opcode Map (0F xx) Dispatch
// =========================================================================

// Check if a 2-byte opcode (0F xx) is lockable.
// Lockable: BTS (0F AB), BTR (0F B3), BTC (0F BB),
// CMPXCHG (0F B0, 0F B1), XADD (0F C0, 0F C1), CMPXCHG8B/16B (0F C7)
val is_lockable_2byte : range(0, 255) -> bool
function is_lockable_2byte(op) = match op {
  171 => true,  // 0F AB: BTS
  176 => true, 177 => true,  // 0F B0-B1: CMPXCHG
  179 => true,  // 0F B3: BTR
  186 => true,  // 0F BA: Group 8 (BTS/BTR/BTC imm, not BT)
  187 => true,  // 0F BB: BTC
  192 => true, 193 => true,  // 0F C0-C1: XADD
  199 => true,  // 0F C7: CMPXCHG8B/16B
  _ => false,
}

val dispatch_opcode_2byte : (byte, Prefixes) -> unit
function dispatch_opcode_2byte(opcode, pfx) = {
  let op : range(0, 255) = unsigned(opcode);
  // LOCK prefix is only valid on specific 2-byte opcodes; #UD otherwise.
  if pfx.has_lock & ~(is_lockable_2byte(op)) then raise_UD();
  match op {
    // 0F 38: 3-byte escape (SSSE3/SSE4/AES-NI)
    56 => {
      let opcode3 = fetch_byte();
      let op3 : range(0, 255) = unsigned(opcode3);
      if op3 == 246 then {
        // ADCX (66) / ADOX (F3)
        // The 66/F3 prefix is a mandatory prefix, NOT an operand size override.
        // Operand size is determined by REX.W only: W=1 → 64-bit, else 32-bit.
        if ~(has_adx) then raise_UD();
        let mp = get_mandatory_prefix(pfx);
        let os : OperandSize = if pfx.rex_w then OS64 else OS32;
        let modrm = fetch_byte();
        let reg = modrm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_val = read_rm_val(rm, os, pfx.has_rex);
        if mp == MP_66 then {
          let a : qword = read_gpr(reg, os);
          let result : qword = a + src_val + zero_extend(CF);
          match os {
            OS32 => { let w : bits(33) = (0b0 @ a[31..0]) + (0b0 @ src_val[31..0]) + zero_extend(CF); CF = w[32] },
            OS64 => { let w : bits(65) = (0b0 @ a) + (0b0 @ src_val) + zero_extend(CF); CF = w[64] },
            _ => (),
          };
          write_gpr(reg, os, result)
        } else if mp == MP_F3 then {
          let a : qword = read_gpr(reg, os);
          let result : qword = a + src_val + zero_extend(OF);
          match os {
            OS32 => { let w : bits(33) = (0b0 @ a[31..0]) + (0b0 @ src_val[31..0]) + zero_extend(OF); OF = w[32] },
            OS64 => { let w : bits(65) = (0b0 @ a) + (0b0 @ src_val) + zero_extend(OF); OF = w[64] },
            _ => (),
          };
          write_gpr(reg, os, result)
        } else {
          raise_UD()
        }
      } else if op3 == 20 | op3 == 21 then {
        // BLENDVPS or BLENDVPD (SSE4.1)
        if sse_em_blocked() then raise_UD();
        if ~(has_sse4_1) then raise_UD();
        dispatch_3byte_38_sse_fp(opcode3, pfx)
      } else if op3 == 130 then {
        // 66 0F 38 82: INVPCID r64, m128 — Invalidate TLB by PCID
        if cur_cpl != 0 then raise_GP0();
        let modrm = fetch_byte();
        let rm = decode_rm(modrm, pfx);
        match rm {
          RM_mem(seg, offset) => {
            let inv_type : qword = read_gpr64(modrm_reg(modrm, pfx));
            if unsigned(inv_type) > 3 then raise_GP0();
            let desc : xmmword = seg_read128(seg, offset);
            let reserved : bits(52) = desc[63..12];
            let top17 : bits(17) = desc[127..111];
            // types 0,1: reserved bits must be zero
            // type 0: linear address must be canonical
            let is_type_01 : bit = ~(inv_type[1]);
            let is_type_0 : bit = ~(inv_type[1] | inv_type[0]);
            let bad_reserved : bit = ~(((0b0 @ reserved) - 1)[52]);
            let diff : bits(17) = top17 ^ sign_extend(top17[16..16]);
            let non_canonical : bit = ~(((0b0 @ diff) - 1)[17]);
            let fault : bit = (is_type_01 & bad_reserved) | (is_type_0 & non_canonical);
            if fault == bitone then raise_GP0();
            __tlb_flush()
          },
          RM_reg(_) => raise_UD(),
        }
      } else if (op3 == 240 | op3 == 241) then {
        // MOVBE (0F 38 F0/F1) or CRC32 (F2 0F 38 F0/F1)
        let mp = get_mandatory_prefix(pfx);
        if mp == MP_F2 then {
          if ~(has_crc32) then raise_UD();
          let modrm = fetch_byte();
          let reg = modrm_reg(modrm, pfx);
          let rm = decode_rm(modrm, pfx);
          let crc : bits(32) = read_gpr(reg, OS32)[31..0];
          if op3 == 240 then {
            // CRC32 r32/r64, r/m8
            let src : byte = match rm {
              RM_reg(_) => read_rm_val(rm, OS8, pfx.has_rex)[7..0],
              RM_mem(seg, offset) => seg_read8(seg, offset),
            };
            let result : bits(32) = crc32c_byte(crc, src);
            write_gpr(reg, if pfx.rex_w then OS64 else OS32, zero_extend(result))
          } else {
            // CRC32 r32/r64, r/m16/r/m32/r/m64
            let os = get_operand_size(pfx);
            let result : bits(32) = match os {
              OS16 => {
                let src : bits(16) = match rm {
                  RM_reg(_) => read_rm_val(rm, OS16, pfx.has_rex)[15..0],
                  RM_mem(seg, offset) => seg_read16(seg, offset),
                };
                crc32c_16(crc, src)
              },
              OS64 => {
                let src : bits(64) = match rm {
                  RM_reg(_) => read_rm_val(rm, OS64, pfx.has_rex),
                  RM_mem(seg, offset) => seg_read64(seg, offset),
                };
                crc32c_64(crc, src)
              },
              _ => {
                let src : bits(32) = match rm {
                  RM_reg(_) => read_rm_val(rm, OS32, pfx.has_rex)[31..0],
                  RM_mem(seg, offset) => seg_read32(seg, offset),
                };
                crc32c_32(crc, src)
              },
            };
            write_gpr(reg, if pfx.rex_w then OS64 else OS32, zero_extend(result))
          }
        } else {
          // MOVBE (0F 38 F0/F1) — load/store with byte swap
          if ~(has_movbe) then raise_UD();
          let os = get_operand_size(pfx);
          let modrm = fetch_byte();
          let reg = modrm_reg(modrm, pfx);
          let rm = decode_rm(modrm, pfx);
          if op3 == 240 then {
            // MOVBE r, m — load from memory and byte-swap
            match rm {
              RM_mem(seg, offset) => {
                match os {
                  OS8 => (),
                  OS16 => {
                    let v = seg_read16(seg, offset);
                    write_gpr(reg, OS16, zero_extend(v[7..0] @ v[15..8]))
                  },
                  OS32 => {
                    let v = seg_read32(seg, offset);
                    write_gpr(reg, OS32, zero_extend(v[7..0] @ v[15..8] @ v[23..16] @ v[31..24]))
                  },
                  OS64 => {
                    let v = seg_read64(seg, offset);
                    write_gpr(reg, OS64, v[7..0] @ v[15..8] @ v[23..16] @ v[31..24] @
                                         v[39..32] @ v[47..40] @ v[55..48] @ v[63..56])
                  },
                }
              },
              RM_reg(_) => raise_UD(),
            }
          } else {
            // MOVBE m, r — byte-swap register and store to memory
            match rm {
              RM_mem(seg, offset) => {
                match os {
                  OS8 => (),
                  OS16 => {
                    let v : word = read_gpr(reg, OS16)[15..0];
                    seg_write16(seg, offset, v[7..0] @ v[15..8])
                  },
                  OS32 => {
                    let v : dword = read_gpr(reg, OS32)[31..0];
                    seg_write32(seg, offset, v[7..0] @ v[15..8] @ v[23..16] @ v[31..24])
                  },
                  OS64 => {
                    let v : qword = read_gpr(reg, OS64);
                    seg_write64(seg, offset, v[7..0] @ v[15..8] @ v[23..16] @ v[31..24] @
                                      v[39..32] @ v[47..40] @ v[55..48] @ v[63..56])
                  },
                }
              },
              RM_reg(_) => raise_UD(),
            }
          }
        }
      } else if op3 == 249 & get_mandatory_prefix(pfx) == MP_NONE then {
        // MOVDIRI m32/m64, r32/r64 (NP 0F 38 F9)
        if ~(has_movdiri) then raise_UD();
        let os = if pfx.rex_w then OS64 else OS32;
        let modrm = fetch_byte();
        let reg = modrm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        match rm {
          RM_mem(seg, offset) => {
            let v = read_gpr(reg, os);
            match os {
              OS32 => seg_write32(seg, offset, v[31..0]),
              _    => seg_write64(seg, offset, v),
            }
          },
          RM_reg(_) => raise_UD(),
        }
      } else if op3 == 248 & get_mandatory_prefix(pfx) == MP_66 then {
        // MOVDIR64B r, m512 (66 0F 38 F8)
        if ~(has_movdir64b) then raise_UD();
        let modrm = fetch_byte();
        let rm = decode_rm(modrm, pfx);
        match rm {
          RM_mem(seg, offset) => {
            // Source: 64 bytes from ModRM:r/m memory address
            let src : zmmword = seg_read512(seg, offset);
            // Destination: address from ModRM:reg (ES-relative, no override)
            let asz = get_address_size(pfx);
            let reg = modrm_reg(modrm, pfx);
            let dst_addr : qword = match asz {
              AS32 => zero_extend(read_gpr32(reg)),
              _    => read_gpr64(reg),
            };
            // Destination must be 64-byte aligned
            if (dst_addr & 0x000000000000003F) != zeros() then raise_GP0();
            mem_write512(dst_addr, src)
          },
          RM_reg(_) => raise_UD(),
        }
      } else if 200 <= op3 & op3 <= 205 & get_mandatory_prefix(pfx) == MP_NONE then {
        // SHA extensions (NP 0F 38 C8-CD)
        if ~(has_sha) then raise_UD();
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, rm, pfx);
        match op3 {
          200 => // SHA1NEXTE xmm1, xmm2/m128
            write_xmm_legacy(xreg, __sha1nexte(read_xmm(xreg), src_xmm)),
          201 => // SHA1MSG1 xmm1, xmm2/m128
            write_xmm_legacy(xreg, __sha1msg1(read_xmm(xreg), src_xmm)),
          202 => // SHA1MSG2 xmm1, xmm2/m128
            write_xmm_legacy(xreg, __sha1msg2(read_xmm(xreg), src_xmm)),
          203 => // SHA256RNDS2 xmm1, xmm2/m128, <XMM0>
            write_xmm_legacy(xreg, __sha256rnds2(read_xmm(xreg), src_xmm, read_xmm(0))),
          204 => // SHA256MSG1 xmm1, xmm2/m128
            write_xmm_legacy(xreg, __sha256msg1(read_xmm(xreg), src_xmm)),
          205 => // SHA256MSG2 xmm1, xmm2/m128
            write_xmm_legacy(xreg, __sha256msg2(read_xmm(xreg), src_xmm)),
          _ => raise_UD(),
        }
      } else {
        if sse_em_blocked() then raise_UD();
        if ~(has_ssse3) then raise_UD();
        dispatch_3byte_38_sse_int(opcode3, pfx)
      }
    },
    // 0F 3A: 3-byte escape (SSE4/AES-NI with imm8)
    58 => {
      if sse_em_blocked() then raise_UD();
      let opcode3 = fetch_byte();
      let op3 : range(0, 255) = unsigned(opcode3);
      match op3 {
        // SSE4.1 FP: ROUNDPS/PD/SS/SD, BLENDPS/PD, PEXTRW, EXTRACTPS, INSERTPS, DPPS, DPPD
        op3 if (8 <= op3 & op3 <= 13) | op3 == 21 | op3 == 23 | op3 == 33 | op3 == 64 | op3 == 65 => {
          if ~(has_sse4_1) then raise_UD();
          dispatch_3byte_3a_sse_fp(opcode3, pfx)
        },
        204 if get_mandatory_prefix(pfx) == MP_NONE => {
          // SHA1RNDS4 xmm1, xmm2/m128, imm8 (NP 0F 3A CC /r ib)
          if ~(has_sha) then raise_UD();
          let modrm = fetch_byte();
          let xreg = modrm_xmm_reg(modrm, pfx);
          let rm = decode_rm(modrm, pfx);
          let src_xmm : xmmword = decode_xmm_src(modrm, rm, pfx);
          let imm : byte = fetch_byte();
          write_xmm_legacy(xreg, __sha1rnds4(read_xmm(xreg), src_xmm, imm))
        },
        _  => {
          if ~(has_ssse3) then raise_UD();
          dispatch_3byte_3a_sse_int(opcode3, pfx)
        },
      }
    },

    // SSE floating-point (data movement, arithmetic, conversion, comparison)
    // CR0.EM=1 blocks all legacy SSE instructions with #UD
    op if (16 <= op & op <= 23) | (40 <= op & op <= 47) | (80 <= op & op <= 95)
        | op == 124 | op == 125 | op == 194 | op == 198
        | op == 208 | op == 214 | op == 230
      => { if sse_em_blocked() then raise_UD(); dispatch_2byte_sse_fp(op, pfx) },

    // SSE integer (packed integer arithmetic, logical, shift, pack/unpack)
    op if (96 <= op & op <= 118) | op == 126 | op == 127 | op == 196 | op == 197
        | (209 <= op & op <= 213) | (215 <= op & op <= 229) | (231 <= op & op <= 255)
      => { if sse_em_blocked() then raise_UD(); dispatch_2byte_sse_int(op, pfx) },

    // GPR and system operations (everything else)
    _ => dispatch_2byte_gpr(op, pfx),
  }
}

// =========================================================================
// 1-Byte Opcode Map Dispatch
// =========================================================================

// Check if a 1-byte opcode is lockable (LOCK prefix valid with memory dest).
// Lockable: ALU cols 0-1 (00-3F), 80-83 (ALU imm), 86-87 (XCHG),
// F6/F7 (NOT /2, NEG /3), FE/FF (INC /0, DEC /1)
val is_lockable_1byte : range(0, 255) -> bool
function is_lockable_1byte(op) = {
  if op <= 63 & (op % 8 == 0 | op % 8 == 1) then {
    true   // ALU r/m, r
  } else {
    match op {
      128 => true, 129 => true, 130 => true, 131 => true,  // 80-83: ALU r/m, imm
      134 => true, 135 => true,                             // 86-87: XCHG
      246 => true, 247 => true,                             // F6-F7: TEST/NOT/NEG/MUL/DIV
      254 => true, 255 => true,                             // FE-FF: INC/DEC
      _ => false,
    }
  }
}

// RETF — Far return (opcodes CA, CB).
// In 64-bit mode, default operand size is 32; REX.W makes it 64.
// Same-privilege: pop RIP, CS.
// Outer-privilege (RPL > CPL): also pop RSP, SS, then set CPL = RPL.
// SDM Vol.2 RET — IA-32e Mode Operation.
val exec_retf : (Prefixes, option(word)) -> unit
function exec_retf(pfx, maybe_imm) = {
  // Operand size: in 64-bit mode, default is 32, REX.W → 64, 66h → 16.
  // In non-64-bit mode, determined by CS.D and 66h prefix.
  let os : OperandSize = if cur_mode == LongMode then {
    if pfx.rex_w then OS64
    else if pfx.has_opsize then OS16
    else OS32
  } else {
    get_operand_size(pfx)
  };

  // Pop return RIP and CS
  let new_rip : qword = match os {
    OS64 => pop64(),
    OS32 => zero_extend(pop32()),
    _    => zero_extend(pop16()),
  };
  let new_cs_raw : qword = match os {
    OS64 => pop64(),
    OS32 => zero_extend(pop32()),
    _    => zero_extend(pop16()),
  };
  let new_cs : word = new_cs_raw[15..0];

  // In protected/long mode, null CS selector is invalid.
  // In real mode, CS=0x0000 is a valid segment (linear address 0).
  if cur_mode != RealMode & new_cs == 0x0000 then {
    throw Fault(EXN_GP, 0x00000000)
  };

  let return_rpl : cpl_t = unsigned(new_cs[1..0]);

  // RPL must not be less than current CPL (not applicable in real mode)
  if cur_mode != RealMode & return_rpl < cur_cpl then {
    throw Fault(EXN_GP, zero_extend(new_cs))
  };

  // In real mode, far return simply pops IP and CS — no privilege checks,
  // no SS/RSP pop (SDM Vol.2B RET, "Real-address mode or virtual-8086 mode").
  // In protected/long mode, check RPL for inter-privilege return.
  if cur_mode != RealMode & return_rpl > cur_cpl then {
    // Outer-privilege return: also pop RSP and SS
    let new_rsp : qword = match os {
      OS64 => pop64(),
      OS32 => zero_extend(pop32()),
      _    => zero_extend(pop16()),
    };
    let new_ss_raw : qword = match os {
      OS64 => pop64(),
      OS32 => zero_extend(pop32()),
      _    => zero_extend(pop16()),
    };
    let new_ss : word = new_ss_raw[15..0];
    write_gpr64(RSP, new_rsp);
    load_segment_register(SS, new_ss);
    // Adjust new RSP for imm16 if present
    match maybe_imm {
      Some(imm) => write_gpr64(RSP, read_gpr64(RSP) + zero_extend(imm)),
      None()    => (),
    }
  } else {
    // Same-privilege (or real mode): adjust RSP for imm16 if present
    match maybe_imm {
      Some(imm) => write_gpr64(RSP, read_gpr64(RSP) + zero_extend(imm)),
      None()    => (),
    }
  };

  // Load new CS (selector + descriptor cache) and set CPL
  load_segment_register(CS, new_cs);
  // Update cur_mode: in IA-32e mode, CS.L determines 64-bit vs compatibility
  if EFER[10] == bitone then {
    if SegCache[CS].seg_l == bitone then cur_mode = LongMode
    else cur_mode = CompatibilityMode
  };
  // In real mode, CPL is always 0 (no privilege levels).
  if cur_mode != RealMode then cur_cpl = return_rpl;

  // Set RIP to return address
  next_rip = Some(new_rip)
}

val decode_execute : unit -> unit
function decode_execute() = {
  let (pfx, opcode) = scan_prefixes();
  let op : range(0, 255) = unsigned(opcode);

  // LOCK prefix is only valid on specific opcodes; #UD otherwise.
  // (Per-instruction checks for register vs memory are done later.)
  if pfx.has_lock & ~(is_lockable_1byte(op)) & op != 15 then raise_UD();
  if op <= 63 & op % 8 <= 5 then {
    // ALU instructions 00-3F (regular pattern, columns 0-5 only)
    dispatch_alu_opcode(op, pfx)
  } else {
    match op {

      // 0F: Two-byte escape
      15 => {
        let opcode2 = fetch_byte();
        dispatch_opcode_2byte(opcode2, pfx)
      },

      // 27: DAA — Decimal Adjust AL After Addition (SDM Vol.2A)
      // #UD in 64-bit mode. Adjusts packed BCD result in AL after ADD.
      39 => {
        if cur_mode == LongMode then raise_UD();
        let old_al = read_gpr8l(RAX);
        let old_cf = CF;
        let lo : bits(4) = old_al[3..0];
        let cond1 : bits(1) = (lo[3..3] & (lo[2..2] | lo[1..1])) | AF;
        let al1 : byte = old_al + (0x06 & sign_extend(cond1));
        AF = cond1[0];
        let cond2 : bits(1) = ~(((0b0 @ old_al) - 0b0_1001_1010)[8..8]) | old_cf;
        let al_final : byte = al1 + (0x60 & sign_extend(cond2));
        CF = cond2[0];
        write_gpr8l(RAX, al_final);
        update_SF_ZF_PF(al_final)
      },

      // 2F: DAS — Decimal Adjust AL After Subtraction (SDM Vol.2A)
      // #UD in 64-bit mode. Adjusts packed BCD result in AL after SUB.
      47 => {
        if cur_mode == LongMode then raise_UD();
        let old_al = read_gpr8l(RAX);
        let old_cf = CF;
        let lo : bits(4) = old_al[3..0];
        let cond1 : bits(1) = (lo[3..3] & (lo[2..2] | lo[1..1])) | AF;
        let al1 : byte = old_al - (0x06 & sign_extend(cond1));
        let borrow1 : bits(5) = (0b0 @ lo) - (0b0 @ 0b0110);
        AF = cond1[0];
        let cond2 : bits(1) = ~(((0b0 @ old_al) - 0b0_1001_1010)[8..8]) | old_cf;
        let al_final : byte = al1 - (0x60 & sign_extend(cond2));
        CF = (cond2 | (cond1 & (old_cf | borrow1[4..4])))[0];
        write_gpr8l(RAX, al_final);
        update_SF_ZF_PF(al_final)
      },

      // 37: AAA — ASCII Adjust After Addition (SDM Vol.2A)
      // #UD in 64-bit mode. Adjusts unpacked BCD result in AL/AH.
      55 => {
        if cur_mode == LongMode then raise_UD();
        let lo : bits(4) = read_gpr8l(RAX)[3..0];
        let cond : bits(1) = (lo[3..3] & (lo[2..2] | lo[1..1])) | AF;
        let new_ax : word = read_gpr16(RAX) + (0x0106 & sign_extend(cond));
        write_gpr16(RAX, new_ax);
        AF = cond[0];
        CF = cond[0];
        write_gpr8l(RAX, new_ax[7..0] & 0x0F)
      },

      // 3F: AAS — ASCII Adjust AL After Subtraction (SDM Vol.2A)
      // #UD in 64-bit mode. Adjusts unpacked BCD result in AL/AH.
      63 => {
        if cur_mode == LongMode then raise_UD();
        let lo : bits(4) = read_gpr8l(RAX)[3..0];
        let cond : bits(1) = (lo[3..3] & (lo[2..2] | lo[1..1])) | AF;
        let new_ax : word = read_gpr16(RAX) - (0x0106 & sign_extend(cond));
        write_gpr16(RAX, new_ax);
        AF = cond[0];
        CF = cond[0];
        write_gpr8l(RAX, new_ax[7..0] & 0x0F)
      },

      // 06: PUSH ES — Push ES selector onto stack (SDM Vol.2B PUSH)
      // Invalid in 64-bit mode. Operand size determines push width:
      // OS32 → push zero-extended dword; OS16 → push word.
      6 => {
        if cur_mode == LongMode then raise_UD();
        let os = get_operand_size(pfx);
        match os {
          OS32 => push32(zero_extend(read_segreg(ES))),
          _    => push16(read_segreg(ES)),
        }
      },

      // 07: POP ES — Pop stack into ES (SDM Vol.2B POP)
      // Invalid in 64-bit mode. Pops operand-size value, loads low 16 bits
      // into ES and updates descriptor cache (load_segment_register).
      7 => {
        if cur_mode == LongMode then raise_UD();
        let os = get_operand_size(pfx);
        let v : word = match os {
          OS32 => pop32()[15..0],
          _    => pop16(),
        };
        load_segment_register(ES, v)
      },

      // 0E: PUSH CS — Push CS selector onto stack (SDM Vol.2B PUSH)
      // Invalid in 64-bit mode.
      14 => {
        if cur_mode == LongMode then raise_UD();
        let os = get_operand_size(pfx);
        match os {
          OS32 => push32(zero_extend(read_segreg(CS))),
          _    => push16(read_segreg(CS)),
        }
      },

      // 16: PUSH SS — Push SS selector onto stack (SDM Vol.2B PUSH)
      // Invalid in 64-bit mode.
      22 => {
        if cur_mode == LongMode then raise_UD();
        let os = get_operand_size(pfx);
        match os {
          OS32 => push32(zero_extend(read_segreg(SS))),
          _    => push16(read_segreg(SS)),
        }
      },

      // 17: POP SS — Pop stack into SS (SDM Vol.2B POP)
      // Invalid in 64-bit mode. Loading SS inhibits interrupts until after
      // the next instruction (SDM Vol.3A §7.8.3). Not modeled here.
      23 => {
        if cur_mode == LongMode then raise_UD();
        let os = get_operand_size(pfx);
        let v : word = match os {
          OS32 => pop32()[15..0],
          _    => pop16(),
        };
        load_segment_register(SS, v)
      },

      // 1E: PUSH DS — Push DS selector onto stack (SDM Vol.2B PUSH)
      // Invalid in 64-bit mode.
      30 => {
        if cur_mode == LongMode then raise_UD();
        let os = get_operand_size(pfx);
        match os {
          OS32 => push32(zero_extend(read_segreg(DS))),
          _    => push16(read_segreg(DS)),
        }
      },

      // 1F: POP DS — Pop stack into DS (SDM Vol.2B POP)
      // Invalid in 64-bit mode.
      31 => {
        if cur_mode == LongMode then raise_UD();
        let os = get_operand_size(pfx);
        let v : word = match os {
          OS32 => pop32()[15..0],
          _    => pop16(),
        };
        load_segment_register(DS, v)
      },

      // 60: PUSHA/PUSHAD — Push All General-Purpose Registers
      // #UD in 64-bit mode. Pushes AX..DI (OS16) or EAX..EDI (OS32).
      // Push order: AX, CX, DX, BX, original SP, BP, SI, DI.
      96 => {
        if cur_mode == LongMode then {
          raise_UD()
        } else {
          let os = get_operand_size(pfx);
          let orig_sp = read_stack_ptr();
          match os {
            OS32 => {
              push32(read_gpr32(RAX));
              push32(read_gpr32(RCX));
              push32(read_gpr32(RDX));
              push32(read_gpr32(RBX));
              push32(orig_sp[31..0] - get_seg_base(SS)[31..0]);
              push32(read_gpr32(RBP));
              push32(read_gpr32(RSI));
              push32(read_gpr32(RDI))
            },
            _ => {
              push16(read_gpr16(RAX));
              push16(read_gpr16(RCX));
              push16(read_gpr16(RDX));
              push16(read_gpr16(RBX));
              push16(orig_sp[15..0] - get_seg_base(SS)[15..0]);
              push16(read_gpr16(RBP));
              push16(read_gpr16(RSI));
              push16(read_gpr16(RDI))
            },
          }
        }
      },

      // 61: POPA/POPAD — Pop All General-Purpose Registers
      // #UD in 64-bit mode. Pops DI..AX (OS16) or EDI..EAX (OS32).
      // Pop order: EDI, ESI, EBP, skip ESP slot, EBX, EDX, ECX, EAX.
      97 => {
        if cur_mode == LongMode then {
          raise_UD()
        } else {
          let os = get_operand_size(pfx);
          match os {
            OS32 => {
              write_gpr32(RDI, pop32());
              write_gpr32(RSI, pop32());
              write_gpr32(RBP, pop32());
              // Skip the ESP slot (increment past it)
              let sp = read_stack_ptr();
              write_stack_ptr(sp + 4 - get_seg_base(SS));
              write_gpr32(RBX, pop32());
              write_gpr32(RDX, pop32());
              write_gpr32(RCX, pop32());
              write_gpr32(RAX, pop32())
            },
            _ => {
              write_gpr16(RDI, pop16());
              write_gpr16(RSI, pop16());
              write_gpr16(RBP, pop16());
              // Skip the SP slot
              let sp = read_stack_ptr();
              write_stack_ptr(sp + 2 - get_seg_base(SS));
              write_gpr16(RBX, pop16());
              write_gpr16(RDX, pop16());
              write_gpr16(RCX, pop16());
              write_gpr16(RAX, pop16())
            },
          }
        }
      },

      // 62: EVEX prefix (in 64-bit mode); BOUND (in 16/32-bit mode)
      // BOUND r16/r32, m16&16/m32&32: #BR if index out of bounds.
      // In non-64-bit mode, the second byte is a ModR/M — if mod==11b
      // (register operand), it's #UD (BOUND requires memory).
      // In 64-bit mode, 0x62 is always EVEX prefix.
      98 => {
        if cur_mode == LongMode then {
          dispatch_evex()
        } else {
          let modrm = fetch_byte();
          let rm = decode_rm(modrm, pfx);
          match rm {
            RM_reg(_) => raise_UD(),  // BOUND requires memory operand
            RM_mem(_, addr) => {
              let os = get_operand_size(pfx);
              let reg = modrm_reg(modrm, pfx);
              let index : qword = read_gpr(reg, os);
              match os {
                OS32 => {
                  let lower : dword = mem_read32(addr);
                  let upper : dword = mem_read32(addr + 4);
                  if signed(index[31..0]) < signed(lower) | signed(upper) < signed(index[31..0]) then
                    raise_BR()
                },
                _ => {
                  let lower : word = mem_read16(addr);
                  let upper : word = mem_read16(addr + 2);
                  if signed(index[15..0]) < signed(lower) | signed(upper) < signed(index[15..0]) then
                    raise_BR()
                },
              }
            },
          }
        }
      },

      // 63: MOVSXD r64, r/m32 (in 64-bit mode)
      99 => {
        let modrm = fetch_byte();
        let reg = modrm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        if pfx.rex_w then {
          let src = read_rm_val(rm, OS32, pfx.has_rex);
          write_gpr64(reg, sign_extend(src[31..0]))
        } else {
          let os = get_operand_size(pfx);
          let src = read_rm_val(rm, os, pfx.has_rex);
          write_gpr(reg, os, src)
        }
      },

      // 68: PUSH imm16/32 (d64, Iz)
      104 => {
        let os = get_operand_size_d64(pfx);
        let imm = fetch_imm_z(os);
        exec_push_imm(imm, os)
      },

      // 69: IMUL r, r/m, imm (3-operand, Iz)
      105 => {
        let os = get_operand_size(pfx);
        let modrm = fetch_byte();
        let reg = modrm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        // Fetch imm BEFORE reading rm so decode_pos is final for RIP-relative fixup
        let imm = fetch_imm_z(os);
        let src = read_rm_val(rm, os, pfx.has_rex);
        let product : int = match os {
          OS8  => signed(src[7..0]) * signed(imm[7..0]),
          OS16 => signed(src[15..0]) * signed(imm[15..0]),
          OS32 => signed(src[31..0]) * signed(imm[31..0]),
          OS64 => signed(src) * signed(imm),
        };
        let result : qword = to_bits_truncate(product);
        CF = match os {
          OS8  => {
            let w : bits(16) = to_bits_truncate(product);
            (or_reduce_8(w[15..8] ^ sign_extend(w[7..7])))[0]
          },
          OS16 => {
            let w : bits(32) = to_bits_truncate(product);
            (or_reduce_16(w[31..16] ^ sign_extend(w[15..15])))[0]
          },
          OS32 => {
            let w : bits(64) = to_bits_truncate(product);
            (or_reduce_32(w[63..32] ^ sign_extend(w[31..31])))[0]
          },
          OS64 => {
            let w : bits(128) = to_bits_truncate(product);
            (or_reduce_64(w[127..64] ^ sign_extend(w[63..63])))[0]
          },
        };
        OF = CF;
        write_gpr(reg, os, result)
      },

      // 6A: PUSH imm8 (d64, sign-extended)
      106 => {
        let os = get_operand_size_d64(pfx);
        let imm = fetch_imm8_sx();
        exec_push_imm(imm, os)
      },

      // 6B: IMUL r, r/m, imm8 (3-operand, Ib sign-extended)
      107 => {
        let os = get_operand_size(pfx);
        let modrm = fetch_byte();
        let reg = modrm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        // Fetch imm BEFORE reading rm so decode_pos is final for RIP-relative fixup
        let imm = fetch_imm8_sx();
        let src = read_rm_val(rm, os, pfx.has_rex);
        let product : int = match os {
          OS8  => signed(src[7..0]) * signed(imm[7..0]),
          OS16 => signed(src[15..0]) * signed(imm[15..0]),
          OS32 => signed(src[31..0]) * signed(imm[31..0]),
          OS64 => signed(src) * signed(imm),
        };
        let result : qword = to_bits_truncate(product);
        CF = match os {
          OS8  => {
            let w : bits(16) = to_bits_truncate(product);
            (or_reduce_8(w[15..8] ^ sign_extend(w[7..7])))[0]
          },
          OS16 => {
            let w : bits(32) = to_bits_truncate(product);
            (or_reduce_16(w[31..16] ^ sign_extend(w[15..15])))[0]
          },
          OS32 => {
            let w : bits(64) = to_bits_truncate(product);
            (or_reduce_32(w[63..32] ^ sign_extend(w[31..31])))[0]
          },
          OS64 => {
            let w : bits(128) = to_bits_truncate(product);
            (or_reduce_64(w[127..64] ^ sign_extend(w[63..63])))[0]
          },
        };
        OF = CF;
        write_gpr(reg, os, result)
      },

      // 6C: INSB — Input byte from port DX to ES:[RDI]
      108 => {
        let asz = get_address_size(pfx);
        if pfx.has_rep then exec_rep(REP_rep, STR_ins, OS8, asz, pfx)
        else exec_ins(OS8, asz)
      },
      // 6D: INSW/INSD — Input word/dword from port DX to ES:[RDI]
      109 => {
        let os = get_operand_size(pfx);
        let asz = get_address_size(pfx);
        if pfx.has_rep then exec_rep(REP_rep, STR_ins, os, asz, pfx)
        else exec_ins(os, asz)
      },
      // 6E: OUTSB — Output byte from DS:[RSI] to port DX
      110 => {
        let asz = get_address_size(pfx);
        if pfx.has_rep then exec_rep(REP_rep, STR_outs, OS8, asz, pfx)
        else exec_outs(OS8, asz, pfx)
      },
      // 6F: OUTSW/OUTSD — Output word/dword from DS:[RSI] to port DX
      111 => {
        let os = get_operand_size(pfx);
        let asz = get_address_size(pfx);
        if pfx.has_rep then exec_rep(REP_rep, STR_outs, os, asz, pfx)
        else exec_outs(os, asz, pfx)
      },

      // 80: Group 1 — ALU r/m8, imm8
      128 => {
        let modrm = fetch_byte();
        let rm = decode_rm(modrm, pfx);
        let reg_field : range(0, 7) = unsigned(modrm[5..3]);
        let imm : qword = zero_extend(fetch_byte());
        let alu_op = group1_op(reg_field);
        check_lock_rm(pfx, rm, alu_op == ALU_CMP);
        exec_alu_rm_imm(alu_op, rm, imm, OS8, pfx)
      },

      // 81: Group 1 — ALU r/m, imm (Iz)
      129 => {
        let os = get_operand_size(pfx);
        let modrm = fetch_byte();
        let rm = decode_rm(modrm, pfx);
        let reg_field : range(0, 7) = unsigned(modrm[5..3]);
        let imm = fetch_imm_z(os);
        let alu_op = group1_op(reg_field);
        check_lock_rm(pfx, rm, alu_op == ALU_CMP);
        exec_alu_rm_imm(alu_op, rm, imm, os, pfx)
      },

      // 83: Group 1 — ALU r/m, imm8 (sign-extended)
      131 => {
        let os = get_operand_size(pfx);
        let modrm = fetch_byte();
        let rm = decode_rm(modrm, pfx);
        let reg_field : range(0, 7) = unsigned(modrm[5..3]);
        let imm = fetch_imm8_sx();
        let alu_op = group1_op(reg_field);
        check_lock_rm(pfx, rm, alu_op == ALU_CMP);
        exec_alu_rm_imm(alu_op, rm, imm, os, pfx)
      },

      // 84: TEST r/m8, r8
      132 => {
        let modrm = fetch_byte();
        let reg = modrm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let a = read_rm_val(rm, OS8, pfx.has_rex);
        let b : qword = zero_extend(read_byte_reg(reg, pfx.has_rex));
        let result = a & b;
        update_flags_logic(result[7..0])
      },

      // 85: TEST r/m, r
      133 => {
        let os = get_operand_size(pfx);
        let modrm = fetch_byte();
        let reg = modrm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let a = read_rm_val(rm, os, pfx.has_rex);
        let b = read_gpr(reg, os);
        let result = a & b;
        match os {
          OS8  => update_flags_logic(result[7..0]),
          OS16 => update_flags_logic(result[15..0]),
          OS32 => update_flags_logic(result[31..0]),
          OS64 => update_flags_logic(result),
        }
      },

      // 86: XCHG r/m8, r8
      134 => {
        let modrm = fetch_byte();
        let reg = modrm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let a = read_rm_val(rm, OS8, pfx.has_rex);
        let b : qword = zero_extend(read_byte_reg(reg, pfx.has_rex));
        write_rm_val(rm, OS8, pfx.has_rex, b);
        write_byte_reg(reg, pfx.has_rex, a[7..0])
      },

      // 87: XCHG r/m, r
      135 => {
        let os = get_operand_size(pfx);
        let modrm = fetch_byte();
        let reg = modrm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let a = read_rm_val(rm, os, pfx.has_rex);
        let b = read_gpr(reg, os);
        write_rm_val(rm, os, pfx.has_rex, b);
        write_gpr(reg, os, a)
      },

      // 88: MOV r/m8, r8
      136 => {
        let modrm = fetch_byte();
        let reg = modrm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let v : qword = zero_extend(read_byte_reg(reg, pfx.has_rex));
        write_rm_val(rm, OS8, pfx.has_rex, v)
      },

      // 89: MOV r/m, r
      137 => {
        let os = get_operand_size(pfx);
        let modrm = fetch_byte();
        let reg = modrm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        write_rm_val(rm, os, pfx.has_rex, read_gpr(reg, os))
      },

      // 8A: MOV r8, r/m8
      138 => {
        let modrm = fetch_byte();
        let reg = modrm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let v = read_rm_val(rm, OS8, pfx.has_rex);
        write_byte_reg(reg, pfx.has_rex, v[7..0])
      },

      // 8B: MOV r, r/m
      139 => {
        let os = get_operand_size(pfx);
        let modrm = fetch_byte();
        let reg = modrm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        write_gpr(reg, os, read_rm_val(rm, os, pfx.has_rex))
      },

      // 8C: MOV r/m16, sreg
      140 => {
        let modrm = fetch_byte();
        let reg_field : range(0, 7) = unsigned(modrm[5..3]);
        if reg_field > 5 then {
          raise_UD()
        } else {
          let seg : segreg_idx = reg_field;
          let rm = decode_rm(modrm, pfx);
          match rm {
            RM_reg(idx) => {
              let os = get_operand_size(pfx);
              write_gpr(idx, os, zero_extend(read_segreg(seg)))
            },
            RM_mem(s, offset) => seg_write16(s, offset, read_segreg(seg)),
          }
        }
      },

      // 8E: MOV sreg, r/m16
      142 => {
        let modrm = fetch_byte();
        let reg_field : range(0, 7) = unsigned(modrm[5..3]);
        if reg_field > 5 then {
          raise_UD()
        } else {
          let seg : segreg_idx = reg_field;
          let rm = decode_rm(modrm, pfx);
          let v : word = match rm {
            RM_reg(idx) => read_gpr16(idx),
            RM_mem(s, offset) => seg_read16(s, offset),
          };
          if seg == CS then raise_UD();
          load_segment_register(seg, v)
        }
      },

      // 8D: LEA r, m
      141 => {
        let os = get_operand_size(pfx);
        let modrm = fetch_byte();
        let reg = modrm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        match rm {
          RM_mem(_, offset) => write_gpr(reg, os, offset),
          RM_reg(_) => raise_UD(),
        }
      },

      // 8F /0: POP r/m (d64)
      // SDM: "If the RSP register is used as a base register for addressing
      // a destination operand in memory, the POP instruction computes the
      // effective address of the operand after it increments the RSP register."
      143 => {
        let modrm = fetch_byte();
        let reg_field : range(0, 7) = unsigned(modrm[5..3]);
        if reg_field == 0 then {
          let os = get_operand_size_d64(pfx);
          let mod_field : range(0, 3) = unsigned(modrm[7..6]);
          let rm_field : range(0, 7) = unsigned(modrm[2..0]);
          if mod_field == 3 then {
            // Register destination — no address computation issue
            let idx = extend_reg(rm_field, pfx.rex_b);
            exec_pop_reg(idx, os)
          } else {
            // Memory destination: pop first, THEN compute effective address
            // (SDM requires RSP-relative addresses use the post-pop RSP).
            // We pop first so that decode_rm sees the updated RSP.
            let v : qword = match os {
              OS64 => pop64(),
              OS32 => zero_extend(pop32()),
              OS16 => zero_extend(pop16()),
              _ => zeros(),
            };
            let rm = decode_rm(modrm, pfx);
            match rm {
              RM_mem(seg, offset) => {
                match os {
                  OS64 => seg_write64(seg, offset, v),
                  OS32 => seg_write32(seg, offset, v[31..0]),
                  OS16 => seg_write16(seg, offset, v[15..0]),
                  _ => (),
                }
              },
              _ => raise_UD(),
            }
          }
        } else {
          raise_UD()
        }
      },

      // 90: NOP / PAUSE (F3 90) / XCHG R8D,EAX (REX.B)
      144 => {
        if pfx.has_rep then {
          ()
        } else if pfx.rex_b == bitone then {
          let os = get_operand_size(pfx);
          exec_xchg_reg_reg(RAX, R8, os)
        } else {
          ()
        }
      },

      // 98: CBW/CWDE/CDQE
      152 => {
        let os = get_operand_size(pfx);
        match os {
          OS8 => (),
          OS16 => { let v : word = sign_extend(read_gpr8l(RAX)); write_gpr16(RAX, v) },
          OS32 => { let v : dword = sign_extend(read_gpr16(RAX)); write_gpr32(RAX, v) },
          OS64 => { let v : qword = sign_extend(read_gpr32(RAX)); write_gpr64(RAX, v) },
        }
      },

      // 99: CWD/CDQ/CQO
      153 => {
        let os = get_operand_size(pfx);
        match os {
          OS8 => (),
          OS16 => write_gpr16(RDX, sign_extend(read_gpr16(RAX)[15..15])),
          OS32 => write_gpr32(RDX, sign_extend(read_gpr32(RAX)[31..31])),
          OS64 => write_gpr64(RDX, sign_extend(read_gpr64(RAX)[63..63])),
        }
      },

      // 9A: CALL ptr16:16/ptr16:32 — Far call, immediate
      // Invalid in 64-bit mode. Encoding: offset (16/32 bits) then selector (16 bits).
      154 => {
        if cur_mode == LongMode then {
          raise_UD()
        } else {
          let os = get_operand_size(pfx);
          let offset : qword = match os {
            OS16 => fetch_imm_v(OS16),
            _    => fetch_imm_v(OS32),
          };
          let selector : word = fetch_imm16();
          match cur_mode {
            RealMode => {
              // Push old CS:IP/EIP
              match os {
                OS16 => { push16(read_segreg(CS)); push16(decode_pos[15..0]) },
                _    => { push32(zero_extend(read_segreg(CS))); push32(decode_pos[31..0]) },
              };
              load_segment_register(CS, selector);
              let target : qword = match os {
                OS16 => zero_extend(offset[15..0]),
                _    => zero_extend(offset[31..0]),
              };
              next_rip = Some(target)
            },
            _ => exec_far_call_protected(selector, offset, os),
          }
        }
      },

      // 9B: FWAIT/WAIT
      155 => __wait(),

      // 9C: PUSHF (d64)
      // SDM: push(RFLAGS AND 00FCFFFFH) — RF (bit 16) and VM (bit 17) cleared.
      156 => {
        let os = get_operand_size_d64(pfx);
        let flags = read_rflags() & 0x0000000000FCFFFF;
        exec_push_imm(flags, os)
      },

      // 9D: POPF (d64)
      // At CPL 0: all flags except RF, VIP, VIF, VM modifiable.
      // RF is always cleared (cleared at start of every instruction).
      // For 16-bit: only lower 16 bits affect flags (IOPL modifiable at CPL 0,
      // but AC/ID are above bit 15 and are NOT modified).
      157 => {
        let os = get_operand_size_d64(pfx);
        match os {
          OS16 => {
            let v : word = pop16();
            CF = v[0]; PF = v[2]; AF = v[4]; ZF = v[6]; SF = v[7];
            TF = v[8]; DF = v[10]; OF = v[11];
            NT = v[14];
            // IOPL modifiable only at CPL 0; IF modifiable at CPL <= IOPL
            if cur_cpl == 0 then IOPL = v[13..12];
            if cur_cpl <= unsigned(IOPL) then IF_flag = v[9];
          },
          OS32 => {
            let v : dword = pop32();
            CF = v[0]; PF = v[2]; AF = v[4]; ZF = v[6]; SF = v[7];
            TF = v[8]; DF = v[10]; OF = v[11];
            NT = v[14];
            AC_flag = v[18]; ID = v[21];
            if cur_cpl == 0 then IOPL = v[13..12];
            if cur_cpl <= unsigned(IOPL) then IF_flag = v[9];
          },
          OS64 => {
            let v : qword = pop64();
            // Save IOPL and IF before write_rflags overwrites them
            let old_iopl = IOPL;
            let old_if = IF_flag;
            write_rflags(v);
            // RF always cleared; VIP, VIF, VM not modifiable
            RF = bitzero;
            // IOPL modifiable only at CPL 0; IF modifiable at CPL <= IOPL
            if cur_cpl != 0 then IOPL = old_iopl;
            if cur_cpl > unsigned(old_iopl) then IF_flag = old_if;
          },
          _ => (),
        }
      },

      // 9E: SAHF
      158 => {
        let ah : byte = read_gpr8h(RAX);
        CF = ah[0]; PF = ah[2]; AF = ah[4]; ZF = ah[6]; SF = ah[7]
      },

      // 9F: LAHF — AH := RFLAGS[7:0] = SF:ZF:0:AF:0:PF:1:CF
      159 => {
        let v : byte = SF @ ZF @ bitzero @ AF @ bitzero @ PF @ bitone @ CF;
        write_gpr8h(RAX, v)
      },

      // A0: MOV AL, moffs8
      160 => {
        let addr = apply_segment(fetch_moffs(pfx), pfx, DS);
        write_gpr8l(RAX, mem_read8(addr))
      },

      // A1: MOV rAX, moffs
      161 => {
        let os = get_operand_size(pfx);
        let addr = apply_segment(fetch_moffs(pfx), pfx, DS);
        let v : qword = match os {
          OS8  => zero_extend(mem_read8(addr)),
          OS16 => zero_extend(mem_read16(addr)),
          OS32 => zero_extend(mem_read32(addr)),
          OS64 => mem_read64(addr),
        };
        write_gpr(RAX, os, v)
      },

      // A2: MOV moffs8, AL
      162 => {
        let addr = apply_segment(fetch_moffs(pfx), pfx, DS);
        mem_write8(addr, read_gpr8l(RAX))
      },

      // A3: MOV moffs, rAX
      163 => {
        let os = get_operand_size(pfx);
        let addr = apply_segment(fetch_moffs(pfx), pfx, DS);
        let v = read_gpr(RAX, os);
        match os {
          OS8  => mem_write8(addr, v[7..0]),
          OS16 => mem_write16(addr, v[15..0]),
          OS32 => mem_write32(addr, v[31..0]),
          OS64 => mem_write64(addr, v),
        }
      },

      // A4: MOVSB
      164 => {
        let asz = get_address_size(pfx);
        if pfx.has_rep then exec_rep(REP_rep, STR_movs, OS8, asz, pfx)
        else exec_movs(OS8, asz, pfx)
      },

      // A5: MOVSW/MOVSD/MOVSQ
      165 => {
        let os = get_operand_size(pfx);
        let asz = get_address_size(pfx);
        if pfx.has_rep then exec_rep(REP_rep, STR_movs, os, asz, pfx)
        else exec_movs(os, asz, pfx)
      },

      // A6: CMPSB
      166 => {
        let asz = get_address_size(pfx);
        if pfx.has_rep then exec_rep(REP_repe, STR_cmps, OS8, asz, pfx)
        else if pfx.has_repne then exec_rep(REP_repne, STR_cmps, OS8, asz, pfx)
        else exec_cmps(OS8, asz, pfx)
      },

      // A7: CMPSW/CMPSD/CMPSQ
      167 => {
        let os = get_operand_size(pfx);
        let asz = get_address_size(pfx);
        if pfx.has_rep then exec_rep(REP_repe, STR_cmps, os, asz, pfx)
        else if pfx.has_repne then exec_rep(REP_repne, STR_cmps, os, asz, pfx)
        else exec_cmps(os, asz, pfx)
      },

      // A8: TEST AL, imm8
      168 => {
        let imm : qword = zero_extend(fetch_byte());
        let a : qword = zero_extend(read_gpr8l(RAX));
        let result = a & imm;
        update_flags_logic(result[7..0])
      },

      // A9: TEST rAX, imm (Iz)
      169 => {
        let os = get_operand_size(pfx);
        let imm = fetch_imm_z(os);
        let a = read_gpr(RAX, os);
        let result = a & imm;
        match os {
          OS8  => update_flags_logic(result[7..0]),
          OS16 => update_flags_logic(result[15..0]),
          OS32 => update_flags_logic(result[31..0]),
          OS64 => update_flags_logic(result),
        }
      },

      // AA: STOSB
      170 => {
        let asz = get_address_size(pfx);
        if pfx.has_rep then exec_rep(REP_rep, STR_stos, OS8, asz, pfx)
        else exec_stos(OS8, asz)
      },

      // AB: STOSW/STOSD/STOSQ
      171 => {
        let os = get_operand_size(pfx);
        let asz = get_address_size(pfx);
        if pfx.has_rep then exec_rep(REP_rep, STR_stos, os, asz, pfx)
        else exec_stos(os, asz)
      },

      // AC: LODSB
      172 => {
        let asz = get_address_size(pfx);
        if pfx.has_rep then exec_rep(REP_rep, STR_lods, OS8, asz, pfx)
        else exec_lods(OS8, asz, pfx)
      },

      // AD: LODSW/LODSD/LODSQ
      173 => {
        let os = get_operand_size(pfx);
        let asz = get_address_size(pfx);
        if pfx.has_rep then exec_rep(REP_rep, STR_lods, os, asz, pfx)
        else exec_lods(os, asz, pfx)
      },

      // AE: SCASB
      174 => {
        let asz = get_address_size(pfx);
        if pfx.has_rep then exec_rep(REP_repe, STR_scas, OS8, asz, pfx)
        else if pfx.has_repne then exec_rep(REP_repne, STR_scas, OS8, asz, pfx)
        else exec_scas(OS8, asz)
      },

      // AF: SCASW/SCASD/SCASQ
      175 => {
        let os = get_operand_size(pfx);
        let asz = get_address_size(pfx);
        if pfx.has_rep then exec_rep(REP_repe, STR_scas, os, asz, pfx)
        else if pfx.has_repne then exec_rep(REP_repne, STR_scas, os, asz, pfx)
        else exec_scas(os, asz)
      },

      // C0: Group 2 — shift r/m8 by imm8
      192 => {
        let modrm = fetch_byte();
        let rm = decode_rm(modrm, pfx);
        let reg_field : range(0, 7) = unsigned(modrm[5..3]);
        let count = fetch_byte();
        exec_shift_rm(reg_field, rm, count, OS8, pfx)
      },

      // C1: Group 2 — shift r/m by imm8
      193 => {
        let os = get_operand_size(pfx);
        let modrm = fetch_byte();
        let rm = decode_rm(modrm, pfx);
        let reg_field : range(0, 7) = unsigned(modrm[5..3]);
        let count = fetch_byte();
        exec_shift_rm(reg_field, rm, count, os, pfx)
      },

      // C2: RET near imm16
      // SDM: In 64-bit mode, operand size = stack-address size = 64.
      // 66h prefix is ignored; 16/32-bit forms are not encodable.
      194 => {
        let imm = fetch_imm16();
        let os = get_operand_size_f64(pfx);
        let target : qword = match os {
          OS64 => pop64(),
          OS32 => zero_extend(pop32()),
          OS16 => zero_extend(pop16()),
          OS8 => zeros(),
        };
        next_rip = Some(target);
        GPR[RSP] = GPR[RSP] + zero_extend(imm)
      },

      // C3: RET near
      // SDM: In 64-bit mode, operand size = stack-address size = 64.
      // 66h prefix is ignored; 16/32-bit forms are not encodable.
      195 => {
        let os = get_operand_size_f64(pfx);
        let target : qword = match os {
          OS64 => pop64(),
          OS32 => zero_extend(pop32()),
          OS16 => zero_extend(pop16()),
          OS8 => zeros(),
        };
        next_rip = Some(target)
      },

      // C6 /0: MOV r/m8, imm8
      198 => {
        let modrm = fetch_byte();
        let reg_field : range(0, 7) = unsigned(modrm[5..3]);
        if reg_field == 0 then {
          let rm = decode_rm(modrm, pfx);
          let imm : qword = zero_extend(fetch_byte());
          write_rm_val(rm, OS8, pfx.has_rex, imm)
        } else {
          raise_UD()
        }
      },

      // C7 /0: MOV r/m, imm (Iz)
      199 => {
        let modrm = fetch_byte();
        let reg_field : range(0, 7) = unsigned(modrm[5..3]);
        if reg_field == 0 then {
          let os = get_operand_size(pfx);
          let rm = decode_rm(modrm, pfx);
          let imm = fetch_imm_z(os);
          write_rm_val(rm, os, pfx.has_rex, imm)
        } else {
          raise_UD()
        }
      },

      // C8: ENTER imm16, imm8
      200 => {
        let size = fetch_imm16();
        let level = fetch_byte();
        let os = get_operand_size_d64(pfx);
        let nesting : range(0, 31) = unsigned(level) % 32;
        match os {
          OS64 => {
            push64(read_gpr64(RBP));
            let frame_temp : qword = read_gpr64(RSP);
            if nesting > 1 then {
              foreach (i from 1 to (nesting - 1)) {
                write_gpr64(RBP, read_gpr64(RBP) - 8);
                push64(mem_read64(read_gpr64(RBP)));
              };
            };
            if nesting >= 1 then
              push64(frame_temp);
            write_gpr64(RBP, frame_temp);
            write_gpr64(RSP, read_gpr64(RSP) - zero_extend(size));
          },
          OS16 => {
            push16(read_gpr16(RBP));
            let frame_temp : word = read_gpr16(RSP);
            if nesting > 1 then {
              foreach (i from 1 to (nesting - 1)) {
                write_gpr16(RBP, read_gpr16(RBP) - 2);
                push16(mem_read16(zero_extend(read_gpr16(RBP))));
              };
            };
            if nesting >= 1 then
              push16(frame_temp);
            write_gpr16(RBP, frame_temp);
            write_gpr64(RSP, read_gpr64(RSP) - zero_extend(size));
          },
          _ => (),
        }
      },

      // C9: LEAVE
      // In 64-bit mode, StackAddrSize is always 64: RSP := RBP uses full
      // 64-bit RBP regardless of operand-size prefix. Only the POP of RBP
      // is affected by operand size (16 vs 64).
      201 => {
        let os = get_operand_size_d64(pfx);
        write_gpr64(RSP, read_gpr64(RBP));
        match os {
          OS8 => (),
          OS16 => write_gpr16(RBP, pop16()),
          OS32 => {
            let v : qword = pop64();
            write_gpr32(RBP, v[31..0]);
          },
          OS64 => write_gpr64(RBP, pop64()),
        }
      },

      // CA: RETF imm16 — Far return with stack adjustment
      // CB: RETF — Far return
      // In 64-bit mode, default operand size for far RET is 32; REX.W makes it 64.
      // Same-privilege: pop RIP, CS only.
      // Outer-privilege (RPL of new CS > CPL): also pop RSP, SS. (SDM Vol.2 RET)
      202 => exec_retf(pfx, Some(fetch_imm16())),
      203 => exec_retf(pfx, None()),

      // CC: INT 3 — trap (saved RIP points past the INT3 byte)
      // SDM: software interrupt, no error code pushed, gate DPL check applies.
      204 => {
        if system_mode then {
          sw_return_rip = Some(decode_pos);
          deliver_exception(3, 0x00000000, true);
          next_rip = Some(RIP)  // deliver_exception set RIP to handler
        } else {
          __software_interrupt(0x03)
        }
      },

      // CD: INT imm8
      // SDM: software interrupt, no error code pushed, gate DPL check applies.
      205 => {
        let imm = fetch_byte();
        if system_mode then {
          sw_return_rip = Some(decode_pos);
          deliver_exception(unsigned(imm), 0x00000000, true);
          next_rip = Some(RIP)  // deliver_exception set RIP to handler
        } else {
          __software_interrupt(imm)
        }
      },

      // CE: INTO — Interrupt on Overflow (SDM Vol.2A INT n/INTO/INT3/INT1)
      // #UD in 64-bit mode. If OF=1, generates #OF (vector 4).
      206 => {
        if cur_mode == LongMode then raise_UD();
        if OF == bitone then {
          if system_mode then {
            sw_return_rip = Some(decode_pos);
            deliver_exception(EXN_OF, 0x00000000, true);
            next_rip = Some(RIP)
          } else {
            __software_interrupt(0x04)
          }
        }
      },

      // CF: IRET/IRETD/IRETQ — Interrupt Return
      // Real mode: pop IP, CS, FLAGS (3 words, no SP/SS).
      // Protected mode same-privilege: pop EIP, CS, EFLAGS (no ESP/SS).
      // Protected mode outer-privilege: also pop ESP, SS.
      // 64-bit mode: always pop RIP, CS, RFLAGS, RSP, SS (SDM Vol.2 IRET).
      207 => {
        let os = get_operand_size(pfx);
        if NT == bitone then {
          throw Fault(EXN_GP, 0x00000000)
        };
        match os {
          OS8 => (),
          OS16 => {
            let new_ip     = pop16();
            let new_cs     = pop16();
            let new_flags  = pop16();

            let return_rpl : cpl_t = unsigned(new_cs[1..0]);

            next_rip = Some(zero_extend(new_ip));
            load_segment_register(CS, new_cs);

            // Only pop SP/SS on outer-privilege return (not in real mode)
            if cur_mode != RealMode & return_rpl > cur_cpl then {
              let new_sp = pop16();
              let new_ss = pop16();
              write_gpr64(RSP, zero_extend(new_sp));
              load_segment_register(SS, new_ss)
            };

            // In real mode, CPL is always 0 (no privilege levels).
            // In protected mode, set CPL from the return CS selector RPL.
            if cur_mode != RealMode then cur_cpl = return_rpl;
            let old_rflags = read_rflags();
            write_rflags((old_rflags & 0xFFFFFFFFFFFF0000) | zero_extend(new_flags));
            RF = bitzero
          },
          OS32 => {
            let new_eip    = pop32();
            let new_cs_raw = pop32();
            let new_eflags = pop32();
            let new_cs : word = new_cs_raw[15..0];

            let return_rpl : cpl_t = unsigned(new_cs[1..0]);

            next_rip = Some(zero_extend(new_eip));
            load_segment_register(CS, new_cs);

            // Only pop ESP/SS on outer-privilege return (not in real mode)
            if cur_mode != RealMode & return_rpl > cur_cpl then {
              let new_esp = pop32();
              let new_ss  = pop32();
              write_gpr64(RSP, zero_extend(new_esp));
              load_segment_register(SS, new_ss[15..0])
            };

            if cur_mode != RealMode then cur_cpl = return_rpl;
            write_rflags(zero_extend(new_eflags));
            RF = bitzero
          },
          OS64 => {
            let new_rip    = pop64();
            let new_cs     = pop64();
            let new_rflags = pop64();
            let new_rsp    = pop64();
            let new_ss     = pop64();

            next_rip = Some(new_rip);

            // Load CS selector and descriptor cache from GDT.
            let sel_offset : qword = zero_extend(new_cs[15..3] @ 0b000);
            let desc_lo : dword = mem_read32(GDTR_base + sel_offset);
            let desc_hi : dword = mem_read32(GDTR_base + sel_offset + 4);
            write_segreg(CS, new_cs[15..0]);
            SegCache[CS] = parse_seg_descriptor(desc_lo, desc_hi);
            cur_mode = if SegCache[CS].seg_l == bitone then LongMode
                       else CompatibilityMode;

            let new_cpl : cpl_t = unsigned(new_cs[1..0]);
            cur_cpl = new_cpl;

            write_rflags(new_rflags);
            RF = bitzero;

            write_gpr64(RSP, new_rsp);
            write_segreg(SS, new_ss[15..0]);
          },
        }
      },

      // D0: Group 2 — shift r/m8 by 1
      208 => {
        let modrm = fetch_byte();
        let rm = decode_rm(modrm, pfx);
        let reg_field : range(0, 7) = unsigned(modrm[5..3]);
        exec_shift_rm(reg_field, rm, 0x01, OS8, pfx)
      },

      // D1: Group 2 — shift r/m by 1
      209 => {
        let os = get_operand_size(pfx);
        let modrm = fetch_byte();
        let rm = decode_rm(modrm, pfx);
        let reg_field : range(0, 7) = unsigned(modrm[5..3]);
        exec_shift_rm(reg_field, rm, 0x01, os, pfx)
      },

      // D2: Group 2 — shift r/m8 by CL
      210 => {
        let modrm = fetch_byte();
        let rm = decode_rm(modrm, pfx);
        let reg_field : range(0, 7) = unsigned(modrm[5..3]);
        let count = read_gpr8l(RCX);
        exec_shift_rm(reg_field, rm, count, OS8, pfx)
      },

      // D3: Group 2 — shift r/m by CL
      211 => {
        let os = get_operand_size(pfx);
        let modrm = fetch_byte();
        let rm = decode_rm(modrm, pfx);
        let reg_field : range(0, 7) = unsigned(modrm[5..3]);
        let count = read_gpr8l(RCX);
        exec_shift_rm(reg_field, rm, count, os, pfx)
      },

      // D4: AAM — ASCII Adjust AX After Multiply (SDM Vol.2A)
      // #UD in 64-bit mode. D4 ib: AH := AL / imm8; AL := AL MOD imm8.
      // #DE if imm8 == 0.
      212 => {
        if cur_mode == LongMode then raise_UD();
        let imm = fetch_byte();
        if imm == 0x00 then raise_DE();
        let temp_al = read_gpr8l(RAX);
        let divisor = unsigned(imm);
        assert(divisor > 0);
        write_gpr8h(RAX, to_bits(8, unsigned(temp_al) / divisor));
        write_gpr8l(RAX, to_bits(8, unsigned(temp_al) % divisor));
        update_SF_ZF_PF(read_gpr8l(RAX))
      },

      // D5: AAD — ASCII Adjust AX Before Division (SDM Vol.2A)
      // #UD in 64-bit mode. D5 ib: AL := (AL + AH * imm8) AND FFH; AH := 0.
      213 => {
        if cur_mode == LongMode then raise_UD();
        let imm = fetch_byte();
        let temp_al = read_gpr8l(RAX);
        let temp_ah = read_gpr8h(RAX);
        let result : byte = to_bits(8, (unsigned(temp_al) + unsigned(temp_ah) * unsigned(imm)) % 256);
        write_gpr8l(RAX, result);
        write_gpr8h(RAX, 0x00);
        update_SF_ZF_PF(result)
      },

      // D6: SALC — Set AL to Carry Flag (undocumented, invalid in 64-bit mode)
      // AL := 0 - CF (0xFF if CF=1, 0x00 if CF=0). No flags affected.
      214 => {
        if cur_mode == LongMode then raise_UD();
        write_gpr8l(RAX, sign_extend(CF))
      },

      // D7: XLAT/XLATB
      215 => {
        let asz = get_address_size(pfx);
        let al : qword = zero_extend(read_gpr8l(RAX));
        let addr : qword = match asz {
          AS64 => read_gpr64(RBX) + al,
          AS32 => zero_extend(read_gpr32(RBX)) + al,
          AS16 => zero_extend(read_gpr16(RBX)) + al,
        };
        write_gpr8l(RAX, mem_read8(addr))
      },

      // D8-DF: x87 FPU
      op if 216 <= op & op <= 223 => dispatch_x87(opcode, pfx),

      // E0: LOOPNE/LOOPNZ rel8
      224 => {
        let rel = fetch_byte();
        let asz = get_address_size(pfx);
        exec_loop(rel, LOOP_ne, asz)
      },

      // E1: LOOPE/LOOPZ rel8
      225 => {
        let rel = fetch_byte();
        let asz = get_address_size(pfx);
        exec_loop(rel, LOOP_e, asz)
      },

      // E2: LOOP rel8
      226 => {
        let rel = fetch_byte();
        let asz = get_address_size(pfx);
        exec_loop(rel, LOOP_always, asz)
      },

      // E3: JCXZ/JECXZ/JRCXZ rel8
      // Address size selects CX (AS16), ECX (AS32), or RCX (AS64).
      227 => {
        let rel = fetch_rel8();
        let asz = get_address_size(pfx);
        let count_reg : qword = match asz {
          AS16 => zero_extend(read_gpr16(RCX)),
          AS32 => zero_extend(read_gpr32(RCX)),
          AS64 => read_gpr64(RCX),
        };
        if count_reg == zeros() then {
          let os = get_operand_size_f64(pfx);
          next_rip = Some(truncate_rip(decode_pos + rel, os))
        } else {
          ()
        }
      },

      // E4: IN AL, imm8
      228 => {
        let port : word = zero_extend(fetch_byte());
        exec_in(port, OS8)
      },

      // E5: IN eAX, imm8
      229 => {
        let port : word = zero_extend(fetch_byte());
        let os = get_operand_size(pfx);
        exec_in(port, os)
      },

      // E6: OUT imm8, AL
      230 => {
        let port : word = zero_extend(fetch_byte());
        exec_out(port, OS8)
      },

      // E7: OUT imm8, eAX
      231 => {
        let port : word = zero_extend(fetch_byte());
        let os = get_operand_size(pfx);
        exec_out(port, os)
      },

      // E8: CALL rel16/rel32 (f64)
      232 => {
        let offset = fetch_rel_os(pfx);
        let os = get_operand_size_f64(pfx);
        let return_addr = decode_pos;
        match os {
          OS8 => (),
          OS16 => push16(return_addr[15..0]),
          OS32 => if cur_mode == LongMode then push64(zero_extend(return_addr[31..0]))
                  else push32(return_addr[31..0]),
          OS64 => push64(return_addr),
        };
        next_rip = Some(truncate_rip(return_addr + offset, os))
      },

      // E9: JMP rel16/rel32 (f64)
      233 => {
        let os = get_operand_size_f64(pfx);
        next_rip = Some(truncate_rip(decode_pos + fetch_rel_os(pfx), os))
      },

      // EA: JMP ptr16:16/ptr16:32 — Far jump, immediate
      // Invalid in 64-bit mode. Encoding: offset (16/32 bits) then selector (16 bits).
      234 => {
        if cur_mode == LongMode then {
          raise_UD()
        } else {
          let os = get_operand_size(pfx);
          let offset : qword = match os {
            OS16 => fetch_imm_v(OS16),
            _    => fetch_imm_v(OS32),
          };
          let selector : word = fetch_imm16();
          match cur_mode {
            RealMode => {
              load_segment_register(CS, selector);
              let target : qword = match os {
                OS16 => zero_extend(offset[15..0]),
                _    => zero_extend(offset[31..0]),
              };
              next_rip = Some(target)
            },
            _ => exec_far_jmp_protected(selector, offset, os),
          }
        }
      },

      // EB: JMP rel8 (f64)
      235 => {
        let os = get_operand_size_f64(pfx);
        next_rip = Some(truncate_rip(decode_pos + fetch_rel8(), os))
      },

      // EC: IN AL, DX
      236 => exec_in(read_gpr16(RDX), OS8),

      // ED: IN eAX, DX
      237 => {
        let os = get_operand_size(pfx);
        exec_in(read_gpr16(RDX), os)
      },

      // EE: OUT DX, AL
      238 => exec_out(read_gpr16(RDX), OS8),

      // EF: OUT DX, eAX
      239 => {
        let os = get_operand_size(pfx);
        exec_out(read_gpr16(RDX), os)
      },

      // F1: INT1 / ICEBP — Generate #DB (vector 1) without setting DR6 bits.
      // SDM: delivers interrupt/exception to vector 1.
      241 => throw Fault(EXN_DB, 0x00000000),

      // F4: HLT — SDM: #GP(0) if CPL > 0
      244 => {
        if cur_cpl != 0 then raise_GP0();
        system_state = SysHalted
      },

      // F5: CMC
      245 => CF = ~(CF),

      // F6: Group 3 — unary byte operations
      246 => {
        let modrm = fetch_byte();
        let reg_field : range(0, 7) = unsigned(modrm[5..3]);
        let rm = decode_rm(modrm, pfx);
        // LOCK valid only for NOT (/2) and NEG (/3) with memory destination
        if pfx.has_lock & (reg_field != 2 & reg_field != 3) then raise_UD();
        check_lock_rm(pfx, rm, false);
        dispatch_group3_byte(reg_field, rm, pfx)
      },

      // F7: Group 3 — unary word/dword/qword operations
      247 => {
        let os = get_operand_size(pfx);
        let modrm = fetch_byte();
        let reg_field : range(0, 7) = unsigned(modrm[5..3]);
        let rm = decode_rm(modrm, pfx);
        // LOCK valid only for NOT (/2) and NEG (/3) with memory destination
        if pfx.has_lock & (reg_field != 2 & reg_field != 3) then raise_UD();
        check_lock_rm(pfx, rm, false);
        dispatch_group3(reg_field, rm, os, pfx)
      },

      // F8: CLC
      248 => CF = bitzero,

      // F9: STC
      249 => CF = bitone,

      // FA: CLI
      250 => IF_flag = bitzero,

      // FB: STI
      251 => IF_flag = bitone,

      // FC: CLD
      252 => DF = bitzero,

      // FD: STD
      253 => DF = bitone,

      // FE: Group 4 — INC/DEC r/m8
      254 => {
        let modrm = fetch_byte();
        let reg_field : range(0, 7) = unsigned(modrm[5..3]);
        let rm = decode_rm(modrm, pfx);
        // LOCK valid only for INC (/0) and DEC (/1) with memory
        if pfx.has_lock & reg_field >= 2 then raise_UD();
        check_lock_rm(pfx, rm, false);
        if reg_field == 0 then {
          let v = read_rm_val(rm, OS8, pfx.has_rex);
          let result = exec_inc(v, OS8);
          write_rm_val(rm, OS8, pfx.has_rex, result)
        } else if reg_field == 1 then {
          let v = read_rm_val(rm, OS8, pfx.has_rex);
          let result = exec_dec(v, OS8);
          write_rm_val(rm, OS8, pfx.has_rex, result)
        } else {
          raise_UD()
        }
      },

      // FF: Group 5 — INC/DEC/CALL/JMP/PUSH r/m
      255 => {
        let modrm = fetch_byte();
        let reg_field : range(0, 7) = unsigned(modrm[5..3]);
        let rm = decode_rm(modrm, pfx);
        // LOCK valid only for INC (/0) and DEC (/1) with memory
        if pfx.has_lock & reg_field >= 2 then raise_UD();
        check_lock_rm(pfx, rm, false);
        dispatch_group5(reg_field, rm, pfx)
      },

      // 40-47: INC r32/r16 (compat/protected mode only; REX prefix in 64-bit)
      op if 64 <= op & op <= 71 => {
        let reg_field : range(0, 7) = op - 64;
        let reg = extend_reg(reg_field, bitzero);
        let os = get_operand_size(pfx);
        let v = read_gpr(reg, os);
        let result = exec_inc(v, os);
        write_gpr(reg, os, result)
      },

      // 48-4F: DEC r32/r16 (compat/protected mode only; REX prefix in 64-bit)
      op if 72 <= op & op <= 79 => {
        let reg_field : range(0, 7) = op - 72;
        let reg = extend_reg(reg_field, bitzero);
        let os = get_operand_size(pfx);
        let v = read_gpr(reg, os);
        let result = exec_dec(v, os);
        write_gpr(reg, os, result)
      },

      // 50-57: PUSH reg (d64)
      op if 80 <= op & op <= 87 => {
        let reg_field : range(0, 7) = op - 80;
        let reg = extend_reg(reg_field, pfx.rex_b);
        let os = get_operand_size_d64(pfx);
        match os {
          OS8 => (),
          OS16 => push16(read_gpr16(reg)),
          OS32 => if cur_mode == LongMode then push64(zero_extend(read_gpr32(reg)))
                  else push32(read_gpr32(reg)),
          OS64 => push64(read_gpr64(reg)),
        }
      },

      // 58-5F: POP reg (d64)
      op if 88 <= op & op <= 95 => {
        let reg_field : range(0, 7) = op - 88;
        let reg = extend_reg(reg_field, pfx.rex_b);
        let os = get_operand_size_d64(pfx);
        exec_pop_reg(reg, os)
      },

      // 70-7F: Jcc rel8 (f64)
      op if 112 <= op & op <= 127 => {
        let cc : cc_idx = op - 112;
        let offset = fetch_rel8();
        if eval_cc(cc) == bitone then {
          let os = get_operand_size_f64(pfx);
          next_rip = Some(truncate_rip(decode_pos + offset, os));
        }
      },

      // 91-97: XCHG rAX, r
      op if 145 <= op & op <= 151 => {
        let reg_field : range(0, 7) = op - 144;
        let reg = extend_reg(reg_field, pfx.rex_b);
        let os = get_operand_size(pfx);
        exec_xchg_reg_reg(RAX, reg, os)
      },

      // B0-B7: MOV r8, imm8
      op if 176 <= op & op <= 183 => {
        let reg_field : range(0, 7) = op - 176;
        let reg = extend_reg(reg_field, pfx.rex_b);
        let imm = fetch_byte();
        write_byte_reg(reg, pfx.has_rex, imm)
      },

      // B8-BF: MOV r, imm (Iv)
      op if 184 <= op & op <= 191 => {
        let reg_field : range(0, 7) = op - 184;
        let reg = extend_reg(reg_field, pfx.rex_b);
        let os = get_operand_size(pfx);
        let imm = fetch_imm_v(os);
        write_gpr(reg, os, imm)
      },

      // C4: LES r, m16:16/32 (non-64-bit) or 3-byte VEX prefix
      // SDM Vol.2A §2.3.5: In non-64-bit mode, if the second byte has
      // bit 7 set (mod=11 in ModRM terms), it is a VEX prefix, not LES.
      // This works because LES requires a memory operand (mod≠11),
      // so mod=11 is an otherwise-invalid encoding reused for VEX.
      196 => {
        if cur_mode == LongMode then dispatch_vex(0xC4)
        else {
          // Peek at second byte to distinguish VEX from LES.
          // SDM Vol.2A §2.3.5: VEX requires mod=11 (bits 7:6 both set).
          // mod≠11 (memory operand) is a valid LES encoding.
          let byte2 = fetch_byte();
          if byte2[7..6] == 0b11 then {
            // mod=11: VEX prefix in non-64-bit mode
            dispatch_vex_with_byte2(0xC4, byte2)
          } else {
            // mod≠11: LES r, m16:16/32
            let os = get_operand_size(pfx);
            let reg = modrm_reg(byte2, pfx);
            let rm = decode_rm(byte2, pfx);
            match rm {
              RM_mem(seg, ea) => {
                let far_offset : qword = match os {
                  OS16 => zero_extend(seg_read16(seg, ea)),
                  _    => zero_extend(seg_read32(seg, ea)),
                };
                let sel_off : int = match os { OS16 => 2, _ => 4 };
                let selector : word = seg_read16(seg, ea + to_bits_truncate(sel_off));
                write_gpr(reg, os, far_offset);
                load_segment_register(ES, selector)
              },
              RM_reg(_) => raise_UD(),  // unreachable: mod=11 handled above
            }
          }
        }
      },

      // C5: LDS r, m16:16/32 (non-64-bit) or 2-byte VEX prefix
      // Same VEX/LDS distinction as C4/LES above.
      197 => {
        if cur_mode == LongMode then dispatch_vex(0xC5)
        else {
          let byte2 = fetch_byte();
          if byte2[7..6] == 0b11 then {
            dispatch_vex_with_byte2(0xC5, byte2)
          } else {
            let os = get_operand_size(pfx);
            let reg = modrm_reg(byte2, pfx);
            let rm = decode_rm(byte2, pfx);
            match rm {
              RM_mem(seg, ea) => {
                let far_offset : qword = match os {
                  OS16 => zero_extend(seg_read16(seg, ea)),
                  _    => zero_extend(seg_read32(seg, ea)),
                };
                let sel_off : int = match os { OS16 => 2, _ => 4 };
                let selector : word = seg_read16(seg, ea + to_bits_truncate(sel_off));
                write_gpr(reg, os, far_offset);
                load_segment_register(DS, selector)
              },
              RM_reg(_) => raise_UD(),
            }
          }
        }
      },

      // Unhandled opcode
      _ => raise_UD(),
    }
  }
}

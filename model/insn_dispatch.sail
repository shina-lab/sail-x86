// x86-64 Decoder — Opcode Dispatch
//
// Central dispatch for 1-byte, 2-byte (0F xx), and 3-byte (0F 38/3A xx)
// opcode maps. Routes to category-specific handlers.

val __software_interrupt : byte -> ExecutionResult

// XCHG — Exchange Register/Memory with Register

val exec_xchg_reg_reg : (gpr_idx, gpr_idx, OperandSize) -> ExecutionResult
function exec_xchg_reg_reg(a, b, os) = {
  let va : qword = read_gpr(a, os);
  let vb : qword = read_gpr(b, os);
  write_gpr(a, os, vb);
  write_gpr(b, os, va);
  Ok()
}

// IN — Input from Port

val __port_in8  : word -> byte
val __port_in16 : word -> word
val __port_in32 : word -> dword

val exec_in : (word, OperandSize) -> ExecutionResult
function exec_in(port, os) = {
  match os {
    OS8  => write_gpr8l(RAX, __port_in8(port)),
    OS16 => write_gpr16(RAX, __port_in16(port)),
    OS32 => write_gpr32(RAX, __port_in32(port)),
    OS64 => (),
  };
  Ok()
}

// OUT — Output to Port

val __port_out8  : (word, byte)  -> unit
val __port_out16 : (word, word) -> unit
val __port_out32 : (word, dword) -> unit

val exec_out : (word, OperandSize) -> ExecutionResult
function exec_out(port, os) = {
  match os {
    OS8  => __port_out8(port, read_gpr8l(RAX)),
    OS16 => __port_out16(port, read_gpr16(RAX)),
    OS32 => __port_out32(port, read_gpr32(RAX)),
    OS64 => (),
  };
  Ok()
}

// JMP near relative: RIP := decode_pos + sign-extended offset

// POP — Pop a Value from the Stack

val exec_pop_reg : (gpr_idx, OperandSize) -> ExecutionResult
function exec_pop_reg(dst, os) = {
  match os {
    OS64 => write_gpr64(dst, pop64()),
    OS32 => write_gpr32(dst, pop64()[31..0]),
    OS16 => write_gpr16(dst, pop16()),
    _ => (),
  };
  Ok()
}

// LOOP/LOOPcc — Loop According to ECX Counter

enum LoopVariant = { LOOP_always, LOOP_e, LOOP_ne }

val exec_loop : (byte, LoopVariant, AddressSize) -> ExecutionResult
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
    next_rip = Some(decode_pos + sign_extend(rel8));
  };
  Ok()
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
val dispatch_alu_opcode : (range(0, 63), Prefixes) -> ExecutionResult
function dispatch_alu_opcode(op, pfx) = {
  let alu_op = opcode_to_alu(op);
  let col : range(0, 7) = op % 8;
  match col {
    0 => {
      // OP r/m8, r8
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      exec_alu_rm_reg_byte(alu_op, rm, reg, pfx)
    },
    1 => {
      // OP r/m, r (word/dword/qword)
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      exec_alu_rm_reg(alu_op, rm, reg, os, pfx)
    },
    2 => {
      // OP r8, r/m8
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      exec_alu_reg_rm_byte(alu_op, reg, rm, pfx)
    },
    3 => {
      // OP r, r/m (word/dword/qword)
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      exec_alu_reg_rm(alu_op, reg, rm, os, pfx)
    },
    4 => {
      // OP AL, imm8
      let imm : qword = zero_extend(fetch_byte());
      exec_alu_acc_imm(alu_op, imm, OS8, pfx)
    },
    5 => {
      // OP rAX, imm (Iz: 16 or 32 bit, sign-extended)
      let os = get_operand_size(pfx);
      let imm = fetch_imm_z(os);
      exec_alu_acc_imm(alu_op, imm, os, pfx)
    },
    _ => raise_UD(),  // unreachable
  }
}

// =========================================================================
// String Operations (MOVS, STOS, LODS, SCAS, CMPS, REP)
// =========================================================================

val exec_movs : (OperandSize, AddressSize) -> ExecutionResult
function exec_movs(os, asz) = {
  let src_addr : qword = read_index_src(asz);
  let dst_addr : qword = read_index_dst(asz);
  match os {
    OS8  => mem_write8(dst_addr, mem_read8(src_addr)),
    OS16 => mem_write16(dst_addr, mem_read16(src_addr)),
    OS32 => mem_write32(dst_addr, mem_read32(src_addr)),
    OS64 => mem_write64(dst_addr, mem_read64(src_addr)),
  };
  let delta : qword = match os {
    OS8  => 0x0000000000000001,
    OS16 => 0x0000000000000002,
    OS32 => 0x0000000000000004,
    OS64 => 0x0000000000000008,
  };
  if DF == bitzero then {
    write_index_src(asz, src_addr + delta);
    write_index_dst(asz, dst_addr + delta);
  } else {
    write_index_src(asz, src_addr - delta);
    write_index_dst(asz, dst_addr - delta);
  };
  Ok()
}

val exec_stos : (OperandSize, AddressSize) -> ExecutionResult
function exec_stos(os, asz) = {
  let addr : qword = read_index_dst(asz);
  match os {
    OS8  => mem_write8(addr, read_gpr8l(RAX)),
    OS16 => mem_write16(addr, read_gpr16(RAX)),
    OS32 => mem_write32(addr, read_gpr32(RAX)),
    OS64 => mem_write64(addr, read_gpr64(RAX)),
  };
  let delta : qword = match os {
    OS8  => 0x0000000000000001,
    OS16 => 0x0000000000000002,
    OS32 => 0x0000000000000004,
    OS64 => 0x0000000000000008,
  };
  if DF == bitzero then
    write_index_dst(asz, addr + delta)
  else
    write_index_dst(asz, addr - delta);
  Ok()
}

val exec_lods : (OperandSize, AddressSize) -> ExecutionResult
function exec_lods(os, asz) = {
  let addr : qword = read_index_src(asz);
  match os {
    OS8  => write_gpr8l(RAX, mem_read8(addr)),
    OS16 => write_gpr16(RAX, mem_read16(addr)),
    OS32 => write_gpr32(RAX, mem_read32(addr)),
    OS64 => write_gpr64(RAX, mem_read64(addr)),
  };
  let delta : qword = match os {
    OS8  => 0x0000000000000001,
    OS16 => 0x0000000000000002,
    OS32 => 0x0000000000000004,
    OS64 => 0x0000000000000008,
  };
  if DF == bitzero then
    write_index_src(asz, addr + delta)
  else
    write_index_src(asz, addr - delta);
  Ok()
}

val exec_scas : (OperandSize, AddressSize) -> ExecutionResult
function exec_scas(os, asz) = {
  let addr : qword = read_index_dst(asz);
  match os {
    OS8 => {
      let a : byte = read_gpr8l(RAX);
      let b : byte = mem_read8(addr);
      update_flags_sub(a - b, a, b);
    },
    OS16 => {
      let a : word = read_gpr16(RAX);
      let b : word = mem_read16(addr);
      update_flags_sub(a - b, a, b);
    },
    OS32 => {
      let a : dword = read_gpr32(RAX);
      let b : dword = mem_read32(addr);
      update_flags_sub(a - b, a, b);
    },
    OS64 => {
      let a : qword = read_gpr64(RAX);
      let b : qword = mem_read64(addr);
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
    write_index_dst(asz, addr + delta)
  else
    write_index_dst(asz, addr - delta);
  Ok()
}

val exec_cmps : (OperandSize, AddressSize) -> ExecutionResult
function exec_cmps(os, asz) = {
  let src_addr : qword = read_index_src(asz);
  let dst_addr : qword = read_index_dst(asz);
  match os {
    OS8 => {
      let a : byte = mem_read8(src_addr);
      let b : byte = mem_read8(dst_addr);
      update_flags_sub(a - b, a, b);
    },
    OS16 => {
      let a : word = mem_read16(src_addr);
      let b : word = mem_read16(dst_addr);
      update_flags_sub(a - b, a, b);
    },
    OS32 => {
      let a : dword = mem_read32(src_addr);
      let b : dword = mem_read32(dst_addr);
      update_flags_sub(a - b, a, b);
    },
    OS64 => {
      let a : qword = mem_read64(src_addr);
      let b : qword = mem_read64(dst_addr);
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
    write_index_src(asz, src_addr + delta);
    write_index_dst(asz, dst_addr + delta);
  } else {
    write_index_src(asz, src_addr - delta);
    write_index_dst(asz, dst_addr - delta);
  };
  Ok()
}

enum RepPrefix = { REP_none, REP_rep, REP_repe, REP_repne }

enum StringOp = { STR_movs, STR_stos, STR_lods, STR_cmps, STR_scas }

val exec_rep : (RepPrefix, StringOp, OperandSize, AddressSize) -> ExecutionResult
function exec_rep(prefix, op, os, asz) = {
  var done : bool = false;
  while ~(done) do {
    if read_count_reg(asz) == zeros() then
      done = true
    else {
      match op {
        STR_movs => { let _ = exec_movs(os, asz); () },
        STR_stos => { let _ = exec_stos(os, asz); () },
        STR_lods => { let _ = exec_lods(os, asz); () },
        STR_cmps => { let _ = exec_cmps(os, asz); () },
        STR_scas => { let _ = exec_scas(os, asz); () },
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
  };
  Ok()
}

// =========================================================================
// 2-Byte Opcode Map (0F xx) Dispatch
// =========================================================================

val dispatch_opcode_2byte : (byte, Prefixes) -> ExecutionResult
function dispatch_opcode_2byte(opcode, pfx) = {
  let op : range(0, 255) = unsigned(opcode);
  match op {
    // 0F 38: 3-byte escape (SSSE3/SSE4/AES-NI)
    56 => {
      let opcode3 = fetch_byte();
      let op3 : range(0, 255) = unsigned(opcode3);
      if op3 == 246 then {
        // ADCX (66) / ADOX (F3)
        // The 66/F3 prefix is a mandatory prefix, NOT an operand size override.
        // Operand size is determined by REX.W only: W=1 → 64-bit, else 32-bit.
        let mp = get_mandatory_prefix(pfx);
        let os : OperandSize = if pfx.rex_w then OS64 else OS32;
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
        } else {
          raise_UD()
        }
      } else if op3 == 20 then {
        dispatch_3byte_38_sse_fp(opcode3, pfx)    // BLENDVPS
      } else if op3 == 21 then {
        dispatch_3byte_38_sse_fp(opcode3, pfx)    // BLENDVPD
      } else if (op3 == 240 | op3 == 241) then {
        // CRC32 (F2 0F 38 F0/F1)
        let mp = get_mandatory_prefix(pfx);
        if mp != MP_F2 then {
          raise_UD()
        } else {
          let modrm = fetch_byte();
          let reg = modrm_reg(modrm, pfx);
          let rm = decode_rm(modrm, pfx);
          let crc : bits(32) = read_gpr(reg, OS32)[31..0];
          if op3 == 240 then {
            // CRC32 r32/r64, r/m8
            let src : byte = match rm {
              RM_reg(_) => read_rm_val(rm, OS8, pfx.has_rex)[7..0],
              RM_mem(addr) => mem_read8(addr),
            };
            let result : bits(32) = crc32c_byte(crc, src);
            if pfx.rex_w then {
              write_gpr(reg, OS64, zero_extend(result))
            } else {
              write_gpr(reg, OS32, zero_extend(result))
            };
            Ok()
          } else {
            // CRC32 r32/r64, r/m16/r/m32/r/m64
            let os = get_operand_size(pfx);
            let result : bits(32) = match os {
              OS16 => {
                let src : bits(16) = match rm {
                  RM_reg(_) => read_rm_val(rm, OS16, pfx.has_rex)[15..0],
                  RM_mem(addr) => mem_read16(addr),
                };
                crc32c_16(crc, src)
              },
              OS64 => {
                let src : bits(64) = match rm {
                  RM_reg(_) => read_rm_val(rm, OS64, pfx.has_rex),
                  RM_mem(addr) => mem_read64(addr),
                };
                crc32c_64(crc, src)
              },
              _ => {
                let src : bits(32) = match rm {
                  RM_reg(_) => read_rm_val(rm, OS32, pfx.has_rex)[31..0],
                  RM_mem(addr) => mem_read32(addr),
                };
                crc32c_32(crc, src)
              },
            };
            if pfx.rex_w then {
              write_gpr(reg, OS64, zero_extend(result))
            } else {
              write_gpr(reg, OS32, zero_extend(result))
            };
            Ok()
          }
        }
      } else {
        dispatch_3byte_38_sse_int(opcode3, pfx)
      }
    },
    // 0F 3A: 3-byte escape (SSE4/AES-NI with imm8)
    58 => {
      let opcode3 = fetch_byte();
      let op3 : range(0, 255) = unsigned(opcode3);
      if op3 == 8 then dispatch_3byte_3a_sse_fp(opcode3, pfx)       // ROUNDPS
      else if op3 == 9 then dispatch_3byte_3a_sse_fp(opcode3, pfx)  // ROUNDPD
      else if op3 == 10 then dispatch_3byte_3a_sse_fp(opcode3, pfx) // ROUNDSS
      else if op3 == 11 then dispatch_3byte_3a_sse_fp(opcode3, pfx) // ROUNDSD
      else if op3 == 12 then dispatch_3byte_3a_sse_fp(opcode3, pfx) // BLENDPS
      else if op3 == 13 then dispatch_3byte_3a_sse_fp(opcode3, pfx) // BLENDPD
      else if op3 == 23 then dispatch_3byte_3a_sse_fp(opcode3, pfx) // EXTRACTPS
      else if op3 == 33 then dispatch_3byte_3a_sse_fp(opcode3, pfx) // INSERTPS
      else if op3 == 64 then dispatch_3byte_3a_sse_fp(opcode3, pfx) // DPPS
      else if op3 == 65 then dispatch_3byte_3a_sse_fp(opcode3, pfx) // DPPD
      else dispatch_3byte_3a_sse_int(opcode3, pfx)
    },

    // SSE floating-point (data movement, arithmetic, conversion, comparison)
    op if 16 <= op & op <= 23 => dispatch_2byte_sse_fp(op, pfx),
    op if 40 <= op & op <= 47 => dispatch_2byte_sse_fp(op, pfx),
    op if 80 <= op & op <= 95 => dispatch_2byte_sse_fp(op, pfx),
    124 => dispatch_2byte_sse_fp(op, pfx),
    125 => dispatch_2byte_sse_fp(op, pfx),
    194 => dispatch_2byte_sse_fp(op, pfx),
    198 => dispatch_2byte_sse_fp(op, pfx),
    208 => dispatch_2byte_sse_fp(op, pfx),
    214 => dispatch_2byte_sse_fp(op, pfx),
    230 => dispatch_2byte_sse_fp(op, pfx),

    // SSE integer (packed integer arithmetic, logical, shift, pack/unpack)
    op if 96 <= op & op <= 118 => dispatch_2byte_sse_int(op, pfx),
    126 => dispatch_2byte_sse_int(op, pfx),
    127 => dispatch_2byte_sse_int(op, pfx),
    196 => dispatch_2byte_sse_int(op, pfx),
    197 => dispatch_2byte_sse_int(op, pfx),
    op if 209 <= op & op <= 213 => dispatch_2byte_sse_int(op, pfx),
    op if 215 <= op & op <= 229 => dispatch_2byte_sse_int(op, pfx),
    op if 231 <= op & op <= 255 => dispatch_2byte_sse_int(op, pfx),

    // GPR and system operations (everything else)
    _ => dispatch_2byte_gpr(op, pfx),
  }
}

// =========================================================================
// 1-Byte Opcode Map Dispatch
// =========================================================================

val dispatch_opcode_1byte : (byte, Prefixes) -> ExecutionResult
function dispatch_opcode_1byte(opcode, pfx) = {
  let op : range(0, 255) = unsigned(opcode);

  // ALU instructions 00-3F (regular pattern, columns 0-5 only)
  if op <= 63 & op % 8 <= 5 then dispatch_alu_opcode(op, pfx)
  else match op {

    // 0F: Two-byte escape
    15 => {
      let opcode2 = fetch_byte();
      dispatch_opcode_2byte(opcode2, pfx)
    },

    // 62: EVEX prefix (in 64-bit mode; BOUND in 32-bit mode)
    98 => dispatch_evex(),

    // 63: MOVSXD r64, r/m32 (in 64-bit mode)
    99 => {
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.rex_w then {
        let src = read_rm_val(rm, OS32, pfx.has_rex);
        write_gpr64(reg, sign_extend(src[31..0]));
        Ok()
      } else {
        let os = get_operand_size(pfx);
        let src = read_rm_val(rm, os, pfx.has_rex);
        write_gpr(reg, os, src);
        Ok()
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
      let truncated : bool = match os {
        OS8  => product != signed(result[7..0]),
        OS16 => product != signed(result[15..0]),
        OS32 => product != signed(result[31..0]),
        OS64 => product != signed(result),
      };
      CF = bool_to_bit(truncated);
      OF = CF;
      write_gpr(reg, os, result);
      Ok()
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
      let truncated : bool = match os {
        OS8  => product != signed(result[7..0]),
        OS16 => product != signed(result[15..0]),
        OS32 => product != signed(result[31..0]),
        OS64 => product != signed(result),
      };
      CF = bool_to_bit(truncated);
      OF = CF;
      write_gpr(reg, os, result);
      Ok()
    },

    // 80: Group 1 — ALU r/m8, imm8
    128 => {
      let modrm = fetch_byte();
      let rm = decode_rm(modrm, pfx);
      let reg_field : range(0, 7) = unsigned(modrm[5..3]);
      let imm : qword = zero_extend(fetch_byte());
      let alu_op = group1_op(reg_field);
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
      update_flags_logic(result[7..0]);
      Ok()
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
      };
      Ok()
    },

    // 86: XCHG r/m8, r8
    134 => {
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let a = read_rm_val(rm, OS8, pfx.has_rex);
      let b : qword = zero_extend(read_byte_reg(reg, pfx.has_rex));
      write_rm_val(rm, OS8, pfx.has_rex, b);
      write_byte_reg(reg, pfx.has_rex, a[7..0]);
      Ok()
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
      write_gpr(reg, os, a);
      Ok()
    },

    // 88: MOV r/m8, r8
    136 => {
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v : qword = zero_extend(read_byte_reg(reg, pfx.has_rex));
      write_rm_val(rm, OS8, pfx.has_rex, v);
      Ok()
    },

    // 89: MOV r/m, r
    137 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      write_rm_val(rm, os, pfx.has_rex, read_gpr(reg, os));
      Ok()
    },

    // 8A: MOV r8, r/m8
    138 => {
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = read_rm_val(rm, OS8, pfx.has_rex);
      write_byte_reg(reg, pfx.has_rex, v[7..0]);
      Ok()
    },

    // 8B: MOV r, r/m
    139 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      write_gpr(reg, os, read_rm_val(rm, os, pfx.has_rex));
      Ok()
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
            write_gpr(idx, os, zero_extend(read_segreg(seg)));
            Ok()
          },
          RM_mem(addr) => { mem_write16(addr, read_segreg(seg)); Ok() },
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
          RM_mem(addr) => mem_read16(addr),
        };
        if seg == CS then {
          raise_UD()
        } else {
          write_segreg(seg, v); Ok()
        }
      }
    },

    // 8D: LEA r, m
    141 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      match rm {
        RM_mem(addr) => { write_gpr(reg, os, addr); Ok() },
        RM_reg(_) => raise_UD(),
      }
    },

    // 8F /0: POP r/m (d64)
    143 => {
      let modrm = fetch_byte();
      let reg_field : range(0, 7) = unsigned(modrm[5..3]);
      if reg_field == 0 then {
        let rm = decode_rm(modrm, pfx);
        let os = get_operand_size_d64(pfx);
        match rm {
          RM_reg(idx) => exec_pop_reg(idx, os),
          RM_mem(addr) => {
            match os {
              OS64 => mem_write64(addr, pop64()),
              OS16 => mem_write16(addr, pop16()),
              _ => (),
            };
            Ok()
          },
        }
      } else {
        raise_UD()
      }
    },

    // 90: NOP / PAUSE (F3 90) / XCHG R8D,EAX (REX.B)
    144 => {
      if pfx.has_rep then {
        Ok()
      } else if pfx.rex_b then {
        let os = get_operand_size(pfx);
        exec_xchg_reg_reg(RAX, R8, os)
      } else {
        Ok()
      }
    },

    // 98: CBW/CWDE/CDQE
    152 => {
      let os = get_operand_size(pfx);
      match os {
        OS16 => { let v : word = sign_extend(read_gpr8l(RAX)); write_gpr16(RAX, v) },
        OS32 => { let v : dword = sign_extend(read_gpr16(RAX)); write_gpr32(RAX, v) },
        OS64 => { let v : qword = sign_extend(read_gpr32(RAX)); write_gpr64(RAX, v) },
        _ => (),
      };
      Ok()
    },

    // 99: CWD/CDQ/CQO
    153 => {
      let os = get_operand_size(pfx);
      match os {
        OS16 => {
          if read_gpr16(RAX)[15] == bitone then write_gpr16(RDX, 0xFFFF)
          else write_gpr16(RDX, 0x0000)
        },
        OS32 => {
          if read_gpr32(RAX)[31] == bitone then write_gpr32(RDX, 0xFFFFFFFF)
          else write_gpr32(RDX, 0x00000000)
        },
        OS64 => {
          if read_gpr64(RAX)[63] == bitone then write_gpr64(RDX, ones())
          else write_gpr64(RDX, zeros())
        },
        _ => (),
      };
      Ok()
    },

    // 9B: FWAIT/WAIT
    155 => __wait(),

    // 9C: PUSHF (d64)
    156 => {
      let os = get_operand_size_d64(pfx);
      let flags = read_rflags();
      exec_push_imm(flags, os)
    },

    // 9D: POPF (d64)
    157 => {
      let os = get_operand_size_d64(pfx);
      match os {
        OS16 => {
          let v : word = pop16();
          CF = v[0]; PF = v[2]; AF = v[4]; ZF = v[6]; SF = v[7];
          TF = v[8]; IF_flag = v[9]; DF = v[10]; OF = v[11];
        },
        OS64 => {
          let v : qword = pop64();
          CF = v[0]; PF = v[2]; AF = v[4]; ZF = v[6]; SF = v[7];
          TF = v[8]; IF_flag = v[9]; DF = v[10]; OF = v[11];
          IOPL = v[13..12];
        },
        _ => (),
      };
      Ok()
    },

    // 9E: SAHF
    158 => {
      let ah : byte = read_gpr8h(RAX);
      CF = ah[0]; PF = ah[2]; AF = ah[4]; ZF = ah[6]; SF = ah[7];
      Ok()
    },

    // 9F: LAHF
    159 => {
      let v : byte = CF @ bitone @ PF @ bitzero @ AF @ bitzero @ ZF @ SF;
      write_gpr8h(RAX, v);
      Ok()
    },

    // A0: MOV AL, moffs8
    160 => { let addr = fetch_moffs(pfx); write_gpr8l(RAX, mem_read8(addr)); Ok() },

    // A1: MOV rAX, moffs
    161 => {
      let os = get_operand_size(pfx);
      let addr = fetch_moffs(pfx);
      let v : qword = match os {
        OS8  => zero_extend(mem_read8(addr)),
        OS16 => zero_extend(mem_read16(addr)),
        OS32 => zero_extend(mem_read32(addr)),
        OS64 => mem_read64(addr),
      };
      write_gpr(RAX, os, v);
      Ok()
    },

    // A2: MOV moffs8, AL
    162 => { let addr = fetch_moffs(pfx); mem_write8(addr, read_gpr8l(RAX)); Ok() },

    // A3: MOV moffs, rAX
    163 => {
      let os = get_operand_size(pfx);
      let addr = fetch_moffs(pfx);
      let v = read_gpr(RAX, os);
      match os {
        OS8  => mem_write8(addr, v[7..0]),
        OS16 => mem_write16(addr, v[15..0]),
        OS32 => mem_write32(addr, v[31..0]),
        OS64 => mem_write64(addr, v),
      };
      Ok()
    },

    // A4: MOVSB
    164 => {
      let asz = get_address_size(pfx);
      if pfx.has_rep then exec_rep(REP_rep, STR_movs, OS8, asz)
      else exec_movs(OS8, asz)
    },

    // A5: MOVSW/MOVSD/MOVSQ
    165 => {
      let os = get_operand_size(pfx);
      let asz = get_address_size(pfx);
      if pfx.has_rep then exec_rep(REP_rep, STR_movs, os, asz)
      else exec_movs(os, asz)
    },

    // A6: CMPSB
    166 => {
      let asz = get_address_size(pfx);
      if pfx.has_rep then exec_rep(REP_repe, STR_cmps, OS8, asz)
      else if pfx.has_repne then exec_rep(REP_repne, STR_cmps, OS8, asz)
      else exec_cmps(OS8, asz)
    },

    // A7: CMPSW/CMPSD/CMPSQ
    167 => {
      let os = get_operand_size(pfx);
      let asz = get_address_size(pfx);
      if pfx.has_rep then exec_rep(REP_repe, STR_cmps, os, asz)
      else if pfx.has_repne then exec_rep(REP_repne, STR_cmps, os, asz)
      else exec_cmps(os, asz)
    },

    // A8: TEST AL, imm8
    168 => {
      let imm : qword = zero_extend(fetch_byte());
      let a : qword = zero_extend(read_gpr8l(RAX));
      let result = a & imm;
      update_flags_logic(result[7..0]);
      Ok()
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
      };
      Ok()
    },

    // AA: STOSB
    170 => {
      let asz = get_address_size(pfx);
      if pfx.has_rep then exec_rep(REP_rep, STR_stos, OS8, asz)
      else exec_stos(OS8, asz)
    },

    // AB: STOSW/STOSD/STOSQ
    171 => {
      let os = get_operand_size(pfx);
      let asz = get_address_size(pfx);
      if pfx.has_rep then exec_rep(REP_rep, STR_stos, os, asz)
      else exec_stos(os, asz)
    },

    // AC: LODSB
    172 => {
      let asz = get_address_size(pfx);
      if pfx.has_rep then exec_rep(REP_rep, STR_lods, OS8, asz)
      else exec_lods(OS8, asz)
    },

    // AD: LODSW/LODSD/LODSQ
    173 => {
      let os = get_operand_size(pfx);
      let asz = get_address_size(pfx);
      if pfx.has_rep then exec_rep(REP_rep, STR_lods, os, asz)
      else exec_lods(os, asz)
    },

    // AE: SCASB
    174 => {
      let asz = get_address_size(pfx);
      if pfx.has_rep then exec_rep(REP_repe, STR_scas, OS8, asz)
      else if pfx.has_repne then exec_rep(REP_repne, STR_scas, OS8, asz)
      else exec_scas(OS8, asz)
    },

    // AF: SCASW/SCASD/SCASQ
    175 => {
      let os = get_operand_size(pfx);
      let asz = get_address_size(pfx);
      if pfx.has_rep then exec_rep(REP_repe, STR_scas, os, asz)
      else if pfx.has_repne then exec_rep(REP_repne, STR_scas, os, asz)
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
    194 => {
      let imm = fetch_imm16();
      let os = get_operand_size_d64(pfx);
      let target : qword = match os {
        OS64 => pop64(),
        OS32 => zero_extend(pop64()[31..0]),
        OS16 => zero_extend(pop16()),
        OS8 => zeros(),
      };
      next_rip = Some(target);
      GPR[RSP] = GPR[RSP] + zero_extend(imm);
      Ok()
    },

    // C3: RET near
    195 => {
      let os = get_operand_size_d64(pfx);
      let target : qword = match os {
        OS64 => pop64(),
        OS32 => zero_extend(pop64()[31..0]),
        OS16 => zero_extend(pop16()),
        OS8 => zeros(),
      };
      next_rip = Some(target);
      Ok()
    },

    // C6 /0: MOV r/m8, imm8
    198 => {
      let modrm = fetch_byte();
      let reg_field : range(0, 7) = unsigned(modrm[5..3]);
      if reg_field == 0 then {
        let rm = decode_rm(modrm, pfx);
        let imm : qword = zero_extend(fetch_byte());
        write_rm_val(rm, OS8, pfx.has_rex, imm);
        Ok()
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
        write_rm_val(rm, os, pfx.has_rex, imm);
        Ok()
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
      };
      Ok()
    },

    // C9: LEAVE
    201 => {
      let os = get_operand_size_d64(pfx);
      match os {
        OS64 => {
          write_gpr64(RSP, read_gpr64(RBP));
          write_gpr64(RBP, pop64());
        },
        OS32 => {
          write_gpr64(RSP, zero_extend(read_gpr32(RBP)));
          let v : qword = pop64();
          write_gpr32(RBP, v[31..0]);
        },
        OS16 => {
          write_gpr16(RSP, read_gpr16(RBP));
          write_gpr16(RBP, pop16());
        },
        _ => (),
      };
      Ok()
    },

    // CC: INT 3
    204 => __software_interrupt(0x03),

    // CD: INT imm8
    205 => {
      let imm = fetch_byte();
      __software_interrupt(imm)
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

    // D7: XLAT/XLATB
    215 => {
      let asz = get_address_size(pfx);
      let al : qword = zero_extend(read_gpr8l(RAX));
      let addr : qword = match asz {
        AS64 => read_gpr64(RBX) + al,
        AS32 => zero_extend(read_gpr32(RBX)) + al,
        AS16 => zero_extend(read_gpr16(RBX)) + al,
      };
      write_gpr8l(RAX, mem_read8(addr));
      Ok()
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

    // E3: JRCXZ rel8
    227 => {
      let rel = fetch_rel8();
      let asz = get_address_size(pfx);
      let count_reg : qword = if asz == AS32 then zero_extend(read_gpr32(RCX)) else read_gpr64(RCX);
      if count_reg == zeros() then {
        let target = decode_pos + rel;
        next_rip = Some(target);
        Ok()
      } else {
        Ok()
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

    // E8: CALL rel32 (f64)
    232 => {
      let offset = fetch_rel32();
      let os = get_operand_size_f64(pfx);
      let return_addr = decode_pos;
      match os {
        OS64 => push64(return_addr),
        OS32 => push64(zero_extend(return_addr[31..0])),
        OS16 => push16(return_addr[15..0]),
        _ => (),
      };
      next_rip = Some(return_addr + offset);
      Ok()
    },

    // E9: JMP rel32 (f64)
    233 => {
      next_rip = Some(decode_pos + fetch_rel32());
      Ok()
    },

    // EB: JMP rel8 (f64)
    235 => {
      next_rip = Some(decode_pos + fetch_rel8());
      Ok()
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

    // F4: HLT
    244 => Halt(()),

    // F5: CMC
    245 => { CF = ~(CF); Ok() },

    // F6: Group 3 — unary byte operations
    246 => {
      let modrm = fetch_byte();
      let reg_field : range(0, 7) = unsigned(modrm[5..3]);
      let rm = decode_rm(modrm, pfx);
      dispatch_group3_byte(reg_field, rm, pfx)
    },

    // F7: Group 3 — unary word/dword/qword operations
    247 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg_field : range(0, 7) = unsigned(modrm[5..3]);
      let rm = decode_rm(modrm, pfx);
      dispatch_group3(reg_field, rm, os, pfx)
    },

    // F8: CLC
    248 => { CF = bitzero; Ok() },

    // F9: STC
    249 => { CF = bitone; Ok() },

    // FA: CLI
    250 => { IF_flag = bitzero; Ok() },

    // FB: STI
    251 => { IF_flag = bitone; Ok() },

    // FC: CLD
    252 => { DF = bitzero; Ok() },

    // FD: STD
    253 => { DF = bitone; Ok() },

    // FE: Group 4 — INC/DEC r/m8
    254 => {
      let modrm = fetch_byte();
      let reg_field : range(0, 7) = unsigned(modrm[5..3]);
      let rm = decode_rm(modrm, pfx);
      if reg_field == 0 then {
        let v = read_rm_val(rm, OS8, pfx.has_rex);
        let (res, result) = exec_inc(v, OS8);
        write_rm_val(rm, OS8, pfx.has_rex, result);
        res
      } else if reg_field == 1 then {
        let v = read_rm_val(rm, OS8, pfx.has_rex);
        let (res, result) = exec_dec(v, OS8);
        write_rm_val(rm, OS8, pfx.has_rex, result);
        res
      } else {
        raise_UD()
      }
    },

    // FF: Group 5 — INC/DEC/CALL/JMP/PUSH r/m
    255 => {
      let modrm = fetch_byte();
      let reg_field : range(0, 7) = unsigned(modrm[5..3]);
      let rm = decode_rm(modrm, pfx);
      dispatch_group5(reg_field, rm, pfx)
    },

    // 50-57: PUSH reg (d64)
    op if 80 <= op & op <= 87 => {
      let reg_field : range(0, 7) = op - 80;
      let reg = extend_reg(reg_field, pfx.rex_b);
      let os = get_operand_size_d64(pfx);
      match os {
        OS64 => push64(read_gpr64(reg)),
        OS32 => push64(zero_extend(read_gpr32(reg))),
        OS16 => push16(read_gpr16(reg)),
        _ => (),
      };
      Ok()
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
      if eval_cc(cc) then {
        next_rip = Some(decode_pos + offset);
      };
      Ok()
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
      write_byte_reg(reg, pfx.has_rex, imm);
      Ok()
    },

    // B8-BF: MOV r, imm (Iv)
    op if 184 <= op & op <= 191 => {
      let reg_field : range(0, 7) = op - 184;
      let reg = extend_reg(reg_field, pfx.rex_b);
      let os = get_operand_size(pfx);
      let imm = fetch_imm_v(os);
      write_gpr(reg, os, imm);
      Ok()
    },

    // C4: 3-byte VEX prefix (in 64-bit mode)
    196 => dispatch_vex(0xC4),

    // C5: 2-byte VEX prefix (in 64-bit mode)
    197 => dispatch_vex(0xC5),

    // Unhandled opcode
    _ => raise_UD(),
  }
}

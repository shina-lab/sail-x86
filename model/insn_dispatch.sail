// x86-64 — Opcode Dispatch
//
// Central dispatch for 1-byte, 2-byte (0F xx), and 3-byte (0F 38/3A xx)
// opcode maps. Routes to category-specific handlers.

val __software_interrupt : byte -> unit

// XCHG — Exchange Register/Memory with Register

val exec_xchg_reg_reg : (gpr_idx, gpr_idx, operand_size) -> unit
function exec_xchg_reg_reg(a, b, os) = {
  let temp = v(os, a);
  v(a) = v(os, b);
  v(b) = temp
}

// IN — Input from Port

val __port_in8  : word -> byte
val __port_in16 : word -> word
val __port_in32 : word -> dword

val exec_in : (word, operand_size) -> unit
function exec_in(port, os) = {
  match os {
    8  => v(RAX) = __port_in8(port),
    16 => v(RAX) = __port_in16(port),
    32 => v(RAX) = __port_in32(port),
    64 => v(RAX) = __port_in32(port)
  }
}

// OUT — Output to Port

val __port_out8  : (word, byte)  -> unit
val __port_out16 : (word, word) -> unit
val __port_out32 : (word, dword) -> unit

val exec_out : (word, operand_size) -> unit
function exec_out(port, os) = {
  match os {
    8  => __port_out8(port, v(RAX)),
    16 => __port_out16(port, v(RAX)),
    32 => __port_out32(port, v(RAX)),
    64 => __port_out32(port, v(RAX))
  }
}

// JMP near relative: RIP := decode_pos + sign-extended offset

// POP — Pop a Value from the Stack

val exec_pop_reg : (gpr_idx, {16, 32, 64}) -> unit
function exec_pop_reg(dst, os) = {
  match os {
    16 => v(dst) = pop16(),
    32 => v(dst) = if cur_mode == LongMode then pop64()[31..0] else pop32(),
    64 => v(dst) = pop64(),
  }
}

// LOOP/LOOPcc — Loop According to ECX Counter

enum LoopVariant = { LOOP_always, LOOP_e, LOOP_ne }

val exec_loop : (byte, LoopVariant, address_size) -> unit
function exec_loop(rel8, variant, asz) = {
  v(RCX) = v(asz, RCX) - 1;
  let count_nonzero : bool = v(asz, RCX) != zeros();
  let take_branch : bool = match variant {
    LOOP_always => count_nonzero,
    LOOP_e      => if count_nonzero then ZF == 0b1 else false,
    LOOP_ne     => if count_nonzero then ZF == 0b0 else false,
  };
  if take_branch then {
    let os = if cur_mode == LongMode then 64
             else if get_cs_db() == 0b1 then 32
             else 16;
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
      let (reg, dest) = fetch_modrm(pfx);
      check_lock_rm(pfx, dest, alu_op == ALU_CMP);
      exec_alu_rm_reg_byte(alu_op, dest, reg)
    },
    // OP r/m, r (word/dword/qword)
    1 => {
      let os = get_operand_size(pfx);
      let (reg, dest) = fetch_modrm(pfx);
      check_lock_rm(pfx, dest, alu_op == ALU_CMP);
      exec_alu_rm_reg(alu_op, dest, reg, os)
    },
    // OP r8, r/m8
    2 => {
      let (reg, src) = fetch_modrm(pfx);
      exec_alu_reg_rm_byte(alu_op, reg, src)
    },
    // OP r, r/m (word/dword/qword)
    3 => {
      let os = get_operand_size(pfx);
      let (reg, src) = fetch_modrm(pfx);
      exec_alu_reg_rm(alu_op, reg, src, os)
    },
    // OP AL, imm8
    4 => {
      let imm : byte = fetch_byte();
      exec_alu_acc_imm(alu_op, imm, 8, pfx)
    },
    // OP rAX, imm (Iz: 16 or 32 bit, sign-extended)
    5 => {
      let os = get_operand_size(pfx);
      let imm = fetch_imm_z(os);
      exec_alu_acc_imm(alu_op, imm[(os - 1) .. 0], os, pfx)
    },
    _ => raise_UD(),  // unreachable
  }
}

// =========================================================================
// String Operations (MOVS, STOS, LODS, SCAS, CMPS, INS, OUTS, REP)
// =========================================================================

// INS — Input from port DX to ES:[RDI]
val exec_ins : (operand_size, address_size) -> unit
function exec_ins(os_in, asz) = {
  // SDM: INS only supports 8/16/32-bit I/O; REX.W is ignored.
  let os : {8, 16, 32} = if os_in == 64 then 32 else os_in;
  let port : word = v(RDX);
  let off : qword = zero_extend(v(asz, RDI));
  // INS destination is always ES:DI (not overridable).
  let dst : MemRef = struct { seg = ES, addr = off };
  match os {
    8  => v(dst) = __port_in8(port),
    16 => v(dst) = __port_in16(port),
    32 => v(dst) = __port_in32(port),
  };
  let step = if DF == 0b0 then os / 8 else -(os / 8);
  v(RDI) = (off + step)[asz - 1 .. 0]
}

// OUTS — Output from DS:[RSI] to port DX
// SDM Vol.2B §OUTS: Source is DS:(E)SI, DS segment may be overridden.
val exec_outs : (operand_size, address_size, Prefixes) -> unit
function exec_outs(os_in, asz, pfx) = {
  // SDM: OUTS only supports 8/16/32-bit I/O; REX.W is ignored.
  let os : {8, 16, 32} = if os_in == 64 then 32 else os_in;
  let port : word = v(RDX);
  let off : qword = zero_extend(v(asz, RSI));
  let src_seg : segreg_idx = match pfx.seg_override {
    Some(s) => s,
    None()  => DS,
  };
  let src : MemRef = struct { seg = src_seg, addr = off };
  match os {
    8  => __port_out8(port,  v(src)),
    16 => __port_out16(port, v(src)),
    32 => __port_out32(port, v(src)),
  };
  let step = if DF == 0b0 then os / 8 else -(os / 8);
  v(RSI) = (off + step)[asz - 1 .. 0]
}

val exec_movs : (operand_size, address_size, Prefixes) -> unit
function exec_movs(os, asz, pfx) = {
  let src_off : qword = zero_extend(v(asz, RSI));
  let dst_off : qword = zero_extend(v(asz, RDI));
  // MOVS source is DS:SI (overridable), destination is always ES:DI.
  let src_seg : segreg_idx = match pfx.seg_override {
    Some(s) => s,
    None()  => DS,
  };
  let src : MemRef = struct { seg = src_seg, addr = src_off };
  let dst : MemRef = struct { seg = ES, addr = dst_off };
  v(dst) = v(os, src);
  let step = if DF == 0b0 then os / 8 else -(os / 8);
  v(RSI) = (src_off + step)[asz - 1 .. 0];
  v(RDI) = (dst_off + step)[asz - 1 .. 0];
}

val exec_stos : (operand_size, address_size) -> unit
function exec_stos(os, asz) = {
  let off : qword = zero_extend(v(asz, RDI));
  // STOS destination is always ES:DI (not overridable).
  let dst : MemRef = struct { seg = ES, addr = off };
  v(dst) = v(os, RAX);
  let step = if DF == 0b0 then os / 8 else -(os / 8);
  v(RDI) = (off + step)[asz - 1 .. 0]
}

val exec_lods : (operand_size, address_size, Prefixes) -> unit
function exec_lods(os, asz, pfx) = {
  let off : qword = zero_extend(v(asz, RSI));
  // LODS source is DS:SI (overridable).
  let src_seg : segreg_idx = match pfx.seg_override {
    Some(s) => s,
    None()  => DS,
  };
  let src : MemRef = struct { seg = src_seg, addr = off };
  v(RAX) = v(os, src);
  let step = if DF == 0b0 then os / 8 else -(os / 8);
  v(RSI) = (off + step)[asz - 1 .. 0]
}

val exec_scas : (operand_size, address_size) -> unit
function exec_scas(os, asz) = {
  let off : qword = zero_extend(v(asz, RDI));
  // SCAS destination is always ES:DI (not overridable).
  let dst : MemRef = struct { seg = ES, addr = off };
  let a = v(os, RAX);
  let b = v(os, dst);
  update_flags_sub(a - b, a, b);
  let step = if DF == 0b0 then os / 8 else -(os / 8);
  v(RDI) = (off + step)[asz - 1 .. 0]
}

val exec_cmps : (operand_size, address_size, Prefixes) -> unit
function exec_cmps(os, asz, pfx) = {
  let src_off : qword = zero_extend(v(asz, RSI));
  let dst_off : qword = zero_extend(v(asz, RDI));
  // CMPS source is DS:SI (overridable), destination is ES:DI.
  let src_seg : segreg_idx = match pfx.seg_override {
    Some(s) => s,
    None()  => DS,
  };
  let src : MemRef = struct { seg = src_seg, addr = src_off };
  let dst : MemRef = struct { seg = ES, addr = dst_off };
  let a = v(os, src);
  let b = v(os, dst);
  update_flags_sub(a - b, a, b);
  let step = if DF == 0b0 then os / 8 else -(os / 8);
  v(RSI) = (src_off + step)[asz - 1 .. 0];
  v(RDI) = (dst_off + step)[asz - 1 .. 0]
}

enum RepPrefix = { REP_none, REP_rep, REP_repe, REP_repne }

enum StringOp = { STR_movs, STR_stos, STR_lods, STR_cmps, STR_scas, STR_ins, STR_outs }

val exec_rep : (RepPrefix, StringOp, operand_size, address_size, Prefixes) -> unit
function exec_rep(prefix, op, os, asz, pfx) = {
  while v(asz, RCX) != zeros() do {
    match op {
      STR_movs => exec_movs(os, asz, pfx),
      STR_stos => exec_stos(os, asz),
      STR_lods => exec_lods(os, asz, pfx),
      STR_cmps => exec_cmps(os, asz, pfx),
      STR_scas => exec_scas(os, asz),
      STR_ins  => exec_ins(os, asz),
      STR_outs => exec_outs(os, asz, pfx),
    };
    v(RCX) = v(asz, RCX) - 1;
    if prefix == REP_repe  & ZF == 0b0 then return ();
    if prefix == REP_repne & ZF == 0b1 then return ()
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
  176 => true,  // 0F B0: CMPXCHG
  177 => true,  // 0F B1: CMPXCHG
  179 => true,  // 0F B3: BTR
  186 => true,  // 0F BA: Group 8 (BTS/BTR/BTC imm, not BT)
  187 => true,  // 0F BB: BTC
  192 => true,  // 0F C0: XADD
  193 => true,  // 0F C1: XADD
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
        let os : {32, 64} = if pfx.rex_w then 64 else 32;
        let (reg, src) = fetch_modrm(pfx);
        let src_val = v(os, src);
        if mp == MP_66 then {
          let a = v(os, reg);
          let result = a + src_val + zero_extend(CF);
          let w = (0b0 @ a) + (0b0 @ src_val) + zero_extend(CF);
          CF = w[os];
          v(reg) = result
        } else if mp == MP_F3 then {
          let a = v(os, reg);
          let result = a + src_val + zero_extend(OF);
          let w = (0b0 @ a) + (0b0 @ src_val) + zero_extend(OF);
          OF = w[os];
          v(reg) = result
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
        let (reg, src) = fetch_modrm(pfx);
        let desc : xmmword = rm_mem(src);
        let inv_type : qword = v(reg);
        if unsigned(inv_type) > 3 then raise_GP0();
        let reserved : bits(52) = desc[63..12];
        let top17 : bits(17) = desc[127..111];
        // types 0,1: reserved bits must be zero
        // type 0: linear address must be canonical
        let is_type_01 : bit = ~(inv_type[1]);
        let is_type_0 : bit = ~(inv_type[1] | inv_type[0]);
        let bad_reserved : bit = ~(((0b0 @ reserved) - 1)[52]);
        let diff : bits(17) = top17 ^ sign_extend(top17[16]);
        let non_canonical : bit = ~(((0b0 @ diff) - 1)[17]);
        let fault : bit = (is_type_01 & bad_reserved) | (is_type_0 & non_canonical);
        if fault == 0b1 then raise_GP0();
        __tlb_flush()
      } else if (op3 == 240 | op3 == 241) then {
        // MOVBE (0F 38 F0/F1) or CRC32 (F2 0F 38 F0/F1)
        let mp = get_mandatory_prefix(pfx);
        if mp == MP_F2 then {
          if ~(has_crc32) then raise_UD();
          let (reg, src) = fetch_modrm(pfx);
          let os = if op3 == 240 then 8 else get_operand_size(pfx);
          let src_val = v(os, src);
          let result : bits(32) = crc32c(v(32, reg), src_val);
          if pfx.rex_w then {
            v(reg) = zero_extend(64, result)
          } else {
            v(reg) = result
          }
        } else {
          // MOVBE (0F 38 F0/F1) — load/store with byte swap
          if ~(has_movbe) then raise_UD();
          let os = get_operand_size(pfx);
          let (reg, dest) = fetch_modrm(pfx);
          if op3 == 240 then {
            v(os, reg) = bswap(rm_mem(os, dest))
          } else {
            rm_mem(dest) = bswap(v(os, reg))
          }
        }
      } else if op3 == 249 & get_mandatory_prefix(pfx) == MP_NONE then {
        // MOVDIRI m32/m64, r32/r64 (NP 0F 38 F9)
        if ~(has_movdiri) then raise_UD();
        let (reg, dest) = fetch_modrm(pfx);
        let os = if pfx.rex_w then 64 else 32;
        rm_mem(dest) = v(os, reg)
      } else if op3 == 248 & get_mandatory_prefix(pfx) == MP_66 then {
        // MOVDIR64B r, m512 (66 0F 38 F8)
        if ~(has_movdir64b) then raise_UD();
        let (reg, src) = fetch_modrm(pfx);
        let src_val : zmmword = rm_mem(src);
        let asz = get_address_size(pfx);
        let dst_addr : qword = zero_extend(v(asz, reg));
        if (dst_addr & 0x000000000000003F) != zeros() then raise_GP0();
        write_mem(dst_addr, src_val)
      } else if 200 <= op3 & op3 <= 205 & get_mandatory_prefix(pfx) == MP_NONE then {
        // SHA extensions (NP 0F 38 C8-CD)
        if ~(has_sha) then raise_UD();
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let src = modrm_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, src, pfx);
        match op3 {
          // SHA1NEXTE xmm1, xmm2/m128
          200 => write_xmm_legacy(xreg, __sha1nexte(read_xmm(xreg), src_xmm)),
          // SHA1MSG1 xmm1, xmm2/m128
          201 => write_xmm_legacy(xreg, __sha1msg1(read_xmm(xreg), src_xmm)),
          // SHA1MSG2 xmm1, xmm2/m128
          202 => write_xmm_legacy(xreg, __sha1msg2(read_xmm(xreg), src_xmm)),
          // SHA256RNDS2 xmm1, xmm2/m128, <XMM0>
          203 => write_xmm_legacy(xreg, __sha256rnds2(read_xmm(xreg), src_xmm, read_xmm(0))),
          // SHA256MSG1 xmm1, xmm2/m128
          204 => write_xmm_legacy(xreg, __sha256msg1(read_xmm(xreg), src_xmm)),
          // SHA256MSG2 xmm1, xmm2/m128
          205 => write_xmm_legacy(xreg, __sha256msg2(read_xmm(xreg), src_xmm)),
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
          let src = modrm_rm(modrm, pfx);
          let src_xmm : xmmword = decode_xmm_src(modrm, src, pfx);
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
        | op == 208 | op == 214 | op == 230 => {
      if sse_em_blocked() then raise_UD();
      dispatch_2byte_sse_fp(op, pfx)
    },

    // SSE integer (packed integer arithmetic, logical, shift, pack/unpack)
    op if (96 <= op & op <= 118) | op == 126 | op == 127 | op == 196 | op == 197
        | (209 <= op & op <= 213) | (215 <= op & op <= 229)
        | (231 <= op & op <= 255) => {
      if sse_em_blocked() then raise_UD();
      dispatch_2byte_sse_int(op, pfx)
    },

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
  let os : {16, 32, 64} = if cur_mode == LongMode then {
    if pfx.rex_w then 64
    else if pfx.has_opsize then 16
    else 32
  } else {
    get_operand_size(pfx)
  };

  // Pop return RIP and CS
  let new_rip : qword = pop_qword(os);
  let new_cs_raw : qword = pop_qword(os);
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
    let new_rsp : qword = pop_qword(os);
    let new_ss_raw : qword = pop_qword(os);
    let new_ss : word = new_ss_raw[15..0];
    v(RSP) = new_rsp;
    load_segment_register(SS, new_ss);
    // Adjust new RSP for imm16 if present
    match maybe_imm {
      Some(imm) => v(RSP) = v(64, RSP) + zero_extend(imm),
      None()    => (),
    }
  } else {
    // Same-privilege (or real mode): adjust RSP for imm16 if present
    match maybe_imm {
      Some(imm) => v(RSP) = v(64, RSP) + zero_extend(imm),
      None()    => (),
    }
  };

  // Load new CS (selector + descriptor cache) and set CPL
  load_segment_register(CS, new_cs);
  // Update cur_mode: in IA-32e mode, CS.L determines 64-bit vs compatibility
  if EFER[10] == 0b1 then {
    if SegCache[CS].seg_l == 0b1 then cur_mode = LongMode
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
      // 06: PUSH ES — Push ES selector onto stack (SDM Vol.2B PUSH)
      // Invalid in 64-bit mode. Operand size determines push width:
      // 32 → push zero-extended dword; 16 → push word.
      6 => {
        if cur_mode == LongMode then raise_UD();
        let os = get_operand_size(pfx);
        match os {
          32 => push32(zero_extend(read_segreg(ES))),
          _  => push16(read_segreg(ES)),
        }
      },

      // 07: POP ES — Pop stack into ES (SDM Vol.2B POP)
      // Invalid in 64-bit mode. Pops operand-size value, loads low 16 bits
      // into ES and updates descriptor cache (load_segment_register).
      7 => {
        if cur_mode == LongMode then raise_UD();
        let os = get_operand_size(pfx);
        let v : word = match os {
          32 => pop32()[15..0],
          _  => pop16(),
        };
        load_segment_register(ES, v)
      },

      // 0E: PUSH CS — Push CS selector onto stack (SDM Vol.2B PUSH)
      // Invalid in 64-bit mode.
      14 => {
        if cur_mode == LongMode then raise_UD();
        let os = get_operand_size(pfx);
        match os {
          32 => push32(zero_extend(read_segreg(CS))),
          _  => push16(read_segreg(CS)),
        }
      },

      // 0F: Two-byte escape
      15 => {
        let opcode2 = fetch_byte();
        dispatch_opcode_2byte(opcode2, pfx)
      },

      // 16: PUSH SS — Push SS selector onto stack (SDM Vol.2B PUSH)
      // Invalid in 64-bit mode.
      22 => {
        if cur_mode == LongMode then raise_UD();
        let os = get_operand_size(pfx);
        match os {
          32 => push32(zero_extend(read_segreg(SS))),
          _  => push16(read_segreg(SS)),
        }
      },

      // 17: POP SS — Pop stack into SS (SDM Vol.2B POP)
      // Invalid in 64-bit mode. Loading SS inhibits interrupts until after
      // the next instruction (SDM Vol.3A §7.8.3). Not modeled here.
      23 => {
        if cur_mode == LongMode then raise_UD();
        let os = get_operand_size(pfx);
        let v : word = match os {
          32 => pop32()[15..0],
          _  => pop16(),
        };
        load_segment_register(SS, v)
      },

      // 1E: PUSH DS — Push DS selector onto stack (SDM Vol.2B PUSH)
      // Invalid in 64-bit mode.
      30 => {
        if cur_mode == LongMode then raise_UD();
        let os = get_operand_size(pfx);
        match os {
          32 => push32(zero_extend(read_segreg(DS))),
          _  => push16(read_segreg(DS)),
        }
      },

      // 1F: POP DS — Pop stack into DS (SDM Vol.2B POP)
      // Invalid in 64-bit mode.
      31 => {
        if cur_mode == LongMode then raise_UD();
        let os = get_operand_size(pfx);
        let v : word = match os {
          32 => pop32()[15..0],
          _  => pop16(),
        };
        load_segment_register(DS, v)
      },

      // 27: DAA — Decimal Adjust AL After Addition (SDM Vol.2A)
      // #UD in 64-bit mode. Adjusts packed BCD result in AL after ADD.
      39 => {
        if cur_mode == LongMode then raise_UD();
        let old_al : byte = v(RAX);
        let old_cf = CF;
        let lo : bits(4) = old_al[3..0];
        let cond1 : bits(1) = (lo[3] & (lo[2] | lo[1])) | AF;
        let al1 : byte = old_al + (0x06 & sign_extend(cond1));
        AF = cond1[0];
        let cond2 : bits(1) = ~(((0b0 @ old_al) - 0b0_1001_1010)[8]) | old_cf;
        let al_final : byte = al1 + (0x60 & sign_extend(cond2));
        CF = cond2[0];
        v(RAX) = al_final;
        update_SF_ZF_PF(al_final)
      },

      // 2F: DAS — Decimal Adjust AL After Subtraction (SDM Vol.2A)
      // #UD in 64-bit mode. Adjusts packed BCD result in AL after SUB.
      47 => {
        if cur_mode == LongMode then raise_UD();
        let old_al : byte = v(RAX);
        let old_cf = CF;
        let lo : bits(4) = old_al[3..0];
        let cond1 : bits(1) = (lo[3] & (lo[2] | lo[1])) | AF;
        let al1 : byte = old_al - (0x06 & sign_extend(cond1));
        let borrow1 : bits(5) = (0b0 @ lo) - (0b0 @ 0b0110);
        AF = cond1[0];
        let cond2 : bits(1) = ~(((0b0 @ old_al) - 0b0_1001_1010)[8]) | old_cf;
        let al_final : byte = al1 - (0x60 & sign_extend(cond2));
        CF = (cond2 | (cond1 & (old_cf | borrow1[4])))[0];
        v(RAX) = al_final;
        update_SF_ZF_PF(al_final)
      },

      // 37: AAA — ASCII Adjust After Addition (SDM Vol.2A)
      // #UD in 64-bit mode. Adjusts unpacked BCD result in AL/AH.
      55 => {
        if cur_mode == LongMode then raise_UD();
        let lo : bits(4) = v(8, RAX)[3..0];
        let cond : bits(1) = (lo[3] & (lo[2] | lo[1])) | AF;
        let new_ax : word = v(RAX) + (0x0106 & sign_extend(cond));
        v(RAX) = new_ax;
        AF = cond[0];
        CF = cond[0];
        v(RAX) = new_ax[7..0] & 0x0F;
      },

      // 3F: AAS — ASCII Adjust AL After Subtraction (SDM Vol.2A)
      // #UD in 64-bit mode. Adjusts unpacked BCD result in AL/AH.
      63 => {
        if cur_mode == LongMode then raise_UD();
        let lo : bits(4) = v(8, RAX)[3..0];
        let cond : bits(1) = (lo[3] & (lo[2] | lo[1])) | AF;
        let new_ax : word = v(RAX) - (0x0106 & sign_extend(cond));
        v(RAX) = new_ax;
        AF = cond[0];
        CF = cond[0];
        v(RAX) = new_ax[7..0] & 0x0F;
      },

      // 40-47: INC r32/r16 (compat/protected mode only; REX prefix in 64-bit)
      op if 64 <= op & op <= 71 => {
        let reg : range(0, 7) = op - 64;
        let os = get_operand_size(pfx);
        v(reg) = exec_inc(v(os, reg))
      },

      // 48-4F: DEC r32/r16 (compat/protected mode only; REX prefix in 64-bit)
      op if 72 <= op & op <= 79 => {
        let reg : range(0, 7) = op - 72;
        let os = get_operand_size(pfx);
        v(reg) = exec_dec(v(os, reg))
      },

      // 50-57: PUSH reg (d64)
      op if 80 <= op & op <= 87 => {
        let reg_field : range(0, 7) = op - 80;
        let reg = unsigned(pfx.rex_b @ to_bits(3, reg_field));
        let os = get_operand_size_default64(pfx);
        match os {
          16 => push16(v(reg)),
          32 => if cur_mode == LongMode then push64(zero_extend(v(32, reg)))
                  else push32(v(reg)),
          64 => push64(v(reg)),
        }
      },

      // 58-5F: POP reg (d64)
      op if 88 <= op & op <= 95 => {
        let reg_field : range(0, 7) = op - 88;
        let reg = unsigned(pfx.rex_b @ to_bits(3, reg_field));
        let os = get_operand_size_default64(pfx);
        exec_pop_reg(reg, os)
      },

      // 60: PUSHA/PUSHAD — Push All General-Purpose Registers
      // #UD in 64-bit mode. Pushes AX..DI (16) or EAX..EDI (32).
      // Push order: AX, CX, DX, BX, original SP, BP, SI, DI.
      96 => {
        if cur_mode == LongMode then {
          raise_UD()
        } else {
          let os = get_operand_size(pfx);
          let orig_sp = read_stack_ptr();
          match os {
            32 => {
              push32(v(RAX));
              push32(v(RCX));
              push32(v(RDX));
              push32(v(RBX));
              push32(orig_sp[31..0] - get_seg_base(SS)[31..0]);
              push32(v(RBP));
              push32(v(RSI));
              push32(v(RDI))
            },
            _ => {
              push16(v(RAX));
              push16(v(RCX));
              push16(v(RDX));
              push16(v(RBX));
              push16(orig_sp[15..0] - get_seg_base(SS)[15..0]);
              push16(v(RBP));
              push16(v(RSI));
              push16(v(RDI))
            },
          }
        }
      },

      // 61: POPA/POPAD — Pop All General-Purpose Registers
      // #UD in 64-bit mode. Pops DI..AX (16) or EDI..EAX (32).
      // Pop order: EDI, ESI, EBP, skip ESP slot, EBX, EDX, ECX, EAX.
      97 => {
        if cur_mode == LongMode then {
          raise_UD()
        } else {
          let os = get_operand_size(pfx);
          match os {
            32 => {
              v(RDI) = pop32();
              v(RSI) = pop32();
              v(RBP) = pop32();
              // Skip the ESP slot (increment past it)
              let sp = read_stack_ptr();
              write_stack_ptr(sp + 4 - get_seg_base(SS));
              v(RBX) = pop32();
              v(RDX) = pop32();
              v(RCX) = pop32();
              v(RAX) = pop32()
            },
            _ => {
              v(RDI) = pop16();
              v(RSI) = pop16();
              v(RBP) = pop16();
              // Skip the SP slot
              let sp = read_stack_ptr();
              write_stack_ptr(sp + 2 - get_seg_base(SS));
              v(RBX) = pop16();
              v(RDX) = pop16();
              v(RCX) = pop16();
              v(RAX) = pop16()
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
          let src = modrm_rm(modrm, pfx);
          match src {
            RM_reg(_) => raise_UD(),  // BOUND requires memory operand
            RM_mem(m) => {
              let os = get_operand_size(pfx);
              assert(os <= 32);
              let reg = modrm_reg(modrm, pfx);
              let index = signed(v(os, reg));
              // BOUND reads two consecutive os-bit values (lower, upper bounds)
              let d = v(os * 2, m);
              if index < signed(d[os - 1 .. 0]) | signed(d[os * 2 - 1 .. os]) < index then
                raise_BR();
            },
          }
        }
      },

      // 63: MOVSXD r64, r/m32 (in 64-bit mode)
      99 => {
        let (reg, src) = fetch_modrm(pfx);
        if pfx.rex_w then {
          v(reg) = sign_extend(64, v(32, src))
        } else {
          let os = get_operand_size(pfx);
          v(reg) = v(os, src)
        }
      },

      // 68: PUSH imm16/32 (d64, Iz)
      104 => {
        let os = get_operand_size_default64(pfx);
        let imm = fetch_imm_z(os);
        exec_push_imm(imm[(os - 1) .. 0], os)
      },

      // 69: IMUL r, r/m, imm (3-operand, Iz)
      105 => {
        let 'os = get_operand_size(pfx);
        let (reg, src) = fetch_modrm(pfx);
        // Fetch imm BEFORE reading src so decode_pos is final for RIP-relative fixup
        let imm = fetch_imm_z(os);
        let src_val = v(os, src);
        let product : int = signed(src_val[os - 1 .. 0]) * signed(imm[os - 1 .. 0]);
        let result : qword = to_bits_truncate(product);
        let w : bits('os * 2) = to_bits_truncate(product);
        CF = is_nonzero(w['os * 2 - 1 .. 'os] ^ sign_extend(w['os - 1]));
        OF = CF;
        v(reg) = result[(os - 1) .. 0]
      },

      // 6A: PUSH imm8 (d64, sign-extended)
      106 => {
        let os = get_operand_size_default64(pfx);
        let imm = fetch_imm8_sx();
        exec_push_imm(imm[(os - 1) .. 0], os)
      },

      // 6B: IMUL r, r/m, imm8 (3-operand, Ib sign-extended)
      107 => {
        let 'os = get_operand_size(pfx);
        let (reg, src) = fetch_modrm(pfx);
        // Fetch imm BEFORE reading src so decode_pos is final for RIP-relative fixup
        let imm = fetch_imm8_sx();
        let src_val = v(os, src);
        let product : int = signed(src_val[os - 1 .. 0]) * signed(imm[os - 1 .. 0]);
        let result : qword = to_bits_truncate(product);
        let w : bits('os * 2) = to_bits_truncate(product);
        CF = is_nonzero(w['os * 2 - 1 .. 'os] ^ sign_extend(w['os - 1]));
        OF = CF;
        v(reg) = result[(os - 1) .. 0]
      },

      // 6C: INSB — Input byte from port DX to ES:[RDI]
      108 => {
        let asz = get_address_size(pfx);
        if pfx.has_rep then exec_rep(REP_rep, STR_ins, 8, asz, pfx)
        else exec_ins(8, asz)
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
        if pfx.has_rep then exec_rep(REP_rep, STR_outs, 8, asz, pfx)
        else exec_outs(8, asz, pfx)
      },
      // 6F: OUTSW/OUTSD — Output word/dword from DS:[RSI] to port DX
      111 => {
        let os = get_operand_size(pfx);
        let asz = get_address_size(pfx);
        if pfx.has_rep then exec_rep(REP_rep, STR_outs, os, asz, pfx)
        else exec_outs(os, asz, pfx)
      },

      // 70-7F: Jcc rel8 (f64)
      op if 112 <= op & op <= 127 => {
        let cc : cc_idx = op - 112;
        let offset = fetch_rel8();
        if eval_cc(cc) == 0b1 then {
          let os = get_operand_size_forced64(pfx);
          next_rip = Some(truncate_rip(decode_pos + offset, os));
        }
      },

      // 80: Group 1 — ALU r/m8, imm8
      128 => {
        let (reg_field, dest) = fetch_modrm_raw(pfx);
        let imm : byte = fetch_byte();
        let alu_op = group1_op(reg_field);
        check_lock_rm(pfx, dest, alu_op == ALU_CMP);
        exec_alu_rm_imm(alu_op, dest, imm, 8)
      },

      // 81: Group 1 — ALU r/m, imm (Iz)
      129 => {
        let os = get_operand_size(pfx);
        let (reg_field, dest) = fetch_modrm_raw(pfx);
        let imm = fetch_imm_z(os);
        let alu_op = group1_op(reg_field);
        check_lock_rm(pfx, dest, alu_op == ALU_CMP);
        exec_alu_rm_imm(alu_op, dest, imm[(os - 1) .. 0], os)
      },

      // 83: Group 1 — ALU r/m, imm8 (sign-extended)
      131 => {
        let os = get_operand_size(pfx);
        let (reg_field, dest) = fetch_modrm_raw(pfx);
        let imm = fetch_imm8_sx();
        let alu_op = group1_op(reg_field);
        check_lock_rm(pfx, dest, alu_op == ALU_CMP);
        exec_alu_rm_imm(alu_op, dest, imm[(os - 1) .. 0], os)
      },

      // 84: TEST r/m8, r8
      132 => {
        let (reg, src) = fetch_modrm(pfx);
        let a : byte = v(src);
        let b : byte = v(reg);
        let result = a & b;
        update_flags_logic(result)
      },

      // 85: TEST r/m, r
      133 => {
        let os = get_operand_size(pfx);
        let (reg, src) = fetch_modrm(pfx);
        let a = v(os, src);
        let b = v(os, reg);
        let result = a & b;
        update_flags_logic(result)
      },

      // 86: XCHG r/m8, r8
      134 => {
        let (reg, dest) = fetch_modrm(pfx);
        let a : byte = v(dest);
        let b : byte = v(reg);
        v(dest) = b;
        v(reg) = a
      },

      // 87: XCHG r/m, r
      135 => {
        let os = get_operand_size(pfx);
        let (reg, dest) = fetch_modrm(pfx);
        let a = v(os, dest);
        let b = v(os, reg);
        v(dest) = b;
        v(reg) = a
      },

      // 88: MOV r/m8, r8
      136 => {
        let (reg, dest) = fetch_modrm(pfx);
        v(dest) = v(8, reg)
      },

      // 89: MOV r/m, r
      137 => {
        let os = get_operand_size(pfx);
        let (reg, dest) = fetch_modrm(pfx);
        v(dest) = v(os, reg)
      },

      // 8A: MOV r8, r/m8
      138 => {
        let (reg, src) = fetch_modrm(pfx);
        v(reg) = v(8, src)
      },

      // 8B: MOV r, r/m
      139 => {
        let os = get_operand_size(pfx);
        let (reg, src) = fetch_modrm(pfx);
        v(reg) = v(os, src)
      },

      // 8C: MOV r/m16, sreg
      140 => {
        let (reg_field, dest) = fetch_modrm_raw(pfx);
        if reg_field > 5 then raise_UD();
        assert(reg_field <= 5);
        let seg : segreg_idx = reg_field;
        match dest {
          RM_reg(r) => {
            let os = get_operand_size(pfx);
            v(r) = zero_extend(os, read_segreg(seg))
          },
          RM_mem(m) => v(m) = read_segreg(seg),
        }
      },

      // 8D: LEA r, m
      141 => {
        let os = get_operand_size(pfx);
        let (reg, src) = fetch_modrm(pfx);
        match src {
          RM_mem(m) => v(reg) = m.addr[(os - 1) .. 0],
          RM_reg(_) => raise_UD(),
        }
      },

      // 8E: MOV sreg, r/m16
      142 => {
        let (reg_field, src) = fetch_modrm_raw(pfx);
        if reg_field > 5 then {
          raise_UD()
        } else {
          let seg : segreg_idx = reg_field;
          if seg == CS then raise_UD();
          load_segment_register(seg, v(src))
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
          let os = get_operand_size_default64(pfx);
          let mod_field : range(0, 3) = unsigned(modrm[7..6]);
          if mod_field == 3 then {
            // Register destination — no address computation issue
            let idx = unsigned(pfx.rex_b @ modrm[2..0]);
            exec_pop_reg(idx, os)
          } else {
            // Memory destination: pop first, THEN compute effective address
            // (SDM requires RSP-relative addresses use the post-pop RSP).
            // We pop first so that modrm_rm sees the updated RSP.
            let v : qword = pop_qword(os);
            let dest = modrm_rm(modrm, pfx);
            match dest {
              RM_mem(m) => v(os, m) = v[(os - 1) .. 0],
              _ => raise_UD(),
            }
          }
        } else {
          raise_UD()
        }
      },

      // 90: NOP / PAUSE (F3 90) / XCHG R8D,EAX (REX.B)
      144 => {
        if ~(pfx.has_rep) & pfx.rex_b == 0b1 then {
          let os = get_operand_size(pfx);
          exec_xchg_reg_reg(RAX, R8, os)
        } else {
          ()
        }
      },

      // 91-97: XCHG rAX, r
      op if 145 <= op & op <= 151 => {
        let reg_field : range(0, 7) = op - 144;
        let reg = unsigned(pfx.rex_b @ to_bits(3, reg_field));
        let os = get_operand_size(pfx);
        exec_xchg_reg_reg(RAX, reg, os)
      },

      // 98: CBW/CWDE/CDQE
      152 => {
        let os = get_operand_size(pfx);
        v(RAX) = sign_extend(os, v(os / 2, RAX))
      },

      // 99: CWD/CDQ/CQO
      153 => {
        let os = get_operand_size(pfx);
        v(RDX) = sign_extend(os, v(os, RAX)[os - 1])
      },

      // 9A: CALL ptr16:16/ptr16:32 — Far call, immediate
      // Invalid in 64-bit mode. Encoding: offset (16/32 bits) then selector (16 bits).
      154 => {
        if cur_mode == LongMode then {
          raise_UD()
        } else {
          let os = get_operand_size(pfx);
          let offset : qword = match os {
            16 => fetch_imm_v(16),
            _  => fetch_imm_v(32),
          };
          let selector : word = fetch_imm16();
          match cur_mode {
            RealMode => {
              // Push old CS:IP/EIP
              match os {
                16 => { push16(read_segreg(CS)); push16(decode_pos[15..0]) },
                _  => { push32(zero_extend(read_segreg(CS))); push32(decode_pos[31..0]) },
              };
              load_segment_register(CS, selector);
              let target : qword = match os {
                16 => zero_extend(offset[15..0]),
                _  => zero_extend(offset[31..0]),
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
        let os = get_operand_size_default64(pfx);
        let flags = read_rflags() & 0x0000000000FCFFFF;
        exec_push_imm(flags[(os - 1) .. 0], os)
      },

      // 9D: POPF (d64)
      // At CPL 0: all flags except RF, VIP, VIF, VM modifiable.
      // RF is always cleared (cleared at start of every instruction).
      // For 16-bit: only lower 16 bits affect flags (IOPL modifiable at CPL 0,
      // but AC/ID are above bit 15 and are NOT modified).
      157 => {
        let os = get_operand_size_default64(pfx);
        match os {
          16 => {
            let v : word = pop16();
            CF = v[0]; PF = v[2]; AF = v[4]; ZF = v[6]; SF = v[7];
            TF = v[8]; DF = v[10]; OF = v[11];
            NT = v[14];
            // IOPL modifiable only at CPL 0; IF modifiable at CPL <= IOPL
            if cur_cpl == 0 then IOPL = v[13..12];
            if cur_cpl <= unsigned(IOPL) then IF_flag = v[9];
          },
          32 => {
            let v : dword = pop32();
            CF = v[0]; PF = v[2]; AF = v[4]; ZF = v[6]; SF = v[7];
            TF = v[8]; DF = v[10]; OF = v[11];
            NT = v[14];
            AC_flag = v[18]; ID = v[21];
            if cur_cpl == 0 then IOPL = v[13..12];
            if cur_cpl <= unsigned(IOPL) then IF_flag = v[9];
          },
          64 => {
            let v : qword = pop64();
            // Save IOPL and IF before write_rflags overwrites them
            let old_iopl = IOPL;
            let old_if = IF_flag;
            write_rflags(v);
            // RF always cleared; VIP, VIF, VM not modifiable
            RF = 0b0;
            // IOPL modifiable only at CPL 0; IF modifiable at CPL <= IOPL
            if cur_cpl != 0 then IOPL = old_iopl;
            if cur_cpl > unsigned(old_iopl) then IF_flag = old_if;
          },
          _ => (),
        }
      },

      // 9E: SAHF
      158 => {
        let ah : byte = v(16, RAX)[15..8];
        CF = ah[0];
        PF = ah[2];
        AF = ah[4];
        ZF = ah[6];
        SF = ah[7]
      },

      // 9F: LAHF — AH := RFLAGS[7:0] = SF:ZF:0:AF:0:PF:1:CF
      159 => v(16, RAX) = SF @ ZF @ 0b0 @ AF @ 0b0 @ PF @ 0b1 @ CF @ v(8, RAX),

      // A0: MOV AL, moffs8
      160 => {
        let addr = apply_segment(fetch_moffs(pfx), pfx, DS);
        v(8, RAX) = read_mem(addr);
      },

      // A1: MOV rAX, moffs
      161 => {
        let os = get_operand_size(pfx);
        let addr = apply_segment(fetch_moffs(pfx), pfx, DS);
        v(os, RAX) = read_mem(addr)
      },

      // A2: MOV moffs8, AL
      162 => {
        let addr = apply_segment(fetch_moffs(pfx), pfx, DS);
        write_mem(addr, v(8, RAX))
      },

      // A3: MOV moffs, rAX
      163 => {
        let os = get_operand_size(pfx);
        let addr = apply_segment(fetch_moffs(pfx), pfx, DS);
        write_mem(addr, v(os, RAX))
      },

      // A4: MOVSB
      164 => {
        let asz = get_address_size(pfx);
        if pfx.has_rep then exec_rep(REP_rep, STR_movs, 8, asz, pfx)
        else exec_movs(8, asz, pfx)
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
        if pfx.has_rep then exec_rep(REP_repe, STR_cmps, 8, asz, pfx)
        else if pfx.has_repne then exec_rep(REP_repne, STR_cmps, 8, asz, pfx)
        else exec_cmps(8, asz, pfx)
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
        let a : qword = zero_extend(v(8, RAX));
        let result = a & imm;
        update_flags_logic(result[7..0])
      },

      // A9: TEST rAX, imm (Iz)
      169 => {
        let os = get_operand_size(pfx);
        let imm = fetch_imm_z(os);
        let a = v(os, RAX);
        let result = a & imm[(os - 1) .. 0];
        update_flags_logic(result)
      },

      // AA: STOSB
      170 => {
        let asz = get_address_size(pfx);
        if pfx.has_rep then exec_rep(REP_rep, STR_stos, 8, asz, pfx)
        else exec_stos(8, asz)
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
        if pfx.has_rep then exec_rep(REP_rep, STR_lods, 8, asz, pfx)
        else exec_lods(8, asz, pfx)
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
        if pfx.has_rep then exec_rep(REP_repe, STR_scas, 8, asz, pfx)
        else if pfx.has_repne then exec_rep(REP_repne, STR_scas, 8, asz, pfx)
        else exec_scas(8, asz)
      },

      // AF: SCASW/SCASD/SCASQ
      175 => {
        let os = get_operand_size(pfx);
        let asz = get_address_size(pfx);
        if pfx.has_rep then exec_rep(REP_repe, STR_scas, os, asz, pfx)
        else if pfx.has_repne then exec_rep(REP_repne, STR_scas, os, asz, pfx)
        else exec_scas(os, asz)
      },

      // B0-B7: MOV r8, imm8
      op if 176 <= op & op <= 183 => {
        let reg_field : range(0, 7) = op - 176;
        let reg = struct { gpr_idx = unsigned(pfx.rex_b @ to_bits(3, reg_field)), has_rex = pfx.has_rex } : GPRRef;
        let imm = fetch_byte();
        v(reg) = imm
      },

      // B8-BF: MOV r, imm (Iv)
      op if 184 <= op & op <= 191 => {
        let reg_field : range(0, 7) = op - 184;
        let reg = unsigned(pfx.rex_b @ to_bits(3, reg_field));
        let os = get_operand_size(pfx);
        let imm = fetch_imm_v(os);
        v(reg) = imm[(os - 1) .. 0]
      },

      // C0: Group 2 — shift r/m8 by imm8
      192 => {
        let (reg_field, dest) = fetch_modrm_raw(pfx);
        let count = fetch_byte();
        exec_shift_rm(reg_field, dest, count, 8)
      },

      // C1: Group 2 — shift r/m by imm8
      193 => {
        let os = get_operand_size(pfx);
        let (reg_field, dest) = fetch_modrm_raw(pfx);
        let count = fetch_byte();
        exec_shift_rm(reg_field, dest, count, os)
      },

      // C2: RET near imm16
      // SDM: In 64-bit mode, operand size = stack-address size = 64.
      // 66h prefix is ignored; 16/32-bit forms are not encodable.
      194 => {
        let imm = fetch_imm16();
        let os = get_operand_size_forced64(pfx);
        next_rip = Some(pop_qword(os));
        v(64, RSP) = v(RSP) + zero_extend(imm)
      },

      // C3: RET near
      // SDM: In 64-bit mode, operand size = stack-address size = 64.
      // 66h prefix is ignored; 16/32-bit forms are not encodable.
      195 => {
        next_rip = Some(pop_qword(get_operand_size_forced64(pfx)))
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
            let src = modrm_rm(byte2, pfx);
            match src {
              RM_mem(m) => {
                let (far_offset, selector) : (qword, word) = match os {
                  16 => { let d : bits(32) = v(m); (zero_extend(d[15..0]), d[31..16]) },
                  _  => { let d : bits(48) = read_mem(m); (zero_extend(d[31..0]), d[47..32]) },
                };
                v(reg) = far_offset;
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
            let src = modrm_rm(byte2, pfx);
            match src {
              RM_mem(m) => {
                let (far_offset, selector) : (qword, word) = match os {
                  16 => { let d : bits(32) = v(m); (zero_extend(d[15..0]), d[31..16]) },
                  _  => { let d : bits(48) = read_mem(m); (zero_extend(d[31..0]), d[47..32]) },
                };
                v(reg) = far_offset;
                load_segment_register(DS, selector)
              },
              RM_reg(_) => raise_UD(),
            }
          }
        }
      },

      // C6 /0: MOV r/m8, imm8
      198 => {
        let (reg_field, dest) = fetch_modrm_raw(pfx);
        if reg_field == 0 then {
          let imm : byte = fetch_byte();
          v(dest) = imm
        } else {
          raise_UD()
        }
      },

      // C7 /0: MOV r/m, imm (Iz)
      199 => {
        let (reg_field, dest) = fetch_modrm_raw(pfx);
        if reg_field == 0 then {
          let os = get_operand_size(pfx);
          let imm = fetch_imm_z(os);
          v(dest) = imm[(os - 1) .. 0]
        } else {
          raise_UD()
        }
      },

      // C8: ENTER imm16, imm8
      200 => {
        let size = fetch_imm16();
        let level = fetch_byte();
        let os = get_operand_size_default64(pfx);
        let nesting : range(0, 31) = unsigned(level) % 32;
        match os {
          64 => {
            push64(v(RBP));
            let frame_temp : qword = v(RSP);
            if nesting > 1 then {
              foreach (i from 1 to (nesting - 1)) {
                v(RBP) = v(64, RBP) - 8;
                push64(read_mem(v(64, RBP)));
              };
            };
            if nesting >= 1 then
              push64(frame_temp);
            v(RBP) = frame_temp;
            v(RSP) = v(64, RSP) - zero_extend(size);
          },
          16 => {
            push16(v(RBP));
            let frame_temp : word = v(RSP);
            if nesting > 1 then {
              foreach (i from 1 to (nesting - 1)) {
                v(RBP) = v(16, RBP) - 2;
                push16(read_mem(zero_extend(v(16, RBP))));
              };
            };
            if nesting >= 1 then
              push16(frame_temp);
            v(RBP) = frame_temp;
            v(RSP) = v(64, RSP) - zero_extend(size);
          },
          _ => (),
        }
      },

      // C9: LEAVE
      // In 64-bit mode, StackAddrSize is always 64: RSP := RBP uses full
      // 64-bit RBP regardless of operand-size prefix. Only the POP of RBP
      // is affected by operand size (16 vs 64).
      201 => {
        let os = get_operand_size_default64(pfx);
        v(RSP) = v(64, RBP);
        match os {
          16 => v(RBP) = pop16(),
          32 => v(RBP) = pop64()[31..0],
          64 => v(RBP) = pop64(),
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
        if OF == 0b1 then {
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
        if NT == 0b1 then {
          throw Fault(EXN_GP, 0x00000000)
        };
        match os {
          16 => {
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
              v(RSP) = zero_extend(64, new_sp);
              load_segment_register(SS, new_ss)
            };

            // In real mode, CPL is always 0 (no privilege levels).
            // In protected mode, set CPL from the return CS selector RPL.
            if cur_mode != RealMode then cur_cpl = return_rpl;
            let old_rflags = read_rflags();
            write_rflags((old_rflags & 0xFFFFFFFFFFFF0000) | zero_extend(new_flags));
            RF = 0b0
          },
          32 => {
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
              v(RSP) = zero_extend(64, new_esp);
              load_segment_register(SS, new_ss[15..0])
            };

            if cur_mode != RealMode then cur_cpl = return_rpl;
            write_rflags(zero_extend(new_eflags));
            RF = 0b0
          },
          64 => {
            let new_rip    = pop64();
            let new_cs     = pop64();
            let new_rflags = pop64();
            let new_rsp    = pop64();
            let new_ss     = pop64();

            next_rip = Some(new_rip);

            // Load CS selector and descriptor cache from GDT.
            let sel_offset : qword = zero_extend(new_cs[15..3] @ 0b000);
            let desc_lo : dword = read_mem(GDTR_base + sel_offset);
            let desc_hi : dword = read_mem(GDTR_base + sel_offset + 4);
            write_segreg(CS, new_cs[15..0]);
            SegCache[CS] = parse_seg_descriptor(desc_lo, desc_hi);
            cur_mode = if SegCache[CS].seg_l == 0b1 then LongMode
                       else CompatibilityMode;

            let new_cpl : cpl_t = unsigned(new_cs[1..0]);
            cur_cpl = new_cpl;

            write_rflags(new_rflags);
            RF = 0b0;

            v(RSP) = new_rsp;
            write_segreg(SS, new_ss[15..0]);
          },
        }
      },

      // D0: Group 2 — shift r/m8 by 1
      208 => {
        let (reg_field, dest) = fetch_modrm_raw(pfx);
        exec_shift_rm(reg_field, dest, 0x01, 8)
      },

      // D1: Group 2 — shift r/m by 1
      209 => {
        let os = get_operand_size(pfx);
        let (reg_field, dest) = fetch_modrm_raw(pfx);
        exec_shift_rm(reg_field, dest, 0x01, os)
      },

      // D2: Group 2 — shift r/m8 by CL
      210 => {
        let (reg_field, dest) = fetch_modrm_raw(pfx);
        let count : byte = v(RCX);
        exec_shift_rm(reg_field, dest, count, 8)
      },

      // D3: Group 2 — shift r/m by CL
      211 => {
        let os = get_operand_size(pfx);
        let (reg_field, dest) = fetch_modrm_raw(pfx);
        let count : byte = v(RCX);
        exec_shift_rm(reg_field, dest, count, os)
      },

      // D4: AAM — ASCII Adjust AX After Multiply (SDM Vol.2A)
      // #UD in 64-bit mode. D4 ib: AH := AL / imm8; AL := AL MOD imm8.
      // #DE if imm8 == 0.
      212 => {
        if cur_mode == LongMode then raise_UD();
        let imm = fetch_byte();
        if imm == 0x00 then raise_DE();
        let temp_al : byte = v(RAX);
        let divisor = unsigned(imm);
        assert(divisor > 0);
        v(RAX) = to_bits(8, unsigned(temp_al) / divisor) @ to_bits(8, unsigned(temp_al) % divisor);
        update_SF_ZF_PF(v(8, RAX))
      },

      // D5: AAD — ASCII Adjust AX Before Division (SDM Vol.2A)
      // #UD in 64-bit mode. D5 ib: AL := (AL + AH * imm8) AND FFH; AH := 0.
      213 => {
        if cur_mode == LongMode then raise_UD();
        let imm = fetch_byte();
        let temp_al = v(8, RAX);
        let temp_ah = v(16, RAX)[15..8];
        let result : byte = to_bits(8, (unsigned(temp_al) + unsigned(temp_ah) * unsigned(imm)) % 256);
        v(RAX) = 0x00 @ result;
        update_SF_ZF_PF(result)
      },

      // D6: SALC — Set AL to Carry Flag (undocumented, invalid in 64-bit mode)
      // AL := 0 - CF (0xFF if CF=1, 0x00 if CF=0). No flags affected.
      214 => {
        if cur_mode == LongMode then raise_UD();
        v(8, RAX) = sign_extend(CF);
      },

      // D7: XLAT/XLATB
      215 => {
        let al : qword = zero_extend(v(8, RAX));
        let addr : qword = zero_extend(v(get_address_size(pfx), RBX)) + al;
        v(8, RAX) = read_mem(addr)
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
      // Address size selects CX (16), ECX (32), or RCX (64).
      227 => {
        let rel = fetch_rel8();
        let count_reg : qword = zero_extend(v(get_address_size(pfx), RCX));
        if count_reg == zeros() then {
          let os = get_operand_size_forced64(pfx);
          next_rip = Some(truncate_rip(decode_pos + rel, os))
        } else {
          ()
        }
      },

      // E4: IN AL, imm8
      228 => exec_in(zero_extend(fetch_byte()), 8),

      // E5: IN eAX, imm8
      229 => exec_in(zero_extend(fetch_byte()), get_operand_size(pfx)),

      // E6: OUT imm8, AL
      230 => {
        let port : word = zero_extend(fetch_byte());
        exec_out(port, 8)
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
        let os = get_operand_size_forced64(pfx);
        let return_addr = decode_pos;
        match os {
          16 => push16(return_addr[15..0]),
          32 => if cur_mode == LongMode then push64(zero_extend(return_addr[31..0]))
                  else push32(return_addr[31..0]),
          64 => push64(return_addr),
        };
        next_rip = Some(truncate_rip(return_addr + offset, os))
      },

      // E9: JMP rel16/rel32 (f64)
      233 => {
        let os = get_operand_size_forced64(pfx);
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
            16 => fetch_imm_v(16),
            _    => fetch_imm_v(32),
          };
          let selector : word = fetch_imm16();
          match cur_mode {
            RealMode => {
              load_segment_register(CS, selector);
              let target : qword = match os {
                16 => zero_extend(offset[15..0]),
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
        let os = get_operand_size_forced64(pfx);
        next_rip = Some(truncate_rip(decode_pos + fetch_rel8(), os))
      },

      // EC: IN AL, DX
      236 => exec_in(v(RDX), 8),

      // ED: IN eAX, DX
      237 => exec_in(v(RDX), get_operand_size(pfx)),

      // EE: OUT DX, AL
      238 => exec_out(v(RDX), 8),

      // EF: OUT DX, eAX
      239 => exec_out(v(RDX), get_operand_size(pfx)),

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
        let (reg_field, dest) = fetch_modrm_raw(pfx);
        // LOCK valid only for NOT (/2) and NEG (/3) with memory destination
        if pfx.has_lock & (reg_field != 2 & reg_field != 3) then raise_UD();
        check_lock_rm(pfx, dest, false);
        dispatch_group3_byte(reg_field, dest)
      },

      // F7: Group 3 — unary word/dword/qword operations
      247 => {
        let os = get_operand_size(pfx);
        let (reg_field, dest) = fetch_modrm_raw(pfx);
        // LOCK valid only for NOT (/2) and NEG (/3) with memory destination
        if pfx.has_lock & (reg_field != 2 & reg_field != 3) then raise_UD();
        check_lock_rm(pfx, dest, false);
        dispatch_group3(reg_field, dest, os)
      },

      // F8: CLC
      248 => CF = 0b0,

      // F9: STC
      249 => CF = 0b1,

      // FA: CLI
      250 => IF_flag = 0b0,

      // FB: STI
      251 => IF_flag = 0b1,

      // FC: CLD
      252 => DF = 0b0,

      // FD: STD
      253 => DF = 0b1,

      // FE: Group 4 — INC/DEC r/m8
      254 => {
        let (reg_field, dest) = fetch_modrm_raw(pfx);
        // LOCK valid only for INC (/0) and DEC (/1) with memory
        if pfx.has_lock & reg_field >= 2 then raise_UD();
        check_lock_rm(pfx, dest, false);
        if reg_field == 0 then {
          v(dest) = exec_inc(v(8, dest))
        } else if reg_field == 1 then {
          v(dest) = exec_dec(v(8, dest))
        } else {
          raise_UD()
        }
      },

      // FF: Group 5 — INC/DEC/CALL/JMP/PUSH r/m
      255 => {
        let (reg_field, dest) = fetch_modrm_raw(pfx);
        // LOCK valid only for INC (/0) and DEC (/1) with memory
        if pfx.has_lock & reg_field >= 2 then raise_UD();
        check_lock_rm(pfx, dest, false);
        dispatch_group5(reg_field, dest, pfx)
      },

      // Unhandled opcode
      _ => raise_UD(),
    }
  }
}

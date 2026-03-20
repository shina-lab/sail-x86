// x86-64 — Types and Structures

// =========================================================================
// Prefix state accumulated during prefix scanning
// =========================================================================

struct Prefixes = {
  has_lock : bool,
  has_repne : bool,     // F2
  has_rep : bool,       // F3
  seg_override : option(segreg_idx),
  has_opsize : bool,    // 66
  has_adsize : bit,     // 67
  rex_w : bool,
  rex_r : bit,
  rex_x : bit,
  rex_b : bit,
  has_rex : bool,       // any REX present (changes byte reg encoding)
  // VEX prefix fields
  vex_present : bool,   // VEX prefix was decoded
  vex_l : bool,         // vector length: false=128, true=256
  vex_vvvv : simd_idx,  // extra register operand (already complemented)
  vex_w : bool,         // VEX.W (like REX.W for some instructions)
  // EVEX prefix fields
  evex_present : bool,  // EVEX prefix was decoded
  evex_ll : range(0, 3),// vector length: 0=128, 1=256, 2=512
  evex_vvvvv : simd_idx,// 5-bit source register (vvvv + V')
  evex_aaa : kreg_idx,  // opmask register index (k0-k7)
  evex_z : bit,         // zeroing (1) vs merging (0)
  evex_b : bool,        // broadcast / rounding control
  evex_rr : bit,        // R' (extends reg to 5 bits)
}

val default_prefixes : unit -> Prefixes
function default_prefixes() = struct {
  has_lock = false,
  has_repne = false,
  has_rep = false,
  seg_override = None(),
  has_opsize = false,
  has_adsize = bitzero,
  rex_w = false,
  rex_r = bitzero,
  rex_x = bitzero,
  rex_b = bitzero,
  has_rex = false,
  vex_present = false,
  vex_l = false,
  vex_vvvv = 0,
  vex_w = false,
  evex_present = false,
  evex_ll = 0,
  evex_vvvvv = 0,
  evex_aaa = 0,
  evex_z = bitzero,
  evex_b = false,
  evex_rr = bitzero,
}

// =========================================================================
// Resolved ModR/M operand — either a register or memory address
// =========================================================================

union RM = {
  RM_reg : gpr_idx,
  RM_mem : qword,
}

// Fixup for RIP-relative addressing. When rip_rel_pending is true, the
// RM_mem address was computed with an intermediate decode_pos (before
// trailing imm bytes were fetched). This function recomputes the correct
// address using the final decode_pos and the saved displacement.
// Idempotent: safe to call multiple times (e.g. read + write).
val fixup_addr : qword -> qword
function fixup_addr(addr) =
  if rip_rel_pending then decode_pos + rip_rel_disp
  else addr

// Extract the memory address from an RM, applying RIP-relative fixup.
// For SSE/misc code that directly matches RM_mem(addr).
val rm_effective_addr : RM -> qword
function rm_effective_addr(rm) = match rm {
  RM_mem(addr) => fixup_addr(addr),
  RM_reg(_) => zeros(),  // shouldn't be called for register operands
}

// =========================================================================
// ALU operation codes (for the regular 00-3F pattern + Group 1)
// =========================================================================

enum ALUOp = {
  ALU_ADD,
  ALU_OR,
  ALU_ADC,
  ALU_SBB,
  ALU_AND,
  ALU_SUB,
  ALU_XOR,
  ALU_CMP,
}

// =========================================================================
// Shift/rotate operation codes (for Group 2)
// =========================================================================

enum ShiftOp = {
  SHIFT_ROL,
  SHIFT_ROR,
  SHIFT_RCL,
  SHIFT_RCR,
  SHIFT_SHL,
  SHIFT_SHR,
  SHIFT_SAL,  // same as SHL
  SHIFT_SAR,
}

// =========================================================================
// Mandatory prefix classification (for 2-byte+ opcodes)
// =========================================================================

enum MandatoryPrefix = {
  MP_NONE,
  MP_66,
  MP_F2,
  MP_F3,
}

// =========================================================================
// Decode state — mutable position tracking during fetch
// (decode_pos is defined in core/regs.sail so instruction implementations
// can access it for control-flow instructions)
// =========================================================================

// Read a byte from memory for instruction fetch.
// Uses PT_Execute access type for paging permission checks (NX bit).
val ifetch_read8 : qword -> byte
function ifetch_read8(addr) = {
  let paddr = translate_addr(addr, PT_Execute);
  phys_read(paddr, 1)
}

val fetch_byte : unit -> byte
function fetch_byte() = {
  // x86 instructions are at most 15 bytes. Raise #GP(0) if exceeded.
  if unsigned(decode_pos) - unsigned(insn_start) >= 15 then {
    throw(Fault(EXN_GP, 0x00000000))
  };
  let b = ifetch_read8(decode_pos);
  decode_pos = decode_pos + 1;
  b
}

// =========================================================================
// Operand size determination
// =========================================================================

// Standard operand size (SDM Vol.1 §3.6).
// LongMode: default OS32, REX.W → OS64, 66h → OS16.
// Non-LongMode, CS.D=1: default OS32, 66h → OS16.
// Non-LongMode, CS.D=0: default OS16, 66h → OS32.
val get_operand_size : Prefixes -> OperandSize
function get_operand_size(pfx) =
  if pfx.rex_w then OS64
  else if cur_mode == LongMode then {
    if pfx.has_opsize then OS16 else OS32
  } else if get_cs_db() == bitone then {
    if pfx.has_opsize then OS16 else OS32
  } else {
    if pfx.has_opsize then OS32 else OS16
  }

// Operand size for instructions that default to 64-bit (PUSH, POP, CALL, RET).
// LongMode: default OS64, 66h → OS16 (OS32 not encodable).
// Non-LongMode, CS.D=1: default OS32, 66h → OS16.
// Non-LongMode, CS.D=0: default OS16, 66h → OS32.
val get_operand_size_d64 : Prefixes -> OperandSize
function get_operand_size_d64(pfx) =
  if cur_mode == LongMode then {
    if pfx.has_opsize then OS16 else OS64
  } else if get_cs_db() == bitone then {
    if pfx.has_opsize then OS16 else OS32
  } else {
    if pfx.has_opsize then OS32 else OS16
  }

// Operand size for instructions forced to 64-bit (JMP rel, CALL rel, Jcc rel).
// LongMode: always OS64, 66h ignored.
// Non-LongMode, CS.D=1: always OS32.
// Non-LongMode, CS.D=0: always OS16.
val get_operand_size_f64 : Prefixes -> OperandSize
function get_operand_size_f64(_pfx) =
  if cur_mode == LongMode then OS64
  else if get_cs_db() == bitone then OS32
  else OS16

// =========================================================================
// Register index helpers (extending 3-bit fields with REX bits)
// =========================================================================

// Extend a 3-bit register field with a REX extension bit to get gpr_idx.
val extend_reg : (range(0, 7), bit) -> gpr_idx
function extend_reg(base, rex_bit) =
  unsigned(rex_bit @ to_bits(3, base))

// Decode the ModR/M reg field (bits 5:3) with REX.R.
val modrm_reg : (byte, Prefixes) -> gpr_idx
function modrm_reg(modrm, pfx) = {
  let r : range(0, 7) = unsigned(modrm[5..3]);
  extend_reg(r, pfx.rex_r)
}

// Decode the ModR/M r/m field (bits 2:0) with REX.B.
val modrm_rm_reg : (byte, Prefixes) -> gpr_idx
function modrm_rm_reg(modrm, pfx) = {
  let r : range(0, 7) = unsigned(modrm[2..0]);
  extend_reg(r, pfx.rex_b)
}

// =========================================================================
// Byte register read/write (handles AH/CH/DH/BH vs SPL/BPL/SIL/DIL)
// =========================================================================

// In byte mode without REX, indices 4-7 mean AH/CH/DH/BH (high byte of
// GPR 0-3). With any REX prefix, they mean SPL/BPL/SIL/DIL (low byte of
// GPR 4-7, or 12-15 with REX.B).

val read_byte_reg : (gpr_idx, bool) -> byte
function read_byte_reg(idx, has_rex) =
  if not_bool(has_rex) & 4 <= idx & idx <= 7 then
    read_gpr8h(idx - 4)
  else
    read_gpr8l(idx)

val write_byte_reg : (gpr_idx, bool, byte) -> unit
function write_byte_reg(idx, has_rex, v) =
  if not_bool(has_rex) & 4 <= idx & idx <= 7 then
    write_gpr8h(idx - 4, v)
  else
    write_gpr8l(idx, v)

// =========================================================================
// Generic operand read/write through RM union
// =========================================================================

val read_rm_val : (RM, OperandSize, bool) -> qword
function read_rm_val(rm, os, has_rex) = match rm {
  RM_reg(idx) => match os {
    OS8  => zero_extend(read_byte_reg(idx, has_rex)),
    OS16 => zero_extend(read_gpr16(idx)),
    OS32 => zero_extend(read_gpr32(idx)),
    OS64 => read_gpr64(idx),
  },
  RM_mem(addr) => {
    let a = fixup_addr(addr);
    match os {
      OS8  => zero_extend(mem_read8(a)),
      OS16 => zero_extend(mem_read16(a)),
      OS32 => zero_extend(mem_read32(a)),
      OS64 => mem_read64(a),
    }
  },
}

val write_rm_val : (RM, OperandSize, bool, qword) -> unit
function write_rm_val(rm, os, has_rex, v) = match rm {
  RM_reg(idx) => match os {
    OS8  => write_byte_reg(idx, has_rex, v[7..0]),
    OS16 => write_gpr16(idx, v[15..0]),
    OS32 => write_gpr32(idx, v[31..0]),
    OS64 => write_gpr64(idx, v),
  },
  RM_mem(addr) => {
    let a = fixup_addr(addr);
    match os {
      OS8  => mem_write8(a, v[7..0]),
      OS16 => mem_write16(a, v[15..0]),
      OS32 => mem_write32(a, v[31..0]),
      OS64 => mem_write64(a, v),
    }
  },
}

// =========================================================================
// Immediate fetch helpers
// =========================================================================

// Fetch a sign-extended immediate of size Ib (1 byte) -> qword.
val fetch_imm8_sx : unit -> qword
function fetch_imm8_sx() = sign_extend(fetch_byte())

// Fetch an immediate Iz: 16-bit if opsize=16, else 32-bit, sign-extended to 64.
val fetch_imm_z : OperandSize -> qword
function fetch_imm_z(os) = match os {
  OS16 => {
    let lo = fetch_byte();
    let hi = fetch_byte();
    sign_extend(hi @ lo)
  },
  _ => {
    let b0 = fetch_byte();
    let b1 = fetch_byte();
    let b2 = fetch_byte();
    let b3 = fetch_byte();
    sign_extend(b3 @ b2 @ b1 @ b0)
  },
}

// Fetch an immediate Iv: matches operand size. 64-bit only for MOV reg,imm with REX.W.
val fetch_imm_v : OperandSize -> qword
function fetch_imm_v(os) = match os {
  OS8 => zero_extend(fetch_byte()),
  OS16 => {
    let lo = fetch_byte();
    let hi = fetch_byte();
    zero_extend(hi @ lo)
  },
  OS32 => {
    let b0 = fetch_byte();
    let b1 = fetch_byte();
    let b2 = fetch_byte();
    let b3 = fetch_byte();
    zero_extend(b3 @ b2 @ b1 @ b0)
  },
  OS64 => {
    let b0 = fetch_byte();
    let b1 = fetch_byte();
    let b2 = fetch_byte();
    let b3 = fetch_byte();
    let b4 = fetch_byte();
    let b5 = fetch_byte();
    let b6 = fetch_byte();
    let b7 = fetch_byte();
    b7 @ b6 @ b5 @ b4 @ b3 @ b2 @ b1 @ b0
  },
}

// Fetch a 16-bit immediate (always 2 bytes, e.g. for RET imm16).
val fetch_imm16 : unit -> word
function fetch_imm16() = {
  let lo = fetch_byte();
  let hi = fetch_byte();
  hi @ lo
}

// Fetch a 32-bit sign-extended relative offset.
val fetch_rel32 : unit -> qword
function fetch_rel32() = {
  let b0 = fetch_byte();
  let b1 = fetch_byte();
  let b2 = fetch_byte();
  let b3 = fetch_byte();
  sign_extend(b3 @ b2 @ b1 @ b0)
}

// Fetch an 8-bit sign-extended relative offset.
val fetch_rel8 : unit -> qword
function fetch_rel8() = sign_extend(fetch_byte())

// =========================================================================
// Address size determination (for string ops, LOOP, XLAT, etc.)
// =========================================================================

// Address size (SDM Vol.1 §3.6).
// LongMode: default AS64, 67h → AS32.
// Non-LongMode, CS.D=1: default AS32, 67h → AS16.
// Non-LongMode, CS.D=0: default AS16, 67h → AS32.
val get_address_size : Prefixes -> AddressSize
function get_address_size(pfx) =
  if cur_mode == LongMode then {
    if pfx.has_adsize == bitone then AS32 else AS64
  } else if get_cs_db() == bitone then {
    if pfx.has_adsize == bitone then AS16 else AS32
  } else {
    if pfx.has_adsize == bitone then AS32 else AS16
  }

// Fetch a full moffs (memory offset) address.
// Size depends on effective address size: AS64 → 8 bytes, AS32 → 4 bytes,
// AS16 → 2 bytes.
val fetch_moffs : Prefixes -> qword
function fetch_moffs(pfx) = match get_address_size(pfx) {
  AS16 => {
    let b0 = fetch_byte();
    let b1 = fetch_byte();
    zero_extend(b1 @ b0)
  },
  AS32 => {
    let b0 = fetch_byte();
    let b1 = fetch_byte();
    let b2 = fetch_byte();
    let b3 = fetch_byte();
    zero_extend(b3 @ b2 @ b1 @ b0)
  },
  AS64 => {
    let b0 = fetch_byte();
    let b1 = fetch_byte();
    let b2 = fetch_byte();
    let b3 = fetch_byte();
    let b4 = fetch_byte();
    let b5 = fetch_byte();
    let b6 = fetch_byte();
    let b7 = fetch_byte();
    b7 @ b6 @ b5 @ b4 @ b3 @ b2 @ b1 @ b0
  },
}

// =========================================================================
// SIMD register index helpers (extending 3-bit fields with REX bits)
// =========================================================================

val modrm_xmm_reg : (byte, Prefixes) -> simd_idx
function modrm_xmm_reg(modrm, pfx) =
  unsigned(pfx.rex_r @ modrm[5..3])

val modrm_xmm_rm : (byte, Prefixes) -> simd_idx
function modrm_xmm_rm(modrm, pfx) =
  unsigned(pfx.rex_b @ modrm[2..0])

// =========================================================================
// Branchless helpers (used across multiple instruction files)
// =========================================================================

// or_reduce: 1 if any bit is set, 0 otherwise (branchless tree reduction).
val or_reduce_8 : byte -> bits(1)
function or_reduce_8(v) = {
  let r4 : bits(4) = v[7..4] | v[3..0];
  let r2 : bits(2) = r4[3..2] | r4[1..0];
  r2[1..1] | r2[0..0]
}

val or_reduce_16 : word -> bits(1)
function or_reduce_16(v) = or_reduce_8(v[15..8] | v[7..0])

val or_reduce_32 : dword -> bits(1)
function or_reduce_32(v) = or_reduce_16(v[31..16] | v[15..0])

val or_reduce_64 : qword -> bits(1)
function or_reduce_64(v) = or_reduce_32(v[63..32] | v[31..0])

// Branchless blend: select a or b per element based on a single bit.
// sel=0 → a, sel=1 → b.
val blend8 : (byte, byte, bits(1)) -> byte
function blend8(a, b, sel) = {
  let m : byte = sign_extend(sel);
  (a & ~(m)) | (b & m)
}

val blend16 : (word, word, bits(1)) -> word
function blend16(a, b, sel) = {
  let m : word = sign_extend(sel);
  (a & ~(m)) | (b & m)
}

val blend32 : (dword, dword, bits(1)) -> dword
function blend32(a, b, sel) = {
  let m : dword = sign_extend(sel);
  (a & ~(m)) | (b & m)
}

val blend64 : (qword, qword, bits(1)) -> qword
function blend64(a, b, sel) = {
  let m : qword = sign_extend(sel);
  (a & ~(m)) | (b & m)
}

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
  has_adsize = 0b0,
  rex_w = false,
  rex_r = 0b0,
  rex_x = 0b0,
  rex_b = 0b0,
  has_rex = false,
  vex_present = false,
  vex_l = false,
  vex_vvvv = 0,
  vex_w = false,
  evex_present = false,
  evex_ll = 0,
  evex_vvvvv = 0,
  evex_aaa = 0,
  evex_z = 0b0,
  evex_b = false,
  evex_rr = 0b0,
}

// =========================================================================
// Resolved ModR/M operand — either a register or memory address
// =========================================================================

// A resolved ModR/M operand: either a register index or a logical memory
// address (segment + effective address/offset).  Per SDM Vol.3A §3.4, the
// processor translates a logical address to a linear address by:
//   1. checking the offset against the segment limit (§6.3)
//   2. adding the segment base to the offset
// Both steps happen at memory-access time, not during decode.
union RM = {
  RM_reg : GPRRef,
  RM_mem : MemRef,
}

// RIP-relative fixup for effective addresses.  When rip_rel_pending is true,
// the offset was computed with an intermediate decode_pos (before trailing
// imm bytes were fetched).  seg_linear() handles this automatically, so
// instruction code rarely needs to call this directly.
val fixup_addr : qword -> qword
function fixup_addr(addr) =
  if rip_rel_pending then decode_pos + rip_rel_disp
  else addr

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
  phys_read(paddr)
}

val fetch_byte : unit -> byte
function fetch_byte() = {
  // x86 instructions are at most 15 bytes. Raise #GP(0) if exceeded.
  if unsigned(decode_pos) - unsigned(insn_start) >= 15 then {
    throw(Fault(EXN_GP, 0x00000000))
  };
  // In non-long mode, add CS base to form the linear address for fetch.
  // decode_pos holds the instruction pointer (IP/EIP), not the linear address.
  let linear = decode_pos + get_seg_base(CS);
  let b = ifetch_read8(linear);
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
val get_operand_size : Prefixes -> {16, 32, 64}
function get_operand_size(pfx) =
  if pfx.rex_w then {
    64
  } else if cur_mode == LongMode then {
    if pfx.has_opsize then 16 else 32
  } else if get_cs_db() == 0b1 then {
    if pfx.has_opsize then 16 else 32
  } else {
    if pfx.has_opsize then 32 else 16
  }

// Operand size for instructions that default to 64-bit (PUSH, POP, CALL, RET).
// LongMode: default OS64, 66h → OS16 (OS32 not encodable).
// Non-LongMode, CS.D=1: default OS32, 66h → OS16.
// Non-LongMode, CS.D=0: default OS16, 66h → OS32.
val get_operand_size_d64 : Prefixes -> {16, 32, 64}
function get_operand_size_d64(pfx) =
  if cur_mode == LongMode then {
    if pfx.has_opsize then 16 else 64
  } else if get_cs_db() == 0b1 then {
    if pfx.has_opsize then 16 else 32
  } else {
    if pfx.has_opsize then 32 else 16
  }

// Operand size for instructions forced to 64-bit (JMP rel, CALL rel, Jcc rel).
// LongMode: always OS64, 66h ignored.
// Non-LongMode, CS.D=1: always OS32.
// Non-LongMode, CS.D=0: always OS16.
// Operand size for f64 instructions (CALL near, RET near, JMP near).
// In LongMode: forced to OS64 (66h prefix is accepted but overrides to OS16).
// In non-LongMode: same as normal operand size, respecting 66h prefix.
// SDM Vol.2A Table 3-4: "f64" means "64-Bit Mode: Forced to 64-bit operand
// size when in 64-bit mode (prefixes that change operand size are ignored
// for this instruction in 64-bit mode)."
// In non-64-bit modes, the 66h prefix works normally per CS.D setting.
val get_operand_size_f64 : Prefixes -> {16, 32, 64}
function get_operand_size_f64(pfx) =
  if pfx.rex_w then {
    64
  } else if cur_mode == LongMode then {
    if pfx.has_opsize then 16 else 64
  } else if get_cs_db() == 0b1 then {
    if pfx.has_opsize then 16 else 32
  } else {
    if pfx.has_opsize then 32 else 16
  }

// =========================================================================
// Register index helpers (extending 3-bit fields with REX bits)
// =========================================================================

// Decode the ModR/M reg field (bits 5:3) with REX.R.
val modrm_reg : (byte, Prefixes) -> GPRRef
function modrm_reg(modrm, pfx) =
  struct { gpr_idx = unsigned(pfx.rex_r @ modrm[5..3]), has_rex = pfx.has_rex }

// Decode the ModR/M r/m field (bits 2:0) with REX.B.
val modrm_rm_reg : (byte, Prefixes) -> gpr_idx
function modrm_rm_reg(modrm, pfx) =
  unsigned(pfx.rex_b @ modrm[2..0])

// =========================================================================
// Generic operand read/write through RM union
// =========================================================================

val read_rm_val : forall 'os, 'os in {8, 16, 32, 64}. (implicit('os), RM) -> bits('os)
function read_rm_val(os, rm) =
  match rm {
    RM_reg(r) => reg(r),
    RM_mem(m) => read_mem(m),
  }

val write_rm_val : forall 'os, 'os in {8, 16, 32, 64}. (implicit('os), RM, bits('os)) -> unit
function write_rm_val(os, rm, v) =
  match rm {
    RM_reg(r) => reg(r) = v,
    RM_mem(m) => write_mem(m,v),
  }

// Memory-only RM read/write: raise #UD if register operand.
val read_mem_rm : forall 'n, 'n > 0. (implicit('n), RM) -> bits(8 * 'n)
function read_mem_rm(n, rm) =
  match rm {
    RM_reg(_) => raise_UD(),
    RM_mem(m) => read_mem(m),
  }

val write_mem_rm : forall 'n, 'n > 0. (implicit('n), RM, bits(8 * 'n)) -> unit
function write_mem_rm(n, rm, v) =
  match rm {
    RM_reg(_) => raise_UD(),
    RM_mem(m) => write_mem(m,v),
  }

// Register-only RM read/write: raise #UD if memory operand.
val read_reg_rm : forall 'os, 'os in {8, 16, 32, 64}. (implicit('os), RM) -> bits('os)
function read_reg_rm(os, rm) =
  match rm {
    RM_reg(r) => reg(r),
    RM_mem(_) => raise_UD(),
  }

val write_reg_rm : forall 'os, 'os in {8, 16, 32, 64}. (implicit('os), RM, bits('os)) -> unit
function write_reg_rm(os, rm, v) =
  match rm {
    RM_reg(r) => reg(r) = v,
    RM_mem(_) => raise_UD(),
  }

overload rm = {read_rm_val, write_rm_val}
overload rm_mem = {read_mem_rm, write_mem_rm}
overload rm_reg = {read_reg_rm, write_reg_rm}

// =========================================================================
// Immediate fetch helpers
// =========================================================================

// Fetch a sign-extended immediate of size Ib (1 byte) -> qword.
val fetch_imm8_sx : unit -> qword
function fetch_imm8_sx() = sign_extend(fetch_byte())

// Fetch an immediate Iz: 16-bit if opsize=16, else 32-bit, sign-extended to 64.
val fetch_imm_z : {16, 32, 64} -> qword
function fetch_imm_z(os) = match os {
  16 => {
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
val fetch_imm_v : operand_size -> qword
function fetch_imm_v(os) = match os {
  8 => zero_extend(fetch_byte()),
  16 => {
    let lo = fetch_byte();
    let hi = fetch_byte();
    zero_extend(hi @ lo)
  },
  32 => {
    let b0 = fetch_byte();
    let b1 = fetch_byte();
    let b2 = fetch_byte();
    let b3 = fetch_byte();
    zero_extend(b3 @ b2 @ b1 @ b0)
  },
  64 => {
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

// Fetch a 16-bit sign-extended relative offset.
val fetch_rel16 : unit -> qword
function fetch_rel16() = {
  let b0 = fetch_byte();
  let b1 = fetch_byte();
  sign_extend(b1 @ b0)
}

// Fetch an 8-bit sign-extended relative offset.
val fetch_rel8 : unit -> qword
function fetch_rel8() = sign_extend(fetch_byte())

// Fetch a relative offset sized by effective operand size (rel16 or rel32).
// SDM Vol.2: for near CALL/JMP/Jcc, the displacement size matches the
// operand-size attribute: 16-bit in 16-bit mode, 32-bit in 32-bit mode.
// The 66h prefix toggles it: 66h in 16-bit mode → 32-bit offset.
// In 64-bit mode (f64 instructions), always 32-bit (SDM Vol.2 §E.3.3).
val fetch_rel_os : Prefixes -> qword
function fetch_rel_os(pfx) = {
  let use_32 : bool = if cur_mode == LongMode then true
    else if get_cs_db() == 0b1 then ~(pfx.has_opsize)
    else pfx.has_opsize;
  if use_32 then fetch_rel32() else fetch_rel16()
}

// Truncate a branch target to the effective operand size.
// SDM: "In Real-Address Mode, the target operand is truncated to 16 bits."
// In 32-bit protected mode, truncated to 32 bits.
// In 64-bit mode, no truncation.
val truncate_rip : (qword, {16, 32, 64}) -> qword
function truncate_rip(target, os) =
  match os {
    16 => zero_extend(target[15..0]),
    32 => zero_extend(target[31..0]),
    64 => target,
  }

// =========================================================================
// Address size determination (for string ops, LOOP, XLAT, etc.)
// =========================================================================

// Address size (SDM Vol.1 §3.6).
// LongMode: default 64, 67h → 32.
// Non-LongMode, CS.D=1: default 32, 67h → 16.
// Non-LongMode, CS.D=0: default 16, 67h → 32.
val get_address_size : Prefixes -> address_size
function get_address_size(pfx) =
  if cur_mode == LongMode then {
    if pfx.has_adsize == 0b1 then 32 else 64
  } else if get_cs_db() == 0b1 then {
    if pfx.has_adsize == 0b1 then 16 else 32
  } else {
    if pfx.has_adsize == 0b1 then 32 else 16
  }

// Fetch a full moffs (memory offset) address.
// Size depends on effective address size: 64 → 8 bytes, 32 → 4 bytes,
// 16 → 2 bytes.
val fetch_moffs : Prefixes -> qword
function fetch_moffs(pfx) = match get_address_size(pfx) {
  16 => {
    let b0 = fetch_byte();
    let b1 = fetch_byte();
    zero_extend(b1 @ b0)
  },
  32 => {
    let b0 = fetch_byte();
    let b1 = fetch_byte();
    let b2 = fetch_byte();
    let b3 = fetch_byte();
    zero_extend(b3 @ b2 @ b1 @ b0)
  },
  64 => {
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

// Branchless POPCNT
val popcount : forall 'n, 0 < 'n & 'n <= 64. bits('n) -> range(0, 'n)
function popcount(v) = {
  let x1 : qword = zero_extend(v);
  let x2 = (x1 & 0x5555555555555555) + ((x1 >> 1)  & 0x5555555555555555);
  let x3 = (x2 & 0x3333333333333333) + ((x2 >> 2)  & 0x3333333333333333);
  let x4 = (x3 & 0x0f0f0f0f0f0f0f0f) + ((x3 >> 4)  & 0x0f0f0f0f0f0f0f0f);
  let x5 = (x4 & 0x00ff00ff00ff00ff) + ((x4 >> 8)  & 0x00ff00ff00ff00ff);
  let x6 = (x5 & 0x0000ffff0000ffff) + ((x5 >> 16) & 0x0000ffff0000ffff);
  let x7 = (x6 & 0x00000000ffffffff) + ((x6 >> 32) & 0x00000000ffffffff);
  let x = unsigned(x7);
  assert(x <= 'n);
  x
}

// or_reduce: 1 if any bit is set, 0 otherwise (branchless tree reduction).
val or_reduce : forall 'n, 0 < 'n & 'n <= 64. bits('n) -> bits(1)
function or_reduce(v) = {
  let x1 : qword = zero_extend(v);
  let x2 = x1 | (x1 >> 1);
  let x3 = x2 | (x2 >> 2);
  let x4 = x3 | (x3 >> 4);
  let x5 = x4 | (x4 >> 8);
  let x6 = x5 | (x5 >> 16);
  let x7 = x6 | (x6 >> 32);
  x7[0]
}

// is_nonzero: 0 if all bits are zero, 1 otherwise.
val is_nonzero : forall 'n, 0 < 'n & 'n <= 64. bits('n) -> bit
function is_nonzero(v) = or_reduce(v)[0]

// is_zero: 1 if all bits are zero, 0 otherwise.
val is_zero : forall 'n, 0 < 'n & 'n <= 64. bits('n) -> bit
function is_zero(v) = (~(or_reduce(v)))[0]

// is_eq: 1 if a == b, 0 otherwise.
val is_eq : forall 'n, 0 < 'n & 'n <= 64. (bits('n), bits('n)) -> bit
function is_eq(a, b) = is_zero(a ^ b)

// is_gt: 1 if a > b (signed), 0 otherwise.
val is_gt : forall 'n, 0 < 'n & 'n <= 64. (bits('n), bits('n)) -> bit
function is_gt(a, b) = {
  let diff : bits('n + 1) = sign_extend(b) - sign_extend(a);
  diff['n]
}

// is_gt_u: 1 if a > b (unsigned), 0 otherwise.
val is_gt_u : forall 'n, 0 < 'n & 'n <= 64. (bits('n), bits('n)) -> bit
function is_gt_u(a, b) = {
  let diff : bits('n + 1) = zero_extend(b) - zero_extend(a);
  diff['n]
}

// Rotate left/right by a bounded integer amount.
val rotl : forall 'm 'n, 'm >= 'n >= 0. (bits('m), int('n)) -> bits('m)
function rotl(v, shift) = (v << shift) | (v >> ('m - shift))

val rotr : forall 'm 'n, 'm >= 'n >= 0. (bits('m), int('n)) -> bits('m)
function rotr(v, shift) = (v >> shift) | (v << ('m - shift))

// Branchless blend: select a or b per element based on a single bit.
// sel=0 → a, sel=1 → b.
val blend : forall 'n, 0 < 'n. (bits('n), bits('n), bit) -> bits('n)
function blend(a, b, sel) = {
  let m : bits('n) = sign_extend(sel);
  (a & ~(m)) | (b & m)
}

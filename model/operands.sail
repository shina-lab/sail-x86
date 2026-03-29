// x86-64 — Operand types, decode helpers, and operand accessors

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

// SIMD register-or-memory operand (XMM/YMM/ZMM).
// Unlike RM (which carries a GPRRef), XRM carries a simd_idx directly.
union XRM = {
  XRM_reg : simd_idx,
  XRM_mem : MemRef,
}

// Extract simd_idx from XRM, raising #UD if it's a memory operand.
// Use for register-only SIMD instructions.
val xrm_reg : XRM -> simd_idx
function xrm_reg(xm) = match xm {
  XRM_reg(xi) => xi,
  XRM_mem(_)  => { raise_UD(); 0 },
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

// Fetch n bytes from the instruction stream. Returns bits(8*n).
// Uses PT_Execute access type for paging permission checks (NX bit).
// x86 instructions are at most 15 bytes; raises #GP(0) if exceeded.
val fetch : forall 'n, 'n > 0. int('n) -> bits(8 * 'n)
function fetch(n) = {
  if unsigned(decode_pos) - unsigned(insn_start) + n > 15 then {
    throw(Fault(EXN_GP, 0x00000000))
  };
  let addr = decode_pos + get_seg_base(CS);
  let result : bits(8 * 'n) = read_mem_linear(addr, PT_Execute);
  decode_pos = decode_pos + n;
  result
}

// =========================================================================
// Operand size determination
// =========================================================================

// Standard operand size (SDM Vol.1 §3.6).
// LongMode: default OS32, REX.W → OS64, 66h → OS16.
// Non-LongMode, CS.D=1: default OS32, 66h → OS16.
// Non-LongMode, CS.D=0: default OS16, 66h → OS32.
val opsize : Prefixes -> {16, 32, 64}
function opsize(pfx) =
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
val opsize_default64 : Prefixes -> {16, 32, 64}
function opsize_default64(pfx) =
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
val opsize_forced64 : Prefixes -> {16, 32, 64}
function opsize_forced64(pfx) =
  if pfx.rex_w then {
    64
  } else if cur_mode == LongMode then {
    if pfx.has_opsize then 16 else 64
  } else if get_cs_db() == 0b1 then {
    if pfx.has_opsize then 16 else 32
  } else {
    if pfx.has_opsize then 32 else 16
  }

// Operand size for relative displacements (Jcc rel, CALL rel, JMP rel).
// LongMode: always OS32 (66h ignored; displacement is sign-extended to 64).
// Non-LongMode, CS.D=1: default OS32, 66h → OS16.
// Non-LongMode, CS.D=0: default OS16, 66h → OS32.
val opsize_rel : Prefixes -> {16, 32}
function opsize_rel(pfx) =
  if cur_mode == LongMode then {
    32
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
    RM_reg(r) => read_gpr_ref(r),
    RM_mem(m) => read_mem(m),
  }

val write_rm_val : forall 'os, 'os in {8, 16, 32, 64}. (implicit('os), RM, bits('os)) -> unit
function write_rm_val(os, rm, v) =
  match rm {
    RM_reg(r) => write_gpr_ref(r) = v,
    RM_mem(m) => write_mem(m,v),
  }

// Memory-only RM read/write: raise #UD if register operand.
// Size parameter 'n is in bits.
val read_mem_rm : forall 'n, 'n > 0. (implicit('n), RM) -> bits('n)
function read_mem_rm(n, rm) =
  match rm {
    RM_reg(_) => raise_UD(),
    RM_mem(m) => read_mem(m),
  }

val write_mem_rm : forall 'n, 'n > 0. (implicit('n), RM, bits('n)) -> unit
function write_mem_rm(n, rm, v) =
  match rm {
    RM_reg(_) => raise_UD(),
    RM_mem(m) => write_mem(m,v),
  }

// Register-only RM read/write: raise #UD if memory operand.
val read_reg_rm : forall 'os, 'os in {8, 16, 32, 64}. (implicit('os), RM) -> bits('os)
function read_reg_rm(os, rm) =
  match rm {
    RM_reg(r) => read_gpr_ref(r),
    RM_mem(_) => raise_UD(),
  }

val write_reg_rm : forall 'os, 'os in {8, 16, 32, 64}. (implicit('os), RM, bits('os)) -> unit
function write_reg_rm(os, rm, v) =
  match rm {
    RM_reg(r) => write_gpr_ref(r) = v,
    RM_mem(_) => raise_UD(),
  }

overload rm = {read_rm_val, write_rm_val}
overload rm_mem = {read_mem_rm, write_mem_rm}
overload rm_reg = {read_reg_rm, write_reg_rm}

// Alignment check: raises #GP(0) if linear address is not aligned.
// No-op for register operands.
val check_memref_alignment : forall 'a, 'a in {16, 32, 64}. (MemRef, int('a)) -> unit
function check_memref_alignment(m, align) =
  if unsigned(seg_linear(m, 0)) % align != 0 then raise_GP0()

val check_rm_alignment : forall 'a, 'a in {16, 32, 64}. (RM, int('a)) -> unit
function check_rm_alignment(rm, align) = match rm {
  RM_mem(m) => check_memref_alignment(m, align),
  RM_reg(_) => (),
}

overload check_alignment = {check_memref_alignment, check_rm_alignment}

// =========================================================================
// Universal operand accessor v()
// =========================================================================
//
// Mirrors SDM pseudocode style: v(dest) = v(src) + v(dest)
// Works uniformly on gpr_idx, GPRRef, RM, and MemRef operands.
val read_memref_val : forall 'os, 'os in {8, 16, 32, 64}. (implicit('os), MemRef) -> bits('os)
function read_memref_val(os, m) = read_mem(m)

val write_memref_val : forall 'os, 'os in {8, 16, 32, 64}. (implicit('os), MemRef, bits('os)) -> unit
function write_memref_val(os, m, x) = write_mem(m, x)

overload v = {read_memref_val, write_memref_val, read_rm_val, write_rm_val}

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

// =========================================================================
// SIMD register index helpers (extending 3-bit fields with REX bits)
// =========================================================================

val modrm_xreg : (byte, Prefixes) -> simd_idx
function modrm_xreg(modrm, pfx) =
  unsigned(pfx.rex_r @ modrm[5..3])

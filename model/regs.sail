// x86-64 Sail Model — Register Definitions

// =========================================================================
// Instruction pointer
// =========================================================================

register RIP : qword

// Branch target set by control-flow instructions (JMP, CALL, RET, Jcc).
// When Some, step() uses this instead of decode_pos to update RIP.
register next_rip : option(qword) = None()

// =========================================================================
// General-purpose registers
//
// x86-64 has 16 64-bit GPRs. Sub-register access (e.g. AL, AX, EAX)
// is handled by the read/write functions below.
// =========================================================================

register GPR : vector(16, qword)

// Read a full 64-bit GPR.
val read_gpr64 : gpr_idx -> qword
function read_gpr64(idx) = GPR[idx]

// Write a full 64-bit GPR.
val write_gpr64 : (gpr_idx, qword) -> unit
function write_gpr64(idx, v) = GPR[idx] = v

// Read the low 32 bits of a GPR.
val read_gpr32 : gpr_idx -> dword
function read_gpr32(idx) = GPR[idx][31..0]

// Write to the low 32 bits of a GPR.
// Per x86-64 convention, writing a 32-bit register zero-extends to 64 bits.
val write_gpr32 : (gpr_idx, dword) -> unit
function write_gpr32(idx, v) = GPR[idx] = zero_extend(v)

// Read the low 16 bits of a GPR.
val read_gpr16 : gpr_idx -> word
function read_gpr16(idx) = GPR[idx][15..0]

// Write to the low 16 bits of a GPR.
// 16-bit writes do NOT zero-extend; upper bits are preserved.
val write_gpr16 : (gpr_idx, word) -> unit
function write_gpr16(idx, v) = {
  let old = GPR[idx];
  GPR[idx] = old[63..16] @ v
}

// Read the low 8 bits of a GPR.
val read_gpr8l : gpr_idx -> byte
function read_gpr8l(idx) = GPR[idx][7..0]

// Write to the low 8 bits of a GPR.
// 8-bit writes preserve upper bits.
val write_gpr8l : (gpr_idx, byte) -> unit
function write_gpr8l(idx, v) = {
  let old = GPR[idx];
  GPR[idx] = old[63..8] @ v
}

// Read bits [15:8] of a GPR (AH, BH, CH, DH — only for GPR 0-3).
val read_gpr8h : gpr_idx -> byte
function read_gpr8h(idx) = GPR[idx][15..8]

// Write to bits [15:8] of a GPR.
val write_gpr8h : (gpr_idx, byte) -> unit
function write_gpr8h(idx, v) = {
  let old = GPR[idx];
  GPR[idx] = old[63..16] @ v @ old[7..0]
}

// Polymorphic GPR read by operand size.
val read_gpr : (gpr_idx, OperandSize) -> qword
function read_gpr(idx, os) = match os {
  OS8  => zero_extend(read_gpr8l(idx)),
  OS16 => zero_extend(read_gpr16(idx)),
  OS32 => zero_extend(read_gpr32(idx)),
  OS64 => read_gpr64(idx),
}

// Polymorphic GPR write by operand size.
val write_gpr : (gpr_idx, OperandSize, qword) -> unit
function write_gpr(idx, os, v) = match os {
  OS8  => write_gpr8l(idx, v[7..0]),
  OS16 => write_gpr16(idx, v[15..0]),
  OS32 => write_gpr32(idx, v[31..0]),
  OS64 => write_gpr64(idx, v),
}

// Named GPR indices for readability.
let RAX : gpr_idx = 0
let RCX : gpr_idx = 1
let RDX : gpr_idx = 2
let RBX : gpr_idx = 3
let RSP : gpr_idx = 4
let RBP : gpr_idx = 5
let RSI : gpr_idx = 6
let RDI : gpr_idx = 7
let R8  : gpr_idx = 8
let R9  : gpr_idx = 9
let R10 : gpr_idx = 10
let R11 : gpr_idx = 11
let R12 : gpr_idx = 12
let R13 : gpr_idx = 13
let R14 : gpr_idx = 14
let R15 : gpr_idx = 15

// =========================================================================
// SIMD registers (XMM/YMM/ZMM)
//
// We model the full 512-bit ZMM registers. XMM and YMM access the
// low 128 and 256 bits respectively.
// x86-64 has 16 registers (0-15), AVX-512 extends to 32.
// =========================================================================

type simd_idx = range(0, 31)

register ZMM : vector(32, zmmword)

val read_xmm : simd_idx -> xmmword
function read_xmm(idx) = ZMM[idx][127..0]

val write_xmm : (simd_idx, xmmword) -> unit
function write_xmm(idx, v) = {
  var r : zmmword = zeros();
  r[127..0] = v;
  ZMM[idx] = r
}

// VEX-encoded write: zero upper bits (128->MAXVL)
val write_xmm_vex : (simd_idx, xmmword) -> unit
function write_xmm_vex(idx, v) = write_xmm(idx, v)

val read_ymm : simd_idx -> ymmword
function read_ymm(idx) = ZMM[idx][255..0]

val write_ymm : (simd_idx, ymmword) -> unit
function write_ymm(idx, v) = {
  var r : zmmword = zeros();
  r[255..0] = v;
  ZMM[idx] = r
}

val read_zmm : simd_idx -> zmmword
function read_zmm(idx) = ZMM[idx]

val write_zmm : (simd_idx, zmmword) -> unit
function write_zmm(idx, v) = ZMM[idx] = v

// Legacy SSE write: preserves upper bits beyond 128
val write_xmm_legacy : (simd_idx, xmmword) -> unit
function write_xmm_legacy(idx, v) = {
  var r : zmmword = ZMM[idx];
  r[127..0] = v;
  ZMM[idx] = r
}

// =========================================================================
// AVX-512 Opmask registers (k0-k7)
//
// k0 is special: when used as a writemask, it means "no masking" (all 1s).
// k1-k7 are general-purpose mask registers.
// =========================================================================

type kreg_idx = range(0, 7)

register KREG : vector(8, qword)

val read_kreg : kreg_idx -> qword
function read_kreg(idx) = KREG[idx]

val write_kreg : (kreg_idx, qword) -> unit
function write_kreg(idx, v) = KREG[idx] = v

// =========================================================================
// Segment registers
// =========================================================================

register SegReg : vector(6, word)

val read_segreg : segreg_idx -> word
function read_segreg(idx) = SegReg[idx]

val write_segreg : (segreg_idx, word) -> unit
function write_segreg(idx, v) = SegReg[idx] = v

// FS and GS segment base addresses (used in 64-bit mode for TLS).
// In 64-bit mode, only FS and GS have non-zero bases.
register FS_BASE : qword
register GS_BASE : qword

// =========================================================================
// Processor mode and privilege
// =========================================================================

register cur_mode : ProcessorMode
register cur_cpl : cpl_t

// =========================================================================
// Decode position
//
// Tracks the current position in the instruction stream during decoding.
// Placed here (rather than in decode/) so instruction implementations
// can access it for control-flow instructions (CALL, JMP, RET, Jcc).
// =========================================================================

register decode_pos : qword

// RIP-relative fixup state: when decode_rm sees mod=00 rm=101 (RIP+disp32),
// it saves decode_pos after consuming the displacement bytes. If the
// instruction has trailing bytes (imm8, imm32), decode_pos will advance
// further. The fixup delta (decode_pos - rip_rel_saved_pos) is added to
// the preliminary RM_mem address at use time.
register rip_rel_pending : bool
register rip_rel_disp : qword

// =========================================================================
// String operation index register helpers
//
// Address size (67h prefix) selects RCX/RSI/RDI vs ECX/ESI/EDI.
// Placed here so all string instruction files can use them.
// =========================================================================

val read_count_reg : AddressSize -> qword
function read_count_reg(asz) = match asz {
  AS32 => zero_extend(read_gpr32(RCX)),
  _    => read_gpr64(RCX),
}

val write_count_reg : (AddressSize, qword) -> unit
function write_count_reg(asz, v) = match asz {
  AS32 => write_gpr32(RCX, v[31..0]),
  _    => write_gpr64(RCX, v),
}

val read_index_src : AddressSize -> qword
function read_index_src(asz) = match asz {
  AS32 => zero_extend(read_gpr32(RSI)),
  _    => read_gpr64(RSI),
}

val write_index_src : (AddressSize, qword) -> unit
function write_index_src(asz, v) = match asz {
  AS32 => write_gpr32(RSI, v[31..0]),
  _    => write_gpr64(RSI, v),
}

val read_index_dst : AddressSize -> qword
function read_index_dst(asz) = match asz {
  AS32 => zero_extend(read_gpr32(RDI)),
  _    => read_gpr64(RDI),
}

val write_index_dst : (AddressSize, qword) -> unit
function write_index_dst(asz, v) = match asz {
  AS32 => write_gpr32(RDI, v[31..0]),
  _    => write_gpr64(RDI, v),
}

// VSIB (Vector SIB) addressing info for gather/scatter
struct VSIB = {
  vsib_base : qword,        // base address (GPR + displacement)
  vsib_vidx : simd_idx,     // vector register containing indices
  vsib_scale : range(0, 3), // scale factor (0=1, 1=2, 2=4, 3=8)
}

// x86-64 — Register Definitions

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

// Polymorphic GPR read by operand size.
val read_gpr : forall 'os, 'os in {8, 16, 32, 64}. (implicit('os), gpr_idx) -> bits('os)
function read_gpr(os, idx) = match os {
  8  => GPR[idx][7..0],
  16 => GPR[idx][15..0],
  32 => GPR[idx][31..0],
  64 => GPR[idx]
}

// Polymorphic GPR write by operand size.
val write_gpr : forall 'os, 'os in {8, 16, 32, 64}. (implicit('os), gpr_idx, bits('os)) -> unit
function write_gpr(os, idx, v) = match os {
  8  => GPR[idx] = GPR[idx][63..8] @ v,
  16 => GPR[idx] = GPR[idx][63..16] @ v,
  32 => GPR[idx] = zero_extend(v),
  64 => GPR[idx] = v
}

// Polymorphic GPR read via GPRRef.
// In byte mode without REX, indices 4-7 mean AH/CH/DH/BH (high byte of
// GPR 0-3). With any REX prefix, they mean SPL/BPL/SIL/DIL.
val read_gpr_ref : forall 'os, 'os in {8, 16, 32, 64}. (implicit('os), GPRRef) -> bits('os)
function read_gpr_ref(os, r) = {
  let idx = r.gpr_idx;
  if os == 8 then {
    if ~(r.has_rex) & 4 <= idx & idx <= 7 then
      GPR[idx - 4][15..8]
    else
      GPR[idx][7..0]
  } else {
    read_gpr(idx)
  }
}

// Polymorphic GPR write via GPRRef.
val write_gpr_ref : forall 'os, 'os in {8, 16, 32, 64}. (implicit('os), GPRRef, bits('os)) -> unit
function write_gpr_ref(os, r, v) = {
  let idx = r.gpr_idx;
  if os == 8 then {
    if ~(r.has_rex) & 4 <= idx & idx <= 7 then
      GPR[idx - 4][15..8] = v
    else
      GPR[idx][7..0] = v
  } else {
    write_gpr(idx, v)
  }
}

overload v = {read_gpr, write_gpr, read_gpr_ref, write_gpr_ref}

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
// x87 FPU Register State
//
// The x87 FPU has an 8-register stack of 80-bit extended precision values.
// Registers are accessed relative to the TOP pointer in the status word.
// The full state includes the control word, status word, and tag word.
// =========================================================================

register x87_ST : vector(8, fp80)
register x87_cw : word    // control word (default 0x037F)
register x87_sw : word    // status word (default 0x0000)
register x87_tw : word    // tag word (default 0xFFFF = all empty)

val x87_top : unit -> range(0, 7)
function x87_top() = unsigned(x87_sw[13..11])

val x87_set_top : int -> unit
function x87_set_top(t) = {
  x87_sw[13..11] = to_bits_truncate(3, t)
}

val x87_physical : int -> range(0, 7)
function x87_physical(i) = unsigned(to_bits_truncate(3, x87_top() + i))

// Tag word helpers: each register has a 2-bit tag at bits [2*phys+1 .. 2*phys].
// Tag value 3 = empty, anything else = valid.
val x87_mark_valid : range(0, 7) -> unit
function x87_mark_valid(phys) = {
  let shift_amt = 2 * phys;
  let mask : word = ~(0x0003 << shift_amt);
  x87_tw = x87_tw & mask
}

val x87_mark_empty : range(0, 7) -> unit
function x87_mark_empty(phys) = {
  let shift_amt = 2 * phys;
  let bits : word = 0x0003 << shift_amt;
  x87_tw = x87_tw | bits
}

// Read ST(i) — the i-th register from the top of the x87 stack.
val x87_read_st : int -> fp80
function x87_read_st(i) = x87_ST[x87_physical(i)]

// Write a value to ST(i).
val x87_write_st : (int, fp80) -> unit
function x87_write_st(i, v) = {
  x87_ST[x87_physical(i)] = v
}

// Push a value onto the x87 stack (decrement TOP, write to new ST(0)).
val x87_push : fp80 -> unit
function x87_push(v) = {
  let new_top = x87_physical(-1);
  x87_set_top(new_top);
  x87_ST[new_top] = v;
  x87_mark_valid(new_top)
}

// Pop the top of the x87 stack (read ST(0), increment TOP).
val x87_pop : unit -> fp80
function x87_pop() = {
  let cur_top = x87_top();
  let result = x87_ST[cur_top];
  x87_mark_empty(cur_top);
  x87_set_top(x87_physical(1));
  result
}

// Mark ST(i) as empty (used by FFREE).
val x87_free : int -> unit
function x87_free(i) = x87_mark_empty(x87_physical(i))

// Decrement TOP (used by FDECSTP).
val x87_dec_top : unit -> unit
function x87_dec_top() = x87_set_top(x87_physical(-1))

// Increment TOP (used by FINCSTP).
val x87_inc_top : unit -> unit
function x87_inc_top() = x87_set_top(x87_physical(1))

// Initialize x87 state (used by FINIT/FNINIT).
val x87_init : unit -> unit
function x87_init() = {
  x87_cw = 0x037F;
  x87_sw = 0x0000;
  x87_tw = 0xFFFF;
  foreach (i from 0 to 7) {
    x87_ST[i] = zeros()
  }
}

// =========================================================================
// MMX register access
//
// MMX registers MM0-MM7 alias the low 64 bits of the x87 physical registers
// ST(0)-ST(7), accessed by physical index (not relative to TOP).
// Writing an MMX register sets bits [79:64] to all ones and marks the tag
// as valid. All MMX instructions also set TOS (TOP) to 0 and mark all
// tag bits as valid (tag word = 0x0000).
// =========================================================================

// Called on any MMX instruction: set TOS=0, all tags=valid.
val mmx_touch : unit -> unit
function mmx_touch() = {
  x87_sw[13..11] = 0b000;  // TOP = 0
  x87_tw = 0x0000          // all valid
}

// Save 28-byte x87 environment (CW, SW, TW) as bits(224).
val x87_save_env : unit -> bits(224)
function x87_save_env() = {
  var buf : bits(224) = zeros();
  buf[15..0] = x87_cw;
  buf[47..32] = x87_sw;
  buf[79..64] = x87_tw;
  buf
}

// Load 28-byte x87 environment from bits(224).
val x87_load_env : bits(224) -> unit
function x87_load_env(buf) = {
  x87_cw = buf[15..0];
  x87_sw = buf[47..32];
  x87_tw = buf[79..64]
}

// Save full x87 state (28 bytes env + 8 x 10 bytes regs) as bits(864).
val x87_save_state : unit -> bits(864)
function x87_save_state() = {
  var buf : bits(864) = zeros();
  buf[15..0] = x87_cw;
  buf[47..32] = x87_sw;
  buf[79..64] = x87_tw;
  foreach (i from 0 to 7) {
    let lo = 224 + i * 80;
    buf[(lo + 79) .. lo] = x87_ST[i]
  };
  buf
}

// Load full x87 state from bits(864).
val x87_load_state : bits(864) -> unit
function x87_load_state(buf) = {
  x87_cw = buf[15..0];
  x87_sw = buf[47..32];
  x87_tw = buf[79..64];
  foreach (i from 0 to 7) {
    let lo = 224 + i * 80;
    x87_ST[i] = buf[(lo + 79) .. lo]
  }
}

// =========================================================================
// SIMD registers (XMM/YMM/ZMM)
//
// We model the full 512-bit ZMM registers. XMM and YMM access the
// low 128 and 256 bits respectively.
// x86-64 has 16 registers (0-15), AVX-512 extends to 32.
// =========================================================================

type simd_idx = range(0, 31)

register ZMM : vector(32, zmmword)

// Polymorphic SIMD read by vector length.
val read_simd : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), simd_idx) -> bits('vl)
function read_simd(vl, idx) = match vl {
  128 => ZMM[idx][127..0],
  256 => ZMM[idx][255..0],
  512 => ZMM[idx]
}

// Polymorphic SIMD write by vector length (zeros upper bits).
val write_simd : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), simd_idx, bits('vl)) -> unit
function write_simd(vl, idx, v) = match vl {
  128 => { ZMM[idx][511..128] = zeros(); ZMM[idx][127..0] = v },
  256 => { ZMM[idx][511..256] = zeros(); ZMM[idx][255..0] = v },
  512 => ZMM[idx] = v
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

// Segment descriptor caches (hidden part of each segment register).
// Per SDM Vol.3A §3.4.3, loaded from GDT/LDT on segment register write.
register SegCache : vector(6, SegDescCache)

val read_segreg : segreg_idx -> word
function read_segreg(idx) = SegReg[idx]

val write_segreg : (segreg_idx, word) -> unit
function write_segreg(idx, v) = SegReg[idx] = v

// Kernel GS base (shadow register swapped with SegCache[GS].seg_base by SWAPGS).
register KERNEL_GS_BASE : qword

// =========================================================================
// Processor mode and privilege
// =========================================================================

register cur_mode : ProcessorMode
register cur_cpl : cpl_t

// =========================================================================
// Descriptor table registers
// =========================================================================

register GDTR_base  : qword
register GDTR_limit : word
register IDTR_base  : qword
register IDTR_limit : word
register LDTR       : word   // LDT selector
register TR         : word   // Task register selector

// TSS base and limit (loaded from GDT when LTR executes)
register TR_base  : qword
register TR_limit : dword

// =========================================================================
// Segment descriptor cache helpers
// =========================================================================

// Get the linear base address of a segment.
// In LongMode, ES/CS/SS/DS are treated as base 0 (SDM Vol.3A §3.4.4);
// FS and GS bases are stored in SegCache (set via MSR or descriptor load).
// In other modes, all segment bases come from the descriptor cache.
val get_seg_base : segreg_idx -> qword
function get_seg_base(seg) =
  if cur_mode == LongMode & seg != FS & seg != GS
  then 0x0000000000000000
  else SegCache[seg].seg_base

// Get the CS.D bit (default operation size).
// Returns 0b1 when CS.D=1 (32-bit default), 0b0 when CS.D=0 (16-bit).
val get_cs_db : unit -> bit
function get_cs_db() = SegCache[CS].seg_db

// Parse an 8-byte segment descriptor into a SegDescCache (SDM Vol.3A §3.4.5).
// lo = descriptor bytes [3:0], hi = descriptor bytes [7:4].
val parse_seg_descriptor : (dword, dword) -> SegDescCache
function parse_seg_descriptor(lo, hi) = {
  // Base address: hi[31:24] @ hi[7:0] @ lo[31:16]
  let base : dword = hi[31..24] @ hi[7..0] @ lo[31..16];
  // Limit: hi[19:16] @ lo[15:0]  (20-bit raw limit)
  let raw_limit : bits(20) = hi[19..16] @ lo[15..0];
  // Granularity: if G=1, scale limit by 4KB (shift left 12, fill low bits)
  let g : bit = hi[23];
  let limit : dword = if g == 0b1 then zero_extend(raw_limit) @ 0xFFF
                      else zero_extend(raw_limit);
  struct {
    seg_base    = zero_extend(base),
    seg_limit   = limit,
    seg_type    = hi[11..8],
    seg_s       = hi[12],
    seg_dpl     = unsigned(hi[14..13]),
    seg_present = hi[15],
    seg_db      = hi[22],
    seg_l       = hi[21],
    seg_g       = g,
  }
}

// load_segment_register is defined in mem.sail (needs mem_read32).

// =========================================================================
// Decode position
//
// Tracks the current position in the instruction stream during decoding.
// Placed here (rather than in decode/) so instruction implementations
// can access it for control-flow instructions (CALL, JMP, RET, Jcc).
// =========================================================================

register decode_pos : qword

// Start of current instruction (set to RIP at beginning of step()).
// Used to enforce the 15-byte maximum instruction length.
register insn_start : qword

// Instruction buffer for Isla symbolic execution.
// Holds up to 15 instruction bytes (120 bits) in little-endian order:
// bits [7..0] = byte at offset 0, bits [15..8] = byte at offset 1, etc.
// The splice file overrides fetch() to read from this register
// instead of memory, because Isla's symbolic memory model does not
// connect writes to subsequent reads at the same address.
register insn_buf : bits(120) = zeros()

// Output register for ISLA equivalence proofs.
register Final_result : bits(128) = zeros()

// Symbolic data-memory window for ISLA equivalence proofs: 256 bytes at
// 0x7000.  The splice file routes phys_read/phys_write here so that a
// load at a concrete address is a shared symbolic input.  Unused by the
// emulator.
register mem_window : bits(2048)

// RIP-relative fixup state: when modrm_rm sees mod=00 rm=101 (RIP+disp32),
// it saves decode_pos after consuming the displacement bytes. If the
// instruction has trailing bytes (imm8, imm32), decode_pos will advance
// further. The fixup delta (decode_pos - rip_rel_saved_pos) is added to
// the preliminary RM_mem address at use time.
register rip_rel_pending : bool
register rip_rel_disp : qword

// VSIB (Vector SIB) addressing info for gather/scatter
struct VSIB = {
  vsib_base : qword,        // base address (GPR + displacement)
  vsib_vidx : simd_idx,     // vector register containing indices
  vsib_scale : range(0, 3), // scale factor (0=1, 1=2, 2=4, 3=8)
}

// =========================================================================
// Control registers (system-level)
// =========================================================================

register CR0  : qword   // PE, PG, WP, etc.
register CR2  : qword   // Page Fault Linear Address
register CR3  : qword   // Page table base
register CR4  : qword   // PAE, PSE, OSFXSR, OSXSAVE, etc.
register CR8  : bits(4) // Task Priority Register (TPR), bits 3:0
register EFER : qword   // Extended Feature Enable Register

// Debug registers
// Default values are specified by SDM
register DR0  : qword = 0x0000000000000000  // Linear breakpoint address 0
register DR1  : qword = 0x0000000000000000  // Linear breakpoint address 1
register DR2  : qword = 0x0000000000000000  // Linear breakpoint address 2
register DR3  : qword = 0x0000000000000000  // Linear breakpoint address 3
register DR6  : qword = 0x00000000FFFF0FF0  // Debug status
register DR7  : qword = 0x0000000000000400  // Debug control

// Single-step bookkeeping, maintained by step() and deliver_exception
// (SDM Vol.3B §20.3.1.4, Vol.3A §7.8.3):
//   event_delivered — an exception or interrupt went through the IDT during
//                     the current instruction (INT n, INT3, INTO, INT1, a
//                     fault); such an instruction gets no single-step trap.
//   ss_shadow       — 2 right after MOV SS/POP SS, 1 through the following
//                     instruction, 0 otherwise: suppresses the trap after the
//                     SS load and holds external interrupts until after the
//                     next instruction.
register event_delivered : bool = false
register ss_shadow : range(0, 2) = 0

// CR0 bit positions
let CR0_PE : int = 0    // Protection Enable
let CR0_MP : int = 1    // Monitor Coprocessor
let CR0_EM : int = 2    // Emulation
let CR0_TS : int = 3    // Task Switched
let CR0_ET : int = 4    // Extension Type
let CR0_NE : int = 5    // Numeric Error
let CR0_WP : int = 16   // Write Protect
let CR0_AM : int = 18   // Alignment Mask
let CR0_NW : int = 29   // Not Write-through
let CR0_CD : int = 30   // Cache Disable
let CR0_PG : int = 31   // Paging

// CR4 bit positions
let CR4_VME        : int = 0   // Virtual-8086 Mode Extensions
let CR4_PVI        : int = 1   // Protected-Mode Virtual Interrupts
let CR4_TSD        : int = 2   // Time Stamp Disable
let CR4_DE         : int = 3   // Debugging Extensions
let CR4_PSE        : int = 4   // Page Size Extensions
let CR4_PAE        : int = 5   // Physical Address Extension
let CR4_MCE        : int = 6   // Machine-Check Enable
let CR4_PGE        : int = 7   // Page Global Enable
let CR4_PCE        : int = 8   // Performance-Monitoring Counter Enable
let CR4_OSFXSR     : int = 9   // OS Support for FXSAVE/FXRSTOR
let CR4_OSXMMEXCPT : int = 10  // OS Support for Unmasked SIMD FP Exceptions
let CR4_LA57       : int = 12  // 5-Level Paging
let CR4_FSGSBASE   : int = 16  // FSGSBASE Enable
let CR4_PCIDE      : int = 17  // PCID Enable
let CR4_VMXE       : int = 13  // VMX Enable
let CR4_OSXSAVE    : int = 18  // XSAVE and Processor Extended States Enable

// EFER bit positions
let EFER_SCE : int = 0   // SYSCALL Enable
let EFER_LME : int = 8   // Long Mode Enable
let EFER_LMA : int = 10  // Long Mode Active
let EFER_NXE : int = 11  // No-Execute Enable

// =========================================================================
// Extended Control Register 0 (XCR0) and CPUID feature flags
//
// XCR0 controls OS-level enabling of XSAVE-managed state components.
// XCR0_SUPPORTED defines the hardware (silicon) mask; XCR0 <= XCR0_SUPPORTED.
// CPUID feature flags model silicon-fixed features (BMI, POPCNT, etc.).
// All are set at init time; Isla treats them as constants.
// =========================================================================

register XCR0           : qword  // Extended Control Register 0 (OS-enabled state)
register XCR0_SUPPORTED : qword  // Which XCR0 bits this "CPU" supports (silicon mask)

// XCR0 bit position constants (SDM Table 13-1)
let XCR0_X87       : int = 0
let XCR0_SSE       : int = 1
let XCR0_AVX       : int = 2
let XCR0_OPMASK    : int = 5
let XCR0_ZMM_HI256 : int = 6
let XCR0_HI16_ZMM  : int = 7
let XCR0_TILECFG   : int = 17
let XCR0_TILEDATA  : int = 18

// CPUID feature flag registers (concrete booleans, set at init)
register has_sse3      : bool  // CPUID.01H:ECX[0]
register has_ssse3     : bool  // CPUID.01H:ECX[9]
register has_sse4_1    : bool  // CPUID.01H:ECX[19]
register has_sse4_2    : bool  // CPUID.01H:ECX[20]
register has_cx16      : bool  // CPUID.01H:ECX[13] — CMPXCHG16B
register has_popcnt    : bool
register has_lzcnt     : bool
register has_bmi1      : bool
register has_bmi2      : bool
register has_fma       : bool
register has_aesni     : bool
register has_pclmulqdq : bool
register has_vpclmulqdq : bool // CPUID.07H:ECX[10] — VEX.256 and EVEX VPCLMULQDQ
register has_vaes      : bool  // CPUID.07H:ECX[9] — VEX.256 and EVEX VAESENC/VAESENCLAST/VAESDEC/VAESDECLAST
register has_gfni      : bool  // CPUID.07H:ECX[8] — GF2P8AFFINEQB/GF2P8AFFINEINVQB/GF2P8MULB in every encoding
register has_avx_vnni  : bool  // CPUID.(07H,1):EAX[4] — VEX VPDPBUSD/VPDPBUSDS/VPDPWSSD/VPDPWSSDS
register has_f16c      : bool
register has_movbe     : bool
register has_adx       : bool
register has_sha       : bool
register has_rdrand    : bool
register has_rdseed    : bool
register has_crc32     : bool
register has_movdiri   : bool
register has_movdir64b : bool
register has_xsave     : bool  // XSAVE/XRSTOR, XSETBV/XGETBV, XCR0 (CPUID.01H:ECX[26])
register has_avx512    : bool  // silicon support (separate from XCR0 enable)
register has_la57      : bool  // CPUID.07H:ECX[16] — 5-Level Paging
register has_vmx       : bool  // CPUID.01H:ECX[5] — VMX support

// Vendor profile for the values the SDM leaves to the implementation and
// on which the two vendors differ: the standard-format XSAVE offsets of
// the AVX-512 components (CPUID.0DH.n:EBX) and MXCSR_MASK.  See
// xsave_std_offset and mxcsr_mask in insn_xsave.sail.  The CPUID vendor
// string stays "GenuineIntel" either way.  The KVM differential harness
// selects the host's vendor so that both profiles are checked against
// silicon; the emulators keep the Intel default.
enum Vendor = { Vendor_Intel, Vendor_AMD }
register vendor : Vendor = Vendor_Intel

// =========================================================================
// XCR0 / feature check helpers
// =========================================================================

// AVX enabled: CR4.OSXSAVE(bit 18)=1 and XCR0.SSE(bit 1)=1, AVX(bit 2)=1
val avx_enabled : unit -> bool
function avx_enabled() =
  CR4[18] == 0b1 & XCR0[2] == 0b1 & XCR0[1] == 0b1

// AVX-512 enabled: AVX enabled + silicon support + XCR0 bits 5,6,7
val avx512_enabled : unit -> bool
function avx512_enabled() =
  avx_enabled() & has_avx512 &
  XCR0[5] == 0b1 & XCR0[6] == 0b1 & XCR0[7] == 0b1

// Legacy SSE blocked by CR0.EM(bit 2)=1
val sse_em_blocked : unit -> bool
function sse_em_blocked() = CR0[2] == 0b1

// =========================================================================
// Convenience functions: configure features by processor level
// =========================================================================

// x86-64-v1: Baseline 64-bit (SSE2 only, no extensions)
val enable_features_v1 : unit -> unit
function enable_features_v1() = {
  // CR0: clear EM, set MP
  CR0 = (CR0 & 0xFFFFFFFFFFFFFFFB) | 0x0000000000000002;
  // CR4: OSFXSR + OSXMMEXCPT
  CR4 = CR4 | 0x0000000000000600;
  XCR0_SUPPORTED = 0x0000000000000003;  // x87 + SSE
  XCR0 = 0x0000000000000003;
  // All CPUID features off
  has_sse3 = false;
  has_ssse3 = false;
  has_sse4_1 = false;
  has_sse4_2 = false;
  has_cx16 = false;
  has_popcnt = false;
  has_lzcnt = false;
  has_bmi1 = false;
  has_bmi2 = false;
  has_fma = false;
  has_aesni = false;
  has_pclmulqdq = false;
  has_vpclmulqdq = false;
  has_vaes = false;
  has_gfni = false;
  has_avx_vnni = false;
  has_f16c = false;
  has_movbe = false;
  has_adx = false;
  has_sha = false;
  has_rdrand = false;
  has_rdseed = false;
  has_crc32 = false;
  has_xsave = false;
  has_avx512 = false;
  has_vmx = false
}

// x86-64-v2: Nehalem+ (SSE4.2, POPCNT, CMPXCHG16B)
val enable_features_v2 : unit -> unit
function enable_features_v2() = {
  enable_features_v1();
  has_sse3 = true;
  has_ssse3 = true;
  has_sse4_1 = true;
  has_sse4_2 = true;
  has_cx16 = true;
  has_xsave = true;
  has_popcnt = true;
  has_crc32 = true;
  has_pclmulqdq = true;
  has_vmx = true
}

// x86-64-v3: Haswell+ (AVX2, FMA, BMI1/2, MOVBE, F16C)
val enable_features_v3 : unit -> unit
function enable_features_v3() = {
  enable_features_v2();
  CR4 = CR4 | 0x0000000000040000;  // OSXSAVE
  XCR0_SUPPORTED = 0x0000000000000007;  // x87 + SSE + AVX
  XCR0 = 0x0000000000000007;
  has_bmi1 = true;
  has_bmi2 = true;
  has_fma = true;
  has_lzcnt = true;
  has_f16c = true;
  has_movbe = true;
  has_rdrand = true;
  has_aesni = true;
  has_adx = true
}

// x86-64-v4 and everything above it that the model implements: AVX-512
// (F/CD/BW/DQ/VL and the sub-extensions advertised in cpuid), SHA, RDSEED,
// GFNI, VAES, VPCLMULQDQ, AVX-VNNI
val enable_features_v4 : unit -> unit
function enable_features_v4() = {
  enable_features_v3();
  XCR0_SUPPORTED = 0x00000000000000E7;  // + opmask + ZMM_Hi256 + Hi16_ZMM
  XCR0 = 0x00000000000000E7;
  has_avx512 = true;
  has_rdseed = true;
  has_sha = true;
  has_vpclmulqdq = true;
  has_vaes = true;
  has_gfni = true;
  has_avx_vnni = true
}

// All features (current default behavior, matches XCR0=0xE7)
val enable_features_all : unit -> unit
function enable_features_all() = {
  enable_features_v4()
}

// =========================================================================
// System mode flag
//
// When true, faults are delivered via IDT (system-level emulation).
// When false, faults return to the C++ harness (user-mode emulation).
// =========================================================================

register system_mode : bool

// Exception delivery nesting depth (0 = normal, 1 = delivering, 2 = double fault)
// Used to detect double fault and triple fault conditions.
register exception_depth : range(0, 3)

// Class of the exception currently being delivered (for escalation decisions).
register delivering_exc_class : ExceptionClass

// =========================================================================
// System Management Mode (SMM) — SDM Vol.3C Chapter 34
//
// in_smm: true when the processor is in SMM. RSM is only valid in SMM.
// smbase: base physical address of SMRAM. Default 0x30000 after reset.
//         Updated from SMRAM state save area (offset 7EF8h) on each RSM.
// =========================================================================

register in_smm : bool = false
register smbase : dword = 0x00030000

// =========================================================================
// VMX (VT-x) State — SDM Vol.3C Chapter 24
//
// in_vmx_root:     true when in VMX root operation (hypervisor)
// in_vmx_non_root: true when in VMX non-root operation (guest)
// vmcs_ptr:        physical address of the current VMCS (None if no current VMCS)
// vmxon_region_pa: physical address of the VMXON region
// vmcs:            cached VMCS data (serialized to memory by VMCLEAR)
// =========================================================================

register in_vmx_root     : bool = false
register in_vmx_non_root : bool = false
register vmcs_ptr        : option(qword) = None()
register vmxon_region_pa : qword = zeros()
register vmcs            : VMCS_data = default_vmcs()

// IA32_FEATURE_CONTROL MSR (0x3A)
// Bit 0: Lock — once set, WRMSR to this MSR causes #GP(0)
// Bit 1: Enable VMX in SMX operation
// Bit 2: Enable VMX outside SMX operation
// Default: locked + VMX-outside-SMX enabled (bits 0 and 2)
register ia32_feature_control : qword = 0x0000000000000005

// Cached EPT-active flag. Set by vm_entry(), cleared by complete_vm_exit().
// Avoids re-reading VMCS control bits on every phys_read/phys_write.
register ept_active : bool = false

// =========================================================================
// A20 gate
//
// When disabled, physical address bit 20 is forced to zero, causing
// the 1MB address space to wrap around (real-mode compatibility).
// On reset, A20 is disabled. Enabled via port 0x92 or keyboard controller.
// =========================================================================

register a20_enabled : bool = false


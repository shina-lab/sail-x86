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
// Returns bitone when CS.D=1 (32-bit default), bitzero when CS.D=0 (16-bit).
val get_cs_db : unit -> bit
function get_cs_db() = SegCache[CS].seg_db

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
// The splice file overrides ifetch_read8() to read from this register
// instead of memory, because Isla's symbolic memory model does not
// connect writes to subsequent reads at the same address.
register insn_buf : bits(120) = zeros()

// Output register for ISLA equivalence proofs.
register Final_result : bits(128) = zeros()

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

// =========================================================================
// Control registers (system-level)
// =========================================================================

register CR0  : qword  // PE, PG, WP, etc.
register CR2  : qword  // Page Fault Linear Address
register CR3  : qword  // Page table base
register CR4  : qword  // PAE, PSE, OSFXSR, OSXSAVE, etc.
register CR8  : bits(4) // Task Priority Register (TPR), bits 3:0
register EFER : qword  // Extended Feature Enable Register

// Debug registers
register DR0  : qword  // Linear breakpoint address 0
register DR1  : qword  // Linear breakpoint address 1
register DR2  : qword  // Linear breakpoint address 2
register DR3  : qword  // Linear breakpoint address 3
register DR6  : qword  // Debug status
register DR7  : qword  // Debug control

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
let CR4_VME       : int = 0   // Virtual-8086 Mode Extensions
let CR4_PVI       : int = 1   // Protected-Mode Virtual Interrupts
let CR4_TSD       : int = 2   // Time Stamp Disable
let CR4_DE        : int = 3   // Debugging Extensions
let CR4_PSE       : int = 4   // Page Size Extensions
let CR4_PAE       : int = 5   // Physical Address Extension
let CR4_MCE       : int = 6   // Machine-Check Enable
let CR4_PGE       : int = 7   // Page Global Enable
let CR4_PCE       : int = 8   // Performance-Monitoring Counter Enable
let CR4_OSFXSR    : int = 9   // OS Support for FXSAVE/FXRSTOR
let CR4_OSXMMEXCPT : int = 10 // OS Support for Unmasked SIMD FP Exceptions
let CR4_LA57      : int = 12  // 5-Level Paging
let CR4_FSGSBASE  : int = 16  // FSGSBASE Enable
let CR4_PCIDE     : int = 17  // PCID Enable
let CR4_OSXSAVE   : int = 18  // XSAVE and Processor Extended States Enable

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
register has_popcnt    : bool
register has_lzcnt     : bool
register has_bmi1      : bool
register has_bmi2      : bool
register has_fma       : bool
register has_aesni     : bool
register has_pclmulqdq : bool
register has_f16c      : bool
register has_movbe     : bool
register has_adx       : bool
register has_sha       : bool
register has_rdrand    : bool
register has_rdseed    : bool
register has_crc32     : bool
register has_movdiri   : bool
register has_movdir64b : bool
register has_avx512    : bool  // silicon support (separate from XCR0 enable)

// =========================================================================
// XCR0 / feature check helpers
// =========================================================================

// AVX enabled: CR4.OSXSAVE(bit 18)=1 and XCR0.SSE(bit 1)=1, AVX(bit 2)=1
val avx_enabled : unit -> bool
function avx_enabled() =
  CR4[18] == bitone & XCR0[2] == bitone & XCR0[1] == bitone

// AVX-512 enabled: AVX enabled + silicon support + XCR0 bits 5,6,7
val avx512_enabled : unit -> bool
function avx512_enabled() =
  avx_enabled() & has_avx512 &
  XCR0[5] == bitone & XCR0[6] == bitone & XCR0[7] == bitone

// Legacy SSE blocked by CR0.EM(bit 2)=1
val sse_em_blocked : unit -> bool
function sse_em_blocked() = CR0[2] == bitone

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
  has_popcnt = false;
  has_lzcnt = false;
  has_bmi1 = false;
  has_bmi2 = false;
  has_fma = false;
  has_aesni = false;
  has_pclmulqdq = false;
  has_f16c = false;
  has_movbe = false;
  has_adx = false;
  has_sha = false;
  has_rdrand = false;
  has_rdseed = false;
  has_crc32 = false;
  has_avx512 = false
}

// x86-64-v2: Nehalem+ (SSE4.2, POPCNT, CMPXCHG16B)
val enable_features_v2 : unit -> unit
function enable_features_v2() = {
  enable_features_v1();
  has_popcnt = true;
  has_crc32 = true;
  has_pclmulqdq = true
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

// x86-64-v4: Skylake-X+ (AVX-512F/BW/CD/DQ/VL)
val enable_features_v4 : unit -> unit
function enable_features_v4() = {
  enable_features_v3();
  XCR0_SUPPORTED = 0x00000000000000E7;  // + opmask + ZMM_Hi256 + Hi16_ZMM
  XCR0 = 0x00000000000000E7;
  has_avx512 = true;
  has_rdseed = true;
  has_sha = true
}

// All features (current default behavior, matches XCR0=0xE7)
val enable_features_all : unit -> unit
function enable_features_all() = {
  enable_features_v4()
}

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

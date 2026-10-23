// x86-64 — Register Definitions

// =========================================================================
// Instruction pointer
// =========================================================================

register RIP : qword

// Branch target set by control-flow instructions (JMP, CALL, RET, Jcc).
// When Some, step() uses this instead of decode_pos to update RIP.
register next_rip : option(qword) = None()

// =========================================================================
// Processor mode and privilege
// =========================================================================

register cur_mode : ProcessorMode
register cur_cpl : cpl_t

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

// Polymorphic GPR write by operand size.  A 32-bit result is zero-extended
// to 64 bits in 64-bit mode (SDM Vol.1 §3.4.1.1).  Outside it "the upper
// 32 bits of 64-bit general-purpose registers are undefined" (SDM Vol.1
// §3.4.1.1, p.3-13; APM Vol.1 §3.4.5, p.74: "undefined and not accessible
// to software"), and a 32-bit write leaves them so.  An 8- or 16-bit
// write keeps the rest of the register.
val write_gpr : forall 'os, 'os in {8, 16, 32, 64}. (implicit('os), gpr_idx, bits('os)) -> unit
function write_gpr(os, idx, v) = match os {
  8  => GPR[idx] = GPR[idx][63..8] @ v,
  16 => GPR[idx] = GPR[idx][63..16] @ v,
  32 => GPR[idx] = if cur_mode == LongMode then zero_extend(v) else (undefined : dword) @ v,
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

// A change of processor mode: "the upper 32 bits of any general-purpose
// register are not preserved when switching from 64-bit mode to a 32-bit
// mode (to protected mode or compatibility mode)" (SDM Vol.1 §3.4.1.1,
// p.3-13); "The processor does not preserve the upper 32 bits of the
// 64-bit GPRs across changes from 64-bit mode to compatibility or legacy
// modes" (APM Vol.1 §3.4.5, p.74).  Those of RAX-RDI become undefined.
// R8-R15, which a 32-bit mode cannot reach, "are preserved across
// transitions from 64-bit mode into compatibility mode then back into
// 64-bit mode" (SDM, ibid.).
val set_mode : ProcessorMode -> unit
function set_mode(m) = {
  if cur_mode == LongMode & m != LongMode then {
    foreach (i from 0 to 7) {
      GPR[i] = (undefined : dword) @ GPR[i][31..0]
    }
  };
  cur_mode = m
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

// Vendor profile for the values the SDM leaves to the implementation and
// on which the two vendors differ: the CPUID bits that govern the x87
// pointers.  See fdp_excptn_only below.
// The CPUID vendor string stays "GenuineIntel" either way.  The KVM
// differential harness selects the host's vendor so that both profiles are
// checked against silicon; the emulators keep the Intel default.
enum Vendor = { Vendor_Intel, Vendor_AMD }
register vendor : Vendor = Vendor_Intel

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
// The last non-control x87 instruction's address, CS selector and opcode,
// and its memory operand's offset and segment selector (SDM Vol.1 §8.1.8,
// §8.1.9).  x87_record_last says what each vendor updates.
register x87_fip : qword
register x87_fcs : word
register x87_fop : bits(11)
register x87_fdp : qword
register x87_fds : word
// Whether MMX instructions ran after the last x87 instruction: FXSAVE and
// XSAVE then save "the MMX technology registers", and "the high 16 bits
// of the field are reserved" (SDM Vol.2A FXSAVE, Field Definitions
// p.3-414).  mmx_touch and EMMS set it, and dispatch_x87 clears it.
register x87_mmx_last : bool = false

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

// Write a value to ST(i).  The register then holds a number, so it is no
// longer tagged empty (SDM Vol.1 §8.1.7: the tag indicates whether a
// register contains a valid number, zero, a special value, or is empty).
val x87_write_st : (int, fp80) -> unit
function x87_write_st(i, v) = {
  let phys = x87_physical(i);
  x87_ST[phys] = v;
  x87_mark_valid(phys)
}

// Tag of a non-empty register from its contents (SDM Vol.1 §8.1.7, Figure
// 8-7): 00 valid, 01 zero, 10 special (NaN, unsupported, infinity, denormal).
val x87_class_tag : fp80 -> bits(2)
function x87_class_tag(v) = {
  let exp : bits(15) = v[78..64];
  let mant : qword = v[63..0];
  if exp == zeros() then (if mant == zeros() then 0b01 else 0b10)
  else if exp == ones() then 0b10
  else if mant[63] == bitzero then 0b10
  else 0b00
}

// The tag word as FSTENV and FSAVE store it: registers tagged empty stay
// empty, the others are classified from their contents.
val x87_tag_word : unit -> word
function x87_tag_word() = {
  var tw : word = x87_tw;
  foreach (i from 0 to 7) {
    let tag : bits(2) = (tw >> (2 * i))[1..0];
    if tag != 0b11 then {
      let cleared : word = tw & ~(0x0003 << (2 * i));
      tw = cleared | (zero_extend(x87_class_tag(x87_ST[i])) << (2 * i))
    }
  };
  tw
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

// Whether ST(i) is tagged empty.
val x87_is_empty : int -> bool
function x87_is_empty(i) = (x87_tw >> (2 * x87_physical(i)))[1..0] == 0b11

// The real indefinite, a QNaN with the sign set and the significand
// 1100...0 (SDM Vol.1 §4.8.3.7, Table 4-3): the masked response of an
// x87 invalid operation.  The packed BCD indefinite has the same bits.
let x87_indefinite : fp80 = 0xFFFFC000000000000000

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
  x87_fip = zeros();
  x87_fcs = zeros();
  x87_fop = zeros();
  x87_fdp = zeros();
  x87_fds = zeros();
  foreach (i from 0 to 7) {
    x87_ST[i] = zeros()
  }
}

// FSW.ES (bit 7, error summary) and FSW.B (bit 15) are set exactly when an
// exception flag is set whose mask bit is clear.  Loading either word
// recomputes them, as does unmasking a set flag (FLDCW).
val x87_update_es : unit -> unit
function x87_update_es() = {
  let pending : bit = if (x87_sw[5..0] & ~(x87_cw[5..0])) != 0b000000 then bitone else bitzero;
  x87_sw[7] = pending;
  x87_sw[15] = pending
}

// FCW bits 15:13 and 7:6 are reserved (SDM Vol.1 Figure 8-6 p.8-7; APM
// Vol.1 Figure 6-4 p.293, §6.2.3: "All bits, except reserved bits, can be
// read and written"), and neither manual says what they read after a
// load, so a load leaves them undefined.  FNINIT and FNSAVE set the whole
// word to 037FH (SDM §8.1.5; x87_init).
val x87_set_cw : word -> unit
function x87_set_cw(cw) = {
  x87_cw = (cw & 0x1F3F) | ((undefined : word) & 0xE0C0);
  x87_update_es()
}

val x87_set_sw : word -> unit
function x87_set_sw(sw) = {
  x87_sw = sw;
  x87_update_es()
}

// The CPUID bits that select how the x87 pointers are kept and saved.  The
// Intel profile reports CPUID.(EAX=07H,ECX=0):EBX[6] FDP_EXCPTN_ONLY ("the
// x87 FPU Data Pointer is updated only on x87 exceptions") and EBX[13]
// FCS_FDS_DEPRECATION (SDM Vol.1 Table 21-19 p.21-27, §8.1.8), which the
// APM reserves; the AMD profile reports CPUID Fn8000_0008_EBX[2]
// RstrFpErrPtrs, "FP Error Pointers Restored by XRSTOR" (APM Vol.3
// Appendix E p.659, Vol.2 §11.5.10), which the SDM reserves.
val fdp_excptn_only : unit -> bool
function fdp_excptn_only() = vendor == Vendor_Intel

val fcs_fds_deprecated : unit -> bool
function fcs_fds_deprecated() = vendor == Vendor_Intel

val rstr_fp_err_ptrs : unit -> bool
function rstr_fp_err_ptrs() = vendor == Vendor_AMD

// The FCS or FDS that FNSTENV, FNSAVE, FXSAVE and XSAVE write: "If
// CPUID.07H.00H:EBX[13] = 1, the processor deprecates FCS and FDS; it
// saves each as 0000H" (SDM Vol.1 §8.1.8).  The loads take both from the
// image on either vendor.
val x87_saved_selector : word -> word
function x87_saved_selector(sel) = if fcs_fds_deprecated() then 0x0000 else sel

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
  x87_tw = 0x0000;         // all valid
  x87_mmx_last = true
}

// Save the 28-byte x87 environment in the 32-bit protected-mode format
// (SDM Vol.1 Figure 8-9 p.8-11; APM Vol.2 Figure 11-4 p.352) as
// bits(224): FCW, FSW and FTW in the low halves of three doublewords,
// then FIP[31:0], FCS with FOP in bits 26:16 and 00000b above it,
// FDP[31:0], and FDS.  The high halves of the FCW, FSW, FTW and FDS
// doublewords are reserved ("Reserved, IGN" in the APM) with no value
// given, so they are written undefined.
val x87_save_env : unit -> bits(224)
function x87_save_env() = {
  var buf : bits(224) = zeros();
  buf[15..0] = x87_cw;
  buf[31..16] = (undefined : word);
  buf[47..32] = x87_sw;
  buf[63..48] = (undefined : word);
  buf[79..64] = x87_tag_word();
  buf[95..80] = (undefined : word);
  buf[127..96] = x87_fip[31..0];
  buf[143..128] = x87_saved_selector(x87_fcs);
  buf[154..144] = x87_fop;
  buf[191..160] = x87_fdp[31..0];
  buf[207..192] = x87_saved_selector(x87_fds);
  buf[223..208] = (undefined : word);
  buf
}

// Load the 28-byte x87 environment from bits(224), the inverse of
// x87_save_env.  FCW is loaded first, so that FSW.ES reflects its masks.
val x87_load_env : bits(224) -> unit
function x87_load_env(buf) = {
  x87_set_cw(buf[15..0]);
  x87_set_sw(buf[47..32]);
  x87_tw = buf[79..64];
  x87_fip = zero_extend(buf[127..96]);
  x87_fcs = buf[143..128];
  x87_fop = buf[154..144];
  x87_fdp = zero_extend(buf[191..160]);
  x87_fds = buf[207..192]
}

// The 14-byte environment of a 16-bit operand size in protected mode
// (SDM Vol.1 §8.1.10, Figure 8-11 p.8-12; APM Vol.2 Figure 11-6 p.354):
// FCW, FSW, FTW, FIP[15:0], FCS, FDP[15:0] and FDS, without FOP.  Loading
// it zero-extends the two offsets ("loads the lower 32 bits from memory
// and clears the upper 32 bits", §8.1.8, of which the image holds 16).
// Neither manual says what FOP becomes, since the image has none; the
// model clears it.
val x87_save_env16 : unit -> bits(112)
function x87_save_env16() =
  x87_saved_selector(x87_fds) @ x87_fdp[15..0] @ x87_saved_selector(x87_fcs) @ x87_fip[15..0]
  @ x87_tag_word() @ x87_sw @ x87_cw

val x87_load_env16 : bits(112) -> unit
function x87_load_env16(buf) = {
  x87_set_cw(buf[15..0]);
  x87_set_sw(buf[31..16]);
  x87_tw = buf[47..32];
  x87_fip = zero_extend(buf[63..48]);
  x87_fcs = buf[79..64];
  x87_fop = zeros();
  x87_fdp = zero_extend(buf[95..80]);
  x87_fds = buf[111..96]
}

// The eight registers that follow the environment in an FSAVE image, in
// stack order: DEST[ST(i)] := ST(i) (SDM Vol.2A FSAVE/FNSAVE, Operation).
val x87_save_regs : unit -> bits(640)
function x87_save_regs() = {
  var buf : bits(640) = zeros();
  foreach (i from 0 to 7) {
    buf[(i * 80 + 79) .. (i * 80)] = x87_read_st(i)
  };
  buf
}

// ST(i) := SRC[ST(i)] (SDM Vol.2A FRSTOR, Operation), relative to the TOP
// of the environment loaded first.
val x87_load_regs : bits(640) -> unit
function x87_load_regs(buf) = {
  foreach (i from 0 to 7) {
    x87_ST[x87_physical(i)] = buf[(i * 80 + 79) .. (i * 80)]
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
// Descriptor table registers
// =========================================================================

register GDTR_base  : qword
register GDTR_limit : word
register IDTR_base  : qword
register IDTR_limit : word
register LDTR       : word   // LDT selector
register LDTR_base : qword
register LDTR_limit : dword
register LDTR_valid : bool = false
register TR         : word   // Task register selector

// TSS base and limit (loaded from GDT when LTR executes)
register TR_base  : qword
register TR_limit : dword
// Hidden TSS descriptor type, retained by LTR (SDM Vol.3A section 10.2.4).
register TR_type : bits(4) = 0xB

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
  vsib_seg : segreg_idx,    // segment of the accesses
  vsib_addr64 : bool,       // 64-bit addresses (else 32-bit)
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
// STI delays maskable interrupts through the following instruction, but
// unlike MOV SS it does not suppress debug traps.
register sti_shadow : range(0, 2) = 0

// Data-breakpoint bookkeeping (SDM Vol.3B §20.3.1.2), maintained by the
// memory interface, exec_rep and step():
//   pending_dbp — Bn of the data breakpoints hit by the current
//                 instruction's accesses; reported as a trap after it,
//                 kept across a MOV SS/POP SS and delivered after the
//                 following instruction, lost on a fault.
//   rep_trap_rf — a repeated string instruction stopped after an
//                 iteration that is not its last (data breakpoint or single
//                 step): the trap's RFLAGS image carries RF = 1 (§20.3.1.1).
register pending_dbp : bits(4) = 0x0
register rep_trap_rf : bool = false

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
register has_rdpid     : bool  // CPUID.07H:ECX[22] — RDPID (F3 0F C7 /7)
register has_crc32     : bool
register has_movdiri   : bool
register has_movdir64b : bool
register has_enqcmd    : bool  // CPUID.07H:ECX[29] — ENQCMD, ENQCMDS and IA32_PASID
register has_xsave     : bool  // XSAVE/XRSTOR, XSETBV/XGETBV, XCR0 (CPUID.01H:ECX[26])
// The AVX-512 extensions, each its own CPUID bit (SDM Vol.1 Tables 21-19
// to 21-22, pp. 21-27 to 21-30), which the model reports in leaf 7 and
// whose instructions are #UD without it ("If any corresponding CPUID
// feature flag is '0'", Vol.2A Table 2-46 and the other EVEX exception
// classes; "If relevant CPUID feature flag is '0'", Tables 2-65 and 2-66
// of the opmask instructions).  evex_extension in insn_evex_forms.sail
// gives each EVEX form its extension; AVX512VL adds the 128- and 256-bit
// forms of the instructions that have a 512-bit form.
register has_avx512f      : bool  // CPUID.07H:EBX[16]
register has_avx512dq     : bool  // CPUID.07H:EBX[17]
register has_avx512_ifma  : bool  // CPUID.07H:EBX[21]
register has_avx512pf     : bool  // CPUID.07H:EBX[26] — VGATHERPF*, VSCATTERPF* (Xeon Phi)
register has_avx512er     : bool  // CPUID.07H:EBX[27] — VEXP2*, VRCP28*, VRSQRT28* (Xeon Phi)
register has_avx512cd     : bool  // CPUID.07H:EBX[28]
register has_avx512bw     : bool  // CPUID.07H:EBX[30]
register has_avx512vl     : bool  // CPUID.07H:EBX[31]
register has_avx512_vbmi  : bool  // CPUID.07H:ECX[1]
register has_avx512_vbmi2 : bool  // CPUID.07H:ECX[6]
register has_avx512_vnni  : bool  // CPUID.07H:ECX[11] — EVEX VPDPBUSD/VPDPBUSDS/VPDPWSSD/VPDPWSSDS
register has_avx512_bitalg : bool // CPUID.07H:ECX[12]
register has_avx512_vpopcntdq : bool // CPUID.07H:ECX[14]
register has_avx512_vp2intersect : bool // CPUID.07H:EDX[8]
// The XSAVE extensions of CPUID.(0DH,1):EAX (SDM Vol.1 §13.2 p.13-3,
// Table 21-35): "If EAX[0] = 0, execution of XSAVEOPT causes an
// invalid-opcode exception (#UD)"; EAX[1], "the compacted format", XSAVEC
// and "the compacted form of XRSTOR"; EAX[2], XGETBV with ECX = 1; EAX[3],
// XSAVES, XRSTORS and IA32_XSS ("an attempt to access the IA32_XSS MSR
// using RDMSR or WRMSR causes a general-protection exception (#GP)"
// without it); EAX[4], extended feature disable (§13.14: IA32_XFD and
// IA32_XFD_ERR).
register has_xsaveopt  : bool
register has_xsavec    : bool
register has_xgetbv1   : bool
register has_xsaves    : bool
register has_xfd       : bool
register has_avx512_fp16 : bool  // CPUID.07H:EDX[23] — AVX512-FP16 (EVEX maps 5 and 6, and 0F3A forms)
register has_avx512_bf16  : bool  // CPUID.(07H,1):EAX[5]
register has_la57      : bool  // CPUID.07H:ECX[16] — 5-Level Paging
register has_vmx       : bool  // CPUID.01H:ECX[5] — VMX support
register has_amx_tile  : bool  // CPUID.07H:EDX[24] — AMX tile architecture (LDTILECFG, TILELOADD, ...)
register has_amx_int8  : bool  // CPUID.07H:EDX[25] — TDPBSSD/TDPBSUD/TDPBUSD/TDPBUUD
register has_amx_bf16  : bool  // CPUID.07H:EDX[22] — TDPBF16PS
register has_prefetchw : bool  // CPUID.80000001H:ECX[8] — PREFETCHW (0F 0D /1; a NOP either way)
register has_cldemote  : bool  // CPUID.07H:ECX[25] — CLDEMOTE (0F 1C /0; a NOP either way)
register has_waitpkg   : bool  // CPUID.07H:ECX[5] — TPAUSE, UMONITOR, UMWAIT and IA32_UMWAIT_CONTROL
// SMAP (CPUID.07H:EBX[20]): CLAC and STAC are #UD without it (SDM Vol.2A
// CLAC, Vol.2B STAC; APM Vol.3 CLAC, STAC).  The model has the
// instructions but not CR4.SMAP's access checks, so no profile sets it;
// the KVM harness gives it the guest's value.
register has_smap      : bool
// PTWRITE (F3 0F AE /4) is #UD unless CPUID.(14H,0):EBX[4] = 1 (SDM Vol.2B
// PTWRITE), a leaf of Intel PT, which CPUID.07H:EBX[25] reports (SDM
// §36.3.1).  The model has no processor trace (no IA32_RTIT_* MSRs), so
// no profile sets it; the KVM harness gives it the host's value, as the
// guest executes PTWRITE natively.
register has_ptwrite   : bool
// AMD SSE4A (EXTRQ, INSERTQ, MOVNTSS, MOVNTSD) is #UD unless CPUID
// Fn8000_0001_ECX[SSE4A] (bit 6) = 1 (AMD APM Vol.4 EXTRQ, INSERTQ,
// MOVNTSD, MOVNTSS).  The profiles describe the "GenuineIntel" processor
// the CPUID presents, so none sets it; the KVM harness gives it the
// host's value.
register has_sse4a     : bool
// AMD Misaligned SSE mode, CPUID Fn8000_0001_ECX[MisAlignSse] (bit 7;
// APM Vol.3 Appendix E p.649): MXCSR.MM (bit 17) then exists and masks the
// #GP of a misaligned legacy SSE memory operand (check_sse_src_alignment
// in insn_modrm.sail; APM Vol.1 §4.2.2 p.118, §4.3.2 p.120).  "The
// corresponding MXCSR_MASK bit (17) is 1", so a machine with it reports
// that bit in MXCSR_MASK as well.  No enable_features_* profile sets it;
// the KVM harness sets it, and MXCSR_MASK, from the host.
register has_misalignsse : bool

// MXCSR_MASK, the value FXSAVE and XSAVE store at bytes 31:28 of the
// legacy region: "All bits set to 0 in the MXCSR_MASK value indicate
// reserved bits in the MXCSR register", which LDMXCSR, FXRSTOR and XRSTOR
// may not set (#GP(0)), and "If the value of the MXCSR_MASK field is
// 00000000H, then the MXCSR_MASK value is the default value of 0000FFBFH"
// (SDM Vol.1 §11.6.6 p.11-21; APM Vol.2 §11.5.10 p.364).  The value is the
// implementation's, which software reads from an FXSAVE image; the KVM
// harness sets the host's.  The default is bits 15:0, DAZ included.
register MXCSR_MASK : dword = 0x0000FFFF

// The XSAVE layout of the user state components the model implements:
// 2 (AVX), 5-7 (AVX-512) and 17-18 (AMX).  For each, CPUID.(0DH,i) "EAX
// enumerates the size (in bytes) required for state component i", "EBX
// enumerates the offset (in bytes, from the base of the XSAVE area) of the
// section used for state component i" in the standard format, and "If
// ECX[1] returns 1, state component i is located on the next 64-byte
// boundary following the preceding state component" in the compacted one
// (SDM Vol.1 §13.2 p.13-4, §13.4.3; APM Vol.2 §11.5.3, Table 11-6).
// Neither manual fixes the offsets or the alignment, so they are the
// implementation's; the KVM harness sets the host's.  Indexed by
// component; a component the processor does not support has size 0.
register xsave_comp_size   : vector(19, dword)
register xsave_comp_offset : vector(19, dword)
register xsave_comp_align  : vector(19, bool)

val set_xsave_component : (range(0, 18), int, int, bool) -> unit
function set_xsave_component(i, size, offset, align) = {
  xsave_comp_size[i] = get_slice_int(32, size, 0);
  xsave_comp_offset[i] = get_slice_int(32, offset, 0);
  xsave_comp_align[i] = align
}

// The user-level monitor of UMONITOR/UMWAIT (SDM Vol.2B): armed by
// UMONITOR, consumed by UMWAIT.  Stores to the monitored range are not
// tracked; UMWAIT is taken to run to its deadline, which the SDM allows.
register umonitor_armed : bool = false

// IA32_PASID (D93H; SDM Vol.2A ENQCMD, and Vol.4 Table 2-2): bits 19:0
// hold the process address space identifier that ENQCMD puts in bits 19:0
// of its command, bit 31 whether it is valid (ENQCMD is #GP(0) while it is
// 0); bits 30:20 and 63:32 are reserved.  The MSR exists with ENQCMD.  The
// model starts it at 0, no valid PASID, as a thread that was given none
// has it (a KVM guest, which cannot write it, runs with that value).
// XSAVES and XRSTORS manage it as supervisor state component 10, PASID
// state (CPUID.0DH.01H:ECX[10]), which the model does not implement:
// IA32_XSS supports no component.
register IA32_PASID : qword = zeros()

// =========================================================================
// Intel AMX tile state (SDM Vol.1 Chapter 19)
//
// Palette 1, the only non-INIT palette, has eight tiles of at most 16 rows
// by 64 bytes (CPUID.1DH.01H).  TILECFG holds the palette, the restart row
// of an interrupted tile load or store, and each tile's shape; a tile whose
// rows and colsb are both zero is not valid.  TMM holds the rows, tile t
// row r at index 16 * t + r.  TILES_CONFIGURED of the SDM is
// tilecfg_palette != 0.  XSAVE manages TILECFG as component 17 and the
// 8 KB of tile data as component 18.
// =========================================================================

register tilecfg_palette   : byte = 0x00
register tilecfg_start_row : byte = 0x00
register tilecfg_colsb     : vector(8, word)
register tilecfg_rows      : vector(8, byte)
register TMM               : vector(128, zmmword)

// Extended feature disable (SDM Vol.1 §13.14; CPUID.0DH.01H:EAX[4]):
// IA32_XFD (1C4H) disables the state components whose bits it and XCR0
// both have, and IA32_XFD_ERR (1C5H) names the components an instruction
// faulted on (#NM).  Only bit 18 (TILEDATA) can be set (xfd_supported in
// insn_xsave.sail); both reset to zero.
register IA32_XFD     : qword = zeros()
register IA32_XFD_ERR : qword = zeros()

// zero_all_tile_data of the SDM.
val amx_zero_all_tiles : unit -> unit
function amx_zero_all_tiles() = {
  foreach (i from 0 to 127) {
    TMM[i] = zeros()
  }
}

// TILECFG in its INIT state: palette 0, TILES_CONFIGURED = 0.
val amx_init_tilecfg : unit -> unit
function amx_init_tilecfg() = {
  tilecfg_palette = 0x00;
  tilecfg_start_row = 0x00;
  foreach (n from 0 to 7) {
    tilecfg_colsb[n] = 0x0000;
    tilecfg_rows[n] = 0x00
  }
}

// =========================================================================
// XCR0 / feature check helpers
// =========================================================================

// AVX enabled: CR4.OSXSAVE(bit 18)=1 and XCR0.SSE(bit 1)=1, AVX(bit 2)=1
val avx_enabled : unit -> bool
function avx_enabled() =
  CR4[18] == 0b1 & XCR0[2] == 0b1 & XCR0[1] == 0b1

// The state requirement of the AVX-512 instructions, the EVEX-encoded and
// the opmask ones: "software can execute Intel AVX-512 instructions only
// if CR4.OSXSAVE = 1 and XCR0[7:5] = 111b.  Otherwise, any execution of an
// Intel AVX-512 instruction causes an invalid-opcode exception (#UD)"
// (SDM Vol.1 §13.3, p. 13-5; Vol.2A Table 2-39: "111xx111b", and
// "111xxx11b" for the opmask instructions, a difference XSETBV leaves no
// room for: it allows XCR0[7:5] = 111b only with XCR0[2:1] = 11b, §13.3).
// Their CPUID features are checked per instruction (evex_check_form,
// vex_check_form).
val avx512_enabled : unit -> bool
function avx512_enabled() =
  avx_enabled() & XCR0[5] == 0b1 & XCR0[6] == 0b1 & XCR0[7] == 0b1

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
  has_rdpid = false;
  has_crc32 = false;
  has_movdiri = false;
  has_movdir64b = false;
  has_enqcmd = false;
  has_xsave = false;
  has_avx512f = false;
  has_avx512dq = false;
  has_avx512_ifma = false;
  has_avx512pf = false;
  has_avx512er = false;
  has_avx512cd = false;
  has_avx512bw = false;
  has_avx512vl = false;
  has_avx512_vbmi = false;
  has_avx512_vbmi2 = false;
  has_avx512_vnni = false;
  has_avx512_bitalg = false;
  has_avx512_vpopcntdq = false;
  has_avx512_vp2intersect = false;
  has_xsaveopt = false;
  has_xsavec = false;
  has_xgetbv1 = false;
  has_xsaves = false;
  has_xfd = false;
  has_avx512_fp16 = false;
  has_avx512_bf16 = false;
  has_vmx = false;
  has_la57 = false;
  has_amx_tile = false;
  has_amx_int8 = false;
  has_amx_bf16 = false;
  has_prefetchw = false;
  has_cldemote = false;
  has_ptwrite = false;
  has_sse4a = false;
  has_misalignsse = false;
  has_waitpkg = false;
  MXCSR_MASK = 0x0000FFFF;
  // No extended state component: x87 and SSE are in the legacy region.
  foreach (i from 0 to 18) {
    set_xsave_component(i, 0, 0, false)
  }
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
  has_xsaveopt = true;
  has_xsavec = true;
  has_xgetbv1 = true;
  has_xsaves = true;
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
  // The extended region starts right after the 64-byte header.
  set_xsave_component(2, 256, 576, false);
  has_bmi1 = true;
  has_bmi2 = true;
  has_fma = true;
  has_lzcnt = true;
  has_f16c = true;
  has_movbe = true;
  has_rdrand = true;
  has_aesni = true;
  has_adx = true;
  has_prefetchw = true  // Broadwell and later
}

// x86-64-v4 and everything above it that the model implements: AVX-512
// (F/CD/BW/DQ/VL, IFMA, VBMI, VBMI2, VNNI, BITALG, VPOPCNTDQ,
// VP2INTERSECT, FP16, BF16), SHA, RDSEED, GFNI, VAES, VPCLMULQDQ, AVX-VNNI
val enable_features_v4 : unit -> unit
function enable_features_v4() = {
  enable_features_v3();
  XCR0_SUPPORTED = 0x00000000000000E7;  // + opmask + ZMM_Hi256 + Hi16_ZMM
  XCR0 = 0x00000000000000E7;
  // The places of the MPX components 3 and 4 (960 and 1024, 64 bytes
  // each) stay unused.
  set_xsave_component(5, 64, 1088, false);
  set_xsave_component(6, 512, 1152, false);
  set_xsave_component(7, 1024, 1664, false);
  has_avx512f = true;
  has_avx512dq = true;
  has_avx512_ifma = true;
  has_avx512cd = true;
  has_avx512bw = true;
  has_avx512vl = true;
  has_avx512_vbmi = true;
  has_avx512_vbmi2 = true;
  has_avx512_vnni = true;
  has_avx512_bitalg = true;
  has_avx512_vpopcntdq = true;
  has_avx512_vp2intersect = true;
  has_avx512_fp16 = true;
  has_avx512_bf16 = true;
  has_rdseed = true;
  has_rdpid = true;
  has_sha = true;
  has_vpclmulqdq = true;
  has_vaes = true;
  has_gfni = true;
  has_avx_vnni = true
}

// Everything the model implements: x86-64-v4 plus Intel AMX (AMX-TILE,
// AMX-INT8, AMX-BF16), whose tile state XCR0 bits 17 and 18 enable, and
// AVX512ER and AVX512PF, the extensions of the Xeon Phi processors only
// (SDM Vol.1 Table 21-19).
val enable_features_all : unit -> unit
function enable_features_all() = {
  enable_features_v4();
  XCR0_SUPPORTED = XCR0_SUPPORTED | 0x0000000000060000;  // + TILECFG + TILEDATA
  XCR0 = XCR0 | 0x0000000000060000;
  has_avx512er = true;
  has_avx512pf = true;
  // After the PKRU component (9, 2688, 8 bytes), each 64-byte aligned in
  // the compacted format.
  set_xsave_component(17, 64, 2752, true);
  set_xsave_component(18, 8192, 2816, true);
  has_xfd = true;
  has_amx_tile = true;
  has_amx_int8 = true;
  has_amx_bf16 = true;
  has_cldemote = true;
  has_waitpkg = true;
  has_enqcmd = true
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

// x86-64 — Core Types

// Operand size in bits. Used throughout the model to select register
// and memory access widths. Replaces a dedicated enum so that subset
// types like {16, 32, 64} work naturally with Sail's type system.
type operand_size = {8, 16, 32, 64}

// Address sizes for memory operands.
type address_size = {16, 32, 64}

// Processor operating modes.
enum ProcessorMode = {
  RealMode,
  ProtectedMode,
  CompatibilityMode,
  LongMode,
}

// Current privilege level.
type cpl_t = range(0, 3)

// Common byte/word/dword/qword types.
type byte    = bits(8)
type word    = bits(16)
type dword   = bits(32)
type qword   = bits(64)
type fp80    = bits(80)
type xmmword = bits(128)
type ymmword = bits(256)
type zmmword = bits(512)

// Access type for page table permission checks.
enum PTAccess = { PT_Read, PT_Write, PT_Execute }

// Index into the 16 general-purpose registers (0..15).
type gpr_idx = range(0, 15)

// GPR reference: register index + REX context (needed for 8-bit AH/SPL distinction).
struct GPRRef = {
  gpr_idx : gpr_idx,
  has_rex : bool,
}

// Index into the segment register file (0..5: ES, CS, SS, DS, FS, GS).
type segreg_idx = range(0, 5)
let ES : segreg_idx = 0
let CS : segreg_idx = 1
let SS : segreg_idx = 2
let DS : segreg_idx = 3
let FS : segreg_idx = 4
let GS : segreg_idx = 5

// Memory reference: segment + linear/effective address.
// Every x86 memory access is relative to a segment.
struct MemRef = {
  seg  : segreg_idx,
  addr : qword,
}

// Segment descriptor cache (hidden part of segment registers).
// Per SDM Vol.3A §3.4.3, each segment register has a visible part
// (16-bit selector) and a hidden part loaded from the GDT/LDT descriptor.
struct SegDescCache = {
  seg_base    : qword,       // linear base address
  seg_limit   : dword,       // segment limit (byte-granular after scaling)
  seg_type    : bits(4),     // type field (code/data, R/W, accessed, etc.)
  seg_s       : bit,         // descriptor type: 0=system, 1=code/data
  seg_dpl     : range(0, 3), // descriptor privilege level
  seg_present : bit,         // segment present
  seg_db      : bit,         // D/B bit (default operation size)
  seg_l       : bit,         // L bit (64-bit code segment)
  seg_g       : bit,         // granularity (0=byte, 1=4KB)
}

// Default segment descriptor cache for real mode:
// base=0, limit=0xFFFF, present, data R/W, DPL=0
val default_seg_desc_cache : unit -> SegDescCache
function default_seg_desc_cache() = struct {
  seg_base    = 0x0000000000000000,
  seg_limit   = 0x0000FFFF,
  seg_type    = 0x3, // data, R/W, accessed
  seg_s       = 0b1, // code/data
  seg_dpl     = 0,
  seg_present = 0b1,
  seg_db      = 0b0, // 16-bit default
  seg_l       = 0b0,
  seg_g       = 0b0, // byte granularity
}

// Exception class for double-fault escalation (SDM Vol.3 Table 7-4).
enum ExceptionClass = { EC_Benign, EC_Contributory, EC_PageFault }

// Exception/interrupt vector numbers.
type exception_vector = range(0, 255)

// Standard x86 exceptions.
let EXN_DE  : exception_vector = 0   // Divide Error
let EXN_DB  : exception_vector = 1   // Debug
let EXN_NMI : exception_vector = 2   // Non-Maskable Interrupt
let EXN_BP  : exception_vector = 3   // Breakpoint
let EXN_OF  : exception_vector = 4   // Overflow
let EXN_BR  : exception_vector = 5   // BOUND Range Exceeded
let EXN_UD  : exception_vector = 6   // Invalid Opcode
let EXN_NM  : exception_vector = 7   // Device Not Available
let EXN_DF  : exception_vector = 8   // Double Fault
let EXN_TS  : exception_vector = 10  // Invalid TSS
let EXN_NP  : exception_vector = 11  // Segment Not Present
let EXN_SS  : exception_vector = 12  // Stack-Segment Fault
let EXN_GP  : exception_vector = 13  // General Protection
let EXN_PF  : exception_vector = 14  // Page Fault
let EXN_MF  : exception_vector = 16  // x87 FPU Error
let EXN_AC  : exception_vector = 17  // Alignment Check
let EXN_MC  : exception_vector = 18  // Machine Check
let EXN_XM  : exception_vector = 19  // SIMD Floating-Point
 
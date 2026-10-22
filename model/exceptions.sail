// x86-64 — Exception Handling

// Sail exception type for faults raised during decode/execute.
// Caught by step() and stored in fault registers.
union exception = {
  Fault  : (exception_vector, dword),
  VMExit : (dword, qword),  // (exit_reason, exit_qualification)
  // An x87 stack fault with the invalid-operation exception unmasked.  It
  // ends the x87 instruction without delivering an exception; the #MF
  // waits for the next waiting x87 instruction (dispatch_x87).
  X87Unmasked : unit,
}

// System state — tracks whether the CPU is running, halted, or handling a syscall.
enum SystemState = { SysRunning, SysHalted, SysSyscall }
register system_state : SystemState

// Fault registers — set by step() when an exception is caught.
// The C++ harness reads these to determine the fault disposition.
register fault_pending : bool
register fault_vector : exception_vector
register fault_error_code : dword

// Raise #GP(0) — the most common fault.
val raise_GP0 : forall ('a : Type). unit -> 'a
function raise_GP0() = {
  throw Fault(EXN_GP, 0x00000000);
  exit()  // never reached; satisfies type checker
}

// Raise #GP with a selector error code.
val raise_GP : forall ('a : Type). dword -> 'a
function raise_GP(sel) = {
  throw Fault(EXN_GP, sel);
  exit()  // never reached; satisfies type checker
}

// Raise #UD — invalid opcode.
val raise_UD : forall ('a : Type). unit -> 'a
function raise_UD() = {
  throw Fault(EXN_UD, 0x00000000);
  exit()  // never reached; satisfies type checker
}

// Raise #SS(0) — stack segment fault.
val raise_SS0 : forall ('a : Type). unit -> 'a
function raise_SS0() = {
  throw Fault(EXN_SS, 0x00000000);
  exit()  // never reached; satisfies type checker
}

// Raise #DE — divide error.
val raise_DE : forall ('a : Type). unit -> 'a
function raise_DE() = {
  throw Fault(EXN_DE, 0x00000000);
  exit()  // never reached; satisfies type checker
}

// Raise #BR — BOUND range exceeded.
val raise_BR : forall ('a : Type). unit -> 'a
function raise_BR() = {
  throw Fault(EXN_BR, 0x00000000);
  exit()  // never reached; satisfies type checker
}

// Raise #NM — device not available.
val raise_NM : forall ('a : Type). unit -> 'a
function raise_NM() = {
  throw Fault(EXN_NM, 0x00000000);
  exit()  // never reached; satisfies type checker
}

// CR0.EM and CR0.TS (SDM Vol.3A §2.5; APM Vol.2 §3.1.1).  An OS sets TS
// on a task switch and saves the x87, MMX and SIMD state of the old task
// only when the new one first uses it, on the #NM; EM says there is no
// x87 FPU.
//
// #UD and #NM are both faults from decoding the instruction, in one class
// whose internal order the manuals leave open: "Faults from Decoding the
// Next Instruction ... Invalid Opcode (#UD), Coprocessor Not Available
// (#NM)", and "the priority of events within a class is
// implementation-dependent" (SDM Vol.3A §7.9, Table 7-2, class 9);
// "interrupt prioritization within a group is implementation dependent"
// (APM Vol.2 §8.5, Table 8-9, group 6).  The model's choice is to raise
// every #UD the encoding or the enabled state decides first: an undefined
// opcode, prefix, ModR/M.reg extension or r/m form, a VSIB operand without
// a SIB byte, register operands an instruction forbids, a CPUID feature
// the processor lacks, AVX or AVX-512 state disabled in XCR0, an undefined
// x87 form.  So the checks come after the decoder's (the tables of
// insn_dispatch.sail, vex_check_form, evex_check_form, x87_undefined).
// Both come before the instruction touches its operands: Table 7-2 "does
// not specify the prioritization of faults that arise during instruction
// execution" (#GP, #SS, #PF, #AC), which follow the decoding, and the
// APM puts those in group 7, below group 6.
//
// PAUSE, PREFETCHh, SFENCE, LFENCE, MFENCE, MOVNTI, CLFLUSH, CRC32 and
// POPCNT (SDM Vol.3A §2.5) and the VEX-encoded general-purpose
// instructions (BMI1, BMI2: Vol.2A §2.6.1, Type 13) are not affected.

// MMX and legacy-encoded SSE instructions, LDMXCSR, STMXCSR and EMMS
// (the exception classes of Vol.2A §2.5, Vol.3B §23.25.3 for MMX and the
// EMMS page): #UD if EM = 1, whatever TS; else #NM if TS = 1.
val check_cr0_sse : unit -> unit
function check_cr0_sse() = {
  if CR0[2] == 0b1 then raise_UD();   // EM
  if CR0[3] == 0b1 then raise_NM()    // TS
}

// VEX-encoded SIMD instructions (Vol.2A §2.5, Types 1-12) and XSAVE,
// XRSTOR, XSAVEOPT, XSAVEC, XSAVES and XRSTORS: #NM if TS = 1.  EM does
// not affect them: the SDM's classes name it only as "Legacy SSE
// instruction: If CR0.EM[bit 2] = 1" (Type 5, Table 2-22), and neither
// manual's XSAVE pages name it.  For VEX the APM contradicts itself:
// Vol.2 §8.2.7 gives #UD for "any SSE instruction (uses ZMM/YMM/XMM
// registers) ... when CR0.EM = 1", while the Vol.4 pages of the
// instructions with an SSE form (PADDD/VPADDD, LDMXCSR/VLDMXCSR, Class 1)
// mark the EM row "S — SSE exception" only.  The model follows the SDM on
// both vendors.
val check_cr0_ts : unit -> unit
function check_cr0_ts() = if CR0[3] == 0b1 then raise_NM()

// AVX-512 instructions: EVEX-encoded (Vol.2A §2.8, Types E1-E12) and the
// VEX-encoded opmask instructions (§2.9, Types K20 and K21).  The SDM's
// classes give #NM if TS = 1 and nothing for EM.  The APM lists "CR0.EM =
// 1" with the #UD of the AVX512 instructions (Vol.4 §3.2.1, "Control
// Register Exceptions"), to which the pages of the opmask instructions
// refer as well ("Exceptions for AVX512 instructions are enumerated in
// Section 3.2"), so on AMD EM gives #UD, ahead of the #NM like the other
// #UDs the enabled state decides.
val check_cr0_avx512 : unit -> unit
function check_cr0_avx512() = {
  if vendor == Vendor_AMD & CR0[2] == 0b1 then raise_UD();  // EM
  check_cr0_ts()
}

// x87 instructions (Vol.3A Table 2-2), FXSAVE and FXRSTOR: #NM if EM = 1
// or TS = 1.  FXSAVE and FXRSTOR: "#NM If CR0.TS[bit 3] = 1. If
// CR0.EM[bit 2] = 1." (SDM Vol.2A FXSAVE, FXRSTOR); "setting EM to 1
// forces an invalid-opcode exception (#UD) when an attempt is made to
// execute any of the 64-bit or 128-bit media instructions except the
// FXSAVE and FXRSTOR instructions.  Attempting to execute these
// instructions when EM is set results in an #NM exception instead" (APM
// Vol.2 §3.1.1).  That is the rule of the two instructions, NP 0F AE /0
// and /1 with a memory operand; their opcode under a 66, F2 or F3 prefix,
// or VEX- or EVEX-encoded, is no instruction and takes the #UD of the
// decoder.  WAIT/FWAIT has a rule of its own (opcode 9B).
val check_cr0_x87 : unit -> unit
function check_cr0_x87() = if CR0[2] == 0b1 | CR0[3] == 0b1 then raise_NM()

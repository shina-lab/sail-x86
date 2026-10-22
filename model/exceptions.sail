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

// CR0.EM and CR0.TS (SDM Vol.3A §2.5).  An OS sets TS on a task switch
// and saves the x87, MMX and SIMD state of the old task only when the new
// one first uses it, on the #NM; EM says there is no x87 FPU.  #UD and
// #NM are both faults from decoding the instruction (Vol.3A §7.9, Table
// 7-2), whose order the SDM leaves open, and come ahead of the #GP, #SS,
// #PF and #AC of a memory operand (the exception classes of Vol.2A §2.5,
// §2.8 and §2.9 list them in that order).  An Emerald Rapids raises every
// #UD the encoding decides first: an undefined opcode, prefix, ModR/M.reg
// extension or r/m form, a VSIB operand without a SIB byte, register
// operands an instruction forbids, AVX or AVX-512 state disabled in XCR0,
// an undefined x87 form.  So the checks come after the decoder's (the
// tables of insn_dispatch.sail, vex_check_form, evex_check_form,
// x87_undefined) and before the instruction touches its operands.
// PAUSE, PREFETCHh, SFENCE, LFENCE, MFENCE, MOVNTI, CLFLUSH, CRC32,
// POPCNT and the VEX-encoded general-purpose instructions (BMI1, BMI2) are
// not affected.

// MMX and legacy-encoded SSE instructions, LDMXCSR, STMXCSR and EMMS
// (the exception classes of Vol.2A §2.5, Vol.3B §23.25.3 for MMX and the
// EMMS page): #UD if EM = 1, whatever TS; else #NM if TS = 1.
val check_cr0_sse : unit -> unit
function check_cr0_sse() = {
  if CR0[2] == 0b1 then raise_UD();   // EM
  if CR0[3] == 0b1 then raise_NM()    // TS
}

// VEX- and EVEX-encoded SIMD instructions (Vol.2A §2.5 Types 1-12, §2.8
// Types E1-E12, §2.9 Types K20 and K21) and XSAVE, XRSTOR, XSAVEOPT,
// XSAVEC, XSAVES and XRSTORS: #NM if TS = 1.  EM does not affect them.
val check_cr0_ts : unit -> unit
function check_cr0_ts() = if CR0[3] == 0b1 then raise_NM()

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

// x86-64 — Exception Handling

// Sail exception type for faults raised during decode/execute.
// Caught by step() and stored in fault registers.
union exception = {
  Fault  : (exception_vector, dword),
  VMExit : (dword, qword),  // (exit_reason, exit_qualification)
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

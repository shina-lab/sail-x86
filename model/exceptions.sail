// x86-64 Sail Model — Exception Handling

// Result type for instruction execution.
union ExecutionResult = {
  Ok       : unit,
  Fault    : (exception_vector, dword),  // vector + error code
  Halt     : unit,
}

// Sail exception type for faults raised mid-decode (e.g. 15-byte length limit).
// Caught by step() and converted to ExecutionResult.Fault.
union exception = {
  X86Fault : (exception_vector, dword),
}

// Raise a fault with an error code.
val raise_fault : (exception_vector, dword) -> ExecutionResult
function raise_fault(vec, err) = Fault(vec, err)

// Raise #GP(0) — the most common fault.
val raise_GP0 : unit -> ExecutionResult
function raise_GP0() = Fault(EXN_GP, 0x00000000)

// Raise #GP with a selector error code.
val raise_GP : dword -> ExecutionResult
function raise_GP(sel) = Fault(EXN_GP, sel)

// Raise #UD — invalid opcode.
val raise_UD : unit -> ExecutionResult
function raise_UD() = Fault(EXN_UD, 0x00000000)

// Raise #SS(0) — stack segment fault.
val raise_SS0 : unit -> ExecutionResult
function raise_SS0() = Fault(EXN_SS, 0x00000000)

// Raise #DE — divide error.
val raise_DE : unit -> ExecutionResult
function raise_DE() = Fault(EXN_DE, 0x00000000)

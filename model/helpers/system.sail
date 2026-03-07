// System Instructions — Part 2
//
// These are privileged/system instructions. Most are modeled as external
// functions since they interact with system state not fully represented
// in our model.

// SIDT — Store Interrupt Descriptor Table Register
// Stores the IDTR (limit + base) to a memory operand.
// We model this as an external since IDTR is system state.
val __sidt : unit -> (word, qword)

// SLDT — Store Local Descriptor Table Register
// Stores the segment selector from LDTR to r/m16.
val __sldt : unit -> word

// SMCTRL — GETSEC[SMCTRL] — SMX Mode Control
// Highly privileged SMX instruction. Modeled entirely as external.
val __smctrl : dword -> ExecutionResult

// SMSW — Store Machine Status Word
// Stores the machine status word (low 16 bits of CR0) to r/m16.
val __smsw : unit -> word

// STAC — Set AC Flag in EFLAGS Register
// Sets the AC (Alignment Check) flag. Requires CPL=0.
// AC flag is not in our simplified RFLAGS model; modeled as external.
val __stac : unit -> unit

// STR — Store Task Register
// Stores the segment selector from TR to r/m16.
val __str : unit -> word

// STUI — Set User Interrupt Flag
// Sets UIF to 1, enabling recognition of user interrupts. 64-bit mode only.
val __stui : unit -> unit

// SWAPGS — Swap GS Base Register
// Exchanges the current GS base register value with the value in
// IA32_KERNEL_GS_BASE MSR. Privileged (CPL=0), 64-bit mode only.
val __swapgs : unit -> unit

// SYSCALL — Fast System Call
// Transfers control to the OS at CPL 0. Loads CS/SS, RIP, RFLAGS
// from MSRs. Complex privilege transition modeled as external.
val __syscall : (qword, qword) -> ExecutionResult

val exec_syscall : unit -> ExecutionResult
function exec_syscall() = {
  let rip_val : qword = RIP;
  let rflags_val : qword = read_rflags();
  __syscall(rip_val, rflags_val)
}

// SYSENTER — Fast System Call (Intel)
// Transfers control to the OS at CPL 0 using SYSENTER_CS/EIP/ESP MSRs.
val __sysenter : (qword, qword) -> ExecutionResult

// SYSEXIT — Fast Return from System Call (SYSENTER counterpart)
// Returns from CPL 0 to CPL 3. Loads CS/SS/RIP/RSP from registers/MSRs.
val __sysexit : (qword, qword) -> ExecutionResult

// SYSRET — Return from Fast System Call (SYSCALL counterpart)
// Returns from CPL 0 to CPL 3. Loads CS/SS/RIP/RFLAGS from RCX/R11.
val __sysret : (qword, qword) -> ExecutionResult

// FXSAVE -- Save x87 FPU, MMX, XMM, and MXCSR State
//
// Saves the x87 FPU, MMX, XMM, and MXCSR register state to a
// 512-byte memory region. The exact layout depends on operating mode.
// We model this as an external operation.

val __fxsave : qword -> ExecutionResult

val exec_fxsave : qword -> ExecutionResult
function exec_fxsave(addr) = __fxsave(addr)

val __fxsave64 : qword -> ExecutionResult

val exec_fxsave64 : qword -> ExecutionResult
function exec_fxsave64(addr) = __fxsave64(addr)
// FXRSTOR -- Restore x87 FPU, MMX, XMM, and MXCSR State
//
// Restores the x87 FPU, MMX, XMM, and MXCSR register state from a
// 512-byte memory image. The exact layout depends on operating mode.
// We model this as an external operation.

val __fxrstor : qword -> ExecutionResult

val exec_fxrstor : qword -> ExecutionResult
function exec_fxrstor(addr) = __fxrstor(addr)

val __fxrstor64 : qword -> ExecutionResult

val exec_fxrstor64 : qword -> ExecutionResult
function exec_fxrstor64(addr) = __fxrstor64(addr)

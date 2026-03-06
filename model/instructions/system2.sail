// System Instructions — Part 2
//
// SIDT, SLDT, SMCTRL, SMSW, STAC, STR, STUI, SWAPGS,
// SYSCALL, SYSENTER, SYSEXIT, SYSRET
//
// These are privileged/system instructions. Most are modeled as external
// functions since they interact with system state not fully represented
// in our model.

// SIDT — Store Interrupt Descriptor Table Register
// Stores the IDTR (limit + base) to a memory operand.
// We model this as an external since IDTR is system state.
val __sidt : unit -> (word, qword)

val exec_sidt : unit -> (word, qword)
function exec_sidt() = __sidt()

// SLDT — Store Local Descriptor Table Register
// Stores the segment selector from LDTR to r/m16.
val __sldt : unit -> word

val exec_sldt : unit -> word
function exec_sldt() = __sldt()

// SMCTRL — GETSEC[SMCTRL] — SMX Mode Control
// Highly privileged SMX instruction. Modeled entirely as external.
val __smctrl : dword -> ExecutionResult

val exec_smctrl : unit -> ExecutionResult
function exec_smctrl() = {
  let ebx_val : dword = read_gpr32(RBX);
  __smctrl(ebx_val)
}

// SMSW — Store Machine Status Word
// Stores the machine status word (low 16 bits of CR0) to r/m16.
val __smsw : unit -> word

val exec_smsw : unit -> word
function exec_smsw() = __smsw()

// STAC — Set AC Flag in EFLAGS Register
// Sets the AC (Alignment Check) flag. Requires CPL=0.
// AC flag is not in our simplified RFLAGS model; modeled as external.
val __stac : unit -> unit

val exec_stac : unit -> ExecutionResult
function exec_stac() = {
  __stac();
  Ok(())
}

// STR — Store Task Register
// Stores the segment selector from TR to r/m16.
val __str : unit -> word

val exec_str : unit -> word
function exec_str() = __str()

// STUI — Set User Interrupt Flag
// Sets UIF to 1, enabling recognition of user interrupts. 64-bit mode only.
val __stui : unit -> unit

val exec_stui : unit -> ExecutionResult
function exec_stui() = {
  __stui();
  Ok(())
}

// SWAPGS — Swap GS Base Register
// Exchanges the current GS base register value with the value in
// IA32_KERNEL_GS_BASE MSR. Privileged (CPL=0), 64-bit mode only.
val __swapgs : unit -> unit

val exec_swapgs : unit -> ExecutionResult
function exec_swapgs() = {
  __swapgs();
  Ok(())
}

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

val exec_sysenter : unit -> ExecutionResult
function exec_sysenter() = {
  let rip_val : qword = RIP;
  let rsp_val : qword = read_gpr64(RSP);
  __sysenter(rip_val, rsp_val)
}

// SYSEXIT — Fast Return from System Call (SYSENTER counterpart)
// Returns from CPL 0 to CPL 3. Loads CS/SS/RIP/RSP from registers/MSRs.
val __sysexit : (qword, qword) -> ExecutionResult

val exec_sysexit : unit -> ExecutionResult
function exec_sysexit() = {
  let rdx_val : qword = read_gpr64(RDX);
  let rcx_val : qword = read_gpr64(RCX);
  __sysexit(rdx_val, rcx_val)
}

// SYSRET — Return from Fast System Call (SYSCALL counterpart)
// Returns from CPL 0 to CPL 3. Loads CS/SS/RIP/RFLAGS from RCX/R11.
val __sysret : (qword, qword) -> ExecutionResult

val exec_sysret : unit -> ExecutionResult
function exec_sysret() = {
  let rcx_val : qword = read_gpr64(RCX);
  let r11_val : qword = read_gpr64(R11);
  __sysret(rcx_val, r11_val)
}

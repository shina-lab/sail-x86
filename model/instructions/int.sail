// INT imm8 — Software Interrupt
// INT3 — Breakpoint (opcode 0xCC)
// INTO — Interrupt on Overflow (opcode 0xCE, invalid in 64-bit mode)
//
// These trigger software interrupts. The exact behavior (pushing flags,
// looking up IDT entries, switching privilege levels) is highly
// implementation-dependent, so we model them as external calls.

val __software_interrupt : byte -> ExecutionResult

// INT imm8
val exec_int : byte -> ExecutionResult
function exec_int(imm8) = __software_interrupt(imm8)

// INT3 (breakpoint)
val exec_int3 : unit -> ExecutionResult
function exec_int3() = __software_interrupt(0x03)

// INTO — Interrupt on Overflow (invalid in 64-bit mode).
// Generates INT 4 if OF=1.
val exec_into : unit -> ExecutionResult
function exec_into() = {
  if OF == bitone
  then __software_interrupt(0x04)
  else Ok(())
}

// INT1 — Debug trap (opcode 0xF1, also known as ICEBP).
val exec_int1 : unit -> ExecutionResult
function exec_int1() = __software_interrupt(0x01)

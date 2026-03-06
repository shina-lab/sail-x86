// User Interrupt Instructions — UIRET, TESTUI, STUI
//
// These instructions support User-Level Interrupts (UINTR).
// STUI and UIRET involve complex state transitions; TESTUI reads UIF.
// All are 64-bit mode only.

// Note: STUI (Set User Interrupt Flag) is defined in system2.sail.

// UIRET — User-Interrupt Return
// Pops RIP, RFLAGS, RSP from the stack and sets UIF=1.
// Complex stack/state manipulation; modeled as external.
val __uiret : (qword, qword) -> ExecutionResult

val exec_uiret : unit -> ExecutionResult
function exec_uiret() = {
  let rsp_val : qword = read_gpr64(RSP);
  let rflags_val : qword = read_rflags();
  __uiret(rsp_val, rflags_val)
}

// TESTUI — Determine User Interrupt Flag
// Copies the current value of UIF into EFLAGS.CF.
// Other arithmetic flags are cleared.
val __testui : unit -> bit

val exec_testui : unit -> ExecutionResult
function exec_testui() = {
  let uif : bit = __testui();
  CF = uif;
  PF = bitzero;
  AF = bitzero;
  ZF = bitzero;
  SF = bitzero;
  OF = bitzero;
  Ok(())
}

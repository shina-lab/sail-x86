// CLI — Clear Interrupt Flag
//
// Clears the IF flag, disabling maskable hardware interrupts.
// Full privilege checking (IOPL, PVI/VME modes) is simplified here;
// we model the common case where IOPL >= CPL.

val exec_cli : unit -> ExecutionResult
function exec_cli() = {
  IF_flag = bitzero;
  Ok(())
}

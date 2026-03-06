// STI — Set Interrupt Flag
//
// Sets the IF flag, enabling maskable hardware interrupts.
// Full privilege checking (IOPL, PVI/VME modes) is simplified here;
// we model the common case where IOPL >= CPL.

val exec_sti : unit -> ExecutionResult
function exec_sti() = {
  IF_flag = bitone;
  Ok(())
}

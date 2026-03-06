// UMWAIT — User Level Monitor Wait
//
// Directs the processor to enter an optimized state while waiting for
// a store to the monitored address range (set by UMONITOR) or until
// the TSC reaches EDX:EAX. Similar to TPAUSE but also wakes on store.
// Sets CF=1 if the OS deadline was exceeded.

val __umwait : (dword, qword) -> bit

val exec_umwait : dword -> ExecutionResult
function exec_umwait(ctrl) = {
  let deadline : qword = read_gpr32(RDX) @ read_gpr32(RAX);
  let timed_out : bit = __umwait(ctrl, deadline);
  CF = timed_out;
  PF = bitzero;
  AF = bitzero;
  ZF = bitzero;
  SF = bitzero;
  OF = bitzero;
  Ok(())
}

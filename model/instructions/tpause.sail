// TPAUSE — Timed PAUSE
//
// Directs the processor to enter an optimized state until the TSC
// reaches the value in EDX:EAX. The input register bit[0] selects
// the power state (0 = C0.2 deeper, 1 = C0.1 lighter).
// Sets CF=1 if woken by timeout expiration with OS deadline exceeded.
// We model the wait behavior as external.

val __tpause : (dword, qword) -> bit

val exec_tpause : dword -> ExecutionResult
function exec_tpause(ctrl) = {
  let deadline : qword = read_gpr32(RDX) @ read_gpr32(RAX);
  let timed_out : bit = __tpause(ctrl, deadline);
  CF = timed_out;
  PF = bitzero;
  AF = bitzero;
  ZF = bitzero;
  SF = bitzero;
  OF = bitzero;
  Ok(())
}

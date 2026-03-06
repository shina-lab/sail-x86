// UMONITOR — User Level Set Up Monitor Address
//
// Arms address monitoring hardware using the address in the source register.
// The monitored range is used by UMWAIT. This is a hint; we model as external.

val __umonitor : qword -> unit

val exec_umonitor : gpr_idx -> ExecutionResult
function exec_umonitor(src) = {
  let addr : qword = read_gpr64(src);
  __umonitor(addr);
  Ok(())
}

// WAKEUP — Wake Up Processor from Monitoring (WAITPKG)
// WBINVD — Write Back and Invalidate Cache
// WBNOINVD — Write Back and Do Not Invalidate Cache
// XRESLDTRK — Resume Tracking of Load Addresses (TSX)
// XSUSLDTRK — Suspend Tracking of Load Addresses (TSX)
//
// Miscellaneous system instructions.
// WAKEUP (UMONITOR/UMWAIT related) wakes the processor from a monitor wait.
// WBINVD writes back all modified cache lines and invalidates caches (CPL=0).
// WBNOINVD writes back all modified cache lines without invalidation (CPL=0).
// XRESLDTRK/XSUSLDTRK resume/suspend load address tracking for TSX.
// All modeled as external functions.

val __wakeup : unit -> ExecutionResult
val exec_wakeup : unit -> ExecutionResult
function exec_wakeup() = __wakeup()

val __wbinvd : unit -> ExecutionResult
val exec_wbinvd : unit -> ExecutionResult
function exec_wbinvd() = __wbinvd()

val __wbnoinvd : unit -> ExecutionResult
val exec_wbnoinvd : unit -> ExecutionResult
function exec_wbnoinvd() = __wbnoinvd()

val __xresldtrk : unit -> ExecutionResult
val exec_xresldtrk : unit -> ExecutionResult
function exec_xresldtrk() = __xresldtrk()

val __xsusldtrk : unit -> ExecutionResult
val exec_xsusldtrk : unit -> ExecutionResult
function exec_xsusldtrk() = __xsusldtrk()

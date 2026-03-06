// ENQCMD/ENQCMDS — Enqueue Command
//
// Atomically enqueue 64-byte command data to a device enqueue register.
// ENQCMD sets privilege bit to 0 (user); ENQCMDS sets it to 1 (supervisor).
// Modeled as external functions due to MMIO/device interaction.

val __enqcmd : unit -> ExecutionResult
val exec_enqcmd : unit -> ExecutionResult
function exec_enqcmd() = __enqcmd()

val __enqcmds : unit -> ExecutionResult
val exec_enqcmds : unit -> ExecutionResult
function exec_enqcmds() = __enqcmds()

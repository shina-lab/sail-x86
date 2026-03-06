// ENCODEKEY128/ENCODEKEY256 — Encode Key With Key Locker
//
// These instructions wrap AES keys into key handles.
// Modeled as external functions due to their complexity
// (interaction with internal wrapper keys, IWKey state).

// =========================================================================
// ENCODEKEY128 — Encode 128-Bit Key With Key Locker
// =========================================================================

val __encodekey128 : unit -> ExecutionResult
val exec_encodekey128 : unit -> ExecutionResult
function exec_encodekey128() = __encodekey128()

// =========================================================================
// ENCODEKEY256 — Encode 256-Bit Key With Key Locker
// =========================================================================

val __encodekey256 : unit -> ExecutionResult
val exec_encodekey256 : unit -> ExecutionResult
function exec_encodekey256() = __encodekey256()

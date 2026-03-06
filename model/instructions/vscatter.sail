// VSCATTERDPS/VSCATTERDPD/VSCATTERQPS/VSCATTERQPD — Scatter Packed FP Values (AVX-512)
// VSCATTERPF0DPS/VSCATTERPF0QPS/VSCATTERPF0DPD/VSCATTERPF0QPD — Scatter Prefetch L1 (AVX-512PF)
// VSCATTERPF1DPS/VSCATTERPF1QPS/VSCATTERPF1DPD/VSCATTERPF1QPD — Scatter Prefetch L2 (AVX-512PF)
//
// Scatter instructions store packed FP values to memory using vector indices
// and a writemask. Each element is stored to base + scale*index.
// Prefetch variants issue prefetch hints for scatter store addresses.
// Modeled as external functions (require YMM/ZMM and masked memory access).

// =========================================================================
// VSCATTER — Scatter Packed Single/Double FP with Dword/Qword Indices
// =========================================================================

val __vscatterdps : unit -> ExecutionResult
val exec_vscatterdps : unit -> ExecutionResult
function exec_vscatterdps() = __vscatterdps()

val __vscatterdpd : unit -> ExecutionResult
val exec_vscatterdpd : unit -> ExecutionResult
function exec_vscatterdpd() = __vscatterdpd()

val __vscatterqps : unit -> ExecutionResult
val exec_vscatterqps : unit -> ExecutionResult
function exec_vscatterqps() = __vscatterqps()

val __vscatterqpd : unit -> ExecutionResult
val exec_vscatterqpd : unit -> ExecutionResult
function exec_vscatterqpd() = __vscatterqpd()

// =========================================================================
// VSCATTERPF0 — Sparse Prefetch Packed SP/DP Data Values with T0 Hint
// =========================================================================

val __vscatterpf0dps : unit -> ExecutionResult
val exec_vscatterpf0dps : unit -> ExecutionResult
function exec_vscatterpf0dps() = __vscatterpf0dps()

val __vscatterpf0qps : unit -> ExecutionResult
val exec_vscatterpf0qps : unit -> ExecutionResult
function exec_vscatterpf0qps() = __vscatterpf0qps()

val __vscatterpf0dpd : unit -> ExecutionResult
val exec_vscatterpf0dpd : unit -> ExecutionResult
function exec_vscatterpf0dpd() = __vscatterpf0dpd()

val __vscatterpf0qpd : unit -> ExecutionResult
val exec_vscatterpf0qpd : unit -> ExecutionResult
function exec_vscatterpf0qpd() = __vscatterpf0qpd()

// =========================================================================
// VSCATTERPF1 — Sparse Prefetch Packed SP/DP Data Values with T1 Hint
// =========================================================================

val __vscatterpf1dps : unit -> ExecutionResult
val exec_vscatterpf1dps : unit -> ExecutionResult
function exec_vscatterpf1dps() = __vscatterpf1dps()

val __vscatterpf1qps : unit -> ExecutionResult
val exec_vscatterpf1qps : unit -> ExecutionResult
function exec_vscatterpf1qps() = __vscatterpf1qps()

val __vscatterpf1dpd : unit -> ExecutionResult
val exec_vscatterpf1dpd : unit -> ExecutionResult
function exec_vscatterpf1dpd() = __vscatterpf1dpd()

val __vscatterpf1qpd : unit -> ExecutionResult
val exec_vscatterpf1qpd : unit -> ExecutionResult
function exec_vscatterpf1qpd() = __vscatterpf1qpd()

// VGATHERDPS — Gather Packed Single FP Values Using Signed Dword Indices
// VGATHERQPS — Gather Packed Single FP Values Using Signed Qword Indices
// VGATHERDPD — Gather Packed Double FP Values Using Signed Dword Indices
// VGATHERQPD — Gather Packed Double FP Values Using Signed Qword Indices
//
// VGATHERPF0DPS/QPD/etc. — Sparse Prefetch Packed SP/DP Data Values (T0 Hint)
// VGATHERPF1DPS/QPD/etc. — Sparse Prefetch Packed SP/DP Data Values (T1 Hint)
//
// Gather instructions use VSIB (vector SIB) addressing to conditionally load
// elements from memory into a vector register using indices from another
// vector register. Complex memory addressing makes these external.
// Prefetch variants use gather-style addressing for cache prefetches.
// No flags affected.

// =========================================================================
// Gather — Data (AVX2/AVX-512)
// =========================================================================

val __vgatherdps : unit -> ExecutionResult
val __vgatherqps : unit -> ExecutionResult
val __vgatherdpd : unit -> ExecutionResult
val __vgatherqpd : unit -> ExecutionResult

// VGATHERDPS — Gather Packed Single FP Using Signed Dword Indices
// VEX.128/256: xmm1/ymm1 := gather(vm32x/vm32y, xmm2/ymm2 mask)
// EVEX.128/256/512: xmm1/ymm1/zmm1 {k1} := gather(vm32x/vm32y/vm32z)
val exec_vgatherdps : unit -> ExecutionResult
function exec_vgatherdps() = __vgatherdps()

// VGATHERQPS — Gather Packed Single FP Using Signed Qword Indices
// VEX.128/256: xmm1 := gather(vm64x/vm64y, xmm2 mask)
// EVEX.128/256/512: xmm1/xmm1/ymm1 {k1} := gather(vm64x/vm64y/vm64z)
val exec_vgatherqps : unit -> ExecutionResult
function exec_vgatherqps() = __vgatherqps()

// VGATHERDPD — Gather Packed Double FP Using Signed Dword Indices
// VEX.128/256: xmm1/ymm1 := gather(vm32x/vm32x, xmm2/ymm2 mask)
// EVEX.128/256/512: xmm1/ymm1/zmm1 {k1} := gather(vm32x/vm32x/vm32y)
val exec_vgatherdpd : unit -> ExecutionResult
function exec_vgatherdpd() = __vgatherdpd()

// VGATHERQPD — Gather Packed Double FP Using Signed Qword Indices
// VEX.128/256: xmm1/ymm1 := gather(vm64x/vm64y, xmm2/ymm2 mask)
// EVEX.128/256/512: xmm1/ymm1/zmm1 {k1} := gather(vm64x/vm64y/vm64z)
val exec_vgatherqpd : unit -> ExecutionResult
function exec_vgatherqpd() = __vgatherqpd()

// =========================================================================
// Gather Prefetch — T0 Hint (AVX-512PF)
// =========================================================================

val __vgatherpf0dps : unit -> ExecutionResult
val __vgatherpf0qps : unit -> ExecutionResult
val __vgatherpf0dpd : unit -> ExecutionResult
val __vgatherpf0qpd : unit -> ExecutionResult

// VGATHERPF0DPS — Sparse Prefetch Packed SP Using Signed Dword Indices (T0 Hint)
// EVEX.512: prefetch(vm32z {k1}) using T0 hint
val exec_vgatherpf0dps : unit -> ExecutionResult
function exec_vgatherpf0dps() = __vgatherpf0dps()

// VGATHERPF0QPS — Sparse Prefetch Packed SP Using Signed Qword Indices (T0 Hint)
// EVEX.512: prefetch(vm64z {k1}) using T0 hint
val exec_vgatherpf0qps : unit -> ExecutionResult
function exec_vgatherpf0qps() = __vgatherpf0qps()

// VGATHERPF0DPD — Sparse Prefetch Packed DP Using Signed Dword Indices (T0 Hint)
// EVEX.512: prefetch(vm32y {k1}) using T0 hint
val exec_vgatherpf0dpd : unit -> ExecutionResult
function exec_vgatherpf0dpd() = __vgatherpf0dpd()

// VGATHERPF0QPD — Sparse Prefetch Packed DP Using Signed Qword Indices (T0 Hint)
// EVEX.512: prefetch(vm64z {k1}) using T0 hint
val exec_vgatherpf0qpd : unit -> ExecutionResult
function exec_vgatherpf0qpd() = __vgatherpf0qpd()

// =========================================================================
// Gather Prefetch — T1 Hint (AVX-512PF)
// =========================================================================

val __vgatherpf1dps : unit -> ExecutionResult
val __vgatherpf1qps : unit -> ExecutionResult
val __vgatherpf1dpd : unit -> ExecutionResult
val __vgatherpf1qpd : unit -> ExecutionResult

// VGATHERPF1DPS — Sparse Prefetch Packed SP Using Signed Dword Indices (T1 Hint)
// EVEX.512: prefetch(vm32z {k1}) using T1 hint
val exec_vgatherpf1dps : unit -> ExecutionResult
function exec_vgatherpf1dps() = __vgatherpf1dps()

// VGATHERPF1QPS — Sparse Prefetch Packed SP Using Signed Qword Indices (T1 Hint)
// EVEX.512: prefetch(vm64z {k1}) using T1 hint
val exec_vgatherpf1qps : unit -> ExecutionResult
function exec_vgatherpf1qps() = __vgatherpf1qps()

// VGATHERPF1DPD — Sparse Prefetch Packed DP Using Signed Dword Indices (T1 Hint)
// EVEX.512: prefetch(vm32y {k1}) using T1 hint
val exec_vgatherpf1dpd : unit -> ExecutionResult
function exec_vgatherpf1dpd() = __vgatherpf1dpd()

// VGATHERPF1QPD — Sparse Prefetch Packed DP Using Signed Qword Indices (T1 Hint)
// EVEX.512: prefetch(vm64z {k1}) using T1 hint
val exec_vgatherpf1qpd : unit -> ExecutionResult
function exec_vgatherpf1qpd() = __vgatherpf1qpd()

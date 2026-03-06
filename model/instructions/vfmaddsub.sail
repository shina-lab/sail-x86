// VFMADDSUBxxxPD — Fused Multiply-Alternating Add/Subtract of Packed Double Precision FP Values
// VFMADDSUBxxxPS — Fused Multiply-Alternating Add/Subtract of Packed Single Precision FP Values
// VFMADDSUBxxxPH — Fused Multiply-Alternating Add/Subtract of Packed FP16 Values (AVX-512 FP16)
// VFMSUBADDxxxPD — Fused Multiply-Alternating Subtract/Add of Packed Double Precision FP Values
// VFMSUBADDxxxPS — Fused Multiply-Alternating Subtract/Add of Packed Single Precision FP Values
// VFMSUBADDxxxPH — Fused Multiply-Alternating Subtract/Add of Packed FP16 Values (AVX-512 FP16)
//
// VFMADDSUB: odd lanes get multiply-add, even lanes get multiply-subtract.
// VFMSUBADD: odd lanes get multiply-subtract, even lanes get multiply-add.
// The 132/213/231 forms differ in operand ordering (see vfma.sail).
// All are modeled as external (VEX.128/256, EVEX.128/256/512).
// No flags affected.

// =========================================================================
// VFMADDSUB — Packed Double Precision (pd)
// =========================================================================

val __vfmaddsub132pd : unit -> ExecutionResult
val __vfmaddsub213pd : unit -> ExecutionResult
val __vfmaddsub231pd : unit -> ExecutionResult

val exec_vfmaddsub132pd : unit -> ExecutionResult
function exec_vfmaddsub132pd() = __vfmaddsub132pd()

val exec_vfmaddsub213pd : unit -> ExecutionResult
function exec_vfmaddsub213pd() = __vfmaddsub213pd()

val exec_vfmaddsub231pd : unit -> ExecutionResult
function exec_vfmaddsub231pd() = __vfmaddsub231pd()

// =========================================================================
// VFMADDSUB — Packed Single Precision (ps)
// =========================================================================

val __vfmaddsub132ps : unit -> ExecutionResult
val __vfmaddsub213ps : unit -> ExecutionResult
val __vfmaddsub231ps : unit -> ExecutionResult

val exec_vfmaddsub132ps : unit -> ExecutionResult
function exec_vfmaddsub132ps() = __vfmaddsub132ps()

val exec_vfmaddsub213ps : unit -> ExecutionResult
function exec_vfmaddsub213ps() = __vfmaddsub213ps()

val exec_vfmaddsub231ps : unit -> ExecutionResult
function exec_vfmaddsub231ps() = __vfmaddsub231ps()

// =========================================================================
// VFMADDSUB — Packed FP16 (ph) — AVX-512 FP16
// =========================================================================

val __vfmaddsub132ph : unit -> ExecutionResult
val __vfmaddsub213ph : unit -> ExecutionResult
val __vfmaddsub231ph : unit -> ExecutionResult

val exec_vfmaddsub132ph : unit -> ExecutionResult
function exec_vfmaddsub132ph() = __vfmaddsub132ph()

val exec_vfmaddsub213ph : unit -> ExecutionResult
function exec_vfmaddsub213ph() = __vfmaddsub213ph()

val exec_vfmaddsub231ph : unit -> ExecutionResult
function exec_vfmaddsub231ph() = __vfmaddsub231ph()

// =========================================================================
// VFMSUBADD — Packed Double Precision (pd)
// =========================================================================

val __vfmsubadd132pd : unit -> ExecutionResult
val __vfmsubadd213pd : unit -> ExecutionResult
val __vfmsubadd231pd : unit -> ExecutionResult

val exec_vfmsubadd132pd : unit -> ExecutionResult
function exec_vfmsubadd132pd() = __vfmsubadd132pd()

val exec_vfmsubadd213pd : unit -> ExecutionResult
function exec_vfmsubadd213pd() = __vfmsubadd213pd()

val exec_vfmsubadd231pd : unit -> ExecutionResult
function exec_vfmsubadd231pd() = __vfmsubadd231pd()

// =========================================================================
// VFMSUBADD — Packed Single Precision (ps)
// =========================================================================

val __vfmsubadd132ps : unit -> ExecutionResult
val __vfmsubadd213ps : unit -> ExecutionResult
val __vfmsubadd231ps : unit -> ExecutionResult

val exec_vfmsubadd132ps : unit -> ExecutionResult
function exec_vfmsubadd132ps() = __vfmsubadd132ps()

val exec_vfmsubadd213ps : unit -> ExecutionResult
function exec_vfmsubadd213ps() = __vfmsubadd213ps()

val exec_vfmsubadd231ps : unit -> ExecutionResult
function exec_vfmsubadd231ps() = __vfmsubadd231ps()

// =========================================================================
// VFMSUBADD — Packed FP16 (ph) — AVX-512 FP16
// =========================================================================

val __vfmsubadd132ph : unit -> ExecutionResult
val __vfmsubadd213ph : unit -> ExecutionResult
val __vfmsubadd231ph : unit -> ExecutionResult

val exec_vfmsubadd132ph : unit -> ExecutionResult
function exec_vfmsubadd132ph() = __vfmsubadd132ph()

val exec_vfmsubadd213ph : unit -> ExecutionResult
function exec_vfmsubadd213ph() = __vfmsubadd213ph()

val exec_vfmsubadd231ph : unit -> ExecutionResult
function exec_vfmsubadd231ph() = __vfmsubadd231ph()

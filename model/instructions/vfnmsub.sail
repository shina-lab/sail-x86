// VFNMSUBxxxPD — Fused Negative Multiply-Subtract of Packed Double Precision FP Values
// VFNMSUBxxxPS — Fused Negative Multiply-Subtract of Packed Single Precision FP Values
// VFNMSUBxxxSD — Fused Negative Multiply-Subtract of Scalar Double Precision FP Values
// VFNMSUBxxxSS — Fused Negative Multiply-Subtract of Scalar Single Precision FP Values
// VFNMSUBxxxPH — Fused Negative Multiply-Subtract of Packed FP16 Values (AVX-512 FP16)
// VFNMSUBxxxSH — Fused Negative Multiply-Subtract of Scalar FP16 Values (AVX-512 FP16)
//
// FNMSUB computes -(src1 * src2) - src3 (negate the product, then subtract).
// The 132/213/231 forms differ in operand ordering:
//   132: DEST = -(DEST * SRC3) - SRC2
//   213: DEST = -(SRC2 * DEST) - SRC3
//   231: DEST = -(SRC2 * SRC3) - DEST
//
// No flags affected.

// =========================================================================
// External FMA primitives are declared in vfma.sail:
//   __f64_fnmsub, __f32_fnmsub
// =========================================================================

// =========================================================================
// VFNMSUB — Packed Double Precision (pd)
// =========================================================================

val __vfnmsub132pd : unit -> ExecutionResult
val __vfnmsub213pd : unit -> ExecutionResult
val __vfnmsub231pd : unit -> ExecutionResult

val exec_vfnmsub132pd : unit -> ExecutionResult
function exec_vfnmsub132pd() = __vfnmsub132pd()

val exec_vfnmsub213pd : unit -> ExecutionResult
function exec_vfnmsub213pd() = __vfnmsub213pd()

val exec_vfnmsub231pd : unit -> ExecutionResult
function exec_vfnmsub231pd() = __vfnmsub231pd()

// =========================================================================
// VFNMSUB — Packed Single Precision (ps)
// =========================================================================

val __vfnmsub132ps : unit -> ExecutionResult
val __vfnmsub213ps : unit -> ExecutionResult
val __vfnmsub231ps : unit -> ExecutionResult

val exec_vfnmsub132ps : unit -> ExecutionResult
function exec_vfnmsub132ps() = __vfnmsub132ps()

val exec_vfnmsub213ps : unit -> ExecutionResult
function exec_vfnmsub213ps() = __vfnmsub213ps()

val exec_vfnmsub231ps : unit -> ExecutionResult
function exec_vfnmsub231ps() = __vfnmsub231ps()

// =========================================================================
// VFNMSUB — Scalar Double Precision (sd)
// =========================================================================

// VFNMSUB132SD: DEST[63:0] := -(DEST * SRC3) - SRC2
val exec_vfnmsub132sd : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfnmsub132sd(dst, src2, src3) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src2;
  let c : xmmword = src3;
  let result : qword = __f64_fnmsub(a[63..0], c[63..0], b[63..0]);
  write_xmm(dst, a[127..64] @ result);
  Ok(())
}

// VFNMSUB213SD: DEST[63:0] := -(SRC2 * DEST) - SRC3
val exec_vfnmsub213sd : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfnmsub213sd(dst, src2, src3) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src2;
  let c : xmmword = src3;
  let result : qword = __f64_fnmsub(b[63..0], a[63..0], c[63..0]);
  write_xmm(dst, a[127..64] @ result);
  Ok(())
}

// VFNMSUB231SD: DEST[63:0] := -(SRC2 * SRC3) - DEST
val exec_vfnmsub231sd : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfnmsub231sd(dst, src2, src3) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src2;
  let c : xmmword = src3;
  let result : qword = __f64_fnmsub(b[63..0], c[63..0], a[63..0]);
  write_xmm(dst, a[127..64] @ result);
  Ok(())
}

// =========================================================================
// VFNMSUB — Scalar Single Precision (ss)
// =========================================================================

// VFNMSUB132SS: DEST[31:0] := -(DEST * SRC3) - SRC2
val exec_vfnmsub132ss : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfnmsub132ss(dst, src2, src3) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src2;
  let c : xmmword = src3;
  let result : dword = __f32_fnmsub(a[31..0], c[31..0], b[31..0]);
  write_xmm(dst, a[127..32] @ result);
  Ok(())
}

// VFNMSUB213SS: DEST[31:0] := -(SRC2 * DEST) - SRC3
val exec_vfnmsub213ss : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfnmsub213ss(dst, src2, src3) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src2;
  let c : xmmword = src3;
  let result : dword = __f32_fnmsub(b[31..0], a[31..0], c[31..0]);
  write_xmm(dst, a[127..32] @ result);
  Ok(())
}

// VFNMSUB231SS: DEST[31:0] := -(SRC2 * SRC3) - DEST
val exec_vfnmsub231ss : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfnmsub231ss(dst, src2, src3) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src2;
  let c : xmmword = src3;
  let result : dword = __f32_fnmsub(b[31..0], c[31..0], a[31..0]);
  write_xmm(dst, a[127..32] @ result);
  Ok(())
}

// =========================================================================
// VFNMSUB — Packed/Scalar FP16 (ph/sh) — AVX-512 FP16
// =========================================================================

val __vfnmsub132ph : unit -> ExecutionResult
val __vfnmsub213ph : unit -> ExecutionResult
val __vfnmsub231ph : unit -> ExecutionResult
val __vfnmsub132sh : unit -> ExecutionResult
val __vfnmsub213sh : unit -> ExecutionResult
val __vfnmsub231sh : unit -> ExecutionResult

val exec_vfnmsub132ph : unit -> ExecutionResult
function exec_vfnmsub132ph() = __vfnmsub132ph()

val exec_vfnmsub213ph : unit -> ExecutionResult
function exec_vfnmsub213ph() = __vfnmsub213ph()

val exec_vfnmsub231ph : unit -> ExecutionResult
function exec_vfnmsub231ph() = __vfnmsub231ph()

val exec_vfnmsub132sh : unit -> ExecutionResult
function exec_vfnmsub132sh() = __vfnmsub132sh()

val exec_vfnmsub213sh : unit -> ExecutionResult
function exec_vfnmsub213sh() = __vfnmsub213sh()

val exec_vfnmsub231sh : unit -> ExecutionResult
function exec_vfnmsub231sh() = __vfnmsub231sh()

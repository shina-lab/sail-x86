// VFNMADDxxxPD — Fused Negative Multiply-Add of Packed Double Precision FP Values
// VFNMADDxxxPS — Fused Negative Multiply-Add of Packed Single Precision FP Values
// VFNMADDxxxSD — Fused Negative Multiply-Add of Scalar Double Precision FP Values
// VFNMADDxxxSS — Fused Negative Multiply-Add of Scalar Single Precision FP Values
// VFNMADDxxxPH — Fused Negative Multiply-Add of Packed FP16 Values (AVX-512 FP16)
// VFNMADDxxxSH — Fused Negative Multiply-Add of Scalar FP16 Values (AVX-512 FP16)
//
// FNMADD computes -(src1 * src2) + src3 (negate the product, then add).
// The 132/213/231 forms differ in operand ordering:
//   132: DEST = -(DEST * SRC3) + SRC2
//   213: DEST = -(SRC2 * DEST) + SRC3
//   231: DEST = -(SRC2 * SRC3) + DEST
//
// No flags affected.

// =========================================================================
// External FMA primitives are declared in vfma.sail:
//   __f64_fnmadd, __f32_fnmadd
// =========================================================================

// =========================================================================
// VFNMADD — Packed Double Precision (pd)
// =========================================================================

val __vfnmadd132pd : unit -> ExecutionResult
val __vfnmadd213pd : unit -> ExecutionResult
val __vfnmadd231pd : unit -> ExecutionResult

val exec_vfnmadd132pd : unit -> ExecutionResult
function exec_vfnmadd132pd() = __vfnmadd132pd()

val exec_vfnmadd213pd : unit -> ExecutionResult
function exec_vfnmadd213pd() = __vfnmadd213pd()

val exec_vfnmadd231pd : unit -> ExecutionResult
function exec_vfnmadd231pd() = __vfnmadd231pd()

// =========================================================================
// VFNMADD — Packed Single Precision (ps)
// =========================================================================

val __vfnmadd132ps : unit -> ExecutionResult
val __vfnmadd213ps : unit -> ExecutionResult
val __vfnmadd231ps : unit -> ExecutionResult

val exec_vfnmadd132ps : unit -> ExecutionResult
function exec_vfnmadd132ps() = __vfnmadd132ps()

val exec_vfnmadd213ps : unit -> ExecutionResult
function exec_vfnmadd213ps() = __vfnmadd213ps()

val exec_vfnmadd231ps : unit -> ExecutionResult
function exec_vfnmadd231ps() = __vfnmadd231ps()

// =========================================================================
// VFNMADD — Scalar Double Precision (sd)
// =========================================================================

// VFNMADD132SD: DEST[63:0] := -(DEST * SRC3) + SRC2
val exec_vfnmadd132sd : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfnmadd132sd(dst, src2, src3) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src2;
  let c : xmmword = src3;
  let result : qword = __f64_fnmadd(a[63..0], c[63..0], b[63..0]);
  write_xmm(dst, a[127..64] @ result);
  Ok(())
}

// VFNMADD213SD: DEST[63:0] := -(SRC2 * DEST) + SRC3
val exec_vfnmadd213sd : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfnmadd213sd(dst, src2, src3) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src2;
  let c : xmmword = src3;
  let result : qword = __f64_fnmadd(b[63..0], a[63..0], c[63..0]);
  write_xmm(dst, a[127..64] @ result);
  Ok(())
}

// VFNMADD231SD: DEST[63:0] := -(SRC2 * SRC3) + DEST
val exec_vfnmadd231sd : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfnmadd231sd(dst, src2, src3) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src2;
  let c : xmmword = src3;
  let result : qword = __f64_fnmadd(b[63..0], c[63..0], a[63..0]);
  write_xmm(dst, a[127..64] @ result);
  Ok(())
}

// =========================================================================
// VFNMADD — Scalar Single Precision (ss)
// =========================================================================

// VFNMADD132SS: DEST[31:0] := -(DEST * SRC3) + SRC2
val exec_vfnmadd132ss : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfnmadd132ss(dst, src2, src3) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src2;
  let c : xmmword = src3;
  let result : dword = __f32_fnmadd(a[31..0], c[31..0], b[31..0]);
  write_xmm(dst, a[127..32] @ result);
  Ok(())
}

// VFNMADD213SS: DEST[31:0] := -(SRC2 * DEST) + SRC3
val exec_vfnmadd213ss : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfnmadd213ss(dst, src2, src3) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src2;
  let c : xmmword = src3;
  let result : dword = __f32_fnmadd(b[31..0], a[31..0], c[31..0]);
  write_xmm(dst, a[127..32] @ result);
  Ok(())
}

// VFNMADD231SS: DEST[31:0] := -(SRC2 * SRC3) + DEST
val exec_vfnmadd231ss : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfnmadd231ss(dst, src2, src3) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src2;
  let c : xmmword = src3;
  let result : dword = __f32_fnmadd(b[31..0], c[31..0], a[31..0]);
  write_xmm(dst, a[127..32] @ result);
  Ok(())
}

// =========================================================================
// VFNMADD — Packed/Scalar FP16 (ph/sh) — AVX-512 FP16
// =========================================================================

val __vfnmadd132ph : unit -> ExecutionResult
val __vfnmadd213ph : unit -> ExecutionResult
val __vfnmadd231ph : unit -> ExecutionResult
val __vfnmadd132sh : unit -> ExecutionResult
val __vfnmadd213sh : unit -> ExecutionResult
val __vfnmadd231sh : unit -> ExecutionResult

val exec_vfnmadd132ph : unit -> ExecutionResult
function exec_vfnmadd132ph() = __vfnmadd132ph()

val exec_vfnmadd213ph : unit -> ExecutionResult
function exec_vfnmadd213ph() = __vfnmadd213ph()

val exec_vfnmadd231ph : unit -> ExecutionResult
function exec_vfnmadd231ph() = __vfnmadd231ph()

val exec_vfnmadd132sh : unit -> ExecutionResult
function exec_vfnmadd132sh() = __vfnmadd132sh()

val exec_vfnmadd213sh : unit -> ExecutionResult
function exec_vfnmadd213sh() = __vfnmadd213sh()

val exec_vfnmadd231sh : unit -> ExecutionResult
function exec_vfnmadd231sh() = __vfnmadd231sh()

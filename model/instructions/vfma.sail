// VFMADDxxxPD/PS/SD/SS — Fused Multiply-Add of Floating-Point Values
// VFMSUBxxxPD/PS/SD/SS — Fused Multiply-Subtract of Floating-Point Values
// VFMADDxxxPH/SH — Fused Multiply-Add of FP16 Values (AVX-512 FP16)
// VFMSUBxxxPH/SH — Fused Multiply-Subtract of FP16 Values (AVX-512 FP16)
// VFMADDRND231PD — Fused Multiply-Add with Rounding Control
//
// VFCMADDCPH/VFMADDCPH — Complex Multiply and Accumulate FP16 Values
// VFCMADDCSH/VFMADDCSH — Complex Multiply and Accumulate Scalar FP16 Values
// VFCMULCPH/VFMULCPH — Complex Multiply FP16 Values
// VFCMULCSH/VFMULCSH — Complex Multiply Scalar FP16 Values
//
// The 132/213/231 forms differ in which operand is multiplied and which is added:
//   132: DEST = DEST * SRC3 +/- SRC2
//   213: DEST = SRC2 * DEST +/- SRC3
//   231: DEST = SRC2 * SRC3 +/- DEST
//
// All FMA instructions are modeled as external functions since they span
// VEX.128/256 and EVEX.128/256/512 encodings with YMM/ZMM operands.
// No flags affected.

// =========================================================================
// External FMA primitives (scalar)
// =========================================================================
val __f64_fmadd  : (qword, qword, qword) -> qword
val __f64_fmsub  : (qword, qword, qword) -> qword
val __f64_fnmadd : (qword, qword, qword) -> qword
val __f64_fnmsub : (qword, qword, qword) -> qword
val __f32_fmadd  : (dword, dword, dword) -> dword
val __f32_fmsub  : (dword, dword, dword) -> dword
val __f32_fnmadd : (dword, dword, dword) -> dword
val __f32_fnmsub : (dword, dword, dword) -> dword

// =========================================================================
// VFMADD — Packed Double Precision (pd)
// =========================================================================

// External packed operations (VEX.128/256, EVEX.128/256/512)
val __vfmadd132pd : unit -> ExecutionResult
val __vfmadd213pd : unit -> ExecutionResult
val __vfmadd231pd : unit -> ExecutionResult

val exec_vfmadd132pd : unit -> ExecutionResult
function exec_vfmadd132pd() = __vfmadd132pd()

val exec_vfmadd213pd : unit -> ExecutionResult
function exec_vfmadd213pd() = __vfmadd213pd()

val exec_vfmadd231pd : unit -> ExecutionResult
function exec_vfmadd231pd() = __vfmadd231pd()

// =========================================================================
// VFMADD — Packed Single Precision (ps)
// =========================================================================

val __vfmadd132ps : unit -> ExecutionResult
val __vfmadd213ps : unit -> ExecutionResult
val __vfmadd231ps : unit -> ExecutionResult

val exec_vfmadd132ps : unit -> ExecutionResult
function exec_vfmadd132ps() = __vfmadd132ps()

val exec_vfmadd213ps : unit -> ExecutionResult
function exec_vfmadd213ps() = __vfmadd213ps()

val exec_vfmadd231ps : unit -> ExecutionResult
function exec_vfmadd231ps() = __vfmadd231ps()

// =========================================================================
// VFMADD — Scalar Double Precision (sd)
// DEST[63:0] = fmadd(src1[63:0], src2[63:0], src3[63:0])
// =========================================================================

// VFMADD132SD: DEST[63:0] := DEST * SRC3 + SRC2
val exec_vfmadd132sd : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfmadd132sd(dst, src2, src3) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src2;
  let c : xmmword = src3;
  let result : qword = __f64_fmadd(a[63..0], c[63..0], b[63..0]);
  write_xmm(dst, a[127..64] @ result);
  Ok(())
}

// VFMADD213SD: DEST[63:0] := SRC2 * DEST + SRC3
val exec_vfmadd213sd : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfmadd213sd(dst, src2, src3) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src2;
  let c : xmmword = src3;
  let result : qword = __f64_fmadd(b[63..0], a[63..0], c[63..0]);
  write_xmm(dst, a[127..64] @ result);
  Ok(())
}

// VFMADD231SD: DEST[63:0] := SRC2 * SRC3 + DEST
val exec_vfmadd231sd : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfmadd231sd(dst, src2, src3) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src2;
  let c : xmmword = src3;
  let result : qword = __f64_fmadd(b[63..0], c[63..0], a[63..0]);
  write_xmm(dst, a[127..64] @ result);
  Ok(())
}

// =========================================================================
// VFMADD — Scalar Single Precision (ss)
// DEST[31:0] = fmadd(src1[31:0], src2[31:0], src3[31:0])
// =========================================================================

// VFMADD132SS: DEST[31:0] := DEST * SRC3 + SRC2
val exec_vfmadd132ss : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfmadd132ss(dst, src2, src3) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src2;
  let c : xmmword = src3;
  let result : dword = __f32_fmadd(a[31..0], c[31..0], b[31..0]);
  write_xmm(dst, a[127..32] @ result);
  Ok(())
}

// VFMADD213SS: DEST[31:0] := SRC2 * DEST + SRC3
val exec_vfmadd213ss : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfmadd213ss(dst, src2, src3) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src2;
  let c : xmmword = src3;
  let result : dword = __f32_fmadd(b[31..0], a[31..0], c[31..0]);
  write_xmm(dst, a[127..32] @ result);
  Ok(())
}

// VFMADD231SS: DEST[31:0] := SRC2 * SRC3 + DEST
val exec_vfmadd231ss : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfmadd231ss(dst, src2, src3) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src2;
  let c : xmmword = src3;
  let result : dword = __f32_fmadd(b[31..0], c[31..0], a[31..0]);
  write_xmm(dst, a[127..32] @ result);
  Ok(())
}

// =========================================================================
// VFMADD — Packed/Scalar FP16 (ph/sh) — AVX-512 FP16
// =========================================================================

val __vfmadd132ph : unit -> ExecutionResult
val __vfmadd213ph : unit -> ExecutionResult
val __vfmadd231ph : unit -> ExecutionResult
val __vfmadd132sh : unit -> ExecutionResult
val __vfmadd213sh : unit -> ExecutionResult
val __vfmadd231sh : unit -> ExecutionResult

val exec_vfmadd132ph : unit -> ExecutionResult
function exec_vfmadd132ph() = __vfmadd132ph()

val exec_vfmadd213ph : unit -> ExecutionResult
function exec_vfmadd213ph() = __vfmadd213ph()

val exec_vfmadd231ph : unit -> ExecutionResult
function exec_vfmadd231ph() = __vfmadd231ph()

val exec_vfmadd132sh : unit -> ExecutionResult
function exec_vfmadd132sh() = __vfmadd132sh()

val exec_vfmadd213sh : unit -> ExecutionResult
function exec_vfmadd213sh() = __vfmadd213sh()

val exec_vfmadd231sh : unit -> ExecutionResult
function exec_vfmadd231sh() = __vfmadd231sh()

// =========================================================================
// VFMSUB — Packed Double Precision (pd)
// =========================================================================

val __vfmsub132pd : unit -> ExecutionResult
val __vfmsub213pd : unit -> ExecutionResult
val __vfmsub231pd : unit -> ExecutionResult

val exec_vfmsub132pd : unit -> ExecutionResult
function exec_vfmsub132pd() = __vfmsub132pd()

val exec_vfmsub213pd : unit -> ExecutionResult
function exec_vfmsub213pd() = __vfmsub213pd()

val exec_vfmsub231pd : unit -> ExecutionResult
function exec_vfmsub231pd() = __vfmsub231pd()

// =========================================================================
// VFMSUB — Packed Single Precision (ps)
// =========================================================================

val __vfmsub132ps : unit -> ExecutionResult
val __vfmsub213ps : unit -> ExecutionResult
val __vfmsub231ps : unit -> ExecutionResult

val exec_vfmsub132ps : unit -> ExecutionResult
function exec_vfmsub132ps() = __vfmsub132ps()

val exec_vfmsub213ps : unit -> ExecutionResult
function exec_vfmsub213ps() = __vfmsub213ps()

val exec_vfmsub231ps : unit -> ExecutionResult
function exec_vfmsub231ps() = __vfmsub231ps()

// =========================================================================
// VFMSUB — Scalar Double Precision (sd)
// DEST[63:0] = fmsub(src1[63:0], src2[63:0], src3[63:0])
// =========================================================================

// VFMSUB132SD: DEST[63:0] := DEST * SRC3 - SRC2
val exec_vfmsub132sd : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfmsub132sd(dst, src2, src3) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src2;
  let c : xmmword = src3;
  let result : qword = __f64_fmsub(a[63..0], c[63..0], b[63..0]);
  write_xmm(dst, a[127..64] @ result);
  Ok(())
}

// VFMSUB213SD: DEST[63:0] := SRC2 * DEST - SRC3
val exec_vfmsub213sd : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfmsub213sd(dst, src2, src3) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src2;
  let c : xmmword = src3;
  let result : qword = __f64_fmsub(b[63..0], a[63..0], c[63..0]);
  write_xmm(dst, a[127..64] @ result);
  Ok(())
}

// VFMSUB231SD: DEST[63:0] := SRC2 * SRC3 - DEST
val exec_vfmsub231sd : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfmsub231sd(dst, src2, src3) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src2;
  let c : xmmword = src3;
  let result : qword = __f64_fmsub(b[63..0], c[63..0], a[63..0]);
  write_xmm(dst, a[127..64] @ result);
  Ok(())
}

// =========================================================================
// VFMSUB — Scalar Single Precision (ss)
// DEST[31:0] = fmsub(src1[31:0], src2[31:0], src3[31:0])
// =========================================================================

// VFMSUB132SS: DEST[31:0] := DEST * SRC3 - SRC2
val exec_vfmsub132ss : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfmsub132ss(dst, src2, src3) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src2;
  let c : xmmword = src3;
  let result : dword = __f32_fmsub(a[31..0], c[31..0], b[31..0]);
  write_xmm(dst, a[127..32] @ result);
  Ok(())
}

// VFMSUB213SS: DEST[31:0] := SRC2 * DEST - SRC3
val exec_vfmsub213ss : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfmsub213ss(dst, src2, src3) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src2;
  let c : xmmword = src3;
  let result : dword = __f32_fmsub(b[31..0], a[31..0], c[31..0]);
  write_xmm(dst, a[127..32] @ result);
  Ok(())
}

// VFMSUB231SS: DEST[31:0] := SRC2 * SRC3 - DEST
val exec_vfmsub231ss : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfmsub231ss(dst, src2, src3) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src2;
  let c : xmmword = src3;
  let result : dword = __f32_fmsub(b[31..0], c[31..0], a[31..0]);
  write_xmm(dst, a[127..32] @ result);
  Ok(())
}

// =========================================================================
// VFMSUB — Packed/Scalar FP16 (ph/sh) — AVX-512 FP16
// =========================================================================

val __vfmsub132ph : unit -> ExecutionResult
val __vfmsub213ph : unit -> ExecutionResult
val __vfmsub231ph : unit -> ExecutionResult
val __vfmsub132sh : unit -> ExecutionResult
val __vfmsub213sh : unit -> ExecutionResult
val __vfmsub231sh : unit -> ExecutionResult

val exec_vfmsub132ph : unit -> ExecutionResult
function exec_vfmsub132ph() = __vfmsub132ph()

val exec_vfmsub213ph : unit -> ExecutionResult
function exec_vfmsub213ph() = __vfmsub213ph()

val exec_vfmsub231ph : unit -> ExecutionResult
function exec_vfmsub231ph() = __vfmsub231ph()

val exec_vfmsub132sh : unit -> ExecutionResult
function exec_vfmsub132sh() = __vfmsub132sh()

val exec_vfmsub213sh : unit -> ExecutionResult
function exec_vfmsub213sh() = __vfmsub213sh()

val exec_vfmsub231sh : unit -> ExecutionResult
function exec_vfmsub231sh() = __vfmsub231sh()

// =========================================================================
// VFMADDRND231PD — Fused Multiply-Add with Rounding Control
// Packed double precision: DEST := SRC2 * SRC3 + DEST, with imm8 rounding
// VEX.128/256 only. Rounding mode from imm8 overrides MXCSR.
// =========================================================================

val __vfmaddrnd231pd : unit -> ExecutionResult

val exec_vfmaddrnd231pd : unit -> ExecutionResult
function exec_vfmaddrnd231pd() = __vfmaddrnd231pd()

// =========================================================================
// VFCMADDCPH/VFMADDCPH — Complex Multiply and Accumulate FP16 Values
// EVEX.128/256/512, AVX-512 FP16
// =========================================================================

val __vfcmaddcph : unit -> ExecutionResult
val __vfmaddcph  : unit -> ExecutionResult

val exec_vfcmaddcph : unit -> ExecutionResult
function exec_vfcmaddcph() = __vfcmaddcph()

val exec_vfmaddcph : unit -> ExecutionResult
function exec_vfmaddcph() = __vfmaddcph()

// =========================================================================
// VFCMADDCSH/VFMADDCSH — Complex Multiply and Accumulate Scalar FP16 Values
// EVEX.128, AVX-512 FP16
// =========================================================================

val __vfcmaddcsh : unit -> ExecutionResult
val __vfmaddcsh  : unit -> ExecutionResult

val exec_vfcmaddcsh : unit -> ExecutionResult
function exec_vfcmaddcsh() = __vfcmaddcsh()

val exec_vfmaddcsh : unit -> ExecutionResult
function exec_vfmaddcsh() = __vfmaddcsh()

// =========================================================================
// VFCMULCPH/VFMULCPH — Complex Multiply FP16 Values
// EVEX.128/256/512, AVX-512 FP16
// =========================================================================

val __vfcmulcph : unit -> ExecutionResult
val __vfmulcph  : unit -> ExecutionResult

val exec_vfcmulcph : unit -> ExecutionResult
function exec_vfcmulcph() = __vfcmulcph()

val exec_vfmulcph : unit -> ExecutionResult
function exec_vfmulcph() = __vfmulcph()

// =========================================================================
// VFCMULCSH/VFMULCSH — Complex Multiply Scalar FP16 Values
// EVEX.128, AVX-512 FP16
// =========================================================================

val __vfcmulcsh : unit -> ExecutionResult
val __vfmulcsh  : unit -> ExecutionResult

val exec_vfcmulcsh : unit -> ExecutionResult
function exec_vfcmulcsh() = __vfcmulcsh()

val exec_vfmulcsh : unit -> ExecutionResult
function exec_vfmulcsh() = __vfmulcsh()

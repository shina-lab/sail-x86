// CVTDQ2PD — Convert Packed Doubleword Integers to Packed Double-Precision FP Values
// Converts two 32-bit signed integers from low quadword of src to two 64-bit doubles.
// No flags affected.

val exec_cvtdq2pd : (simd_idx, xmmword) -> ExecutionResult
function exec_cvtdq2pd(dst, src) = {
  let s : xmmword = src;
  let r : xmmword = __int32_to_f64(s[63..32]) @ __int32_to_f64(s[31..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}
// CVTDQ2PS — Convert Packed Doubleword Integers to Packed Single-Precision FP Values
// Converts four 32-bit signed integers to four 32-bit singles. No flags affected.

val exec_cvtdq2ps : (simd_idx, xmmword) -> ExecutionResult
function exec_cvtdq2ps(dst, src) = {
  let s : xmmword = src;
  let r : xmmword =
    __int32_to_f32(s[127..96]) @ __int32_to_f32(s[95..64]) @
    __int32_to_f32(s[63..32]) @ __int32_to_f32(s[31..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}
// CVTPD2DQ — Convert Packed Double-Precision FP Values to Packed Doubleword Integers
// Converts two 64-bit doubles to two 32-bit signed integers in low quadword, upper zeroed.
// No flags affected.

val exec_cvtpd2dq : (simd_idx, xmmword) -> ExecutionResult
function exec_cvtpd2dq(dst, src) = {
  let s : xmmword = src;
  let r : xmmword = zeros(64) @ __f64_to_int32(s[127..64]) @ __f64_to_int32(s[63..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}
// CVTPD2PS — Convert Packed Double-Precision FP Values to Packed Single-Precision FP Values
// Converts two 64-bit doubles to two 32-bit singles in low quadword, upper zeroed.
// No flags affected.

val exec_cvtpd2ps : (simd_idx, xmmword) -> ExecutionResult
function exec_cvtpd2ps(dst, src) = {
  let s : xmmword = src;
  let r : xmmword = zeros(64) @ __f64_to_f32(s[127..64]) @ __f64_to_f32(s[63..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}
// CVTPS2DQ — Convert Packed Single-Precision FP Values to Packed Doubleword Integers
// Converts four 32-bit singles to four 32-bit signed integers (rounding per MXCSR).
// No flags affected.

val exec_cvtps2dq : (simd_idx, xmmword) -> ExecutionResult
function exec_cvtps2dq(dst, src) = {
  let s : xmmword = src;
  let r : xmmword =
    __f32_to_int32(s[127..96]) @ __f32_to_int32(s[95..64]) @
    __f32_to_int32(s[63..32]) @ __f32_to_int32(s[31..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}
// CVTPS2PD — Convert Packed Single-Precision FP Values to Packed Double-Precision FP Values
// Converts two 32-bit singles from low quadword of src to two 64-bit doubles.
// No flags affected.

val exec_cvtps2pd : (simd_idx, xmmword) -> ExecutionResult
function exec_cvtps2pd(dst, src) = {
  let s : xmmword = src;
  let r : xmmword = __f32_to_f64(s[63..32]) @ __f32_to_f64(s[31..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}
// CVTSD2SI — Convert Scalar Double Precision FP to Integer
//
// Converts double-precision FP in XMM to 32/64-bit integer in GPR.
// No flags affected.

val exec_cvtsd2si : (gpr_idx, xmmword, OperandSize) -> ExecutionResult
function exec_cvtsd2si(dst, src, os) = {
  let fp_val : qword = src[63..0];
  match os {
    OS64 => write_gpr64(dst, __f64_to_int64(fp_val)),
    _    => write_gpr32(dst, __f64_to_int32(fp_val)),
  };
  Ok(())
}
// CVTSD2SS — Convert Scalar Double Precision FP to Single Precision FP
//
// Converts double in XMM src[63:0] to single in XMM dst[31:0].
// Upper bits of dst preserved. No flags affected.

val exec_cvtsd2ss : (simd_idx, xmmword) -> ExecutionResult
function exec_cvtsd2ss(dst, src) = {
  let result : dword = __f64_to_f32(src[63..0]);
  var xmm : xmmword = read_xmm(dst);
  xmm[31..0] = result;
  write_xmm_legacy(dst, xmm);
  Ok(())
}
// CVTSI2SD — Convert Integer to Scalar Double Precision FP
//
// Converts a 32/64-bit integer to double-precision FP in XMM.
// Upper bits of XMM preserved. No flags affected.

val exec_cvtsi2sd : (simd_idx, qword, OperandSize) -> ExecutionResult
function exec_cvtsi2sd(dst, src, os) = {
  let result : qword = match os {
    OS64 => __int64_to_f64(src),
    _    => __int32_to_f64(src[31..0]),
  };
  var xmm : xmmword = read_xmm(dst);
  xmm[63..0] = result;
  write_xmm_legacy(dst, xmm);
  Ok(())
}
// CVTSI2SS — Convert Integer to Scalar Single Precision FP
//
// Converts a 32/64-bit integer to single-precision FP in XMM[31:0].
// Upper bits of XMM preserved. No flags affected.

val exec_cvtsi2ss : (simd_idx, qword, OperandSize) -> ExecutionResult
function exec_cvtsi2ss(dst, src, os) = {
  let result : dword = match os {
    OS64 => __int64_to_f32(src),
    _    => __int32_to_f32(src[31..0]),
  };
  var xmm : xmmword = read_xmm(dst);
  xmm[31..0] = result;
  write_xmm_legacy(dst, xmm);
  Ok(())
}
// CVTSS2SD — Convert Scalar Single Precision FP to Double Precision FP
//
// Converts single in XMM src[31:0] to double in XMM dst[63:0].
// Upper bits of dst preserved. No flags affected.

val exec_cvtss2sd : (simd_idx, xmmword) -> ExecutionResult
function exec_cvtss2sd(dst, src) = {
  let result : qword = __f32_to_f64(src[31..0]);
  var xmm : xmmword = read_xmm(dst);
  xmm[63..0] = result;
  write_xmm_legacy(dst, xmm);
  Ok(())
}
// CVTSS2SI — Convert Scalar Single Precision FP to Integer
//
// Converts single-precision FP in XMM to 32/64-bit integer in GPR.
// No flags affected.

val exec_cvtss2si : (gpr_idx, xmmword, OperandSize) -> ExecutionResult
function exec_cvtss2si(dst, src, os) = {
  let fp_val : dword = src[31..0];
  match os {
    OS64 => write_gpr64(dst, __f32_to_int64(fp_val)),
    _    => write_gpr32(dst, __f32_to_int32(fp_val)),
  };
  Ok(())
}
// CVTTPD2DQ — Convert with Truncation Packed Double-FP to Packed Dword Integers
// Converts two 64-bit doubles to two 32-bit signed integers using truncation.
// Result is stored in low 64 bits of XMM; upper 64 bits are zeroed.
// No flags affected.

val exec_cvttpd2dq : (simd_idx, xmmword) -> ExecutionResult
function exec_cvttpd2dq(dst, src) = {
  let s : xmmword = src;
  let lo : dword = __f64_to_int32_trunc(s[63..0]);
  let hi : dword = __f64_to_int32_trunc(s[127..64]);
  let r : xmmword = zeros(64) @ hi @ lo;
  write_xmm_legacy(dst, r);
  Ok(())
}
// CVTTPS2DQ — Convert with Truncation Packed Single-Precision FP Values to Packed Doubleword Integers
// Converts four 32-bit singles to four 32-bit signed integers using truncation.
// No flags affected.

val exec_cvttps2dq : (simd_idx, xmmword) -> ExecutionResult
function exec_cvttps2dq(dst, src) = {
  let s : xmmword = src;
  let r : xmmword =
    __f32_to_int32_trunc(s[127..96]) @ __f32_to_int32_trunc(s[95..64]) @
    __f32_to_int32_trunc(s[63..32]) @ __f32_to_int32_trunc(s[31..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}
// CVTTSD2SI — Convert with Truncation Scalar Double Precision FP to Integer
//
// Like CVTSD2SI but always truncates toward zero. No flags affected.

val exec_cvttsd2si : (gpr_idx, xmmword, OperandSize) -> ExecutionResult
function exec_cvttsd2si(dst, src, os) = {
  let fp_val : qword = src[63..0];
  match os {
    OS64 => write_gpr64(dst, __f64_to_int64_trunc(fp_val)),
    _    => write_gpr32(dst, __f64_to_int32_trunc(fp_val)),
  };
  Ok(())
}
// CVTTSS2SI — Convert with Truncation Scalar Single Precision FP to Integer
//
// Like CVTSS2SI but always truncates toward zero. No flags affected.

val exec_cvttss2si : (gpr_idx, xmmword, OperandSize) -> ExecutionResult
function exec_cvttss2si(dst, src, os) = {
  let fp_val : dword = src[31..0];
  match os {
    OS64 => write_gpr64(dst, __f32_to_int64_trunc(fp_val)),
    _    => write_gpr32(dst, __f32_to_int32_trunc(fp_val)),
  };
  Ok(())
}

// MMX/FP Conversion Instructions
// CVTPD2PI, CVTPI2PD, CVTPI2PS, CVTPS2PI, CVTTPD2PI, CVTTPS2PI
//
// These instructions involve MMX (64-bit MM) registers which are not part
// of our register infrastructure. Model as external functions.

// CVTPD2PI — Convert Packed Double-FP to Packed Dword Integers (MMX dest)
val __cvtpd2pi : (qword, xmmword) -> ExecutionResult
val exec_cvtpd2pi : (qword, xmmword) -> ExecutionResult
function exec_cvtpd2pi(mm_idx, src) = __cvtpd2pi(mm_idx, src)

// CVTPI2PD — Convert Packed Dword Integers (MMX src) to Packed Double-FP
val __cvtpi2pd : (simd_idx, qword) -> ExecutionResult
val exec_cvtpi2pd : (simd_idx, qword) -> ExecutionResult
function exec_cvtpi2pd(dst, mm_val) = __cvtpi2pd(dst, mm_val)

// CVTPI2PS — Convert Packed Dword Integers (MMX src) to Packed Single-FP
val __cvtpi2ps : (simd_idx, qword) -> ExecutionResult
val exec_cvtpi2ps : (simd_idx, qword) -> ExecutionResult
function exec_cvtpi2ps(dst, mm_val) = __cvtpi2ps(dst, mm_val)

// CVTPS2PI — Convert Packed Single-FP to Packed Dword Integers (MMX dest)
val __cvtps2pi : (qword, xmmword) -> ExecutionResult
val exec_cvtps2pi : (qword, xmmword) -> ExecutionResult
function exec_cvtps2pi(mm_idx, src) = __cvtps2pi(mm_idx, src)

// CVTTPD2PI — Convert with Truncation Packed Double-FP to Packed Dword Integers (MMX dest)
val __cvttpd2pi : (qword, xmmword) -> ExecutionResult
val exec_cvttpd2pi : (qword, xmmword) -> ExecutionResult
function exec_cvttpd2pi(mm_idx, src) = __cvttpd2pi(mm_idx, src)

// CVTTPS2PI — Convert with Truncation Packed Single-FP to Packed Dword Integers (MMX dest)
val __cvttps2pi : (qword, xmmword) -> ExecutionResult
val exec_cvttps2pi : (qword, xmmword) -> ExecutionResult
function exec_cvttps2pi(mm_idx, src) = __cvttps2pi(mm_idx, src)

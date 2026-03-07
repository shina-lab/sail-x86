// Packed Single Precision FP Arithmetic: ADDPS, SUBPS, MULPS, DIVPS, SQRTPS, MINPS, MAXPS
// Operates on all four 32-bit lanes of XMM. No flags affected.

val exec_addps : (simd_idx, xmmword) -> ExecutionResult
function exec_addps(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword = __f32_add(a[127..96], b[127..96]) @
                       __f32_add(a[95..64], b[95..64]) @
                       __f32_add(a[63..32], b[63..32]) @
                       __f32_add(a[31..0], b[31..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

val exec_subps : (simd_idx, xmmword) -> ExecutionResult
function exec_subps(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword = __f32_sub(a[127..96], b[127..96]) @
                       __f32_sub(a[95..64], b[95..64]) @
                       __f32_sub(a[63..32], b[63..32]) @
                       __f32_sub(a[31..0], b[31..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

val exec_mulps : (simd_idx, xmmword) -> ExecutionResult
function exec_mulps(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword = __f32_mul(a[127..96], b[127..96]) @
                       __f32_mul(a[95..64], b[95..64]) @
                       __f32_mul(a[63..32], b[63..32]) @
                       __f32_mul(a[31..0], b[31..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

val exec_divps : (simd_idx, xmmword) -> ExecutionResult
function exec_divps(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword = __f32_div(a[127..96], b[127..96]) @
                       __f32_div(a[95..64], b[95..64]) @
                       __f32_div(a[63..32], b[63..32]) @
                       __f32_div(a[31..0], b[31..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

val exec_sqrtps : (simd_idx, xmmword) -> ExecutionResult
function exec_sqrtps(dst, src) = {
  let b : xmmword = src;
  let r : xmmword = __f32_sqrt(b[127..96]) @
                       __f32_sqrt(b[95..64]) @
                       __f32_sqrt(b[63..32]) @
                       __f32_sqrt(b[31..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

val exec_minps : (simd_idx, xmmword) -> ExecutionResult
function exec_minps(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword = __f32_min(a[127..96], b[127..96]) @
                       __f32_min(a[95..64], b[95..64]) @
                       __f32_min(a[63..32], b[63..32]) @
                       __f32_min(a[31..0], b[31..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

val exec_maxps : (simd_idx, xmmword) -> ExecutionResult
function exec_maxps(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let r : xmmword = __f32_max(a[127..96], b[127..96]) @
                       __f32_max(a[95..64], b[95..64]) @
                       __f32_max(a[63..32], b[63..32]) @
                       __f32_max(a[31..0], b[31..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}
// Packed Double Precision FP Arithmetic: ADDPD, SUBPD, MULPD, DIVPD, SQRTPD, MINPD, MAXPD
// Operates on both 64-bit lanes of XMM. No flags affected.

val exec_addpd : (simd_idx, xmmword) -> ExecutionResult
function exec_addpd(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let lo : qword = __f64_add(a[63..0], b[63..0]);
  let hi : qword = __f64_add(a[127..64], b[127..64]);
  write_xmm_legacy(dst, hi @ lo);
  Ok(())
}

val exec_subpd : (simd_idx, xmmword) -> ExecutionResult
function exec_subpd(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  write_xmm_legacy(dst, __f64_sub(a[127..64], b[127..64]) @ __f64_sub(a[63..0], b[63..0]));
  Ok(())
}

val exec_mulpd : (simd_idx, xmmword) -> ExecutionResult
function exec_mulpd(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  write_xmm_legacy(dst, __f64_mul(a[127..64], b[127..64]) @ __f64_mul(a[63..0], b[63..0]));
  Ok(())
}

val exec_divpd : (simd_idx, xmmword) -> ExecutionResult
function exec_divpd(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  write_xmm_legacy(dst, __f64_div(a[127..64], b[127..64]) @ __f64_div(a[63..0], b[63..0]));
  Ok(())
}

val exec_sqrtpd : (simd_idx, xmmword) -> ExecutionResult
function exec_sqrtpd(dst, src) = {
  let b : xmmword = src;
  write_xmm_legacy(dst, __f64_sqrt(b[127..64]) @ __f64_sqrt(b[63..0]));
  Ok(())
}

val exec_minpd : (simd_idx, xmmword) -> ExecutionResult
function exec_minpd(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  write_xmm_legacy(dst, __f64_min(a[127..64], b[127..64]) @ __f64_min(a[63..0], b[63..0]));
  Ok(())
}

val exec_maxpd : (simd_idx, xmmword) -> ExecutionResult
function exec_maxpd(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  write_xmm_legacy(dst, __f64_max(a[127..64], b[127..64]) @ __f64_max(a[63..0], b[63..0]));
  Ok(())
}
// Scalar Single Precision FP Arithmetic: ADDSS, SUBSS, MULSS, DIVSS
// Each operates on XMM[31:0], preserving XMM[127:32]. No flags affected.

val exec_addss : (simd_idx, xmmword) -> ExecutionResult
function exec_addss(dst, src) = {
  var xmm : xmmword = read_xmm(dst);
  xmm[31..0] = __f32_add(xmm[31..0], src[31..0]);
  write_xmm_legacy(dst, xmm);
  Ok(())
}

val exec_subss : (simd_idx, xmmword) -> ExecutionResult
function exec_subss(dst, src) = {
  var xmm : xmmword = read_xmm(dst);
  xmm[31..0] = __f32_sub(xmm[31..0], src[31..0]);
  write_xmm_legacy(dst, xmm);
  Ok(())
}

val exec_mulss : (simd_idx, xmmword) -> ExecutionResult
function exec_mulss(dst, src) = {
  var xmm : xmmword = read_xmm(dst);
  xmm[31..0] = __f32_mul(xmm[31..0], src[31..0]);
  write_xmm_legacy(dst, xmm);
  Ok(())
}

val exec_divss : (simd_idx, xmmword) -> ExecutionResult
function exec_divss(dst, src) = {
  var xmm : xmmword = read_xmm(dst);
  xmm[31..0] = __f32_div(xmm[31..0], src[31..0]);
  write_xmm_legacy(dst, xmm);
  Ok(())
}

val exec_sqrtss : (simd_idx, xmmword) -> ExecutionResult
function exec_sqrtss(dst, src) = {
  var xmm : xmmword = read_xmm(dst);
  xmm[31..0] = __f32_sqrt(src[31..0]);
  write_xmm_legacy(dst, xmm);
  Ok(())
}

val exec_minss : (simd_idx, xmmword) -> ExecutionResult
function exec_minss(dst, src) = {
  var xmm : xmmword = read_xmm(dst);
  xmm[31..0] = __f32_min(xmm[31..0], src[31..0]);
  write_xmm_legacy(dst, xmm);
  Ok(())
}

val exec_maxss : (simd_idx, xmmword) -> ExecutionResult
function exec_maxss(dst, src) = {
  var xmm : xmmword = read_xmm(dst);
  xmm[31..0] = __f32_max(xmm[31..0], src[31..0]);
  write_xmm_legacy(dst, xmm);
  Ok(())
}
// Scalar Double Precision FP Arithmetic: ADDSD, SUBSD, MULSD, DIVSD
// Each operates on XMM[63:0], preserving XMM[127:64]. No flags affected.

val exec_addsd : (simd_idx, xmmword) -> ExecutionResult
function exec_addsd(dst, src) = {
  var xmm : xmmword = read_xmm(dst);
  xmm[63..0] = __f64_add(xmm[63..0], src[63..0]);
  write_xmm_legacy(dst, xmm);
  Ok(())
}

val exec_subsd : (simd_idx, xmmword) -> ExecutionResult
function exec_subsd(dst, src) = {
  var xmm : xmmword = read_xmm(dst);
  xmm[63..0] = __f64_sub(xmm[63..0], src[63..0]);
  write_xmm_legacy(dst, xmm);
  Ok(())
}

val exec_mulsd : (simd_idx, xmmword) -> ExecutionResult
function exec_mulsd(dst, src) = {
  var xmm : xmmword = read_xmm(dst);
  xmm[63..0] = __f64_mul(xmm[63..0], src[63..0]);
  write_xmm_legacy(dst, xmm);
  Ok(())
}

val exec_divsd : (simd_idx, xmmword) -> ExecutionResult
function exec_divsd(dst, src) = {
  var xmm : xmmword = read_xmm(dst);
  xmm[63..0] = __f64_div(xmm[63..0], src[63..0]);
  write_xmm_legacy(dst, xmm);
  Ok(())
}

val exec_sqrtsd : (simd_idx, xmmword) -> ExecutionResult
function exec_sqrtsd(dst, src) = {
  var xmm : xmmword = read_xmm(dst);
  xmm[63..0] = __f64_sqrt(src[63..0]);
  write_xmm_legacy(dst, xmm);
  Ok(())
}

val exec_minsd : (simd_idx, xmmword) -> ExecutionResult
function exec_minsd(dst, src) = {
  var xmm : xmmword = read_xmm(dst);
  xmm[63..0] = __f64_min(xmm[63..0], src[63..0]);
  write_xmm_legacy(dst, xmm);
  Ok(())
}

val exec_maxsd : (simd_idx, xmmword) -> ExecutionResult
function exec_maxsd(dst, src) = {
  var xmm : xmmword = read_xmm(dst);
  xmm[63..0] = __f64_max(xmm[63..0], src[63..0]);
  write_xmm_legacy(dst, xmm);
  Ok(())
}
// ADDSUBPS — Packed Single-FP Add/Subtract (SSE3)
// Lanes 0,2: subtract; Lanes 1,3: add. No flags affected.

val exec_addsubps : (simd_idx, xmmword) -> ExecutionResult
function exec_addsubps(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let d0 : dword = __f32_sub(a[31..0], b[31..0]);
  let d1 : dword = __f32_add(a[63..32], b[63..32]);
  let d2 : dword = __f32_sub(a[95..64], b[95..64]);
  let d3 : dword = __f32_add(a[127..96], b[127..96]);
  write_xmm_legacy(dst, d3 @ d2 @ d1 @ d0);
  Ok(())
}
// ADDSUBPD — Packed Double-FP Add/Subtract (SSE3)
// Lane 0: subtract, Lane 1: add. No flags affected.

val exec_addsubpd : (simd_idx, xmmword) -> ExecutionResult
function exec_addsubpd(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let lo : qword = __f64_sub(a[63..0], b[63..0]);
  let hi : qword = __f64_add(a[127..64], b[127..64]);
  write_xmm_legacy(dst, hi @ lo);
  Ok(())
}
// CMPPS — Compare Packed Single Precision Floating-Point Values
//
// Compares four packed single-precision FP values using a comparison predicate
// specified by imm8[2..0]. Each lane is set to all-ones if the comparison is
// true, or all-zeros if false.

val cmp_pred_f32 : (dword, dword, bits(3)) -> dword
function cmp_pred_f32(a, b, pred) = {
  let result = __compare_ss(a, b);
  let cond : bool = match pred {
    0b000 => result == FP_EQ,
    0b001 => result == FP_LT,
    0b010 => result == FP_LT | result == FP_EQ,
    0b011 => result == FP_UNORDERED,
    0b100 => result != FP_EQ,
    0b101 => result != FP_LT,
    0b110 => result == FP_GT,
    0b111 => result != FP_UNORDERED,
  };
  if cond then ones() else zeros()
}

val exec_cmpps : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_cmpps(dst, src, imm8) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let pred : bits(3) = imm8[2..0];
  let r : xmmword =
    cmp_pred_f32(a[127..96], b[127..96], pred) @
    cmp_pred_f32(a[95..64], b[95..64], pred) @
    cmp_pred_f32(a[63..32], b[63..32], pred) @
    cmp_pred_f32(a[31..0], b[31..0], pred);
  write_xmm_legacy(dst, r);
  Ok(())
}
// CMPPD — Compare Packed Double Precision Floating-Point Values
//
// Compares two packed double-precision FP values using a comparison predicate
// specified by imm8[2..0]. Each lane is set to all-ones if the comparison is
// true, or all-zeros if false.

val cmp_pred_f64 : (qword, qword, bits(3)) -> qword
function cmp_pred_f64(a, b, pred) = {
  let result = __compare_sd(a, b);
  let cond : bool = match pred {
    0b000 => result == FP_EQ,
    0b001 => result == FP_LT,
    0b010 => result == FP_LT | result == FP_EQ,
    0b011 => result == FP_UNORDERED,
    0b100 => result != FP_EQ,
    0b101 => result != FP_LT,
    0b110 => result == FP_GT,
    0b111 => result != FP_UNORDERED,
  };
  if cond then ones() else zeros()
}

val exec_cmppd : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_cmppd(dst, src, imm8) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let pred : bits(3) = imm8[2..0];
  let r : xmmword =
    cmp_pred_f64(a[127..64], b[127..64], pred) @
    cmp_pred_f64(a[63..0], b[63..0], pred);
  write_xmm_legacy(dst, r);
  Ok(())
}
// CMPSS — Compare Scalar Single Precision Floating-Point Value
//
// Named cmpss2 to avoid conflict with the string instruction CMPSS.
// Compares the low 32-bit singles using a comparison predicate specified
// by imm8[2..0]. Sets low 32 bits to all-ones or all-zeros; upper bits
// are preserved from dst.

val exec_cmpss2 : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_cmpss2(dst, src, imm8) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let pred : bits(3) = imm8[2..0];
  let low : dword = cmp_pred_f32(a[31..0], b[31..0], pred);
  let r : xmmword = a[127..32] @ low;
  write_xmm_legacy(dst, r);
  Ok(())
}
// CMPSD — Compare Scalar Double Precision Floating-Point Value
//
// Named cmpsd2 to avoid conflict with the string instruction CMPSD.
// Compares the low 64-bit doubles using a comparison predicate specified
// by imm8[2..0]. Sets low 64 bits to all-ones or all-zeros; upper bits
// are preserved from dst.

val exec_cmpsd2 : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_cmpsd2(dst, src, imm8) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let pred : bits(3) = imm8[2..0];
  let low : qword = cmp_pred_f64(a[63..0], b[63..0], pred);
  let r : xmmword = a[127..64] @ low;
  write_xmm_legacy(dst, r);
  Ok(())
}
// COMISS — Compare Scalar Ordered Single Precision FP Values and Set EFLAGS
//
// Compares two single-precision FP values and sets ZF, PF, CF.
// COMISS signals #IA on QNaN; UCOMISS signals only on SNaN.
// OF, AF, SF are cleared.

val exec_comiss : (simd_idx, xmmword) -> ExecutionResult
function exec_comiss(dst, src) = {
  let a : dword = read_xmm(dst)[31..0];
  let b : dword = src[31..0];
  match __compare_ss(a, b) {
    FP_UNORDERED => { ZF = bitone;  PF = bitone;  CF = bitone;  },
    FP_GT        => { ZF = bitzero; PF = bitzero; CF = bitzero; },
    FP_LT        => { ZF = bitzero; PF = bitzero; CF = bitone;  },
    FP_EQ        => { ZF = bitone;  PF = bitzero; CF = bitzero; },
  };
  OF = bitzero;
  AF = bitzero;
  SF = bitzero;
  Ok(())
}
// COMISD — Compare Scalar Ordered Double Precision FP Values and Set EFLAGS

val exec_comisd : (simd_idx, xmmword) -> ExecutionResult
function exec_comisd(dst, src) = {
  let a : qword = read_xmm(dst)[63..0];
  let b : qword = src[63..0];
  match __compare_sd(a, b) {
    FP_UNORDERED => { ZF = bitone;  PF = bitone;  CF = bitone;  },
    FP_GT        => { ZF = bitzero; PF = bitzero; CF = bitzero; },
    FP_LT        => { ZF = bitzero; PF = bitzero; CF = bitone;  },
    FP_EQ        => { ZF = bitone;  PF = bitzero; CF = bitzero; },
  };
  OF = bitzero;
  AF = bitzero;
  SF = bitzero;
  Ok(())
}
// UCOMISD — Unordered Compare Scalar Double Precision FP Values and Set EFLAGS
//
// Same as COMISD for our spec; the only difference is QNaN handling
// which is abstracted into the external __compare_sd function.

val exec_ucomisd : (simd_idx, xmmword) -> ExecutionResult
function exec_ucomisd(dst, src) = {
  let a : qword = read_xmm(dst)[63..0];
  let b : qword = src[63..0];
  match __compare_sd(a, b) {
    FP_UNORDERED => { ZF = bitone;  PF = bitone;  CF = bitone;  },
    FP_GT        => { ZF = bitzero; PF = bitzero; CF = bitzero; },
    FP_LT        => { ZF = bitzero; PF = bitzero; CF = bitone;  },
    FP_EQ        => { ZF = bitone;  PF = bitzero; CF = bitzero; },
  };
  OF = bitzero;
  AF = bitzero;
  SF = bitzero;
  Ok(())
}
// UCOMISS — Unordered Compare Scalar Single Precision FP Values and Set EFLAGS
//
// Same as COMISS for our spec; the only difference is QNaN handling
// which is abstracted into the external __compare_ss function.

val exec_ucomiss : (simd_idx, xmmword) -> ExecutionResult
function exec_ucomiss(dst, src) = {
  let a : dword = read_xmm(dst)[31..0];
  let b : dword = src[31..0];
  match __compare_ss(a, b) {
    FP_UNORDERED => { ZF = bitone;  PF = bitone;  CF = bitone;  },
    FP_GT        => { ZF = bitzero; PF = bitzero; CF = bitzero; },
    FP_LT        => { ZF = bitzero; PF = bitzero; CF = bitone;  },
    FP_EQ        => { ZF = bitone;  PF = bitzero; CF = bitzero; },
  };
  OF = bitzero;
  AF = bitzero;
  SF = bitzero;
  Ok(())
}
// HADDPS — Horizontal Add Packed Singles (SSE3)
// HSUBPS — Horizontal Subtract Packed Singles (SSE3)
// No flags affected.

val exec_haddps : (simd_idx, xmmword) -> ExecutionResult
function exec_haddps(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let d0 : dword = __f32_add(a[31..0], a[63..32]);
  let d1 : dword = __f32_add(a[95..64], a[127..96]);
  let d2 : dword = __f32_add(b[31..0], b[63..32]);
  let d3 : dword = __f32_add(b[95..64], b[127..96]);
  write_xmm_legacy(dst, d3 @ d2 @ d1 @ d0);
  Ok(())
}

val exec_hsubps : (simd_idx, xmmword) -> ExecutionResult
function exec_hsubps(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let d0 : dword = __f32_sub(a[31..0], a[63..32]);
  let d1 : dword = __f32_sub(a[95..64], a[127..96]);
  let d2 : dword = __f32_sub(b[31..0], b[63..32]);
  let d3 : dword = __f32_sub(b[95..64], b[127..96]);
  write_xmm_legacy(dst, d3 @ d2 @ d1 @ d0);
  Ok(())
}

// HADDPD — Horizontal Add Packed Doubles (SSE3)
// HSUBPD — Horizontal Subtract Packed Doubles (SSE3)
// No flags affected.

val exec_haddpd : (simd_idx, xmmword) -> ExecutionResult
function exec_haddpd(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let lo : qword = __f64_add(a[63..0], a[127..64]);
  let hi : qword = __f64_add(b[63..0], b[127..64]);
  write_xmm_legacy(dst, hi @ lo);
  Ok(())
}

val exec_hsubpd : (simd_idx, xmmword) -> ExecutionResult
function exec_hsubpd(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let lo : qword = __f64_sub(a[63..0], a[127..64]);
  let hi : qword = __f64_sub(b[63..0], b[127..64]);
  write_xmm_legacy(dst, hi @ lo);
  Ok(())
}

// DPPS — Dot Product of Packed Single-FP (SSE4.1)
// imm8[7:4] selects which products to include, imm8[3:0] selects output lanes.
// No flags affected.

val exec_dpps : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_dpps(dst, src, imm8) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let zero : dword = 0x00000000;
  let temp0 : dword = if imm8[4] == bitone then __f32_mul(a[31..0], b[31..0]) else zero;
  let temp1 : dword = if imm8[5] == bitone then __f32_mul(a[63..32], b[63..32]) else zero;
  let temp2 : dword = if imm8[6] == bitone then __f32_mul(a[95..64], b[95..64]) else zero;
  let temp3 : dword = if imm8[7] == bitone then __f32_mul(a[127..96], b[127..96]) else zero;
  let sum01 : dword = __f32_add(temp0, temp1);
  let sum23 : dword = __f32_add(temp2, temp3);
  let sum : dword = __f32_add(sum01, sum23);
  let d0 : dword = if imm8[0] == bitone then sum else zero;
  let d1 : dword = if imm8[1] == bitone then sum else zero;
  let d2 : dword = if imm8[2] == bitone then sum else zero;
  let d3 : dword = if imm8[3] == bitone then sum else zero;
  write_xmm_legacy(dst, d3 @ d2 @ d1 @ d0);
  Ok(())
}
// DPPD — Dot Product of Packed Double-FP (SSE4.1)
// imm8[5:4] selects which products to include, imm8[1:0] selects output lanes.
// No flags affected.

val exec_dppd : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_dppd(dst, src, imm8) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let zero : qword = 0x0000000000000000;
  let temp0 : qword = if imm8[4] == bitone then __f64_mul(a[63..0], b[63..0]) else zero;
  let temp1 : qword = if imm8[5] == bitone then __f64_mul(a[127..64], b[127..64]) else zero;
  let sum : qword = __f64_add(temp0, temp1);
  let lo : qword = if imm8[0] == bitone then sum else zero;
  let hi : qword = if imm8[1] == bitone then sum else zero;
  write_xmm_legacy(dst, hi @ lo);
  Ok(())
}
// ROUNDPD — Round Packed Double-FP (SSE4.1)
// ROUNDPS — Round Packed Single-FP (SSE4.1)
// ROUNDSD — Round Scalar Double-FP (SSE4.1)
// ROUNDSS — Round Scalar Single-FP (SSE4.1)
// imm8 controls rounding mode. No flags affected.

val __f64_round : (qword, byte) -> qword
val __f32_round : (dword, byte) -> dword

val exec_roundpd : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_roundpd(dst, src, imm8) = {
  let s : xmmword = src;
  let lo : qword = __f64_round(s[63..0], imm8);
  let hi : qword = __f64_round(s[127..64], imm8);
  write_xmm_legacy(dst, hi @ lo);
  Ok(())
}

val exec_roundps : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_roundps(dst, src, imm8) = {
  let s : xmmword = src;
  let d0 : dword = __f32_round(s[31..0], imm8);
  let d1 : dword = __f32_round(s[63..32], imm8);
  let d2 : dword = __f32_round(s[95..64], imm8);
  let d3 : dword = __f32_round(s[127..96], imm8);
  write_xmm_legacy(dst, d3 @ d2 @ d1 @ d0);
  Ok(())
}

val exec_roundsd : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_roundsd(dst, src, imm8) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let lo : qword = __f64_round(b[63..0], imm8);
  write_xmm_legacy(dst, a[127..64] @ lo);
  Ok(())
}

val exec_roundss : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_roundss(dst, src, imm8) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let lo : dword = __f32_round(b[31..0], imm8);
  write_xmm_legacy(dst, a[127..32] @ lo);
  Ok(())
}
// RSQRTSS/RSQRTPS: Reciprocal Square Root Approximation of Scalar/Packed Single-Precision FP
// No flags affected.

val __f32_rsqrt : dword -> dword

val exec_rsqrtss : (simd_idx, xmmword) -> ExecutionResult
function exec_rsqrtss(dst, src) = {
  var xmm : xmmword = read_xmm(dst);
  xmm[31..0] = __f32_rsqrt(src[31..0]);
  write_xmm_legacy(dst, xmm);
  Ok(())
}

val exec_rsqrtps : (simd_idx, xmmword) -> ExecutionResult
function exec_rsqrtps(dst, src) = {
  let src_xmm : xmmword = src;
  var xmm : xmmword = zeros();
  xmm[31..0]   = __f32_rsqrt(src_xmm[31..0]);
  xmm[63..32]  = __f32_rsqrt(src_xmm[63..32]);
  xmm[95..64]  = __f32_rsqrt(src_xmm[95..64]);
  xmm[127..96] = __f32_rsqrt(src_xmm[127..96]);
  write_xmm_legacy(dst, xmm);
  Ok(())
}
// RCPSS/RCPPS: Reciprocal Approximation of Scalar/Packed Single-Precision FP
// No flags affected.

val __f32_rcp : dword -> dword

val exec_rcpss : (simd_idx, xmmword) -> ExecutionResult
function exec_rcpss(dst, src) = {
  var xmm : xmmword = read_xmm(dst);
  xmm[31..0] = __f32_rcp(src[31..0]);
  write_xmm_legacy(dst, xmm);
  Ok(())
}

val exec_rcpps : (simd_idx, xmmword) -> ExecutionResult
function exec_rcpps(dst, src) = {
  let src_xmm : xmmword = src;
  var xmm : xmmword = zeros();
  xmm[31..0]   = __f32_rcp(src_xmm[31..0]);
  xmm[63..32]  = __f32_rcp(src_xmm[63..32]);
  xmm[95..64]  = __f32_rcp(src_xmm[95..64]);
  xmm[127..96] = __f32_rcp(src_xmm[127..96]);
  write_xmm_legacy(dst, xmm);
  Ok(())
}
// ANDPS/ANDNPS/ORPS/XORPS — Packed Single Precision FP Bitwise Logical
// Pure bitwise operations on 128-bit XMM registers. No flags affected.

val exec_andps : (simd_idx, xmmword) -> ExecutionResult
function exec_andps(dst, src) = {
  write_xmm_legacy(dst, read_xmm(dst) & src);
  Ok(())
}

val exec_andnps : (simd_idx, xmmword) -> ExecutionResult
function exec_andnps(dst, src) = {
  write_xmm_legacy(dst, ~(read_xmm(dst)) & src);
  Ok(())
}

val exec_orps : (simd_idx, xmmword) -> ExecutionResult
function exec_orps(dst, src) = {
  write_xmm_legacy(dst, read_xmm(dst) | src);
  Ok(())
}

val exec_xorps : (simd_idx, xmmword) -> ExecutionResult
function exec_xorps(dst, src) = {
  write_xmm_legacy(dst, xor_vec(read_xmm(dst), src));
  Ok(())
}
// ANDPD/ANDNPD/ORPD/XORPD — Packed Double Precision FP Bitwise Logical
// These are pure bitwise operations on 128-bit XMM registers. No flags affected.

val exec_andpd : (simd_idx, xmmword) -> ExecutionResult
function exec_andpd(dst, src) = {
  write_xmm_legacy(dst, read_xmm(dst) & src);
  Ok(())
}

val exec_andnpd : (simd_idx, xmmword) -> ExecutionResult
function exec_andnpd(dst, src) = {
  write_xmm_legacy(dst, ~(read_xmm(dst)) & src);
  Ok(())
}

val exec_orpd : (simd_idx, xmmword) -> ExecutionResult
function exec_orpd(dst, src) = {
  write_xmm_legacy(dst, read_xmm(dst) | src);
  Ok(())
}

val exec_xorpd : (simd_idx, xmmword) -> ExecutionResult
function exec_xorpd(dst, src) = {
  write_xmm_legacy(dst, xor_vec(read_xmm(dst), src));
  Ok(())
}
// SHUFPS — Shuffle Packed Single-Precision FP Values
// imm8[1:0] selects result[31:0] from dst's 4 dwords.
// imm8[3:2] selects result[63:32] from dst's 4 dwords.
// imm8[5:4] selects result[95:64] from src's 4 dwords.
// imm8[7:6] selects result[127:96] from src's 4 dwords.
// No flags affected.

val select_dword : (xmmword, bits(2)) -> dword
function select_dword(v, sel) = {
  let idx : range(0, 3) = unsigned(sel);
  v[(idx * 32 + 31) .. (idx * 32)]
}

val exec_shufps : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_shufps(dst, src, imm8) = {
  let d : xmmword = read_xmm(dst);
  let s : xmmword = src;
  let d0 : dword = select_dword(d, imm8[1..0]);
  let d1 : dword = select_dword(d, imm8[3..2]);
  let d2 : dword = select_dword(s, imm8[5..4]);
  let d3 : dword = select_dword(s, imm8[7..6]);
  write_xmm_legacy(dst, d3 @ d2 @ d1 @ d0);
  Ok(())
}
// SHUFPD — Shuffle Packed Double-Precision FP Values
// Bit 0 of imm8 selects result[63:0] from dst's low or high qword.
// Bit 1 of imm8 selects result[127:64] from src's low or high qword.
// No flags affected.

val exec_shufpd : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_shufpd(dst, src, imm8) = {
  let d : xmmword = read_xmm(dst);
  let s : xmmword = src;
  let low : qword = if imm8[0] == bitone then d[127..64] else d[63..0];
  let high : qword = if imm8[1] == bitone then s[127..64] else s[63..0];
  write_xmm_legacy(dst, high @ low);
  Ok(())
}
// UNPCKLPS — Unpack and Interleave Low Packed Single-Precision FP
//
// Note: exec_unpcklps is already defined in unpckhps.sail alongside its
// high counterpart. This file exists as a placeholder to document that fact.
// See unpckhps.sail for the implementation.
// UNPCKLPD — Unpack and Interleave Low Packed Double-Precision FP
//
// Note: exec_unpcklpd is already defined in unpckhpd.sail alongside its
// high counterpart. This file exists as a placeholder to document that fact.
// See unpckhpd.sail for the implementation.
// UNPCKHPS — Unpack and Interleave High Packed Single-Precision FP
// UNPCKLPS — Unpack and Interleave Low Packed Single-Precision FP
// No flags affected.

val exec_unpckhps : (simd_idx, xmmword) -> ExecutionResult
function exec_unpckhps(dst, src) = {
  let d : xmmword = read_xmm(dst);
  let s : xmmword = src;
  write_xmm_legacy(dst, s[127..96] @ d[127..96] @ s[95..64] @ d[95..64]);
  Ok(())
}

val exec_unpcklps : (simd_idx, xmmword) -> ExecutionResult
function exec_unpcklps(dst, src) = {
  let d : xmmword = read_xmm(dst);
  let s : xmmword = src;
  write_xmm_legacy(dst, s[63..32] @ d[63..32] @ s[31..0] @ d[31..0]);
  Ok(())
}
// UNPCKHPD — Unpack and Interleave High Packed Double-Precision FP
// UNPCKLPD — Unpack and Interleave Low Packed Double-Precision FP
// No flags affected.

val exec_unpckhpd : (simd_idx, xmmword) -> ExecutionResult
function exec_unpckhpd(dst, src) = {
  let d : xmmword = read_xmm(dst);
  let s : xmmword = src;
  write_xmm_legacy(dst, s[127..64] @ d[127..64]);
  Ok(())
}

val exec_unpcklpd : (simd_idx, xmmword) -> ExecutionResult
function exec_unpcklpd(dst, src) = {
  let d : xmmword = read_xmm(dst);
  let s : xmmword = src;
  write_xmm_legacy(dst, s[63..0] @ d[63..0]);
  Ok(())
}
// BLENDPS — Blend Packed Single-FP (SSE4.1)
// imm8[0..3] each select the corresponding lane: 0=dst, 1=src.
// No flags affected.

val exec_blendps : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_blendps(dst, src, imm8) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let d0 : dword = if imm8[0] == bitone then b[31..0] else a[31..0];
  let d1 : dword = if imm8[1] == bitone then b[63..32] else a[63..32];
  let d2 : dword = if imm8[2] == bitone then b[95..64] else a[95..64];
  let d3 : dword = if imm8[3] == bitone then b[127..96] else a[127..96];
  write_xmm_legacy(dst, d3 @ d2 @ d1 @ d0);
  Ok(())
}
// BLENDPD — Blend Packed Double-FP (SSE4.1)
// imm8[0] selects lane 0: 0=dst, 1=src. imm8[1] selects lane 1.
// No flags affected.

val exec_blendpd : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_blendpd(dst, src, imm8) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let lo : qword = if imm8[0] == bitone then b[63..0] else a[63..0];
  let hi : qword = if imm8[1] == bitone then b[127..64] else a[127..64];
  write_xmm_legacy(dst, hi @ lo);
  Ok(())
}
// BLENDVPD — Variable Blend Packed Double-FP (SSE4.1)
// BLENDVPS — Variable Blend Packed Single-FP (SSE4.1)
// PBLENDVB — Variable Blend Packed Bytes (SSE4.1)
// Mask register selects per-element from dst or src.
// No flags affected.

val exec_blendvpd : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_blendvpd(dst, src, mask_xmm) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let m : xmmword = mask_xmm;
  let lo : qword = if m[63] == bitone then b[63..0] else a[63..0];
  let hi : qword = if m[127] == bitone then b[127..64] else a[127..64];
  write_xmm_legacy(dst, hi @ lo);
  Ok(())
}

val exec_blendvps : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_blendvps(dst, src, mask_xmm) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let m : xmmword = mask_xmm;
  let d0 : dword = if m[31] == bitone then b[31..0] else a[31..0];
  let d1 : dword = if m[63] == bitone then b[63..32] else a[63..32];
  let d2 : dword = if m[95] == bitone then b[95..64] else a[95..64];
  let d3 : dword = if m[127] == bitone then b[127..96] else a[127..96];
  write_xmm_legacy(dst, d3 @ d2 @ d1 @ d0);
  Ok(())
}

val blend_byte : (byte, byte, bit) -> byte
function blend_byte(a, b, sel) = if sel == bitone then b else a

val exec_pblendvb : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_pblendvb(dst, src, mask_xmm) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let m : xmmword = mask_xmm;
  let r0  : byte = blend_byte(a[7..0],     b[7..0],     m[7]);
  let r1  : byte = blend_byte(a[15..8],    b[15..8],    m[15]);
  let r2  : byte = blend_byte(a[23..16],   b[23..16],   m[23]);
  let r3  : byte = blend_byte(a[31..24],   b[31..24],   m[31]);
  let r4  : byte = blend_byte(a[39..32],   b[39..32],   m[39]);
  let r5  : byte = blend_byte(a[47..40],   b[47..40],   m[47]);
  let r6  : byte = blend_byte(a[55..48],   b[55..48],   m[55]);
  let r7  : byte = blend_byte(a[63..56],   b[63..56],   m[63]);
  let r8  : byte = blend_byte(a[71..64],   b[71..64],   m[71]);
  let r9  : byte = blend_byte(a[79..72],   b[79..72],   m[79]);
  let r10 : byte = blend_byte(a[87..80],   b[87..80],   m[87]);
  let r11 : byte = blend_byte(a[95..88],   b[95..88],   m[95]);
  let r12 : byte = blend_byte(a[103..96],  b[103..96],  m[103]);
  let r13 : byte = blend_byte(a[111..104], b[111..104], m[111]);
  let r14 : byte = blend_byte(a[119..112], b[119..112], m[119]);
  let r15 : byte = blend_byte(a[127..120], b[127..120], m[127]);
  write_xmm_legacy(dst, r15 @ r14 @ r13 @ r12 @ r11 @ r10 @ r9 @ r8 @ r7 @ r6 @ r5 @ r4 @ r3 @ r2 @ r1 @ r0);
  Ok(())
}

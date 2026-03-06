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

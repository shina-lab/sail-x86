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

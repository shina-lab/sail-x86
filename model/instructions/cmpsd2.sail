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

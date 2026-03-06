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

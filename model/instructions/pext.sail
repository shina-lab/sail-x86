// PEXT — Parallel Bits Extract
//
// Extracts bits from src at positions indicated by mask,
// packing them into contiguous low-order bits. Upper bits zeroed.
// No flags affected. 32/64-bit only (BMI2).

val pext64 : (qword, qword, int, int) -> qword
function pext64(src, mask, m, k) = {
  if m >= 64 | m < 0 | k >= 64 | k < 0 then zeros()
  else if m == 63 then {
    if bit_to_bool(mask[63]) then
      to_bits_truncate(unsigned(src[63]) * pow2(k))
    else zeros()
  } else {
    let rest : qword = if bit_to_bool(mask[m]) then
      pext64(src, mask, m + 1, k + 1)
    else
      pext64(src, mask, m + 1, k);
    if bit_to_bool(mask[m]) then {
      var r : qword = rest;
      r[k] = src[m];
      r
    } else rest
  }
}

val exec_pext : (gpr_idx, gpr_idx, gpr_idx, OperandSize) -> ExecutionResult
function exec_pext(dst, src, mask_reg, os) = {
  let src_val : qword = read_gpr(src, os);
  let mask_val : qword = read_gpr(mask_reg, os);
  let result : qword = pext64(src_val, mask_val, 0, 0);
  write_gpr(dst, os, result);
  Ok(())
}

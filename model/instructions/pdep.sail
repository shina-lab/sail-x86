// PDEP — Parallel Bits Deposit
//
// Deposits contiguous low-order bits from src into positions
// indicated by mask. Other bits are zeroed. No flags affected.
// 32/64-bit only (BMI2).

val pdep64 : (qword, qword, int, int) -> qword
function pdep64(src, mask, m, k) = {
  if m >= 64 | m < 0 | k >= 64 | k < 0 then zeros()
  else if m == 63 then {
    if bit_to_bool(mask[63]) then
      to_bits_truncate(unsigned(src[k]) * pow2(63))
    else zeros()
  } else {
    let rest : qword = if bit_to_bool(mask[m]) then
      pdep64(src, mask, m + 1, k + 1)
    else
      pdep64(src, mask, m + 1, k);
    if bit_to_bool(mask[m]) then {
      var r : qword = rest;
      r[m] = src[k];
      r
    } else rest
  }
}

val exec_pdep : (gpr_idx, gpr_idx, gpr_idx, OperandSize) -> ExecutionResult
function exec_pdep(dst, src, mask_reg, os) = {
  let src_val : qword = read_gpr(src, os);
  let mask_val : qword = read_gpr(mask_reg, os);
  let result : qword = pdep64(src_val, mask_val, 0, 0);
  write_gpr(dst, os, result);
  Ok(())
}

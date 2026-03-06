// MOVMSKPS — Extract Packed Single-Precision Floating-Point Sign Mask
// Creates a 4-bit mask from the MSB of each 32-bit single in XMM. No flags affected.

val exec_movmskps : (gpr_idx, xmmword) -> ExecutionResult
function exec_movmskps(dst, s) = {
  let mask : bits(4) = s[127] @ s[95] @ s[63] @ s[31];
  write_gpr32(dst, zero_extend(mask));
  Ok(())
}

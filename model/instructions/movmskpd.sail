// MOVMSKPD — Extract Packed Double-Precision Floating-Point Sign Mask
// Creates a 2-bit mask from the MSB of each 64-bit double in XMM. No flags affected.

val exec_movmskpd : (gpr_idx, xmmword) -> ExecutionResult
function exec_movmskpd(dst, s) = {
  let mask : bits(2) = s[127] @ s[63];
  write_gpr32(dst, zero_extend(mask));
  Ok(())
}

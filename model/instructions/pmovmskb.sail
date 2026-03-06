// PMOVMSKB — Move Byte Mask
// Creates a 16-bit mask from the MSB of each byte in XMM. No flags affected.

val exec_pmovmskb : (gpr_idx, xmmword) -> ExecutionResult
function exec_pmovmskb(dst, s) = {
  let mask : word = s[127] @ s[119] @ s[111] @ s[103] @
                         s[95]  @ s[87]  @ s[79]  @ s[71] @
                         s[63]  @ s[55]  @ s[47]  @ s[39] @
                         s[31]  @ s[23]  @ s[15]  @ s[7];
  write_gpr32(dst, zero_extend(mask));
  Ok(())
}

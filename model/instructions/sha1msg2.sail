// SHA1MSG2 — Perform a Final Calculation for the Next
//            Four SHA1 Message Dwords
//
// Performs the final calculation for the next four SHA1 message dwords
// using the intermediate result from SHA1MSG1. The result is stored
// in the destination XMM register.
// No flags affected. Modeled as external due to SHA complexity.

val __sha1msg2 : (xmmword, xmmword) -> xmmword

val exec_sha1msg2 : (simd_idx, xmmword) -> ExecutionResult
function exec_sha1msg2(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let result : xmmword = __sha1msg2(a, b);
  write_xmm_legacy(dst, result);
  Ok(())
}

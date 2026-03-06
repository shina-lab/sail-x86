// SHA1MSG1 — Perform an Intermediate Calculation for the Next
//            Four SHA1 Message Dwords
//
// Performs an intermediate calculation for the next four SHA1 message
// dwords. The result is stored in the destination XMM register.
// No flags affected. Modeled as external due to SHA complexity.

val __sha1msg1 : (xmmword, xmmword) -> xmmword

val exec_sha1msg1 : (simd_idx, xmmword) -> ExecutionResult
function exec_sha1msg1(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let result : xmmword = __sha1msg1(a, b);
  write_xmm_legacy(dst, result);
  Ok(())
}

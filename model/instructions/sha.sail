// SHA — SHA-1 and SHA-256 Extensions
//
// These instructions accelerate SHA-1 and SHA-256 hashing.
// The cryptographic operations are complex; we model them as external functions.

// SHA1NEXTE — Calculate SHA1 state variable E after four rounds
// Takes XMM dst (containing SHA1 state) and XMM src, returns updated 128-bit state.
val __sha1nexte : (xmmword, xmmword) -> xmmword

val exec_sha1nexte : (simd_idx, xmmword) -> ExecutionResult
function exec_sha1nexte(dst, src) = {
  let d : xmmword = read_xmm(dst);
  let s : xmmword = src;
  let result : xmmword = __sha1nexte(d, s);
  write_xmm_legacy(dst, result);
  Ok(())
}

// SHA1RNDS4 — Perform four rounds of SHA1 operation
// The imm8[1:0] selects which SHA1 function (Ch, Parity, Maj, Parity) to use.
val __sha1rnds4 : (xmmword, xmmword, byte) -> xmmword

val exec_sha1rnds4 : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_sha1rnds4(dst, src, imm8) = {
  let d : xmmword = read_xmm(dst);
  let s : xmmword = src;
  let result : xmmword = __sha1rnds4(d, s, imm8);
  write_xmm_legacy(dst, result);
  Ok(())
}

// SHA256MSG1 — Perform an intermediate calculation for the next four
// SHA256 message dwords.
val __sha256msg1 : (xmmword, xmmword) -> xmmword

val exec_sha256msg1 : (simd_idx, xmmword) -> ExecutionResult
function exec_sha256msg1(dst, src) = {
  let d : xmmword = read_xmm(dst);
  let s : xmmword = src;
  let result : xmmword = __sha256msg1(d, s);
  write_xmm_legacy(dst, result);
  Ok(())
}

// SHA256MSG2 — Perform a final calculation for the next four SHA256
// message dwords.
val __sha256msg2 : (xmmword, xmmword) -> xmmword

val exec_sha256msg2 : (simd_idx, xmmword) -> ExecutionResult
function exec_sha256msg2(dst, src) = {
  let d : xmmword = read_xmm(dst);
  let s : xmmword = src;
  let result : xmmword = __sha256msg2(d, s);
  write_xmm_legacy(dst, result);
  Ok(())
}

// SHA256RNDS2 — Perform two rounds of SHA256 operation
// Implicitly uses XMM0 as a third source operand.
val __sha256rnds2 : (xmmword, xmmword, xmmword) -> xmmword

val exec_sha256rnds2 : (simd_idx, xmmword) -> ExecutionResult
function exec_sha256rnds2(dst, src) = {
  let d : xmmword = read_xmm(dst);
  let s : xmmword = src;
  let xmm0_val : xmmword = read_xmm(0);
  let result : xmmword = __sha256rnds2(d, s, xmm0_val);
  write_xmm_legacy(dst, result);
  Ok(())
}

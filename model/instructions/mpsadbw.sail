// MPSADBW — Multiple Sum of Absolute Differences (SSE4.1)
// Complex operation modeled as external. No flags affected.

val __mpsadbw : (xmmword, xmmword, byte) -> xmmword

val exec_mpsadbw : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_mpsadbw(dst, src, imm8) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  write_xmm_legacy(dst, __mpsadbw(a, b, imm8));
  Ok(())
}

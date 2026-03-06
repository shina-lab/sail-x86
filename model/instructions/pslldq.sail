// PSLLDQ — Shift Double Quadword Left Logical (byte granularity)
// PSRLDQ — Shift Double Quadword Right Logical (byte granularity)
// Shifts entire 128-bit value left/right by imm8 bytes, filling with zeros.
// No flags affected.

val sll128 : (xmmword, int) -> xmmword
function sll128(v, count) = if count > 127 | count < 0 then zeros() else v << count

val srl128 : (xmmword, int) -> xmmword
function srl128(v, count) = if count > 127 | count < 0 then zeros() else v >> count

val exec_pslldq : (simd_idx, byte) -> ExecutionResult
function exec_pslldq(dst, imm8) = {
  let c : int = unsigned(imm8);
  let byte_count : int = if c > 15 then 16 else c;
  let a : xmmword = read_xmm(dst);
  let r : xmmword = sll128(a, byte_count * 8);
  write_xmm_legacy(dst, r);
  Ok(())
}

val exec_psrldq : (simd_idx, byte) -> ExecutionResult
function exec_psrldq(dst, imm8) = {
  let c : int = unsigned(imm8);
  let byte_count : int = if c > 15 then 16 else c;
  let a : xmmword = read_xmm(dst);
  let r : xmmword = srl128(a, byte_count * 8);
  write_xmm_legacy(dst, r);
  Ok(())
}

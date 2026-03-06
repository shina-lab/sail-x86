// PCMPISTRI — Packed Compare Implicit Length Strings, Return Index (SSE4.2)
//
// Compares two null-terminated string fragments using imm8 control.
// Lengths are implicit (determined by null characters in the operands).
// The result index is returned in ECX.
// Flags CF, ZF, SF, OF, AF, PF are set.
//
// This is a very complex operation; modeled as external.

val __pcmpistri : (xmmword, xmmword, byte) -> (dword, bit, bit, bit, bit)

val exec_pcmpistri : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_pcmpistri(dst, src, imm8) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let (idx, cf_val, zf_val, sf_val, of_val) = __pcmpistri(a, b, imm8);
  write_gpr32(RCX, idx);
  CF = cf_val;
  ZF = zf_val;
  SF = sf_val;
  OF = of_val;
  AF = bitzero;
  PF = bitzero;
  Ok(())
}

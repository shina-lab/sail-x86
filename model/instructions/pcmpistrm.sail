// PCMPISTRM — Packed Compare Implicit Length Strings, Return Mask (SSE4.2)
//
// Compares two null-terminated string fragments using imm8 control.
// Lengths are implicit (determined by null characters in the operands).
// The result mask is returned in XMM0.
// Flags CF, ZF, SF, OF, AF, PF are set.
//
// This is a very complex operation; modeled as external.

val __pcmpistrm : (xmmword, xmmword, byte) -> (xmmword, bit, bit, bit, bit)

val exec_pcmpistrm : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_pcmpistrm(dst, src, imm8) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let (mask, cf_val, zf_val, sf_val, of_val) = __pcmpistrm(a, b, imm8);
  write_xmm_legacy(0, mask);
  CF = cf_val;
  ZF = zf_val;
  SF = sf_val;
  OF = of_val;
  AF = bitzero;
  PF = bitzero;
  Ok(())
}

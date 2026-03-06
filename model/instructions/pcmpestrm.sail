// PCMPESTRM — Packed Compare Explicit Length Strings, Return Mask (SSE4.2)
//
// Compares two string fragments using imm8 control. The explicit lengths
// are in EAX (for xmm1) and EDX (for xmm2/m128). The result mask is
// returned in XMM0. Flags CF, ZF, SF, OF, AF, PF are set.
//
// This is a very complex operation; modeled as external.

val __pcmpestrm : (xmmword, dword, xmmword, dword, byte) -> (xmmword, bit, bit, bit, bit)

val exec_pcmpestrm : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_pcmpestrm(dst, src, imm8) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let la : dword = read_gpr32(RAX);
  let lb : dword = read_gpr32(RDX);
  let (mask, cf_val, zf_val, sf_val, of_val) = __pcmpestrm(a, la, b, lb, imm8);
  write_xmm_legacy(0, mask);
  CF = cf_val;
  ZF = zf_val;
  SF = sf_val;
  OF = of_val;
  AF = bitzero;
  PF = bitzero;
  Ok(())
}

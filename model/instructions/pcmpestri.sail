// PCMPESTRI — Packed Compare Explicit Length Strings, Return Index (SSE4.2)
//
// Compares two string fragments using imm8 control. The explicit lengths
// are in EAX (for xmm1) and EDX (for xmm2/m128). The result index is
// returned in ECX. Flags CF, ZF, SF, OF, AF, PF are set based on the
// result IntRes2.
//
// This is a very complex operation; modeled as external.

val __pcmpestri : (xmmword, dword, xmmword, dword, byte) -> (dword, bit, bit, bit, bit)

val exec_pcmpestri : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_pcmpestri(dst, src, imm8) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let la : dword = read_gpr32(RAX);
  let lb : dword = read_gpr32(RDX);
  let (idx, cf_val, zf_val, sf_val, of_val) = __pcmpestri(a, la, b, lb, imm8);
  write_gpr32(RCX, idx);
  CF = cf_val;
  ZF = zf_val;
  SF = sf_val;
  OF = of_val;
  AF = bitzero;
  PF = bitzero;
  Ok(())
}

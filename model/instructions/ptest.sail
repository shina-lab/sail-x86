// PTEST — Logical Compare (SSE4.1)
// Sets ZF if (src1 AND src2) is all zeros.
// Sets CF if (NOT(src1) AND src2) is all zeros.
// Clears OF, AF, PF, SF.

val exec_ptest : (xmmword, xmmword) -> ExecutionResult
function exec_ptest(src1, src2) = {
  let a : xmmword = src1;
  let b : xmmword = src2;
  let temp1 : xmmword = a & b;
  let temp2 : xmmword = (not_vec(a)) & b;
  ZF = if temp1 == zeros() then bitone else bitzero;
  CF = if temp2 == zeros() then bitone else bitzero;
  OF = bitzero;
  AF = bitzero;
  PF = bitzero;
  SF = bitzero;
  Ok(())
}

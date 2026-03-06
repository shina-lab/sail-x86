// LEA — Load Effective Address
//
// Stores the effective address (not the value at that address) into dst.
// No flags are affected. The effective address is computed by the decoder.

val exec_lea : (gpr_idx, qword, OperandSize) -> ExecutionResult
function exec_lea(dst, addr, os) = {
  write_gpr(dst, os, addr);
  Ok(())
}

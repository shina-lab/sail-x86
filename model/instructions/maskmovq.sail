// MASKMOVQ -- Store Selected Bytes of Quadword (MMX)
//
// Selectively writes bytes from the source MMX register to memory at
// DS:DI/EDI/RDI. Each byte in the mask MMX register controls whether
// the corresponding byte is written (high bit = 1 means write).
// This is an MMX instruction. No flags affected.

val __maskmovq : (qword, qword, qword) -> unit

val exec_maskmovq : (qword, qword, qword) -> ExecutionResult
function exec_maskmovq(src, mask, addr) = {
  __maskmovq(src, mask, addr);
  Ok(())
}

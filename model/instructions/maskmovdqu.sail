// MASKMOVDQU -- Store Selected Bytes of Double Quadword
//
// Selectively writes bytes from the source XMM register to memory at
// DS:DI/EDI/RDI. Each byte in the mask XMM register controls whether
// the corresponding byte is written (high bit = 1 means write).
// No flags affected.

val __maskmovdqu : (xmmword, xmmword, qword) -> unit

val exec_maskmovdqu : (xmmword, xmmword, qword) -> ExecutionResult
function exec_maskmovdqu(data, mask, addr) = {
  __maskmovdqu(data, mask, addr);
  Ok(())
}

// MOVDIR64B -- Move 64 Bytes as Direct Store
//
// Moves 64 bytes from the source memory address to the destination memory
// address using a direct store (write-combining, non-temporal).
// The destination must be 64-byte aligned.
// No flags affected. We model this as an external operation since
// it involves special memory ordering semantics.

val __movdir64b : (qword, qword) -> unit

val exec_movdir64b : (qword, qword) -> ExecutionResult
function exec_movdir64b(dst_addr, src_addr) = {
  __movdir64b(dst_addr, src_addr);
  Ok(())
}

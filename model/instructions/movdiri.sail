// MOVDIRI -- Move Doubleword/Quadword as Direct Store
//
// Moves a doubleword or quadword from a GPR to memory using a direct store
// (write-combining, non-temporal hint). No flags affected.

// MOVDIRI m32, r32
val exec_movdiri32 : (qword, dword) -> ExecutionResult
function exec_movdiri32(addr, src) = {
  mem_write32(addr, src);
  Ok(())
}

// MOVDIRI m64, r64
val exec_movdiri64 : (qword, qword) -> ExecutionResult
function exec_movdiri64(addr, src) = {
  mem_write64(addr, src);
  Ok(())
}

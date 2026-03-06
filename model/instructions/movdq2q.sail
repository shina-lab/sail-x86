// MOVDQ2Q -- Move Quadword from XMM to MMX Technology Register
//
// Moves the low 64 bits of an XMM register to an MMX register.
// No flags affected. We model MMX access as external.

val __write_mmx : (int, qword) -> unit

val exec_movdq2q : (int, simd_idx) -> ExecutionResult
function exec_movdq2q(mmx_dst, xmm_src) = {
  __write_mmx(mmx_dst, read_xmm(xmm_src)[63..0]);
  Ok(())
}

// MOVQ2DQ -- Move Quadword from MMX Technology to XMM Register
//
// Moves a 64-bit value from an MMX register to the low 64 bits of an XMM
// register, zeroing the upper 64 bits. No flags affected.
// MMX access modeled as external.

val __read_mmx : int -> qword

val exec_movq2dq : (simd_idx, int) -> ExecutionResult
function exec_movq2dq(xmm_dst, mmx_src) = {
  let v : qword = __read_mmx(mmx_src);
  write_xmm_legacy(xmm_dst, zeros(64) @ v);
  Ok(())
}

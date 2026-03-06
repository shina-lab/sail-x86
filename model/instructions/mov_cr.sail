// MOV -- Move to/from Control Registers
//
// Moves data between control registers (CR0-CR7, CR8) and general-purpose
// registers. These are privileged instructions (CPL=0 required).
// We model them as external due to complex side effects on processor state.

val __read_cr : int -> qword
val __write_cr : (int, qword) -> ExecutionResult

// MOV r64, CRn -- read control register
val exec_mov_from_cr : (gpr_idx, int) -> ExecutionResult
function exec_mov_from_cr(dst, cr_num) = {
  write_gpr(dst, OS64, __read_cr(cr_num));
  Ok(())
}

// MOV CRn, r64 -- write control register
val exec_mov_to_cr : (int, gpr_idx) -> ExecutionResult
function exec_mov_to_cr(cr_num, src) = {
  __write_cr(cr_num, read_gpr(src, OS64))
}

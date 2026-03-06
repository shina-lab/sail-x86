// MOV -- Move to/from Debug Registers
//
// Moves data between debug registers (DR0-DR7) and general-purpose
// registers. These are privileged instructions (CPL=0 required).
// We model them as external due to complex side effects.

val __read_dr : int -> qword
val __write_dr : (int, qword) -> ExecutionResult

// MOV r64, DRn -- read debug register
val exec_mov_from_dr : (gpr_idx, int) -> ExecutionResult
function exec_mov_from_dr(dst, dr_num) = {
  write_gpr(dst, OS64, __read_dr(dr_num));
  Ok(())
}

// MOV DRn, r64 -- write debug register
val exec_mov_to_dr : (int, gpr_idx) -> ExecutionResult
function exec_mov_to_dr(dr_num, src) = {
  __write_dr(dr_num, read_gpr(src, OS64))
}

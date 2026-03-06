// UD — Undefined Instruction
//
// UD0, UD1, UD2 all raise an invalid opcode (#UD) exception.
// UD2 is the standard "intentional undefined instruction" used by compilers.

val exec_ud0 : unit -> ExecutionResult
function exec_ud0() = raise_UD()

val exec_ud1 : unit -> ExecutionResult
function exec_ud1() = raise_UD()

val exec_ud2 : unit -> ExecutionResult
function exec_ud2() = raise_UD()

// CLC — Clear Carry Flag
// STC — Set Carry Flag
// CMC — Complement Carry Flag
// CLD — Clear Direction Flag
// STD — Set Direction Flag

val exec_clc : unit -> ExecutionResult
function exec_clc() = { CF = bitzero; Ok(()) }

val exec_stc : unit -> ExecutionResult
function exec_stc() = { CF = bitone; Ok(()) }

val exec_cmc : unit -> ExecutionResult
function exec_cmc() = {
  CF = if CF == bitone then bitzero else bitone;
  Ok(())
}

val exec_cld : unit -> ExecutionResult
function exec_cld() = { DF = bitzero; Ok(()) }

val exec_std : unit -> ExecutionResult
function exec_std() = { DF = bitone; Ok(()) }

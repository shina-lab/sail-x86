// OUT — Output to Port
//
// Writes a byte/word/dword from AL/AX/EAX to an I/O port.
// No flags affected.

val __port_out8  : (word, byte)  -> unit
val __port_out16 : (word, word) -> unit
val __port_out32 : (word, dword) -> unit

val exec_out : (word, OperandSize) -> ExecutionResult
function exec_out(port, os) = {
  match os {
    OS8  => __port_out8(port, read_gpr8l(RAX)),
    OS16 => __port_out16(port, read_gpr16(RAX)),
    OS32 => __port_out32(port, read_gpr32(RAX)),
    OS64 => (),
  };
  Ok(())
}

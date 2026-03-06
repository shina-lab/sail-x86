// IN — Input From Port
//
// Reads a byte/word/dword from an I/O port into AL/AX/EAX.
// No flags affected. Port access delegated to execution environment.

val __port_in8  : word -> byte
val __port_in16 : word -> word
val __port_in32 : word -> dword

val exec_in : (word, OperandSize) -> ExecutionResult
function exec_in(port, os) = {
  match os {
    OS8  => write_gpr8l(RAX, __port_in8(port)),
    OS16 => write_gpr16(RAX, __port_in16(port)),
    OS32 => write_gpr32(RAX, __port_in32(port)),
    OS64 => (),
  };
  Ok(())
}

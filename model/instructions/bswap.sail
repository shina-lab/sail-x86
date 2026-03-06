// BSWAP — Byte Swap
//
// Reverses the byte order of a 32-bit or 64-bit register.
// No flags are affected.

val exec_bswap : (gpr_idx, OperandSize) -> ExecutionResult
function exec_bswap(dst, os) = {
  match os {
    OS32 => {
      let v : dword = read_gpr32(dst);
      write_gpr32(dst, v[7..0] @ v[15..8] @ v[23..16] @ v[31..24])
    },
    OS64 => {
      let v : qword = read_gpr64(dst);
      write_gpr64(dst, v[7..0] @ v[15..8] @ v[23..16] @ v[31..24] @
                       v[39..32] @ v[47..40] @ v[55..48] @ v[63..56])
    },
    _ => (),
  };
  Ok(())
}

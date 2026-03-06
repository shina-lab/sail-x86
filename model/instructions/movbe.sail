// MOVBE — Move Data After Swapping Bytes
//
// Byte-swaps the source and stores in destination (endian conversion).
// No flags affected. Only 16/32/64-bit operand sizes.

val bswap16 : word -> word
function bswap16(v) = v[7..0] @ v[15..8]

val bswap32 : dword -> dword
function bswap32(v) = v[7..0] @ v[15..8] @ v[23..16] @ v[31..24]

val bswap64 : qword -> qword
function bswap64(v) =
  v[7..0] @ v[15..8] @ v[23..16] @ v[31..24] @
  v[39..32] @ v[47..40] @ v[55..48] @ v[63..56]

val exec_movbe_load : (gpr_idx, gpr_idx, OperandSize) -> ExecutionResult
function exec_movbe_load(dst, src, os) = {
  match os {
    OS16 => write_gpr16(dst, bswap16(read_gpr16(src))),
    OS32 => write_gpr32(dst, bswap32(read_gpr32(src))),
    OS64 => write_gpr64(dst, bswap64(read_gpr64(src))),
    _    => (),
  };
  Ok(())
}

// CRC32 — Accumulate CRC32 Value
//
// Accumulates a CRC32 (polynomial 11EDC6F41H) value using the source operand.
// No flags affected. The actual CRC computation is delegated to an external
// function since the bit-reflection and polynomial division are complex.

val __crc32_8  : (dword, byte)  -> dword
val __crc32_16 : (dword, word) -> dword
val __crc32_32 : (dword, dword) -> dword
val __crc32_64 : (dword, qword) -> dword

val exec_crc32 : (gpr_idx, gpr_idx, OperandSize) -> ExecutionResult
function exec_crc32(dst, src, os) = {
  let acc : dword = read_gpr32(dst);
  let result : dword = match os {
    OS8  => __crc32_8(acc, read_gpr8l(src)),
    OS16 => __crc32_16(acc, read_gpr16(src)),
    OS32 => __crc32_32(acc, read_gpr32(src)),
    OS64 => __crc32_64(acc, read_gpr64(src)),
  };
  write_gpr32(dst, result);
  Ok(())
}

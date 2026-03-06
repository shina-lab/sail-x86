// XLAT/XLATB — Table Look-up Translation
//
// AL := byte at [RBX + zero_extend(AL)] (64-bit mode).
// No flags affected.

val exec_xlat : AddressSize -> ExecutionResult
function exec_xlat(asz) = {
  let al : qword = zero_extend(read_gpr8l(RAX));
  let addr : qword = match asz {
    AS64 => read_gpr64(RBX) + al,
    AS32 => zero_extend(read_gpr32(RBX)) + al,
    AS16 => zero_extend(read_gpr16(RBX)) + al,
  };
  write_gpr8l(RAX, mem_read8(addr));
  Ok(())
}

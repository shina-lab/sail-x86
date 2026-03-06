// AAD — ASCII Adjust AX Before Division
//
// AL := (AL + (AH * imm8)) AND 0xFF; AH := 0.
// Invalid in 64-bit mode (#UD).
// SF, ZF, PF set according to AL result; OF, AF, CF undefined.

val exec_aad : byte -> ExecutionResult
function exec_aad(imm8) = {
  if cur_mode == LongMode then
    raise_UD()
  else {
    let al : byte = read_gpr8l(RAX);
    let ah : byte = read_gpr8h(RAX);
    let result : byte = to_bits_truncate(unsigned(al) + unsigned(ah) * unsigned(imm8));
    write_gpr8l(RAX, result);
    write_gpr8h(RAX, 0x00);
    update_SF_ZF_PF(result);
    Ok(())
  }
}

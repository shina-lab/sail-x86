// AAM — ASCII Adjust AX After Multiply
//
// AH := AL / imm8; AL := AL MOD imm8.
// Invalid in 64-bit mode (#UD). #DE if imm8 = 0.
// SF, ZF, PF set according to AL result; OF, AF, CF undefined.

val exec_aam : byte -> ExecutionResult
function exec_aam(imm8) = {
  if cur_mode == LongMode then
    raise_UD()
  else if imm8 == 0x00 then
    raise_DE()
  else {
    let al_val : int = unsigned(read_gpr8l(RAX));
    let imm_val : int = unsigned(imm8);
    assert(imm_val > 0);
    let quotient : byte = to_bits_truncate(quot_round_zero(al_val, imm_val));
    let remainder : byte = to_bits_truncate(rem_round_zero(al_val, imm_val));
    write_gpr8h(RAX, quotient);
    write_gpr8l(RAX, remainder);
    update_SF_ZF_PF(remainder);
    Ok(())
  }
}

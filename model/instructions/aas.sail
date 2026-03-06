// AAS — ASCII Adjust AL After Subtraction
//
// Adjusts the result of subtraction of two unpacked BCD values.
// Invalid in 64-bit mode (#UD). In compat/legacy mode:
//   If (AL & 0x0F) > 9 or AF=1, then AX -= 6, AH -= 1, AF=CF=1.
//   Else AF=CF=0. In both cases, AL := AL & 0x0F.
// OF, SF, ZF, PF are undefined.

val exec_aas : unit -> ExecutionResult
function exec_aas() = {
  if cur_mode == LongMode then
    raise_UD()
  else {
    let al : byte = read_gpr8l(RAX);
    if ((al & 0x0F) >_u 0x09) | (AF == bitone) then {
      let ax : word = read_gpr16(RAX);
      write_gpr16(RAX, ax - 0x0006);
      let ah : byte = read_gpr8h(RAX);
      write_gpr8h(RAX, ah - 0x01);
      AF = bitone;
      CF = bitone;
    } else {
      AF = bitzero;
      CF = bitzero;
    };
    let al_new : byte = read_gpr8l(RAX);
    write_gpr8l(RAX, al_new & 0x0F);
    Ok(())
  }
}

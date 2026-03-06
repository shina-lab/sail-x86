// AAA — ASCII Adjust After Addition
//
// Adjusts the sum of two unpacked BCD values to create an unpacked BCD result.
// Invalid in 64-bit mode (#UD). In compat/legacy mode:
//   If (AL & 0x0F) > 9 or AF=1, then AX += 0x106, AF=CF=1; else AF=CF=0.
//   AL := AL & 0x0F.
// OF, SF, ZF, PF are undefined.

val exec_aaa : unit -> ExecutionResult
function exec_aaa() = {
  if cur_mode == LongMode then
    raise_UD()
  else {
    let al : byte = read_gpr8l(RAX);
    if ((al & 0x0F) >_u 0x09) | (AF == bitone) then {
      let ax : word = read_gpr16(RAX);
      write_gpr16(RAX, ax + 0x0106);
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

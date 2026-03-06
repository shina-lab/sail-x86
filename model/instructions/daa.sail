// DAA — Decimal Adjust AL After Addition
// DAS — Decimal Adjust AL After Subtraction
//
// BCD adjust instructions. Invalid in 64-bit mode (#UD).

val exec_daa : unit -> ExecutionResult
function exec_daa() = {
  if cur_mode == LongMode then raise_UD()
  else {
    let old_al : byte = read_gpr8l(RAX);
    let old_cf : bit = CF;
    CF = bitzero;
    let low_adjust : bool = if old_al[3..0] >_u 0x9 then true
                            else AF == bitone;
    if low_adjust then {
      let new_al : byte = read_gpr8l(RAX) + 0x06;
      write_gpr8l(RAX, new_al);
      let carry : bool = if old_cf == bitone then true
                         else new_al <_u old_al;
      CF = bool_to_bit(carry);
      AF = bitone;
    } else {
      AF = bitzero;
    };
    let high_adjust : bool = if old_al >_u 0x99 then true
                             else old_cf == bitone;
    if high_adjust then {
      write_gpr8l(RAX, read_gpr8l(RAX) + 0x60);
      CF = bitone;
    };
    update_SF_ZF_PF(read_gpr8l(RAX));
    Ok(())
  }
}

val exec_das : unit -> ExecutionResult
function exec_das() = {
  if cur_mode == LongMode then raise_UD()
  else {
    let old_al : byte = read_gpr8l(RAX);
    let old_cf : bit = CF;
    CF = bitzero;
    let low_adjust : bool = if old_al[3..0] >_u 0x9 then true
                            else AF == bitone;
    if low_adjust then {
      let new_al : byte = read_gpr8l(RAX) - 0x06;
      write_gpr8l(RAX, new_al);
      let borrow : bool = if old_cf == bitone then true
                          else new_al >_u old_al;
      CF = bool_to_bit(borrow);
      AF = bitone;
    } else {
      AF = bitzero;
    };
    let high_adjust : bool = if old_al >_u 0x99 then true
                             else old_cf == bitone;
    if high_adjust then {
      write_gpr8l(RAX, read_gpr8l(RAX) - 0x60);
      CF = bitone;
    };
    update_SF_ZF_PF(read_gpr8l(RAX));
    Ok(())
  }
}

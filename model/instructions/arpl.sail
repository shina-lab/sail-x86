// ARPL — Adjust RPL Field of Segment Selector
//
// If DEST.RPL < SRC.RPL, then ZF := 1, DEST.RPL := SRC.RPL; else ZF := 0.
// Not encodable in 64-bit mode (opcode reused for MOVSXD).

val exec_arpl : (gpr_idx, gpr_idx) -> ExecutionResult
function exec_arpl(dst, src) = {
  if cur_mode == LongMode then
    raise_UD()
  else {
    let dst_val : word = read_gpr16(dst);
    let src_val : word = read_gpr16(src);
    if (dst_val[1..0]) <_u (src_val[1..0]) then {
      ZF = bitone;
      write_gpr16(dst, dst_val[15..2] @ src_val[1..0]);
    } else {
      ZF = bitzero;
    };
    Ok(())
  }
}
